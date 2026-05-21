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
                .tabItem { Label("Compliance", systemImage: "checkmark.seal.fill") }
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
            voiceManager.configure(modelContext: modelContext)
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
    @State private var micPulseScale: CGFloat = 1.0

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                // Background Gradient
                RadialGradient(
                    gradient: Gradient(colors: [Theme.primary.opacity(0.15), .clear]),
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 500
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Modern Header Dashboard
                    headerDashboard
                        .padding(.top, 8)

                    // Alert area
                    if !driverState.hosRemaining.isCompliant || (telemetryManager.fuelLevelGallons > 0 && telemetryManager.isLowFuel) {
                        VStack(spacing: 8) {
                            if !driverState.hosRemaining.isCompliant { hosAlertBanner }
                            if telemetryManager.fuelLevelGallons > 0 && telemetryManager.isLowFuel { fuelWarningBanner }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
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
                                withAnimation(.spring()) { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: driverState.isProcessingAI) {
                            withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                        }
                    }

                    // Interactive Bottom Bar
                    VStack(spacing: 20) {
                        if !voiceManager.isListening && !driverState.isProcessingAI {
                            quickCommandsScroll
                        }

                        micButtonSection
                    }
                    .padding(.bottom, 20)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .mask(LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom))
                    )
                }
            }
            .navigationTitle("Co-Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { driverState.clearConversation() } label: {
                        Image(systemName: "trash").foregroundColor(Theme.textSecondary)
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

    // MARK: - Premium Header
    
    private var headerDashboard: some View {
        HStack(spacing: 12) {
            dashboardCard(
                title: "DRIVE",
                value: driverState.hosRemaining.driveTimeRemainingFormatted,
                icon: "clock.fill",
                color: Theme.primary
            )
            dashboardCard(
                title: "FUEL",
                value: "\(Int(driverState.fuelLevel))%",
                icon: "fuelpump.fill",
                color: driverState.fuelLevel < 20 ? Theme.warning : Theme.success
            )
            dashboardCard(
                title: "SPEED",
                value: "\(Int(driverState.currentSpeedMPH))",
                subtitle: "MPH",
                icon: "speedometer",
                color: Theme.textPrimary
            )
        }
        .padding(.horizontal)
    }

    private func dashboardCard(title: String, value: String, subtitle: String? = nil, icon: String, color: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                    Text(title)
                        .font(Theme.Typography.caption(10))
                        .kerning(1.2)
                }
                .foregroundColor(Theme.textSecondary)
                
                HStack(alignment: .bottom, spacing: 2) {
                    Text(value)
                        .font(Theme.Typography.title(22))
                        .foregroundColor(color)
                    if let sub = subtitle {
                        Text(sub)
                            .font(Theme.Typography.caption(10))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Mic Section

    private var micButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: handleMicTap) {
                ZStack {
                    // Pulsing circles when listening
                    if voiceManager.isListening {
                        Circle()
                            .stroke(Theme.primary.opacity(0.3), lineWidth: 4)
                            .scaleEffect(micPulseScale)
                            .opacity(Double(2 - micPulseScale))
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                                    micPulseScale = 2.0
                                }
                            }
                    }
                    
                    Circle()
                        .fill(Theme.primaryGradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: Theme.primary.opacity(0.5), radius: 15, x: 0, y: 10)
                    
                    Image(systemName: micIcon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(voiceManager.isListening ? 1.2 : 1.0)
                }
            }
            .disabled(driverState.isProcessingAI)
            .animation(.spring(), value: voiceManager.isListening)

            Text(voiceManager.statusMessage)
                .font(Theme.Typography.caption())
                .foregroundColor(voiceManager.isListening ? Theme.primary : Theme.textSecondary)
        }
    }

    private var quickCommandsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(quickCommands, id: \.self) { cmd in
                    Button(action: { /* Handle command */ }) {
                        Text(cmd)
                            .font(Theme.Typography.caption())
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Sub-views

    private func conversationBubble(_ message: ConversationMessage) -> some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 60) }
            
            Text(message.content)
                .font(Theme.Typography.body())
                .padding(14)
                .background(message.role == "user" ? Theme.primary : Color.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(18, corners: message.role == "user" ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            
            if message.role == "assistant" { Spacer(minLength: 60) }
        }
        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
    }

    private var welcomeMessage: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Theme.primary)
            }
            
            VStack(spacing: 8) {
                Text("Welcome Back, Driver")
                    .font(Theme.Typography.title(24))
                Text("Tap the mic to start your pre-trip, log status, or find a route.")
                    .font(Theme.Typography.body())
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Theme.primary)
            Text("Co-Driver is thinking...")
                .font(Theme.Typography.caption())
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal)
        .id("thinking")
    }

    private var hosAlertBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(driverState.hosRemaining.alerts.first ?? "HOS limit approaching")
                .font(Theme.Typography.caption())
            Spacer()
        }
        .foregroundColor(.white)
        .padding()
        .background(Theme.accent)
        .cornerRadius(14)
    }

    private var fuelWarningBanner: some View {
        HStack {
            Image(systemName: "fuelpump.exclamationmark.fill")
            Text(driverState.estimatedRange < 50
                 ? "Low fuel — range \(Int(driverState.estimatedRange)) miles"
                 : "Fuel below 20% — consider refueling")
                .font(Theme.Typography.caption())
            Spacer()
        }
        .foregroundColor(.white)
        .padding()
        .background(Theme.warning)
        .cornerRadius(14)
    }

    // MARK: - Helpers

    private func handleMicTap() {
        guard appState.hasAPIKey else { showAPIKeyAlert = true; return }
        voiceManager.toggleListening()
    }

    private var micIcon: String {
        if driverState.isProcessingAI { return "cpu" }
        return voiceManager.isListening ? "waveform" : "mic.fill"
    }

    private let quickCommands = [
        "Start Inspection", "Am I compliant?", "Log Fuel",
        "Weather check", "Profit for load?", "Taking a break"
    ]
}

// Helper for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
#endif
