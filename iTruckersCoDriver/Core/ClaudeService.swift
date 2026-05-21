//
//  ClaudeService.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//
//  Calls the Claude API (claude-opus-4-6) via URLSession with SSE streaming
//  and tool use for trucking-specific actions.
//

import Foundation

// MARK: - Tool definitions

private let truckingTools: [[String: Any]] = [
    [
        "name": "log_duty_status",
        "description": "Record a change in the driver's duty status in the HOS log. Call this whenever the driver indicates a status change.",
        "input_schema": [
            "type": "object",
            "properties": [
                "status": [
                    "type": "string",
                    "enum": ["driving", "on_duty", "off_duty", "sleeper"],
                    "description": "The new duty status"
                ],
                "notes": [
                    "type": "string",
                    "description": "Optional notes about this status change"
                ]
            ],
            "required": ["status"]
        ]
    ],
    [
        "name": "get_hos_summary",
        "description": "Get the driver's current hours of service summary including remaining drive time, on-duty time, and compliance status.",
        "input_schema": [
            "type": "object",
            "properties": [:],
            "required": [] as [String]
        ]
    ],
    [
        "name": "find_places",
        "description": "Find nearby places of interest for the driver: fuel stations, rest areas, truck stops, or weigh stations.",
        "input_schema": [
            "type": "object",
            "properties": [
                "type": [
                    "type": "string",
                    "enum": ["fuel", "rest", "truck_stop", "weigh_station"],
                    "description": "Type of place to find"
                ],
                "radius_miles": [
                    "type": "integer",
                    "description": "Search radius in miles (default 25)"
                ]
            ],
            "required": ["type"]
        ]
    ],
    [
        "name": "get_weather",
        "description": "Get current weather conditions and forecast for the driver's location or a specified location.",
        "input_schema": [
            "type": "object",
            "properties": [
                "location": [
                    "type": "string",
                    "description": "Location to get weather for. If not provided, uses current GPS location."
                ]
            ],
            "required": [] as [String]
        ]
    ],
    [
        "name": "navigate_to",
        "description": "Start navigation to a destination. Opens the route on the map.",
        "input_schema": [
            "type": "object",
            "properties": [
                "destination": [
                    "type": "string",
                    "description": "The destination address or place name"
                ]
            ],
            "required": ["destination"]
        ]
    ],
    [
        "name": "send_dispatch_message",
        "description": "Send a message to the dispatcher.",
        "input_schema": [
            "type": "object",
            "properties": [
                "message": [
                    "type": "string",
                    "description": "The message to send to dispatch"
                ]
            ],
            "required": ["message"]
        ]
    ],
    [
        "name": "log_expense",
        "description": "Log a business expense for tax and compliance records.",
        "input_schema": [
            "type": "object",
            "properties": [
                "amount": [
                    "type": "number",
                    "description": "Dollar amount of the expense"
                ],
                "category": [
                    "type": "string",
                    "enum": ["fuel", "food", "lodging", "tolls", "maintenance", "other"],
                    "description": "Expense category"
                ],
                "note": [
                    "type": "string",
                    "description": "Description of the expense"
                ]
            ],
            "required": ["amount", "category"]
        ]
    ],
    [
        "name": "contact_customer",
        "description": "Contact the customer or consignee for a load. Use when driver says 'call the customer', 'notify the receiver', 'send ETA to customer'.",
        "input_schema": [
            "type": "object",
            "properties": [
                "load_number": [
                    "type": "string",
                    "description": "The load or order number"
                ],
                "message": [
                    "type": "string",
                    "description": "The message to send (e.g. ETA update)"
                ],
                "channel": [
                    "type": "string",
                    "enum": ["phone", "sms", "email"],
                    "description": "Preferred contact channel"
                ]
            ],
            "required": ["message"]
        ]
    ],
    [
        "name": "get_delivery_contact",
        "description": "Look up the contact information for a delivery destination or load.",
        "input_schema": [
            "type": "object",
            "properties": [
                "load_number": [
                    "type": "string",
                    "description": "The load number to look up"
                ]
            ],
            "required": [] as [String]
        ]
    ],
    [
        "name": "report_maintenance_issue",
        "description": "Report a vehicle maintenance or safety issue. Use when driver says 'report a problem', 'log an issue', mentions brake, tire, light, or mechanical problems.",
        "input_schema": [
            "type": "object",
            "properties": [
                "description": [
                    "type": "string",
                    "description": "Description of the issue"
                ],
                "severity": [
                    "type": "string",
                    "enum": ["low", "medium", "high"],
                    "description": "Severity level. Use 'high' for safety-critical issues."
                ]
            ],
            "required": ["description"]
        ]
    ],
    [
        "name": "get_health_summary",
        "description": "Get the driver's current health and fatigue summary from HealthKit (if authorized).",
        "input_schema": [
            "type": "object",
            "properties": [:],
            "required": [] as [String]
        ]
    ],
    [
        "name": "get_document",
        "description": "Retrieve a compliance document or form for the driver. Use when driver says 'get the IFTA form', 'show me the log sheet', etc.",
        "input_schema": [
            "type": "object",
            "properties": [
                "document_name": [
                    "type": "string",
                    "description": "Name or description of the document needed"
                ]
            ],
            "required": ["document_name"]
        ]
    ],
    [
        "name": "calculate_profit",
        "description": "Calculate the estimated true profit for a potential load based on revenue and miles.",
        "input_schema": [
            "type": "object",
            "properties": [
                "load_revenue": [
                    "type": "number",
                    "description": "The gross revenue offered for the load"
                ],
                "miles": [
                    "type": "number",
                    "description": "Total miles for the trip (including deadhead)"
                ]
            ],
            "required": ["load_revenue", "miles"]
        ]
    ],
    [
        "name": "start_inspection",
        "description": "Begin a voice-guided pre-trip or post-trip vehicle inspection (DVIR).",
        "input_schema": [
            "type": "object",
            "properties": [:],
            "required": [] as [String]
        ]
    ],
    [
        "name": "continue_inspection",
        "description": "Continue with the next step of the current vehicle inspection.",
        "input_schema": [
            "type": "object",
            "properties": [:],
            "required": [] as [String]
        ]
    ]
]

