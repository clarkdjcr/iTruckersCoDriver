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
            // Tax & Vehicle models
            DriverTaxProfile.self,
            QuarterlyIncome.self,
            VehicleInfo.self,
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
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var isOnboardingComplete: Bool = false

    private var onboardingDone: Bool {
        if appState.onboardingComplete || isOnboardingComplete { return true }
        // Backward compat: existing users with a completed DriverAccount skip re-onboarding
        if checkExistingAccount() {
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
}
