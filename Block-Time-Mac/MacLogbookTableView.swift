//
//  MacLogbookTableView.swift
//  Block-Time-Mac
//
//  Split-table logbook: frozen left pane (Date + Flight) + scrollable right pane.
//  Both panes share one Coordinator for data, selection, and vertical scroll sync.
//  Column order is defined by LogbookColumn — user reordering can be persisted later.
//

import AppKit
import BlockTimeKit
import SwiftUI

// MARK: - Vertically Centred Label

private final class CentredLabel: NSTextField {
    override func draw(_ dirtyRect: NSRect) {
        let str = attributedStringValue
        guard str.length > 0 else {
            super.draw(dirtyRect)
            return
        }
        let textHeight = str.boundingRect(with: NSSize(width: bounds.width, height: .greatestFiniteMagnitude),
                                          options: .usesLineFragmentOrigin).height
        let yOffset = max(0, (bounds.height - textHeight) / 2)
        var centred = bounds
        centred.origin.y = yOffset
        centred.size.height = textHeight
        str.draw(in: centred)
    }
}

// MARK: - Square Table View (draws empty rows without inset rounded corners)

fileprivate final class SquareTableView: NSTableView {
    // Always pass focus to the right table so selection colour stays consistent
    override var acceptsFirstResponder: Bool { false }

    override func drawBackground(inClipRect clipRect: NSRect) {
        guard numberOfRows > 0 else { return }
        // Derive stride from actual rendered row rects to match AppKit exactly
        let lastRow = numberOfRows - 1
        let lastRect = rect(ofRow: lastRow)
        let stride = lastRect.height
        var y = lastRect.maxY
        var row = numberOfRows
        while y < clipRect.maxY {
            NSColor.alternatingContentBackgroundColors[row % 2].setFill()
            NSRect(x: 0, y: y, width: bounds.width, height: stride).fill()
            y += stride
            row += 1
        }
    }
}

// MARK: - Accent colours

private extension NSColor {
    static let rowPax     = NSColor.systemOrange
    static let rowSim     = NSColor.systemPurple
    static let rowSpIns   = NSColor.systemRed
    static let rowSummary = NSColor.systemTeal
    static let stripeWidth: CGFloat = 3

    static func accent(for accent: MacFlightRow.RowAccent) -> NSColor? {
        switch accent {
        case .none:    return nil
        case .pax:     return .rowPax
        case .sim:     return .rowSim
        case .spIns:   return .rowSpIns
        case .summary: return .rowSummary
        }
    }
}

// MARK: - Square Row View (frozen left pane — no rounded corners, with accent)

private final class SquareRowView: NSTableRowView {
    var accent: MacFlightRow.RowAccent = .none

    override func drawBackground(in dirtyRect: NSRect) {
        guard let table = superview as? NSTableView else { return }
        let idx = table.row(for: self)
        if let color = NSColor.accent(for: accent) {
            // Accented: solid tint only, no alternating base
            color.withAlphaComponent(0.13).setFill()
            bounds.fill()
            // Left stripe
            color.withAlphaComponent(0.85).setFill()
            NSRect(x: 0, y: 0, width: NSColor.stripeWidth, height: bounds.height).fill()
        } else {
            NSColor.alternatingContentBackgroundColors[idx % 2].setFill()
            bounds.fill()
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.selectedContentBackgroundColor.setFill()
        bounds.fill()
    }

    override var isEmphasized: Bool {
        get { true }
        set { }
    }
}

// MARK: - Accent Row View (right scrolling pane)

private final class AccentRowView: NSTableRowView {
    var accent: MacFlightRow.RowAccent = .none

