//
//  HealthView.swift
//  iTruckersCoDriver
//
//  iOS: Health summary dashboard with fatigue score.
//  Opt-in only — explicit driver consent required.
//

import SwiftUI

#if os(iOS)
struct HealthView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var healthManager = HealthManager()

    var body: some View {
        NavigationView {
            Group {
                if !appState.healthMonitoringEnabled {
                    optInView
                } else if !healthManager.isAuthorized {
                    authorizationView
                } else {
                    healthDashboard
                }
            }
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if appState.healthMonitoringEnabled && !healthManager.isAuthorized {
                    healthManager.requestAuthorization()
                }
            }
        }
    }

    // MARK: - Opt-in prompt

    private var optInView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60)).foregroundColor(.pink)
            Text("Health Monitoring")
                .font(.title).fontWeight(.bold)
            Text("Co-Driver can monitor your heart rate, sleep, and fatigue to help you stay safe on long hauls.")
                .multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal)
            Button("Enable Health Monitoring") {
                appState.healthMonitoringEnabled = true
                healthManager.requestAuthorization()
            }
            .buttonStyle(.borderedProminent)
            Text("Your raw health data stays on this device. Dispatcher sees only a binary fatigue alert, never raw data.")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
        }
        .padding()
    }

    // MARK: - Authorization prompt

    private var authorizationView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.slash").font(.system(size: 48)).foregroundColor(.secondary)
            Text("Health Access Required")
                .font(.headline)
            Text("Tap below to grant access to Health data in iOS Settings.")
                .foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Button("Allow Health Access") { healthManager.requestAuthorization() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Dashboard

    private var healthDashboard: some View {
        ScrollView {
            VStack(spacing: 16) {
                fatigueCard
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    healthCard("Heart Rate",   "\(Int(healthManager.currentHeartRate))",  "bpm", "heart.fill",           .red)
                    healthCard("Resting HR",   "\(Int(healthManager.restingHeartRate))", "bpm", "heart",                 .pink)
                    healthCard("Sleep",        String(format: "%.1f", healthManager.sleepHoursLast24), "hrs", "bed.double.fill", .purple)
                    healthCard("HRV",          "\(Int(healthManager.hrv))",               "ms",  "waveform.path.ecg",    .blue)
                }
                Button("Refresh") { healthManager.fetchLatestData() }
                    .buttonStyle(.bordered).padding(.top, 4)
            }
            .padding()
        }
    }

    private var fatigueCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Fatigue Score").font(.headline)
                Spacer()
                if healthManager.hasFatigueAlert {
                    Label("High Fatigue", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundColor(.red)
                }
            }
            ProgressView(value: Double(healthManager.fatigueScore), total: 100)
                .tint(healthManager.fatigueScore >= 70 ? .red : healthManager.fatigueScore >= 40 ? .orange : .green)
            Text(fatigueMessage).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private var fatigueMessage: String {
        switch healthManager.fatigueScore {
        case 70...: return "You may be fatigued. Consider taking a rest break before continuing."
        case 40..<70: return "Moderate fatigue detected. Stay alert and hydrated."
        default: return "You appear well-rested. Drive safely out there!"
        }
    }

    private func healthCard(_ title: String, _ value: String, _ unit: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.caption).foregroundColor(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value == "0" ? "--" : value).font(.title2).fontWeight(.bold)
                Text(unit).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}
#endif
