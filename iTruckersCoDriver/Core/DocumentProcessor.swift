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
