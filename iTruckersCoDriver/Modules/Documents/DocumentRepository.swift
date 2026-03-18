//
//  DocumentRepository.swift
//  iTruckersCoDriver
//
//  Manages the driver's document library: IFTA forms, BOL templates,
//  paper log sheets, permits. Templates seeded at init; CloudKit
//  can add driver-specific documents from their cloud folder.
//

import Foundation
import Combine

struct DriverDocument: Identifiable {
    let id: UUID
    let name: String
    let category: DocumentCategory
    let fileName: String

    enum DocumentCategory: String, CaseIterable {
        case tax = "Tax"
        case compliance = "Compliance"
        case logs = "Logs"
        case permits = "Permits"
        case other = "Other"

        var icon: String {
            switch self {
            case .tax:        return "dollarsign.circle.fill"
            case .compliance: return "doc.badge.checkmark"
            case .logs:       return "list.clipboard.fill"
            case .permits:    return "checkmark.seal.fill"
            case .other:      return "doc.fill"
            }
        }
    }
}

@MainActor
class DocumentRepository: ObservableObject {
    @Published var documents: [DriverDocument] = []

    init() { loadTemplateLibrary() }

    func loadTemplateLibrary() {
        documents = [
            make("IFTA Q1 Form",               .tax,        "ifta_q1.pdf"),
            make("IFTA Q2 Form",               .tax,        "ifta_q2.pdf"),
            make("IFTA Q3 Form",               .tax,        "ifta_q3.pdf"),
            make("IFTA Q4 Form",               .tax,        "ifta_q4.pdf"),
            make("Fuel Tax Report",            .tax,        "fuel_tax.pdf"),
            make("Paper Log Sheet",            .logs,       "paper_log.pdf"),
            make("Trip Report",                .logs,       "trip_report.pdf"),
            make("Bill of Lading Template",    .compliance, "bol_template.pdf"),
            make("Pre-Trip Inspection",        .compliance, "pre_trip.pdf"),
            make("Post-Trip Inspection",       .compliance, "post_trip.pdf"),
            make("Hazmat Manifest",            .compliance, "hazmat_manifest.pdf"),
            make("Oversize Permit Application",.permits,    "oversize_permit.pdf"),
        ]
    }

    func documents(for category: DriverDocument.DocumentCategory) -> [DriverDocument] {
        documents.filter { $0.category == category }
    }

    func document(named name: String) -> DriverDocument? {
        documents.first { $0.name.localizedCaseInsensitiveContains(name) }
    }

    // MARK: - Private

    private func make(_ name: String, _ category: DriverDocument.DocumentCategory, _ fileName: String) -> DriverDocument {
        DriverDocument(id: UUID(), name: name, category: category, fileName: fileName)
    }
}
