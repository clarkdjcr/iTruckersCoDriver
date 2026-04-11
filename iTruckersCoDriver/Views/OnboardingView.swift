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
                TextField("CDL State (TX)", text: $cdlState)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .frame(maxWidth: 120)
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

    // MARK: - Step 2: AI Backend selection

    private var apiKeyStep: some View {
        VStack(spacing: 20) {
            Spacer()

            if appState.isAppleIntelligenceAvailable {
                // Device supports Apple Intelligence — offer the no-key path
                Text("Choose Your AI")
                    .font(.title).fontWeight(.bold)

                Text("Your phone has built-in AI that runs the whole show locally — no internet, no accounts, no one listening in. Your conversations never leave this device.")
                    .foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)

                VStack(spacing: 12) {
                    Button(action: useAppleIntelligence) {
                        HStack {
                            Image(systemName: "apple.logo")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Apple Intelligence")
                                    .fontWeight(.semibold)
                                Text("On-device · Private · No API key needed")
                                    .font(.caption).opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .opacity(0.8)
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }

                    Button(action: { appState.activeBackend = .claude }) {
                        HStack {
                            Image(systemName: "brain")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Claude (Anthropic)")
                                    .fontWeight(.semibold)
                                Text("Requires a Claude API key from console.anthropic.com")
                                    .font(.caption).opacity(0.8)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.12))
                        .foregroundColor(.primary)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal)

                claudeKeyEntrySection

            } else {
                // Device doesn't support Apple Intelligence — explain the key clearly
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Your AI Brain Needs a Key")
                            .font(.title2).fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        // What is it?
                        InfoCallout(
                            icon: "key.fill",
                            iconColor: .orange,
                            title: "What is an API key?",
                            body: "It's a unique passcode that gives YOU private access to Anthropic's AI. Think of it like your own CB frequency — nobody else can use yours, and it doesn't identify you personally. It's just a random string of characters."
                        )

                        // Privacy facts — this is the trust-builder
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Straight talk on your privacy", systemImage: "lock.shield.fill")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(.green)

                            VStack(alignment: .leading, spacing: 8) {
                                PrivacyRow(icon: "iphone", text: "Your key is stored only on this phone — never on our servers.")
                                PrivacyRow(icon: "arrow.left.arrow.right", text: "Your voice goes straight from your phone to Anthropic. iTrucker never sees your conversations.")
                                PrivacyRow(icon: "hand.raised.fill", text: "Anthropic does NOT sell your data or hand it to the government.")
                                PrivacyRow(icon: "person.slash", text: "No name, no CDL, no personal info is tied to the key.")
                                PrivacyRow(icon: "trash", text: "Delete the key any time from Settings. No account to cancel.")
                            }
                            .padding(14)
                            .background(Color.green.opacity(0.08))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        // Cost note
                        InfoCallout(
                            icon: "dollarsign.circle",
                            iconColor: .blue,
                            title: "What does it cost?",
                            body: "Anthropic charges by usage — for a typical day of voice commands it runs a few cents. You set your own spending cap in the Anthropic console so there are no surprises."
                        )

                        // How to get one
                        InfoCallout(
                            icon: "globe",
                            iconColor: .purple,
                            title: "How do I get one?",
                            body: "Visit console.anthropic.com — takes about 2 minutes, just an email address. No subscription, no credit check."
                        )

                        claudeKeyEntrySection
                    }
                    .padding(.vertical)
                }
            }

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var claudeKeyEntrySection: some View {
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
                if !appState.isAppleIntelligenceAvailable {
                    Button("Skip for now") { finishOnboarding() }
                        .foregroundColor(.secondary).font(.caption)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func useAppleIntelligence() {
        appState.activeBackend = .appleIntelligence
        finishOnboarding()
    }

    private func validateKey() {
        let acc = getOrCreateAccount()
        Task { await onboardingManager.validateAndSaveKey(apiKeyInput, for: acc) }
    }

    private func finishOnboarding() {
        let acc = getOrCreateAccount()
        onboardingManager.completeOnboarding(
            account: acc, name: driverName, cdlState: cdlState
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

// MARK: - Supporting views

private struct InfoCallout: View {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                Text(body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

private struct PrivacyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 18)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
