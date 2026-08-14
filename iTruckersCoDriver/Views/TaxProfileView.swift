//
//  TaxProfileView.swift
//  iTruckersCoDriver
//
//  Detailed driver profile form capturing IRS tax requirements.
//

import SwiftUI
import SwiftData

struct TaxProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [DriverTaxProfile]

    @State private var fullName = ""
    @State private var ssn = ""
    @State private var dateOfBirth = Date()
    @State private var businessName = ""
    @State private var ein = ""
    @State private var businessType: BusinessType = .soleProprietor
    @State private var businessStartDate = Date()
    @State private var streetAddress = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var filingStatus: FilingStatus = .single
    @State private var numberOfDependents = 0
    @State private var spouseName = ""
    @State private var priorYearAGI = ""
    @State private var priorYearTaxLiability = ""
    @State private var employerName = ""
    @State private var employerEIN = ""
    @State private var primaryBusinessCode = "484121"
    @State private var hasHomeOffice = false
    @State private var wantsQuarterlyReminders = true
    
    @State private var showSavedAlert = false
    @State private var driverType: DriverType = .independentContractor

    private var activeProfile: DriverTaxProfile? {
        profiles.first
    }

    var body: some View {
        Form {
            Section("Tax Classification") {
                HStack {
                    Text("Driver Type")
                    Spacer()
                    Text(driverType.rawValue)
                        .foregroundColor(.secondary)
                }
                
                Text(driverType.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Personal Information (Legal)") {
                TextField("Legal Full Name", text: $fullName)
                
                TextField("Social Security Number (SSN)", text: $ssn)
                    .keyboardType(.numberPad)
                
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
            }
            
            Section("Business Address") {
                TextField("Street Address", text: $streetAddress)
                TextField("City", text: $city)
                HStack {
                    TextField("State", text: $state)
                        .textInputAutocapitalization(.characters)
                    TextField("ZIP Code", text: $zipCode)
                        .keyboardType(.numberPad)
                }
            }

            if driverType == .companyDriver {
                Section("W-2 Employer Information") {
                    TextField("Employer Name", text: $employerName)
                    TextField("Employer EIN", text: $employerEIN)
                        .keyboardType(.numberPad)
                }
            } else {
                Section("Business Details (Schedule C)") {
                    TextField("Business Name (optional)", text: $businessName)
                    TextField("Employer ID Number (EIN - optional)", text: $ein)
                        .keyboardType(.numberPad)
                    
                    Picker("Business Structure", selection: $businessType) {
                        ForEach(BusinessType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    TextField("Primary Business Code", text: $primaryBusinessCode)
                        .keyboardType(.numberPad)
                    
                    DatePicker("Business Start Date", selection: $businessStartDate, displayedComponents: .date)
                }
                
                Section("Safe Harbor & Estimated Taxes (Form 1040-ES)") {
                    HStack {
                        Text("Prior Year AGI")
                        Spacer()
                        TextField("0.00", text: $priorYearAGI)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Prior Year Tax Liability")
                        Spacer()
                        TextField("0.00", text: $priorYearTaxLiability)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if let pAGI = Double(priorYearAGI), let pTax = Double(priorYearTaxLiability) {
                        let threshold = pAGI > 150_000 ? 1.10 : 1.00
                        let estimatedQuarterly = (pTax * threshold) / 4.0
                        HStack {
                            Text("Safe Harbor Quarterly Target")
                                .font(.subheadline)
                                .bold()
                            Spacer()
                            Text(estimatedQuarterly, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text("IRS Safe Harbor guidelines protect you from underpayment penalties if your estimated quarterly payments equal at least 100% (or 110% for high income) of your prior year's total tax liability.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Filing Information") {
                Picker("Filing Status", selection: $filingStatus) {
                    ForEach(FilingStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                
                if filingStatus == .marriedFilingJointly {
                    TextField("Spouse Name", text: $spouseName)
                }
                
                Stepper("Dependents: \(numberOfDependents)", value: $numberOfDependents, in: 0...20)
            }
            
            Section("Preferences") {
                if driverType != .companyDriver {
                    Toggle("Has Home Office (Form 8829)", isOn: $hasHomeOffice)
                }
                Toggle("Remind me of Quarterly Deadlines", isOn: $wantsQuarterlyReminders)
            }
        }
        .navigationTitle("Tax Profile Details")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveProfile() }
            }
        }
        .alert("Tax Profile Saved", isPresented: $showSavedAlert) {
            Button("OK") {}
        }
        .onAppear { loadProfileData() }
    }
    
    private func loadProfileData() {
        if let profile = activeProfile {
            fullName = profile.fullName
            ssn = profile.socialSecurityNumber
            if let dob = profile.dateOfBirth { dateOfBirth = dob }
            businessName = profile.businessName ?? ""
            ein = profile.ein ?? ""
            businessType = profile.businessType
            if let start = profile.businessStartDate { businessStartDate = start }
            streetAddress = profile.streetAddress
            city = profile.city
            state = profile.state
            zipCode = profile.zipCode
            filingStatus = profile.filingStatus
            numberOfDependents = profile.numberOfDependents
            spouseName = profile.spouseName ?? ""
            if let agi = profile.priorYearAGI { priorYearAGI = String(format: "%.2f", agi) }
            if let tax = profile.priorYearTaxLiability { priorYearTaxLiability = String(format: "%.2f", tax) }
            employerName = profile.employerName ?? ""
            employerEIN = profile.employerEIN ?? ""
            primaryBusinessCode = profile.primaryBusinessCode
            hasHomeOffice = profile.hasHomeOffice
            wantsQuarterlyReminders = profile.wantsQuarterlyReminders
            driverType = profile.driverType
        }
    }
    
    private func saveProfile() {
        let profile = activeProfile ?? DriverTaxProfile()
        profile.fullName = fullName
        profile.socialSecurityNumber = ssn
        profile.dateOfBirth = dateOfBirth
        profile.businessName = businessName.isEmpty ? nil : businessName
        profile.ein = ein.isEmpty ? nil : ein
        profile.businessType = businessType
        profile.businessStartDate = businessStartDate
        profile.streetAddress = streetAddress
        profile.city = city
        profile.state = state
        profile.zipCode = zipCode
        profile.filingStatus = filingStatus
        profile.numberOfDependents = numberOfDependents
        profile.spouseName = spouseName.isEmpty ? nil : spouseName
        profile.priorYearAGI = Double(priorYearAGI)
        profile.priorYearTaxLiability = Double(priorYearTaxLiability)
        profile.employerName = employerName.isEmpty ? nil : employerName
        profile.employerEIN = employerEIN.isEmpty ? nil : employerEIN
        profile.primaryBusinessCode = primaryBusinessCode
        profile.hasHomeOffice = hasHomeOffice
        profile.wantsQuarterlyReminders = wantsQuarterlyReminders
        profile.driverType = driverType
        profile.isComplete = !fullName.isEmpty && !ssn.isEmpty && !streetAddress.isEmpty
        profile.updatedAt = Date()
        
        if activeProfile == nil {
            modelContext.insert(profile)
        }
        
        try? modelContext.save()
        showSavedAlert = true
    }
}
