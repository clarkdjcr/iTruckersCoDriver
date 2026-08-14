//
//  BatchReceiptImportView.swift
//  iTruckersCoDriver
//
//  Multi-PDF receipt import with page-by-page OCR and driver review.
//

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers
import UIKit

#if os(iOS)
struct ReceiptDraft: Identifiable {
    let id = UUID()
    var sourceName: String
    var pageNumber: Int
    var imageData: Data
    var vendorName: String
    var date: Date
    var amount: Double
    var subtotal: Double
    var taxAmount: Double
    var bucket: TaxBucket
    var stateCode: String
    var gallons: Double
    var pricePerGallon: Double
    var odometer: Double
    var paymentMethod: String
    var rawOCRText: String
    var ocrConfidence: Double
    var businessUsePercent: Double = 100
    var isSelected = true

    init(sourceName: String, pageNumber: Int, imageData: Data, receipt: ReceiptData, driverType: DriverType) {
        self.sourceName = sourceName
        self.pageNumber = pageNumber
        self.imageData = imageData
        self.vendorName = receipt.vendorName ?? ""
        self.date = receipt.date ?? Date()
        self.amount = receipt.totalPrice ?? 0
        self.subtotal = receipt.subtotal ?? 0
        self.taxAmount = receipt.taxAmount ?? 0
        self.bucket = TaxBucket.suggested(from: receipt.rawText, for: driverType)
        self.stateCode = receipt.state ?? ""
        self.gallons = receipt.gallons ?? 0
        self.pricePerGallon = receipt.pricePerGallon ?? 0
        self.odometer = receipt.odometer ?? 0
        self.paymentMethod = receipt.paymentMethod ?? ""
        self.rawOCRText = receipt.rawText
        self.ocrConfidence = receipt.confidence
    }
}

