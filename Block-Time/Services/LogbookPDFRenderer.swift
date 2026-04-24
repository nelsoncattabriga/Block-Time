//
//  LogbookPDFRenderer.swift
//  Block-Time
//

import UIKit

struct LogbookPDFRenderer {

    /// Generates a PDF logbook from the given flights.
    /// - Parameters:
    ///   - flights: All flights, pre-sorted oldest-first. Positioning flights are filtered internally.
    ///   - pilotName: Displayed in the page header.
    /// - Returns: PDF data ready to write to disk or share.
    static nonisolated func render(flights: [FlightSector], pilotName: String) -> Data {
        let slots = LogbookPDFPaginator.buildSlots(from: flights)
        let pages = LogbookPDFPaginator.paginate(slots)
        let totals = LogbookPDFPaginator.computeTotals(pages: pages)
        let totalPages = pages.count
        let dateRange = makeDateRange(flights: flights)

        // Page size defined locally to avoid referencing @MainActor layout properties
        let pageSize = CGSize(width: 842, height: 595)
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: format
        )

        let data = renderer.pdfData { ctx in
            for (index, pageSlots) in pages.enumerated() {
                ctx.beginPage()
                let drawer = LogbookPDFPageDrawer(
                    context: ctx,
                    slots: pageSlots,
                    pageTotals: totals[index].page,
                    broughtForward: totals[index].broughtForward,
                    pageNumber: index + 1,
                    totalPages: totalPages,
                    pilotName: pilotName,
                    dateRange: dateRange
                )
                drawer.draw()
            }
        }

        return data
    }

    // MARK: - Date range label

    private static nonisolated let inputDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    private static nonisolated let outputDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    private static nonisolated func makeDateRange(flights: [FlightSector]) -> String {
        guard !flights.isEmpty else { return "" }
        let dates = flights.compactMap { inputDF.date(from: $0.date) }
        guard let first = dates.min(), let last = dates.max() else { return "" }
        return "\(outputDF.string(from: first)) – \(outputDF.string(from: last))"
    }
}
