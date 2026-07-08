//
//  DispatcherSummaryView.swift
//  iTruckersCoDriver
//
//  Compact dispatcher view for iPhone. Shows what needs attention right now:
//  fleet alerts, unread driver messages, active loads, urgent maintenance.
//

import SwiftUI
import SwiftData

#if os(iOS)
struct DispatcherSummaryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DriverProfile.lastUpdated, order: .reverse) private var drivers: [DriverProfile]
    @Query(sort: \DispatchMessage.timestamp, order: .reverse) private var allMessages: [DispatchMessage]
    @Query(sort: \MaintenanceReport.timestamp, order: .reverse) private var reports: [MaintenanceReport]
    @Query private var trips: [TripRecord]
    @Query(sort: \LoadOpportunity.updatedAt, order: .reverse) private var loadOpportunities: [LoadOpportunity]

    @State private var selectedDriver: DriverProfile?
    @State private var replyText = ""
    @State private var showingThread = false

    private var unreadMessages: [DispatchMessage] {
        allMessages.filter { $0.isFromDriver && !$0.isRead }
    }
    private var urgentReports: [MaintenanceReport] {
        reports.filter(\.isUrgent)
    }
    private var activeTrips: [TripRecord] {
        trips.filter(\.isActive)
    }
    private var underpricedLoads: [LoadOpportunity] {
        loadOpportunities.filter { $0.needsBetterRate }
    }
    private var alertDrivers: [DriverProfile] {
        drivers.filter { $0.hasFatigueAlert || ($0.fuelLevel > 0 && $0.fuelLevel < 20) }
    }

    var body: some View {
        NavigationView {
            List {
                // Alerts banner
                if !alertDrivers.isEmpty || !urgentReports.isEmpty {
                    alertsSection
                }

                // Fleet status
                fleetSection

                // Unread messages
                if !unreadMessages.isEmpty {
                    messagesSection
                }

                // Active loads
                if !activeTrips.isEmpty {
                    loadsSection
                }

                if !loadOpportunities.isEmpty {
                    profitSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dispatch")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        DispatcherDashboardView()
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Full View", systemImage: "rectangle.expand.diagonal")
                    }
                }
            }
            .sheet(isPresented: $showingThread) {
                if let driver = selectedDriver {
                    MessageThreadSheet(driver: driver, allMessages: allMessages)
                }
            }
        }
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        Section {
            ForEach(alertDrivers) { driver in
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(driver.hasFatigueAlert ? .orange : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(driver.name).fontWeight(.semibold)
                        Text(driver.hasFatigueAlert ? "Fatigue alert" : "Low fuel — \(Int(driver.fuelLevel))%")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            ForEach(urgentReports.prefix(3)) { report in
                HStack(spacing: 12) {
                    Image(systemName: "wrench.fill").foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.issueDescription)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text("Safety issue · \(report.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Label("Needs Attention", systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }

    // MARK: - Fleet

    private var fleetSection: some View {
        Section {
            if drivers.isEmpty {
                Text("No drivers online yet.")
                    .foregroundColor(.secondary).font(.caption)
            } else {
                ForEach(drivers) { driver in
                    Button {
                        selectedDriver = driver
                        showingThread = true
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(statusColor(driver.dutyStatus))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(driver.name)
                                    .foregroundColor(.primary).fontWeight(.medium)
                                HStack(spacing: 8) {
                                    Text(driver.dutyStatus.displayName)
                                    if driver.driveTimeRemaining > 0 {
                                        Text("· \(formatInterval(driver.driveTimeRemaining)) drive left")
                                    }
                                }
                                .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            let unread = allMessages.filter {
                                $0.driverID == driver.driverID && $0.isFromDriver && !$0.isRead
                            }.count
                            if unread > 0 {
                                Text("\(unread)")
                                    .font(.caption2).fontWeight(.bold)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        } header: {
            Label("Fleet · \(drivers.count) driver\(drivers.count == 1 ? "" : "s")",
                  systemImage: "truck.box.fill")
        }
    }

    // MARK: - Messages

    private var messagesSection: some View {
        Section {
            ForEach(unreadMessages.prefix(5)) { message in
                Button {
                    selectedDriver = drivers.first { $0.driverID == message.driverID }
                    showingThread = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(drivers.first { $0.driverID == message.driverID }?.name ?? "Driver")
                                .fontWeight(.semibold).foregroundColor(.primary)
                            Spacer()
                            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Text(message.content)
                            .font(.caption).foregroundColor(.secondary).lineLimit(2)
                    }
                }
            }
        } header: {
            Label("\(unreadMessages.count) Unread", systemImage: "message.fill")
        }
    }

    // MARK: - Loads

    private var loadsSection: some View {
        Section {
            ForEach(activeTrips.prefix(5)) { trip in
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.destination.isEmpty ? "En route" : "\(trip.origin) → \(trip.destination)")
                        .fontWeight(.medium)
                    if trip.miles > 0 || trip.grossRevenue > 0 {
                        HStack(spacing: 12) {
                            if trip.miles > 0 {
                                Label(String(format: "%.0f mi", trip.miles), systemImage: "road.lanes")
                            }
                            if trip.grossRevenue > 0 {
                                Label(String(format: "$%.0f", trip.grossRevenue), systemImage: "dollarsign")
                            }
                        }
                        .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Label("\(activeTrips.count) Active Load\(activeTrips.count == 1 ? "" : "s")",
                  systemImage: "shippingbox.fill")
        }
    }

    private var profitSection: some View {
        Section {
            ForEach(loadOpportunities.prefix(5)) { opportunity in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(opportunity.loadNumber.isEmpty ? loadRoute(opportunity) : opportunity.loadNumber)
                            .fontWeight(.medium)
                        Spacer()
                        Text(String(format: "$%.2f/mi", opportunity.profitPerMile))
                            .font(.caption)
                            .foregroundColor(opportunity.needsBetterRate ? .orange : .green)
                    }
                    if opportunity.needsBetterRate {
                        Text("Ask at least \(formatCurrency(opportunity.minimumLinehaulRate)) linehaul")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("Projected profit \(formatCurrency(opportunity.projectedProfit))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Label("\(underpricedLoads.count) Rate Alert\(underpricedLoads.count == 1 ? "" : "s")",
                  systemImage: "dollarsign.arrow.circlepath")
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: DutyStatus) -> Color {
        switch status {
        case .offDuty:      return .gray
        case .sleeperBerth: return .purple
        case .driving:      return .green
        case .onDuty:       return .orange
        }
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private func loadRoute(_ opportunity: LoadOpportunity) -> String {
        if opportunity.origin.isEmpty && opportunity.destination.isEmpty {
            return "Load plan"
        }
        return "\(opportunity.origin.isEmpty ? "Origin TBD" : opportunity.origin) -> \(opportunity.destination.isEmpty ? "Destination TBD" : opportunity.destination)"
    }

    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

// MARK: - Message Thread Sheet

private struct MessageThreadSheet: View {
    let driver: DriverProfile
    let allMessages: [DispatchMessage]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var replyText = ""

    private var thread: [DispatchMessage] {
        allMessages.filter { $0.driverID == driver.driverID }
            .sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(thread) { msg in
                                HStack {
                                    if msg.isFromDriver { Spacer(minLength: 60) }
                                    VStack(alignment: msg.isFromDriver ? .trailing : .leading, spacing: 2) {
                                        Text(msg.isFromDriver ? driver.name : "Dispatch")
                                            .font(.caption2).foregroundColor(.secondary)
                                        Text(msg.content)
                                            .padding(10)
                                            .background(msg.isFromDriver
                                                ? Color.blue.opacity(0.15)
                                                : Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(12)
                                        Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2).foregroundColor(.secondary)
                                    }
                                    if !msg.isFromDriver { Spacer(minLength: 60) }
                                }
                                .id(msg.id)
                                .onAppear {
                                    if msg.isFromDriver && !msg.isRead {
                                        msg.isRead = true
                                        try? modelContext.save()
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: thread.count) {
                        if let last = thread.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()
                HStack(spacing: 10) {
                    TextField("Message \(driver.name)...", text: $replyText, axis: .vertical)
                        .lineLimit(1...4).padding(10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                    Button {
                        guard !replyText.isEmpty else { return }
                        let msg = DispatchMessage(
                            sender: "dispatch",
                            content: replyText,
                            driverID: driver.driverID
                        )
                        modelContext.insert(msg)
                        try? modelContext.save()
                        replyText = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(replyText.isEmpty ? .gray : .blue)
                    }
                    .disabled(replyText.isEmpty)
                }
                .padding()
            }
            .navigationTitle(driver.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
