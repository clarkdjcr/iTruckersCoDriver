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

extension FuelRecord {
    /// Rolling average MPG from the most recent fill-ups, newest first by date.
    /// Mirrors the math in TelemetryManager.loadAvgMPG(); nil when there isn't enough data.
    static func averageMPG(from records: [FuelRecord], sampleSize: Int = 10) -> Double? {
        guard records.count >= 2 else { return nil }
        let recent = Array(records.sorted { $0.date > $1.date }.prefix(sampleSize))
        let totalGallons = recent.reduce(0) { $0 + $1.gallons }
        let odometerSpan = recent.first!.odometer - recent.last!.odometer
        guard totalGallons > 0 && odometerSpan > 0 else { return nil }
        return odometerSpan / totalGallons
    }
}
