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
    private var locationManager = CLLocationManager()
    private var currentState: String?
    private var lastLocation: CLLocation?

    // Set by DriverView after init
    weak var driverState: DriverState?
    /// Called on the main queue when the truck crosses a state line. Receives the new state name.
    var onStateCrossing: ((String) -> Void)?

    func configure(driverID: String, context: ModelContext) {
        self.driverID = driverID
        self.modelContext = context
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
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
        // Timer.scheduledTimer requires the main run loop to fire reliably.
        DispatchQueue.main.async { [weak self] in
            self?.telemetryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.writeTelemetrySnapshot()
            }
        }
    }

    private func recalculateRange() {
        estimatedRangeMiles = fuelLevelGallons * avgMPG
        let range = estimatedRangeMiles
        DispatchQueue.main.async { [weak self] in
            self?.driverState?.estimatedRange = range
        }
    }

    private func pushToDriverState() {
        let speed = currentSpeedMPH
        let fuel = fuelPercent
        let range = estimatedRangeMiles
        DispatchQueue.main.async { [weak self] in
            self?.driverState?.currentSpeedMPH = speed
            self?.driverState?.fuelLevel = fuel
            self?.driverState?.estimatedRange = range
        }
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

extension TelemetryManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let speedMPH = max(0, location.speed * 2.23694)
        updateSpeed(speedMPH)
        
        // Calculate mileage if we have a last location
        if let last = lastLocation {
            let distanceMeters = location.distance(from: last)
            let distanceMiles = distanceMeters / 1609.34
            if distanceMiles > 0.01 { // noise threshold
                updateOdometer(currentOdometer + distanceMiles)
                recordIFTAMileage(distanceMiles)
            }
        }
        
        lastLocation = location
        detectStateChange(for: location)
    }
    
    private func detectStateChange(for location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self,
                  let state = placemarks?.first?.administrativeArea,
                  state != self.currentState else { return }
            let isFirstDetection = self.currentState == nil
            self.currentState = state
            guard !isFirstDetection else { return }
            DispatchQueue.main.async { self.onStateCrossing?(state) }
        }
    }
    
    private func recordIFTAMileage(_ miles: Double) {
        guard let state = currentState, let context = modelContext else { return }
        
        // Find active TripRecord
        let descriptor = FetchDescriptor<TripRecord>(
            predicate: #Predicate { $0.endDate == nil }
        )
        if let activeTrip = (try? context.fetch(descriptor))?.first {
            activeTrip.addStateMiles(miles, state: state)
            try? context.save()
        }
    }
}
#endif
