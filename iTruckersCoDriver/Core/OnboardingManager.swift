//
//  OnboardingManager.swift
//  iTruckersCoDriver
//
//  Provisions the driver account and marks onboarding complete. The Co-Driver
//  assistant runs on-device (Apple Intelligence) — no key to validate.
//

import Foundation
import Combine

@MainActor
class OnboardingManager: ObservableObject {

    func completeDriverOnboarding(account: DriverAccount, appState: AppState, name: String, cdlState: String, cycle: HOSCycle) {
        account.name = name.isEmpty ? "Driver" : name
        account.cdlState = cdlState
        account.onboardingComplete = true
        appState.driverName = account.name
        appState.cdlState = cdlState
        appState.hosCycle = cycle
        appState.role = .driver
        appState.onboardingComplete = true
    }
}
