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
            ZStack {
                Theme.background.ignoresSafeArea()
                
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
            }
            .navigationTitle("Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingReport = true } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingReport) { ReportIssueView() }
        }
        .colorScheme(.dark)
    }

    // MARK: - Schedule Tab

    private var scheduleView: some View {
        Group {
            if myItems.isEmpty {
                emptyMaintenanceView
            } else {
                List {
                    let overdue = myItems.filter(\.isOverdue)
                    let due = myItems.filter { $0.isDue && !$0.isOverdue }
                    let upcoming = myItems.filter { !$0.isDue }

                    if !overdue.isEmpty {
                        Section(header: Text("OVERDUE").font(Theme.Typography.caption(10)).foregroundColor(Theme.accent)) {
                            ForEach(overdue) { item in itemRow(item, status: .overdue) }
                        }
                    }
                    if !due.isEmpty {
                        Section(header: Text("DUE NOW").font(Theme.Typography.caption(10)).foregroundColor(Theme.warning)) {
                            ForEach(due) { item in itemRow(item, status: .due) }
                        }
                    }
                    if !upcoming.isEmpty {
                        Section(header: Text("UPCOMING").font(Theme.Typography.caption(10)).foregroundColor(Theme.textSecondary)) {
                            ForEach(upcoming) { item in itemRow(item, status: .ok) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private enum ItemStatus { case overdue, due, ok }

    private func itemRow(_ item: MaintenanceItem, status: ItemStatus) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill((status == .overdue ? Theme.accent : status == .due ? Theme.warning : Theme.success).opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: item.categoryIcon)
                    .foregroundColor(status == .overdue ? Theme.accent : status == .due ? Theme.warning : Theme.success)
                    .font(.system(size: 16, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemDescription)
                    .font(Theme.Typography.body())
                    .fontWeight(.bold)
                
                if let next = item.nextDueDate {
                    Text("Next: \(next.formatted(date: .abbreviated, time: .omitted))")
                        .font(Theme.Typography.caption())
                        .foregroundColor(Theme.textSecondary)
                } else if item.intervalMiles > 0 {
                    let remaining = item.intervalMiles - (item.currentOdometer - item.lastServiceMiles)
                    Text(remaining > 0 ? "Due in \(Int(remaining)) miles" : "OVERDUE")
                        .font(Theme.Typography.caption())
                        .foregroundColor(remaining > 0 ? Theme.textSecondary : Theme.accent)
                }
            }
            Spacer()
            
            if status != .ok {
                Image(systemName: status == .overdue ? "exclamationmark.circle.fill" : "clock.fill")
                    .foregroundColor(status == .overdue ? Theme.accent : Theme.warning)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.white.opacity(0.05))
        .listRowSeparatorTint(Color.white.opacity(0.1))
    }

    // MARK: - Reports Tab

    private var reportsView: some View {
        Group {
            if myReports.isEmpty {
                emptyReportsView
            } else {
                List(myReports) { report in 
                    reportRow(report)
                        .listRowBackground(Color.white.opacity(0.05))
                        .listRowSeparatorTint(Color.white.opacity(0.1))
                }
                .listStyle(.plain)
            }
        }
    }

    private func reportRow(_ report: MaintenanceReport) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(report.severity == "high" ? Theme.accent : report.severity == "medium" ? Theme.warning : Color.yellow)
                .frame(width: 10, height: 10)
                .shadow(color: (report.severity == "high" ? Theme.accent : report.severity == "medium" ? Theme.warning : Color.yellow).opacity(0.5), radius: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(report.issueDescription)
                    .font(Theme.Typography.body())
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    Text(report.timestamp.formatted(date: .abbreviated, time: .shortened))
                    Text("•")
                    Text(report.severity.uppercased())
                }
                .font(Theme.Typography.caption())
                .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            
            if report.resolved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.success)
            }
        }
        .padding(.vertical, 8)
    }

    private var emptyMaintenanceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 60))
                .foregroundColor(Color.white.opacity(0.1))
            Text("No Maintenance Items")
                .font(Theme.Typography.title(20))
            Text("Scheduled items will appear here.")
                .font(Theme.Typography.body())
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var emptyReportsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(Color.white.opacity(0.1))
            Text("No Reports")
                .font(Theme.Typography.title(20))
            Text("Report issues using the button in the top right.")
                .font(Theme.Typography.body())
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
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
