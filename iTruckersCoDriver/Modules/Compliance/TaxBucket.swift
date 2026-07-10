//
//  TaxBucket.swift
//  iTruckersCoDriver
//
//  Deductible expense categories for a 1099 company driver.
//  The truck is company-provided, so fuel/maintenance of the truck are NOT
//  the driver's deductions — these buckets cover only his out-of-pocket costs.
//

import Foundation

/// IRS Schedule C–style buckets a 1099 driver reports quarterly.
enum TaxBucket: String, CaseIterable, Codable, Identifiable {
    case travel        // Lodging, tolls, parking
    case suppliesGear  // CB radios, GPS units, logbooks, safety equipment
    case technology    // Business portion of cell phone, data plans, ELD services
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .travel: return "Travel"
        case .suppliesGear: return "Supplies & Gear"
        case .technology: return "Technology"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .travel: return "bed.double.fill"
        case .suppliesGear: return "shippingbox.fill"
        case .technology: return "iphone"
        case .other: return "square.grid.2x2.fill"
        }
    }

    /// Short hint describing what belongs in this bucket, shown in the entry form.
    var examples: String {
        switch self {
        case .travel: return "Lodging, tolls, parking"
        case .suppliesGear: return "CB radio, GPS, logbooks, safety gear"
        case .technology: return "Business % of phone, data, ELD service"
        case .other: return "Other deductible business expense"
        }
    }

    /// Buckets that commonly mix personal and business use, where only the
    /// business portion is deductible (e.g. a personal cell phone used for work).
    var supportsBusinessUse: Bool { self == .technology }

    /// Resolves a stored category string to a bucket, tolerating legacy
    /// voice-logged categories (e.g. "lodging", "tolls") from earlier builds.
    static func resolve(_ category: String) -> TaxBucket {
        if let exact = TaxBucket(rawValue: category) { return exact }
        switch category.lowercased() {
        case "lodging", "tolls", "toll", "parking": return .travel
        case "supplies", "gear", "equipment", "safety": return .suppliesGear
        case "phone", "cell", "data", "eld", "technology": return .technology
        default: return .other
        }
    }
}
