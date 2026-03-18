//
//  HOSManager.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//
//  Implements FMCSA Hours of Service regulations:
//  - 11-hour driving rule (may drive max 11 hrs after 10 consecutive off)
//  - 14-hour on-duty window (cannot drive after 14 hours on duty)
//  - 30-minute break (must take 30-min break after 8 cumulative driving hours)
//  - 70/8 or 60/7 cycle (70 hrs in 8 days or 60 hrs in 7 days)
//

import Foundation
import Combine
import SwiftData

class HOSManager: ObservableObject {
    @Published var summary: HOSSummary = HOSSummary()
    @Published var todayEntries: [HOSEntry] = []

    private var modelContext: ModelContext?

    func configure(with context: ModelContext) {
        self.modelContext = context
        recalculate()
    }

    // MARK: - Log duty status change

    @discardableResult
    func logDutyChange(status: DutyStatus, location: String = "", notes: String = "") -> HOSEntry {
        let entry = HOSEntry(status: status, locationName: location, notes: notes)
        modelContext?.insert(entry)
        try? modelContext?.save()
        recalculate()
        return entry
    }

    // MARK: - Core HOS calculation

    func recalculate(entries: [HOSEntry]? = nil) {
        guard let context = modelContext else { return }

        let allEntries: [HOSEntry]
        if let entries {
            allEntries = entries
        } else {
            let descriptor = FetchDescriptor<HOSEntry>(sortBy: [SortDescriptor(\.timestamp)])
            allEntries = (try? context.fetch(descriptor)) ?? []
        }

        let now = Date()
        let calendar = Calendar.current

        // Find the start of the current 10-hour reset
        // A 10-hour consecutive off-duty / sleeper period resets the 11-hour & 14-hour clock
        var resetTime = now - (14 * 3600) // default: start of 14-hour window

        // Find the last 10-consecutive-hour off/sleeper period
        if let reset = findLastReset(in: allEntries, before: now) {
            resetTime = reset
        }

        // Calculate driving time since reset
        let drivingSeconds = totalDrivingSeconds(in: allEntries, from: resetTime, to: now)
        let onDutySeconds = totalOnDutySeconds(in: allEntries, from: resetTime, to: now)

        let maxDrive = 11.0 * 3600
        let maxOnDuty = 14.0 * 3600
        let driveRemaining = max(0, maxDrive - drivingSeconds)
        let onDutyRemaining = max(0, maxOnDuty - onDutySeconds)

        // 30-minute break: required after 8 hours of cumulative driving without a 30-min break
        let breakRequired = requiresBreak(in: allEntries, from: resetTime, to: now)
        let breakTimeRemaining = breakRequired ? 0 : max(0, (8 * 3600) - drivingSeconds)

        // Cycle calculation (last 8 days)
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: now)!
        let cycleOnDutySeconds = totalOnDutySeconds(in: allEntries, from: eightDaysAgo, to: now)
        let maxCycle = 70.0 * 3600
        let cycleRemaining = max(0, maxCycle - cycleOnDutySeconds)

        // Build alerts
        var alerts: [String] = []
        if driveRemaining < 3600 && driveRemaining > 0 {
            alerts.append("Less than 1 hour of drive time remaining today.")
        }
        if onDutyRemaining < 3600 && onDutyRemaining > 0 {
            alerts.append("Less than 1 hour in your 14-hour window.")
        }
        if breakRequired {
            alerts.append("30-minute break required before driving.")
        }
        if driveRemaining == 0 {
            alerts.append("Drive time limit reached. Rest required.")
        }

        let todayStart = calendar.startOfDay(for: now)
        let todayList = allEntries.filter { $0.timestamp >= todayStart }

