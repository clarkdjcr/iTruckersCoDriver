//
//  VehicleMetrics.swift
//  iTruckersCoDriver
//
//  SwiftData model for telematics: GPS location, speed, fuel level.
//  Written by TelemetryManager every 60s and synced via CloudKit.
//

import Foundation
import SwiftData

@Model
final class VehicleMetrics {
    var id: UUID
    var timestamp: Date
    var driverID: String
    var latitude: Double
    var longitude: Double
    var speedMPH: Double
    var fuelLevelGallons: Double
    var fuelCapacityGallons: Double
    var odometer: Double    // miles

    init(
        driverID: String,
        latitude: Double = 0,
        longitude: Double = 0,
        speedMPH: Double = 0,
        fuelLevelGallons: Double = 0,
        fuelCapacityGallons: Double = 150,
        odometer: Double = 0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.driverID = driverID
        self.latitude = latitude
        self.longitude = longitude
        self.speedMPH = speedMPH
        self.fuelLevelGallons = fuelLevelGallons
        self.fuelCapacityGallons = fuelCapacityGallons
        self.odometer = odometer
    }

    var fuelPercent: Double {
        guard fuelCapacityGallons > 0 else { return 0 }
        return (fuelLevelGallons / fuelCapacityGallons) * 100
    }

    var isLowFuel: Bool { fuelPercent < 20 }
}
