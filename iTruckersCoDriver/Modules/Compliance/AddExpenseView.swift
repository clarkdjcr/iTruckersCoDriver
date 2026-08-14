//
//  AddExpenseView.swift
//  iTruckersCoDriver
//
//  Manual expense entry for a 1099 driver, with optional receipt scan to
//  pre-fill the amount via on-device Vision OCR.
//

import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
import UIKit

struct AddExpenseView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingExpenses: [ExpenseEntry]

    @State private var bucket: TaxBucket = .other
    @State private var amount = ""
    @State private var vendorName = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var businessUsePercent: Double = 100

    // Receipt scan
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var scanError: String?
    @State private var receiptImage: UIImage?
    @State private var rawOCRText = ""
    @State private var ocrConfidence: Double = 0
    @State private var subtotal: Double = 0
    @State private var taxAmount: Double = 0
    @State private var stateCode = ""
    @State private var gallons: Double = 0
    @State private var pricePerGallon: Double = 0
    @State private var odometer: Double = 0
    @State private var paymentMethod = ""

    private var availableBuckets: [TaxBucket] {
        TaxBucket.allowed(for: appState.driverType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Bucket", selection: $bucket) {
                        ForEach(availableBuckets) { b in
                            Label(b.displayName, systemImage: b.systemImage).tag(b)
                        }
                    }
                    Text(bucket.examples)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Details") {
                    TextField("Vendor", text: $vendorName)
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField("Description (e.g. CB radio, hotel)", text: $note)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if bucket.supportsBusinessUse {
                    businessUseSection
                }

                receiptSection
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled((Double(amount) ?? 0) <= 0)
                }
            }
            .sheet(isPresented: $showCamera) {
                ExpenseImagePicker(sourceType: .camera) { image in
                    showCamera = false
                    scan(image)
                }
            }
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        scan(image)
                    }
                }
            }
        }
    }

    private var businessUseSection: some View {
        Section("Business Use") {
            Text("\(Int(businessUsePercent))% business")
            Slider(value: $businessUsePercent, in: 0...100, step: 5)
            if let value = Double(amount), value > 0, businessUsePercent < 100 {
                LabeledContent("Deductible", value: currency(value * businessUsePercent / 100))
            }
            Text("Only the business portion of mixed-use items is deductible.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var receiptSection: some View {
        Section("Receipt") {
            if let receiptImage {
                HStack(spacing: 12) {
                    Image(uiImage: receiptImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Receipt attached")
                    Spacer()
                    Button("Remove receipt", systemImage: "trash", role: .destructive) {
                        self.receiptImage = nil
                        libraryItem = nil
                    }
                    .labelStyle(.iconOnly)
                }
            }

            if isScanning {
                LabeledContent {
                    ProgressView()
                } label: {
                    Text("Reading receipt…")
                }
            } else {
                Button(receiptImage == nil ? "Scan Receipt" : "Retake Photo", systemImage: "doc.viewfinder") {
                    showCamera = true
                }
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label("Choose Receipt Photo", systemImage: "photo.on.rectangle")
                }
            }

            if ocrConfidence > 0 {
                Text("OCR confidence: \(Int(ocrConfidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(ocrConfidence >= 0.75 ? Color.secondary : Color.orange)
            }
            if let scanError {
                Text(scanError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Actions

    private func scan(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            scanError = "Couldn't read the image."
            return
        }
        receiptImage = image
        isScanning = true
        scanError = nil
        Task {
            do {
                let ocr = try await DocumentProcessor.shared.extractText(from: cgImage)
                let parsed = DocumentProcessor.shared.parseReceipt(from: ocr)
                await MainActor.run {
                    if let total = parsed.totalPrice { amount = String(format: "%.2f", total) }
                    if let parsedDate = parsed.date { date = parsedDate }
                    vendorName = parsed.vendorName ?? ""
                    note = parsed.vendorName ?? note
                    rawOCRText = parsed.rawText
                    ocrConfidence = parsed.confidence
                    subtotal = parsed.subtotal ?? 0
                    taxAmount = parsed.taxAmount ?? 0
                    stateCode = parsed.state ?? ""
                    gallons = parsed.gallons ?? 0
                    pricePerGallon = parsed.pricePerGallon ?? 0
                    odometer = parsed.odometer ?? 0
                    paymentMethod = parsed.paymentMethod ?? ""
                    bucket = TaxBucket.suggested(from: parsed.rawText, for: appState.driverType)
                    isScanning = false
                    if parsed.totalPrice == nil {
                        scanError = "Couldn't find a total — review and enter it manually."
                    }
                }
            } catch {
                await MainActor.run {
                    scanError = "OCR failed — enter the amount manually."
                    isScanning = false
                }
            }
        }
    }

    private func save() {
        let total = Double(amount) ?? 0
        let fingerprint = receiptFingerprint(vendor: vendorName, date: date, amount: total)
        if !fingerprint.isEmpty,
           existingExpenses.contains(where: { $0.receiptFingerprint == fingerprint }) {
            scanError = "This receipt appears to have already been saved."
            return
        }

        let entry = ExpenseEntry(
            category: bucket.rawValue,
            amount: total,
            note: note.trimmingCharacters(in: .whitespaces),
            businessUsePercent: bucket.supportsBusinessUse ? businessUsePercent : 100
        )
        entry.date = date
        entry.vendorName = vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.subtotal = subtotal
        entry.taxAmount = taxAmount
        entry.paymentMethod = paymentMethod
        entry.stateCode = stateCode
        entry.gallons = gallons
        entry.pricePerGallon = pricePerGallon
        entry.odometer = odometer
        entry.rawOCRText = rawOCRText
        entry.ocrConfidence = ocrConfidence
        entry.isVerified = true
        entry.receiptFingerprint = fingerprint
        entry.receiptImageData = receiptImage?.jpegData(compressionQuality: 0.7)
        modelContext.insert(entry)

        if appState.driverType == .ownerOperator, bucket == .fuel, gallons > 0 {
            let resolvedPrice = pricePerGallon > 0 ? pricePerGallon : total / gallons
            let fuel = FuelRecord(
                driverID: appState.driverID,
                gallons: gallons,
                pricePerGallon: resolvedPrice,
                odometer: odometer,
                stateCode: stateCode,
                stationName: vendorName
            )
            fuel.date = date
            modelContext.insert(fuel)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            scanError = "Couldn't save this receipt. Please try again."
        }
    }

    private func receiptFingerprint(vendor: String, date: Date, amount: Double) -> String {
        guard amount > 0 else { return "" }
        let normalizedVendor = vendor.lowercased()
            .filter { $0.isLetter || $0.isNumber }
        guard !normalizedVendor.isEmpty else { return "" }
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        return "\(normalizedVendor)|\(Int(day))|\(String(format: "%.2f", amount))"
    }

    private func currency(_ value: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        return f.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Camera picker (self-contained; private to this file)

private struct ExpenseImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    var onPick: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onPick(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif
