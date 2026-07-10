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

    @State private var bucket: TaxBucket = .travel
    @State private var amount = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var businessUsePercent: Double = 100

    // Receipt scan
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var scanError: String?
    @State private var receiptImage: UIImage?

    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Bucket", selection: $bucket) {
                        ForEach(TaxBucket.allCases) { b in
                            Label(b.displayName, systemImage: b.systemImage).tag(b)
                        }
                    }
                    Text(bucket.examples)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Details") {
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
                    Section("Business Use") {
                        HStack {
                            Text("\(Int(businessUsePercent))% business")
                            Spacer()
                        }
                        Slider(value: $businessUsePercent, in: 0...100, step: 5)
                        if let amt = Double(amount), amt > 0, businessUsePercent < 100 {
                            HStack {
                                Text("Deductible")
                                Spacer()
                                Text(currency(amt * businessUsePercent / 100))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text("Only the business portion of mixed-use items (phone, data) is deductible.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Receipt") {
                    if let receiptImage {
                        HStack(spacing: 12) {
                            Image(uiImage: receiptImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Receipt attached")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                self.receiptImage = nil
                                libraryItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    if isScanning {
                        HStack {
                            ProgressView()
                            Text("Reading receipt…").foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            showCamera = true
                        } label: {
                            Label(receiptImage == nil ? "Scan Receipt" : "Retake Photo", systemImage: "doc.viewfinder")
                        }
                        PhotosPicker(selection: $libraryItem, matching: .images) {
                            Label("Choose Receipt Photo", systemImage: "photo.on.rectangle")
                        }
                    }
                    if let scanError {
                        Text(scanError).font(.caption).foregroundColor(.red)
                    }
                }
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
            .onChange(of: libraryItem) {
                guard let item = libraryItem else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        scan(image)
                    }
                }
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
                    isScanning = false
                    if parsed.totalPrice == nil {
                        scanError = "Couldn't find a total — enter the amount manually."
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
        let entry = ExpenseEntry(
            category: bucket.rawValue,
            amount: Double(amount) ?? 0,
            note: note.trimmingCharacters(in: .whitespaces),
            businessUsePercent: bucket.supportsBusinessUse ? businessUsePercent : 100
        )
        entry.date = date
        entry.receiptImageData = receiptImage?.jpegData(compressionQuality: 0.7)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
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
