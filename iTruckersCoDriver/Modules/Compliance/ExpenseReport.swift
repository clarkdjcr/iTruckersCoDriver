//
//  ExpenseReport.swift
//  iTruckersCoDriver
//
//  Quarterly tax report generation for a 1099 driver — CSV and PDF written to
//  temporary files so they can be handed off via the native share sheet
//  (email, Dropbox, Google Drive, Files, AirDrop, print — provider-neutral).
//

import Foundation

#if os(iOS)
import UIKit

// MARK: - Quarter

/// A calendar quarter (Q1–Q4 of a given year) with a half-open date range.
struct Quarter: Identifiable, Hashable {
    let year: Int
    let quarter: Int   // 1...4

    var id: String { "Q\(quarter)-\(year)" }
    var label: String { "Q\(quarter) \(year)" }

    /// Half-open range [start, end) covering the quarter.
    var dateRange: (start: Date, end: Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let startMonth = (quarter - 1) * 3 + 1
        let start = cal.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? Date()
        let end = cal.date(byAdding: .month, value: 3, to: start) ?? start
        return (start, end)
    }

    func contains(_ date: Date) -> Bool {
        let range = dateRange
        return date >= range.start && date < range.end
    }

    /// The quarter containing `date`.
    static func current(for date: Date = Date()) -> Quarter {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month], from: date)
        let month = comps.month ?? 1
        return Quarter(year: comps.year ?? 2026, quarter: (month - 1) / 3 + 1)
    }

    /// The most recent `count` quarters, newest first, ending with the current one.
    static func recent(count: Int, from date: Date = Date()) -> [Quarter] {
        var result: [Quarter] = []
        var q = current(for: date)
        for _ in 0..<count {
            result.append(q)
            q = q.previous
        }
        return result
    }

    var previous: Quarter {
        quarter == 1 ? Quarter(year: year - 1, quarter: 4)
                     : Quarter(year: year, quarter: quarter - 1)
    }
}

// MARK: - Report generation

enum ExpenseReport {

