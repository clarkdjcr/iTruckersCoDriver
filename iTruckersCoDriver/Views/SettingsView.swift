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
    @State private var fixedCostInput = ""
    @State private var truckMPGInput = ""

    var body: some View {
        NavigationView {
            Form {
                appModeSection
                aiConfigSection
                driverProfileSection
                hosSection
                costEfficiencySection
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
    private var appModeSection: some View {
        Section {
            Picker("App Mode", selection: $appState.role) {
                ForEach(AppRole.allCases, id: \.self) { role in
                    Text(role.displayName).tag(role)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: appState.role == .driver ? "truck.box.fill" : "desktopcomputer")
                    .foregroundColor(.blue)
                Text(appState.role == .driver
                    ? "Driver mode: voice assistant, HOS, route, and compliance tools."
                    : "Dispatcher mode: fleet overview, messages, loads, and maintenance.")
                    .font(.caption).foregroundColor(.secondary)
            }
        } header: {
            Text("App Mode")
        }
    }

    @ViewBuilder
    private var aiConfigSection: some View {
        Section {
            // Backend picker (only shown when Apple Intelligence is available)
            if appState.isAppleIntelligenceAvailable {
                Picker("AI Backend", selection: $appState.activeBackend) {
                    ForEach(AIBackend.allCases, id: \.self) { backend in
                        Label(backend.displayName, systemImage: backend.iconName)
                            .tag(backend)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)

                if appState.activeBackend == .appleIntelligence {
                    HStack {
                        Image(systemName: "lock.shield.fill").foregroundColor(.green)
                        Text("On-device · No API key required · Works offline")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "info.circle").foregroundColor(.blue)
                    Text("Apple Intelligence requires iPhone 15 Pro or later.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // Claude API key — shown when Claude is selected or Apple Intelligence unavailable
            if appState.activeBackend == .claude || !appState.isAppleIntelligenceAvailable {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Claude API Key", systemImage: "key.fill")
                        .font(.subheadline).fontWeight(.medium)
                    Text("Get your key at console.anthropic.com")
                        .font(.caption).foregroundColor(.secondary)
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
                                .font(.caption).foregroundColor(.green)
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
            }
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
    private var costEfficiencySection: some View {
        Section {
            HStack {
                Text("Fixed Cost / Mile")
                Spacer()
                TextField("0.45", text: $fixedCostInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .frame(width: 80)
                Text("$").foregroundColor(.secondary)
            }
            HStack {
                Text("Truck MPG")
                Spacer()
                TextField("Auto", text: $truckMPGInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .frame(width: 80)
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").foregroundColor(.blue)
                Text("Leave MPG blank to compute automatically from your fuel records. Fixed cost covers insurance, truck payment, and other per-mile overhead.")
                    .font(.caption).foregroundColor(.secondary)
            }
        } header: {
            Text("Cost & Efficiency")
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0 (2)")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("AI Model")
                Spacer()
                Text(appState.activeBackend.modelLabel)
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
        fixedCostInput = String(format: "%.2f", appState.fixedCostPerMile)
        truckMPGInput = appState.truckMPG > 0 ? String(format: "%.1f", appState.truckMPG) : ""
    }

    private func save() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            KeychainHelper.save(trimmed, forKey: KeychainHelper.anthropicAPIKey)
        }

        appState.driverName = driverName
        appState.cdlState = cdlState
        appState.hosCycle = selectedCycle
        if let cpm = Double(fixedCostInput), cpm > 0 { appState.fixedCostPerMile = cpm }
        appState.truckMPG = Double(truckMPGInput) ?? 0

        showSavedAlert = true
    }
}
