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
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Compliance status banner
                        if !hosManager.summary.isCompliant {
                            complianceAlertBanner
                        }

                        // Current status hero section
                        currentStatusHero

                        // Hours remaining cards
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LOG SUMMARY")
                                .font(Theme.Typography.caption(10))
                                .kerning(1.2)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal)
                            
                            hoursGrid
                        }

                        // Duty status selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DUTY STATUS")
                                .font(Theme.Typography.caption(10))
                                .kerning(1.2)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal)
                            
                            dutyStatusSelection
                        }

                        // Recent activity
                        recentActivitySection
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Hours of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            hosManager.configure(with: modelContext)
        }
    }

    // MARK: - Compliance Banner
    
    private var complianceAlertBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(hosManager.summary.alerts, id: \.self) { alert in
                    Text(alert)
                        .font(Theme.Typography.caption())
                        .fontWeight(.bold)
                }
            }
            Spacer()
        }
        .foregroundColor(.white)
        .padding()
        .background(Theme.accent)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Current Status Hero
    
    private var currentStatusHero: some View {
        GlassCard {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(statusColor(driverState.currentDutyStatus).opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: driverState.currentDutyStatus.systemImage)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(statusColor(driverState.currentDutyStatus))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT STATUS")
                        .font(Theme.Typography.caption(10))
                        .kerning(1.2)
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(driverState.currentDutyStatus.displayName)
                        .font(Theme.Typography.title(24))
                        .foregroundColor(.white)
                    
                    if let lastEntry = allEntries.first {
                        Text("Active since \(lastEntry.timestamp.formatted(date: .omitted, time: .shortened))")
                            .font(Theme.Typography.caption())
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Hours grid

    private var hoursGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            hoursCard(
                title: "DRIVE TIME",
                remaining: hosManager.summary.driveTimeRemaining,
                max: 11 * 3600,
                color: Theme.primary
            )
            hoursCard(
                title: "ON-DUTY WINDOW",
                remaining: hosManager.summary.onDutyTimeRemaining,
                max: 14 * 3600,
                color: Theme.warning
            )
            hoursCard(
                title: "CYCLE HOURS",
                remaining: hosManager.summary.cycleHoursRemaining,
                max: 70 * 3600,
                color: .purple
            )
            hoursCard(
                title: "UNTIL BREAK",
                remaining: hosManager.summary.breakTimeUntilRequired,
                max: 8 * 3600,
                color: Theme.success
            )
        }
        .padding(.horizontal)
    }

    private func hoursCard(title: String, remaining: TimeInterval, max: TimeInterval, color: Color) -> some View {
        let fraction = max > 0 ? min(1, remaining / max) : 0
        let isLow = fraction < 0.15
        
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(Theme.Typography.caption(10))
                    .kerning(1.0)
                    .foregroundColor(Theme.textSecondary)
                
                Text(formatInterval(remaining))
                    .font(Theme.Typography.title(22))
                    .foregroundColor(isLow ? Theme.accent : .white)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(isLow ? Theme.accent : color)
                            .frame(width: geo.size.width * fraction, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: - Duty Status Selection

    private var dutyStatusSelection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(DutyStatus.allCases, id: \.self) { status in
                Button {
                    withAnimation(.spring()) {
                        let entry = hosManager.logDutyChange(status: status)
                        driverState.currentDutyStatus = status
                        driverState.hosRemaining = hosManager.summary
                        _ = entry
                    }
                } label: {
                    HStack {
                        Image(systemName: status.systemImage)
                            .font(.system(size: 14, weight: .bold))
                        Text(status.displayName)
                            .font(Theme.Typography.caption())
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        driverState.currentDutyStatus == status 
                        ? statusColor(status).opacity(0.2) 
                        : Color.white.opacity(0.05)
                    )
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                driverState.currentDutyStatus == status 
                                ? statusColor(status) 
                                : Color.white.opacity(0.1), 
                                lineWidth: 1.5
                            )
                    )
                }
                .foregroundColor(driverState.currentDutyStatus == status ? statusColor(status) : .white)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = allEntries.filter { $0.timestamp >= today }

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TODAY'S ACTIVITY")
                    .font(Theme.Typography.caption(10))
                    .kerning(1.2)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("\(todayEntries.count) events")
                    .font(Theme.Typography.caption(10))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal)

            if todayEntries.isEmpty {
                GlassCard {
                    Text("No activity recorded for today")
                        .font(Theme.Typography.caption())
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(todayEntries) { entry in
                        HStack(spacing: 16) {
                            Circle()
                                .fill(statusColor(entry.dutyStatus).opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: entry.dutyStatus.systemImage)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(statusColor(entry.dutyStatus))
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.dutyStatus.displayName)
                                    .font(Theme.Typography.body(14))
                                    .fontWeight(.bold)
                                if !entry.locationName.isEmpty {
                                    Text(entry.locationName)
                                        .font(Theme.Typography.caption(10))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(Theme.Typography.caption(12))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: DutyStatus) -> Color {
        switch status {
        case .offDuty: return .gray
        case .sleeperBerth: return .purple
        case .driving: return Theme.accent
        case .onDuty: return Theme.warning
        }
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}
#endif
