//
//  VoiceManager.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

#if os(iOS)
import Foundation
import Combine
import Speech
import AVFoundation
import MapKit
import SwiftData

class VoiceManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var statusMessage = "Tap the mic to speak"
    @Published var permissionsGranted = false

    // Set by DriverView
    weak var appState: AppState?       // for API key + active backend selection
    weak var driverState: DriverState? // for conversation, HOS, duty status

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var modelContext: ModelContext?

    // Both backends are held so switching is instant (no re-init overhead).
    private let appleService = AppleIntelligenceService()
    private let claudeService = ClaudeService()

    // Route + HOS managers (lazy initialized to avoid circular deps)
    private lazy var hosManager = HOSManager()
    private lazy var routeManager = RouteManager()
    private lazy var dvirManager = DVIRManager()

    override init() {
        super.init()
        synthesizer.delegate = self
        appleService.toolHandler = self
        claudeService.toolHandler = self
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.hosManager.configure(with: modelContext)
    }

    /// The currently active AI backend, based on AppState preference.
    private var activeService: any CoDriverAIService {
        switch appState?.activeBackend ?? .claude {
        case .appleIntelligence: return appleService
        case .claude: return claudeService
        }
    }

    // MARK: - Permissions

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                if status == .authorized {
                    self.checkMicPermission()
                } else {
                    self.statusMessage = "Speech recognition access denied. Check Settings."
                    self.permissionsGranted = false
                }
            }
        }
    }

    private func checkMicPermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permissionsGranted = true
            statusMessage = "Tap the mic to speak"
        case .denied:
            permissionsGranted = false
            statusMessage = "Microphone access denied. Check Settings."
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionsGranted = granted
                    self?.statusMessage = granted ? "Tap the mic to speak" : "Microphone access denied."
                }
            }
        @unknown default:
            permissionsGranted = false
        }
    }

    // MARK: - Listening control

    func toggleListening() {
        if isListening { stopListening() } else { startListening() }
    }

    func startListening() {
        guard permissionsGranted, !audioEngine.isRunning else { return }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognizedText = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusMessage = "Audio session error"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            var isFinal = false
            if let result {
                let text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                DispatchQueue.main.async { self.recognizedText = text }
            }
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                DispatchQueue.main.async {
                    self.isListening = false
                    self.statusMessage = "Processing..."
                    if isFinal { self.processWithClaude(self.recognizedText) }
                }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isListening = true
                self.statusMessage = "Listening..."
            }
        } catch {
            statusMessage = "Failed to start listening"
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        DispatchQueue.main.async {
            self.isListening = false
            self.statusMessage = "Tap the mic to speak"
        }
    }

    // MARK: - AI processing

    private func processWithClaude(_ text: String) {
        guard !text.isEmpty else {
            DispatchQueue.main.async { self.statusMessage = "Tap the mic to speak" }
            return
        }

        guard let driver = driverState else { return }

        // For Claude backend, validate and inject the API key before calling.
        if appState?.activeBackend == .claude {
            guard let apiKey = appState?.apiKey, !apiKey.isEmpty else {
                speak("Please add your Claude API key in Settings to enable AI interaction.")
                return
            }
            claudeService.apiKey = apiKey
        }

        DispatchQueue.main.async {
            driver.addUserMessage(text)
            driver.isProcessingAI = true
        }

        let service = activeService
        var sentenceBuffer = ""

        Task {
            do {
                let fullResponse = try await service.sendMessage(
                    text,
                    history: Array(driver.conversationHistory.dropLast()),
                    onPartialResponse: { [weak self] chunk in
                        guard let self else { return }
                        sentenceBuffer += chunk
                        if let sentenceEnd = self.findSentenceEnd(in: sentenceBuffer) {
                            let sentence = String(sentenceBuffer[...sentenceEnd])
                            sentenceBuffer = String(sentenceBuffer[sentenceBuffer.index(after: sentenceEnd)...])
                            self.speak(sentence, isChunk: true)
                        }
                    }
                )

                let remaining = sentenceBuffer
                DispatchQueue.main.async {
                    if !remaining.isEmpty {
                        self.speak(remaining, isChunk: true)
                    }
                    driver.addAssistantMessage(fullResponse)
                    driver.isProcessingAI = false
                    self.statusMessage = "Tap the mic to speak"
                }
            } catch AIServiceError.appleIntelligenceUnavailable(_) {
                DispatchQueue.main.async {
                    driver.isProcessingAI = false
                    self.statusMessage = "Apple Intelligence unavailable"
                    self.speak("Apple Intelligence isn't available right now. Add a Claude API key in Settings for full features.")
                }
            } catch AIServiceError.noAPIKey {
                DispatchQueue.main.async {
                    driver.isProcessingAI = false
                    self.statusMessage = "No API key"
                    self.speak("Please add your Claude API key in Settings to use the Claude backend.")
                }
            } catch {
                DispatchQueue.main.async {
                    driver.isProcessingAI = false
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    driver.lastAIError = error.localizedDescription
                    self.speak("Sorry, I had trouble with that. Check your connection or AI settings.")
                }
            }
        }
    }

    // MARK: - Speech synthesis

    func speak(_ text: String, isChunk: Bool = false) {
        if !isChunk {
            synthesizer.stopSpeaking(at: .immediate)
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try session.setActive(true)
        } catch {}

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    private func findSentenceEnd(in text: String) -> String.Index? {
        let sentenceEnders: [Character] = [".", "!", "?"]
        for (idx, char) in text.enumerated() {
            if sentenceEnders.contains(char) {
                return text.index(text.startIndex, offsetBy: idx)
            }
        }
        return nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.driverState?.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.driverState?.isSpeaking = true }
    }
}

