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
    
    // Advanced fields
    var fixedCostsPerMile: Double = 0.45 // placeholder: insurance, truck payment, etc.
    var currentAvgFuelPrice: Double = 4.50 // fallback average
    
    // IFTA state-by-state mileage stored as JSON string
    var stateMileageJSON: String = "{}"

    init(origin: String, destination: String, fixedCosts: Double = 0.45) {
        self.id = UUID()
        self.startDate = Date()
        self.endDate = nil
        self.origin = origin
        self.destination = destination
        self.miles = 0
        self.fuelGallons = 0
        self.grossRevenue = 0
        self.notes = ""
        self.fixedCostsPerMile = fixedCosts
        self.stateMileageJSON = "{}"
    }

    var isActive: Bool { endDate == nil }

    /// Calculates "True Profit": Revenue - (Fuel + Maintenance + Fixed Costs)
    var profit: Double { 
        grossRevenue - totalExpenses 
    }

    var totalExpenses: Double { 
        fuelCost + fixedExpenses
    }
    
    var fuelCost: Double { 
        fuelGallons * currentAvgFuelPrice 
    }
    
    var fixedExpenses: Double {
        miles * fixedCostsPerMile
    }

    var profitPerMile: Double {
        guard miles > 0 else { return 0 }
        return profit / miles
    }

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

    func complete(endMiles: Double, revenue: Double, avgFuelPrice: Double? = nil) {
        self.endDate = Date()
        self.miles = endMiles
        self.grossRevenue = revenue
        if let avgFuelPrice {
            self.currentAvgFuelPrice = avgFuelPrice
        }
    }
}
