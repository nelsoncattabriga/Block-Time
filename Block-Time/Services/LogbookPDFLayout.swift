//
//  LogbookPDFLayout.swift
//  Block-Time
//

import UIKit

// MARK: - Column Group

enum ColumnGroup: String {
    case date
    case aircraft
    case crew
    case route
    case remarks
    case time
}

// MARK: - Column Definition

struct ColumnDef {
    let id: Int
    let title: String
    let width: CGFloat
    let alignment: NSTextAlignment
    let group: ColumnGroup
}

// MARK: - Layout Constants

enum LogbookPDFLayout {

    // MARK: Page geometry

    static nonisolated let pageSize = CGSize(width: 842, height: 595)
    static nonisolated let marginH: CGFloat = 18
    static nonisolated let pageHeaderHeight: CGFloat = 0   // no per-page header band
    static nonisolated let subHeaderHeight: CGFloat = 0
    static nonisolated let groupHeaderHeight: CGFloat = 24
    static nonisolated let leafHeaderHeight: CGFloat = 18
    static nonisolated let dataRowHeight: CGFloat = 18
    static nonisolated let footerRowHeight: CGFloat = 14
    static nonisolated let footerRowCount: Int = 3
    static nonisolated let maxDataSlotsPerPage: Int = 25
    static nonisolated let topMargin: CGFloat = 38         // centres table vertically on A4 landscape

    static nonisolated let groupHeaderTop: CGFloat = topMargin
    static nonisolated let leafHeaderTop: CGFloat = groupHeaderTop + groupHeaderHeight
    static nonisolated let dataTop: CGFloat = leafHeaderTop + leafHeaderHeight
    static nonisolated let contentWidth: CGFloat = pageSize.width - marginH * 2  // 806 pt

    // MARK: Colours (CASA plain style)

    static nonisolated let headerBg        = UIColor(hex: "#FFFFFF")   // white header bg
    static nonisolated let headerText      = UIColor(hex: "#000000")   // black header text
    static nonisolated let rowAlt          = UIColor(hex: "#E8E8E8")   // light grey alternate row
    static nonisolated let rowBase         = UIColor(hex: "#FFFFFF")   // white row
    static nonisolated let totalsBg        = UIColor(hex: "#FFFFFF")   // white footer bg
    static nonisolated let gridLine        = UIColor(hex: "#000000")   // black borders
    static nonisolated let gridLineThin    = UIColor(hex: "#AAAAAA")   // grey inner lines
    static nonisolated let bodyText        = UIColor(hex: "#000000")
    static nonisolated let zeroText        = UIColor(hex: "#AAAAAA")

    // MARK: Fonts

    static nonisolated let fontGroupHeader = UIFont(name: "TimesNewRomanPS-BoldMT", size: 8) ?? .boldSystemFont(ofSize: 8)
    static nonisolated let fontLeafHeader  = UIFont(name: "TimesNewRomanPS-BoldMT", size: 7) ?? .boldSystemFont(ofSize: 7)
    static nonisolated let fontDataCell    = UIFont(name: "HelveticaNeue", size: 7) ?? .systemFont(ofSize: 7)
    static nonisolated let fontDataBold    = UIFont(name: "HelveticaNeue-Bold", size: 7) ?? .boldSystemFont(ofSize: 7)
    static nonisolated let fontDataRemarks = UIFont(name: "HelveticaNeue", size: 6.5) ?? .systemFont(ofSize: 6.5)
    static nonisolated let fontFooterLabel = UIFont(name: "HelveticaNeue-Bold", size: 7) ?? .boldSystemFont(ofSize: 7)
    static nonisolated let fontFooterValue = UIFont(name: "HelveticaNeue", size: 7) ?? .systemFont(ofSize: 7)
    static nonisolated let fontFooterTotal = UIFont(name: "HelveticaNeue-Bold", size: 7) ?? .boldSystemFont(ofSize: 7)
    static nonisolated let fontPageNum     = UIFont(name: "HelveticaNeue", size: 7) ?? .systemFont(ofSize: 7)

    // MARK: Column Definitions
    // Total usable width = 806 pt (842 - 18*2 margins), 17 columns
    // Order: DATE | AIRCRAFT | CREW | FLIGHT DETAILS (Flt#, From, To, Remarks) | TIME

    static nonisolated let columns: [ColumnDef] = [
        ColumnDef(id: 0,  title: "DATE",    width:  46, alignment: .center, group: .date),
        ColumnDef(id: 1,  title: "TYPE",    width:  36, alignment: .center, group: .aircraft),
        ColumnDef(id: 2,  title: "REG",     width:  36, alignment: .center, group: .aircraft),
        ColumnDef(id: 3,  title: "CAPT",    width: 85, alignment: .left,   group: .crew),
        ColumnDef(id: 4,  title: "F/O",     width: 85, alignment: .left,   group: .crew),
        ColumnDef(id: 5,  title: "FLT #",   width:  30, alignment: .center, group: .route),
        ColumnDef(id: 6,  title: "FROM",    width:  34, alignment: .center, group: .route),
        ColumnDef(id: 7,  title: "TO",      width:  34, alignment: .center, group: .route),
        ColumnDef(id: 8,  title: "REMARKS", width: 176, alignment: .left,   group: .remarks),
        ColumnDef(id: 9,  title: "BLOCK",   width:  32, alignment: .center, group: .time),
        ColumnDef(id: 10, title: "NIGHT",   width:  32, alignment: .center, group: .time),
        ColumnDef(id: 11, title: "P1",      width:  30, alignment: .center, group: .time),
        ColumnDef(id: 12, title: "ICUS",    width:  30, alignment: .center, group: .time),
        ColumnDef(id: 13, title: "P2",      width:  30, alignment: .center, group: .time),
        ColumnDef(id: 14, title: "INST",   width:  30, alignment: .center, group: .time),
        ColumnDef(id: 15, title: "SIM",     width:  30, alignment: .center, group: .time),
        ColumnDef(id: 16, title: "TRNG",  width:  30, alignment: .center, group: .time),
    ]

    // MARK: Group metadata

    static nonisolated let groupOrder: [ColumnGroup] = [.date, .aircraft, .crew, .route, .remarks, .time]

    static nonisolated let groupTitles: [ColumnGroup: String] = [
        .date:     "DATE",
        .aircraft: "AIRCRAFT",
        .crew:     "CREW",
        .route:    "FLIGHT",
        .remarks:  "REMARKS",
        .time:     "TIMES",
    ]

    // MARK: Computed column x-offsets (cached)

    static nonisolated let columnOffsets: [Int: CGFloat] = {
        var offsets: [Int: CGFloat] = [:]
        var x = marginH
        for col in columns {
            offsets[col.id] = x
            x += col.width
        }
        return offsets
    }()

    static nonisolated func groupGeometry(for group: ColumnGroup) -> (x: CGFloat, width: CGFloat) {
        let cols = columns.filter { $0.group == group }
        guard let first = cols.first, let offset = columnOffsets[first.id] else { return (marginH, 0) }
        let width = cols.reduce(0) { $0 + $1.width }
        return (offset, width)
    }

    // MARK: Footer geometry

    static nonisolated var footerTop: CGFloat {
        dataTop + CGFloat(maxDataSlotsPerPage) * dataRowHeight
    }
}

// MARK: - UIColor hex init

extension UIColor {
    convenience init(hex: String) {
        var hexSanitised = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitised.hasPrefix("#") { hexSanitised.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hexSanitised).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