    override func drawBackground(in dirtyRect: NSRect) {
        guard let table = superview as? NSTableView else { return }
        let idx = table.row(for: self)
        if let color = NSColor.accent(for: accent) {
            // Accented rows: solid accent tint, no alternating
            color.withAlphaComponent(0.13).setFill()
            bounds.fill()
        } else {
            // Normal rows: standard alternating background
            NSColor.alternatingContentBackgroundColors[idx % 2].setFill()
            bounds.fill()
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.selectedContentBackgroundColor.setFill()
        bounds.fill()
    }
}

// MARK: - Column Definition

struct LogbookColumn: Identifiable {
    let id: String
    let title: String
    let minWidth: CGFloat
    let idealWidth: CGFloat
    let value: (MacFlightRow) -> String
    var alignment: NSTextAlignment = .left

    static func frozenColumns(localTime: Bool) -> [LogbookColumn] { [
        LogbookColumn(id: "date",    title: "Date",   minWidth: 72, idealWidth: 84, value: { $0.dateDisplay(localTime: localTime) }, alignment: .center),
        LogbookColumn(id: "flight",  title: "Flt No", minWidth: 52, idealWidth: 68, value: { $0.flightNumber }, alignment: .center),
    ] }

    static func scrollingColumns(hhmm: Bool, rounding: String, localTime: Bool, useIATA: Bool = true) -> [LogbookColumn] {
        var cols: [LogbookColumn] = [
            LogbookColumn(id: "dep",     title: "DEP",       minWidth: 36,  idealWidth: 44,  value: { AirportService.shared.getDisplayCode($0.fromAirport, useIATA: useIATA) }, alignment: .center),
            LogbookColumn(id: "arr",     title: "ARR",       minWidth: 36,  idealWidth: 44,  value: { AirportService.shared.getDisplayCode($0.toAirport,   useIATA: useIATA) }, alignment: .center),
            LogbookColumn(id: "std",     title: "STD",       minWidth: 40,  idealWidth: 48,  value: { $0.displayTime($0.scheduledDeparture, localTime: localTime, airportICAO: $0.fromAirport) }, alignment: .center),
            LogbookColumn(id: "sta",     title: "STA",       minWidth: 40,  idealWidth: 48,  value: { $0.displayTime($0.scheduledArrival,   localTime: localTime, airportICAO: $0.toAirport)   }, alignment: .center),
            LogbookColumn(id: "out",     title: "OUT",       minWidth: 40,  idealWidth: 48,  value: { $0.displayTime($0.outTime,            localTime: localTime, airportICAO: $0.fromAirport) }, alignment: .center),
            LogbookColumn(id: "in",      title: "IN",        minWidth: 40,  idealWidth: 48,  value: { $0.displayTime($0.inTime,             localTime: localTime, airportICAO: $0.toAirport)   }, alignment: .center),
            LogbookColumn(id: "block",   title: "Block",     minWidth: 44,  idealWidth: 52,  value: { $0.blockDisplay(hhmm: hhmm, rounding: rounding) },       alignment: .center),
            LogbookColumn(id: "night",   title: "Night",     minWidth: 44,  idealWidth: 52,  value: { $0.nightDisplay(hhmm: hhmm, rounding: rounding) },       alignment: .center),
            LogbookColumn(id: "instr",   title: "Inst",      minWidth: 44,  idealWidth: 52,  value: { $0.instrumentDisplay(hhmm: hhmm, rounding: rounding) },  alignment: .center),
            LogbookColumn(id: "captain", title: "Captain",   minWidth: 80,  idealWidth: 130, value: { $0.captainName }, alignment: .center),
            LogbookColumn(id: "fo",      title: "FO",        minWidth: 80,  idealWidth: 130, value: { $0.foName },      alignment: .center),
            LogbookColumn(id: "so1",     title: "SO1",       minWidth: 80,  idealWidth: 130, value: { $0.so1Name },     alignment: .center),
            LogbookColumn(id: "so2",     title: "SO2",       minWidth: 80,  idealWidth: 130, value: { $0.so2Name },     alignment: .center),
            LogbookColumn(id: "p1",      title: "P1",        minWidth: 40,  idealWidth: 48,  value: { $0.p1Display(hhmm: hhmm, rounding: rounding) },          alignment: .center),
            LogbookColumn(id: "p1s",     title: "ICUS",      minWidth: 40,  idealWidth: 48,  value: { $0.p1usDisplay(hhmm: hhmm, rounding: rounding) },        alignment: .center),
            LogbookColumn(id: "p2",      title: "P2",        minWidth: 40,  idealWidth: 48,  value: { $0.p2Display(hhmm: hhmm, rounding: rounding) },          alignment: .center),
            LogbookColumn(id: "sim",     title: "Sim",       minWidth: 40,  idealWidth: 48,  value: { $0.simDisplay(hhmm: hhmm, rounding: rounding) },         alignment: .center),
            LogbookColumn(id: "spins",   title: "Sp/Ins",    minWidth: 44,  idealWidth: 52,  value: { $0.spInsDisplay(hhmm: hhmm, rounding: rounding) },       alignment: .center),
            LogbookColumn(id: "type",    title: "Type",      minWidth: 48,  idealWidth: 60,  value: { $0.aircraftType },       alignment: .center),
            LogbookColumn(id: "reg",     title: "Reg",       minWidth: 60,  idealWidth: 76,  value: { $0.aircraftReg },        alignment: .center),
            LogbookColumn(id: "tod",     title: "T/O Day",   minWidth: 36,  idealWidth: 42,  value: { $0.dayTakeoffs   > 0 ? "\($0.dayTakeoffs)"   : "" }, alignment: .center),
            LogbookColumn(id: "ton",     title: "T/O Night", minWidth: 36,  idealWidth: 42,  value: { $0.nightTakeoffs > 0 ? "\($0.nightTakeoffs)" : "" }, alignment: .center),
            LogbookColumn(id: "ldgd",    title: "Ldg Day",   minWidth: 36,  idealWidth: 42,  value: { $0.dayLandings   > 0 ? "\($0.dayLandings)"   : "" }, alignment: .center),
            LogbookColumn(id: "ldgn",    title: "Ldg Night", minWidth: 36,  idealWidth: 42,  value: { $0.nightLandings > 0 ? "\($0.nightLandings)" : "" }, alignment: .center),
            LogbookColumn(id: "pf",      title: "Was PF",    minWidth: 28,  idealWidth: 32,  value: { $0.isPilotFlying  ? "✓" : "" }, alignment: .center),
            LogbookColumn(id: "pax",     title: "PAXING",    minWidth: 28,  idealWidth: 32,  value: { $0.isPositioning  ? "✓" : "" }, alignment: .center),
            LogbookColumn(id: "ils",     title: "ILS",       minWidth: 28,  idealWidth: 32,  value: { $0.isILS  ? "✓" : "" }, alignment: .center),
            LogbookColumn(id: "gls",     title: "GLS",       minWidth: 28,  idealWidth: 32,  value: { $0.isGLS  ? "✓" : "" }, alignment: .center),
            LogbookColumn(id: "npa",     title: "NPA",       minWidth: 28,  idealWidth: 32,  value: { $0.isNPA  ? "✓" : "" }, alignment: .center),
            LogbookColumn(id: "rnp",     title: "RNP",       minWidth: 28,  idealWidth: 32,  value: { $0.isRNP  ? "✓" : "" }, alignment: .center),
            LogbookColumn(id: "aiii",    title: "AIII",      minWidth: 28,  idealWidth: 36,  value: { $0.isAIII ? "✓" : "" }, alignment: .center),
        ]

        // Inject one typed column per custom-field definition, sorted by columnIndex.
        let defs = MainActor.assumeIsolated { CustomCounterService.shared.definitions }
            .sorted { $0.columnIndex < $1.columnIndex }
        for def in defs {
            let idx = def.columnIndex
            let defType = def.type
            cols.append(LogbookColumn(
                id: "counter\(idx)",
                title: def.label,
                minWidth: 44,
                idealWidth: 64,
                value: { row in
                    let raw = row.counterValue(idx)
                    guard !raw.isEmpty else { return "" }
                    switch defType {
                    case .time:
                        let d = MacFlightRow.parseTime(raw)
                        return d > 0 ? MacFlightRow.formatTime(d, hhmm: hhmm, rounding: rounding) : raw
                    case .decimal:
                        if let d = Double(raw), d > 0 {
                            return MacFlightRow.decimalDisplay(d, rounding: rounding)
                        }
                        return raw
                    case .integer, .text:
                        return raw
                    }
                },
                alignment: .center
            ))
        }

        cols.append(LogbookColumn(id: "remarks", title: "Remarks", minWidth: 120, idealWidth: 800, value: { $0.remarks }))
        return cols
    }
}

// MARK: - Container NSView

/// Hosts the frozen left table and scrollable right table side by side.
final class SplitLogbookView: NSView {
    let leftScroll  = NSScrollView()
    let rightScroll = NSScrollView()
    fileprivate let leftTable = SquareTableView()
    let rightTable  = NSTableView()
    let divider     = NSBox()

