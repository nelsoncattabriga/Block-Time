//
//  LogbookPDFPageDrawer.swift
//  Block-Time
//

import UIKit

// MARK: - Cover Page

struct LogbookPDFCoverDrawer {

    let context: UIGraphicsPDFRendererContext
    let title: String
    let pilotName: String
    let arn: String
    let dateRange: String

    private let L = LogbookPDFLayout.self

    func draw() {
        let ctx = context.cgContext
        let page = L.pageSize

        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: page))

        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(1.0)
        let borderInset: CGFloat = 20
        ctx.stroke(CGRect(x: borderInset, y: borderInset,
                          width: page.width - borderInset * 2,
                          height: page.height - borderInset * 2))

        ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: borderInset + 4, y: borderInset + 4,
                          width: page.width - (borderInset + 4) * 2,
                          height: page.height - (borderInset + 4) * 2))

        let centreX = page.width / 2
        let textWidth: CGFloat = page.width - 120

        let titleFont = UIFont(name: "TimesNewRomanPS-BoldMT", size: 28) ?? .boldSystemFont(ofSize: 28)
        drawCentredText(title,
                        centreX: centreX, y: page.height / 2 - 80,
                        width: textWidth, font: titleFont, color: .black)

        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(0.75)
        let ruleY = page.height / 2 - 46
        ctx.move(to: CGPoint(x: centreX - 120, y: ruleY))
        ctx.addLine(to: CGPoint(x: centreX + 120, y: ruleY))
        ctx.strokePath()

        let nameFont = UIFont(name: "TimesNewRomanPSMT", size: 16) ?? .systemFont(ofSize: 16)
        drawCentredText(pilotName,
                        centreX: centreX, y: page.height / 2 - 36,
                        width: textWidth, font: nameFont, color: .black)

        if !arn.isEmpty {
            let arnFont = UIFont(name: "TimesNewRomanPSMT", size: 11) ?? .systemFont(ofSize: 11)
            drawCentredText("ARN \(arn)",
                            centreX: centreX, y: page.height / 2 - 14,
                            width: textWidth, font: arnFont, color: UIColor(white: 0.3, alpha: 1))
        }

        let rangeFont = UIFont(name: "TimesNewRomanPSMT", size: 11) ?? .systemFont(ofSize: 11)
        let rangeY = arn.isEmpty ? page.height / 2 + 4 : page.height / 2 + 10
        drawCentredText(dateRange,
                        centreX: centreX, y: rangeY,
                        width: textWidth, font: rangeFont, color: UIColor(white: 0.3, alpha: 1))

        let appFont = UIFont(name: "HelveticaNeue", size: 8) ?? .systemFont(ofSize: 8)
        let genDate = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        drawCentredText("Printed  ·  \(genDate)",
                        centreX: centreX, y: page.height - borderInset - 24,
                        width: textWidth, font: appFont, color: UIColor(white: 0.5, alpha: 1))
    }

    private func drawCentredText(_ text: String, centreX: CGFloat, y: CGFloat,
                                 width: CGFloat, font: UIFont, color: UIColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: style,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let rect = CGRect(x: centreX - width / 2, y: y, width: width, height: size.height + 2)
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }
}

// MARK: - Data Page

struct LogbookPDFPageDrawer {

    let context: UIGraphicsPDFRendererContext
    let slots: [RowSlot]
    let pageTotals: PageTotals
    let broughtForward: PageTotals
    let pageNumber: Int
    let totalPages: Int
    let dateFormat: String
    let useHHMM: Bool
    /// Pre-resolved date strings keyed by "date|outTime|from|to"
    let flightToDate: [String: String]
    /// Active column definitions — Standard callers pass LogbookPDFLayout.columns.
    let columns: [ColumnDef]
    /// Active column offsets — Standard callers pass LogbookPDFLayout.columnOffsets.
    let columnOffsets: [Int: CGFloat]
    /// Custom field definitions used by Training Record mode; empty for Standard.
    let customFields: [CustomCounterDefinition]

    private let L = LogbookPDFLayout.self

