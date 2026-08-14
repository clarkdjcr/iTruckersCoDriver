//
//  ReceiptProcessingTests.swift
//  iTruckersCoDriverTests
//

import XCTest
@testable import iTruckersCoDriver

final class ReceiptProcessingTests: XCTestCase {
    func test_parseReceipt_extractsBookkeepingFields() {
        let results = [
            OCRResult(text: "LOVE'S TRAVEL STOP #123", confidence: 0.96),
            OCRResult(text: "Dallas, TX 75001", confidence: 0.92),
            OCRResult(text: "08/14/2026", confidence: 0.91),
            OCRResult(text: "Gallons 100.000", confidence: 0.95),
            OCRResult(text: "Price/Gal $3.499", confidence: 0.94),
            OCRResult(text: "Sales Tax $1.25", confidence: 0.90),
            OCRResult(text: "Total $351.15", confidence: 0.97),
            OCRResult(text: "VISA ****1234", confidence: 0.93)
        ]

        let receipt = DocumentProcessor.shared.parseReceipt(from: results)

        XCTAssertEqual(receipt.vendorName, "LOVE'S TRAVEL STOP #123")
        XCTAssertEqual(receipt.gallons ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(receipt.pricePerGallon ?? 0, 3.499, accuracy: 0.001)
        XCTAssertEqual(receipt.taxAmount ?? 0, 1.25, accuracy: 0.001)
        XCTAssertEqual(receipt.totalPrice ?? 0, 351.15, accuracy: 0.001)
        XCTAssertEqual(receipt.state, "TX")
        XCTAssertEqual(receipt.paymentMethod, "Visa")
        XCTAssertGreaterThan(receipt.confidence, 0.9)
    }

    func test_suggestedCategory_recognizesCommonOwnerOperatorReceipts() {
        XCTAssertEqual(TaxBucket.suggested(from: "Pilot Flying J Diesel Gallons"), .fuel)
        XCTAssertEqual(TaxBucket.suggested(from: "CAT Scale weigh ticket"), .scales)
        XCTAssertEqual(TaxBucket.suggested(from: "Roadside repair and parts"), .repairsMaintenance)
        XCTAssertEqual(TaxBucket.suggested(from: "Holiday Inn lodging"), .travel)
    }
}
