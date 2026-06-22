//
//  ExpenseEntryTests.swift
//  iTruckersCoDriverTests
//
//  Category grouping/summing used by the Compliance > Expenses tab and tax exports.
//

import XCTest
@testable import iTruckersCoDriver

final class ExpenseEntryTests: XCTestCase {

    func test_totalsByCategory_sumsWithinEachCategory() {
        let expenses = [
            ExpenseEntry(category: "fuel", amount: 400),
            ExpenseEntry(category: "fuel", amount: 350),
            ExpenseEntry(category: "tolls", amount: 25.50),
            ExpenseEntry(category: "maintenance", amount: 120)
        ]

        let totals = ExpenseEntry.totalsByCategory(expenses)

        XCTAssertEqual(totals["fuel"], 750)
        XCTAssertEqual(totals["tolls"], 25.50)
        XCTAssertEqual(totals["maintenance"], 120)
    }

    func test_totalsByCategory_emptyExpenses_returnsEmptyDictionary() {
        XCTAssertTrue(ExpenseEntry.totalsByCategory([]).isEmpty)
    }

    func test_totalsByCategory_singleEntry_returnsItsOwnAmount() {
        let totals = ExpenseEntry.totalsByCategory([ExpenseEntry(category: "parking", amount: 15)])
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals["parking"], 15)
    }

    func test_init_setsDefaultsAndProvidedValues() {
        let expense = ExpenseEntry(category: "fuel", amount: 99.99, note: "Pilot #4521")
        XCTAssertEqual(expense.category, "fuel")
        XCTAssertEqual(expense.amount, 99.99, accuracy: 0.001)
        XCTAssertEqual(expense.note, "Pilot #4521")
    }
}
