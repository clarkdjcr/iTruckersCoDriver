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

// MARK: - Root View (iOS onboarding gate)

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    #if os(iOS)
    @State private var isOnboardingComplete: Bool = false

    private var onboardingDone: Bool {
        // Onboarding complete if we have a DriverAccount for this device OR have an API key
        isOnboardingComplete || appState.hasAPIKey || checkExistingAccount()
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
    var body: some View {
        ContentView()
    }
    #endif
}