    private static let dividerWidth: CGFloat = 1

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupDivider()
        setupScroll(leftScroll,  table: leftTable,  hasHorizontal: false)
        setupScroll(rightScroll, table: rightTable, hasHorizontal: true)
        addSubview(leftScroll)
        addSubview(divider)
        addSubview(rightScroll)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupDivider() {
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.isHidden = true
    }

    private func setupScroll(_ scroll: NSScrollView, table: NSTableView, hasHorizontal: Bool) {
        scroll.documentView = table
        scroll.hasVerticalScroller = hasHorizontal
        scroll.hasHorizontalScroller = hasHorizontal
        scroll.autohidesScrollers = false
        scroll.borderType = .noBorder
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 22
        table.rowSizeStyle = .custom
        table.allowsMultipleSelection = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.style = .inset
        table.headerView = NSTableHeaderView()
    }

    override func layout() {
        super.layout()
        let dw = SplitLogbookView.dividerWidth
        let leftWidth = leftTable.tableColumns.reduce(0) { $0 + $1.width }
        let intercellPadding = leftTable.intercellSpacing.width * CGFloat(leftTable.tableColumns.count)
        let lw = leftWidth + intercellPadding + 20
        // Match left pane height exactly to right so content origins align.
        // Right pane reserves space for horizontal scroller; left must do the same.
        let hScrollHeight = rightScroll.horizontalScroller?.frame.height ?? NSScroller.scrollerWidth(for: .regular, scrollerStyle: .overlay)
        let rightHeight = bounds.height
        let leftHeight  = rightHeight - hScrollHeight
        leftScroll.frame  = NSRect(x: 0,      y: hScrollHeight, width: lw,                     height: leftHeight)
        divider.frame     = NSRect(x: lw,      y: 0,             width: dw,                     height: bounds.height)
        rightScroll.frame = NSRect(x: lw + dw, y: 0,             width: bounds.width - lw - dw, height: rightHeight)
    }
}

// MARK: - NSViewRepresentable

struct MacLogbookTableView: NSViewRepresentable {
    let rows: [MacFlightRow]
    @Binding var selection: Set<UUID>
    var columns: [LogbookColumn]
    var frozenColumns: [LogbookColumn]
    var prefs: ColumnPreferences? = nil
    var hhmm: Bool = true
    var rounding: String = "standard"
    var localTime: Bool = false
    var useIATA: Bool = true
    var saveVersion: Int = 0
    var definitionsVersion: Int = 0

