//
//  MacLogbookTableView.swift
//  Block-Time-Mac
//
//  Split-table logbook: frozen left pane (Date + Flight) + scrollable right pane.
//  Both panes share one Coordinator for data, selection, and vertical scroll sync.
//  Column order is defined by LogbookColumn — user reordering can be persisted later.
//

import AppKit
import SwiftUI

// MARK: - Square Row View (removes inset-style rounded corners on frozen pane)

private final class SquareRowView: NSTableRowView {
    override func drawBackground(in dirtyRect: NSRect) {
        guard let table = superview as? NSTableView else { return }
        let idx = table.row(for: self)
        NSColor.alternatingContentBackgroundColors[idx % 2].setFill()
        dirtyRect.fill()
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

    static let frozenColumns: [LogbookColumn] = [
        LogbookColumn(id: "date",    title: "Date",   minWidth: 72, idealWidth: 84, value: { $0.dateDisplay }),
        LogbookColumn(id: "flight",  title: "Flight", minWidth: 52, idealWidth: 68, value: { $0.flightNumber }, alignment: .center),
    ]

    static let scrollingColumns: [LogbookColumn] = [
        LogbookColumn(id: "dep",     title: "DEP",     minWidth: 36,  idealWidth: 44,  value: { $0.fromAirport },        alignment: .center),
        LogbookColumn(id: "arr",     title: "ARR",     minWidth: 36,  idealWidth: 44,  value: { $0.toAirport },          alignment: .center),
        LogbookColumn(id: "std",     title: "STD",     minWidth: 40,  idealWidth: 48,  value: { $0.scheduledDeparture }, alignment: .center),
        LogbookColumn(id: "sta",     title: "STA",     minWidth: 40,  idealWidth: 48,  value: { $0.scheduledArrival },   alignment: .center),
        LogbookColumn(id: "out",     title: "OUT",     minWidth: 40,  idealWidth: 48,  value: { $0.outTime },            alignment: .center),
        LogbookColumn(id: "in",      title: "IN",      minWidth: 40,  idealWidth: 48,  value: { $0.inTime },             alignment: .center),
        LogbookColumn(id: "block",   title: "Block",   minWidth: 44,  idealWidth: 52,  value: { $0.blockDisplay },       alignment: .right),
        LogbookColumn(id: "night",   title: "Night",   minWidth: 44,  idealWidth: 52,  value: { $0.nightDisplay },       alignment: .right),
        LogbookColumn(id: "instr",   title: "Instr",   minWidth: 44,  idealWidth: 52,  value: { $0.instrumentDisplay },  alignment: .right),
        LogbookColumn(id: "captain", title: "Captain", minWidth: 80,  idealWidth: 100, value: { $0.captainName }),
        LogbookColumn(id: "fo",      title: "FO",      minWidth: 80,  idealWidth: 100, value: { $0.foName }),
        LogbookColumn(id: "so1",     title: "SO1",     minWidth: 80,  idealWidth: 100, value: { $0.so1Name }),
        LogbookColumn(id: "so2",     title: "SO2",     minWidth: 80,  idealWidth: 100, value: { $0.so2Name }),
        LogbookColumn(id: "p1",      title: "P1",      minWidth: 40,  idealWidth: 48,  value: { $0.p1Display },          alignment: .right),
        LogbookColumn(id: "p1s",     title: "P1s",     minWidth: 40,  idealWidth: 48,  value: { $0.p1usDisplay },        alignment: .right),
        LogbookColumn(id: "p2",      title: "P2",      minWidth: 40,  idealWidth: 48,  value: { $0.p2Display },          alignment: .right),
        LogbookColumn(id: "sim",     title: "Sim",     minWidth: 40,  idealWidth: 48,  value: { $0.simDisplay },         alignment: .right),
        LogbookColumn(id: "spins",   title: "SpIns",   minWidth: 44,  idealWidth: 52,  value: { $0.spInsDisplay },       alignment: .right),
        LogbookColumn(id: "type",    title: "Type",    minWidth: 48,  idealWidth: 60,  value: { $0.aircraftType },       alignment: .center),
        LogbookColumn(id: "reg",     title: "Reg",     minWidth: 60,  idealWidth: 76,  value: { $0.aircraftReg },        alignment: .center),
        LogbookColumn(id: "tod",     title: "T/O D",   minWidth: 36,  idealWidth: 42,  value: { $0.dayTakeoffs   > 0 ? "\($0.dayTakeoffs)"   : "" }, alignment: .center),
        LogbookColumn(id: "ton",     title: "T/O N",   minWidth: 36,  idealWidth: 42,  value: { $0.nightTakeoffs > 0 ? "\($0.nightTakeoffs)" : "" }, alignment: .center),
        LogbookColumn(id: "ldgd",    title: "Ldg D",   minWidth: 36,  idealWidth: 42,  value: { $0.dayLandings   > 0 ? "\($0.dayLandings)"   : "" }, alignment: .center),
        LogbookColumn(id: "ldgn",    title: "Ldg N",   minWidth: 36,  idealWidth: 42,  value: { $0.nightLandings > 0 ? "\($0.nightLandings)" : "" }, alignment: .center),
        LogbookColumn(id: "pf",      title: "PF",      minWidth: 28,  idealWidth: 32,  value: { $0.isPilotFlying  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "pax",     title: "PAX",     minWidth: 28,  idealWidth: 32,  value: { $0.isPositioning  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "ils",     title: "ILS",     minWidth: 28,  idealWidth: 32,  value: { $0.isILS  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "gls",     title: "GLS",     minWidth: 28,  idealWidth: 32,  value: { $0.isGLS  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "npa",     title: "NPA",     minWidth: 28,  idealWidth: 32,  value: { $0.isNPA  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "rnp",     title: "RNP",     minWidth: 28,  idealWidth: 32,  value: { $0.isRNP  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "aiii",    title: "AIII",    minWidth: 28,  idealWidth: 36,  value: { $0.isAIII ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "custom",  title: "Custom",  minWidth: 44,  idealWidth: 52,  value: { $0.customCount > 0 ? "\($0.customCount)" : "" }, alignment: .center),
        LogbookColumn(id: "remarks", title: "Remarks", minWidth: 120, idealWidth: 200, value: { $0.remarks }),
    ]
}

// MARK: - Container NSView

/// Hosts the frozen left table and scrollable right table side by side.
final class SplitLogbookView: NSView {
    let leftScroll  = NSScrollView()
    let rightScroll = NSScrollView()
    let leftTable   = NSTableView()
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
    }

    private func setupScroll(_ scroll: NSScrollView, table: NSTableView, hasHorizontal: Bool) {
        scroll.documentView = table
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = hasHorizontal
        scroll.autohidesScrollers = false
        scroll.borderType = .noBorder
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 20
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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SplitLogbookView {
        let view = SplitLogbookView()
        let c = context.coordinator

        // Left table — frozen columns
        view.leftTable.delegate   = c
        view.leftTable.dataSource = c
        for col in LogbookColumn.frozenColumns {
            view.leftTable.addTableColumn(makeColumn(col))
        }

        // Right table — scrolling columns
        view.rightTable.delegate   = c
        view.rightTable.dataSource = c
        for col in LogbookColumn.scrollingColumns {
            view.rightTable.addTableColumn(makeColumn(col))
        }

        c.splitView  = view
        c.leftTable  = view.leftTable
        c.rightTable = view.rightTable

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
        context.coordinator.parent = self
        splitView.leftTable.reloadData()
        splitView.rightTable.reloadData()
        splitView.needsLayout = true

        // Sync selection SwiftUI → tables
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

    private func makeColumn(_ col: LogbookColumn) -> NSTableColumn {
        let tc = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col.id))
        tc.title = col.title
        tc.minWidth = col.minWidth
        tc.width = col.idealWidth
        tc.resizingMask = .userResizingMask
        return tc
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: MacLogbookTableView
        weak var splitView: SplitLogbookView?
        weak var leftTable: NSTableView?
        weak var rightTable: NSTableView?

        private var isSyncingScroll = false
        private var isSyncingSelection = false

        init(_ parent: MacLogbookTableView) { self.parent = parent }

        // MARK: Row view — left pane uses square rows to match right pane visually

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            tableView === leftTable ? SquareRowView() : nil
        }

        // MARK: Data source

        func numberOfRows(in tableView: NSTableView) -> Int { parent.rows.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let colID = tableColumn?.identifier.rawValue,
                  row < parent.rows.count else { return nil }

            let allColumns = LogbookColumn.frozenColumns + LogbookColumn.scrollingColumns
            guard let col = allColumns.first(where: { $0.id == colID }) else { return nil }

            let flight = parent.rows[row]
            let text = col.value(flight)

            let cellID = NSUserInterfaceItemIdentifier("cell-\(colID)")
            let cell: NSTextField
            if let reused = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTextField {
                cell = reused
            } else {
                cell = NSTextField(labelWithString: "")
                cell.identifier = cellID
                cell.lineBreakMode = .byTruncatingTail
                cell.cell?.truncatesLastVisibleLine = true
            }

            cell.stringValue = text.isEmpty ? "—" : text
            cell.textColor = text.isEmpty ? .tertiaryLabelColor : .labelColor
            cell.alignment = col.alignment

            let baseFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            if flight.isPositioning && (colID == "date" || colID == "flight") {
                cell.font = NSFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.italic), size: 12) ?? baseFont
            } else {
                cell.font = baseFont
            }

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
