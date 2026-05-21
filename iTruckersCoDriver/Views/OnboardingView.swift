//
//  OnboardingView.swift
//  iTruckersCoDriver
//
//  Branched onboarding:
//    Step 0 — Role selection (driver or dispatcher)
//    Step 1 — Profile (driver: name/CDL/cycle; dispatcher: name/company)
//    Step 2 — AI setup (driver only; dispatcher is done after step 1)
//

import SwiftUI
import SwiftData

#if os(iOS)
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var onboardingManager = OnboardingManager()
    @Binding var isOnboardingComplete: Bool

    @State private var step = 0
    // Shared
    @State private var userName = ""
    // Driver
    @State private var cdlState = ""
    @State private var selectedCycle: HOSCycle = .seventyHour
    @State private var apiKeyInput = ""
    @State private var showAPIKey = false
    @State private var account: DriverAccount?
    // Dispatcher
    @State private var companyName = ""

    private var totalSteps: Int { appState.role == .driver ? 3 : 2 }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if step > 0 { progressBar.padding(.top, 16) }

                Group {
                    switch step {
                    case 0: roleStep
                    case 1: profileStep
                    case 2: aiStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .animation(.easeInOut(duration: 0.3), value: step)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private var navigationTitle: String {
        switch step {
        case 0: return "Welcome"
        case 1: return appState.role == .driver ? "Driver Profile" : "Dispatcher Profile"
        case 2: return "AI Setup"
        default: return "iTrucker Co-Driver"
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i < step ? Color.blue : i == step ? Color.blue.opacity(0.5) : Color.gray.opacity(0.25))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 0: Role selection

    private var roleStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 8) {
                Text("🚛").font(.system(size: 72))
                Text("iTrucker's Co-Driver")
                    .font(.largeTitle).fontWeight(.bold)
                Text("Who's using this device?")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            .padding(.bottom, 40)

            VStack(spacing: 16) {
                roleCard(
                    icon: "truck.box.fill",
                    iconColor: .blue,
                    title: "I'm a Driver",
                    subtitle: "Voice assistant · HOS tracking · Route & navigation · Compliance",
                    role: .driver
                )
                roleCard(
                    icon: "desktopcomputer",
                    iconColor: .purple,
                    title: "I'm a Dispatcher",
                    subtitle: "Fleet overview · Driver messages · Loads · Maintenance dashboard",
                    role: .dispatcher
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func roleCard(icon: String, iconColor: Color, title: String, subtitle: String, role: AppRole) -> some View {
        Button {
            appState.role = role
            withAnimation { step = 1 }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline).foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(18)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Step 1: Profile (branched)

    private var profileStep: some View {
        appState.role == .driver ? AnyView(driverProfileStep) : AnyView(dispatcherProfileStep)
    }

    private var driverProfileStep: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 44)).foregroundColor(.blue)
                Text("Your Driver Profile")
                    .font(.title2).fontWeight(.bold)
                Text("Personalizes HOS, compliance, and Co-Driver's voice.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }

            VStack(spacing: 12) {
                TextField("Your name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                HStack(spacing: 12) {
                    TextField("CDL State (TX)", text: $cdlState)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .frame(maxWidth: 130)

                    Picker("HOS Cycle", selection: $selectedCycle) {
                        Text("70 hr / 8 day").tag(HOSCycle.seventyHour)
                        Text("60 hr / 7 day").tag(HOSCycle.sixtyHour)
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(7)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            primaryButton(title: "Continue", disabled: userName.isEmpty) {
                withAnimation { step = 2 }
            }
        }
        .padding()
    }

    private var dispatcherProfileStep: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 44)).foregroundColor(.purple)
                Text("Dispatcher Profile")
                    .font(.title2).fontWeight(.bold)
                Text("Your name and fleet info appear in driver communications.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }

            VStack(spacing: 12) {
                TextField("Your name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                TextField("Company / Fleet name (optional)", text: $companyName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 24)

            Spacer()

            primaryButton(title: "Finish Setup", disabled: userName.isEmpty) {
                finishDispatcherOnboarding()
            }
        }
        .padding()
    }

    // MARK: - Step 2: AI Setup (driver only)

    private var aiStep: some View {
        VStack(spacing: 20) {
            Spacer()

            if appState.isAppleIntelligenceAvailable {
                VStack(spacing: 6) {
                    Image(systemName: "brain.filled.head.profile")
                        .font(.system(size: 44)).foregroundColor(.blue)
                    Text("Choose Your AI")
                        .font(.title2).fontWeight(.bold)
                    Text("Your phone has built-in AI that runs entirely on-device — no internet, no accounts, nothing leaves your phone.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button(action: { useAppleIntelligence() }) {
                        HStack {
                            Image(systemName: "apple.logo")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Apple Intelligence")
                                    .fontWeight(.semibold)
                                Text("On-device · Private · No API key")
                                    .font(.caption).opacity(0.85)
                            }
                            Spacer()
                            Image(systemName: "checkmark.shield.fill").opacity(0.85)
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
                                Text("Requires a free API key from console.anthropic.com")
                                    .font(.caption).opacity(0.8)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.2)))
                    }
                }
                .padding(.horizontal, 24)

                if appState.activeBackend == .claude { claudeKeySection }

            } else {
                VStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 44)).foregroundColor(.orange)
                    Text("Connect Your AI")
                        .font(.title2).fontWeight(.bold)
                }

                ScrollView {
                    VStack(spacing: 16) {
                        InfoCallout(icon: "key.fill", iconColor: .orange,
                            title: "What is an API key?",
                            message: "A unique passcode giving YOU private access to Anthropic's AI. Like your own CB frequency — nobody else can use yours, and it doesn't identify you personally.")
                        InfoCallout(icon: "lock.shield.fill", iconColor: .green,
                            title: "Your privacy",
                            message: "Your key lives only on this phone. Your voice goes straight to Anthropic — iTrucker never sees your conversations. Anthropic doesn't sell your data.")
                        InfoCallout(icon: "dollarsign.circle", iconColor: .blue,
                            title: "What does it cost?",
                            message: "Anthropic charges by usage — a typical day of voice commands runs a few cents. Set your own spending cap in the console so there are no surprises.")
                        InfoCallout(icon: "globe", iconColor: .purple,
                            title: "How do I get one?",
                            message: "Visit console.anthropic.com — takes about 2 minutes, just an email address. No subscription, no credit check.")
                        claudeKeySection
                    }
                    .padding(.vertical)
                }
            }

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var claudeKeySection: some View {
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
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)

            if case .invalid(let msg) = onboardingManager.keyValidationResult {
                Text(msg).font(.caption).foregroundColor(.red)
            }
            if case .valid = onboardingManager.keyValidationResult {
                Label("API key verified!", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundColor(.green)
            }
        }
        .padding(.horizontal, 24)

        if onboardingManager.isValidatingKey {
            ProgressView("Verifying…")
        } else if case .valid = onboardingManager.keyValidationResult {
            primaryButton(title: "Start Driving! 🚛", disabled: false) {
                finishDriverOnboarding()
            }
        } else {
            VStack(spacing: 10) {
                primaryButton(title: "Verify & Continue",
                              disabled: apiKeyInput.isEmpty,
                              color: apiKeyInput.isEmpty ? .gray : .blue) {
                    validateKey()
                }
                Button("Skip for now — add key in Settings later") {
                    finishDriverOnboarding()
                }
                .font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Shared button

    private func primaryButton(title: String, disabled: Bool, color: Color = .blue, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity).padding()
                .background(disabled ? Color.gray.opacity(0.4) : color)
                .foregroundColor(.white).cornerRadius(14)
        }
        .disabled(disabled)
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func useAppleIntelligence() {
        appState.activeBackend = .appleIntelligence
        finishDriverOnboarding()
    }

    private func validateKey() {
        let acc = getOrCreateAccount()
        Task { await onboardingManager.validateAndSaveKey(apiKeyInput, for: acc) }
    }

    private func finishDriverOnboarding() {
        let acc = getOrCreateAccount()
        onboardingManager.completeDriverOnboarding(
            account: acc,
            appState: appState,
            name: userName,
            cdlState: cdlState,
            cycle: selectedCycle
        )
        try? modelContext.save()
        isOnboardingComplete = true
    }

    private func finishDispatcherOnboarding() {
        onboardingManager.completeDispatcherOnboarding(
            appState: appState,
            name: userName,
            companyName: companyName
        )
        isOnboardingComplete = true
    }

    private func getOrCreateAccount() -> DriverAccount {
        if let existing = account { return existing }
        let acc = DriverAccount(driverID: appState.driverID, name: userName)
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
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor).frame(width: 24).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(message).font(.caption).foregroundColor(.secondary)
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
            Image(systemName: icon).foregroundColor(.green).frame(width: 18).padding(.top, 1)
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
