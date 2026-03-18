//
//  FuelRecord.swift
//  iTruckersCoDriver
//
//  SwiftData model for fuel fill-ups. Used to compute rolling avg MPG for IFTA.
//

import Foundation
import SwiftData

@Model
final class FuelRecord {
    var id: UUID
    var date: Date
    var driverID: String
    var gallons: Double
    var pricePerGallon: Double
    var odometer: Double
    var stateCode: String   // two-letter state code for IFTA
    var stationName: String

    init(
        driverID: String,
        gallons: Double,
        pricePerGallon: Double = 0,
        odometer: Double = 0,
        stateCode: String = "",
        stationName: String = ""
    ) {
        self.id = UUID()
        self.date = Date()
        self.driverID = driverID
        self.gallons = gallons
        self.pricePerGallon = pricePerGallon
        self.odometer = odometer
        self.stateCode = stateCode
        self.stationName = stationName
    }

    var totalCost: Double { gallons * pricePerGallon }
}
