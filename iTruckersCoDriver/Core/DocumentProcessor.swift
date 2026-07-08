//
//  DocumentProcessor.swift
//  iTruckersCoDriver
//
//  Created by Antigravity on 5/19/26.
//

import Foundation
import Vision
import VisionKit

struct OCRResult {
    let text: String
    let confidence: Float
}

struct ReceiptData {
    var date: Date?
    var gallons: Double?
    var totalPrice: Double?
    var state: String?
}

struct RateConfirmationData {
    var loadNumber: String?
    var brokerName: String?
    var origin: String?
    var destination: String?
    var pickupDate: Date?
    var deliveryDate: Date?
    var rate: Double?
}

class DocumentProcessor {
    static let shared = DocumentProcessor()
    
    private init() {}
    
    /// Processes an image to extract all text using Apple's Vision framework.
    func extractText(from image: CGImage) async throws -> [OCRResult] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let results = observations.compactMap { observation -> OCRResult? in
                    guard let topCandidate = observation.topCandidates(1).first else { return nil }
                    return OCRResult(text: topCandidate.string, confidence: topCandidate.confidence)
                }
                
                continuation.resume(returning: results)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Heuristic-based parsing for fuel receipts.
    /// In a production app, this would be more robust or use LLM-based extraction.
    func parseReceipt(from results: [OCRResult]) -> ReceiptData {
        var data = ReceiptData()
        
        for result in results {
            let text = result.text.lowercased()
            
            // Look for Gallons (e.g., "120.5 G" or "Gallons 120.5")
            if text.contains("gallons") || text.contains(" qty") {
                if let value = extractDouble(from: text) {
                    data.gallons = value
                }
            }
            
            // Look for Total Price
            if text.contains("total") || text.contains("amount") {
                if let value = extractDouble(from: text) {
                    data.totalPrice = value
                }
            }
            
            // Look for State codes (e.g., "TX", "CA")
            // Simple regex for 2 capital letters preceded by space/comma
            if let state = extractState(from: result.text) {
                data.state = state
            }
        }
        
        return data
    }
    
    /// Heuristic-based parsing for rate confirmations extracted via OCR.
    /// Best-effort only — the caller always presents an editable confirmation form.
    func parseRateConfirmation(from results: [OCRResult]) -> RateConfirmationData {
        parseRateConfirmation(fromLines: results.map { $0.text })
    }

    /// Heuristic-based parsing for rate confirmations shared as plain text
    /// (e.g. via the Share Extension from Messages). Reuses the same
    /// keyword/date heuristics as the OCR path, one line per line of text.
    func parseRateConfirmation(fromText text: String) -> RateConfirmationData {
        parseRateConfirmation(fromLines: text.components(separatedBy: .newlines))
    }

    private func parseRateConfirmation(fromLines lines: [String]) -> RateConfirmationData {
        var data = RateConfirmationData()

        let loadNumberKeywords = ["load #", "load#", "po #", "po#", "ref #", "ref#", "order #", "order#"]
        let brokerKeywords = ["broker", "carrier:", "billed to"]
        let brokerNameHints = ["llc", "inc", "logistics", "transport", "freight"]
        let originKeywords = ["origin", "pickup", "ship from", "pu:"]
        let destinationKeywords = ["destination", "delivery", "ship to", "consignee", "del:"]
        let rateKeywords = ["rate", "linehaul", "total"]

        for original in lines {
            let text = original.lowercased()

            if data.loadNumber == nil, loadNumberKeywords.contains(where: { text.contains($0) }) {
                data.loadNumber = extractTrailingToken(from: original)
            }

            if data.brokerName == nil {
                if brokerKeywords.contains(where: { text.contains($0) }) {
                    data.brokerName = extractTrailingToken(from: original, allowSpaces: true)
                } else if brokerNameHints.contains(where: { text.contains($0) }) {
                    data.brokerName = original.trimmingCharacters(in: .whitespaces)
                }
            }

            if data.origin == nil, originKeywords.contains(where: { text.contains($0) }) {
                data.origin = extractTrailingToken(from: original, allowSpaces: true)
            }

            if data.destination == nil, destinationKeywords.contains(where: { text.contains($0) }) {
                data.destination = extractTrailingToken(from: original, allowSpaces: true)
            }

            if data.rate == nil, rateKeywords.contains(where: { text.contains($0) }), let amount = extractDollarAmount(from: original) {
                data.rate = amount
            }
        }

        let (pickup, delivery) = extractDates(fromLines: lines, originKeywords: originKeywords, destinationKeywordsForDelivery: destinationKeywords)
        data.pickupDate = pickup
        data.deliveryDate = delivery

        return data
    }

    /// Grabs the text following a label's colon/keyword, e.g. "Load #: 12345" -> "12345".
    private func extractTrailingToken(from text: String, allowSpaces: Bool = false) -> String? {
        let parts = text.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        let candidate: String
        if parts.count == 2, !parts[1].isEmpty {
            candidate = parts[1]
        } else {
            candidate = text.trimmingCharacters(in: .whitespaces)
        }
        guard !candidate.isEmpty else { return nil }
        if allowSpaces {
            return candidate
        }
        return candidate.split(separator: " ").first.map(String.init) ?? candidate
    }

    private func extractDollarAmount(from text: String) -> Double? {
        let pattern = #"\$[\d,]+\.?\d{0,2}"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        guard let match = regex?.firstMatch(in: text, range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }
        let raw = nsString.substring(with: match.range)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(raw)
    }

    /// Finds calendar dates in the text and associates them with pickup/delivery
    /// based on proximity to labeled lines; falls back to document order.
    private func extractDates(fromLines lines: [String], originKeywords: [String], destinationKeywordsForDelivery: [String]) -> (pickup: Date?, delivery: Date?) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return (nil, nil)
        }

        var pickupDate: Date?
        var deliveryDate: Date?
        var orderedDates: [Date] = []

        for text in lines {
            let nsString = text as NSString
            let matches = detector.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            guard let date = matches.first?.date else { continue }

            orderedDates.append(date)

            let lower = text.lowercased()
            if pickupDate == nil, originKeywords.contains(where: { lower.contains($0) }) {
                pickupDate = date
            } else if deliveryDate == nil, destinationKeywordsForDelivery.contains(where: { lower.contains($0) }) {
                deliveryDate = date
            }
        }

        if pickupDate == nil { pickupDate = orderedDates.first }
        if deliveryDate == nil {
            deliveryDate = orderedDates.first { $0 != pickupDate } ?? orderedDates.dropFirst().first
        }

        return (pickupDate, deliveryDate)
    }

    private func extractDouble(from text: String) -> Double? {
        let pattern = #"\d+\.\d{1,3}"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        if let match = results?.first {
            return Double(nsString.substring(with: match.range))
        }
        return nil
    }
    
    private func extractState(from text: String) -> String? {
        let pattern = #"\b[A-Z]{2}\b"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        // Return the first match that looks like a state code
        for match in results ?? [] {
            let state = nsString.substring(with: match.range)
            // Common states list or just return if it's 2 chars
            return state
        }
        return nil
    }
}
