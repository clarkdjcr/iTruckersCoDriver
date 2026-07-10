//
//  OnboardingView.swift
//  iTruckersCoDriver
//
//  Two-step driver onboarding:
//    Step 0 — Welcome
//    Step 1 — Driver profile (name / CDL state / HOS cycle)
//  The Co-Driver assistant runs on-device via Apple Intelligence — no account,
//  no API key, nothing to configure.
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
    @State private var userName = ""
    @State private var cdlState = ""
    @State private var selectedCycle: HOSCycle = .seventyHour
    @State private var account: DriverAccount?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0: welcomeStep
                    default: profileStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .animation(.easeInOut(duration: 0.3), value: step)
            }
            .navigationTitle(step == 0 ? "Welcome" : "Driver Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                Text("🚛").font(.system(size: 72))
                Text("iTrucker's Co-Driver")
                    .font(.largeTitle).fontWeight(.bold)
                Text("Your voice-first companion for HOS, compliance, expenses, and tax paperwork — with an assistant that runs entirely on your iPhone.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 32)

            VStack(spacing: 12) {
                privacyRow(icon: "lock.shield.fill", text: "On-device assistant — private, works offline, no account or API key.")
                privacyRow(icon: "doc.text.fill", text: "Generates tax & IFTA reports you can share anywhere.")
            }
            .padding(.horizontal, 32)

            Spacer()

            primaryButton(title: "Get Started", disabled: false) {
                withAnimation { step = 1 }
            }
        }
        .padding()
    }

    // MARK: - Step 1: Driver profile

    private var profileStep: some View {
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

            if !appState.isAppleIntelligenceAvailable {
                Text("Note: the voice assistant needs Apple Intelligence (iPhone 15 Pro or later). Everything else works on any device.")
                    .font(.caption).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            primaryButton(title: "Start Driving! 🚛", disabled: userName.isEmpty) {
                finishDriverOnboarding()
            }
        }
        .padding()
    }

    // MARK: - Shared views

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green).frame(width: 24).padding(.top, 2)
            Text(text).font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private func primaryButton(title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity).padding()
                .background(disabled ? Color.gray.opacity(0.4) : Color.blue)
                .foregroundColor(.white).cornerRadius(14)
        }
        .disabled(disabled)
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

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

    private func getOrCreateAccount() -> DriverAccount {
        if let existing = account { return existing }
        let acc = DriverAccount(driverID: appState.driverID, name: userName)
        modelContext.insert(acc)
        account = acc
        return acc
    }
}
#endif
