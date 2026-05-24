//
//  LogbookPDFRenderer.swift
//  Block-Time
//

import UIKit

struct LogbookPDFRenderer {

    /// Generates a PDF logbook from the given flights.
    /// - Parameters:
    ///   - flights: All flights, pre-sorted oldest-first. Positioning flights are filtered internally.
    ///   - pilotName: Displayed on the cover page.
    /// - Returns: PDF data ready to write to disk or share.
    /// resolvedDates: pre-computed effective date string per flight (local or UTC),
    /// resolved on the main actor before Task.detached. Same order as flights.
    static nonisolated func render(
        flights: [FlightSector],
        resolvedDates: [String],
        pilotName: String,
        arn: String = "",
        title: String = "PILOT LOGBOOK",
        dateFormat: String = "dd MMM yyyy",
        useHHMM: Bool = false,
        priorTotals: PageTotals = PageTotals()
    ) -> Data {
        let slots = LogbookPDFPaginator.buildSlots(from: flights)
        let pages = LogbookPDFPaginator.paginate(slots)
        let totals = LogbookPDFPaginator.computeTotals(pages: pages, seed: priorTotals)
        let totalPages = pages.count
        let dateRange = makeDateRange(resolvedDates: resolvedDates, dateFormat: dateFormat)

        let pageSize = CGSize(width: 842, height: 595)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            LogbookPDFCoverDrawer(
                context: ctx,
                title: title,
                pilotName: pilotName,
                arn: arn,
                dateRange: dateRange
            ).draw()

            // Build slot→resolvedDate mapping by matching against the sorted flights array
            var flightToDate: [String: String] = [:]
            for (i, flight) in flights.enumerated() {
                let key = "\(flight.date)|\(flight.outTime)|\(flight.fromAirport)|\(flight.toAirport)"
                if flightToDate[key] == nil, i < resolvedDates.count {
                    flightToDate[key] = resolvedDates[i]
                }
            }

            for (index, pageSlots) in pages.enumerated() {
                ctx.beginPage()
                LogbookPDFPageDrawer(
                    context: ctx,
                    slots: pageSlots,
                    pageTotals: totals[index].page,
                    broughtForward: totals[index].broughtForward,
                    pageNumber: index + 1,
                    totalPages: totalPages,
                    dateFormat: dateFormat,
                    useHHMM: useHHMM,
                    flightToDate: flightToDate
                ).draw()
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

    private static nonisolated func makeDateRange(resolvedDates: [String], dateFormat: String) -> String {
        guard !resolvedDates.isEmpty else { return "" }
        let dates = resolvedDates.compactMap { inputDF.date(from: $0) }
        guard let first = dates.min(), let last = dates.max() else { return "" }
        let f = DateFormatter()
        f.dateFormat = dateFormat
        f.locale = Locale(identifier: "en_AU")
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }
}
