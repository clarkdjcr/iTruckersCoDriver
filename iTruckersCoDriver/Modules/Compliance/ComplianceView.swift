//
//  ComplianceView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI
import SwiftData

#if os(iOS)
struct ComplianceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TripRecord.startDate, order: .reverse) private var trips: [TripRecord]
    @Query(sort: \HOSEntry.timestamp, order: .reverse) private var hosEntries: [HOSEntry]
    @Query(sort: \ExpenseEntry.date, order: .reverse) private var expenses: [ExpenseEntry]
    @State private var showingNewTrip = false
    @State private var showingAddExpense = false
    @State private var showingBatchReceiptImport = false
    @State private var exportItems: [Any] = []
    @State private var showingFileShare = false
    @State private var receiptToView: ReceiptImage?
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack {
                Picker("Section", selection: $selectedTab) {
                    Text("Trips").tag(0)
                    Text("IFTA").tag(1)
                    Text("Expenses").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedTab {
                case 0: tripsView
                case 1: iftaView
                default: expensesView
                }
            }
            .navigationTitle("Compliance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Expense", systemImage: "plus.circle") { showingAddExpense = true }
                        Button("Import Receipt PDFs", systemImage: "doc.on.doc") { showingBatchReceiptImport = true }
                        Button("New Trip", systemImage: "plus") { showingNewTrip = true }

                        Menu("Tax Report (PDF)") {
                            ForEach(Quarter.recent(count: 5)) { q in
                                Button(q.label) { exportTaxReportPDF(q) }
                            }
                        }
                        Menu("Expenses (CSV)") {
                            ForEach(Quarter.recent(count: 5)) { q in
                                Button(q.label) { exportExpensesCSV(q) }
                            }
                        }

                        Menu("IFTA Mileage (CSV)") {
                            ForEach(Quarter.recent(count: 5)) { q in
                                Button(q.label) { exportIFTA(q) }
                            }
                        }
                        Menu("HOS Log (CSV)") {
                            ForEach(Quarter.recent(count: 5)) { q in
                                Button(q.label) { exportHOS(q) }
                            }
                        }
                        NavigationLink(destination: DocumentView()) {
                            Label("Forms & Documents", systemImage: "folder.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingNewTrip) { NewTripView() }
            .sheet(isPresented: $showingAddExpense) { AddExpenseView() }
            .sheet(isPresented: $showingBatchReceiptImport) { BatchReceiptImportView() }
            .sheet(isPresented: $showingFileShare) {
                ShareSheet(items: exportItems)
            }
            .sheet(item: $receiptToView) { item in
                ReceiptViewer(image: item.image)
            }
        }
    }

    // MARK: - Trips view

    private var tripsView: some View {
        Group {
            if trips.isEmpty {
                ContentUnavailableView("No Trips Yet", systemImage: "truck.box", description: Text("Start a new trip to track miles, revenue, and fuel."))
            } else {
                List {
                    ForEach(trips) { trip in
                        tripRow(trip)
                    }
                    .onDelete { indexSet in
                        for index in indexSet { modelContext.delete(trips[index]) }
                        try? modelContext.save()
                    }
                }
                .listStyle(.insetGrouped)

                // Summary footer
                summaryCard
                    .padding()
            }
        }
    }

    private func tripRow(_ trip: TripRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trip.destination.isEmpty ? "In Progress" : trip.destination)
                    .fontWeight(.semibold)
                Spacer()
                if trip.isActive {
                    Text("ACTIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }
            Text("\(trip.origin) → \(trip.destination)")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Label(String(format: "%.0f mi", trip.miles), systemImage: "road.lanes")
                Spacer()
                Label(formatCurrency(trip.grossRevenue), systemImage: "dollarsign")
                Spacer()
                Label(String(format: "%.0f gal", trip.fuelGallons), systemImage: "fuelpump")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var summaryCard: some View {
        let totalMiles = trips.reduce(0) { $0 + $1.miles }
        let totalRevenue = trips.reduce(0) { $0 + $1.grossRevenue }
        let totalFuel = trips.reduce(0) { $0 + $1.fuelGallons }
        let avgMPG = totalFuel > 0 ? totalMiles / totalFuel : 0

        return HStack {
            VStack {
                Text(String(format: "%.0f", totalMiles))
                    .font(.headline)
                Text("Total Miles")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack {
                Text(formatCurrency(totalRevenue))
                    .font(.headline)
                Text("Revenue")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack {
                Text(String(format: "%.1f", avgMPG))
                    .font(.headline)
                Text("Avg MPG")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - IFTA view

    private var iftaView: some View {
        let stateTotals = TripRecord.aggregateStateMileage(trips)

        return Group {
            if stateTotals.isEmpty {
                ContentUnavailableView("No IFTA Data", systemImage: "map", description: Text("State mileage will appear here as you log trips."))
            } else {
                List {
                    Section("State Mileage (Current Quarter)") {
                        ForEach(stateTotals.sorted(by: { $0.key < $1.key }), id: \.key) { state, miles in
                            HStack {
                                Text(state).fontWeight(.medium)
                                Spacer()
                                Text(String(format: "%.0f miles", miles))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Expenses view

    private var expensesView: some View {
        let byBucket = ExpenseEntry.deductibleByBucket(expenses)
        let grandDeductible = expenses.reduce(0) { $0 + $1.deductibleAmount }

        return Group {
            if expenses.isEmpty {
                ContentUnavailableView {
                    Label("No Expenses", systemImage: "receipt")
                } description: {
                    Text("Add a receipt or expense to start tracking deductions.")
                } actions: {
                    Button("Add Expense") { showingAddExpense = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    Section("Deductible by Category") {
                        ForEach(TaxBucket.allCases) { bucket in
                            let total = byBucket[bucket] ?? 0
                            if total > 0 {
                                HStack {
                                    Label(bucket.displayName, systemImage: bucket.systemImage)
                                    Spacer()
                                    Text(formatCurrency(total)).foregroundColor(.secondary)
                                }
                            }
                        }
                        HStack {
                            Text("Total Deductible").fontWeight(.semibold)
                            Spacer()
                            Text(formatCurrency(grandDeductible)).fontWeight(.semibold)
                        }
                    }
                    Section("All Expenses") {
                        ForEach(expenses) { expense in
                            expenseRow(expense)
                                .contentShape(Rectangle())
                                .onTapGesture { openReceipt(expense) }
                        }
                        .onDelete { indexSet in
                            for index in indexSet { modelContext.delete(expenses[index]) }
                            try? modelContext.save()
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func expenseRow(_ expense: ExpenseEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if expense.hasReceipt {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(expense.note.isEmpty ? expense.bucket.displayName : expense.note)
                }
                Text("\(expense.bucket.displayName) · \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(expense.amount))
                if expense.businessUsePercent < 100 {
                    Text("\(Int(expense.businessUsePercent))% → \(formatCurrency(expense.deductibleAmount))")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Export actions

    private func exportHOS(_ quarter: Quarter) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let entries = hosEntries
            .filter { quarter.contains($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
        var csv = "Timestamp,Duty Status,Location,Notes\n"
        for entry in entries {
            let note = entry.notes.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(formatter.string(from: entry.timestamp)),"
            csv += "\(entry.dutyStatus.displayName),"
            csv += "\"\(entry.locationName)\",\"\(note)\"\n"
        }
        guard let url = try? ExpenseReport.textFile(csv, filename: "iTrucker-HOS-\(quarter.id).csv") else { return }
        exportItems = [url]
        showingFileShare = true
    }

    private func exportIFTA(_ quarter: Quarter) {
        let qTrips = trips.filter { quarter.contains($0.startDate) }
        let stateTotals = TripRecord.aggregateStateMileage(qTrips)
        var csv = "State,Miles\n"
        for (state, miles) in stateTotals.sorted(by: { $0.key < $1.key }) {
            csv += "\(state),\(String(format: "%.1f", miles))\n"
        }
        guard let url = try? ExpenseReport.textFile(csv, filename: "iTrucker-IFTA-\(quarter.id).csv") else { return }
        exportItems = [url]
        showingFileShare = true
    }

    private func openReceipt(_ expense: ExpenseEntry) {
        guard let data = expense.receiptImageData, let image = UIImage(data: data) else { return }
        receiptToView = ReceiptImage(image: image)
    }

    private func exportTaxReportPDF(_ quarter: Quarter) {
        guard let url = try? ExpenseReport.pdfFile(expenses, quarter: quarter, driverName: appState.driverName) else { return }
        exportItems = [url]
        showingFileShare = true
    }

    private func exportExpensesCSV(_ quarter: Quarter) {
        guard let url = try? ExpenseReport.csvFile(expenses, quarter: quarter, driverName: appState.driverName) else { return }
        exportItems = [url]
        showingFileShare = true
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - New trip sheet

struct NewTripView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var origin = ""
    @State private var destination = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Trip Details") {
                    TextField("Origin (city, state)", text: $origin)
                    TextField("Destination (city, state)", text: $destination)
                }
                Section {
                    HStack {
                        Image(systemName: "info.circle").foregroundColor(.blue)
                        Text("Fixed cost $\(String(format: "%.2f", appState.fixedCostPerMile))/mile will be used for profit calculations. Adjust in Settings.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let trip = TripRecord(
                            origin: origin,
                            destination: destination,
                            fixedCosts: appState.fixedCostPerMile
                        )
                        modelContext.insert(trip)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(origin.isEmpty)
                }
            }
        }
    }
}

// MARK: - Receipt viewer

/// Identifiable wrapper so a tapped receipt image can drive a `.sheet(item:)`.
struct ReceiptImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Full-screen viewer for an attached receipt, with a share option.
struct ReceiptViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("Receipt", image: Image(uiImage: image))) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    /// Share plain text (e.g. an HOS log).
    init(text: String) { self.activityItems = [text] }

    /// Share arbitrary items — typically a generated file URL (PDF/CSV) so the
    /// user can route it to email, Dropbox, Google Drive, Files, AirDrop, etc.
    init(items: [Any]) { self.activityItems = items }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
