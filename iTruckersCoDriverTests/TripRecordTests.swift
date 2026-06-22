//
//  TripRecordTests.swift
//  iTruckersCoDriverTests
//
//  IFTA mileage tracking and true-profit calculation (revenue minus fuel and fixed costs).
//

import XCTest
@testable import iTruckersCoDriver

final class TripRecordTests: XCTestCase {

    func test_initialState_isActiveWithNoExpenses() {
        let trip = TripRecord(origin: "Dallas, TX", destination: "Atlanta, GA", fixedCosts: 0.40)

        XCTAssertTrue(trip.isActive)
        XCTAssertEqual(trip.profit, 0)
        XCTAssertEqual(trip.stateMileage, [:])
    }

    func test_profitCalculation_subtractsFuelAndFixedCostsFromRevenue() {
        let trip = TripRecord(origin: "Dallas, TX", destination: "Atlanta, GA", fixedCosts: 0.45)
        trip.complete(endMiles: 1000, revenue: 2500, avgFuelPrice: 4.00)
        trip.fuelGallons = 150 // 1000 mi / ~6.7 MPG

        // fuelCost = 150 * 4.00 = 600; fixedExpenses = 1000 * 0.45 = 450
        XCTAssertEqual(trip.fuelCost, 600, accuracy: 0.01)
        XCTAssertEqual(trip.fixedExpenses, 450, accuracy: 0.01)
        XCTAssertEqual(trip.totalExpenses, 1050, accuracy: 0.01)
        XCTAssertEqual(trip.profit, 1450, accuracy: 0.01)
        XCTAssertEqual(trip.profitPerMile, 1.45, accuracy: 0.001)
    }

    func test_profitPerMile_zeroMiles_doesNotDivideByZero() {
        let trip = TripRecord(origin: "Dallas, TX", destination: "Atlanta, GA")
        XCTAssertEqual(trip.profitPerMile, 0)
    }

    func test_complete_setsEndDateAndRevenue() {
        let trip = TripRecord(origin: "Dallas, TX", destination: "Atlanta, GA")
        XCTAssertNil(trip.endDate)

        trip.complete(endMiles: 500, revenue: 1200)

        XCTAssertNotNil(trip.endDate)
        XCTAssertFalse(trip.isActive)
        XCTAssertEqual(trip.miles, 500)
        XCTAssertEqual(trip.grossRevenue, 1200)
    }

    func test_stateMileage_roundTripsThroughJSON() {
        let trip = TripRecord(origin: "Dallas, TX", destination: "Atlanta, GA")
        trip.addStateMiles(120, state: "TX")
        trip.addStateMiles(80, state: "LA")
        trip.addStateMiles(30, state: "TX") // accumulates into existing state

        XCTAssertEqual(trip.stateMileage["TX"], 150)
        XCTAssertEqual(trip.stateMileage["LA"], 80)
    }

    func test_aggregateStateMileage_sumsAcrossMultipleTrips() {
        let trip1 = TripRecord(origin: "Dallas, TX", destination: "Atlanta, GA")
        trip1.addStateMiles(100, state: "TX")
        trip1.addStateMiles(50, state: "LA")

        let trip2 = TripRecord(origin: "Atlanta, GA", destination: "Miami, FL")
        trip2.addStateMiles(20, state: "GA")
        trip2.addStateMiles(40, state: "TX")

        let totals = TripRecord.aggregateStateMileage([trip1, trip2])

        XCTAssertEqual(totals["TX"], 140)
        XCTAssertEqual(totals["LA"], 50)
        XCTAssertEqual(totals["GA"], 20)
    }

    func test_aggregateStateMileage_emptyTrips_returnsEmptyDictionary() {
        XCTAssertTrue(TripRecord.aggregateStateMileage([]).isEmpty)
    }
}
