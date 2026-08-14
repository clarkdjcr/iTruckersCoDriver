//
//  TaxBucket.swift
//  iTruckersCoDriver
//
//  Stable bookkeeping categories used for quarterly expense summaries.
//

import Foundation

enum TaxBucket: String, CaseIterable, Codable, Identifiable {
    case fuel
    case repairsMaintenance
    case tires
    case truckLease
    case insurance
    case permitsLicenses
    case travel
    case meals
    case scales
    case suppliesGear
    case technology
    case professionalServices
    case interest
    case depreciableEquipment
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fuel: return "Fuel"
        case .repairsMaintenance: return "Repairs & Maintenance"
        case .tires: return "Tires"
        case .truckLease: return "Truck & Trailer Lease"
        case .insurance: return "Insurance"
        case .permitsLicenses: return "Permits & Licenses"
        case .travel: return "Travel"
        case .meals: return "Meals"
        case .scales: return "Scale & Weigh Fees"
        case .suppliesGear: return "Supplies & Gear"
        case .technology: return "Technology"
        case .professionalServices: return "Professional Services"
        case .interest: return "Interest"
        case .depreciableEquipment: return "Depreciable Equipment"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .fuel: return "fuelpump.fill"
        case .repairsMaintenance: return "wrench.and.screwdriver.fill"
        case .tires: return "circle.circle.fill"
        case .truckLease: return "truck.box.fill"
        case .insurance: return "shield.fill"
        case .permitsLicenses: return "doc.text.fill"
        case .travel: return "bed.double.fill"
        case .meals: return "fork.knife"
        case .scales: return "scalemass.fill"
        case .suppliesGear: return "shippingbox.fill"
        case .technology: return "iphone"
        case .professionalServices: return "person.crop.rectangle.stack.fill"
        case .interest: return "percent"
        case .depreciableEquipment: return "gearshape.2.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }

    var examples: String {
        switch self {
        case .fuel: return "Diesel, DEF, reefer fuel"
        case .repairsMaintenance: return "Service, parts, oil, roadside repairs"
        case .tires: return "Truck and trailer tires"
        case .truckLease: return "Truck or trailer lease payments"
        case .insurance: return "Liability, cargo, physical damage"
        case .permitsLicenses: return "UCR, registration, permits"
        case .travel: return "Lodging, tolls, parking"
        case .meals: return "Meals while traveling for business"
        case .scales: return "CAT Scale and weigh fees"
        case .suppliesGear: return "Safety gear, logbooks, tools"
        case .technology: return "Business use of phone, data, ELD"
        case .professionalServices: return "Accounting, legal, dispatch services"
        case .interest: return "Business loan interest"
        case .depreciableEquipment: return "Long-lived equipment purchases"
        case .other: return "Other business expense"
        }
    }

    var supportsBusinessUse: Bool {
        self == .technology || self == .depreciableEquipment
    }

    static func allowed(for driverType: DriverType) -> [TaxBucket] {
        switch driverType {
        case .ownerOperator:
            return allCases
        case .independentContractor:
            return [.travel, .meals, .scales, .suppliesGear, .technology, .professionalServices, .other]
        case .companyDriver:
            return [.travel, .meals, .suppliesGear, .technology, .other]
        }
    }

    func isAllowed(for driverType: DriverType) -> Bool {
        Self.allowed(for: driverType).contains(self)
    }

    static func resolve(_ category: String) -> TaxBucket {
        if let exact = TaxBucket(rawValue: category) { return exact }

        switch category.lowercased() {
        case "diesel", "def", "reefer fuel", "gas", "gasoline": return .fuel
        case "repair", "repairs", "maintenance", "service", "oil": return .repairsMaintenance
        case "tire", "tyres": return .tires
        case "lease", "truck lease", "trailer lease", "rent": return .truckLease
        case "insurance", "cargo insurance", "liability insurance": return .insurance
        case "permit", "permits", "license", "licenses", "registration", "ucr": return .permitsLicenses
        case "lodging", "hotel", "motel", "tolls", "toll", "parking": return .travel
        case "meal", "meals", "restaurant", "food": return .meals
        case "scale", "scales", "weigh": return .scales
        case "supplies", "gear", "equipment", "safety": return .suppliesGear
        case "phone", "cell", "data", "eld", "technology": return .technology
        case "accounting", "legal", "dispatch", "professional": return .professionalServices
        case "interest", "finance charge": return .interest
        case "asset", "depreciation", "depreciable equipment": return .depreciableEquipment
        default: return .other
        }
    }

    static func suggested(from text: String) -> TaxBucket {
        let value = text.lowercased()
        let rules: [(TaxBucket, [String])] = [
            (.fuel, ["diesel", "gallon", "fuel", "def", "pilot", "flying j", "love's", "loves", "ta petro"]),
            (.scales, ["cat scale", "weigh ticket", "scale fee"]),
            (.tires, ["tire", "tyre", "goodyear", "michelin"]),
            (.repairsMaintenance, ["repair", "service", "maintenance", "oil change", "roadside", "parts"]),
            (.permitsLicenses, ["permit", "registration", "license", "ucr"]),
            (.insurance, ["insurance", "premium", "liability", "cargo coverage"]),
            (.truckLease, ["lease payment", "truck rental", "trailer rental"]),
            (.meals, ["restaurant", "diner", "cafe", "food", "meal", "mcdonald", "subway"]),
            (.travel, ["hotel", "motel", "inn", "lodging", "toll", "parking"]),
            (.technology, ["phone", "wireless", "cellular", "internet", "eld", "subscription"]),
            (.professionalServices, ["accounting", "bookkeeping", "legal", "dispatch service"]),
            (.suppliesGear, ["safety", "work gloves", "logbook", "cb radio", "truck stop supplies"])
        ]

        return rules.first(where: { _, keywords in
            keywords.contains(where: value.contains)
        })?.0 ?? .other
    }

    static func suggested(from text: String, for driverType: DriverType) -> TaxBucket {
        let suggestion = suggested(from: text)
        return suggestion.isAllowed(for: driverType) ? suggestion : .other
    }
}
