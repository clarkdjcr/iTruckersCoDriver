//
//  DriverTaxProfile.swift
//  iTruckersCoDriver
//
//  Tax profile with smart classification for company drivers vs independent contractors.
//  Adapts UI and reporting based on driver type.
//

import Foundation
import SwiftData

// MARK: - Driver Type Classification

enum DriverType: String, Codable, CaseIterable, Identifiable {
    case companyDriver = "Company Driver"
    case independentContractor = "Independent Contractor (1099)"
    case ownerOperator = "Owner-Operator"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .companyDriver:
            return "W-2 employee driving company truck"
        case .independentContractor:
            return "1099 contractor driving company truck"
        case .ownerOperator:
            return "Own your truck, file Schedule C"
        }
    }
    
    var icon: String {
        switch self {
        case .companyDriver: return "building.2.fill"
        case .independentContractor: return "doc.text.fill"
        case .ownerOperator: return "truck.box.fill"
        }
    }
    
    // What tax forms they need
    var requiredForms: [TaxForm] {
        switch self {
        case .companyDriver:
            return []  // Company handles taxes (W-2)
        case .independentContractor:
            return [.schedule_C, .form_1040_ES, .form_8829_optional]
        case .ownerOperator:
            return [.schedule_C, .form_1040_ES, .form_4562, .form_8829_optional]
        }
    }
    
    // What expenses they can deduct
    var deductibleExpenses: [ExpenseCategory] {
        switch self {
        case .companyDriver:
            return [.meals, .lodging, .phone_partial, .supplies]  // Limited
        case .independentContractor:
            return [.meals, .lodging, .phone_partial, .supplies, .insurance, .licenses, .equipment]  // More
        case .ownerOperator:
            return ExpenseCategory.allCases  // Everything including fuel, maintenance, depreciation
        }
    }
    
    // Whether they need vehicle tracking
    var needsVehicleTracking: Bool {
        self == .ownerOperator
    }
    
    // Whether they need income tracking
    var needsIncomeTracking: Bool {
        self != .companyDriver
    }
    
    // Whether they need mileage tracking
    var needsMileageTracking: Bool {
        self == .ownerOperator
    }
}

enum TaxForm: String, CaseIterable {
    case schedule_C = "Schedule C (Business Profit/Loss)"
    case form_1040_ES = "Form 1040-ES (Estimated Tax)"
    case form_4562 = "Form 4562 (Depreciation)"
    case form_8829_optional = "Form 8829 (Home Office - Optional)"
}

enum ExpenseCategory: String, CaseIterable {
    case fuel = "Fuel"
    case maintenance = "Maintenance & Repairs"
    case insurance = "Insurance"
    case licenses = "Licenses & Permits"
    case tolls = "Tolls & Parking"
    case meals = "Meals (50% deductible)"
    case lodging = "Lodging"
    case phone_partial = "Phone/Data (business %)"
    case supplies = "Supplies & Equipment"
    case equipment = "Equipment Purchases"
    case depreciation = "Vehicle Depreciation"
}

// MARK: - Driver Tax Profile Model

@Model
class DriverTaxProfile {
    // MARK: Classification (REQUIRED - determines everything else)
    
    var driverType: DriverType = DriverType.independentContractor
    
    // MARK: Personal Information (REQUIRED for all contractors)
    
    var fullName: String = ""
    var socialSecurityNumber: String = ""  // Encrypted in production
    var dateOfBirth: Date?
    
    // MARK: Business Information
    
    var businessName: String?  // Optional: "Smith Trucking LLC"
    var ein: String?  // Employer ID Number (if LLC/Corp)
    var businessType: BusinessType = BusinessType.soleProprietor
    var businessStartDate: Date?
    
    // MARK: Address
    
    var streetAddress: String = ""
    var city: String = ""
    var state: String = ""
    var zipCode: String = ""
    
    // MARK: Tax Filing Details
    
    var filingStatus: FilingStatus = FilingStatus.single
    var numberOfDependents: Int = 0
    var spouseName: String?  // If married filing jointly
    
    // MARK: Prior Year Tax Info (for safe harbor)
    
    var priorYearAGI: Double?  // Adjusted Gross Income
    var priorYearTaxLiability: Double?  // Total tax owed
    
    // MARK: Company Driver Specific
    
    var employerName: String?  // Trucking company name
    var employerEIN: String?  // Company's EIN
    
    // MARK: Independent Contractor / Owner-Operator Specific
    
    var primaryBusinessCode: String = "484121"  // General freight trucking
    
    // MARK: Preferences
    
    var preferredDepreciationMethod: DepreciationMethod?
    var hasHomeOffice: Bool = false
    var wantsQuarterlyReminders: Bool = true
    
    // MARK: Metadata
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isComplete: Bool = false  // Profile setup finished?
    
    init() {}
    
    // MARK: - Computed Properties
    
    var displayName: String {
        businessName ?? fullName
    }
    
    var formattedAddress: String {
        "\(streetAddress), \(city), \(state) \(zipCode)"
    }
    
    var safeHarborAmount: Double? {
        guard let priorAGI = priorYearAGI, let priorTax = priorYearTaxLiability else {
            return nil
        }
        // Pay 100% of prior year's tax (110% if AGI > $150k)
        let percentage = priorAGI > 150_000 ? 1.10 : 1.00
        return priorTax * percentage
    }
    
    var isCompanyDriver: Bool {
        driverType == .companyDriver
    }
    
    var needsScheduleC: Bool {
        driverType != .companyDriver
    }
    
    var canDeductVehicleExpenses: Bool {
        driverType == .ownerOperator
    }
}

// MARK: - Supporting Enums

