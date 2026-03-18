//
//  MaintenanceReport.swift
//  iTruckersCoDriver
//
//  SwiftData model for driver-reported maintenance issues.
//  Synced via CloudKit so dispatchers see all reports.
//

import Foundation
import SwiftData

@Model
final class MaintenanceReport {
    var id: UUID
    var driverID: String
    var vehicleID: String
    var timestamp: Date
    var issueDescription: String
    var severity: String    // "low", "medium", "high"
    var resolved: Bool
    var resolvedDate: Date?
    var resolvedNotes: String

    init(
        driverID: String,
        vehicleID: String = "",
        description: String,
        severity: String = "medium"
    ) {
        self.id = UUID()
        self.driverID = driverID
        self.vehicleID = vehicleID
        self.timestamp = Date()
        self.issueDescription = description
        self.severity = severity
        self.resolved = false
        self.resolvedDate = nil
        self.resolvedNotes = ""
    }

    var isUrgent: Bool { severity == "high" && !resolved }
}
