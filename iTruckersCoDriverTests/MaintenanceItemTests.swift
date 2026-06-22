//
//  MaintenanceItemTests.swift
//  iTruckersCoDriverTests
//
//  Due/overdue status for mileage-based and calendar-based maintenance intervals.
//

import XCTest
@testable import iTruckersCoDriver

final class MaintenanceItemTests: XCTestCase {

    private func item(intervalMiles: Double = 0, intervalDays: Int = 0) -> MaintenanceItem {
        MaintenanceItem(
            vehicleID: "truck1",
            driverID: "driver1",
            category: "oil",
            description: "Oil change",
            intervalMiles: intervalMiles,
            intervalDays: intervalDays
        )
    }

    // MARK: - Mileage-based

    func test_mileageBased_notDueBeforeInterval() {
        let m = item(intervalMiles: 5000)
        m.lastServiceMiles = 10_000
        m.currentOdometer = 14_000 // 4000 mi since service, interval is 5000

        XCTAssertFalse(m.isDue)
        XCTAssertFalse(m.isOverdue)
    }

    func test_mileageBased_dueAtInterval() {
        let m = item(intervalMiles: 5000)
        m.lastServiceMiles = 10_000
        m.currentOdometer = 15_000 // exactly at interval

        XCTAssertTrue(m.isDue)
        XCTAssertFalse(m.isOverdue) // overdue threshold is 1.1x
    }

    func test_mileageBased_overdueAt110Percent() {
        let m = item(intervalMiles: 5000)
        m.lastServiceMiles = 10_000
        m.currentOdometer = 15_500 // 5500 mi since service, 110% of interval

        XCTAssertTrue(m.isDue)
        XCTAssertTrue(m.isOverdue)
    }

    // MARK: - Calendar-based

    func test_dayBased_notDueBeforeInterval() {
        let m = item(intervalDays: 90)
        m.lastServiceDate = Date().addingTimeInterval(-60 * 86400)

        XCTAssertFalse(m.isDue)
        XCTAssertFalse(m.isOverdue)
    }

    func test_dayBased_dueAfterInterval() {
        let m = item(intervalDays: 90)
        m.lastServiceDate = Date().addingTimeInterval(-95 * 86400)

        XCTAssertTrue(m.isDue)
        XCTAssertFalse(m.isOverdue) // overdue threshold is 99 days (90 * 1.1)
    }

    func test_dayBased_overdueAt110Percent() {
        let m = item(intervalDays: 90)
        m.lastServiceDate = Date().addingTimeInterval(-100 * 86400)

        XCTAssertTrue(m.isDue)
        XCTAssertTrue(m.isOverdue)
    }

    func test_noLastServiceDate_dayBasedNeverDue() {
        let m = item(intervalDays: 90)
        XCTAssertNil(m.lastServiceDate)
        XCTAssertFalse(m.isDue)
        XCTAssertNil(m.nextDueDate)
    }

    func test_zeroIntervals_neverDue() {
        let m = item() // both intervals 0
        m.lastServiceMiles = 0
        m.currentOdometer = 999_999
        m.lastServiceDate = Date().addingTimeInterval(-999 * 86400)

        XCTAssertFalse(m.isDue)
        XCTAssertFalse(m.isOverdue)
    }

    func test_nextDueDate_addsIntervalDaysToLastService() {
        let m = item(intervalDays: 30)
        let last = Date().addingTimeInterval(-10 * 86400)
        m.lastServiceDate = last

        let expected = Calendar.current.date(byAdding: .day, value: 30, to: last)!
        XCTAssertEqual(m.nextDueDate!.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }
}