struct BatchReceiptImportView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingExpenses: [ExpenseEntry]

    @State private var drafts: [ReceiptDraft] = []
    @State private var showingImporter = false
    @State private var isProcessing = false
    @State private var processedPages = 0
    @State private var totalPages = 0
    @State private var errorMessage: String?

    private var selectedDrafts: [ReceiptDraft] {
        drafts.filter { $0.isSelected && $0.amount > 0 }
    }

    private var availableBuckets: [TaxBucket] {
        TaxBucket.allowed(for: appState.driverType)
    }

    var body: some View {
        NavigationStack {
            Group {
                if drafts.isEmpty && !isProcessing {
                    ContentUnavailableView {
                        Label("Import Receipt PDFs", systemImage: "doc.on.doc")
                    } description: {
                        Text("Select one or more PDFs. Each page will be read as a receipt and held for your review.")
                    } actions: {
                        Button("Choose PDFs", systemImage: "folder") {
                            showingImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    draftList
                }
            }
            .navigationTitle("Receipt Batch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add PDFs", systemImage: "plus") {
                        showingImporter = true
                    }
                    .disabled(isProcessing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save \(selectedDrafts.count)") {
                        saveSelectedDrafts()
                    }
                    .disabled(isProcessing || selectedDrafts.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task { await processPDFs(urls) }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .alert("Receipt Import", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var draftList: some View {
        List {
            if isProcessing {
                Section {
                    ProgressView(
                        value: Double(processedPages),
                        total: Double(max(totalPages, 1))
                    )
                    Text("Reading page \(processedPages) of \(totalPages)…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Pages to Review") {
                ForEach($drafts) { $draft in
                    NavigationLink {
                        ReceiptDraftEditor(draft: $draft, allowedBuckets: availableBuckets)
                    } label: {
                        ReceiptDraftRow(draft: draft)
                    }
                    .swipeActions(edge: .leading) {
                        Button(draft.isSelected ? "Exclude" : "Include") {
                            draft.isSelected.toggle()
                        }
                        .tint(draft.isSelected ? .orange : .green)
                    }
                }
                .onDelete { offsets in
                    drafts.remove(atOffsets: offsets)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @MainActor
    private func processPDFs(_ urls: [URL]) async {
        isProcessing = true
        processedPages = 0

        totalPages = urls.reduce(0) { count, url in
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            return count + (PDFDocument(url: url)?.pageCount ?? 0)
        }

        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            guard let document = PDFDocument(url: url) else { continue }

            for index in 0..<document.pageCount {
                defer { processedPages += 1 }
                guard let page = document.page(at: index) else { continue }
                let image = page.thumbnail(of: CGSize(width: 1800, height: 2400), for: .mediaBox)
                guard let cgImage = image.cgImage,
                      let imageData = image.jpegData(compressionQuality: 0.8) else { continue }

                do {
                    let results = try await DocumentProcessor.shared.extractText(from: cgImage)
                    let receipt = DocumentProcessor.shared.parseReceipt(from: results)
                    drafts.append(
                        ReceiptDraft(
                            sourceName: url.lastPathComponent,
                            pageNumber: index + 1,
                            imageData: imageData,
                            receipt: receipt,
                            driverType: appState.driverType
                        )
                    )
                } catch {
                    errorMessage = "Some PDF pages could not be read. You can retry those pages individually."
                }
            }
        }

        isProcessing = false
        if drafts.isEmpty && errorMessage == nil {
            errorMessage = "No readable receipt pages were found."
        }
    }

    private func saveSelectedDrafts() {
        let existingFingerprints = Set(existingExpenses.map(\.receiptFingerprint))
        var stagedFingerprints = Set<String>()
        var duplicateCount = 0

        for draft in selectedDrafts {
            let fingerprint = receiptFingerprint(
                vendor: draft.vendorName,
                date: draft.date,
                amount: draft.amount
            )
            if !fingerprint.isEmpty &&
                (existingFingerprints.contains(fingerprint) || stagedFingerprints.contains(fingerprint)) {
                duplicateCount += 1
                continue
            }
            stagedFingerprints.insert(fingerprint)

            let expense = ExpenseEntry(
                category: draft.bucket.rawValue,
                amount: draft.amount,
                note: draft.vendorName.isEmpty ? "PDF receipt" : draft.vendorName,
                businessUsePercent: draft.bucket.supportsBusinessUse ? draft.businessUsePercent : 100
            )
            expense.date = draft.date
            expense.vendorName = draft.vendorName
            expense.subtotal = draft.subtotal
            expense.taxAmount = draft.taxAmount
            expense.paymentMethod = draft.paymentMethod
            expense.stateCode = draft.stateCode
            expense.gallons = draft.gallons
            expense.pricePerGallon = draft.pricePerGallon
            expense.odometer = draft.odometer
            expense.rawOCRText = draft.rawOCRText
            expense.ocrConfidence = draft.ocrConfidence
            expense.isVerified = true
            expense.receiptFingerprint = fingerprint
            expense.receiptImageData = draft.imageData
            modelContext.insert(expense)

            if appState.driverType == .ownerOperator, draft.bucket == .fuel, draft.gallons > 0 {
                let price = draft.pricePerGallon > 0
                    ? draft.pricePerGallon
                    : draft.amount / draft.gallons
                let fuel = FuelRecord(
                    driverID: appState.driverID,
                    gallons: draft.gallons,
                    pricePerGallon: price,
                    odometer: draft.odometer,
                    stateCode: draft.stateCode,
                    stationName: draft.vendorName
                )
                fuel.date = draft.date
                modelContext.insert(fuel)
            }
        }

        do {
            try modelContext.save()
            if duplicateCount > 0 {
                errorMessage = "Saved the new receipts and skipped \(duplicateCount) probable duplicate(s)."
                drafts.removeAll()
            } else {
                dismiss()
            }
        } catch {
            errorMessage = "The receipt batch could not be saved."
        }
    }

    private func receiptFingerprint(vendor: String, date: Date, amount: Double) -> String {
        guard amount > 0 else { return "" }
        let normalizedVendor = vendor.lowercased().filter { $0.isLetter || $0.isNumber }
        guard !normalizedVendor.isEmpty else { return "" }
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        return "\(normalizedVendor)|\(Int(day))|\(String(format: "%.2f", amount))"
    }
}

private struct ReceiptDraftRow: View {
    let draft: ReceiptDraft

    var body: some View {
        HStack(spacing: 12) {
            if let image = UIImage(data: draft.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(draft.vendorName.isEmpty ? "Unknown Vendor" : draft.vendorName)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(draft.sourceName) · Page \(draft.pageNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Label(draft.bucket.displayName, systemImage: draft.bucket.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(draft.amount, format: .currency(code: "USD"))
                Image(systemName: draft.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(draft.isSelected ? .green : .secondary)
            }
        }
        .opacity(draft.isSelected ? 1 : 0.55)
    }
}

private struct ReceiptDraftEditor: View {
    @Binding var draft: ReceiptDraft
    let allowedBuckets: [TaxBucket]

    var body: some View {
        Form {
            if let image = UIImage(data: draft.imageData) {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                }
            }

            Section("Review") {
                Toggle("Include in batch", isOn: $draft.isSelected)
                TextField("Vendor", text: $draft.vendorName)
                TextField("Amount", value: $draft.amount, format: .number)
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                Picker("Category", selection: $draft.bucket) {
                    ForEach(allowedBuckets) { bucket in
                        Text(bucket.displayName).tag(bucket)
                    }
                }
            }

            if draft.bucket == .fuel {
                Section("Fuel Details") {
                    TextField("Gallons", value: $draft.gallons, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Price per gallon", value: $draft.pricePerGallon, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("State", text: $draft.stateCode)
                        .textInputAutocapitalization(.characters)
                    TextField("Odometer", value: $draft.odometer, format: .number)
                        .keyboardType(.decimalPad)
                }
            }

            if draft.bucket.supportsBusinessUse {
                Section("Business Use") {
                    Slider(value: $draft.businessUsePercent, in: 0...100, step: 5)
                    Text("\(Int(draft.businessUsePercent))% business use")
                }
            }

            Section("OCR") {
                LabeledContent("Confidence", value: draft.ocrConfidence, format: .percent)
                DisclosureGroup("Recognized Text") {
                    Text(draft.rawOCRText)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Review Receipt")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