enum BusinessType: String, Codable, CaseIterable, Identifiable {
    case soleProprietor = "Sole Proprietor"
    case llc = "LLC"
    case sCorp = "S-Corporation"
    case partnership = "Partnership"
    
    var id: String { rawValue }
}

enum FilingStatus: String, Codable, CaseIterable, Identifiable {
    case single = "Single"
    case marriedFilingJointly = "Married Filing Jointly"
    case marriedFilingSeparately = "Married Filing Separately"
    case headOfHousehold = "Head of Household"
    case qualifyingWidow = "Qualifying Widow(er)"
    
    var id: String { rawValue }
    
    var standardDeduction2026: Double {
        switch self {
        case .single: return 14_600
        case .marriedFilingJointly: return 29_200
        case .marriedFilingSeparately: return 14_600
        case .headOfHousehold: return 21_900
        case .qualifyingWidow: return 29_200
        }
    }
}

enum DepreciationMethod: String, Codable, CaseIterable, Identifiable {
    case section179 = "Section 179 (Immediate Expensing)"
    case bonusDepreciation = "Bonus Depreciation (60% in 2024)"
    case macrs = "MACRS (5-year)"
    case standardMileage = "Standard Mileage Rate"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .section179:
            return "Deduct up to $1.16M immediately (most aggressive)"
        case .bonusDepreciation:
            return "Deduct 60% in first year, rest over 5 years"
        case .macrs:
            return "Deduct evenly over 5 years (conservative)"
        case .standardMileage:
            return "Use $0.67/mile rate (simplest, no vehicle expenses)"
        }
    }
}

// MARK: - Quarterly Income Model

@Model
class QuarterlyIncome {
    var year: Int
    var quarter: Int  // 1-4
    var driverType: DriverType
    
    // Income tracking
    var grossRevenue: Double = 0
    var form1099Income: [Income1099NEC] = []
    
    // Other income (optional)
    var otherIncome: Double?
    var otherIncomeDescription: String?
    
    // Calculated fields
    var totalIncome: Double {
        grossRevenue + (otherIncome ?? 0)
    }
    
    // Notes
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(year: Int, quarter: Int, driverType: DriverType) {
        self.year = year
        self.quarter = quarter
        self.driverType = driverType
    }
    
    var quarterLabel: String {
        "Q\(quarter) \(year)"
    }
}

// MARK: - 1099-NEC Form Data

struct Income1099NEC: Codable, Identifiable {
    var id: UUID = UUID()
    var payerName: String  // "ABC Logistics LLC"
    var payerEIN: String  // "XX-XXXXXXX"
    var payerAddress: String
    var nonemployeeCompensation: Double  // Box 1
    var federalTaxWithheld: Double?  // Box 4 (rare)
    var stateTaxWithheld: Double?  // Box 5 (rare)
    var stateIncome: Double?  // Box 6
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: nonemployeeCompensation)) ?? "$0.00"
    }
}

// MARK: - Vehicle Information (Owner-Operators Only)

@Model
class VehicleInfo {
    var year: Int
    var make: String
    var model: String
    var vin: String
    
    // Purchase details
    var purchaseDate: Date
    var purchasePrice: Double
    var placedInServiceDate: Date
    
    // Depreciation
    var depreciationMethod: DepreciationMethod
    var section179Deduction: Double?
    var bonusDepreciation: Double?
    var accumulatedDepreciation: Double = 0
    
    // Usage
    var totalMiles: Int = 0
    var businessMileagePercentage: Double = 100.0  // Usually 100% for trucks
    
    // Loan info (optional)
    var hasLoan: Bool = false
    var loanAmount: Double?
    var monthlyPayment: Double?
    var interestRate: Double?
    
    // Insurance
    var annualInsuranceCost: Double?
    var registrationCost: Double?
    
    var createdAt: Date = Date()
    
    init(year: Int, make: String, model: String, vin: String, purchaseDate: Date, purchasePrice: Double) {
        self.year = year
        self.make = make
        self.model = model
        self.vin = vin
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.placedInServiceDate = purchaseDate
        self.depreciationMethod = .section179
    }
    
    var displayName: String {
        "\(year) \(make) \(model)"
    }
    
    var currentDepreciation: Double {
        // Simplified calculation - in production use IRS tables
        switch depreciationMethod {
        case .section179:
            return section179Deduction ?? 0
        case .bonusDepreciation:
            return bonusDepreciation ?? 0
        case .macrs:
            // 5-year MACRS schedule: Year 1 = 20%
            return purchasePrice * 0.20
        case .standardMileage:
            return 0  // Built into mileage rate
        }
    }
}

// MARK: - Extensions

extension DriverTaxProfile {
    /// Validates if profile is complete enough for tax filing
    func validate() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Required for everyone
        if fullName.isEmpty {
            issues.append(.init(field: "Full Name", message: "Legal name is required"))
        }
        
        if socialSecurityNumber.isEmpty {
            issues.append(.init(field: "SSN", message: "Social Security Number is required"))
        }
        
        if streetAddress.isEmpty || city.isEmpty || state.isEmpty || zipCode.isEmpty {
            issues.append(.init(field: "Address", message: "Complete address is required"))
        }
        
        // Required for contractors/owners
        if needsScheduleC {
            if businessType == .llc && ein == nil {
                issues.append(.init(field: "EIN", message: "LLC requires EIN"))
            }
            
            if businessStartDate == nil {
                issues.append(.init(field: "Business Start Date", message: "When did you start trucking?"))
            }
        }
        
        // Required for company drivers
        if isCompanyDriver {
            if employerName == nil {
                issues.append(.init(field: "Employer", message: "Company name is required"))
            }
        }
        
        return issues
    }
    
    struct ValidationIssue {
        let field: String
        let message: String
    }
}
