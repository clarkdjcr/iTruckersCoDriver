//
//  TripRecord.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import Foundation
import SwiftData

@Model
final class TripRecord {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?
    var origin: String = ""
    var destination: String = ""
    var miles: Double = 0
    var fuelGallons: Double = 0
    var grossRevenue: Double = 0
    var notes: String = ""
    // IFTA state-by-state mileage stored as JSON string
    var stateMileageJSON: String = "{}"

    init(origin: String, destination: String) {
        self.id = UUID()
        self.startDate = Date()
        self.endDate = nil
        self.origin = origin
        self.destination = destination
        self.miles = 0
        self.fuelGallons = 0
        self.grossRevenue = 0
        self.notes = ""
        self.stateMileageJSON = "{}"
    }

    var isActive: Bool { endDate == nil }

    var profit: Double { grossRevenue - totalExpenses }

    var totalExpenses: Double { fuelCost }
    var fuelCost: Double { fuelGallons * 4.50 } // avg diesel price placeholder

    var stateMileage: [String: Double] {
        get {
            let data = stateMileageJSON.data(using: .utf8) ?? Data()
            return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data()
            stateMileageJSON = String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    func addStateMiles(_ miles: Double, state: String) {
        var current = stateMileage
        current[state, default: 0] += miles
        stateMileage = current
    }

    func complete(endMiles: Double, revenue: Double) {
        self.endDate = Date()
        self.miles = endMiles
        self.grossRevenue = revenue
    }
}
