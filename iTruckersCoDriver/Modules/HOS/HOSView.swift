//
//  HOSView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI
import SwiftData

#if os(iOS)
struct HOSView: View {
    @EnvironmentObject var driverState: DriverState
    @Query(sort: \HOSEntry.timestamp, order: .reverse) private var allEntries: [HOSEntry]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var hosManager = HOSManager()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Compliance status banner
                    if !hosManager.summary.isCompliant {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            VStack(alignment: .leading) {
                                ForEach(hosManager.summary.alerts, id: \.self) { alert in
                                    Text(alert).font(.caption)
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Current status card
                    currentStatusCard

                    // Hours remaining cards
                    hoursGrid

                    // Duty status buttons
                    dutyStatusButtons

                    // Today's log
                    todayLogSection
                }
                .padding(.vertical)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Hours of Service")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            hosManager.configure(with: modelContext)
        }
    }

    // MARK: - Current status card

    private var currentStatusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: driverState.currentDutyStatus.systemImage)
                .font(.system(size: 40))
                .foregroundColor(statusColor(driverState.currentDutyStatus))

            VStack(alignment: .leading) {
                Text("Current Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(driverState.currentDutyStatus.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                if let lastEntry = allEntries.first {
                    Text("Since \(lastEntry.timestamp.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Hours grid

    private var hoursGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            hoursCard(
                title: "Drive Time",
                remaining: hosManager.summary.driveTimeRemaining,
                max: 11 * 3600,
                color: .blue
            )
            hoursCard(
                title: "On-Duty Window",
                remaining: hosManager.summary.onDutyTimeRemaining,
                max: 14 * 3600,
                color: .orange
            )
            hoursCard(
                title: "Cycle Hours",
                remaining: hosManager.summary.cycleHoursRemaining,
                max: 70 * 3600,
                color: .purple
            )
            hoursCard(
                title: "Until Break",
                remaining: hosManager.summary.breakTimeUntilRequired,
                max: 8 * 3600,
                color: .green
            )
        }
        .padding(.horizontal)
    }

    private func hoursCard(title: String, remaining: TimeInterval, max: TimeInterval, color: Color) -> some View {
        let fraction = max > 0 ? min(1, remaining / max) : 0
        let isLow = fraction < 0.25
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(formatInterval(remaining))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(isLow ? .red : .primary)
            ProgressView(value: fraction)
                .tint(isLow ? .red : color)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Duty status buttons

    private var dutyStatusButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Change Status")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(DutyStatus.allCases, id: \.self) { status in
                    Button {
                        let entry = hosManager.logDutyChange(status: status)
                        driverState.currentDutyStatus = status
                        driverState.hosRemaining = hosManager.summary
                        _ = entry
                    } label: {
                        HStack {
                            Image(systemName: status.systemImage)
                            Text(status.displayName)
                                .font(.subheadline)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(driverState.currentDutyStatus == status ? statusColor(status).opacity(0.2) : Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(driverState.currentDutyStatus == status ? statusColor(status) : Color.clear, lineWidth: 2)
                        )
                        .cornerRadius(10)
                    }
                    .foregroundColor(driverState.currentDutyStatus == status ? statusColor(status) : .primary)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Today's log

    private var todayLogSection: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = allEntries.filter { $0.timestamp >= today }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Today's Log")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if todayEntries.isEmpty {
                Text("No entries today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(todayEntries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.dutyStatus.systemImage)
                            .foregroundColor(statusColor(entry.dutyStatus))
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(entry.dutyStatus.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if !entry.locationName.isEmpty {
                                Text(entry.locationName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: DutyStatus) -> Color {
        switch status {
        case .offDuty: return .gray
        case .sleeperBerth: return .purple
        case .driving: return .red
        case .onDuty: return .orange
        }
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}
#endif
