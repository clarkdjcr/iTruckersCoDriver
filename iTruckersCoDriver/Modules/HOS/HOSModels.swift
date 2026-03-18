//
//  HOSModels.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import Foundation
import SwiftData

// MARK: - SwiftData model for HOS log entries

@Model
final class HOSEntry {
    var id: UUID
    var timestamp: Date
    var dutyStatusRaw: String
    var locationName: String
    var notes: String

    init(status: DutyStatus, locationName: String = "", notes: String = "") {
        self.id = UUID()
        self.timestamp = Date()
        self.dutyStatusRaw = status.rawValue
        self.locationName = locationName
        self.notes = notes
    }

    var dutyStatus: DutyStatus {
        DutyStatus(rawValue: dutyStatusRaw) ?? .offDuty
    }
}

// MARK: - SwiftData model for expense entries (used by TripRecord)

@Model
final class ExpenseEntry {
    var id: UUID
    var date: Date
    var category: String
    var amount: Double
    var note: String

    init(category: String, amount: Double, note: String = "") {
        self.id = UUID()
        self.date = Date()
        self.category = category
        self.amount = amount
        self.note = note
    }
}
