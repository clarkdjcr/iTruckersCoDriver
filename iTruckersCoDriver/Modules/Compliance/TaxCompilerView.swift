//
//  TaxCompilerView.swift
//  iTruckersCoDriver
//
//  Interactive OCR compilation of PDF receipts with direct Excel export.
//

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers
import UIKit

#if os(iOS)
struct CompiledTaxItem: Identifiable {
    let id = UUID()
    var sourceName: String
    var pageNumber: Int
    var imageURL: URL
    var vendorName: String
    var date: Date
    var amount: Double
    var bucket: TaxBucket
    var rawOCRText: String
    var ocrConfidence: Double
    var isSelected = true

    init(sourceName: String, pageNumber: Int, imageURL: URL, receipt: ReceiptData, driverType: DriverType) {
        self.sourceName = sourceName
        self.pageNumber = pageNumber
        self.imageURL = imageURL
        self.vendorName = receipt.vendorName ?? ""
        self.date = receipt.date ?? Date()
        self.amount = receipt.totalPrice ?? 0
        self.bucket = TaxBucket.suggested(from: receipt.rawText, for: driverType)
        self.rawOCRText = receipt.rawText
        self.ocrConfidence = receipt.confidence
    }
}

struct TaxCompilerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingExpenses: [ExpenseEntry]

    @State private var items: [CompiledTaxItem] = []
    @State private var isProcessing = false
    @State private var processedPages = 0
    @State private var totalPages = 0
    @State private var showingImporter = false
    @State private var errorMessage: String?
    @State private var exportURL: URL?
    @State private var showingShareSheet = false

    private var availableBuckets: [TaxBucket] {
        TaxBucket.allowed(for: appState.driverType)
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty && !isProcessing {
                    ContentUnavailableView {
                        Label("OCR Tax Compiler", systemImage: "tablecells.badge.ellipsis")
                    } description: {
                        Text("Select PDF receipts from iCloud or local storage. We will extract and compile their data into an Excel spreadsheet.")
                    } actions: {
                        Button("Select Receipts", systemImage: "folder") {
                            showingImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    compilationList
                }
            }
            .navigationTitle("Tax Compiler")
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
                if !items.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Menu {
                            Button("Export to Excel", systemImage: "arrow.up.doc") {
                                exportExcel()
                            }
                            Button("Save to Expenses", systemImage: "square.and.arrow.down") {
                                saveToExpenses()
                            }
                        } label: {
                            Text("Actions")
                        }
                        .disabled(isProcessing)
                    }
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
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Tax Compiler", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onDisappear {
                cleanUpDraftFiles()
            }
        }
    }

    private var compilationList: some View {
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

            Section("Compiled Receipts") {
                ForEach($items) { $item in
                    TaxCompilerRowView(item: $item, allowedBuckets: availableBuckets)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                try? FileManager.default.removeItem(at: item.imageURL)
                                if let index = items.firstIndex(where: { $0.id == item.id }) {
                                    items.remove(at: index)
                                }
                            }
                        }
                }
            }

            summarySection
        }
        .listStyle(.insetGrouped)
    }

    private var summarySection: some View {
        Section("Compilation Summary") {
            ForEach(availableBuckets) { bucket in
                let total = items.filter { $0.bucket == bucket }.reduce(0) { $0 + $1.amount }
                if total > 0 {
                    HStack {
                        Label(bucket.displayName, systemImage: bucket.systemImage)
                        Spacer()
                        Text(total, format: .currency(code: "USD"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            let grandTotal = items.reduce(0) { $0 + $1.amount }
            HStack {
                Text("Total Compiled").fontWeight(.bold)
                Spacer()
                Text(grandTotal, format: .currency(code: "USD"))
                    .fontWeight(.bold)
            }
        }
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
            guard let document = PDFDocument(url: url) else {
                if accessed { url.stopAccessingSecurityScopedResource() }
                continue
            }
            let pageCount = document.pageCount
            let filename = url.lastPathComponent

            for index in 0..<pageCount {
                let pageResult: (URL, [OCRResult], ReceiptData)? = await Task.detached(priority: .userInitiated) {
                    guard let page = document.page(at: index) else { return nil }
                    let image = page.thumbnail(of: CGSize(width: 1800, height: 2400), for: .mediaBox)
                    guard let cgImage = image.cgImage,
                          let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }

                    let tempDir = FileManager.default.temporaryDirectory
                    let fileURL = tempDir.appendingPathComponent("compiler-draft-\(UUID().uuidString).jpg")
                    do {
                        try imageData.write(to: fileURL)
                        let results = try await DocumentProcessor.shared.extractText(from: cgImage)
                        let receipt = DocumentProcessor.shared.parseReceipt(from: results)
                        return (fileURL, results, receipt)
                    } catch {
                        return nil
                    }
                }.value

                if let (fileURL, _, receipt) = pageResult {
                    items.append(
                        CompiledTaxItem(
                            sourceName: filename,
                            pageNumber: index + 1,
                            imageURL: fileURL,
                            receipt: receipt,
                            driverType: appState.driverType
                        )
                    )
                } else {
                    errorMessage = "Some PDF pages could not be read. You can retry those pages individually."
                }
                processedPages += 1
            }

            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        isProcessing = false
        if items.isEmpty && errorMessage == nil {
            errorMessage = "No readable receipt pages were found."
        }
    }

    private func exportExcel() {
        guard let url = generateExcelCSV() else {
            errorMessage = "Failed to generate Excel file."
            return
        }
        exportURL = url
        showingShareSheet = true
    }

    private func generateExcelCSV() -> URL? {
        guard !items.isEmpty else { return nil }
        
        var csv = "\u{FEFF}" // Excel UTF-8 BOM
        csv += "iTrucker - OCR Tax Compilation Backup Report\n"
        csv += "Driver:,\(appState.driverName.isEmpty ? "Owner-Operator" : appState.driverName)\n"
        csv += "Generated:,\(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n\n"
        
        csv += "Source Document,Page,Date,Category,Vendor,Cost,Business %,Deductible,DOT Meal Exemption Limit\n"
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        for item in items {
            let srcName = item.sourceName.replacingOccurrences(of: "\"", with: "\"\"")
            let vendor = item.vendorName.replacingOccurrences(of: "\"", with: "\"\"")
            let isMeal = item.bucket == .meals
            let deductible = isMeal ? item.amount * 0.8 : item.amount
            
            csv += "\"\(srcName)\","
            csv += "\(item.pageNumber),"
            csv += "\(df.string(from: item.date)),"
            csv += "\(item.bucket.displayName),"
            csv += "\"\(vendor)\","
            csv += String(format: "%.2f,", item.amount)
            csv += "100%," // Standalone compilation defaults to 100% business use
            csv += String(format: "%.2f,", deductible)
            csv += isMeal ? "80% (DOT Hours of Service)\n" : "100% (Standard)\n"
        }
        
        // Category Totals
        csv += "\nCategory,Total Cost,Total Deductible\n"
        for bucket in TaxBucket.allCases {
            let catItems = items.filter { $0.bucket == bucket }
            let totalCost = catItems.reduce(0) { $0 + $1.amount }
            if totalCost > 0 {
                let totalDeductible = bucket == .meals ? totalCost * 0.8 : totalCost
                csv += "\(bucket.displayName),"
                csv += String(format: "%.2f,", totalCost)
                csv += String(format: "%.2f\n", totalDeductible)
            }
        }
        
        // Grand Totals
        let grandCost = items.reduce(0) { $0 + $1.amount }
        var totalDed = 0.0
        for item in items {
            totalDed += item.bucket == .meals ? item.amount * 0.8 : item.amount
        }
        
        csv += "Total,"
        csv += String(format: "%.2f,", grandCost)
        csv += String(format: "%.2f\n", totalDed)
        
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "iTrucker-TaxCompilation-\(Quarter.current().id).csv"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try Data(csv.utf8).write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    private func saveToExpenses() {
        var duplicateCount = 0
        let existingFingerprints = Set(existingExpenses.map(\.receiptFingerprint))
        var stagedFingerprints = Set<String>()
        
        for item in items {
            let fingerprint = receiptFingerprint(vendor: item.vendorName, date: item.date, amount: item.amount)
            if !fingerprint.isEmpty && (existingFingerprints.contains(fingerprint) || stagedFingerprints.contains(fingerprint)) {
                duplicateCount += 1
                continue
            }
            if !fingerprint.isEmpty {
                stagedFingerprints.insert(fingerprint)
            }
            
            let expense = ExpenseEntry(
                category: item.bucket.rawValue,
                amount: item.amount,
                note: item.vendorName.isEmpty ? "Compiled PDF receipt" : item.vendorName,
                businessUsePercent: 100
            )
            expense.date = item.date
            expense.vendorName = item.vendorName
            expense.isVerified = true
            expense.receiptFingerprint = fingerprint
            expense.rawOCRText = item.rawOCRText
            expense.ocrConfidence = item.ocrConfidence
            
            if let imageData = try? Data(contentsOf: item.imageURL) {
                expense.receiptImageData = imageData
            }
            
            modelContext.insert(expense)
        }
        
        do {
            try modelContext.save()
            cleanUpDraftFiles()
            items.removeAll()
            if duplicateCount > 0 {
                errorMessage = "Saved the compiled receipts to expenses. Skipped \(duplicateCount) probable duplicate(s)."
            } else {
                dismiss()
            }
        } catch {
            errorMessage = "The compiled expenses could not be saved."
        }
    }

    private func receiptFingerprint(vendor: String, date: Date, amount: Double) -> String {
        guard amount > 0 else { return "" }
        let normalizedVendor = vendor.lowercased().filter { $0.isLetter || $0.isNumber }
        guard !normalizedVendor.isEmpty else { return "" }
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        return "\(normalizedVendor)|\(Int(day))|\(String(format: "%.2f", amount))"
    }

    private func cleanUpDraftFiles() {
        let fm = FileManager.default
        for item in items {
            try? fm.removeItem(at: item.imageURL)
        }
    }
}

struct TaxCompilerRowView: View {
    @Binding var item: CompiledTaxItem
    let allowedBuckets: [TaxBucket]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(item.sourceName) (p. \(item.pageNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if item.ocrConfidence > 0 {
                    Text("\(Int(item.ocrConfidence * 100))% OCR")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(item.ocrConfidence >= 0.75 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundStyle(item.ocrConfidence >= 0.75 ? .green : .orange)
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 8) {
                TextField("Vendor", text: $item.vendorName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Cost", value: $item.amount, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
            
            HStack {
                Picker("Category", selection: $item.bucket) {
                    ForEach(allowedBuckets) { b in
                        Text(b.displayName).tag(b)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
                .labelsHidden()
                
                Spacer()
                
                DatePicker("", selection: $item.date, displayedComponents: .date)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
