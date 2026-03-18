//
//  DriverState.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import Foundation
import Combine
import CoreLocation
import MapKit

class DriverState: ObservableObject {
    @Published var conversationHistory: [ConversationMessage] = []
    @Published var currentDutyStatus: DutyStatus = .offDuty
    @Published var hosRemaining: HOSSummary = HOSSummary()
    @Published var currentLocation: CLLocation?
    @Published var activeRoute: MKRoute?
    @Published var unreadMessageCount: Int = 0
    @Published var isSpeaking: Bool = false
    @Published var isProcessingAI: Bool = false
    @Published var lastAIError: String?

    // Fleet telematics — updated by TelemetryManager
    @Published var currentSpeedMPH: Double = 0
    @Published var fuelLevel: Double = 0        // percentage 0–100
    @Published var estimatedRange: Double = 0   // miles on current fuel

    func addUserMessage(_ text: String) {
        conversationHistory.append(ConversationMessage(role: "user", content: text))
        if conversationHistory.count > 40 {
            conversationHistory = Array(conversationHistory.suffix(40))
        }
    }

    func addAssistantMessage(_ text: String) {
        conversationHistory.append(ConversationMessage(role: "assistant", content: text))
    }

    func clearConversation() {
        conversationHistory.removeAll()
    }
}
