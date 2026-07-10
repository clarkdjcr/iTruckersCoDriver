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
    /// Percentage of `amount` that is business-deductible (e.g. a phone used
    /// partly for personal calls). Defaults to 100 for fully-deductible items.
    var businessUsePercent: Double = 100
    /// Optional scanned receipt image (JPEG). Kept out of the main store via
    /// external storage; nil default keeps the model CloudKit-safe.
    @Attribute(.externalStorage) var receiptImageData: Data? = nil

    init(category: String, amount: Double, note: String = "", businessUsePercent: Double = 100) {
        self.id = UUID()
        self.date = Date()
        self.category = category
        self.amount = amount
        self.note = note
        self.businessUsePercent = businessUsePercent
    }
}

extension ExpenseEntry {
    /// The tax bucket this expense rolls up into for quarterly reporting.
    var bucket: TaxBucket { TaxBucket.resolve(category) }

    /// The portion of `amount` that is actually deductible after applying
    /// the business-use percentage.
    var deductibleAmount: Double { amount * (businessUsePercent / 100) }

    /// Whether a scanned receipt image is attached to this expense.
    var hasReceipt: Bool { receiptImageData != nil }

    /// Sums expense amounts grouped by category. Mirrors ComplianceView's expensesView breakdown.
    static func totalsByCategory(_ expenses: [ExpenseEntry]) -> [String: Double] {
        Dictionary(grouping: expenses, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    /// Sums the deductible portion grouped by tax bucket, for the report/summary.
    static func deductibleByBucket(_ expenses: [ExpenseEntry]) -> [TaxBucket: Double] {
        Dictionary(grouping: expenses, by: \.bucket)
            .mapValues { $0.reduce(0) { $0 + $1.deductibleAmount } }
    }
}