    private var rowIDs: [UUID] { rows.map(\.id) }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SplitLogbookView {
        let view = SplitLogbookView()
        let c = context.coordinator

        // Left table — frozen columns
        view.leftTable.delegate   = c
        view.leftTable.dataSource = c
        for col in frozenColumns {
            view.leftTable.addTableColumn(makeColumn(col))
        }

        // Right table — scrolling columns (initial set)
        view.rightTable.delegate   = c
        view.rightTable.dataSource = c
        for col in columns {
            view.rightTable.addTableColumn(makeColumn(col))
        }

        c.splitView  = view
        c.leftTable  = view.leftTable
        c.rightTable = view.rightTable

        // Restore persisted column widths
        if let prefs = prefs {
            for tc in view.leftTable.tableColumns + view.rightTable.tableColumns {
                if let w = prefs.widths[tc.identifier.rawValue] { tc.width = w }
            }
        }

        // Sync column reorder from NSTableView drag → ColumnPreferences
        NotificationCenter.default.addObserver(
            c,
            selector: #selector(Coordinator.columnMoved(_:)),
            name: NSTableView.columnDidMoveNotification,
            object: view.rightTable
        )

        // Persist column widths when user drags resize handle
        for table in [view.leftTable as NSTableView, view.rightTable] {
            NotificationCenter.default.addObserver(
                c,
                selector: #selector(Coordinator.columnResized(_:)),
                name: NSTableView.columnDidResizeNotification,
                object: table
            )
        }

        // Sync vertical scroll: right drives left
        NotificationCenter.default.addObserver(
            c,
            selector: #selector(Coordinator.rightScrolled(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: view.rightScroll
        )
        NotificationCenter.default.addObserver(
            c,
            selector: #selector(Coordinator.rightScrolled(_:)),
            name: NSView.boundsDidChangeNotification,
            object: view.rightScroll.contentView
        )
        view.rightScroll.contentView.postsBoundsChangedNotifications = true

        // Sync vertical scroll: left drives right
        NotificationCenter.default.addObserver(
            c,
            selector: #selector(Coordinator.leftScrolled(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: view.leftScroll
        )
        NotificationCenter.default.addObserver(
            c,
            selector: #selector(Coordinator.leftScrolled(_:)),
            name: NSView.boundsDidChangeNotification,
            object: view.leftScroll.contentView
        )
        view.leftScroll.contentView.postsBoundsChangedNotifications = true

        return view
    }

