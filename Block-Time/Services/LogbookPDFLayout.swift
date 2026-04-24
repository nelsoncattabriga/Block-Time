//
//  LogbookPDFLayout.swift
//  Block-Time
//

import UIKit

// MARK: - Column Group

enum ColumnGroup: String {
    case date
    case aircraft
    case route
    case crew
    case details
    case time
    case movements
    case approaches
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
    static nonisolated let pageHeaderHeight: CGFloat = 28
    static nonisolated let subHeaderHeight: CGFloat = 10
    static nonisolated let groupHeaderHeight: CGFloat = 14
    static nonisolated let leafHeaderHeight: CGFloat = 14
    static nonisolated let dataRowHeight: CGFloat = 18
    static nonisolated let monthBandHeight: CGFloat = 14
    static nonisolated let footerRowHeight: CGFloat = 14
    static nonisolated let footerRowCount: Int = 3
    static nonisolated let maxDataSlotsPerPage: Int = 25

    static nonisolated let contentTop: CGFloat = pageHeaderHeight + subHeaderHeight
    static nonisolated let groupHeaderTop: CGFloat = contentTop
    static nonisolated let leafHeaderTop: CGFloat = groupHeaderTop + groupHeaderHeight
    static nonisolated let dataTop: CGFloat = leafHeaderTop + leafHeaderHeight
    static nonisolated let headerBandHeight: CGFloat = pageHeaderHeight + subHeaderHeight + groupHeaderHeight + leafHeaderHeight
    static nonisolated let contentWidth: CGFloat = pageSize.width - marginH * 2  // 806 pt

    // MARK: Colours

    static nonisolated let headerNavy      = UIColor(hex: "#1A2744")
    static nonisolated let subHeaderSteel  = UIColor(hex: "#2E4272")
    static nonisolated let headerText      = UIColor(hex: "#FFFFFF")
    static nonisolated let rowAlt          = UIColor(hex: "#EEF2F8")
    static nonisolated let rowBase         = UIColor(hex: "#FFFFFF")
    static nonisolated let monthBandBg     = UIColor(hex: "#D6E0F0")
    static nonisolated let monthBandText   = UIColor(hex: "#1A2744")
    static nonisolated let totalsBg        = UIColor(hex: "#FEFBE8")
    static nonisolated let totalsRule      = UIColor(hex: "#C8B400")
    static nonisolated let gridLine        = UIColor(hex: "#BEC8D6")
    static nonisolated let gridLineThin    = UIColor(hex: "#D8DFE8")
    static nonisolated let accentGold      = UIColor(hex: "#C8A94A")
    static nonisolated let simRowBg        = UIColor(hex: "#F0F0F0")
    static nonisolated let approachDot     = UIColor(hex: "#1A2744")
    static nonisolated let zeroText        = UIColor(hex: "#AAAAAA")
    static nonisolated let bodyText        = UIColor(hex: "#1A1A1A")
    static nonisolated let remarksText     = UIColor(hex: "#2A2A2A")

    // MARK: Fonts

    static nonisolated let fontPageTitle   = UIFont(name: "Georgia-Bold", size: 11) ?? .boldSystemFont(ofSize: 11)
    static nonisolated let fontPageSub     = UIFont(name: "Georgia", size: 8) ?? .systemFont(ofSize: 8)
    static nonisolated let fontPageNum     = UIFont(name: "HelveticaNeue", size: 7.5) ?? .systemFont(ofSize: 7.5)
    static nonisolated let fontGroupHeader = UIFont(name: "Georgia-Bold", size: 7) ?? .boldSystemFont(ofSize: 7)
    static nonisolated let fontLeafHeader  = UIFont(name: "HelveticaNeue-Medium", size: 6) ?? .systemFont(ofSize: 6, weight: .medium)
    static nonisolated let fontMonthBand   = UIFont(name: "Georgia-BoldItalic", size: 8) ?? .italicSystemFont(ofSize: 8)
    static nonisolated let fontDataCell    = UIFont(name: "HelveticaNeue", size: 7) ?? .systemFont(ofSize: 7)
    static nonisolated let fontDataRemarks = UIFont(name: "HelveticaNeue", size: 6.5) ?? .systemFont(ofSize: 6.5)
    static nonisolated let fontFooterLabel = UIFont(name: "Georgia-Bold", size: 6.5) ?? .boldSystemFont(ofSize: 6.5)
    static nonisolated let fontFooterValue = UIFont(name: "HelveticaNeue-Medium", size: 7) ?? .systemFont(ofSize: 7, weight: .medium)
    static nonisolated let fontFooterTotal = UIFont(name: "Georgia-Bold", size: 7) ?? .boldSystemFont(ofSize: 7)