// MARK: - System Prompt

private let systemPrompt = """
You are "Co-Driver", the AI companion in the iTrucker's Co-Driver app for independent truck drivers.

PERSONALITY:
You are warm, knowledgeable, and genuinely care about the driver's safety, wellbeing, and livelihood. You know FMCSA regulations inside and out. You are occasionally witty — truckers appreciate a good road joke on a long haul, but you always read the room and stay serious when safety or compliance matters are at stake. Think of yourself as the ideal co-driver: experienced, reliable, and good company.

COMMUNICATION STYLE:
- Responses will be read aloud via text-to-speech. Keep them concise: 1-3 sentences max unless the driver explicitly asks for more detail.
- Use natural spoken language, not bullet points or markdown.
- Address the driver warmly but not excessively.
- When mentioning numbers, say them conversationally (say "eleven hours" not "11 hours").

TOOLS — USE PROACTIVELY:
- When the driver says they're starting to drive → call log_duty_status("driving")
- When they say they're taking a break, stopping, going off duty → log the appropriate status
- When they mention being tired, needing rest → call find_places(type:"rest")
- When they ask about fuel → call find_places(type:"fuel")
- When they ask about weather → call get_weather()
- When they need directions → call navigate_to()
- Don't wait for exact commands. Infer intent and act.

HOS COMPLIANCE — TOP PRIORITY:
Always be aware of the driver's remaining hours. Proactively warn when they're within 1 hour of a limit. Never encourage driving past legal limits. If a driver asks about pushing through fatigue, prioritize their safety firmly but kindly.

HUMOR GUIDELINES:
Occasional light trucking humor is welcome. Good examples: weigh station jokes, coffee jokes, CB radio jokes, GPS fail jokes. Keep it clean and brief. Never joke about safety violations or fatigue.

The driver's safety and compliance come first — everything else second. You're the co-driver they've always wanted. 🚛
"""

