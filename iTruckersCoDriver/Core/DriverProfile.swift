//
//  DriverProfile.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//
//  CloudKit-synced model. Each driver device creates one profile.
//  Dispatcher reads all profiles to populate the fleet view.
//

import Foundation
import SwiftData

@Model
final class DriverProfile {
    var driverID: String
    var name: String
    var dutyStatusRaw: String
    var locationName: String
    var driveTimeRemaining: TimeInterval
    var onDutyTimeRemaining: TimeInterval
    var cycleHoursRemaining: TimeInterval
    var currentLoadNumber: String
    var lastUpdated: Date

    // Telematics — updated by driver device, read by dispatcher dashboard
    var speedMPH: Double
    var fuelLevel: Double       // percentage 0–100
    var estimatedRange: Double  // miles
    var hasFatigueAlert: Bool   // set if health monitoring opt-in and score ≥ 70

    init(driverID: String, name: String) {
        self.driverID = driverID
        self.name = name.isEmpty ? "Driver" : name
        self.dutyStatusRaw = DutyStatus.offDuty.rawValue
        self.locationName = ""
        self.driveTimeRemaining = 11 * 3600
        self.onDutyTimeRemaining = 14 * 3600
        self.cycleHoursRemaining = 70 * 3600
        self.currentLoadNumber = ""
        self.lastUpdated = Date()
        self.speedMPH = 0
        self.fuelLevel = 0
        self.estimatedRange = 0
        self.hasFatigueAlert = false
    }

    var dutyStatus: DutyStatus {
        DutyStatus(rawValue: dutyStatusRaw) ?? .offDuty
    }
}
