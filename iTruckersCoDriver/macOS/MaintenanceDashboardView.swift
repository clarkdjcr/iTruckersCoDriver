//
//  MaintenanceDashboardView.swift
//  iTruckersCoDriver
//
//  macOS: Fleet-wide maintenance grid — overdue items highlighted,
//  urgent driver reports surfaced, full repair history.
//

import SwiftUI
import SwiftData

#if os(macOS)
struct MaintenanceDashboardView: View {
    @Query(sort: \MaintenanceReport.timestamp, order: .reverse) private var allReports: [MaintenanceReport]
    @Query private var allItems: [MaintenanceItem]
    @Query(sort: \DriverProfile.name) private var drivers: [DriverProfile]

    @State private var selectedDriverID: String? = nil

    private var filteredReports: [MaintenanceReport] {
        guard let id = selectedDriverID else { return allReports }
        return allReports.filter { $0.driverID == id }
    }

    private var filteredItems: [MaintenanceItem] {
        let active = allItems.filter(\.isActive)
        guard let id = selectedDriverID else { return active }
        return active.filter { $0.driverID == id }
    }

    var body: some View {
        HSplitView {
            // Driver filter
            VStack(alignment: .leading, spacing: 0) {
                Text("Filter by Driver")
                    .font(.headline).padding()
                Divider()
                List(selection: $selectedDriverID) {
                    Text("All Drivers").tag(nil as String?)
                    ForEach(drivers) { d in
                        Text(d.name).tag(d.driverID as String?)
                    }
                }
            }
            .frame(minWidth: 140, maxWidth: 180)

            // Main content
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Fleet Maintenance")
                        .font(.largeTitle).fontWeight(.bold)
                    Spacer()
                    let urgentCount = filteredReports.filter(\.isUrgent).count
                    if urgentCount > 0 {
                        Label("\(urgentCount) urgent", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                .padding()
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Urgent reports
                        let urgent = filteredReports.filter(\.isUrgent)
                        if !urgent.isEmpty {
                            sectionBlock(title: "Urgent Issues", icon: "exclamationmark.triangle.fill", color: .red) {
                                ForEach(urgent) { reportRow($0) }
                            }
                        }

                        // Overdue maintenance items
                        let overdue = filteredItems.filter(\.isOverdue)
                        if !overdue.isEmpty {
                            sectionBlock(title: "Overdue Maintenance", icon: "clock.badge.exclamationmark", color: .orange) {
                                ForEach(overdue) { itemRow($0) }
                            }
                        }

                        // All reports
                        sectionBlock(title: "All Reports", icon: "doc.text", color: .primary) {
                            if filteredReports.isEmpty {
                                Text("No reports filed.").foregroundColor(.secondary)
                            } else {
                                ForEach(filteredReports) { reportRow($0) }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    @ViewBuilder
    private func sectionBlock<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline).foregroundColor(color)
            content()
        }
    }

    private func reportRow(_ report: MaintenanceReport) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(report.severity == "high" ? Color.red : report.severity == "medium" ? Color.orange : Color.yellow)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                Text(report.issueDescription).fontWeight(.medium)
                Text(report.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if report.resolved {
                Label("Resolved", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green).font(.caption)
            } else {
                Text(report.severity.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(report.severity == "high" ? Color.red.opacity(0.15) : Color.orange.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    private func itemRow(_ item: MaintenanceItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.categoryIcon)
                .foregroundColor(.orange).frame(width: 20)
            VStack(alignment: .leading) {
                Text(item.itemDescription).fontWeight(.medium)
                if !item.vehicleID.isEmpty {
                    Text("Vehicle: \(item.vehicleID)").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text("OVERDUE").font(.caption).fontWeight(.bold).foregroundColor(.red)
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}
#endif
