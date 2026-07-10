//
//  TaxBucketTests.swift
//  iTruckersCoDriverTests
//
//  Tax-bucket resolution, deductible math, and quarter date ranges used by
//  the Compliance > Expenses tab and the quarterly PDF/CSV reports.
//

import XCTest
@testable import iTruckersCoDriver

final class TaxBucketTests: XCTestCase {

    // MARK: - Bucket resolution

    func test_resolve_exactRawValues() {
        XCTAssertEqual(TaxBucket.resolve("travel"), .travel)
        XCTAssertEqual(TaxBucket.resolve("suppliesGear"), .suppliesGear)
        XCTAssertEqual(TaxBucket.resolve("technology"), .technology)
        XCTAssertEqual(TaxBucket.resolve("other"), .other)
    }

    func test_resolve_legacyAndSynonymCategories() {
        XCTAssertEqual(TaxBucket.resolve("lodging"), .travel)
        XCTAssertEqual(TaxBucket.resolve("Tolls"), .travel)
        XCTAssertEqual(TaxBucket.resolve("parking"), .travel)
        XCTAssertEqual(TaxBucket.resolve("safety"), .suppliesGear)
        XCTAssertEqual(TaxBucket.resolve("eld"), .technology)
        XCTAssertEqual(TaxBucket.resolve("phone"), .technology)
    }

    func test_resolve_unknownFallsBackToOther() {
        XCTAssertEqual(TaxBucket.resolve("fuel"), .other)
        XCTAssertEqual(TaxBucket.resolve("random-thing"), .other)
        XCTAssertEqual(TaxBucket.resolve(""), .other)
    }

    func test_supportsBusinessUse_onlyTechnology() {
        XCTAssertTrue(TaxBucket.technology.supportsBusinessUse)
        XCTAssertFalse(TaxBucket.travel.supportsBusinessUse)
        XCTAssertFalse(TaxBucket.suppliesGear.supportsBusinessUse)
        XCTAssertFalse(TaxBucket.other.supportsBusinessUse)
    }

    // MARK: - Deductible math

    func test_deductibleAmount_fullByDefault() {
        let e = ExpenseEntry(category: "travel", amount: 120)
        XCTAssertEqual(e.deductibleAmount, 120, accuracy: 0.001)
    }

    func test_deductibleAmount_appliesBusinessUsePercent() {
        let e = ExpenseEntry(category: "technology", amount: 100, note: "Phone", businessUsePercent: 60)
        XCTAssertEqual(e.deductibleAmount, 60, accuracy: 0.001)
    }

    func test_deductibleByBucket_sumsDeductiblePortionPerBucket() {
        let expenses = [
            ExpenseEntry(category: "travel", amount: 100),                               // 100
            ExpenseEntry(category: "lodging", amount: 50),                               // 50 -> travel
            ExpenseEntry(category: "technology", amount: 100, businessUsePercent: 50),   // 50
            ExpenseEntry(category: "suppliesGear", amount: 30)                           // 30
        ]

        let totals = ExpenseEntry.deductibleByBucket(expenses)

        XCTAssertEqual(totals[.travel] ?? 0, 150, accuracy: 0.001)
        XCTAssertEqual(totals[.technology] ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(totals[.suppliesGear] ?? 0, 30, accuracy: 0.001)
        XCTAssertNil(totals[.other])
    }

    func test_hasReceipt_reflectsImageData() {
        let e = ExpenseEntry(category: "travel", amount: 10)
        XCTAssertFalse(e.hasReceipt)
        e.receiptImageData = Data([0x01, 0x02])
        XCTAssertTrue(e.hasReceipt)
    }

    // MARK: - Quarter

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func test_quarter_dateRange_isHalfOpen() {
        let q2 = Quarter(year: 2026, quarter: 2)
        let range = q2.dateRange
        XCTAssertEqual(range.start, date(2026, 4, 1))
        XCTAssertEqual(range.end, date(2026, 7, 1))
    }

    func test_quarter_contains() {
        let q2 = Quarter(year: 2026, quarter: 2)
        XCTAssertTrue(q2.contains(date(2026, 5, 15)))
        XCTAssertTrue(q2.contains(date(2026, 4, 1)))    // inclusive start
        XCTAssertFalse(q2.contains(date(2026, 7, 1)))   // exclusive end
        XCTAssertFalse(q2.contains(date(2026, 3, 31)))
    }

    func test_quarter_previous_wrapsYear() {
        XCTAssertEqual(Quarter(year: 2026, quarter: 1).previous, Quarter(year: 2025, quarter: 4))
        XCTAssertEqual(Quarter(year: 2026, quarter: 3).previous, Quarter(year: 2026, quarter: 2))
    }

    func test_quarter_current_fromDate() {
        XCTAssertEqual(Quarter.current(for: date(2026, 5, 15)), Quarter(year: 2026, quarter: 2))
        XCTAssertEqual(Quarter.current(for: date(2026, 1, 1)), Quarter(year: 2026, quarter: 1))
        XCTAssertEqual(Quarter.current(for: date(2026, 12, 31)), Quarter(year: 2026, quarter: 4))
    }

    func test_recent_returnsDescendingQuarters() {
        let recent = Quarter.recent(count: 3, from: date(2026, 5, 15))
        XCTAssertEqual(recent, [
            Quarter(year: 2026, quarter: 2),
            Quarter(year: 2026, quarter: 1),
            Quarter(year: 2025, quarter: 4)
        ])
    }
}
