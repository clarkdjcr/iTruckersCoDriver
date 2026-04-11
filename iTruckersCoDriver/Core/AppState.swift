//
//  AppState.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import Foundation
import Combine
import FoundationModels

// MARK: - Conversation message model

struct ConversationMessage: Identifiable, Codable {
    let id: UUID
    let role: String  // "user" or "assistant"
    var content: String
    let timestamp: Date

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Shared session state (both driver and dispatcher)

class AppState: ObservableObject {
    @Published var driverName: String {
        didSet { UserDefaults.standard.set(driverName, forKey: "driverName") }
    }
    @Published var hosCycle: HOSCycle {
        didSet { UserDefaults.standard.set(hosCycle.rawValue, forKey: "hosCycle") }
    }
    @Published var cdlState: String {
        didSet { UserDefaults.standard.set(cdlState, forKey: "cdlState") }
    }
    @Published var healthMonitoringEnabled: Bool {
        didSet { UserDefaults.standard.set(healthMonitoringEnabled, forKey: "healthMonitoringEnabled") }
    }
    @Published var activeBackend: AIBackend {
        didSet { UserDefaults.standard.set(activeBackend.rawValue, forKey: "aiBackend") }
    }

    /// Stable per-device UUID. Created once and persisted — identifies this driver in CloudKit.
    let driverID: String

    init() {
        self.driverName = UserDefaults.standard.string(forKey: "driverName") ?? ""
        let cycleRaw = UserDefaults.standard.string(forKey: "hosCycle") ?? ""
        self.hosCycle = HOSCycle(rawValue: cycleRaw) ?? .seventyHour
        self.cdlState = UserDefaults.standard.string(forKey: "cdlState") ?? ""
        self.healthMonitoringEnabled = UserDefaults.standard.bool(forKey: "healthMonitoringEnabled")

        if let existing = UserDefaults.standard.string(forKey: "driverID") {
            self.driverID = existing
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "driverID")
            self.driverID = newID
        }

        // Default to Apple Intelligence when available; fall back to Claude otherwise.
        let savedRaw = UserDefaults.standard.string(forKey: "aiBackend")
        let savedBackend: AIBackend? = savedRaw.flatMap { AIBackend(rawValue: $0) }
        let supportsAppleIntelligence: Bool
        if case .available = SystemLanguageModel.default.availability {
            supportsAppleIntelligence = true
        } else {
            supportsAppleIntelligence = false
        }
        self.activeBackend = savedBackend ?? (supportsAppleIntelligence ? .appleIntelligence : .claude)
    }

    var apiKey: String? {
        KeychainHelper.load(forKey: KeychainHelper.anthropicAPIKey)
    }

    var hasAPIKey: Bool { apiKey != nil && !(apiKey!.isEmpty) }

    /// Whether this device can run Apple Intelligence at runtime.
    var isAppleIntelligenceAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }
}

// MARK: - HOS Types

enum DutyStatus: String, Codable, CaseIterable {
    case offDuty = "off_duty"
    case sleeperBerth = "sleeper"
    case driving = "driving"
    case onDuty = "on_duty"

    var displayName: String {
        switch self {
        case .offDuty: return "Off Duty"
        case .sleeperBerth: return "Sleeper Berth"
        case .driving: return "Driving"
        case .onDuty: return "On Duty (Not Driving)"
        }
    }

    var color: String {
        switch self {
        case .offDuty: return "gray"
        case .sleeperBerth: return "purple"
        case .driving: return "red"
        case .onDuty: return "orange"
        }
    }

    var systemImage: String {
        switch self {
        case .offDuty: return "moon.fill"
        case .sleeperBerth: return "bed.double.fill"
        case .driving: return "truck.box.fill"
        case .onDuty: return "briefcase.fill"
        }
    }
}

enum HOSCycle: String, CaseIterable {
    case sixtyHour = "60/7"
    case seventyHour = "70/8"
}

struct HOSSummary {
    var driveTimeRemaining: TimeInterval = 11 * 3600
    var onDutyTimeRemaining: TimeInterval = 14 * 3600
    var breakTimeUntilRequired: TimeInterval = 8 * 3600
    var cycleHoursRemaining: TimeInterval = 70 * 3600
    var currentCycleDay: Int = 1
    var isCompliant: Bool = true
    var alerts: [String] = []

    var driveTimeRemainingFormatted: String { formatInterval(driveTimeRemaining) }
    var onDutyTimeRemainingFormatted: String { formatInterval(onDutyTimeRemaining) }
    var cycleHoursRemainingFormatted: String { formatInterval(cycleHoursRemaining) }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}
