//
//  LoadOpportunity.swift
//  iTruckersCoDriver
//
//  Created by Codex on 6/26/26.
//

import Foundation
import SwiftData

@Model
final class LoadOpportunity {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var statusRaw: String = LoadOpportunityStatus.draft.rawValue
    var tripRecordID: String = ""

    var loadNumber: String = ""
    var brokerName: String = ""
    var origin: String = ""
    var destination: String = ""
    var pickupDate: Date = Date()
    var deliveryDate: Date = Date()
    var notes: String = ""

    var linehaulRate: Double = 0
    var loadedMiles: Double = 0
    var deadheadMiles: Double = 0
    var tolls: Double = 0
    var permits: Double = 0
    var brokerFee: Double = 0

    var fuelPricePerGallon: Double = 4.25
    var mpg: Double = 6.5
    var maintenanceReservePerMile: Double = 0.18
    var fixedCostPerMile: Double = 0.45
    var taxReserveRate: Double = 0.18
    var targetProfitPerMile: Double = 0.65

    var driveHoursAvailable: Double = 0
    var estimatedDriveHours: Double = 0
    var appointmentTime: Date = Date()
    var arrivalTime: Date = Date()
    var dockStartTime: Date = Date()
    var departureTime: Date = Date()
    var freeDetentionHours: Double = 2
    var proofReference: String = ""
    var claimStatusRaw: String = LoadClaimStatus.notStarted.rawValue
    var rateConfirmationOnFile: Bool = false
    var bolOnFile: Bool = false
    var podOnFile: Bool = false
    var lumperReceiptOnFile: Bool = false
    var invoiceSent: Bool = false
    var invoiceSentDate: Date = Date()
    var paymentTermsDays: Int = 30
    var paymentReceived: Bool = false
    var paymentReceivedDate: Date = Date()
    var detentionHours: Double = 0
    var detentionRate: Double = 75
    var layoverAmount: Double = 0
    var lumperFee: Double = 0
    var extraStopCount: Int = 0
    var extraStopRate: Double = 75
    var driverAssistAmount: Double = 0
    var truckOrderedNotUsedAmount: Double = 0
    var washoutAmount: Double = 0
    var scaleTicketAmount: Double = 0

    init() {}

    var status: LoadOpportunityStatus {
        get { LoadOpportunityStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var claimStatus: LoadClaimStatus {
        get { LoadClaimStatus(rawValue: claimStatusRaw) ?? .notStarted }
        set { claimStatusRaw = newValue.rawValue }
    }

    var allMiles: Double {
        loadedMiles + deadheadMiles
    }

    var accessorialRevenue: Double {
        detentionRevenue
        + layoverAmount
        + lumperFee
        + extraStopRevenue
        + driverAssistAmount
        + truckOrderedNotUsedAmount
        + washoutAmount
        + scaleTicketAmount
    }

    var detentionRevenue: Double {
        detentionHours * detentionRate
    }

    var timedDetentionHours: Double {
        let heldHours = max(departureTime.timeIntervalSince(arrivalTime) / 3600, 0)
        return max(heldHours - freeDetentionHours, 0)
    }

    var settlementReady: Bool {
        rateConfirmationOnFile
        && bolOnFile
        && podOnFile
        && (lumperFee <= 0 || lumperReceiptOnFile)
        && claimStatus != .disputed
    }

    var missingSettlementItems: [String] {
        var items: [String] = []
        if !rateConfirmationOnFile { items.append("rate confirmation") }
        if !bolOnFile { items.append("BOL") }
        if !podOnFile { items.append("POD") }
        if lumperFee > 0 && !lumperReceiptOnFile { items.append("lumper receipt") }
        if claimStatus == .disputed { items.append("claim dispute") }
        return items
    }

    var paymentDueDate: Date {
        Calendar.current.date(byAdding: .day, value: paymentTermsDays, to: invoiceSentDate) ?? invoiceSentDate
    }

    var paymentIsOverdue: Bool {
        invoiceSent && !paymentReceived && paymentDueDate < Date()
    }

    var outstandingReceivable: Double {
        invoiceSent && !paymentReceived ? projectedRevenue : 0
    }

    var settlementStatusText: String {
        if paymentReceived { return "Paid" }
        if paymentIsOverdue { return "Overdue" }
        if invoiceSent { return "Invoice Sent" }
        if settlementReady { return "Ready to Invoice" }
        return "Missing Paperwork"
    }

    var extraStopRevenue: Double {
        Double(extraStopCount) * extraStopRate
    }

    var projectedRevenue: Double {
        linehaulRate + accessorialRevenue
    }

    var gallonsNeeded: Double {
        guard mpg > 0 else { return 0 }
        return allMiles / mpg
    }

    var fuelCost: Double {
        gallonsNeeded * fuelPricePerGallon
    }

    var maintenanceReserve: Double {
        allMiles * maintenanceReservePerMile
    }

    var fixedCost: Double {
        allMiles * fixedCostPerMile
    }

    var totalOperatingCost: Double {
        fuelCost + maintenanceReserve + fixedCost + tolls + permits + brokerFee
    }

    var taxReserve: Double {
        max(projectedRevenue - totalOperatingCost, 0) * taxReserveRate
    }

    var projectedProfit: Double {
        projectedRevenue - totalOperatingCost - taxReserve
    }

    var revenuePerMile: Double {
        guard allMiles > 0 else { return 0 }
        return projectedRevenue / allMiles
    }

    var profitPerMile: Double {
        guard allMiles > 0 else { return 0 }
        return projectedProfit / allMiles
    }

    var minimumLinehaulRate: Double {
        max(totalOperatingCost + (targetProfitPerMile * allMiles) - accessorialRevenue, 0)
    }

    var needsBetterRate: Bool {
        linehaulRate > 0 && linehaulRate < minimumLinehaulRate
    }

    var isHOSFeasible: Bool {
        estimatedDriveHours <= 0 || driveHoursAvailable <= 0 || estimatedDriveHours <= driveHoursAvailable
    }
}

enum LoadOpportunityStatus: String, CaseIterable, Identifiable {
    case draft = "Draft"
    case negotiating = "Negotiating"
    case accepted = "Accepted"
    case rejected = "Rejected"
    case completed = "Completed"

    var id: String { rawValue }
}

enum LoadClaimStatus: String, CaseIterable, Identifiable {
    case notStarted = "Not Started"
    case ready = "Ready"
    case submitted = "Submitted"
    case paid = "Paid"
    case disputed = "Disputed"

    var id: String { rawValue }
}