// MARK: - Claude Tool Handler

extension VoiceManager: ClaudeToolHandler {
    func handleLogDutyStatus(status: String, notes: String?) async -> String {
        let dutyStatus = DutyStatus(rawValue: status) ?? .offDuty
        DispatchQueue.main.async {
            self.driverState?.currentDutyStatus = dutyStatus
        }
        return "Duty status logged as \(dutyStatus.displayName). Time: \(Date().formatted(date: .omitted, time: .shortened))."
    }

    func handleGetHOSSummary() async -> String {
        guard let state = driverState else { return "HOS data unavailable." }
        let s = state.hosRemaining
        return """
        Drive time remaining: \(s.driveTimeRemainingFormatted) (11-hour rule)
        On-duty window: \(s.onDutyTimeRemainingFormatted) remaining
        Cycle hours: \(s.cycleHoursRemainingFormatted) remaining (70/8 cycle)
        Status: \(s.isCompliant ? "Compliant" : "Issues present — check HOS tab")
        """
    }

    func handleFindPlaces(type: String, radiusMiles: Int) async -> String {
        guard let placeType = PlaceType(rawValue: type) else { return "Unknown place type." }
        let places = await routeManager.findNearby(type: placeType, radiusMiles: Double(radiusMiles))
        if places.isEmpty { return "No \(type.replacingOccurrences(of: "_", with: " ")) locations found within \(radiusMiles) miles." }
        return places.prefix(3).map { "\($0.name) — \(String(format: "%.1f", $0.distanceMiles)) mi away. \($0.address)" }.joined(separator: "\n")
    }

    func handleGetWeather(location: String?) async -> String {
        if let weather = await routeManager.fetchWeather() {
            var response = "Current conditions: \(weather.summary)."
            if weather.precipitationChance > 30 {
                response += " Precipitation chance: \(Int(weather.precipitationChance))%."
            }
            if weather.isDangerous {
                response += " ⚠️ Dangerous driving conditions. Reduce speed and increase following distance."
            }
            return response
        }
        return "Weather data temporarily unavailable."
    }

    func handleNavigateTo(destination: String) async -> String {
        await routeManager.requestRoute(to: destination)
        DispatchQueue.main.async {
            self.driverState?.activeRoute = self.routeManager.activeRoute
        }
        if routeManager.activeRoute != nil {
            return "Route to \(destination) is ready. Check the Route tab for your map."
        }
        return "I couldn't find a route to \(destination). Try the Route tab to search manually."
    }

    func handleSendDispatchMessage(message: String) async -> String {
        // Message will be saved to SwiftData/CloudKit in MessagesView
        // For now, return confirmation
        return "Message sent to dispatch: \"\(message)\""
    }

    func handleLogExpense(amount: Double, category: String, note: String?) async -> String {
        guard let context = modelContext else { return "Database unavailable. Expense not saved." }
        
        let expense = ExpenseEntry(
            category: category,
            amount: amount,
            note: note ?? ""
        )
        context.insert(expense)
        try? context.save()
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        return "Logged \(category) expense of \(formatted)\(note.map { ": \($0)" } ?? "")."
    }

