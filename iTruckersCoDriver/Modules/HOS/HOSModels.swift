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
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var dutyStatusRaw: String = DutyStatus.offDuty.rawValue
    var locationName: String = ""
    var notes: String = ""

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
    var id: UUID = UUID()
    var date: Date = Date()
    var category: String = ""
    var amount: Double = 0
    var note: String = ""

    init(category: String, amount: Double, note: String = "") {
        self.id = UUID()
        self.date = Date()
        self.category = category
        self.amount = amount
        self.note = note
    }
}
