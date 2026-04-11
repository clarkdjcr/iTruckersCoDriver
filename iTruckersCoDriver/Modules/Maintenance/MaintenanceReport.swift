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
    var id: UUID = UUID()
    var driverID: String = ""
    var vehicleID: String = ""
    var timestamp: Date = Date()
    var issueDescription: String = ""
    var severity: String = "medium"
    var resolved: Bool = false
    var resolvedDate: Date?
    var resolvedNotes: String = ""

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