// MARK: - Claude API Response types

private struct SSEEvent {
    let type: String
    let data: [String: Any]
}

struct ToolCall {
    let id: String
    let name: String
    let input: [String: Any]
}

// MARK: - Tool handler protocol

protocol ClaudeToolHandler: AnyObject {
    func handleLogDutyStatus(status: String, notes: String?) async -> String
    func handleGetHOSSummary() async -> String
    func handleFindPlaces(type: String, radiusMiles: Int) async -> String
    func handleGetWeather(location: String?) async -> String
    func handleNavigateTo(destination: String) async -> String
    func handleSendDispatchMessage(message: String) async -> String
    func handleLogExpense(amount: Double, category: String, note: String?) async -> String
    // Phase 2+
    func handleContactCustomer(loadNumber: String, message: String, channel: String) async -> String
    func handleGetDeliveryContact(loadNumber: String) async -> String
    func handleReportMaintenanceIssue(description: String, severity: String) async -> String
    func handleGetHealthSummary() async -> String
    func handleGetDocument(documentName: String) async -> String
    func handleCalculateProfit(loadRevenue: Double, miles: Double) async -> String
    func handleStartInspection() async -> String
    func handleContinueInspection() async -> String
}

// MARK: - Claude Service

class ClaudeService: CoDriverAIService {
    weak var toolHandler: (any ClaudeToolHandler)?
    /// Set by VoiceManager before each call when the Claude backend is active.
    var apiKey: String?
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let model = "claude-opus-4-6"

    // MARK: - CoDriverAIService

    func resetConversation() {
        // Claude is stateless — conversation history is managed by DriverState.
    }

