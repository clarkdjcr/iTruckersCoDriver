//
//  CoDriverAIService.swift
//  iTruckersCoDriver
//
//  Common interface for AI backends. Both AppleIntelligenceService and ClaudeService
//  conform to this protocol so VoiceManager is backend-agnostic.
//

import Foundation

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
    case noAPIKey
    case contextLengthExceeded

    var errorDescription: String? {
        switch self {
        case .appleIntelligenceUnavailable(let reason):
            return "Apple Intelligence unavailable: \(reason)"
        case .noAPIKey:
            return "No Claude API key. Add one in Settings to use Claude."
        case .contextLengthExceeded:
            return "Conversation reset — context was too long."
        }
    }
}
