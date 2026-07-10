//
//  CoDriverAIService.swift
//  iTruckersCoDriver
//
//  Common interface for the Co-Driver AI. AppleIntelligenceService conforms to
//  this so VoiceManager stays independent of the underlying model.
//

import Foundation

// MARK: - Tool handler protocol

/// Implemented by VoiceManager; the AI service calls these to perform app actions.
/// (Named for historical reasons; the app now runs on-device Apple Intelligence.)
protocol ClaudeToolHandler: AnyObject {
    func handleLogDutyStatus(status: String, notes: String?) async -> String
    func handleGetHOSSummary() async -> String
    func handleFindPlaces(type: String, radiusMiles: Int) async -> String
    func handleGetWeather(location: String?) async -> String
    func handleNavigateTo(destination: String) async -> String
    func handleSendDispatchMessage(message: String) async -> String
    func handleLogExpense(amount: Double, category: String, note: String?) async -> String
    func handleContactCustomer(loadNumber: String, message: String, channel: String) async -> String
    func handleGetDeliveryContact(loadNumber: String) async -> String
    func handleReportMaintenanceIssue(description: String, severity: String) async -> String
    func handleGetHealthSummary() async -> String
    func handleGetDocument(documentName: String) async -> String
    func handleCalculateProfit(loadRevenue: Double, miles: Double) async -> String
    func handleStartInspection() async -> String
    func handleContinueInspection() async -> String
}

protocol CoDriverAIService: AnyObject {
    /// The app-side handler that executes tool actions (implemented by VoiceManager).
    var toolHandler: (any ClaudeToolHandler)? { get set }

    /// Send a user message and receive a streaming response.
    /// - Parameters:
    ///   - text: The user's spoken message.
    ///   - history: Conversation history (used by stateless backends like Claude).
    ///   - onPartialResponse: Called on each streamed text chunk for real-time TTS.
    /// - Returns: The complete assistant response text.
    func sendMessage(
        _ text: String,
        history: [ConversationMessage],
        onPartialResponse: @escaping (String) -> Void
    ) async throws -> String

    /// Reset internal conversation context (e.g. when the driver starts a new session).
    func resetConversation()
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case appleIntelligenceUnavailable(String)
    case contextLengthExceeded

    var errorDescription: String? {
        switch self {
        case .appleIntelligenceUnavailable(let reason):
            return "Apple Intelligence unavailable: \(reason)"
        case .contextLengthExceeded:
            return "Conversation reset — context was too long."
        }
    }
}