    func updateNSView(_ splitView: SplitLogbookView, context: Context) {
        let c = context.coordinator
        c.parent = self

        // Diff right table columns — only add/remove/move what changed
        let existingIDs = splitView.rightTable.tableColumns.map(\.identifier.rawValue)
        let newIDs = columns.map(\.id)
        if existingIDs != newIDs {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            splitView.rightTable.beginUpdates()

            // Remove columns no longer in the visible set
            for tc in splitView.rightTable.tableColumns where !newIDs.contains(tc.identifier.rawValue) {
                splitView.rightTable.removeTableColumn(tc)
            }

            // Add newly visible columns at correct position
            for (idx, col) in columns.enumerated() {
                let currentIDs = splitView.rightTable.tableColumns.map(\.identifier.rawValue)
                if !currentIDs.contains(col.id) {
                    let tc = makeColumn(col)
                    splitView.rightTable.addTableColumn(tc)
                    let insertedAt = splitView.rightTable.tableColumns.count - 1
                    if insertedAt != idx {
                        splitView.rightTable.moveColumn(insertedAt, toColumn: min(idx, splitView.rightTable.tableColumns.count - 1))
                    }
                }
            }

            // Fix ordering if columns were reordered
            let afterIDs = splitView.rightTable.tableColumns.map(\.identifier.rawValue)
            if afterIDs != newIDs {
                for (targetIdx, id) in newIDs.enumerated() {
                    let currentIDs = splitView.rightTable.tableColumns.map(\.identifier.rawValue)
                    if let currentIdx = currentIDs.firstIndex(of: id), currentIdx != targetIdx {
                        splitView.rightTable.moveColumn(currentIdx, toColumn: targetIdx)
                    }
                }
            }

            splitView.rightTable.endUpdates()
            NSAnimationContext.endGrouping()
            splitView.leftTable.reloadData()
            splitView.rightTable.reloadData()
            splitView.needsLayout = true
        }

        let needsReload = rowIDs             != c.lastRowIDs
            || saveVersion       != c.lastSaveVersion
            || hhmm              != c.lastHHMM
            || rounding          != c.lastRounding
            || localTime         != c.lastLocalTime
            || useIATA           != c.lastUseIATA
            || definitionsVersion != c.lastDefinitionsVersion
        if needsReload {
            splitView.leftTable.reloadData()
            splitView.rightTable.reloadData()
            splitView.needsLayout = true
            if c.lastRowIDs.isEmpty && !rowIDs.isEmpty {
                autofitColumns(splitView)
            }
        }
        c.lastRowIDs             = rowIDs
        c.lastSaveVersion        = saveVersion
        c.lastHHMM               = hhmm
        c.lastRounding           = rounding
        c.lastLocalTime          = localTime
        c.lastUseIATA            = useIATA
        c.lastDefinitionsVersion = definitionsVersion

        // Sync selection SwiftUI → tables (cheap, no cell recreation)
        var indexSet = IndexSet()
        for (i, row) in rows.enumerated() {
            if selection.contains(row.id) { indexSet.insert(i) }
        }
        for table in [splitView.leftTable, splitView.rightTable] {
            if table.selectedRowIndexes != indexSet {
                table.selectRowIndexes(indexSet, byExtendingSelection: false)
            }
        }
    }

