//
//  DispatcherDashboardView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI
import SwiftData

struct DispatcherDashboardView: View {
    @EnvironmentObject var dispatcherState: DispatcherState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DispatchMessage.timestamp, order: .forward) private var allMessages: [DispatchMessage]
    @Query(sort: \DriverProfile.lastUpdated, order: .reverse) private var driverProfiles: [DriverProfile]
    @Query private var trips: [TripRecord]
    @Query(sort: \CommunicationLog.timestamp, order: .reverse) private var commLogs: [CommunicationLog]
    @Query(sort: \MaintenanceReport.timestamp, order: .reverse) private var maintReports: [MaintenanceReport]
    @Query private var loadOpportunities: [LoadOpportunity]

    @State private var selectedSidebar: SidebarItem? = .fleet
    @State private var selectedDriverProfile: DriverProfile?
    @State private var newMessageText = ""

    enum SidebarItem: String, CaseIterable, Identifiable {
        case fleet = "Fleet"
        case messages = "Messages"
        case communications = "Communications"
        case loads = "Loads"
        case profit = "Profit"
        case compliance = "Compliance"
        case maintenance = "Maintenance"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .fleet:          return "truck.box.fill"
            case .messages:       return "message.fill"
            case .communications: return "phone.bubble.fill"
            case .loads:          return "shippingbox.fill"
            case .profit:         return "dollarsign.arrow.circlepath"
            case .compliance:     return "doc.badge.checkmark"
            case .maintenance:    return "wrench.and.screwdriver.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationTitle("iTrucker Dispatcher")
        #if os(macOS)
        .frame(minWidth: 960, minHeight: 620)
        #endif
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(SidebarItem.allCases, selection: $selectedSidebar) { item in
            Label(item.rawValue, systemImage: item.icon)
                .tag(item)
                .badge(badgeCount(for: item))
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 170, ideal: 210, max: 250)
    }

    private func badgeCount(for item: SidebarItem) -> Int {
        switch item {
        case .messages:    return allMessages.filter { !$0.isRead && $0.isFromDriver }.count
        case .maintenance: return maintReports.filter(\.isUrgent).count
        case .profit:      return loadOpportunities.filter { $0.needsBetterRate }.count
        default:           return 0
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedSidebar {
        case .fleet:          fleetView
        case .messages:       messagesView
        case .communications: communicationsView
        case .loads:          loadsView
        case .profit:         ProfitPlannerView()
        case .compliance:     complianceDetailView
        case .maintenance:    MaintenanceDashboardView()
        case nil:             fleetView
        }
    }

    // MARK: - Fleet view

    private var fleetView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Fleet Status")
                    .font(.largeTitle).fontWeight(.bold)
                Spacer()
                Text("\(driverProfiles.count) driver\(driverProfiles.count == 1 ? "" : "s") online")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding()
            Divider()
            if driverProfiles.isEmpty {
                ContentUnavailableView(
                    "No Drivers Online",
                    systemImage: "truck.box",
                    description: Text("Drivers will appear here once they open the app on their device.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(driverProfiles) { profile in
                            driverCard(profile)
                                .onTapGesture {
                                    selectedDriverProfile = profile
                                    selectedSidebar = .messages
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func driverCard(_ profile: DriverProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(statusColor(profile.dutyStatus)).frame(width: 10, height: 10)
                Text(profile.name).fontWeight(.semibold)
                Spacer()
                Text(profile.dutyStatus.displayName)
                    .font(.caption).foregroundColor(statusColor(profile.dutyStatus))
            }
            Divider()
            if !profile.locationName.isEmpty {
                Label(profile.locationName, systemImage: "location.fill")
                    .font(.caption).foregroundColor(.secondary)
            }
            Label("Drive time: \(formatInterval(profile.driveTimeRemaining))", systemImage: "clock")
                .font(.caption).foregroundColor(.secondary)
            // Telematics row
            if profile.speedMPH > 0 || profile.fuelLevel > 0 {
                HStack(spacing: 12) {
                    if profile.speedMPH > 0 {
                        Label("\(Int(profile.speedMPH)) mph", systemImage: "speedometer")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    if profile.fuelLevel > 0 {
                        Label("\(Int(profile.fuelLevel))% fuel", systemImage: "fuelpump.fill")
                            .font(.caption2)
                            .foregroundColor(profile.fuelLevel < 20 ? .red : .secondary)
                    }
                    if profile.estimatedRange > 0 {
                        Label("\(Int(profile.estimatedRange)) mi range", systemImage: "road.lanes")
                            .font(.caption2)
                            .foregroundColor(profile.estimatedRange < 50 ? .orange : .secondary)
                    }
                }
            }
            // Low fuel badge
            if profile.fuelLevel > 0 && profile.fuelLevel < 20 {
                Label("Low Fuel", systemImage: "fuelpump.exclamationmark.fill")
                    .font(.caption).fontWeight(.bold).foregroundColor(.red)
            }
            // Fatigue alert
            if profile.hasFatigueAlert {
                Label("Fatigue Alert", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).fontWeight(.bold).foregroundColor(.orange)
            }
            if !profile.currentLoadNumber.isEmpty {
                Label(profile.currentLoadNumber, systemImage: "shippingbox")
                    .font(.caption).foregroundColor(.secondary)
            }
            Text("Updated \(profile.lastUpdated.formatted(date: .omitted, time: .shortened))")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding()
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(UIColor.secondarySystemBackground))
        #endif
        .cornerRadius(12).shadow(radius: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedDriverProfile?.driverID == profile.driverID ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - Messages view

    private var threadMessages: [DispatchMessage] {
        guard let driver = selectedDriverProfile else { return allMessages }
        return allMessages.filter { $0.driverID == driver.driverID }
    }

    private var messagesView: some View {
        #if os(macOS)
        HSplitView {
            driverListColumn
            messageThreadColumn
        }
        #else
        HStack(spacing: 0) {
            driverListColumn.frame(width: 220)
            Divider()
            messageThreadColumn
        }
        #endif
    }

    private var driverListColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Drivers").font(.headline).padding()
            Divider()
            List(driverProfiles, selection: $selectedDriverProfile) { profile in
                HStack {
                    Circle().fill(statusColor(profile.dutyStatus)).frame(width: 8, height: 8)
                    Text(profile.name)
                    Spacer()
                    let unread = allMessages.filter {
                        $0.driverID == profile.driverID && $0.isFromDriver && !$0.isRead
                    }.count
                    if unread > 0 {
                        Text("\(unread)").font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.blue).foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .tag(profile as DriverProfile?)
            }
            if driverProfiles.isEmpty {
                Text("No drivers yet").font(.caption).foregroundColor(.secondary).padding()
            }
        }
        .frame(minWidth: 160, maxWidth: 220)
    }

    private var messageThreadColumn: some View {
        VStack(spacing: 0) {
            HStack {
                if let driver = selectedDriverProfile {
                    Text(driver.name).font(.headline)
                } else {
                    Text("Select a driver").font(.headline).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            Divider()
            if selectedDriverProfile == nil {
                ContentUnavailableView("No Driver Selected", systemImage: "message",
                    description: Text("Select a driver to view their messages."))
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(threadMessages) { message in
                                macMessageBubble(message).id(message.id)
                                    .onAppear {
                                        if message.isFromDriver && !message.isRead {
                                            message.isRead = true
                                            try? modelContext.save()
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: threadMessages.count) {
                        if let last = threadMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                Divider()
                HStack {
                    TextField("Message driver...", text: $newMessageText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { sendDispatchMessage() }
                    Button("Send", action: sendDispatchMessage)
                        .disabled(newMessageText.isEmpty || selectedDriverProfile == nil)
                }
                .padding()
            }
        }
    }

    private func macMessageBubble(_ message: DispatchMessage) -> some View {
        HStack {
            if message.isFromDriver { Spacer() }
            VStack(alignment: message.isFromDriver ? .trailing : .leading, spacing: 2) {
                Text(message.isFromDriver ? "Driver" : "Dispatch")
                    .font(.caption2).foregroundColor(.secondary)
                Text(message.content)
                    .padding(8)
                    .background(message.isFromDriver ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                    .cornerRadius(8)
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundColor(.secondary)
            }
            if !message.isFromDriver { Spacer() }
        }
    }

    private func sendDispatchMessage() {
        guard !newMessageText.isEmpty, let driver = selectedDriverProfile else { return }
        let msg = DispatchMessage(sender: "dispatch", content: newMessageText, driverID: driver.driverID)
        modelContext.insert(msg)
        try? modelContext.save()
        newMessageText = ""
    }

    // MARK: - Communications view (customer comms log)

    private var communicationsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Customer Communications")
                .font(.largeTitle).fontWeight(.bold).padding()
            Divider()
            if commLogs.isEmpty {
                ContentUnavailableView(
                    "No Communications",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Driver-to-customer communications will appear here.")
                )
            } else {
                List(commLogs) { log in
                    HStack(spacing: 12) {
                        Image(systemName: log.isOutbound ? "arrow.up.right" : "arrow.down.left")
                            .foregroundColor(log.isOutbound ? .blue : .green)
                        VStack(alignment: .leading) {
                            HStack {
                                Text(log.contactName).fontWeight(.medium)
                                if !log.loadNumber.isEmpty {
                                    Text("· \(log.loadNumber)").foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(log.channel.capitalized)
                                    .font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1)).cornerRadius(4)
                            }
                            Text(log.content).font(.caption).foregroundColor(.secondary).lineLimit(2)
                            Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        if log.confirmed {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Loads view

    private var activeTrips: [TripRecord] { trips.filter(\.isActive) }
    private var completedTrips: [TripRecord] { trips.filter { !$0.isActive } }

    private var loadsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Loads").font(.largeTitle).fontWeight(.bold)
                Spacer()
                Text("\(activeTrips.count) active · \(completedTrips.count) completed")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding()
            Divider()

            if trips.isEmpty {
                ContentUnavailableView(
                    "No Loads Yet",
                    systemImage: "shippingbox",
                    description: Text("Trips started by drivers will appear here.")
                )
            } else {
                List {
                    if !activeTrips.isEmpty {
                        Section("Active") {
                            ForEach(activeTrips) { trip in tripRow(trip) }
                        }
                    }
                    if !completedTrips.isEmpty {
                        Section("Completed") {
                            ForEach(completedTrips.prefix(50)) { trip in tripRow(trip) }
                        }
                    }
                }
            }
        }
    }

    private func tripRow(_ trip: TripRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trip.destination.isEmpty ? "Destination TBD" : "\(trip.origin) → \(trip.destination)")
                    .fontWeight(.semibold)
                Spacer()
                Text(trip.isActive ? "Active" : "Completed")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(trip.isActive ? .white : .secondary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(trip.isActive ? Color.green : Color.clear)
                    .cornerRadius(4)
            }
            HStack(spacing: 20) {
                Label(trip.startDate.formatted(date: .abbreviated, time: .omitted),
                      systemImage: "calendar")
                if trip.miles > 0 {
                    Label(String(format: "%.0f mi", trip.miles), systemImage: "road.lanes")
                }
                if trip.grossRevenue > 0 {
                    let fmt = NumberFormatter()
                    let _ = { fmt.numberStyle = .currency }()
                    Label(fmt.string(from: NSNumber(value: trip.grossRevenue)) ?? "$0",
                          systemImage: "dollarsign")
                }
                if trip.grossRevenue > 0 && trip.miles > 0 {
                    let fmt = NumberFormatter()
                    let _ = { fmt.numberStyle = .currency }()
                    Label((fmt.string(from: NSNumber(value: trip.profit)) ?? "$0") + " profit",
                          systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundColor(trip.profit >= 0 ? .green : .red)
                }
            }
            .font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Compliance summary

    private var complianceDetailView: some View {
        VStack(alignment: .leading) {
            Text("Fleet Compliance Summary").font(.largeTitle).fontWeight(.bold).padding()
            Divider()
            if !driverProfiles.isEmpty {
                List(driverProfiles) { profile in
                    HStack {
                        Circle().fill(statusColor(profile.dutyStatus)).frame(width: 8, height: 8)
                        Text(profile.name)
                        Spacer()
                        Text(profile.dutyStatus.displayName).foregroundColor(.secondary)
                        Text(formatInterval(profile.driveTimeRemaining) + " remaining")
                            .font(.caption)
                            .foregroundColor(profile.driveTimeRemaining < 3600 ? .red : .secondary)
                    }
                }
            } else {
                Text("No driver data available yet.").foregroundColor(.secondary).padding()
            }
            if !trips.isEmpty {
                Text("Total trips logged: \(trips.count)").padding()
            }
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
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }

}