    /// Expenses falling within the quarter, oldest first.
    static func expenses(_ all: [ExpenseEntry], in quarter: Quarter) -> [ExpenseEntry] {
        all.filter { quarter.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    // MARK: CSV

    /// Writes a per-line expense CSV for the quarter to a temp file, returns its URL.
    static func csvFile(_ all: [ExpenseEntry], quarter: Quarter, driverName: String) throws -> URL {
        let rows = expenses(all, in: quarter)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        var csv = "Date,Bucket,Description,Amount,Business %,Deductible\n"
        for e in rows {
            let note = e.note.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(df.string(from: e.date)),"
            csv += "\(e.bucket.displayName),"
            csv += "\"\(note)\","
            csv += String(format: "%.2f,", e.amount)
            csv += String(format: "%.0f,", e.businessUsePercent)
            csv += String(format: "%.2f\n", e.deductibleAmount)
        }

        // Totals by bucket
        csv += "\n,,,,,\n"
        csv += "Bucket Totals (Deductible),,,,,\n"
        let byBucket = ExpenseEntry.deductibleByBucket(rows)
        for bucket in TaxBucket.allCases where (byBucket[bucket] ?? 0) > 0 {
            csv += "\(bucket.displayName),,,,,\(String(format: "%.2f", byBucket[bucket] ?? 0))\n"
        }
        let grand = rows.reduce(0) { $0 + $1.deductibleAmount }
        csv += "Total Deductible,,,,,\(String(format: "%.2f", grand))\n"

        return try write(csv, filename: "iTrucker-Expenses-\(quarter.id).csv")
    }

    // MARK: PDF

    /// Renders a formatted quarterly tax report PDF, returns its temp-file URL.
    static func pdfFile(_ all: [ExpenseEntry], quarter: Quarter, driverName: String) throws -> URL {
        let rows = expenses(all, in: quarter)
        let pageWidth: CGFloat = 612   // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { ctx in
            var y: CGFloat = margin
            ctx.beginPage()

            func newPageIfNeeded(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    ctx.beginPage()
                    y = margin
                }
            }

            func draw(_ text: String, font: UIFont, color: UIColor = .black, x: CGFloat = margin) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                text.draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
            }

            // Header
            draw("Quarterly Tax Report", font: .boldSystemFont(ofSize: 22))
            y += 30
            draw(driverName.isEmpty ? "Owner-Operator" : driverName, font: .systemFont(ofSize: 13), color: .darkGray)
            y += 18
            let gen = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
            draw("\(quarter.label)   ·   Generated \(gen)", font: .systemFont(ofSize: 11), color: .gray)
            y += 28

            if rows.isEmpty {
                draw("No expenses recorded for \(quarter.label).", font: .systemFont(ofSize: 13), color: .darkGray)
                return
            }

            let byBucket = Dictionary(grouping: rows, by: \.bucket)
            let df = DateFormatter(); df.dateFormat = "MMM d"

            for bucket in TaxBucket.allCases {
                guard let items = byBucket[bucket], !items.isEmpty else { continue }
                newPageIfNeeded(40)

                // Bucket header
                draw(bucket.displayName, font: .boldSystemFont(ofSize: 15), color: .black)
                y += 22

                // Column headers
                draw("Date", font: .systemFont(ofSize: 10), color: .gray, x: margin)
                draw("Description", font: .systemFont(ofSize: 10), color: .gray, x: margin + 70)
                draw("Amount", font: .systemFont(ofSize: 10), color: .gray, x: margin + 330)
                draw("Biz %", font: .systemFont(ofSize: 10), color: .gray, x: margin + 400)
                draw("Deductible", font: .systemFont(ofSize: 10), color: .gray, x: margin + 450)
                y += 16

                var subtotal: Double = 0
                for e in items.sorted(by: { $0.date < $1.date }) {
                    newPageIfNeeded(18)
                    subtotal += e.deductibleAmount
                    let desc = e.note.isEmpty ? bucket.displayName : e.note
                    draw(df.string(from: e.date), font: .systemFont(ofSize: 11), x: margin)
                    draw(String(desc.prefix(38)), font: .systemFont(ofSize: 11), x: margin + 70)
                    draw(currency(e.amount), font: .systemFont(ofSize: 11), x: margin + 330)
                    draw(String(format: "%.0f%%", e.businessUsePercent), font: .systemFont(ofSize: 11), x: margin + 400)
                    draw(currency(e.deductibleAmount), font: .systemFont(ofSize: 11), x: margin + 450)
                    y += 16
                }

                // Subtotal rule
                newPageIfNeeded(24)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin + 330, y: y + 2))
                path.addLine(to: CGPoint(x: margin + contentWidth, y: y + 2))
                UIColor.lightGray.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                y += 6
                draw("Subtotal", font: .boldSystemFont(ofSize: 11), x: margin + 330)
                draw(currency(subtotal), font: .boldSystemFont(ofSize: 11), x: margin + 450)
                y += 28
            }

            // Grand total
            newPageIfNeeded(40)
            let grand = rows.reduce(0) { $0 + $1.deductibleAmount }
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: margin + contentWidth, y: y))
            UIColor.darkGray.setStroke()
            path.lineWidth = 1
            path.stroke()
            y += 10
            draw("Total Deductible", font: .boldSystemFont(ofSize: 15), x: margin)
            draw(currency(grand), font: .boldSystemFont(ofSize: 15), x: margin + 450)

            // Receipt images — one per page, as an audit appendix.
            let df2 = DateFormatter(); df2.dateFormat = "MMM d, yyyy"
            for e in rows where e.receiptImageData != nil {
                guard let data = e.receiptImageData, let image = UIImage(data: data) else { continue }
                ctx.beginPage()
                y = margin
                let caption = "\(e.bucket.displayName) · \(df2.string(from: e.date)) · \(currency(e.amount))"
                draw(caption, font: .boldSystemFont(ofSize: 12))
                if !e.note.isEmpty { y += 18; draw(e.note, font: .systemFont(ofSize: 11), color: .darkGray) }
                y += 24

                // Fit the image within the remaining content area, preserving aspect.
                let maxW = contentWidth
                let maxH = pageHeight - margin - y
                let scale = min(maxW / image.size.width, maxH / image.size.height, 1)
                let drawW = image.size.width * scale
                let drawH = image.size.height * scale
                image.draw(in: CGRect(x: margin, y: y, width: drawW, height: drawH))
            }
        }

        return try write(data, filename: "iTrucker-TaxReport-\(quarter.id).pdf")
    }

    // MARK: - Helpers

    private static func currency(_ value: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        return f.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    /// Writes arbitrary text (e.g. an IFTA/HOS CSV) to a temp file for sharing.
    static func textFile(_ text: String, filename: String) throws -> URL {
        try write(text, filename: filename)
    }

    private static func write(_ text: String, filename: String) throws -> URL {
        try write(Data(text.utf8), filename: filename)
    }

    private static func write(_ data: Data, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}
#endif