    private var utcInputFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.locale = Locale(identifier: "en_AU")
        return f
    }

    private var dateOutputFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = dateFormat
        f.locale = Locale(identifier: "en_AU")
        return f
    }

    private func effectiveDateString(for flight: FlightSector) -> String {
        let key = "\(flight.date)|\(flight.outTime)|\(flight.fromAirport)|\(flight.toAirport)"
        return flightToDate[key] ?? flight.date
    }

    func draw() {
        let ctx = context.cgContext
        drawPageBackground(ctx)
        drawPageNumber(ctx)
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

    // MARK: - Page Number

    private func drawPageNumber(_ ctx: CGContext) {
        let label = "Page \(pageNumber) of \(totalPages)"
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        let attrs: [NSAttributedString.Key: Any] = [
            .font: L.fontPageNum, .foregroundColor: UIColor.black, .paragraphStyle: style,
        ]
        let rect = CGRect(x: L.pageSize.width - L.marginH - 80,
                          y: L.pageSize.height - 10,
                          width: 80, height: 10)
        (label as NSString).draw(in: rect, withAttributes: attrs)
    }

    // MARK: - Column Headers

    // Groups whose leaf row has no sub-labels — drawn as a single merged cell spanning both header rows
    private let mergedHeaderGroups: Set<ColumnGroup> = [.date, .remarks]

    private func drawColumnHeaders(_ ctx: CGContext) {
        let groupTop    = L.groupHeaderTop
        let leafTop     = L.leafHeaderTop
        let totalHeight = L.groupHeaderHeight + L.leafHeaderHeight

        // Row 1: group headers — merged groups span full height, others span only groupHeaderHeight
        for group in L.groupOrder {
            let geo = L.groupGeometry(for: group, in: columns, offsets: columnOffsets)
            guard geo.width > 0 else { continue }
            let isMerged = mergedHeaderGroups.contains(group)
            let height = isMerged ? totalHeight : L.groupHeaderHeight
            ctx.setFillColor(L.headerBg.cgColor)
            ctx.fill(CGRect(x: geo.x, y: groupTop, width: geo.width, height: height))
            let label = L.groupTitles[group] ?? ""
            drawTextVCentred(label,
                             in: CGRect(x: geo.x + 2, y: groupTop, width: geo.width - 4, height: height),
                             font: L.fontGroupHeader, color: L.headerText, alignment: .center)
        }

        // Row 2: leaf column labels — fill and label only for non-merged groups
        for group in L.groupOrder where !mergedHeaderGroups.contains(group) {
            let geo = L.groupGeometry(for: group, in: columns, offsets: columnOffsets)
            guard geo.width > 0 else { continue }
            ctx.setFillColor(L.headerBg.cgColor)
            ctx.fill(CGRect(x: geo.x, y: leafTop, width: geo.width, height: L.leafHeaderHeight))
        }
        for col in columns where !mergedHeaderGroups.contains(col.group) {
            guard let x = columnOffsets[col.id] else { continue }
            drawTextVCentred(col.title,
                             in: CGRect(x: x + 1, y: leafTop, width: col.width - 2, height: L.leafHeaderHeight),
                             font: L.fontLeafHeader, color: L.headerText, alignment: .center)
        }
    }

    // MARK: - Data Rows

    private func drawRows(_ ctx: CGContext) {
        for (rowIndex, slot) in slots.enumerated() {
            let y = L.dataTop + CGFloat(rowIndex) * L.dataRowHeight
            let rowRect = CGRect(x: L.marginH, y: y, width: L.contentWidth, height: L.dataRowHeight)
            if case .flight(let flight) = slot {
                drawFlightRow(ctx, flight: flight, y: y, rowIndex: rowIndex, rowRect: rowRect)
            }
        }
    }

    private func drawFlightRow(_ ctx: CGContext, flight: FlightSector, y: CGFloat, rowIndex: Int, rowRect: CGRect) {
        let bg: UIColor = rowIndex % 2 == 0 ? L.rowBase : L.rowAlt
        ctx.setFillColor(bg.cgColor)
        ctx.fill(rowRect)

        let inset: CGFloat = 2

        func cellRect(_ colId: Int) -> CGRect? {
            guard let x = columnOffsets[colId],
                  let col = columns.first(where: { $0.id == colId }) else { return nil }
            return CGRect(x: x + inset, y: y, width: col.width - inset * 2, height: L.dataRowHeight)
        }

        // Date (col 0)
        if let r = cellRect(0) {
            let dateStr = effectiveDateString(for: flight)
            let parsed = utcInputFormatter.date(from: dateStr) ?? Date()
            drawTextVCentred(dateOutputFormatter.string(from: parsed), in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Aircraft Type (col 1)
        if let r = cellRect(1) {
            drawTextVCentred(flight.aircraftType, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Aircraft Reg (col 2)
        if let r = cellRect(2) {
            drawTextVCentred(flight.aircraftReg, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Crew (cols 3, 4) — centred; absent in Training Record (cellRect returns nil for missing ids)
        if let r = cellRect(3) {
            drawTextVCentred(flight.captainName, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }
        if let r = cellRect(4) {
            drawTextVCentred(flight.foName, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Flight number (col 5) — blank for SUMMARY
        if let r = cellRect(5) {
            let fltNum = flight.flightNumber.uppercased() == "SUMMARY" ? "" : flight.flightNumberFormatted
            drawTextVCentred(fltNum, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Route (cols 6, 7)
        if let r = cellRect(6) {
            drawTextVCentred(flight.fromAirport, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }
        if let r = cellRect(7) {
            drawTextVCentred(flight.toAirport, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }

        // Remarks (col 8)
        if let r = cellRect(8), !flight.remarks.isEmpty {
            drawTextVCentred(flight.remarks, in: r, font: L.fontDataRemarks, color: L.bodyText, alignment: .center, wrap: true)
        }

        // Standard time columns (cols 9–16) — zero-suppress
        let timeMap: [(Int, Double)] = [
            (9,  flight.blockTimeValue),
            (10, flight.nightTimeValue),
            (11, flight.p1TimeValue),
            (12, flight.p1usTimeValue),
            (13, flight.p2TimeValue),
            (14, flight.instrumentTimeValue),
            (15, flight.simTimeValue),
            (16, flight.spInsTimeValue),
        ]
        for (colId, value) in timeMap {
            guard value > 0, let r = cellRect(colId) else { continue }
            let font = colId == 9 ? L.fontDataBold : L.fontDataCell
            let text = useHHMM ? Self.decimalToHHMM(value) : String(format: "%.1f", value)
            drawTextVCentred(text, in: r, font: font, color: L.bodyText, alignment: .center)
        }

        // Custom field columns (id >= 100) — Training Record mode only
        for col in columns where col.id >= 100 {
            let n = col.id - 100
            guard n < customFields.count else { continue }
            let def = customFields[n]
            guard let raw = flight.counterEntries[def.columnIndex], !raw.isEmpty else { continue }
            guard let r = cellRect(col.id) else { continue }
            drawTextVCentred(raw, in: r, font: L.fontDataCell, color: L.bodyText, alignment: .center)
        }
    }

    // MARK: - Footer

    private func drawFooter(_ ctx: CGContext) {
        let footerY = L.footerTop
        let footerBottom = footerY + CGFloat(L.footerRowCount) * L.footerRowHeight
        let totalsToDate = broughtForward + pageTotals

        let rows: [(label: String, totals: PageTotals, bold: Bool)] = [
            ("TOTAL THIS PAGE", pageTotals,     false),
            ("BROUGHT FORWARD", broughtForward, false),
            ("TOTALS TO DATE",  totalsToDate,   true),
        ]

        // Box spans from just before the first time-group column (label area) to right edge.
        // In Standard mode the first time col is id 9; in Training Record it may be id 100 or 16.
        let timeGroupCols = columns.filter { $0.group == .time }
        guard let firstTimeCol = timeGroupCols.first,
              let firstTimeColX = columnOffsets[firstTimeCol.id],
              let lastCol = columns.last,
              let lastColX = columnOffsets[lastCol.id] else { return }

        let labelAreaWidth: CGFloat = 100
        let boxLeft  = firstTimeColX - labelAreaWidth
        let boxRight = lastColX + lastCol.width

        // Fill box background
        ctx.setFillColor(L.totalsBg.cgColor)
        ctx.fill(CGRect(x: boxLeft, y: footerY,
                        width: boxRight - boxLeft,
                        height: CGFloat(L.footerRowCount) * L.footerRowHeight))

        // Top and bottom borders — heavier weight
        ctx.setStrokeColor(L.gridLine.cgColor)
        ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: boxLeft,  y: footerY))
        ctx.addLine(to: CGPoint(x: boxRight, y: footerY))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: boxLeft,  y: footerBottom))
        ctx.addLine(to: CGPoint(x: boxRight, y: footerBottom))
        ctx.strokePath()

        // Left and right borders
        ctx.move(to: CGPoint(x: boxLeft,  y: footerY))
        ctx.addLine(to: CGPoint(x: boxLeft,  y: footerBottom))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: boxRight, y: footerY))
        ctx.addLine(to: CGPoint(x: boxRight, y: footerBottom))
        ctx.strokePath()

        for (i, row) in rows.enumerated() {
            let y = footerY + CGFloat(i) * L.footerRowHeight
            let labelFont = row.bold ? L.fontFooterTotal : L.fontFooterLabel
            let valueFont = row.bold ? L.fontFooterTotal : L.fontFooterValue

            // Label centred in the label area, immediately left of the first time column
            drawTextVCentred(row.label,
                             in: CGRect(x: boxLeft, y: y, width: labelAreaWidth, height: L.footerRowHeight),
                             font: labelFont, color: L.bodyText, alignment: .center)

            // Iterate the actual time-group columns present in this layout
            for col in timeGroupCols {
                guard let x = columnOffsets[col.id] else { continue }
                let val: String
                if col.id >= 100 {
                    // Custom field column
                    let n = col.id - 100
                    guard n < customFields.count else { continue }
                    let def = customFields[n]
                    val = row.totals.formattedCustomValue(columnIndex: def.columnIndex, type: def.type, useHHMM: useHHMM)
                } else {
                    val = row.totals.formattedValue(for: col.id, useHHMM: useHHMM)
                }
                guard !val.isEmpty else { continue }
                let isFirstTime = col.id == firstTimeCol.id
                let colFont = (isFirstTime || row.bold) ? L.fontFooterTotal : valueFont
                drawTextVCentred(val,
                                 in: CGRect(x: x + 1, y: y, width: col.width - 2, height: L.footerRowHeight),
                                 font: colFont, color: L.bodyText, alignment: .center)
            }
        }
    }

    // MARK: - Grid Lines

    private func drawGridLines(_ ctx: CGContext) {
        let dataBottom = L.footerTop + CGFloat(L.footerRowCount) * L.footerRowHeight
        let left  = L.marginH
        let right = L.pageSize.width - L.marginH

        // Outer border of data table (header + data rows only — footer has its own border)
        ctx.setStrokeColor(L.gridLine.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(CGRect(x: left, y: L.groupHeaderTop, width: L.contentWidth, height: L.footerTop - L.groupHeaderTop))

        // Solid line under leaf header row (makes the two header rows feel like one block)
        ctx.setLineWidth(0.75)
        ctx.move(to: CGPoint(x: left, y: L.dataTop))
        ctx.addLine(to: CGPoint(x: right, y: L.dataTop))
        ctx.strokePath()

        // Separator between group header row and leaf header row — skip merged groups and zero-width groups
        ctx.setStrokeColor(L.gridLineThin.cgColor)
        ctx.setLineWidth(0.25)
        for group in L.groupOrder {
            let geo = L.groupGeometry(for: group, in: columns, offsets: columnOffsets)
            guard !mergedHeaderGroups.contains(group), geo.width > 0 else { continue }
            ctx.move(to: CGPoint(x: geo.x, y: L.leafHeaderTop))
            ctx.addLine(to: CGPoint(x: geo.x + geo.width, y: L.leafHeaderTop))
        }
        ctx.strokePath()

        // Horizontal data row lines (thin)
        ctx.setLineWidth(0.25)
        ctx.setStrokeColor(L.gridLineThin.cgColor)
        var y = L.dataTop + L.dataRowHeight
        for _ in 0..<(L.maxDataSlotsPerPage - 1) {
            ctx.move(to: CGPoint(x: left, y: y))
            ctx.addLine(to: CGPoint(x: right, y: y))
            y += L.dataRowHeight
        }
        ctx.strokePath()

        // Internal footer row dividers — only within the totals box (first time col onward)
        let firstTimeCol = columns.first(where: { $0.group == .time })
        let footerBoxLeft = (firstTimeCol.flatMap { columnOffsets[$0.id] } ?? right) - 100
        ctx.setStrokeColor(L.gridLineThin.cgColor)
        ctx.setLineWidth(0.25)
        for i in 1..<L.footerRowCount {
            let fy = L.footerTop + CGFloat(i) * L.footerRowHeight
            ctx.move(to: CGPoint(x: footerBoxLeft, y: fy))
            ctx.addLine(to: CGPoint(x: right, y: fy))
        }
        ctx.strokePath()

        // Vertical lines — uniform thin weight throughout header and data area
        // Time column dividers continue through the footer box
        ctx.setStrokeColor(L.gridLineThin.cgColor)
        ctx.setLineWidth(0.25)
        var prevGroup: ColumnGroup? = nil
        for col in columns {
            guard let x = columnOffsets[col.id] else { continue }
            let isGroupBoundary = col.group != prevGroup
            let isTimeCol = col.group == .time
            ctx.move(to: CGPoint(x: x, y: isGroupBoundary ? L.groupHeaderTop : L.leafHeaderTop))
            ctx.addLine(to: CGPoint(x: x, y: isTimeCol ? dataBottom : L.footerTop))
            prevGroup = col.group
        }
        ctx.strokePath()
    }

    // MARK: - Text Helpers

    // Draws text vertically centred within rect.
    // truncate=true: single line, tail-truncated.
    // truncate=false, wrap=false: single line, shrink font to fit width.
    // truncate=false, wrap=true: try single line at full size; if too wide, try 2-line wrap;
    //   if 2-line wrap is too tall, shrink font until it fits within rect.height.
    private func drawTextVCentred(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .center,
        truncate: Bool = false,
        wrap: Bool = false,
        minFontSize: CGFloat = 4
    ) {
        let makeStyle: (NSLineBreakMode) -> NSMutableParagraphStyle = { mode in
            let s = NSMutableParagraphStyle()
            s.alignment = alignment
            s.lineBreakMode = mode
            return s
        }

        if truncate {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color,
                .paragraphStyle: makeStyle(.byTruncatingTail),
            ]
            let h = (text as NSString).size(withAttributes: attrs).height
            let vOffset = max(0, (rect.height - h) / 2)
            (text as NSString).draw(
                in: CGRect(x: rect.minX, y: rect.minY + vOffset, width: rect.width, height: h),
                withAttributes: attrs)
            return
        }

        if wrap {
            // Measure wrapped height for a given font size
            func wrappedHeight(size: CGFloat) -> CGFloat {
                let f = font.withSize(size)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: f, .foregroundColor: color,
                    .paragraphStyle: makeStyle(.byWordWrapping),
                ]
                let bound = CGSize(width: rect.width, height: .greatestFiniteMagnitude)
                return (text as NSString).boundingRect(
                    with: bound, options: .usesLineFragmentOrigin,
                    attributes: attrs, context: nil).height
            }

            // Find smallest font size that fits within rect.height, stepping down if needed
            var size = font.pointSize
            while size > minFontSize && wrappedHeight(size: size) > rect.height {
                size -= 0.5
            }

            let drawFont = font.withSize(size)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: drawFont, .foregroundColor: color,
                .paragraphStyle: makeStyle(.byWordWrapping),
            ]
            let h = wrappedHeight(size: size)
            let vOffset = max(0, (rect.height - h) / 2)
            (text as NSString).draw(
                in: CGRect(x: rect.minX, y: rect.minY + vOffset, width: rect.width, height: h),
                withAttributes: attrs)
            return
        }

        // Single-line shrink-to-fit
        var drawFont = font
        var size = font.pointSize
        while size > minFontSize {
            let w = (text as NSString).size(withAttributes: [.font: drawFont]).width
            if w <= rect.width { break }
            size -= 0.5
            drawFont = font.withSize(size)
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: drawFont, .foregroundColor: color,
            .paragraphStyle: makeStyle(.byClipping),
        ]
        let h = (text as NSString).size(withAttributes: attrs).height
        let vOffset = max(0, (rect.height - h) / 2)
        (text as NSString).draw(
            in: CGRect(x: rect.minX, y: rect.minY + vOffset, width: rect.width, height: h),
            withAttributes: attrs)
    }

    private static func decimalToHHMM(_ v: Double) -> String {
        let totalMinutes = Int((v * 60).rounded())
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

}
