//
//  AppleIntelligenceService.swift
//  iTruckersCoDriver
//
//  On-device AI backend using Apple's Foundation Models framework (iOS 26 / macOS 26).
//  No API key required. Requires iPhone 15 Pro or later, or M1+ Mac.
//
//  The LanguageModelSession maintains its own conversation history, so the `history`
//  parameter from the protocol is intentionally unused — the session accumulates context.
//

import Foundation
import FoundationModels

// MARK: - Tool Handler Reference

/// Sendable wrapper holding a weak reference to the ClaudeToolHandler.
/// @unchecked Sendable is safe here — all accesses are serialised through async/await.
final class ToolHandlerRef: @unchecked Sendable {
    nonisolated(unsafe) weak var handler: (any ClaudeToolHandler)?
    init() {}
}

// MARK: - System Instructions (mirrors ClaudeService system prompt)

private let coDriverInstructions = """
You are "Co-Driver", the AI companion in the iTrucker's Co-Driver app for independent truck drivers.

PERSONALITY:
You are warm, knowledgeable, and genuinely care about the driver's safety, wellbeing, and livelihood. You know FMCSA regulations inside and out. You are occasionally witty — truckers appreciate a good road joke on a long haul, but always read the room and stay serious when safety or compliance matters are at stake.

COMMUNICATION STYLE:
- Responses will be read aloud via text-to-speech. Keep them concise: 1–3 sentences max unless the driver explicitly asks for more detail.
- Use natural spoken language, not bullet points or markdown.
- Say numbers conversationally ("eleven hours", not "11 hours").

TOOLS — USE PROACTIVELY:
- Driver starting to drive → log_duty_status "driving"
- Taking a break, going off duty → log appropriate status
- Mentions being tired or needing rest → find_places "rest"
- Asks about fuel → find_places "fuel"
- Asks about weather → get_weather
- Needs directions → navigate_to
- Infer intent and act without waiting for exact commands.

HOS COMPLIANCE — TOP PRIORITY:
Proactively warn when within 1 hour of a limit. Never encourage driving past legal limits.

HUMOR: Occasional light trucking humor is welcome. Never joke about safety violations or fatigue.
"""

// MARK: - Tool Definitions (12 tools, one per ClaudeToolHandler method)

struct LogDutyStatusTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "log_duty_status"
    let description = "Record a change in the driver's HOS duty status."

    @Generable struct Arguments {
        @Guide(description: "New duty status. Values: driving, on_duty, off_duty, sleeper")
        var status: String
        @Guide(description: "Optional notes about this status change")
        var notes: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleLogDutyStatus(status: arguments.status, notes: arguments.notes)
    }
}

struct GetHOSSummaryTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "get_hos_summary"
    let description = "Get the driver's current hours of service: remaining drive time, on-duty window, cycle hours, and compliance status."

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleGetHOSSummary()
    }
}

struct FindPlacesTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "find_places"
    let description = "Find nearby places for the driver: fuel stations, rest areas, truck stops, or weigh stations."

    @Generable struct Arguments {
        @Guide(description: "Type of place. Values: fuel, rest, truck_stop, weigh_station")
        var type: String
        @Guide(description: "Search radius in miles. Default 25.")
        var radius_miles: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleFindPlaces(type: arguments.type, radiusMiles: arguments.radius_miles ?? 25)
    }
}

struct GetWeatherTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "get_weather"
    let description = "Get current weather conditions for the driver's current GPS location or a specified location."

    @Generable struct Arguments {
        @Guide(description: "Location to check. Leave empty to use current GPS position.")
        var location: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleGetWeather(location: arguments.location)
    }
}

struct NavigateToTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "navigate_to"
    let description = "Start navigation to a destination and show the route on the map."

    @Generable struct Arguments {
        @Guide(description: "Destination address or place name")
        var destination: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleNavigateTo(destination: arguments.destination)
    }
}

struct SendDispatchMessageTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "send_dispatch_message"
    let description = "Send a message to the dispatcher."

    @Generable struct Arguments {
        @Guide(description: "The message to send to dispatch")
        var message: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleSendDispatchMessage(message: arguments.message)
    }
}

struct LogExpenseTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "log_expense"
    let description = "Log a business expense for tax and compliance records."

    @Generable struct Arguments {
        @Guide(description: "Dollar amount of the expense")
        var amount: Double
        @Guide(description: "Expense category: fuel, food, lodging, tolls, maintenance, or other")
        var category: String
        @Guide(description: "Optional description of the expense")
        var note: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleLogExpense(amount: arguments.amount, category: arguments.category, note: arguments.note)
    }
}

struct ContactCustomerTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "contact_customer"
    let description = "Contact the customer or consignee for a load with an ETA or status update."

    @Generable struct Arguments {
        @Guide(description: "The message to send to the customer")
        var message: String
        @Guide(description: "Load or order number, if known")
        var load_number: String?
        @Guide(description: "Contact channel: phone, sms, or email")
        var channel: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleContactCustomer(
            loadNumber: arguments.load_number ?? "",
            message: arguments.message,
            channel: arguments.channel ?? "phone"
        )
    }
}

struct GetDeliveryContactTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "get_delivery_contact"
    let description = "Look up contact information for a delivery destination or load."

    @Generable struct Arguments {
        @Guide(description: "The load number to look up")
        var load_number: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleGetDeliveryContact(loadNumber: arguments.load_number ?? "")
    }
}

struct ReportMaintenanceIssueTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "report_maintenance_issue"
    let description = "Report a vehicle maintenance or safety issue."

    @Generable struct Arguments {
        @Guide(description: "Description of the issue")
        var description: String
        @Guide(description: "Severity level: low, medium, or high. Use high for safety-critical issues.")
        var severity: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleReportMaintenanceIssue(
            description: arguments.description,
            severity: arguments.severity ?? "medium"
        )
    }
}

struct GetHealthSummaryTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "get_health_summary"
    let description = "Get the driver's current health and fatigue summary from HealthKit."

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleGetHealthSummary()
    }
}

struct GetDocumentTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "get_document"
    let description = "Retrieve a compliance document or form such as IFTA forms, log sheets, or permits."

    @Generable struct Arguments {
        @Guide(description: "Name or description of the document needed")
        var document_name: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleGetDocument(documentName: arguments.document_name)
    }
}

struct CalculateProfitTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "calculate_profit"
    let description = "Calculate estimated true profit for a potential load based on gross revenue and total miles."

    @Generable struct Arguments {
        @Guide(description: "Gross revenue offered for the load in dollars")
        var load_revenue: Double
        @Guide(description: "Total miles for the trip including deadhead")
        var miles: Double
    }

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleCalculateProfit(loadRevenue: arguments.load_revenue, miles: arguments.miles)
    }
}

struct StartInspectionTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "start_inspection"
    let description = "Begin a voice-guided pre-trip or post-trip vehicle inspection (DVIR)."

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleStartInspection()
    }
}

struct ContinueInspectionTool: Tool {
    let handlerRef: ToolHandlerRef
    let name = "continue_inspection"
    let description = "Continue to the next step of the active vehicle inspection after the driver responds."

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        guard let h = handlerRef.handler else { return "Tool handler unavailable." }
        return await h.handleContinueInspection()
    }
}

// MARK: - Apple Intelligence Service

class AppleIntelligenceService: CoDriverAIService {

    weak var toolHandler: (any ClaudeToolHandler)? {
        didSet { handlerRef.handler = toolHandler }
    }

    private let handlerRef = ToolHandlerRef()
    private var session: LanguageModelSession?

    // MARK: - Availability

    /// Whether this device supports Apple Intelligence at runtime.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Session

    private func getOrCreateSession() -> LanguageModelSession {
        if let existing = session { return existing }
        let s = LanguageModelSession(tools: [
            LogDutyStatusTool(handlerRef: handlerRef),
            GetHOSSummaryTool(handlerRef: handlerRef),
            FindPlacesTool(handlerRef: handlerRef),
            GetWeatherTool(handlerRef: handlerRef),
            NavigateToTool(handlerRef: handlerRef),
            SendDispatchMessageTool(handlerRef: handlerRef),
            LogExpenseTool(handlerRef: handlerRef),
            ContactCustomerTool(handlerRef: handlerRef),
            GetDeliveryContactTool(handlerRef: handlerRef),
            ReportMaintenanceIssueTool(handlerRef: handlerRef),
            GetHealthSummaryTool(handlerRef: handlerRef),
            GetDocumentTool(handlerRef: handlerRef),
            CalculateProfitTool(handlerRef: handlerRef),
            StartInspectionTool(handlerRef: handlerRef),
            ContinueInspectionTool(handlerRef: handlerRef)
        ]) {
            coDriverInstructions
        }
        session = s
        return s
    }

    func resetConversation() {
        session = nil
    }

    // MARK: - CoDriverAIService

    func sendMessage(
        _ text: String,
        history: [ConversationMessage],
        onPartialResponse: @escaping (String) -> Void
    ) async throws -> String {
        // Check runtime availability (user may have disabled Apple Intelligence in Settings)
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw AIServiceError.appleIntelligenceUnavailable(String(describing: reason))
        }

        return try await streamWithFallbackReset(text: text, onPartialResponse: onPartialResponse)
    }

    private func streamWithFallbackReset(
        text: String,
        onPartialResponse: @escaping (String) -> Void,
        isRetry: Bool = false
    ) async throws -> String {
        let activeSession = getOrCreateSession()
        do {
            // streamResponse yields ResponseStream<String>.Snapshot.
            // Each snapshot's `content` property holds the accumulated text so far.
            // We compute deltas for sentence-chunked TTS streaming.
            var previousLength = 0
            var fullResponse = ""
            for try await snapshot in activeSession.streamResponse(to: text) {
                let accumulated = snapshot.content
                let delta = String(accumulated.dropFirst(previousLength))
                previousLength = accumulated.count
                fullResponse = accumulated
                if !delta.isEmpty {
                    onPartialResponse(delta)
                }
            }
            return fullResponse
        } catch {
            // If the context window is full, reset and retry once with a fresh session
            if !isRetry && isContextLengthError(error) {
                session = nil
                return try await streamWithFallbackReset(text: text, onPartialResponse: onPartialResponse, isRetry: true)
            }
            throw error
        }
    }

    private func isContextLengthError(_ error: Error) -> Bool {
        let desc = error.localizedDescription.lowercased()
        return desc.contains("context") || desc.contains("length") || desc.contains("token")
    }
}
