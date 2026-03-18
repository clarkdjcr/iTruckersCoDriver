//
//  OnboardingView.swift
//  iTruckersCoDriver
//
//  Multi-step driver onboarding: welcome → profile setup → API key entry → complete.
//

import SwiftUI
import SwiftData

#if os(iOS)
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @StateObject private var onboardingManager = OnboardingManager()
    @Binding var isOnboardingComplete: Bool

    @State private var step = 0
    @State private var driverName = ""
    @State private var cdlNumber = ""
    @State private var cdlState = ""
    @State private var apiKeyInput = ""
    @State private var showAPIKey = false
    @State private var account: DriverAccount?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i <= step ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    profileStep.tag(1)
                    apiKeyStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
            .navigationTitle("Welcome to Co-Driver")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🚛")
                .font(.system(size: 80))
            Text("iTrucker's Co-Driver")
                .font(.largeTitle).fontWeight(.bold)
            Text("Your AI-powered trucking companion.\nVoice-driven. Safety-first. Always on duty.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Spacer()
            Button(action: { withAnimation { step = 1 } }) {
                Text("Get Started")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.blue).foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Step 1: Profile

    private var profileStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Your Profile")
                .font(.title).fontWeight(.bold)
            Text("Helps Co-Driver personalize your experience.")
                .foregroundColor(.secondary).multilineTextAlignment(.center)
            VStack(spacing: 12) {
                TextField("Your name", text: $driverName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                HStack {
                    TextField("CDL Number", text: $cdlNumber)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    TextField("State (TX)", text: $cdlState)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .frame(width: 90)
                }
            }
            .padding(.horizontal)
            Spacer()
            Button(action: { withAnimation { step = 2 } }) {
                Text("Continue")
                    .frame(maxWidth: .infinity).padding()
                    .background(driverName.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white).cornerRadius(14)
            }
            .disabled(driverName.isEmpty)
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Step 2: API Key

    private var apiKeyStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Claude API Key")
                .font(.title).fontWeight(.bold)
            Text("Co-Driver uses Claude AI for voice interaction. Get your key at console.anthropic.com")
                .foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if showAPIKey {
                        TextField("sk-ant-...", text: $apiKeyInput)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                    } else {
                        SecureField("sk-ant-...", text: $apiKeyInput)
                            .autocorrectionDisabled()
                    }
                    Button { showAPIKey.toggle() } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
                if case .invalid(let msg) = onboardingManager.keyValidationResult {
                    Text(msg).font(.caption).foregroundColor(.red)
                }
                if case .valid = onboardingManager.keyValidationResult {
                    Label("API key verified!", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            Spacer()
            if onboardingManager.isValidatingKey {
                ProgressView("Verifying key...")
            } else if case .valid = onboardingManager.keyValidationResult {
                Button(action: finishOnboarding) {
                    Text("Start Driving!")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.green).foregroundColor(.white).cornerRadius(14)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    Button(action: validateKey) {
                        Text("Verify & Continue")
                            .frame(maxWidth: .infinity).padding()
                            .background(apiKeyInput.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white).cornerRadius(14)
                    }
                    .disabled(apiKeyInput.isEmpty)
                    Button("Skip for now") { finishOnboarding() }
                        .foregroundColor(.secondary).font(.caption)
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func validateKey() {
        let acc = getOrCreateAccount()
        Task { await onboardingManager.validateAndSaveKey(apiKeyInput, for: acc) }
    }

    private func finishOnboarding() {
        let acc = getOrCreateAccount()
        onboardingManager.completeOnboarding(
            account: acc, name: driverName, cdlNumber: cdlNumber, cdlState: cdlState
        )
        appState.driverName = driverName
        appState.cdlState = cdlState
        try? modelContext.save()
        isOnboardingComplete = true
    }

    private func getOrCreateAccount() -> DriverAccount {
        if let existing = account { return existing }
        let acc = DriverAccount(driverID: appState.driverID, name: driverName)
        modelContext.insert(acc)
        account = acc
        return acc
    }
}
#endif
