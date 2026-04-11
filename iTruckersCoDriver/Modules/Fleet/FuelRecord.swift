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
    var id: UUID = UUID()
    var date: Date = Date()
    var driverID: String = ""
    var gallons: Double = 0
    var pricePerGallon: Double = 0
    var odometer: Double = 0
    var stateCode: String = ""
    var stationName: String = ""

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