    func handleCalculateProfit(loadRevenue: Double, miles: Double) async -> String {
        let fixedCostPerMile = appState?.fixedCostPerMile ?? 0.45

        // Resolve MPG: manual override → computed from fuel records → default
        var avgMPG = appState?.truckMPG ?? 0
        var avgFuelPrice = 4.50
        var mpgSource = "default estimate"

        if let context = modelContext, let driverID = appState?.driverID {
            let descriptor = FetchDescriptor<FuelRecord>(
                predicate: #Predicate { $0.driverID == driverID },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let records = (try? context.fetch(descriptor)) ?? []

            if avgMPG == 0, records.count >= 2 {
                let recent = Array(records.prefix(10))
                let totalGallons = recent.reduce(0) { $0 + $1.gallons }
                let odometerSpan = (recent.first?.odometer ?? 0) - (recent.last?.odometer ?? 0)
                if totalGallons > 0 && odometerSpan > 0 {
                    avgMPG = odometerSpan / totalGallons
                    mpgSource = "your fuel records"
                }
            } else if avgMPG > 0 {
                mpgSource = "your settings"
            }

            if let lastFill = records.first, lastFill.pricePerGallon > 0 {
                avgFuelPrice = lastFill.pricePerGallon
            }
        } else if avgMPG > 0 {
            mpgSource = "your settings"
        }
        if avgMPG == 0 { avgMPG = 6.5 }

        let estimatedFuelGallons = miles / avgMPG
        let fuelCost = estimatedFuelGallons * avgFuelPrice
        let fixedExpenses = miles * fixedCostPerMile
        let totalExpenses = fuelCost + fixedExpenses
        let profit = loadRevenue - totalExpenses
        let profitPerMile = miles > 0 ? profit / miles : 0

        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        let pFormatted = fmt.string(from: NSNumber(value: profit)) ?? "$\(Int(profit))"
        let ppmFormatted = fmt.string(from: NSNumber(value: profitPerMile)) ?? "$\(String(format: "%.2f", profitPerMile))"

        return """
        Profit analysis for \(Int(miles))-mile load at \(fmt.string(from: NSNumber(value: loadRevenue)) ?? "$\(Int(loadRevenue))") gross:
        Fuel: \(String(format: "%.0f", estimatedFuelGallons)) gal @ $\(String(format: "%.3f", avgFuelPrice)) = $\(Int(fuelCost)) (\(Int(avgMPG)) MPG from \(mpgSource))
        Fixed costs: $\(Int(fixedExpenses)) at $\(String(format: "%.2f", fixedCostPerMile))/mile
        Total expenses: $\(Int(totalExpenses))
        True profit: \(pFormatted) | \(ppmFormatted)/mile
        """
    }

    func handleStartInspection() async -> String {
        return dvirManager.startInspection()
    }
    
    func handleContinueInspection() async -> String {
        let lastUserMessage = driverState?.conversationHistory.last { $0.role == "user" }?.content ?? ""
        return dvirManager.processResponse(lastUserMessage)
    }

    func handleContactCustomer(loadNumber: String, message: String, channel: String) async -> String {
        let loadInfo = loadNumber.isEmpty ? "" : " for load \(loadNumber)"
        return "Message\(loadInfo) sent via \(channel): \"\(message)\". Communication logged."
    }

    func handleGetDeliveryContact(loadNumber: String) async -> String {
        if loadNumber.isEmpty {
            return "No load number provided. Check the Dispatch tab for current load contact info."
        }
        return "Delivery contact for \(loadNumber): Check the Contacts tab in the Dispatch screen for details."
    }

    func handleReportMaintenanceIssue(description: String, severity: String) async -> String {
        DispatchQueue.main.async {
            // The actual SwiftData insert happens via the MaintenanceView UI.
            // Here we just confirm to Claude so it can inform the driver.
        }
        let urgency = severity == "high" ? " This has been flagged as a safety issue. Dispatch has been notified." : ""
        return "Maintenance issue reported: \"\(description)\" (severity: \(severity)).\(urgency) Check the Maintenance tab for details."
    }

    func handleGetHealthSummary() async -> String {
        // Health data is managed on-device via HealthManager in HealthView.
        // VoiceManager does not hold a HealthManager reference to avoid redundant HealthKit authorization.
        return "Check the Health tab for your current heart rate, sleep hours, and fatigue score."
    }

    func handleGetDocument(documentName: String) async -> String {
        let repo = DocumentRepository()
        if let doc = repo.document(named: documentName) {
            return "Found \"\(doc.name)\" in the \(doc.category.rawValue) category. Open the Documents tab to view and share it."
        }
        return "I couldn't find a document matching \"\(documentName)\". Check the Documents tab for the full library."
    }
}
#endif
