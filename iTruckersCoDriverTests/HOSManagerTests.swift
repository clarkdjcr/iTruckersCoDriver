//
//  HOSManagerTests.swift
//  iTruckersCoDriverTests
//
//  FMCSA HOS calculations: 11-hour drive rule, 14-hour on-duty window,
//  30-minute break rule, 70/8 cycle, and 10-hour reset detection.
//

import XCTest
import SwiftData
@testable import iTruckersCoDriver

final class HOSManagerTests: XCTestCase {

    private func makeContext() -> ModelContext {
        let container = try! ModelContainer(
            for: HOSEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    /// Inserts entries, configures the manager (which triggers recalculate()),
    /// then spins the main queue so the manager's async summary update lands before asserting.
    private func configuredManager(entries: [(DutyStatus, Date)]) -> HOSManager {
        let context = makeContext()
        for (status, timestamp) in entries {
            let entry = HOSEntry(status: status)
            entry.timestamp = timestamp
            context.insert(entry)
        }
        try? context.save()

        let manager = HOSManager()
        manager.configure(with: context)

        let exp = expectation(description: "recalculate")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
        return manager
    }

    func test_noEntries_fullHOSAvailableAndCompliant() {
        let manager = configuredManager(entries: [])
        let s = manager.summary

        XCTAssertEqual(s.driveTimeRemaining, 11 * 3600, accuracy: 5)
        XCTAssertEqual(s.onDutyTimeRemaining, 14 * 3600, accuracy: 5)
        XCTAssertEqual(s.cycleHoursRemaining, 70 * 3600, accuracy: 5)
        XCTAssertTrue(s.isCompliant)
        XCTAssertTrue(s.alerts.isEmpty)
    }

    func test_approachingDriveLimit_triggersLowTimeAndBreakAlerts() {
        // Driving continuously for 10h45m — 15 min of drive time left, and well past
        // the 8-hour mark so a 30-minute break is also required.
        let manager = configuredManager(entries: [
            (.driving, Date().addingTimeInterval(-(10 * 3600 + 45 * 60)))
        ])
        let s = manager.summary

        XCTAssertEqual(s.driveTimeRemaining, 15 * 60, accuracy: 5)
        XCTAssertFalse(s.isCompliant)
        XCTAssertTrue(s.alerts.contains("Less than 1 hour of drive time remaining today."))
        XCTAssertTrue(s.alerts.contains("30-minute break required before driving."))
        XCTAssertEqual(s.breakTimeUntilRequired, 0)
    }

    func test_driveTimeExhausted_clampsToZero_notCompliant() {
        // 12 hours of straight driving exceeds the 11-hour rule.
        let manager = configuredManager(entries: [
            (.driving, Date().addingTimeInterval(-12 * 3600))
        ])
        let s = manager.summary

        XCTAssertEqual(s.driveTimeRemaining, 0)
        XCTAssertFalse(s.isCompliant)
        XCTAssertTrue(s.alerts.contains("Drive time limit reached. Rest required."))
    }

    func test_tenHourOffDutyPeriod_resetsClocks() {
        // Drove long ago, then took a qualifying 10h05m off-duty period that's still ongoing.
        let now = Date()
        let manager = configuredManager(entries: [
            (.driving, now.addingTimeInterval(-20 * 3600)),
            (.offDuty, now.addingTimeInterval(-(10 * 3600 + 5 * 60)))
        ])
        let s = manager.summary

        XCTAssertEqual(s.driveTimeRemaining, 11 * 3600, accuracy: 5)
        XCTAssertEqual(s.onDutyTimeRemaining, 14 * 3600, accuracy: 5)
        XCTAssertEqual(s.breakTimeUntilRequired, 8 * 3600, accuracy: 5)
        XCTAssertTrue(s.isCompliant)
    }

    /// Regression test for a reset-detection bug: findLastReset() used to measure the
    /// off-duty period's start from the *previous* (different-status) entry's timestamp
    /// instead of the off-duty entry's own timestamp, which inflated a short break into
    /// looking like a qualifying 10-hour reset. A 5-hour off-duty period must NOT reset
    /// the 11/14-hour clocks.
    func test_shortOffDutyPeriod_doesNotQualifyAsReset() {
        let now = Date()
        let manager = configuredManager(entries: [
            (.driving, now.addingTimeInterval(-12 * 3600)),
            (.offDuty, now.addingTimeInterval(-5 * 3600))
        ])
        let s = manager.summary

        // 7 hours of driving (from -12h to -5h) remain counted against the clock.
        XCTAssertEqual(s.driveTimeRemaining, 4 * 3600, accuracy: 5)
        XCTAssertEqual(s.onDutyTimeRemaining, 7 * 3600, accuracy: 5)
    }

    func test_cycleHours_accumulatesOnDutyTime() {
        let manager = configuredManager(entries: [
            (.onDuty, Date().addingTimeInterval(-5 * 3600))
        ])
        let s = manager.summary

        XCTAssertEqual(s.cycleHoursRemaining, 65 * 3600, accuracy: 5)
    }
}
