//
//  HealthManager.swift
//  iTruckersCoDriver
//
//  iOS-only. HealthKit authorization and fatigue scoring.
//  Health data never leaves the device without explicit driver opt-in.
//  Dispatcher sees only a binary fatigue alert flag, not raw health data.
//

#if os(iOS)
import Foundation
import HealthKit
import Combine

class HealthManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var currentHeartRate: Double = 0
    @Published var restingHeartRate: Double = 0
    @Published var sleepHoursLast24: Double = 0
    @Published var hrv: Double = 0              // heart rate variability (ms)
    @Published var fatigueScore: Int = 0        // 0–100; higher = more fatigued

    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let hr  = HKObjectType.quantityType(forIdentifier: .heartRate)            { types.insert(hr)  }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate)      { types.insert(rhr) }
        if let slp = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)         { types.insert(slp) }
        return types
    }()

    var hasFatigueAlert: Bool { fatigueScore >= 70 }

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        store.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success { self?.fetchLatestData() }
            }
        }
    }

    func fetchLatestData() {
        fetchLatestHeartRate()
        fetchRestingHeartRate()
        fetchHRV()
        fetchSleepHours()
    }

    func summaryText() -> String {
        """
        Heart rate: \(Int(currentHeartRate)) bpm (resting: \(Int(restingHeartRate)) bpm)
        HRV: \(Int(hrv)) ms
        Sleep last 24h: \(String(format: "%.1f", sleepHoursLast24)) hrs
        Fatigue score: \(fatigueScore)/100\(hasFatigueAlert ? " ⚠️ Consider taking a break." : "")
        """
    }

    // MARK: - HealthKit Queries

    private func fetchLatestHeartRate() {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async {
                self?.currentHeartRate = bpm
                self?.recalculateFatigue()
            }
        }
        store.execute(query)
    }

    private func fetchRestingHeartRate() {
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            DispatchQueue.main.async {
                self?.restingHeartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }
        }
        store.execute(query)
    }

    private func fetchHRV() {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let ms = sample.quantity.doubleValue(for: HKUnit(from: "ms"))
            DispatchQueue.main.async {
                self?.hrv = ms
                self?.recalculateFatigue()
            }
        }
        store.execute(query)
    }

    private func fetchSleepHours() {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let yesterday = Date().addingTimeInterval(-24 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: Date())
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            let total = samples?
                .compactMap { $0 as? HKCategorySample }
                .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0
            DispatchQueue.main.async {
                self?.sleepHoursLast24 = total / 3600
                self?.recalculateFatigue()
            }
        }
        store.execute(query)
    }

    private func recalculateFatigue() {
        var score = 0
        
        // 1. Sleep debt (Primary factor)
        if sleepHoursLast24 < 4 { score += 50 }
        else if sleepHoursLast24 < 5.5 { score += 35 }
        else if sleepHoursLast24 < 7 { score += 15 }
        
        // 2. Physiological Strain (HR relative to resting)
        if restingHeartRate > 0 && currentHeartRate > restingHeartRate * 1.4 { 
            score += 25 // High strain
        } else if restingHeartRate > 0 && currentHeartRate > restingHeartRate * 1.2 {
            score += 10 // Moderate strain
        }
        
        // 3. Autonomic Nervous System Recovery (HRV)
        // Values < 20ms typically indicate high stress/fatigue in most adults
        if hrv > 0 && hrv < 20 { score += 35 }
        else if hrv > 0 && hrv < 45 { score += 20 }
        
        // 4. Time of Day Effect (Circadian Rhythm)
        let hour = Calendar.current.component(.hour, from: Date())
        if (0...4).contains(hour) || (13...15).contains(hour) {
            score += 10 // Natural circadian dips
        }
        
        fatigueScore = min(score, 100)
    }
}
#endif