    private func autofitColumns(_ splitView: SplitLogbookView) {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let sampleRows = Array(rows.prefix(100))
        let padding: CGFloat = 16

        let savedWidths = prefs?.widths ?? [:]
        let allColumns = frozenColumns + columns
        let frozenIDs  = Set(frozenColumns.map(\.id))
        for col in allColumns {
            if savedWidths[col.id] != nil { continue }
            let headerWidth = (col.title as NSString).size(withAttributes: attrs).width + padding
            let maxContentWidth = sampleRows.reduce(headerWidth) { maxW, row in
                let text = col.value(row)
                let w = (text as NSString).size(withAttributes: attrs).width + padding
                return max(maxW, w)
            }
            let targetWidth = max(col.minWidth, headerWidth, min(maxContentWidth, col.idealWidth))
            let isFrozen = frozenIDs.contains(col.id)
            let table = isFrozen ? splitView.leftTable : splitView.rightTable
            if let tc = table.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(col.id)) {
                tc.width = targetWidth
            }
        }
        splitView.needsLayout = true
    }

    private func makeColumn(_ col: LogbookColumn) -> NSTableColumn {
        let tc = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col.id))
        tc.title = col.title
        let headerWidth = (col.title as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]).width + 16
        tc.minWidth = max(col.minWidth, headerWidth)
        tc.maxWidth = max(col.idealWidth, 2000)
        tc.width = col.idealWidth
        tc.resizingMask = .userResizingMask
        tc.headerCell.alignment = col.alignment
        return tc
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: MacLogbookTableView
        weak var splitView: SplitLogbookView?
        weak var leftTable: NSTableView?
        weak var rightTable: NSTableView?

        var lastRowIDs: [UUID] = []
        var lastSaveVersion: Int = 0
        var lastHHMM: Bool = true
        var lastRounding: String = "standard"
        var lastLocalTime: Bool = false
        var lastUseIATA: Bool = true
        var lastDefinitionsVersion: Int = 0
        private var isSyncingScroll = false
        private var isSyncingSelection = false

        init(_ parent: MacLogbookTableView) { self.parent = parent }

        // MARK: Row view — left pane uses square rows to match right pane visually

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            guard row < parent.rows.count else { return nil }
            let accent = parent.rows[row].accent
            if tableView === leftTable {
                let rv = SquareRowView()
                rv.accent = accent
                return rv
            } else {
                let rv = AccentRowView()
                rv.accent = accent
                return rv
            }
        }

        // MARK: Data source

        func numberOfRows(in tableView: NSTableView) -> Int { parent.rows.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let colID = tableColumn?.identifier.rawValue,
                  row < parent.rows.count else { return nil }

            let allColumns = parent.frozenColumns + parent.columns
            guard let col = allColumns.first(where: { $0.id == colID }) else { return nil }

            let flight = parent.rows[row]
            let text = col.value(flight)

            let cellID = NSUserInterfaceItemIdentifier("cell-\(colID)")
            let cell: CentredLabel
            if let reused = tableView.makeView(withIdentifier: cellID, owner: nil) as? CentredLabel {
                cell = reused
            } else {
                cell = CentredLabel(labelWithString: "")
                cell.identifier = cellID
                cell.lineBreakMode = .byTruncatingTail
                cell.cell?.truncatesLastVisibleLine = true
            }

            cell.stringValue = text.isEmpty ? "—" : text
            cell.textColor = text.isEmpty ? .tertiaryLabelColor : .labelColor
            cell.alignment = col.alignment

            cell.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

            return cell
        }

        // MARK: Selection sync

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncingSelection,
                  let tv = notification.object as? NSTableView else { return }
            isSyncingSelection = true
            defer { isSyncingSelection = false }

            let indexes = tv.selectedRowIndexes
            let other: NSTableView? = tv === leftTable ? rightTable : leftTable
            other?.selectRowIndexes(indexes, byExtendingSelection: false)

            let selected = indexes.compactMap { idx -> UUID? in
                guard idx < parent.rows.count else { return nil }
                return parent.rows[idx].id
            }
            let newSet = Set(selected)
            if newSet != parent.selection { parent.selection = newSet }
        }

        // MARK: Vertical scroll sync

        @objc func columnResized(_ notification: Notification) {
            guard let prefs = parent.prefs,
                  let tc = notification.userInfo?["NSTableColumn"] as? NSTableColumn else { return }
            prefs.saveWidth(tc.width, forID: tc.identifier.rawValue)
        }

        @objc func columnMoved(_ notification: Notification) {
            guard let tv = notification.object as? NSTableView,
                  let prefs = parent.prefs else { return }
            // Visible IDs in new drag order
            let visibleOrder = tv.tableColumns.map(\.identifier.rawValue)
            // Rebuild full order: slot hidden columns back into their relative positions
            let hidden = prefs.hidden
            var result: [String] = []
            var visibleIdx = 0
            for id in prefs.order {
                if hidden.contains(id) {
                    result.append(id)
                } else if visibleIdx < visibleOrder.count {
                    result.append(visibleOrder[visibleIdx])
                    visibleIdx += 1
                }
            }
            prefs.order = result
            prefs.persist()
        }

        @objc func rightScrolled(_ notification: Notification) {
            guard !isSyncingScroll,
                  let rightCV = splitView?.rightScroll.contentView,
                  let leftCV  = splitView?.leftScroll.contentView else { return }
            isSyncingScroll = true
            leftCV.scroll(to: NSPoint(x: leftCV.bounds.origin.x, y: rightCV.bounds.origin.y))
            splitView?.leftScroll.reflectScrolledClipView(leftCV)
            isSyncingScroll = false
        }

        @objc func leftScrolled(_ notification: Notification) {
            guard !isSyncingScroll,
                  let rightCV = splitView?.rightScroll.contentView,
                  let leftCV  = splitView?.leftScroll.contentView else { return }
            isSyncingScroll = true
            rightCV.scroll(to: NSPoint(x: rightCV.bounds.origin.x, y: leftCV.bounds.origin.y))
            splitView?.rightScroll.reflectScrolledClipView(rightCV)
            isSyncingScroll = false
        }
    }
}