    func sendMessage(
        _ text: String,
        history: [ConversationMessage],
        onPartialResponse: @escaping (String) -> Void
    ) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw AIServiceError.noAPIKey
        }
        var messages: [[String: Any]] = history.map { msg in
            ["role": msg.role, "content": msg.content]
        }
        messages.append(["role": "user", "content": text])
        return try await runToolLoop(messages: messages, apiKey: key, onPartialResponse: onPartialResponse)
    }

    // MARK: - Legacy entry point (kept for any direct callers)

    func sendMessage(
        userText: String,
        history: [ConversationMessage],
        apiKey: String,
        onPartialResponse: @escaping (String) -> Void
    ) async throws -> String {
        // Build messages array from history
        var messages: [[String: Any]] = history.map { msg in
            ["role": msg.role, "content": msg.content]
        }
        messages.append(["role": "user", "content": userText])

        return try await runToolLoop(
            messages: messages,
            apiKey: apiKey,
            onPartialResponse: onPartialResponse
        )
    }

    // MARK: - Tool use loop

    private func runToolLoop(
        messages: [[String: Any]],
        apiKey: String,
        onPartialResponse: @escaping (String) -> Void
    ) async throws -> String {
        var currentMessages = messages
        var fullResponse = ""

        while true {
            let isFirstIteration = fullResponse.isEmpty
            let (responseText, toolCalls, stopReason) = try await callClaudeStreaming(
                messages: currentMessages,
                apiKey: apiKey,
                onPartialResponse: isFirstIteration ? onPartialResponse : { _ in }
            )

            fullResponse = responseText

            guard stopReason == "tool_use", !toolCalls.isEmpty else {
                break
            }

            // Execute all tool calls and collect results
            var assistantContent: [[String: Any]] = []
            if !responseText.isEmpty {
                assistantContent.append(["type": "text", "text": responseText])
            }
            for tool in toolCalls {
                assistantContent.append([
                    "type": "tool_use",
                    "id": tool.id,
                    "name": tool.name,
                    "input": tool.input
                ])
            }

            currentMessages.append(["role": "assistant", "content": assistantContent])

            var toolResults: [[String: Any]] = []
            for tool in toolCalls {
                let result = await executeTool(tool)
                toolResults.append([
                    "type": "tool_result",
                    "tool_use_id": tool.id,
                    "content": result
                ])
            }
            currentMessages.append(["role": "user", "content": toolResults])

            // Reset the partial response callback now that tools ran
            fullResponse = ""
        }

        return fullResponse
    }

    // MARK: - SSE streaming request

    private func callClaudeStreaming(
        messages: [[String: Any]],
        apiKey: String,
        onPartialResponse: @escaping (String) -> Void
    ) async throws -> (text: String, toolCalls: [ToolCall], stopReason: String) {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "thinking": ["type": "adaptive"],
            "stream": true,
            "system": systemPrompt,
            "tools": truckingTools,
            "messages": messages
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 120

        return try await withCheckedThrowingContinuation { continuation in
            var accumulatedText = ""
            var currentToolInputJson = ""
            var toolCalls: [ToolCall] = []
            var currentToolId = ""
            var currentToolName = ""
            var stopReason = "end_turn"
            var inToolUseBlock = false
            var buffer = ""

            let delegate = SSEStreamDelegate(
                onData: { line in
                    buffer += line + "\n"
                    // Process complete SSE events
                    while let range = buffer.range(of: "\n\n") {
                        let event = String(buffer[buffer.startIndex..<range.lowerBound])
                        buffer = String(buffer[range.upperBound...])
                        self.processSSEEvent(
                            event,
                            accumulatedText: &accumulatedText,
                            currentToolInputJson: &currentToolInputJson,
                            toolCalls: &toolCalls,
                            currentToolId: &currentToolId,
                            currentToolName: &currentToolName,
                            stopReason: &stopReason,
                            inToolUseBlock: &inToolUseBlock,
                            onPartialResponse: onPartialResponse
                        )
                    }
                },
                onComplete: {
                    continuation.resume(returning: (accumulatedText, toolCalls, stopReason))
                },
                onError: { error in
                    continuation.resume(throwing: error)
                }
            )

            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            task.resume()
        }
    }

    // MARK: - SSE event parser

    private func processSSEEvent(
        _ event: String,
        accumulatedText: inout String,
        currentToolInputJson: inout String,
        toolCalls: inout [ToolCall],
        currentToolId: inout String,
        currentToolName: inout String,
        stopReason: inout String,
        inToolUseBlock: inout Bool,
        onPartialResponse: @escaping (String) -> Void
    ) {
        var dataLine = ""
        for line in event.components(separatedBy: "\n") {
            if line.hasPrefix("data: ") {
                dataLine = String(line.dropFirst(6))
            }
        }

        guard !dataLine.isEmpty, dataLine != "[DONE]",
              let data = dataLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "content_block_start":
            if let block = json["content_block"] as? [String: Any] {
                let blockType = block["type"] as? String ?? ""
                if blockType == "tool_use" {
                    inToolUseBlock = true
                    currentToolId = block["id"] as? String ?? ""
                    currentToolName = block["name"] as? String ?? ""
                    currentToolInputJson = ""
                } else {
                    inToolUseBlock = false
                }
            }

        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any] {
                let deltaType = delta["type"] as? String ?? ""
                if deltaType == "text_delta", let text = delta["text"] as? String {
                    accumulatedText += text
                    DispatchQueue.main.async { onPartialResponse(text) }
                } else if deltaType == "input_json_delta", let partial = delta["partial_json"] as? String {
                    currentToolInputJson += partial
                }
            }

        case "content_block_stop":
            if inToolUseBlock && !currentToolId.isEmpty {
                let inputData = currentToolInputJson.data(using: .utf8) ?? Data()
                let input = (try? JSONSerialization.jsonObject(with: inputData) as? [String: Any]) ?? [:]
                toolCalls.append(ToolCall(id: currentToolId, name: currentToolName, input: input))
                inToolUseBlock = false
                currentToolId = ""
                currentToolName = ""
                currentToolInputJson = ""
            }

        case "message_delta":
            if let delta = json["delta"] as? [String: Any],
               let reason = delta["stop_reason"] as? String {
                stopReason = reason
            }

        default:
            break
        }
    }

    // MARK: - Tool execution

    private func executeTool(_ tool: ToolCall) async -> String {
        guard let handler = toolHandler else {
            return "Tool handler not available."
        }

        switch tool.name {
        case "log_duty_status":
            let status = tool.input["status"] as? String ?? "off_duty"
            let notes = tool.input["notes"] as? String
            return await handler.handleLogDutyStatus(status: status, notes: notes)

        case "get_hos_summary":
            return await handler.handleGetHOSSummary()

        case "find_places":
            let type = tool.input["type"] as? String ?? "fuel"
            let radius = tool.input["radius_miles"] as? Int ?? 25
            return await handler.handleFindPlaces(type: type, radiusMiles: radius)

        case "get_weather":
            let location = tool.input["location"] as? String
            return await handler.handleGetWeather(location: location)

        case "navigate_to":
            let destination = tool.input["destination"] as? String ?? ""
            return await handler.handleNavigateTo(destination: destination)

        case "send_dispatch_message":
            let message = tool.input["message"] as? String ?? ""
            return await handler.handleSendDispatchMessage(message: message)

        case "log_expense":
            let amount = tool.input["amount"] as? Double ?? 0
            let category = tool.input["category"] as? String ?? "other"
            let note = tool.input["note"] as? String
            return await handler.handleLogExpense(amount: amount, category: category, note: note)

        case "contact_customer":
            let loadNumber = tool.input["load_number"] as? String ?? ""
            let message = tool.input["message"] as? String ?? ""
            let channel = tool.input["channel"] as? String ?? "phone"
            return await handler.handleContactCustomer(loadNumber: loadNumber, message: message, channel: channel)

        case "get_delivery_contact":
            let loadNumber = tool.input["load_number"] as? String ?? ""
            return await handler.handleGetDeliveryContact(loadNumber: loadNumber)

        case "report_maintenance_issue":
            let description = tool.input["description"] as? String ?? ""
            let severity = tool.input["severity"] as? String ?? "medium"
            return await handler.handleReportMaintenanceIssue(description: description, severity: severity)

        case "get_health_summary":
            return await handler.handleGetHealthSummary()

        case "get_document":
            let documentName = tool.input["document_name"] as? String ?? ""
            return await handler.handleGetDocument(documentName: documentName)

        case "calculate_profit":
            let revenue = tool.input["load_revenue"] as? Double ?? 0
            let miles = tool.input["miles"] as? Double ?? 0
            return await handler.handleCalculateProfit(loadRevenue: revenue, miles: miles)

        case "start_inspection":
            return await handler.handleStartInspection()
            
        case "continue_inspection":
            return await handler.handleContinueInspection()

        default:
            return "Unknown tool: \(tool.name)"
        }
    }
}

// MARK: - SSE Stream Delegate

private class SSEStreamDelegate: NSObject, URLSessionDataDelegate {
    private let onData: (String) -> Void
    private let onComplete: () -> Void
    private let onError: (Error) -> Void
    private var dataBuffer = Data()

    init(
        onData: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onData = onData
        self.onComplete = onComplete
        self.onError = onError
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        dataBuffer.append(data)
        // Process complete lines
        while let range = dataBuffer.range(of: Data([0x0A])) { // newline
            let lineData = dataBuffer.subdata(in: dataBuffer.startIndex..<range.lowerBound)
            dataBuffer.removeSubrange(dataBuffer.startIndex...range.lowerBound)
            if let line = String(data: lineData, encoding: .utf8) {
                onData(line)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onError(error)
        } else {
            // Process any remaining data
            if !dataBuffer.isEmpty, let line = String(data: dataBuffer, encoding: .utf8) {
                onData(line)
            }
            onComplete()
        }
        session.invalidateAndCancel()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let error = NSError(
                domain: "ClaudeAPI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]
            )
            onError(error)
            completionHandler(.cancel)
        } else {
            completionHandler(.allow)
        }
    }
}
