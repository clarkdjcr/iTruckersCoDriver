//
//  DriverAccount.swift
//  iTruckersCoDriver
//
//  SwiftData model for the per-driver account: profile, cloud folder, and
//  onboarding state.
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
}
