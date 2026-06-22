//
//  FuelRecordTests.swift
//  iTruckersCoDriverTests
//
//  Fuel cost and rolling average MPG (used for fuel-range estimates and IFTA).
//

import XCTest
@testable import iTruckersCoDriver

final class FuelRecordTests: XCTestCase {

    private func record(daysAgo: Int, gallons: Double, odometer: Double) -> FuelRecord {
        let r = FuelRecord(driverID: "driver1", gallons: gallons, odometer: odometer)
        r.date = Date().addingTimeInterval(-Double(daysAgo) * 86400)
        return r
    }

    func test_totalCost_multipliesGallonsByPrice() {
        let r = FuelRecord(driverID: "driver1", gallons: 100, pricePerGallon: 3.75)
        XCTAssertEqual(r.totalCost, 375, accuracy: 0.01)
    }

    func test_averageMPG_fewerThanTwoRecords_returnsNil() {
        let records = [record(daysAgo: 1, gallons: 50, odometer: 1000)]
        XCTAssertNil(FuelRecord.averageMPG(from: records))
        XCTAssertNil(FuelRecord.averageMPG(from: []))
    }

    func test_averageMPG_computesFromOdometerSpanAndGallons() {
        // Newest fill-up at the highest odometer reading, oldest at the lowest.
        let records = [
            record(daysAgo: 0, gallons: 60, odometer: 1600),
            record(daysAgo: 7, gallons: 55, odometer: 1200),
            record(daysAgo: 14, gallons: 0, odometer: 600) // oldest, defines the span
        ]
        // totalGallons = 60 + 55 + 0 = 115; odometerSpan = 1600 - 600 = 1000
        let mpg = FuelRecord.averageMPG(from: records)
        XCTAssertEqual(mpg!, 1000.0 / 115.0, accuracy: 0.001)
    }

    func test_averageMPG_onlyUsesMostRecentSample() {
        var records: [FuelRecord] = []
        for i in 0..<12 {
            records.append(record(daysAgo: i, gallons: 50, odometer: Double(2000 - i * 100)))
        }
        // Default sampleSize is 10: newest (daysAgo 0, odometer 2000) through
        // daysAgo 9 (odometer 1100). The two oldest records (daysAgo 10, 11) are excluded.
        let mpg = FuelRecord.averageMPG(from: records, sampleSize: 10)
        let expectedSpan = 2000.0 - 1100.0
        let expectedGallons = 50.0 * 10
        XCTAssertEqual(mpg!, expectedSpan / expectedGallons, accuracy: 0.001)
    }

    func test_averageMPG_zeroOdometerSpan_returnsNil() {
        let records = [
            record(daysAgo: 0, gallons: 50, odometer: 1000),
            record(daysAgo: 1, gallons: 50, odometer: 1000)
        ]
        XCTAssertNil(FuelRecord.averageMPG(from: records))
    }

    func test_averageMPG_zeroGallons_returnsNil() {
        let records = [
            record(daysAgo: 0, gallons: 0, odometer: 1500),
            record(daysAgo: 1, gallons: 0, odometer: 1000)
        ]
        XCTAssertNil(FuelRecord.averageMPG(from: records))
    }
}
