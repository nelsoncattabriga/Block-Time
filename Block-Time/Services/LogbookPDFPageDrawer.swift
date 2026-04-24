//
//  LogbookPDFPageDrawer.swift
//  Block-Time
//

import UIKit

struct LogbookPDFPageDrawer {

    let context: UIGraphicsPDFRendererContext
    let slots: [RowSlot]
    let pageTotals: PageTotals
    let broughtForward: PageTotals
    let pageNumber: Int
    let totalPages: Int
    let pilotName: String
    let dateRange: String   // e.g. "01 Jan 2025 – 20 Apr 2026"

    private let L = LogbookPDFLayout.self

    func draw() {
        let ctx = context.cgContext

        drawPageBackground(ctx)
        drawPageHeader(ctx)
        drawColumnHeaders(ctx)
        drawRows(ctx)
        drawFooter(ctx)
        drawGridLines(ctx)
    }

    // MARK: - Page Background

    private func drawPageBackground(_ ctx: CGContext) {
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: L.pageSize))
    }

    // MARK: - Page Header

    private func drawPageHeader(_ ctx: CGContext) {
        let fullWidth = L.pageSize.width

        // Top navy strip
        ctx.setFillColor(L.headerNavy.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: fullWidth, height: L.pageHeaderHeight))

        // Sub-header steel strip
        ctx.setFillColor(L.subHeaderSteel.cgColor)
        ctx.fill(CGRect(x: 0, y: L.pageHeaderHeight, width: fullWidth, height: L.subHeaderHeight))

        // Gold accent rule between strips
        ctx.setStrokeColor(L.accentGold.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 0, y: L.pageHeaderHeight))
        ctx.addLine(to: CGPoint(x: fullWidth, y: L.pageHeaderHeight))
        ctx.strokePath()

        // ✈ + "BLOCK-TIME" wordmark
        let planeAndTitle = "✈  BLOCK-TIME"
        drawText(planeAndTitle,
                 in: CGRect(x: L.marginH, y: 6, width: 200, height: 18),
                 font: L.fontPageTitle,
                 color: L.headerText,
                 alignment: .left)

        // Centre divider label
        drawText("PILOT LOGBOOK",
                 in: CGRect(x: 0, y: 6, width: fullWidth, height: 18),
                 font: L.fontPageTitle,
                 color: L.headerText,
                 alignment: .center)

        // Pilot name (gold) — right-aligned, leaving room for page number
        drawText(pilotName,
                 in: CGRect(x: fullWidth - 280, y: 7, width: 180, height: 14),
                 font: L.fontPageSub,
                 color: L.accentGold,
                 alignment: .right)

        // Page number — far right
        drawText("Page \(pageNumber) of \(totalPages)",
                 in: CGRect(x: fullWidth - 90, y: 7, width: 74, height: 14),
                 font: L.fontPageNum,
                 color: L.headerText,
                 alignment: .right)

        // Date range in sub-header strip
        drawText(dateRange,
                 in: CGRect(x: L.marginH, y: L.pageHeaderHeight + 1, width: fullWidth - L.marginH * 2, height: 9),
                 font: L.fontPageNum,
                 color: L.headerText,
                 alignment: .center)
    }

    // MARK: - Column Headers (Group row + Leaf row)

    private func drawColumnHeaders(_ ctx: CGContext) {
        let groupTop = L.groupHeaderTop
        let leafTop = L.leafHeaderTop

        // Group header backgrounds
        for group in L.groupOrder {
            let geo = L.groupGeometry(for: group)
            ctx.setFillColor(L.headerNavy.cgColor)
            ctx.fill(CGRect(x: geo.x, y: groupTop, width: geo.width, height: L.groupHeaderHeight))

            let label = L.groupTitles[group] ?? ""
            drawText(label,
                     in: CGRect(x: geo.x + 2, y: groupTop + 1, width: geo.width - 4, height: L.groupHeaderHeight - 2),
                     font: L.fontGroupHeader,
                     color: L.headerText,
                     alignment: .center)
        }

        // Leaf header backgrounds + labels
        for col in L.columns {
            guard let x = L.columnOffsets[col.id] else { continue }
            ctx.setFillColor(L.subHeaderSteel.cgColor)
            ctx.fill(CGRect(x: x, y: leafTop, width: col.width, height: L.leafHeaderHeight))

            drawText(col.title,
                     in: CGRect(x: x + 1, y: leafTop + 1, width: col.width - 2, height: L.leafHeaderHeight - 2),
                     font: L.fontLeafHeader,
                     color: L.headerText,
                     alignment: .center)
        }

        // Gold rule under leaf headers
        ctx.setStrokeColor(L.accentGold.cgColor)
        ctx.setLineWidth(1.0)
        ctx.move(to: CGPoint(x: L.marginH, y: L.dataTop))
        ctx.addLine(to: CGPoint(x: L.pageSize.width - L.marginH, y: L.dataTop))
        ctx.strokePath()
    }

    // MARK: - Data Rows

    private func drawRows(_ ctx: CGContext) {
        var rowIndex = 0  // visual slot index (0-based), used for alternating shading

        for slot in slots {
            let y = L.dataTop + CGFloat(rowIndex) * L.dataRowHeight
            let rowRect = CGRect(x: L.marginH, y: y, width: L.contentWidth, height: L.dataRowHeight)

            switch slot {
            case .monthBand(let label):
                drawMonthBand(ctx, label: label, y: y)

            case .flight(let flight):
                drawFlightRow(ctx, flight: flight, y: y, rowIndex: rowIndex, rowRect: rowRect)
            }

            rowIndex += 1
        }
    }

    private func drawMonthBand(_ ctx: CGContext, label: String, y: CGFloat) {
        let rect = CGRect(x: L.marginH, y: y, width: L.contentWidth, height: L.monthBandHeight)
        ctx.setFillColor(L.monthBandBg.cgColor)
        ctx.fill(rect)

        // Gold left accent bar
        ctx.setFillColor(L.accentGold.cgColor)
        ctx.fill(CGRect(x: L.marginH, y: y, width: 3, height: L.monthBandHeight))

        drawText(label,
                 in: CGRect(x: L.marginH + 8, y: y + 1, width: L.contentWidth - 12, height: L.monthBandHeight - 2),
                 font: L.fontMonthBand,
                 color: L.monthBandText,
                 alignment: .left)
    }

    private func drawFlightRow(_ ctx: CGContext, flight: FlightSector, y: CGFloat, rowIndex: Int, rowRect: CGRect) {
        // Background
        let isSim = flight.simTimeValue > 0
        let bg: UIColor = isSim ? L.simRowBg : (rowIndex % 2 == 0 ? L.rowBase : L.rowAlt)
        ctx.setFillColor(bg.cgColor)
        ctx.fill(rowRect)

        // Cell inset for text
        let inset: CGFloat = 2
        let textH = L.dataRowHeight - 2

        func cellRect(_ colId: Int) -> CGRect? {
            guard let x = L.columnOffsets[colId], let col = L.columns.first(where: { $0.id == colId }) else { return nil }
            return CGRect(x: x + inset, y: y + 1, width: col.width - inset * 2, height: textH)
        }

        // Date
        if let r = cellRect(0) {
            drawText(shortDate(flight.date), in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Aircraft Type
        if let r = cellRect(1) {
            let typeLabel = isSim ? "SIM" : flight.aircraftType
            drawText(typeLabel, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Aircraft Reg — blank for sim
        if let r = cellRect(2), !isSim {
            drawText(flight.aircraftReg, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Route
        if let r = cellRect(3) {
            drawText(flight.fromAirport, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }
        if let r = cellRect(4) {
            drawText(flight.toAirport, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Crew
        if let r = cellRect(5) {
            drawText(flight.captainName, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .left)
        }
        if let r = cellRect(6) {
            drawText(flight.foName, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .left)
        }

        // Flight details
        if let r = cellRect(7) {
            drawText(flight.flightNumberFormatted, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }
        if let r = cellRect(8), !flight.outTime.isEmpty {
            drawText(formatHHMM(flight.outTime), in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }
        if let r = cellRect(9), !flight.inTime.isEmpty {
            drawText(formatHHMM(flight.inTime), in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }
        if let r = cellRect(10), !flight.remarks.isEmpty {
            drawText(flight.remarks, in: r, font: L.fontDataRemarks, color: L.remarksText, alignment: .left, truncate: true)
        }

        // Time columns — zero-suppress
        let timeMap: [(Int, Double)] = [
            (11, flight.blockTimeValue),
            (12, flight.nightTimeValue),
            (13, flight.p1TimeValue),
            (14, flight.p1usTimeValue),
            (15, flight.p2TimeValue),
            (16, flight.instrumentTimeValue),
            (17, flight.simTimeValue),
            (18, flight.spInsTimeValue),
        ]
        for (colId, value) in timeMap {
            guard value > 0, let r = cellRect(colId) else { continue }
            drawText(String(format: "%.1f", value), in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // T/O & Ldgs — zero-suppress
        let intMap: [(Int, Int)] = [
            (19, flight.dayTakeoffs),
            (20, flight.nightTakeoffs),
            (21, flight.dayLandings),
            (22, flight.nightLandings),
        ]
        for (colId, value) in intMap {
            guard value > 0, let r = cellRect(colId) else { continue }
            drawText("\(value)", in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Approach boolean — filled dot
        let approachMap: [(Int, Bool)] = [
            (23, flight.isILS),
            (24, flight.isRNP),
            (25, flight.isAIII),
            (26, flight.isGLS),
            (27, flight.isNPA),
        ]
        for (colId, isSet) in approachMap {
            guard isSet, let r = cellRect(colId) else { continue }
            drawText("●", in: r, font: UIFont.systemFont(ofSize: 6), color: L.approachDot, alignment: .center)
        }
    }

    // MARK: - Footer

    private func drawFooter(_ ctx: CGContext) {
        let footerY = L.footerTop
        let totalsToDate = broughtForward + pageTotals

        let rows: [(label: String, totals: PageTotals, bold: Bool)] = [
            ("TOTAL THIS PAGE",  pageTotals,     false),
            ("BROUGHT FORWARD",  broughtForward, false),
            ("TOTALS TO DATE",   totalsToDate,   true),
        ]

        // Gold rule above footer
        ctx.setStrokeColor(L.totalsRule.cgColor)
        ctx.setLineWidth(1.0)
        ctx.move(to: CGPoint(x: L.marginH, y: footerY))
        ctx.addLine(to: CGPoint(x: L.pageSize.width - L.marginH, y: footerY))
        ctx.strokePath()

        for (i, row) in rows.enumerated() {
            let y = footerY + CGFloat(i) * L.footerRowHeight

            // Background
            ctx.setFillColor(L.totalsBg.cgColor)
            ctx.fill(CGRect(x: L.marginH, y: y, width: L.contentWidth, height: L.footerRowHeight))

            // Label spans date + aircraft + route + crew columns
            let labelWidth = L.groupGeometry(for: .crew).x + L.groupGeometry(for: .crew).width - L.marginH
            let labelFont = row.bold ? L.fontFooterTotal : L.fontFooterLabel
            let valueFont = row.bold ? L.fontFooterTotal : L.fontFooterValue

            drawText(row.label,
                     in: CGRect(x: L.marginH + 4, y: y + 1, width: labelWidth - 8, height: L.footerRowHeight - 2),
                     font: labelFont,
                     color: L.monthBandText,
                     alignment: .right)

            // Values for time + movements + approaches columns
            for colId in 11...27 {
                guard let col = L.columns.first(where: { $0.id == colId }),
                      let x = L.columnOffsets[colId] else { continue }
                let val = row.totals.formattedValue(for: colId)
                guard !val.isEmpty else { continue }
                drawText(val,
                         in: CGRect(x: x + 1, y: y + 1, width: col.width - 2, height: L.footerRowHeight - 2),
                         font: valueFont,
                         color: L.monthBandText,
                         alignment: .center)
            }
        }
    }

    // MARK: - Grid Lines (drawn last, on top)

    private func drawGridLines(_ ctx: CGContext) {
        let dataBottom = L.footerTop + CGFloat(L.footerRowCount) * L.footerRowHeight
        let left = L.marginH
        let right = L.pageSize.width - L.marginH

        // Outer border of the entire table
        ctx.setStrokeColor(L.gridLine.cgColor)
        ctx.setLineWidth(0.5)
        let tableRect = CGRect(x: left, y: L.groupHeaderTop, width: L.contentWidth, height: dataBottom - L.groupHeaderTop)
        ctx.stroke(tableRect)

        // Horizontal row lines (data area only)
        ctx.setLineWidth(0.25)
        ctx.setStrokeColor(L.gridLineThin.cgColor)
        var y = L.dataTop
        for _ in 0..<L.maxDataSlotsPerPage {
            ctx.move(to: CGPoint(x: left, y: y))
            ctx.addLine(to: CGPoint(x: right, y: y))
            y += L.dataRowHeight
        }
        ctx.strokePath()

        // Horizontal footer row lines
        ctx.setStrokeColor(L.gridLine.cgColor)
        ctx.setLineWidth(0.5)
        for i in 1...L.footerRowCount {
            let fy = L.footerTop + CGFloat(i) * L.footerRowHeight
            ctx.move(to: CGPoint(x: left, y: fy))
            ctx.addLine(to: CGPoint(x: right, y: fy))
        }
        ctx.strokePath()

        // Vertical column lines
        var prevGroup: ColumnGroup? = nil
        for col in L.columns {
            guard let x = L.columnOffsets[col.id] else { continue }
            let isGroupBoundary = col.group != prevGroup
            ctx.setStrokeColor(isGroupBoundary ? L.gridLine.cgColor : L.gridLineThin.cgColor)
            ctx.setLineWidth(isGroupBoundary ? 0.5 : 0.25)
            ctx.move(to: CGPoint(x: x, y: L.groupHeaderTop))
            ctx.addLine(to: CGPoint(x: x, y: dataBottom))
            ctx.strokePath()
            prevGroup = col.group
        }

        // Right edge of last column
        if let lastCol = L.columns.last, let lastX = L.columnOffsets[lastCol.id] {
            let rightEdge = lastX + lastCol.width
            ctx.setStrokeColor(L.gridLine.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: rightEdge, y: L.groupHeaderTop))
            ctx.addLine(to: CGPoint(x: rightEdge, y: dataBottom))
            ctx.strokePath()
        }

        // Separator between group header and leaf header rows
        ctx.setStrokeColor(L.gridLine.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: left, y: L.leafHeaderTop))
        ctx.addLine(to: CGPoint(x: right, y: L.leafHeaderTop))
        ctx.strokePath()
    }

    // MARK: - Text Drawing Helper

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        truncate: Bool = false
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = truncate ? .byTruncatingTail : .byClipping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    // MARK: - Formatting Helpers

    private func shortDate(_ dateString: String) -> String {
        // Input: "dd/MM/yyyy", output: "dd/MM/yy"
        let parts = dateString.split(separator: "/")
        guard parts.count == 3 else { return dateString }
        let year = String(parts[2].suffix(2))
        return "\(parts[0])/\(parts[1])/\(year)"
    }

    private func formatHHMM(_ raw: String) -> String {
        // Input may be "HHMM" (4 chars) or "HH:MM" — normalise to "HH:MM"
        let clean = raw.replacingOccurrences(of: ":", with: "")
        guard clean.count == 4 else { return raw }
        return "\(clean.prefix(2)):\(clean.suffix(2))"
    }
}
