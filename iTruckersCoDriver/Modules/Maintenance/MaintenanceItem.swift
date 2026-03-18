//
//  MaintenanceItem.swift
//  iTruckersCoDriver
//
//  SwiftData model for scheduled maintenance (oil changes, tires, brakes, etc.)
//  with computed due/overdue status based on mileage or calendar interval.
//

import Foundation
import SwiftData

@Model
final class MaintenanceItem {
    var id: UUID
    var vehicleID: String
    var driverID: String
    var category: String        // "tires", "oil", "brakes", "filters", "lights", "other"
    var itemDescription: String
    var lastServiceDate: Date?
    var lastServiceMiles: Double
    var intervalMiles: Double   // 0 = not mileage-based
    var intervalDays: Int       // 0 = not calendar-based
    var currentOdometer: Double
    var isActive: Bool

    init(
        vehicleID: String,
        driverID: String,
        category: String,
        description: String,
        intervalMiles: Double = 0,
        intervalDays: Int = 0
    ) {
        self.id = UUID()
        self.vehicleID = vehicleID
        self.driverID = driverID
        self.category = category
        self.itemDescription = description
        self.lastServiceDate = nil
        self.lastServiceMiles = 0
        self.intervalMiles = intervalMiles
        self.intervalDays = intervalDays
        self.currentOdometer = 0
        self.isActive = true
    }

    var isDue: Bool {
        if intervalMiles > 0 && (currentOdometer - lastServiceMiles) >= intervalMiles { return true }
        if intervalDays > 0, let last = lastServiceDate {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            return daysSince >= intervalDays
        }
        return false
    }

    var isOverdue: Bool {
        if intervalMiles > 0 && (currentOdometer - lastServiceMiles) >= intervalMiles * 1.1 { return true }
        if intervalDays > 0, let last = lastServiceDate {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            return daysSince >= Int(Double(intervalDays) * 1.1)
        }
        return false
    }

    var nextDueDate: Date? {
        guard intervalDays > 0, let last = lastServiceDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: intervalDays, to: last)
    }

    var categoryIcon: String {
        switch category {
        case "tires": return "circle.dotted"
        case "oil": return "drop.fill"
        case "brakes": return "slowmo"
        case "filters": return "aqi.medium"
        case "lights": return "lightbulb.fill"
        default: return "wrench.fill"
        }
    }
}
