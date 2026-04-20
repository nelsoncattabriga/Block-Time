//
//  MacLogbookTableView.swift
//  Block-Time-Mac
//
//  NSTableView-based logbook grid with no column-count limit.
//  Column order is defined by LogbookColumn.defaultOrder — user reordering
//  can be persisted later by saving/restoring that array.
//

import AppKit
import SwiftUI

// MARK: - Column Definition

struct LogbookColumn: Identifiable {
    let id: String          // stable identifier for persistence
    let title: String
    let minWidth: CGFloat
    let idealWidth: CGFloat
    let value: (MacFlightRow) -> String
    var alignment: NSTextAlignment = .left

    static let defaultOrder: [LogbookColumn] = [
        LogbookColumn(id: "date",       title: "Date",    minWidth: 72,  idealWidth: 84,  value: { $0.dateDisplay }),
        LogbookColumn(id: "flight",     title: "Flight",  minWidth: 52,  idealWidth: 68,  value: { $0.flightNumber }, alignment: .center),
        LogbookColumn(id: "dep",        title: "DEP",     minWidth: 36,  idealWidth: 44,  value: { $0.fromAirport },  alignment: .center),
        LogbookColumn(id: "arr",        title: "ARR",     minWidth: 36,  idealWidth: 44,  value: { $0.toAirport },    alignment: .center),
        LogbookColumn(id: "std",        title: "STD",     minWidth: 40,  idealWidth: 48,  value: { $0.scheduledDeparture }, alignment: .center),
        LogbookColumn(id: "sta",        title: "STA",     minWidth: 40,  idealWidth: 48,  value: { $0.scheduledArrival },   alignment: .center),
        LogbookColumn(id: "out",        title: "OUT",     minWidth: 40,  idealWidth: 48,  value: { $0.outTime },      alignment: .center),
        LogbookColumn(id: "in",         title: "IN",      minWidth: 40,  idealWidth: 48,  value: { $0.inTime },       alignment: .center),
        LogbookColumn(id: "block",      title: "Block",   minWidth: 44,  idealWidth: 52,  value: { $0.blockDisplay },      alignment: .right),
        LogbookColumn(id: "night",      title: "Night",   minWidth: 44,  idealWidth: 52,  value: { $0.nightDisplay },      alignment: .right),
        LogbookColumn(id: "instr",      title: "Instr",   minWidth: 44,  idealWidth: 52,  value: { $0.instrumentDisplay }, alignment: .right),
        LogbookColumn(id: "captain",    title: "Captain", minWidth: 80,  idealWidth: 100, value: { $0.captainName }),
        LogbookColumn(id: "fo",         title: "FO",      minWidth: 80,  idealWidth: 100, value: { $0.foName }),
        LogbookColumn(id: "so1",        title: "SO1",     minWidth: 80,  idealWidth: 100, value: { $0.so1Name }),
        LogbookColumn(id: "so2",        title: "SO2",     minWidth: 80,  idealWidth: 100, value: { $0.so2Name }),
        LogbookColumn(id: "p1",         title: "P1",      minWidth: 40,  idealWidth: 48,  value: { $0.p1Display },    alignment: .right),
        LogbookColumn(id: "p1s",        title: "P1s",     minWidth: 40,  idealWidth: 48,  value: { $0.p1usDisplay },  alignment: .right),
        LogbookColumn(id: "p2",         title: "P2",      minWidth: 40,  idealWidth: 48,  value: { $0.p2Display },    alignment: .right),
        LogbookColumn(id: "sim",        title: "Sim",     minWidth: 40,  idealWidth: 48,  value: { $0.simDisplay },   alignment: .right),
        LogbookColumn(id: "spins",      title: "SpIns",   minWidth: 44,  idealWidth: 52,  value: { $0.spInsDisplay }, alignment: .right),
        LogbookColumn(id: "type",       title: "Type",    minWidth: 48,  idealWidth: 60,  value: { $0.aircraftType }, alignment: .center),
        LogbookColumn(id: "reg",        title: "Reg",     minWidth: 60,  idealWidth: 76,  value: { $0.aircraftReg },  alignment: .center),
        LogbookColumn(id: "tod",        title: "T/O D",   minWidth: 36,  idealWidth: 42,  value: { $0.dayTakeoffs   > 0 ? "\($0.dayTakeoffs)"   : "" }, alignment: .center),
        LogbookColumn(id: "ton",        title: "T/O N",   minWidth: 36,  idealWidth: 42,  value: { $0.nightTakeoffs > 0 ? "\($0.nightTakeoffs)" : "" }, alignment: .center),
        LogbookColumn(id: "ldgd",       title: "Ldg D",   minWidth: 36,  idealWidth: 42,  value: { $0.dayLandings   > 0 ? "\($0.dayLandings)"   : "" }, alignment: .center),
        LogbookColumn(id: "ldgn",       title: "Ldg N",   minWidth: 36,  idealWidth: 42,  value: { $0.nightLandings > 0 ? "\($0.nightLandings)" : "" }, alignment: .center),
        LogbookColumn(id: "pf",         title: "PF",      minWidth: 28,  idealWidth: 32,  value: { $0.isPilotFlying  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "pax",        title: "PAX",     minWidth: 28,  idealWidth: 32,  value: { $0.isPositioning  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "ils",        title: "ILS",     minWidth: 28,  idealWidth: 32,  value: { $0.isILS  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "gls",        title: "GLS",     minWidth: 28,  idealWidth: 32,  value: { $0.isGLS  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "npa",        title: "NPA",     minWidth: 28,  idealWidth: 32,  value: { $0.isNPA  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "rnp",        title: "RNP",     minWidth: 28,  idealWidth: 32,  value: { $0.isRNP  ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "aiii",       title: "AIII",    minWidth: 28,  idealWidth: 36,  value: { $0.isAIII ? "✓" : "" }, alignment: .center),
        LogbookColumn(id: "custom",     title: "Custom",  minWidth: 44,  idealWidth: 52,  value: { $0.customCount > 0 ? "\($0.customCount)" : "" }, alignment: .center),
        LogbookColumn(id: "remarks",    title: "Remarks", minWidth: 120, idealWidth: 200, value: { $0.remarks }),
    ]
}

// MARK: - NSViewRepresentable

struct MacLogbookTableView: NSViewRepresentable {
    let rows: [MacFlightRow]
    @Binding var selection: Set<UUID>
    var columns: [LogbookColumn] = LogbookColumn.defaultOrder

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 20
        tableView.allowsMultipleSelection = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.frozenColumns = 2
        tableView.style = .inset
        tableView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        for col in columns {
            let tc = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col.id))
            tc.title = col.title
            tc.minWidth = col.minWidth
            tc.width = col.idealWidth
            tc.resizingMask = .userResizingMask
            tableView.addTableColumn(tc)
        }

        context.coordinator.tableView = tableView

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = false
        scroll.borderType = .noBorder
        tableView.headerView = NSTableHeaderView()
        tableView.headerView?.frame.size.height = 22

        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        context.coordinator.parent = self

        // Sync column list if it changed
        let existingIDs = tableView.tableColumns.map(\.identifier.rawValue)
        let newIDs = columns.map(\.id)
        if existingIDs != newIDs {
            for col in tableView.tableColumns { tableView.removeTableColumn(col) }
            for col in columns {
                let tc = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col.id))
                tc.title = col.title
                tc.minWidth = col.minWidth
                tc.width = col.idealWidth
                tc.resizingMask = .userResizingMask
                tableView.addTableColumn(tc)
            }
        }

        tableView.reloadData()

        // Sync selection from SwiftUI → NSTableView
        var indexSet = IndexSet()
        for (i, row) in rows.enumerated() {
            if selection.contains(row.id) { indexSet.insert(i) }
        }
        if tableView.selectedRowIndexes != indexSet {
            tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: MacLogbookTableView
        weak var tableView: NSTableView?

        init(_ parent: MacLogbookTableView) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.rows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let colID = tableColumn?.identifier.rawValue,
                  let col = parent.columns.first(where: { $0.id == colID }),
                  row < parent.rows.count else { return nil }

            let flight = parent.rows[row]
            let text = col.value(flight)

            let cellID = NSUserInterfaceItemIdentifier("cell-\(colID)")
            let cell: NSTextField
            if let reused = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTextField {
                cell = reused
            } else {
                cell = NSTextField(labelWithString: "")
                cell.identifier = cellID
                cell.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                cell.lineBreakMode = .byTruncatingTail
                cell.cell?.truncatesLastVisibleLine = true
            }

            cell.stringValue = text.isEmpty ? "—" : text
            cell.textColor = text.isEmpty ? .tertiaryLabelColor : .labelColor
            cell.alignment = col.alignment

            // Italicise positioning flights in the date/flight columns
            if flight.isPositioning && (colID == "date" || colID == "flight") {
                cell.font = NSFont(descriptor: NSFontDescriptor.preferredFontDescriptor(
                    forTextStyle: .body, options: [:])
                    .withSymbolicTraits(.italic)
                    .withSize(12), size: 12)
                    ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
            } else {
                cell.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            }

            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTableView else { return }
            let selected = tv.selectedRowIndexes.compactMap { idx -> UUID? in
                guard idx < parent.rows.count else { return nil }
                return parent.rows[idx].id
            }
            let newSet = Set(selected)
            if newSet != parent.selection {
                parent.selection = newSet
            }
        }
    }
}
