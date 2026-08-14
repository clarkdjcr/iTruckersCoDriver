//
//  SettingsView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var driverName = ""
    @State private var cdlState = ""
    @State private var selectedCycle: HOSCycle = .seventyHour
    @State private var isELogMode = true
    @State private var showSavedAlert = false
    @State private var fixedCostInput = ""
    @State private var truckMPGInput = ""
    @State private var selectedDriverType: DriverType = .independentContractor

    var body: some View {
        NavigationStack {
            Form {
                assistantSection
                driverProfileSection
                hosSection
                if selectedDriverType == .ownerOperator {
                    costEfficiencySection
                }
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
    private var assistantSection: some View {
        Section {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: appState.isAppleIntelligenceAvailable ? "lock.shield.fill" : "info.circle")
                    .foregroundColor(appState.isAppleIntelligenceAvailable ? .green : .blue)
                Text(appState.isAppleIntelligenceAvailable
                    ? "Co-Driver runs on-device with Apple Intelligence — private, no account or API key, works offline."
                    : "The voice assistant needs Apple Intelligence (iPhone 15 Pro or later). HOS, compliance, and reports work on any device.")
                    .font(.caption).foregroundColor(.secondary)
            }
        } header: {
            Text("Co-Driver Assistant")
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
            Picker("Work & Tax Status", selection: $selectedDriverType) {
                ForEach(DriverType.allCases) { driverType in
                    Text(driverType.rawValue).tag(driverType)
                }
            }
            Text(selectedDriverType.description)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    #endif
                    .foregroundColor(.secondary)
                    .frame(width: 80)
                Text("$").foregroundColor(.secondary)
            }
            HStack {
                Text("Truck MPG")
                Spacer()
                TextField("Auto", text: $truckMPGInput)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    #endif
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
                Text("2.1 (9)")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Assistant")
                Spacer()
                Text("Apple Intelligence (on-device)")
                    .foregroundColor(.secondary)
            }
            Link("FMCSA HOS Regulations", destination: URL(string: "https://www.fmcsa.dot.gov/regulations/hours-service/summary-hours-service-regulations")!)
        }
    }

    private func loadCurrentSettings() {
        driverName = appState.driverName
        cdlState = appState.cdlState
        selectedCycle = appState.hosCycle
        selectedDriverType = appState.driverType
        fixedCostInput = String(format: "%.2f", appState.fixedCostPerMile)
        truckMPGInput = appState.truckMPG > 0 ? String(format: "%.1f", appState.truckMPG) : ""
    }

    private func save() {
        appState.driverName = driverName
        appState.cdlState = cdlState
        appState.hosCycle = selectedCycle
        appState.driverType = selectedDriverType
        if let cpm = Double(fixedCostInput), cpm > 0 { appState.fixedCostPerMile = cpm }
        appState.truckMPG = Double(truckMPGInput) ?? 0

        showSavedAlert = true
    }
}
