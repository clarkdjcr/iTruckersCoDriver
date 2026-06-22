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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TripRecord.startDate, order: .reverse) private var trips: [TripRecord]
    @Query(sort: \HOSEntry.timestamp, order: .reverse) private var hosEntries: [HOSEntry]
    @State private var showingNewTrip = false
    @State private var showingExport = false
    @State private var exportText = ""
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
                        Button("New Trip", systemImage: "plus") { showingNewTrip = true }
                        Button("Export HOS Log", systemImage: "square.and.arrow.up") { exportHOS() }
                        Button("Export IFTA", systemImage: "square.and.arrow.up") { exportIFTA() }
                        NavigationLink(destination: DocumentView()) {
                            Label("Forms & Documents", systemImage: "folder.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingNewTrip) { NewTripView() }
            .sheet(isPresented: $showingExport) {
                ShareSheet(text: exportText)
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
        let allExpenses: [ExpenseEntry] = (try? modelContext.fetch(FetchDescriptor<ExpenseEntry>())) ?? []
        let categoryTotals = ExpenseEntry.totalsByCategory(allExpenses)

        return Group {
            if allExpenses.isEmpty {
                ContentUnavailableView("No Expenses", systemImage: "receipt", description: Text("Ask Co-Driver to log expenses or add them here."))
            } else {
                List {
                    Section("By Category") {
                        ForEach(categoryTotals.sorted(by: { $0.key < $1.key }), id: \.key) { category, total in
                            HStack {
                                Text(category.capitalized)
                                Spacer()
                                Text(formatCurrency(total))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Section("All Expenses") {
                        ForEach(allExpenses.sorted(by: { $0.date > $1.date })) { expense in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(expense.note.isEmpty ? expense.category.capitalized : expense.note)
                                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(expense.amount))
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Export actions

    private func exportHOS() {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        var log = "HOS LOG — Exported \(formatter.string(from: Date()))\n"
        log += String(repeating: "=", count: 40) + "\n"
        for entry in hosEntries.reversed() {
            log += "\(formatter.string(from: entry.timestamp)) | \(entry.dutyStatus.displayName)"
            if !entry.locationName.isEmpty { log += " @ \(entry.locationName)" }
            log += "\n"
        }
        exportText = log
        showingExport = true
    }

    private func exportIFTA() {
        var csv = "State,Miles\n"
        let stateTotals = TripRecord.aggregateStateMileage(trips)
        for (state, miles) in stateTotals.sorted(by: { $0.key < $1.key }) {
            csv += "\(state),\(String(format: "%.1f", miles))\n"
        }
        exportText = csv
        showingExport = true
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

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
