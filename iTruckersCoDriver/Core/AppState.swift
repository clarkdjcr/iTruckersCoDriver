//
//  AppState.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import Foundation
import Combine

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
    }

    var apiKey: String? {
        KeychainHelper.load(forKey: KeychainHelper.anthropicAPIKey)
    }

    var hasAPIKey: Bool { apiKey != nil && !(apiKey!.isEmpty) }
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
