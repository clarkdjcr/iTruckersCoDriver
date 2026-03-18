//
//  TelemetryManager.swift
//  iTruckersCoDriver
//
//  iOS-only. Polls location + speed every 60s, computes fuel reserve range,
//  writes VehicleMetrics snapshots to SwiftData for CloudKit sync.
//

#if os(iOS)
import Foundation
import CoreLocation
import Combine
import SwiftData

class TelemetryManager: NSObject, ObservableObject {
    @Published var currentSpeedMPH: Double = 0
    @Published var fuelLevelGallons: Double = 0
    @Published var fuelCapacityGallons: Double = 150   // default 150-gal tank
    @Published var estimatedRangeMiles: Double = 0
    @Published var currentOdometer: Double = 0

    private var modelContext: ModelContext?
    private var driverID: String = ""
    private var telemetryTimer: Timer?
    private var avgMPG: Double = 6.5  // typical loaded truck default

    // Set by DriverView after init
    weak var driverState: DriverState?

    func configure(driverID: String, context: ModelContext) {
        self.driverID = driverID
        self.modelContext = context
        loadAvgMPG()
        startTelemetry()
    }

    func updateFuelLevel(gallons: Double, capacity: Double? = nil) {
        fuelLevelGallons = gallons
        if let cap = capacity { fuelCapacityGallons = cap }
        recalculateRange()
        pushToDriverState()
    }

    func updateOdometer(_ miles: Double) {
        currentOdometer = miles
    }

    func updateSpeed(_ mph: Double) {
        currentSpeedMPH = mph
        pushToDriverState()
    }

    var fuelPercent: Double {
        guard fuelCapacityGallons > 0 else { return 0 }
        return (fuelLevelGallons / fuelCapacityGallons) * 100
    }

    var isLowFuel: Bool { fuelPercent < 20 }

    // MARK: - Private

    private func startTelemetry() {
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.writeTelemetrySnapshot()
        }
    }

    private func recalculateRange() {
        estimatedRangeMiles = fuelLevelGallons * avgMPG
        driverState?.estimatedRange = estimatedRangeMiles
    }

    private func pushToDriverState() {
        driverState?.currentSpeedMPH = currentSpeedMPH
        driverState?.fuelLevel = fuelPercent
        driverState?.estimatedRange = estimatedRangeMiles
    }

    private func loadAvgMPG() {
        guard let context = modelContext else { return }
        let id = driverID
        let descriptor = FetchDescriptor<FuelRecord>(
            predicate: #Predicate { $0.driverID == id },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        if records.count >= 2 {
            let recent = Array(records.prefix(10))
            let totalGallons = recent.reduce(0) { $0 + $1.gallons }
            let odometerSpan = recent.first!.odometer - recent.last!.odometer
            if totalGallons > 0 && odometerSpan > 0 {
                avgMPG = odometerSpan / totalGallons
            }
        }
        recalculateRange()
    }

    private func writeTelemetrySnapshot() {
        guard let context = modelContext else { return }
        let metrics = VehicleMetrics(
            driverID: driverID,
            speedMPH: currentSpeedMPH,
            fuelLevelGallons: fuelLevelGallons,
            fuelCapacityGallons: fuelCapacityGallons,
            odometer: currentOdometer
        )
        context.insert(metrics)
        try? context.save()
    }

    deinit {
        telemetryTimer?.invalidate()
    }
}
#endif