    // MARK: Column Definitions (total = 806 pt)

    static nonisolated let columns: [ColumnDef] = [
        ColumnDef(id: 0,  title: "DATE",    width: 38, alignment: .center, group: .date),
        ColumnDef(id: 1,  title: "TYPE",    width: 36, alignment: .center, group: .aircraft),
        ColumnDef(id: 2,  title: "REG",     width: 38, alignment: .center, group: .aircraft),
        ColumnDef(id: 3,  title: "FROM",    width: 38, alignment: .center, group: .route),
        ColumnDef(id: 4,  title: "TO",      width: 38, alignment: .center, group: .route),
        ColumnDef(id: 5,  title: "CAPT",    width: 50, alignment: .left,   group: .crew),
        ColumnDef(id: 6,  title: "F/O",     width: 50, alignment: .left,   group: .crew),
        ColumnDef(id: 7,  title: "FLT #",   width: 34, alignment: .center, group: .details),
        ColumnDef(id: 8,  title: "OUT",     width: 30, alignment: .center, group: .details),
        ColumnDef(id: 9,  title: "IN",      width: 30, alignment: .center, group: .details),
        ColumnDef(id: 10, title: "REMARKS", width: 62, alignment: .left,   group: .details),
        ColumnDef(id: 11, title: "BLOCK",   width: 28, alignment: .center, group: .time),
        ColumnDef(id: 12, title: "NIGHT",   width: 28, alignment: .center, group: .time),
        ColumnDef(id: 13, title: "P1",      width: 28, alignment: .center, group: .time),
        ColumnDef(id: 14, title: "P1US",    width: 28, alignment: .center, group: .time),
        ColumnDef(id: 15, title: "P2",      width: 28, alignment: .center, group: .time),
        ColumnDef(id: 16, title: "INSTR",   width: 28, alignment: .center, group: .time),
        ColumnDef(id: 17, title: "SIM",     width: 28, alignment: .center, group: .time),
        ColumnDef(id: 18, title: "SP·INS",  width: 28, alignment: .center, group: .time),
        ColumnDef(id: 19, title: "D T/O",   width: 18, alignment: .center, group: .movements),
        ColumnDef(id: 20, title: "N T/O",   width: 18, alignment: .center, group: .movements),
        ColumnDef(id: 21, title: "D LDG",   width: 18, alignment: .center, group: .movements),
        ColumnDef(id: 22, title: "N LDG",   width: 18, alignment: .center, group: .movements),
        ColumnDef(id: 23, title: "ILS",     width: 14, alignment: .center, group: .approaches),
        ColumnDef(id: 24, title: "RNP",     width: 13, alignment: .center, group: .approaches),
        ColumnDef(id: 25, title: "AIII",    width: 13, alignment: .center, group: .approaches),
        ColumnDef(id: 26, title: "GLS",     width: 13, alignment: .center, group: .approaches),
        ColumnDef(id: 27, title: "NPA",     width: 13, alignment: .center, group: .approaches),
    ]

    // MARK: Group metadata

    static nonisolated let groupOrder: [ColumnGroup] = [.date, .aircraft, .route, .crew, .details, .time, .movements, .approaches]

    static nonisolated let groupTitles: [ColumnGroup: String] = [
        .date:       "DATE",
        .aircraft:   "AIRCRAFT",
        .route:      "ROUTE",
        .crew:       "CREW",
        .details:    "FLIGHT DETAILS",
        .time:       "TIME",
        .movements:  "T/O & LDGS",
        .approaches: "APPROACHES",
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
