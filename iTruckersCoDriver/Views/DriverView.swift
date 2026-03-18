//
//  DriverView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI
import SwiftData

#if os(iOS)
struct DriverView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var driverState: DriverState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var telemetryManager = TelemetryManager()
    @State private var selectedTab = 0

    // Overdue maintenance count for badge
    @Query private var allMaintenanceItems: [MaintenanceItem]
    private var overdueCount: Int {
        allMaintenanceItems.filter { $0.driverID == appState.driverID && $0.isActive && $0.isOverdue }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            VoiceTabView(voiceManager: voiceManager, telemetryManager: telemetryManager)
                .tabItem { Label("Co-Driver", systemImage: "waveform.and.mic") }
                .tag(0)

            HOSView()
                .tabItem { Label("HOS", systemImage: "clock.badge.checkmark") }
                .tag(1)

            RouteView()
                .tabItem { Label("Route", systemImage: "map.fill") }
                .tag(2)

            MessagesView()
                .tabItem { Label("Dispatch", systemImage: "message.fill") }
                .badge(driverState.unreadMessageCount > 0 ? "\(driverState.unreadMessageCount)" : nil)
                .tag(3)

            ComplianceView()
                .tabItem { Label("Compliance", systemImage: "doc.badge.checkmark") }
                .tag(4)

            MaintenanceView()
                .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver") }
                .badge(overdueCount > 0 ? "\(overdueCount)" : nil)
                .tag(5)

            HealthView()
                .tabItem { Label("Health", systemImage: "heart.fill") }
                .tag(6)

            DocumentView()
                .tabItem { Label("Documents", systemImage: "folder.fill") }
                .tag(7)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(8)
        }
        .tint(.blue)
        .onAppear {
            voiceManager.appState = appState
            voiceManager.driverState = driverState
            telemetryManager.driverState = driverState
            telemetryManager.configure(driverID: appState.driverID, context: modelContext)
            syncDriverProfile()
        }
        .onChange(of: driverState.currentDutyStatus) { syncDriverProfile() }
        .onChange(of: driverState.hosRemaining.driveTimeRemaining) { syncDriverProfile() }
        .onChange(of: driverState.fuelLevel) { syncDriverProfile() }
        .onChange(of: driverState.currentSpeedMPH) { syncDriverProfile() }
    }

    // MARK: - CloudKit profile sync

    private func syncDriverProfile() {
        let myID = appState.driverID
        let descriptor = FetchDescriptor<DriverProfile>(
            predicate: #Predicate { $0.driverID == myID }
        )
        let existing = try? modelContext.fetch(descriptor)

        if let profile = existing?.first {
            profile.name = appState.driverName.isEmpty ? "Driver" : appState.driverName
            profile.dutyStatusRaw = driverState.currentDutyStatus.rawValue
            profile.driveTimeRemaining = driverState.hosRemaining.driveTimeRemaining
            profile.onDutyTimeRemaining = driverState.hosRemaining.onDutyTimeRemaining
            profile.cycleHoursRemaining = driverState.hosRemaining.cycleHoursRemaining
            profile.speedMPH = driverState.currentSpeedMPH
            profile.fuelLevel = driverState.fuelLevel
            profile.estimatedRange = driverState.estimatedRange
            profile.lastUpdated = Date()
        } else {
            let profile = DriverProfile(driverID: myID, name: appState.driverName)
            profile.dutyStatusRaw = driverState.currentDutyStatus.rawValue
            profile.driveTimeRemaining = driverState.hosRemaining.driveTimeRemaining
            profile.onDutyTimeRemaining = driverState.hosRemaining.onDutyTimeRemaining
            profile.cycleHoursRemaining = driverState.hosRemaining.cycleHoursRemaining
            profile.speedMPH = driverState.currentSpeedMPH
            profile.fuelLevel = driverState.fuelLevel
            profile.estimatedRange = driverState.estimatedRange
            modelContext.insert(profile)
        }
        try? modelContext.save()
    }
}

// MARK: - Voice Tab

