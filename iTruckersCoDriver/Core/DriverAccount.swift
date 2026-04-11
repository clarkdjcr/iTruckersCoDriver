//
//  DriverAccount.swift
//  iTruckersCoDriver
//
//  SwiftData model for per-driver account. Each driver has their own API key
//  (stored in Keychain, keyed by driverID), cloud folder, and onboarding state.
//

import Foundation
import SwiftData

@Model
final class DriverAccount {
    var driverID: String = ""
    var name: String = ""
    var cdlNumber: String = ""
    var cdlState: String = ""
    var cloudFolderID: String = ""
    var onboardingComplete: Bool = false
    var companyID: String = ""

    init(driverID: String, name: String = "") {
        self.driverID = driverID
        self.name = name
        self.cdlNumber = ""
        self.cdlState = ""
        self.cloudFolderID = UUID().uuidString
        self.onboardingComplete = false
        self.companyID = ""
    }

    /// Keychain key scoped to this driver's API key
    var apiKeyKeychainKey: String { "anthropic_api_key_\(driverID)" }

    var hasPersonalAPIKey: Bool {
        KeychainHelper.load(forKey: apiKeyKeychainKey) != nil
    }
}
