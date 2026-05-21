//
//  DVIRManager.swift
//  iTruckersCoDriver
//
//  Created by Antigravity on 5/19/26.
//

import Foundation
import Combine

enum InspectionStep: String, CaseIterable {
    case general = "General walkaround"
    case tires = "Tires and wheels"
    case brakes = "Brake system"
    case lights = "Lights and reflectors"
    case engine = "Engine compartment"
    case coupling = "Fifth wheel and coupling"
    case safety = "Safety equipment (fire extinguisher, triangles)"
    case complete = "Inspection complete"
    
    var prompt: String {
        switch self {
        case .general: return "Let's start the pre-trip. Check the overall condition of the truck and trailer. Any visible leaks or damage?"
        case .tires: return "Check all tires for tread depth and pressure. Are all wheels secured with no missing lug nuts?"
        case .brakes: return "Inspect the brake lines and drums. Do you hear any air leaks or see worn components?"
        case .lights: return "Test all lights: headlights, turn signals, and brake lights. Are they all working?"
        case .engine: return "Check oil, coolant, and power steering fluid levels. Any issues under the hood?"
        case .coupling: return "Check the fifth wheel jaw and locking pin. Is the trailer securely coupled?"
        case .safety: return "Verify your fire extinguisher is charged and you have your warning triangles. All good?"
        case .complete: return "Great job. Pre-trip inspection is complete and logged. Safe travels!"
        }
    }
}

class DVIRManager: ObservableObject {
    @Published var currentStepIndex: Int = -1
    @Published var isInspectionActive: Bool = false
    @Published var issuesFound: [String] = []
    
    var currentStep: InspectionStep? {
        guard currentStepIndex >= 0 && currentStepIndex < InspectionStep.allCases.count else { return nil }
        return InspectionStep.allCases[currentStepIndex]
    }
    
    func startInspection() -> String {
        isInspectionActive = true
        currentStepIndex = 0
        issuesFound = []
        return InspectionStep.allCases[0].prompt
    }
    
    func processResponse(_ response: String) -> String {
        guard isInspectionActive, let step = currentStep else { return "" }
        
        let responseLower = response.lowercased()
        let negativeResponses = ["no", "problem", "issue", "leak", "damage", "broken", "missing", "bad", "worn"]
        
        if negativeResponses.contains(where: { responseLower.contains($0) }) {
            issuesFound.append("\(step.rawValue): \(response)")
        }
        
        currentStepIndex += 1
        
        if let nextStep = currentStep {
            return nextStep.prompt
        } else {
            isInspectionActive = false
            return finalizeInspection()
        }
    }
    
    private func finalizeInspection() -> String {
        let summary = issuesFound.isEmpty ? "No issues reported." : "Issues found: \(issuesFound.joined(separator: "; "))."
        return "Inspection complete. \(summary) I've logged this to your maintenance records."
    }
}
