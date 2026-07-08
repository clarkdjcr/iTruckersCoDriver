//
//  iTruckersCoDriverApp.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI
import SwiftData

@main
struct iTruckersCoDriverApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var driverState = DriverState()
    @StateObject private var dispatcherState = DispatcherState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Original models
            HOSEntry.self,
            TripRecord.self,
            ExpenseEntry.self,
            DispatchMessage.self,
            DriverProfile.self,
            Item.self,
            // Phase 1: Onboarding
            DriverAccount.self,
            // Phase 2: Communications
            DeliveryContact.self,
            CommunicationLog.self,
            // Phase 3: Fleet Telematics
            VehicleMetrics.self,
            FuelRecord.self,
            // Phase 4: Maintenance
            MaintenanceItem.self,
            MaintenanceReport.self,
            // Phase 5: Profit planning
            LoadOpportunity.self,
        ])

        // Local persistent store. CloudKit (.automatic) is intentionally disabled until
        // the Xcode capability is configured and all @Model properties have defaults.
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        }

        // Schema changed (major refactor) — delete stale store and start fresh.
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for name in ["default.store", "default.store-shm", "default.store-wal"] {
                try? FileManager.default.removeItem(at: appSupport.appending(path: name))
            }
        }
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        }

        // In-memory fallback — app launches but data won't persist this session.
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [memConfig]) else {
            fatalError("SwiftData schema is invalid — check @Model definitions.")
        }
        return container
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(sharedModelContainer)
                .environmentObject(appState)
                .environmentObject(driverState)
                .environmentObject(dispatcherState)
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 700)
        #endif

        #if os(macOS)
        Settings {
            DispatcherSettingsView()
                .environmentObject(appState)
        }
        #endif
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    #if os(iOS)
    @State private var isOnboardingComplete: Bool = false

    private var onboardingDone: Bool {
        if appState.onboardingComplete || isOnboardingComplete { return true }
        // Backward compat: existing users with a DriverAccount or API key skip re-onboarding
        if appState.hasAPIKey || checkExistingAccount() {
            appState.onboardingComplete = true
            return true
        }
        return false
    }

    var body: some View {
        if onboardingDone {
            ContentView()
        } else {
            OnboardingView(isOnboardingComplete: $isOnboardingComplete)
        }
    }

    private func checkExistingAccount() -> Bool {
        let myID = appState.driverID
        let descriptor = FetchDescriptor<DriverAccount>(
            predicate: #Predicate { $0.driverID == myID && $0.onboardingComplete }
        )
        return ((try? modelContext.fetch(descriptor))?.isEmpty == false)
    }

    #else

    // macOS: always dispatcher — show a first-launch setup sheet
    @State private var showMacOnboarding: Bool = false
    @State private var macName = ""
    @State private var macCompany = ""

    var body: some View {
        ContentView()
            .onAppear {
                if !appState.onboardingComplete { showMacOnboarding = true }
            }
            .sheet(isPresented: $showMacOnboarding) {
                macOnboardingSheet
            }
    }

    private var macOnboardingSheet: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("🚛").font(.system(size: 56))
                Text("Welcome to iTrucker Dispatcher")
                    .font(.title2).fontWeight(.bold)
                Text("A quick setup before you get started.")
                    .foregroundColor(.secondary)
            }

            Form {
                Section("Your Info") {
                    TextField("Your name", text: $macName)
                    TextField("Company / Fleet name (optional)", text: $macCompany)
                }
            }
            .formStyle(.grouped)
            .frame(height: 140)

            HStack {
                Spacer()
                Button("Get Started") {
                    appState.driverName = macName.isEmpty ? "Dispatcher" : macName
                    appState.companyName = macCompany
                    appState.role = .dispatcher
                    appState.onboardingComplete = true
                    showMacOnboarding = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(macName.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 420)
        .interactiveDismissDisabled()
    }
    #endif
}
