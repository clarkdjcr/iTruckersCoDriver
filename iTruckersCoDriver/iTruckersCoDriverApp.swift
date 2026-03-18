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
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Fallback to local storage if CloudKit is unavailable
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try! ModelContainer(for: schema, configurations: [localConfig])
        }
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
