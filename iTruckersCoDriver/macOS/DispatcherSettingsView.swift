//
//  DispatcherSettingsView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI

#if os(macOS)
struct DispatcherSettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var dispatcherName = ""
    @State private var apiKeyInput = ""
    @State private var showAPIKey = false
    @State private var showSavedAlert = false

    var body: some View {
        Form {
            Section("Dispatcher") {
                TextField("Your name / company", text: $dispatcherName)
            }

            Section("Claude API Key") {
                Text("Optional — enables AI-assisted fleet summaries and dispatch drafting.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    if showAPIKey {
                        TextField("sk-ant-...", text: $apiKeyInput)
                    } else {
                        SecureField("sk-ant-...", text: $apiKeyInput)
                    }
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    if appState.hasAPIKey {
                        Label("API key configured", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
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

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondary)
                }
                HStack {
                    Text("AI Model")
                    Spacer()
                    Text("Claude Opus 4.6").foregroundColor(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
        .onAppear { load() }
        .alert("Settings Saved", isPresented: $showSavedAlert) {
            Button("OK") {}
        }
    }

    private func load() {
        dispatcherName = UserDefaults.standard.string(forKey: "dispatcherName") ?? ""
        if let key = appState.apiKey { apiKeyInput = key }
    }

    private func save() {
        UserDefaults.standard.set(dispatcherName, forKey: "dispatcherName")
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            KeychainHelper.save(trimmed, forKey: KeychainHelper.anthropicAPIKey)
        }
        showSavedAlert = true
    }
}
#endif
