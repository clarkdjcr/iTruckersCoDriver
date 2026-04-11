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
    var driverID: String = ""
    var name: String = ""
    var dutyStatusRaw: String = "off_duty"
    var locationName: String = ""
    var driveTimeRemaining: TimeInterval = 11 * 3600
    var onDutyTimeRemaining: TimeInterval = 14 * 3600
    var cycleHoursRemaining: TimeInterval = 70 * 3600
    var currentLoadNumber: String = ""
    var lastUpdated: Date = Date()

    // Telematics — updated by driver device, read by dispatcher dashboard
    var speedMPH: Double = 0
    var fuelLevel: Double = 0
    var estimatedRange: Double = 0
    var hasFatigueAlert: Bool = false

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
