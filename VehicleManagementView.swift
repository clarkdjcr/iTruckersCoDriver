//
//  VehicleManagementView.swift
//  iTruckersCoDriver
//
//  Vehicle tracking, depreciation calculator, and mileage management
//  for owner-operators. Hidden for company drivers and independent contractors.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct VehicleManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var vehicles: [VehicleInfo]
    @Query private var profiles: [DriverTaxProfile]
    
    @State private var showingAddVehicle = false
    @State private var selectedVehicle: VehicleInfo?
    
    private var profile: DriverTaxProfile? {
        profiles.first
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if let profile = profile, !profile.canDeductVehicleExpenses {
                notApplicableView
            } else {
                mainContent
            }
        }
        .navigationTitle("My Vehicles")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if profile?.canDeductVehicleExpenses == true {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Label("Add Vehicle", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddVehicle) {
            AddVehicleView()
        }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailView(vehicle: vehicle)
        }
    }
    
    // MARK: - Not Applicable View
    
    private var notApplicableView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "truck.box.badge.clock.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.primaryGradient)
            
            Text("Vehicle Tracking Not Needed")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            
            Text(profile?.driverType == .companyDriver
                 ? "Company drivers use company-owned vehicles. No vehicle expenses to track."
                 : "Independent contractors drive company trucks. Vehicle expenses are not deductible.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        Group {
            if vehicles.isEmpty {
                emptyStateView
            } else {
                vehicleListView
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "truck.box.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.primaryGradient)
            
            Text("Add Your Truck")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            
            Text("Track depreciation, mileage, and vehicle expenses for maximum tax deductions.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingAddVehicle = true
            } label: {
                Label("Add Vehicle", systemImage: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Theme.primaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Vehicle List
    
    private var vehicleListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(vehicles) { vehicle in
                    VehicleCard(vehicle: vehicle) {
                        selectedVehicle = vehicle
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Vehicle Card

struct VehicleCard: View {
    let vehicle: VehicleInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.displayName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("VIN: \(vehicle.vin)")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.textSecondary)
                }
                
                Divider()
                
                // Stats
                HStack(spacing: 16) {
                    statColumn(
                        icon: "dollarsign.circle.fill",
                        label: "Purchase",
                        value: formatCurrency(vehicle.purchasePrice)
                    )
                    
                    Divider()
                        .frame(height: 40)
                    
                    statColumn(
                        icon: "chart.line.downtrend.xyaxis",
                        label: "Depreciation",
                        value: formatCurrency(vehicle.currentDepreciation)
                    )
                    
                    Divider()
                        .frame(height: 40)
                    
                    statColumn(
                        icon: "gauge.high",
                        label: "Miles",
                        value: formatNumber(vehicle.totalMiles)
                    )
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private func statColumn(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Theme.primary)
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "0"
    }
}

// MARK: - Add Vehicle View

struct AddVehicleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var make = ""
    @State private var model = ""
    @State private var vin = ""
    @State private var purchaseDate = Date()
    @State private var purchasePrice: Double = 0
    @State private var depreciationMethod: DepreciationMethod = .section179
    @State private var hasLoan = false
    @State private var loanAmount: Double? = nil
    @State private var showingValidation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Vehicle Information") {
                    Stepper("Year: \(year)", value: $year, in: 1990...2030)
                    
                    TextField("Make (e.g., Freightliner)", text: $make)
                    
                    TextField("Model (e.g., Cascadia)", text: $model)
                    
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                Section("Purchase Details") {
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                    
                    TextField("Purchase Price", value: $purchasePrice, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                Section("Depreciation Method") {
                    Picker("Method", selection: $depreciationMethod) {
                        ForEach(DepreciationMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    
                    Text(depreciationMethod.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                Section("Loan Information") {
                    Toggle("Financed Purchase", isOn: $hasLoan)
                    
                    if hasLoan {
                        TextField("Loan Amount", value: $loanAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveVehicle() }
                        .disabled(!canSave)
                }
            }
            .alert("Missing Information", isPresented: $showingValidation) {
                Button("OK") { }
            } message: {
                Text("Please fill in all required fields")
            }
        }
    }
    
    private var canSave: Bool {
        !make.isEmpty && !model.isEmpty && !vin.isEmpty && purchasePrice > 0
    }
    
    private func saveVehicle() {
        guard canSave else {
            showingValidation = true
            return
        }
        
        let vehicle = VehicleInfo(
            year: year,
            make: make,
            model: model,
            vin: vin,
            purchaseDate: purchaseDate,
            purchasePrice: purchasePrice
        )
        
        vehicle.depreciationMethod = depreciationMethod
        vehicle.hasLoan = hasLoan
        vehicle.loanAmount = hasLoan ? loanAmount : nil
        
        // Calculate initial depreciation based on method
        calculateDepreciation(for: vehicle)
        
        modelContext.insert(vehicle)
        try? modelContext.save()
        
        HapticManager.shared.success()
        dismiss()
    }
    
    private func calculateDepreciation(for vehicle: VehicleInfo) {
        switch vehicle.depreciationMethod {
        case .section179:
            // Can deduct up to $1,160,000 immediately (2024 limit)
            vehicle.section179Deduction = min(vehicle.purchasePrice, 1_160_000)
            
        case .bonusDepreciation:
            // 60% in 2024 (phases down each year)
            vehicle.bonusDepreciation = vehicle.purchasePrice * 0.60
            
        case .macrs:
            // Year 1 of 5-year MACRS: 20%
            vehicle.accumulatedDepreciation = vehicle.purchasePrice * 0.20
            
        case .standardMileage:
            // No depreciation tracking - built into mileage rate
            break
        }
    }
}

// MARK: - Vehicle Detail View

struct VehicleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vehicle: VehicleInfo
    
    var body: some View {
        NavigationView {
            Form {
                Section("Vehicle") {
                    HStack {
                        Text("Vehicle")
                        Spacer()
                        Text(vehicle.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("VIN")
                        Spacer()
                        Text(vehicle.vin)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Purchase Date")
                        Spacer()
                        Text(vehicle.purchaseDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Purchase Price")
                        Spacer()
                        Text(formatCurrency(vehicle.purchasePrice))
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                Section("Depreciation") {
                    HStack {
                        Text("Method")
                        Spacer()
                        Text(vehicle.depreciationMethod.rawValue)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Current Year Deduction")
                        Spacer()
                        Text(formatCurrency(vehicle.currentDepreciation))
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                    
                    if vehicle.accumulatedDepreciation > 0 {
                        HStack {
                            Text("Total Accumulated")
                            Spacer()
                            Text(formatCurrency(vehicle.accumulatedDepreciation))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                Section("Usage") {
                    Stepper("Total Miles: \(vehicle.totalMiles)", value: $vehicle.totalMiles, in: 0...1_000_000, step: 1000)
                    
                    HStack {
                        Text("Business Use")
                        Spacer()
                        Text("\(Int(vehicle.businessMileagePercentage))%")
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                if vehicle.hasLoan {
                    Section("Loan") {
                        if let loanAmount = vehicle.loanAmount {
                            HStack {
                                Text("Loan Amount")
                                Spacer()
                                Text(formatCurrency(loanAmount))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        TextField("Monthly Payment", value: $vehicle.monthlyPayment, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                        
                        TextField("Interest Rate (%)", value: $vehicle.interestRate, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                
                Section("Annual Costs") {
                    TextField("Insurance", value: $vehicle.annualInsuranceCost, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    
                    TextField("Registration", value: $vehicle.registrationCost, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

#endif