        DispatchQueue.main.async {
            self.summary = HOSSummary(
                driveTimeRemaining: driveRemaining,
                onDutyTimeRemaining: onDutyRemaining,
                breakTimeUntilRequired: breakTimeRemaining,
                cycleHoursRemaining: cycleRemaining,
                currentCycleDay: self.currentCycleDay(entries: allEntries),
                isCompliant: alerts.isEmpty,
                alerts: alerts
            )
            self.todayEntries = todayList
        }
    }

    // MARK: - Helpers

    private func findLastReset(in entries: [HOSEntry], before date: Date) -> Date? {
        // Find the end of the most recent ≥10 consecutive hours of off duty or sleeper
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        var i = sorted.count - 1
        while i >= 0 {
            let entry = sorted[i]
            if entry.dutyStatus == .offDuty || entry.dutyStatus == .sleeperBerth {
                // Find when this off/sleeper period started
                let periodStart = i > 0 ? sorted[i - 1].timestamp : sorted[i].timestamp - (10 * 3600)
                let periodEnd = i < sorted.count - 1 ? sorted[i + 1].timestamp : date
                if periodEnd.timeIntervalSince(periodStart) >= (10 * 3600) {
                    return periodEnd
                }
            }
            i -= 1
        }
        return nil
    }

    private func totalDrivingSeconds(in entries: [HOSEntry], from start: Date, to end: Date) -> TimeInterval {
        return totalSeconds(for: [.driving], in: entries, from: start, to: end)
    }

    private func totalOnDutySeconds(in entries: [HOSEntry], from start: Date, to end: Date) -> TimeInterval {
        return totalSeconds(for: [.driving, .onDuty], in: entries, from: start, to: end)
    }

    private func totalSeconds(for statuses: [DutyStatus], in entries: [HOSEntry], from start: Date, to end: Date) -> TimeInterval {
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        var total: TimeInterval = 0
        for i in 0..<sorted.count {
            let entry = sorted[i]
            guard statuses.contains(entry.dutyStatus) else { continue }
            let periodStart = max(entry.timestamp, start)
            let periodEnd: Date
            if i + 1 < sorted.count {
                periodEnd = min(sorted[i + 1].timestamp, end)
            } else {
                periodEnd = end
            }
            if periodEnd > periodStart {
                total += periodEnd.timeIntervalSince(periodStart)
            }
        }
        return total
    }

    private func requiresBreak(in entries: [HOSEntry], from start: Date, to now: Date) -> Bool {
        // Must take 30-min break after 8 cumulative hours of driving
        var cumulativeDrive: TimeInterval = 0
        let sorted = entries.filter { $0.timestamp >= start && $0.timestamp <= now }
            .sorted { $0.timestamp < $1.timestamp }

        for i in 0..<sorted.count {
            let entry = sorted[i]
            let periodEnd = i + 1 < sorted.count ? sorted[i + 1].timestamp : now
            if entry.dutyStatus == .driving {
                cumulativeDrive += periodEnd.timeIntervalSince(entry.timestamp)
            } else if (entry.dutyStatus == .offDuty || entry.dutyStatus == .sleeperBerth) {
                let breakDuration = periodEnd.timeIntervalSince(entry.timestamp)
                if breakDuration >= 1800 { // 30 minutes
                    cumulativeDrive = 0
                }
            }
        }
        return cumulativeDrive >= (8 * 3600)
    }

    private func currentCycleDay(entries: [HOSEntry]) -> Int {
        // Find how long into the 8-day cycle we are from the last reset
        guard let context = modelContext else { return 1 }
        let eightDaysAgo = Date() - (8 * 24 * 3600)
        let descriptor = FetchDescriptor<HOSEntry>(sortBy: [SortDescriptor(\.timestamp)])
        let all = (try? context.fetch(descriptor)) ?? []
        let recent = all.filter { $0.timestamp >= eightDaysAgo }
        guard let first = recent.first else { return 1 }
        return (Calendar.current.dateComponents([.day], from: first.timestamp, to: Date()).day ?? 0) + 1
    }

    // MARK: - Human-readable summary for Claude

    func summaryText() -> String {
        let s = summary
        var text = """
        HOS Status:
        - Drive time remaining: \(s.driveTimeRemainingFormatted) (11-hour rule)
        - On-duty window remaining: \(s.onDutyTimeRemainingFormatted) (14-hour rule)
        - Cycle hours remaining: \(s.cycleHoursRemainingFormatted) (70/8 cycle)
        - Compliance: \(s.isCompliant ? "Compliant ✓" : "Issues present ⚠️")
        """
        if !s.alerts.isEmpty {
            text += "\n- Alerts: " + s.alerts.joined(separator: "; ")
        }
        return text
    }

    // MARK: - Paper log export

    func exportPaperLog() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var log = "HOS LOG — \(formatter.string(from: Date()))\n"
        log += String(repeating: "=", count: 40) + "\n"
        for entry in todayEntries.sorted(by: { $0.timestamp < $1.timestamp }) {
            log += "\(formatter.string(from: entry.timestamp)) | \(entry.dutyStatus.displayName)"
            if !entry.locationName.isEmpty { log += " @ \(entry.locationName)" }
            if !entry.notes.isEmpty { log += " (\(entry.notes))" }
            log += "\n"
        }
        return log
    }
}
