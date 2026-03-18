//
//  SettingsView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var apiKeyInput = ""
    @State private var driverName = ""
    @State private var cdlState = ""
    @State private var selectedCycle: HOSCycle = .seventyHour
    @State private var isELogMode = true
    @State private var showAPIKey = false
    @State private var showSavedAlert = false

    var body: some View {
        NavigationView {
            Form {
                aiConfigSection
                driverProfileSection
                hosSection
                aboutSection
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Settings Saved", isPresented: $showSavedAlert) {
                Button("OK") {}
            }
            .onAppear { loadCurrentSettings() }
        }
    }

    @ViewBuilder
    private var aiConfigSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label("Claude API Key", systemImage: "key.fill")
                    .font(.headline)
                Text("Required for AI voice interaction. Get your key at console.anthropic.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    if showAPIKey {
                        TextField("sk-ant-...", text: $apiKeyInput)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    } else {
                        SecureField("sk-ant-...", text: $apiKeyInput)
                            .autocorrectionDisabled()
                    }
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                HStack {
                    if appState.hasAPIKey {
                        Label("API key configured", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    if appState.hasAPIKey {
                        Button("Remove", role: .destructive) {
                            KeychainHelper.delete(forKey: KeychainHelper.anthropicAPIKey)
                            apiKeyInput = ""
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("AI Configuration")
        }
    }

    @ViewBuilder
    private var driverProfileSection: some View {
        Section("Driver Profile") {
            HStack {
                Text("Name")
                Spacer()
                TextField("Your name", text: $driverName)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("CDL State")
                Spacer()
                TextField("TX", text: $cdlState)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
        }
    }

    @ViewBuilder
    private var hosSection: some View {
        Section("Hours of Service") {
            Picker("HOS Cycle", selection: $selectedCycle) {
                Text("70 hours / 8 days").tag(HOSCycle.seventyHour)
                Text("60 hours / 7 days").tag(HOSCycle.sixtyHour)
            }
            Toggle("eLog Mode", isOn: $isELogMode)
            if !isELogMode {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Paper log mode: entries are still recorded digitally for reference.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("AI Model")
                Spacer()
                Text("Claude Opus 4.6")
                    .foregroundColor(.secondary)
            }
            Link("Anthropic Console", destination: URL(string: "https://console.anthropic.com")!)
            Link("FMCSA HOS Regulations", destination: URL(string: "https://www.fmcsa.dot.gov/regulations/hours-service/summary-hours-service-regulations")!)
        }
    }

    private func loadCurrentSettings() {
        if let key = appState.apiKey { apiKeyInput = key }
        driverName = appState.driverName
        cdlState = appState.cdlState
        selectedCycle = appState.hosCycle
    }

    private func save() {
        // Save API key to Keychain
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            KeychainHelper.save(trimmed, forKey: KeychainHelper.anthropicAPIKey)
        }

        // Save preferences
        appState.driverName = driverName
        appState.cdlState = cdlState
        appState.hosCycle = selectedCycle

        showSavedAlert = true
    }
}