struct VoiceTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var driverState: DriverState
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var telemetryManager: TelemetryManager
    @State private var showAPIKeyAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // HOS alert banner
                    if !driverState.hosRemaining.isCompliant {
                        hosAlertBanner
                    }
                    // Low fuel warning (< 50 miles range or fuel < 20%)
                    if telemetryManager.fuelLevelGallons > 0 && telemetryManager.isLowFuel {
                        fuelWarningBanner
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if driverState.conversationHistory.isEmpty {
                                    welcomeMessage
                                }
                                ForEach(driverState.conversationHistory) { msg in
                                    conversationBubble(msg).id(msg.id)
                                }
                                if driverState.isProcessingAI {
                                    thinkingIndicator
                                }
                            }
                            .padding()
                        }
                        .onChange(of: driverState.conversationHistory.count) {
                            if let last = driverState.conversationHistory.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: driverState.isProcessingAI) {
                            withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                        }
                    }

                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: driverState.currentDutyStatus.systemImage)
                                .foregroundColor(dutyStatusColor)
                            Text(driverState.currentDutyStatus.displayName)
                                .font(.caption).foregroundColor(.gray)
                            Spacer()
                            Text(driverState.hosRemaining.driveTimeRemainingFormatted + " drive")
                                .font(.caption).foregroundColor(.gray)
                        }
                        .padding(.horizontal)

                        Button(action: handleMicTap) {
                            ZStack {
                                Circle()
                                    .fill(micButtonColor)
                                    .frame(width: 110, height: 110)
                                    .shadow(color: micButtonColor.opacity(0.4), radius: voiceManager.isListening ? 16 : 0)
                                Image(systemName: micIcon)
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(driverState.isProcessingAI)
                        .opacity(driverState.isProcessingAI ? 0.5 : 1.0)

                        Text(voiceManager.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(voiceManager.isListening ? .green : .gray)

                        if !voiceManager.isListening && !driverState.isProcessingAI {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(quickCommands, id: \.self) { cmd in
                                        Text(cmd)
                                            .font(.caption).foregroundColor(.white)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(16)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color.black)
                }
            }
            .navigationTitle("Co-Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { driverState.clearConversation() } label: {
                        Image(systemName: "arrow.clockwise").foregroundColor(.gray)
                    }
                }
            }
        }
        .colorScheme(.dark)
        .onAppear { voiceManager.requestPermissions() }
        .alert("API Key Required", isPresented: $showAPIKeyAlert) {
            Button("OK") {}
        } message: {
            Text("Please add your Claude API key in Settings to enable AI voice interaction.")
        }
    }

    // MARK: - Sub-views

    private func conversationBubble(_ message: ConversationMessage) -> some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 40) }
            Text(message.content)
                .font(.body).padding(12)
                .background(message.role == "user" ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(.white).cornerRadius(16)
            if message.role == "assistant" { Spacer(minLength: 40) }
        }
    }

    private var welcomeMessage: some View {
        VStack(spacing: 8) {
            Text("🚛").font(.system(size: 48))
            Text("Hey driver! Tap the mic and let's roll.")
                .font(.body).foregroundColor(.gray).multilineTextAlignment(.center)
            Text("Ask me about fuel stops, weather, HOS log, navigation — or just say hi.")
                .font(.caption).foregroundColor(.gray.opacity(0.7)).multilineTextAlignment(.center)
        }
        .padding(.top, 40).padding(.horizontal)
    }

    private var thinkingIndicator: some View {
        HStack {
            ProgressView().tint(.gray)
            Text("Co-Driver is thinking...").font(.caption).foregroundColor(.gray)
            Spacer()
        }
        .id("thinking")
    }

    private var hosAlertBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(driverState.hosRemaining.alerts.first ?? "HOS limit approaching")
                .font(.caption).lineLimit(1)
            Spacer()
        }
        .foregroundColor(.white).padding(.horizontal).padding(.vertical, 8)
        .background(Color.red)
    }

    private var fuelWarningBanner: some View {
        HStack {
            Image(systemName: "fuelpump.exclamationmark.fill")
            Text(driverState.estimatedRange < 50
                 ? "Low fuel — estimated range \(Int(driverState.estimatedRange)) miles"
                 : "Fuel below 20% — consider refueling soon")
                .font(.caption).lineLimit(1)
            Spacer()
        }
        .foregroundColor(.white).padding(.horizontal).padding(.vertical, 8)
        .background(Color.orange)
    }

    // MARK: - Helpers

    private func handleMicTap() {
        guard appState.hasAPIKey else { showAPIKeyAlert = true; return }
        voiceManager.toggleListening()
    }

    private var micButtonColor: Color {
        if !voiceManager.permissionsGranted { return .gray }
        if voiceManager.isListening { return .red }
        return .blue
    }

    private var micIcon: String {
        if driverState.isProcessingAI { return "cpu" }
        return voiceManager.isListening ? "waveform" : "mic.fill"
    }

    private var dutyStatusColor: Color {
        switch driverState.currentDutyStatus {
        case .offDuty: return .gray
        case .sleeperBerth: return .purple
        case .driving: return .red
        case .onDuty: return .orange
        }
    }

    private let quickCommands = [
        "Starting my drive", "Find fuel", "Find rest area",
        "Weather check", "How many hours left?", "Taking a break", "Tell me a joke"
    ]
}
#endif
