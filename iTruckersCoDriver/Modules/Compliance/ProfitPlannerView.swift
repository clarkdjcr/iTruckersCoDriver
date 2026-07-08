//
//  ProfitPlannerView.swift
//  iTruckersCoDriver
//
//  Created by Codex on 6/26/26.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

#if os(iOS)
private struct ActiveImport: Identifiable {
    let pending: PendingLoadImport
    let data: RateConfirmationData
    var id: UUID { pending.id }
}
#endif

struct ProfitPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LoadOpportunity.updatedAt, order: .reverse) private var opportunities: [LoadOpportunity]
    @State private var selectedOpportunity: LoadOpportunity?
    #if os(iOS)
    @State private var showRateConScanner = false
    @State private var pendingImports: [PendingLoadImport] = []
    @State private var activeImport: ActiveImport?
    #endif

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedOpportunity) {
                if !brokerScorecards.isEmpty {
                    Section("Broker Scorecards") {
                        ForEach(brokerScorecards.prefix(5)) { scorecard in
                            BrokerScorecardRow(scorecard: scorecard)
                        }
                    }
                }

                ForEach(opportunities) { opportunity in
                    LoadOpportunityRow(opportunity: opportunity)
                        .tag(opportunity as LoadOpportunity?)
                }
                .onDelete(perform: deleteOpportunities)
            }
            .navigationTitle("Profit")
            .toolbar {
                #if os(iOS)
                ToolbarItem {
                    Button {
                        showRateConScanner = true
                    } label: {
                        Label("Scan Rate Con", systemImage: "doc.viewfinder.fill")
                    }
                }
                #endif
                ToolbarItem {
                    Button(action: addOpportunity) {
                        Label("New Load", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if opportunities.isEmpty {
                    ContentUnavailableView(
                        "No Load Plans",
                        systemImage: "dollarsign.arrow.circlepath",
                        description: Text("Create a load plan to check net profit, accessorials, and negotiation targets before accepting freight.")
                    )
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showRateConScanner) {
                RateConfirmationScannerSheet { opportunity in
                    selectedOpportunity = opportunity
                }
            }
            .sheet(item: $activeImport, onDismiss: refreshPendingImports) { item in
                RateConfirmationScannerSheet(prefilled: item.data, importID: item.pending.id) { opportunity in
                    selectedOpportunity = opportunity
                }
            }
            .onAppear(perform: refreshPendingImports)
            .onChange(of: scenePhase) {
                if scenePhase == .active { refreshPendingImports() }
            }
            #endif
        } detail: {
            if let selectedOpportunity {
                LoadOpportunityEditor(opportunity: selectedOpportunity)
            } else {
                ContentUnavailableView(
                    "Select a Load",
                    systemImage: "shippingbox.and.arrow.backward",
                    description: Text("Pick a load plan or create a new one.")
                )
            }
        }
    }

    private var brokerScorecards: [BrokerScorecard] {
        let grouped = Dictionary(grouping: opportunities.filter { !$0.brokerName.isEmpty }) { $0.brokerName }
        return grouped.map { broker, loads in
            BrokerScorecard(
                brokerName: broker,
                loadCount: loads.count,
                totalRevenue: loads.reduce(0) { $0 + $1.projectedRevenue },
                totalProfit: loads.reduce(0) { $0 + $1.projectedProfit },
                outstandingReceivable: loads.reduce(0) { $0 + $1.outstandingReceivable },
                underpricedCount: loads.filter(\.needsBetterRate).count,
                overdueCount: loads.filter(\.paymentIsOverdue).count,
                disputedCount: loads.filter { $0.claimStatus == .disputed }.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.averageProfit == rhs.averageProfit {
                return lhs.brokerName < rhs.brokerName
            }
            return lhs.averageProfit > rhs.averageProfit
        }
    }

    private func addOpportunity() {
        let opportunity = LoadOpportunity()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        opportunity.deliveryDate = tomorrow
        opportunity.appointmentTime = opportunity.pickupDate
        opportunity.arrivalTime = opportunity.pickupDate
        opportunity.dockStartTime = opportunity.pickupDate
        opportunity.departureTime = opportunity.pickupDate
        modelContext.insert(opportunity)
        selectedOpportunity = opportunity
        try? modelContext.save()
    }

    private func deleteOpportunities(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(opportunities[index])
        }
        selectedOpportunity = nil
        try? modelContext.save()
    }

    #if os(iOS)
    private func refreshPendingImports() {
        pendingImports = PendingLoadImportStore.pending()
        presentNextImportIfNeeded()
    }

    private func presentNextImportIfNeeded() {
        guard activeImport == nil, let next = pendingImports.first else { return }
        Task {
            let data: RateConfirmationData
            if let text = next.text, !text.isEmpty {
                data = DocumentProcessor.shared.parseRateConfirmation(fromText: text)
            } else if let imageData = PendingLoadImportStore.imageData(for: next),
                      let image = UIImage(data: imageData),
                      let cgImage = image.cgImage,
                      let ocr = try? await DocumentProcessor.shared.extractText(from: cgImage) {
                data = DocumentProcessor.shared.parseRateConfirmation(from: ocr)
            } else {
                data = RateConfirmationData()
            }
            await MainActor.run {
                activeImport = ActiveImport(pending: next, data: data)
            }
        }
    }
    #endif
}

private struct BrokerScorecard: Identifiable {
    let brokerName: String
    let loadCount: Int
    let totalRevenue: Double
    let totalProfit: Double
    let outstandingReceivable: Double
    let underpricedCount: Int
    let overdueCount: Int
    let disputedCount: Int

    var id: String { brokerName }
    var averageProfit: Double {
        guard loadCount > 0 else { return 0 }
        return totalProfit / Double(loadCount)
    }
}

private struct BrokerScorecardRow: View {
    let scorecard: BrokerScorecard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(scorecard.brokerName)
                    .font(.headline)
                Spacer()
                Text(currency(scorecard.averageProfit))
                    .font(.caption)
                    .foregroundStyle(scorecard.averageProfit >= 0 ? .green : .red)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Label("\(scorecard.loadCount) loads", systemImage: "shippingbox")
                    Label(currency(scorecard.totalRevenue), systemImage: "dollarsign.circle")
                    if scorecard.underpricedCount > 0 {
                        Label("\(scorecard.underpricedCount) rate alerts", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    if scorecard.outstandingReceivable > 0 {
                        Label(currency(scorecard.outstandingReceivable), systemImage: "clock.badge.dollar")
                            .foregroundStyle(.blue)
                    }
                    if scorecard.overdueCount > 0 {
                        Label("\(scorecard.overdueCount) overdue", systemImage: "calendar.badge.exclamationmark")
                            .foregroundStyle(.red)
                    }
                    if scorecard.disputedCount > 0 {
                        Label("\(scorecard.disputedCount) disputed", systemImage: "exclamationmark.bubble")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatusChip: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct LoadOpportunityRow: View {
    let opportunity: LoadOpportunity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(routeTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                StatusChip(title: opportunity.settlementStatusText, tint: settlementTint)
            }

            HStack(spacing: 12) {
                Label(currency(opportunity.projectedProfit), systemImage: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(opportunity.projectedProfit >= 0 ? .green : .red)
                Label(String(format: "$%.2f/mi", opportunity.profitPerMile), systemImage: "road.lanes")
            }
            .font(.caption)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    StatusChip(title: opportunity.status.rawValue, tint: .secondary)
                    if opportunity.needsBetterRate {
                        StatusChip(title: "Ask \(currency(opportunity.minimumLinehaulRate))", tint: .orange)
                    }
                    if !opportunity.isHOSFeasible {
                        StatusChip(title: "HOS Risk", tint: .orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var settlementTint: Color {
        if opportunity.paymentReceived { return .green }
        if opportunity.paymentIsOverdue { return .red }
        if opportunity.invoiceSent { return .blue }
        if opportunity.settlementReady { return .green }
        return .orange
    }

    private var routeTitle: String {
        if opportunity.origin.isEmpty && opportunity.destination.isEmpty {
            return opportunity.loadNumber.isEmpty ? "New load plan" : opportunity.loadNumber
        }
        return "\(opportunity.origin.isEmpty ? "Origin TBD" : opportunity.origin) -> \(opportunity.destination.isEmpty ? "Destination TBD" : opportunity.destination)"
    }
}

private struct LoadOpportunityEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var opportunity: LoadOpportunity

    var body: some View {
        Form {
            Group {
                EditorStatusSection(opportunity: opportunity)
                Section {
                    KPIGrid(opportunity: opportunity)
                }
                LoadDetailsSection(opportunity: opportunity, save: save)
                RevenueSection(opportunity: opportunity)
                DetentionEvidenceSection(opportunity: opportunity, save: save)
                SettlementSection(opportunity: opportunity, save: save)
            }

            Group {
                CostSection(opportunity: opportunity)
                HOSCheckSection(opportunity: opportunity)
                NegotiationSection(
                    opportunity: opportunity,
                    negotiationText: negotiationText,
                    save: save,
                    acceptAndStartTrip: acceptAndStartTrip
                )
                InvoicePacketSection(invoicePacketText: invoicePacketText)
                NotesSection(opportunity: opportunity)
            }
        }
        .navigationTitle(opportunity.loadNumber.isEmpty ? "Load Profit" : opportunity.loadNumber)
        .onDisappear { save() }
    }

    private var settlementTint: Color {
        if opportunity.paymentReceived { return .green }
        if opportunity.paymentIsOverdue { return .red }
        if opportunity.invoiceSent { return .blue }
        if opportunity.settlementReady { return .green }
        return .orange
    }

    private var negotiationText: String {
        let route = "\(opportunity.origin.isEmpty ? "the pickup" : opportunity.origin) to \(opportunity.destination.isEmpty ? "delivery" : opportunity.destination)"
        let minimum = currency(opportunity.minimumLinehaulRate)
        let profit = currency(opportunity.projectedProfit)
        let rpm = String(format: "$%.2f", opportunity.revenuePerMile)
        let accessorials = opportunity.accessorialRevenue > 0 ? " Accessorials currently add \(currency(opportunity.accessorialRevenue))." : ""
        let hos = opportunity.isHOSFeasible ? "" : " Current HOS estimate is tight, so timing needs to be protected."
        return "I can cover \(route), but the linehaul needs to be at least \(minimum) based on all miles, operating cost, and target margin. At the current offer, projected profit is \(profit) and revenue is \(rpm)/mi.\(accessorials)\(hos)"
    }

    private var invoicePacketText: String {
        var lines: [String] = []
        lines.append("LOAD INVOICE SUMMARY")
        lines.append("Generated: \(Date().formatted(date: .abbreviated, time: .shortened))")
        lines.append("")
        lines.append("Load: \(opportunity.loadNumber.isEmpty ? "TBD" : opportunity.loadNumber)")
        lines.append("Broker / Customer: \(opportunity.brokerName.isEmpty ? "TBD" : opportunity.brokerName)")
        lines.append("Route: \(opportunity.origin.isEmpty ? "Origin TBD" : opportunity.origin) -> \(opportunity.destination.isEmpty ? "Destination TBD" : opportunity.destination)")
        lines.append("Pickup: \(opportunity.pickupDate.formatted(date: .abbreviated, time: .shortened))")
        lines.append("Delivery: \(opportunity.deliveryDate.formatted(date: .abbreviated, time: .shortened))")
        lines.append("Claim status: \(opportunity.claimStatus.rawValue)")
        lines.append("")
        lines.append("Revenue")
        lines.append("- Linehaul: \(currency(opportunity.linehaulRate))")
        if opportunity.detentionRevenue > 0 { lines.append("- Detention: \(currency(opportunity.detentionRevenue)) (\(formattedNumber(opportunity.detentionHours)) hr @ \(currency(opportunity.detentionRate))/hr)") }
        if opportunity.layoverAmount > 0 { lines.append("- Layover: \(currency(opportunity.layoverAmount))") }
        if opportunity.lumperFee > 0 { lines.append("- Lumper: \(currency(opportunity.lumperFee))") }
        if opportunity.extraStopRevenue > 0 { lines.append("- Extra stops: \(currency(opportunity.extraStopRevenue)) (\(opportunity.extraStopCount) @ \(currency(opportunity.extraStopRate)))") }
        if opportunity.driverAssistAmount > 0 { lines.append("- Driver assist: \(currency(opportunity.driverAssistAmount))") }
        if opportunity.truckOrderedNotUsedAmount > 0 { lines.append("- TONU: \(currency(opportunity.truckOrderedNotUsedAmount))") }
        if opportunity.washoutAmount > 0 { lines.append("- Washout: \(currency(opportunity.washoutAmount))") }
        if opportunity.scaleTicketAmount > 0 { lines.append("- Scale tickets: \(currency(opportunity.scaleTicketAmount))") }
        lines.append("- Total revenue: \(currency(opportunity.projectedRevenue))")
        lines.append("")
        lines.append("Operating Snapshot")
        lines.append("- Loaded miles: \(formattedNumber(opportunity.loadedMiles))")
        lines.append("- Deadhead miles: \(formattedNumber(opportunity.deadheadMiles))")
        lines.append("- All miles: \(formattedNumber(opportunity.allMiles))")
        lines.append("- Revenue per mile: \(String(format: "$%.2f", opportunity.revenuePerMile))")
        lines.append("- Projected profit: \(currency(opportunity.projectedProfit))")
        lines.append("- Projected profit per mile: \(String(format: "$%.2f", opportunity.profitPerMile))")
        if opportunity.needsBetterRate {
            lines.append("- Rate alert: Ask at least \(currency(opportunity.minimumLinehaulRate)) linehaul.")
        }
        if !opportunity.isHOSFeasible {
            lines.append("- HOS alert: Estimated drive hours exceed current available drive hours.")
        }
        lines.append("")
        lines.append("Detention Evidence")
        lines.append("- Appointment: \(opportunity.appointmentTime.formatted(date: .abbreviated, time: .shortened))")
        lines.append("- Arrival: \(opportunity.arrivalTime.formatted(date: .abbreviated, time: .shortened))")
        lines.append("- Dock start: \(opportunity.dockStartTime.formatted(date: .abbreviated, time: .shortened))")
        lines.append("- Departure: \(opportunity.departureTime.formatted(date: .abbreviated, time: .shortened))")
        lines.append("- Free time: \(formattedNumber(opportunity.freeDetentionHours)) hr")
        lines.append("- Timed detention: \(formattedNumber(opportunity.timedDetentionHours)) hr")
        if !opportunity.proofReference.isEmpty {
            lines.append("- Proof: \(opportunity.proofReference)")
        }
        lines.append("")
        lines.append("Settlement")
        lines.append("- Rate confirmation: \(opportunity.rateConfirmationOnFile ? "On file" : "Missing")")
        lines.append("- BOL: \(opportunity.bolOnFile ? "On file" : "Missing")")
        lines.append("- POD: \(opportunity.podOnFile ? "On file" : "Missing")")
        if opportunity.lumperFee > 0 {
            lines.append("- Lumper receipt: \(opportunity.lumperReceiptOnFile ? "On file" : "Missing")")
        }
        lines.append("- Ready to invoice: \(opportunity.settlementReady ? "Yes" : "No")")
        if !opportunity.missingSettlementItems.isEmpty {
            lines.append("- Missing: \(opportunity.missingSettlementItems.joined(separator: ", "))")
        }
        if opportunity.invoiceSent {
            lines.append("- Invoice sent: \(opportunity.invoiceSentDate.formatted(date: .abbreviated, time: .shortened))")
            lines.append("- Payment due: \(opportunity.paymentDueDate.formatted(date: .abbreviated, time: .omitted))")
            lines.append("- Payment received: \(opportunity.paymentReceived ? "Yes" : "No")")
            if opportunity.paymentReceived {
                lines.append("- Paid: \(opportunity.paymentReceivedDate.formatted(date: .abbreviated, time: .shortened))")
            } else {
                lines.append("- Open receivable: \(currency(opportunity.outstandingReceivable))")
            }
        }
        if !opportunity.notes.isEmpty {
            lines.append("")
            lines.append("Notes")
            lines.append(opportunity.notes)
        }
        return lines.joined(separator: "\n")
    }

    private func acceptAndStartTrip() {
        let trip = TripRecord(
            origin: opportunity.origin,
            destination: opportunity.destination,
            fixedCosts: opportunity.fixedCostPerMile
        )
        trip.miles = opportunity.allMiles
        trip.fuelGallons = opportunity.gallonsNeeded
        trip.grossRevenue = opportunity.projectedRevenue
        trip.currentAvgFuelPrice = opportunity.fuelPricePerGallon
        trip.notes = "Started from Profit Planner"
        if !opportunity.loadNumber.isEmpty {
            trip.notes += " load \(opportunity.loadNumber)."
        }
        modelContext.insert(trip)
        opportunity.tripRecordID = trip.id.uuidString
        opportunity.status = .accepted
        save()
    }

    private func save() {
        opportunity.updatedAt = Date()
        try? modelContext.save()
    }

}

private struct EditorStatusSection: View {
    let opportunity: LoadOpportunity

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    StatusChip(title: opportunity.status.rawValue, tint: .secondary)
                    StatusChip(title: opportunity.settlementStatusText, tint: settlementTint)
                    if opportunity.needsBetterRate {
                        StatusChip(title: "Rate Alert", tint: .orange)
                    }
                    if !opportunity.isHOSFeasible {
                        StatusChip(title: "HOS Risk", tint: .orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var settlementTint: Color {
        if opportunity.paymentReceived { return .green }
        if opportunity.paymentIsOverdue { return .red }
        if opportunity.invoiceSent { return .blue }
        if opportunity.settlementReady { return .green }
        return .orange
    }
}

private struct LoadDetailsSection: View {
    @Bindable var opportunity: LoadOpportunity
    let save: () -> Void

    var body: some View {
        Section("Load") {
            TextField("Load number", text: $opportunity.loadNumber)
            TextField("Broker / customer", text: $opportunity.brokerName)
            TextField("Origin", text: $opportunity.origin)
            TextField("Destination", text: $opportunity.destination)
            DatePicker("Pickup", selection: $opportunity.pickupDate)
            DatePicker("Delivery", selection: $opportunity.deliveryDate)
            Picker("Status", selection: statusBinding) {
                ForEach(LoadOpportunityStatus.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
        }
    }

    private var statusBinding: Binding<LoadOpportunityStatus> {
        Binding {
            opportunity.status
        } set: { newStatus in
            opportunity.status = newStatus
            save()
        }
    }
}

private struct RevenueSection: View {
    @Bindable var opportunity: LoadOpportunity

    var body: some View {
        Section("Revenue") {
            currencyField("Linehaul", value: $opportunity.linehaulRate)
            currencyField("Detention", value: $opportunity.detentionRate)
            decimalField("Detention hours", value: $opportunity.detentionHours)
            currencyField("Layover", value: $opportunity.layoverAmount)
            currencyField("Lumper", value: $opportunity.lumperFee)
            Stepper("Extra stops: \(opportunity.extraStopCount)", value: $opportunity.extraStopCount, in: 0...12)
            currencyField("Extra stop rate", value: $opportunity.extraStopRate)
            currencyField("Driver assist", value: $opportunity.driverAssistAmount)
            currencyField("TONU", value: $opportunity.truckOrderedNotUsedAmount)
            currencyField("Washout", value: $opportunity.washoutAmount)
            currencyField("Scale tickets", value: $opportunity.scaleTicketAmount)
        }
    }
}

private struct DetentionEvidenceSection: View {
    @Bindable var opportunity: LoadOpportunity
    let save: () -> Void

    var body: some View {
        Section("Detention Evidence") {
            DatePicker("Appointment", selection: $opportunity.appointmentTime)
            DatePicker("Arrived", selection: $opportunity.arrivalTime)
            DatePicker("Dock start", selection: $opportunity.dockStartTime)
            DatePicker("Departed", selection: $opportunity.departureTime)
            decimalField("Free hours", value: $opportunity.freeDetentionHours)
            LabeledContent("Timed detention") {
                Text("\(formattedNumber(opportunity.timedDetentionHours)) hr")
            }
            Button("Use Timed Detention") {
                opportunity.detentionHours = opportunity.timedDetentionHours
                save()
            }
            TextField("Proof notes / photo refs / BOL note", text: $opportunity.proofReference, axis: .vertical)
                .lineLimit(2...4)
            Picker("Claim status", selection: claimStatusBinding) {
                ForEach(LoadClaimStatus.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
        }
    }

    private var claimStatusBinding: Binding<LoadClaimStatus> {
        Binding {
            opportunity.claimStatus
        } set: { newStatus in
            opportunity.claimStatus = newStatus
            save()
        }
    }
}

private struct SettlementSection: View {
    @Bindable var opportunity: LoadOpportunity
    let save: () -> Void

    var body: some View {
        Section("Settlement") {
            Toggle("Rate confirmation on file", isOn: $opportunity.rateConfirmationOnFile)
            Toggle("BOL on file", isOn: $opportunity.bolOnFile)
            Toggle("POD on file", isOn: $opportunity.podOnFile)
            if opportunity.lumperFee > 0 {
                Toggle("Lumper receipt on file", isOn: $opportunity.lumperReceiptOnFile)
            }
            Stepper("Payment terms: \(opportunity.paymentTermsDays) days", value: $opportunity.paymentTermsDays, in: 0...90)
            Label(
                opportunity.settlementReady ? "Ready to invoice" : "Missing \(opportunity.missingSettlementItems.joined(separator: ", "))",
                systemImage: opportunity.settlementReady ? "checkmark.seal.fill" : "doc.badge.clock"
            )
            .foregroundStyle(opportunity.settlementReady ? .green : .orange)
            Button(opportunity.invoiceSent ? "Invoice Sent" : "Mark Invoice Sent") {
                opportunity.invoiceSent = true
                opportunity.invoiceSentDate = Date()
                save()
            }
            .disabled(!opportunity.settlementReady || opportunity.invoiceSent)
            if opportunity.invoiceSent {
                InvoiceStatusRows(opportunity: opportunity)
            }
        }
    }
}

private struct InvoiceStatusRows: View {
    @Bindable var opportunity: LoadOpportunity

    var body: some View {
        DatePicker("Invoice sent", selection: $opportunity.invoiceSentDate)
        LabeledContent("Payment due") {
            Text(opportunity.paymentDueDate.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(opportunity.paymentIsOverdue ? .red : .secondary)
        }
        if opportunity.paymentIsOverdue {
            Label("Payment is overdue", systemImage: "calendar.badge.exclamationmark")
                .foregroundStyle(.red)
        }
        Toggle("Payment received", isOn: $opportunity.paymentReceived)
        if opportunity.paymentReceived {
            DatePicker("Paid", selection: $opportunity.paymentReceivedDate)
        } else {
            LabeledContent("Open receivable") {
                Text(currency(opportunity.outstandingReceivable))
            }
        }
    }
}

private struct CostSection: View {
    @Bindable var opportunity: LoadOpportunity

    var body: some View {
        Section("Miles and Costs") {
            decimalField("Loaded miles", value: $opportunity.loadedMiles)
            decimalField("Deadhead miles", value: $opportunity.deadheadMiles)
            decimalField("MPG", value: $opportunity.mpg)
            currencyField("Fuel price / gallon", value: $opportunity.fuelPricePerGallon)
            currencyField("Maintenance reserve / mile", value: $opportunity.maintenanceReservePerMile)
            currencyField("Fixed cost / mile", value: $opportunity.fixedCostPerMile)
            percentField("Tax reserve", value: $opportunity.taxReserveRate)
            currencyField("Tolls", value: $opportunity.tolls)
            currencyField("Permits", value: $opportunity.permits)
            currencyField("Broker fee", value: $opportunity.brokerFee)
            currencyField("Target profit / mile", value: $opportunity.targetProfitPerMile)
        }
    }
}

private struct HOSCheckSection: View {
    @Bindable var opportunity: LoadOpportunity

    var body: some View {
        Section("HOS Check") {
            decimalField("Drive hours available", value: $opportunity.driveHoursAvailable)
            decimalField("Estimated drive hours", value: $opportunity.estimatedDriveHours)
            Label(
                opportunity.isHOSFeasible ? "Looks feasible" : "HOS risk",
                systemImage: opportunity.isHOSFeasible ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(opportunity.isHOSFeasible ? .green : .orange)
        }
    }
}

private struct NegotiationSection: View {
    @Bindable var opportunity: LoadOpportunity
    let negotiationText: String
    let save: () -> Void
    let acceptAndStartTrip: () -> Void

    var body: some View {
        Section("Negotiation") {
            Text(negotiationText)
                .textSelection(.enabled)
            Button("Mark Negotiating") {
                opportunity.status = .negotiating
                save()
            }
            Button("Mark Accepted") {
                opportunity.status = .accepted
                save()
            }
            Button(opportunity.tripRecordID.isEmpty ? "Accept & Start Trip" : "Trip Started") {
                acceptAndStartTrip()
            }
            .disabled(opportunity.tripRecordID.isEmpty == false)
        }
    }
}

private struct InvoicePacketSection: View {
    let invoicePacketText: String

    var body: some View {
        Section("Invoice Packet") {
            Text(invoicePacketText)
                .textSelection(.enabled)
            ShareLink(item: invoicePacketText) {
                Label("Share Invoice Packet", systemImage: "square.and.arrow.up")
            }
        }
    }
}

private struct NotesSection: View {
    @Bindable var opportunity: LoadOpportunity

    var body: some View {
        Section("Notes") {
            TextEditor(text: $opportunity.notes)
                .frame(minHeight: 90)
        }
    }
}

private struct KPIGrid: View {
    let opportunity: LoadOpportunity

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            KPICard(title: "Profit", value: currency(opportunity.projectedProfit), systemImage: "chart.line.uptrend.xyaxis", tint: opportunity.projectedProfit >= 0 ? .green : .red)
            KPICard(title: "Profit / mi", value: String(format: "$%.2f", opportunity.profitPerMile), systemImage: "road.lanes", tint: opportunity.profitPerMile >= opportunity.targetProfitPerMile ? .green : .orange)
            KPICard(title: "Revenue / mi", value: String(format: "$%.2f", opportunity.revenuePerMile), systemImage: "dollarsign.circle", tint: .blue)
            KPICard(title: "Min linehaul", value: currency(opportunity.minimumLinehaulRate), systemImage: "megaphone.fill", tint: opportunity.needsBetterRate ? .orange : .green)
        }
    }
}

private struct KPICard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(UIColor.secondarySystemBackground))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private func currency(_ value: Double) -> String {
    value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
}

private func formattedNumber(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
}

private func currencyField(_ title: String, value: Binding<Double>) -> some View {
    TextField(title, value: value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
}

private func decimalField(_ title: String, value: Binding<Double>) -> some View {
    TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
}

private func percentField(_ title: String, value: Binding<Double>) -> some View {
    TextField(title, value: value, format: .percent.precision(.fractionLength(0...1)))
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
}
