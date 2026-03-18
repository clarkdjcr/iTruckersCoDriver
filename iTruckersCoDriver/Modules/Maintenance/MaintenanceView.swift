//
//  MaintenanceView.swift
//  iTruckersCoDriver
//
//  iOS maintenance tab: scheduled items + driver issue reports.
//

import SwiftUI
import SwiftData

#if os(iOS)
struct MaintenanceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [MaintenanceItem]
    @Query(sort: \MaintenanceReport.timestamp, order: .reverse) private var allReports: [MaintenanceReport]

    @State private var showingReport = false
    @State private var selectedTab = 0

    private var myItems: [MaintenanceItem] {
        allItems.filter { $0.driverID == appState.driverID && $0.isActive }
    }
    private var myReports: [MaintenanceReport] {
        allReports.filter { $0.driverID == appState.driverID }
    }
    var overdueCount: Int { myItems.filter(\.isOverdue).count }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    Text("Schedule").tag(0)
                    Text("Reports").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case 0: scheduleView
                default: reportsView
                }
            }
            .navigationTitle("Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingReport = true } label: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
            }
            .sheet(isPresented: $showingReport) { ReportIssueView() }
        }
    }

    // MARK: - Schedule Tab

    private var scheduleView: some View {
        Group {
            if myItems.isEmpty {
                ContentUnavailableView(
                    "No Maintenance Items",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Scheduled maintenance items will appear here.")
                )
            } else {
                List {
                    let overdue = myItems.filter(\.isOverdue)
                    let due = myItems.filter { $0.isDue && !$0.isOverdue }
                    let upcoming = myItems.filter { !$0.isDue }

                    if !overdue.isEmpty {
                        Section(header: Label("Overdue", systemImage: "exclamationmark.triangle.fill").foregroundColor(.red)) {
                            ForEach(overdue) { item in itemRow(item, status: .overdue) }
                        }
                    }
                    if !due.isEmpty {
                        Section(header: Label("Due Now", systemImage: "clock.fill").foregroundColor(.orange)) {
                            ForEach(due) { item in itemRow(item, status: .due) }
                        }
                    }
                    if !upcoming.isEmpty {
                        Section("Upcoming") {
                            ForEach(upcoming) { item in itemRow(item, status: .ok) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private enum ItemStatus { case overdue, due, ok }

    private func itemRow(_ item: MaintenanceItem, status: ItemStatus) -> some View {
        HStack {
            Image(systemName: item.categoryIcon)
                .foregroundColor(status == .overdue ? .red : status == .due ? .orange : .green)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemDescription).fontWeight(.medium)
                if let next = item.nextDueDate {
                    Text("Next: \(next.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundColor(.secondary)
                } else if item.intervalMiles > 0 {
                    let remaining = item.intervalMiles - (item.currentOdometer - item.lastServiceMiles)
                    Text(remaining > 0 ? "Due in \(Int(remaining)) miles" : "OVERDUE")
                        .font(.caption)
                        .foregroundColor(remaining > 0 ? .secondary : .red)
                }
            }
            Spacer()
            switch status {
            case .overdue: Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
            case .due: Image(systemName: "clock.fill").foregroundColor(.orange)
            case .ok: EmptyView()
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Reports Tab

    private var reportsView: some View {
        Group {
            if myReports.isEmpty {
                ContentUnavailableView(
                    "No Reports",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Tap the warning button to report a maintenance issue.")
                )
            } else {
                List(myReports) { report in reportRow(report) }
                    .listStyle(.insetGrouped)
            }
        }
    }

    private func reportRow(_ report: MaintenanceReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(report.severity == "high" ? Color.red : report.severity == "medium" ? Color.orange : Color.yellow)
                    .frame(width: 8, height: 8)
                Text(report.issueDescription).fontWeight(.medium)
                Spacer()
                if report.resolved {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                }
            }
            Text(report.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption).foregroundColor(.secondary)
            Text("Severity: \(report.severity.capitalized)")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Report Issue Sheet

struct ReportIssueView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    @State private var severity = "medium"

    var body: some View {
        NavigationView {
            Form {
                Section("Issue Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
                Section("Severity") {
                    Picker("Severity", selection: $severity) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High — Safety Issue").tag("high")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let report = MaintenanceReport(
                            driverID: appState.driverID,
                            description: description,
                            severity: severity
                        )
                        modelContext.insert(report)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(description.isEmpty)
                }
            }
        }
    }
}
#endif
