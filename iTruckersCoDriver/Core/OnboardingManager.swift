//
//  OnboardingManager.swift
//  iTruckersCoDriver
//
//  Validates Claude API key with a test call, provisions driver account,
//  and marks onboarding complete.
//

import Foundation
import Combine

@MainActor
class OnboardingManager: ObservableObject {
    @Published var isValidatingKey = false
    @Published var keyValidationResult: KeyValidationResult?

    enum KeyValidationResult {
        case valid
        case invalid(String)
    }

    func validateAndSaveKey(_ key: String, for account: DriverAccount) async {
        isValidatingKey = true
        keyValidationResult = nil

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            keyValidationResult = .invalid("API key cannot be empty.")
            isValidatingKey = false
            return
        }

        let isValid = await testAPIKey(trimmed)
        if isValid {
            // Save to driver-scoped key and also global key for backward compatibility
            KeychainHelper.save(trimmed, forKey: account.apiKeyKeychainKey)
            KeychainHelper.save(trimmed, forKey: KeychainHelper.anthropicAPIKey)
            keyValidationResult = .valid
        } else {
            keyValidationResult = .invalid("Key validation failed. Check the key and your internet connection.")
        }
        isValidatingKey = false
    }

    func completeOnboarding(account: DriverAccount, name: String, cdlState: String) {
        account.name = name.isEmpty ? "Driver" : name
        account.cdlState = cdlState
        account.onboardingComplete = true
    }

    // MARK: - Private

    private func testAPIKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return false }
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 5,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return http.statusCode == 200
            }
        } catch {}
        return false
    }
}
