//
//  MacLogbookView.swift
//  Block-Time-Mac
//
//  Spreadsheet-style logbook table using SwiftUI Table.
//

import SwiftUI

struct MacLogbookView: View {
    @State private var viewModel = MacLogbookViewModel()
    @Binding var selection: Set<UUID>

    var body: some View {
        VStack(spacing: 0) {
            tableContent
            footerBar
        }
        .task { await viewModel.load() }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search flights…")
        .toolbar { tableToolbar }
    }

    // MARK: - Table

    private var tableContent: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading logbook…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredFlights.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty ? "No Flights" : "No Results",
                    systemImage: "book.closed",
                    description: Text(viewModel.searchText.isEmpty
                        ? "Flights sync automatically from your iPhone."
                        : "Try a different search term.")
                )
            } else {
                Table(viewModel.filteredFlights, selection: $selection, sortOrder: $viewModel.sortOrder) {
                    identityColumns()
                    routeColumns()
                    timeColumns()
                    aircraftColumns()
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Column Groups

    @TableColumnBuilder<MacFlightRow, KeyPathComparator<MacFlightRow>>
    private func identityColumns() -> some TableColumnContent<MacFlightRow, KeyPathComparator<MacFlightRow>> {
        TableColumn("Date", value: \.rawDate) { row in
            Text(row.dateDisplay)
                .font(.system(size: 12))
                .italic(row.isPositioning)
        }
        .width(min: 80, ideal: 88)

        TableColumn("Flight", value: \.flightNumber) { row in
            MonoCell(row.flightNumber, italic: row.isPositioning)
        }
        .width(min: 56, ideal: 68)
    }

    @TableColumnBuilder<MacFlightRow, KeyPathComparator<MacFlightRow>>
    private func routeColumns() -> some TableColumnContent<MacFlightRow, KeyPathComparator<MacFlightRow>> {
        TableColumn("DEP", value: \.fromAirport) { row in MonoCell(row.fromAirport) }
            .width(min: 40, ideal: 48)
        TableColumn("ARR", value: \.toAirport) { row in MonoCell(row.toAirport) }
            .width(min: 40, ideal: 48)
        TableColumn("OUT", value: \.outTime) { row in MonoCell(row.outTime) }
            .width(min: 44, ideal: 52)
        TableColumn("IN", value: \.inTime) { row in MonoCell(row.inTime) }
            .width(min: 44, ideal: 52)
    }

    @TableColumnBuilder<MacFlightRow, KeyPathComparator<MacFlightRow>>
    private func timeColumns() -> some TableColumnContent<MacFlightRow, KeyPathComparator<MacFlightRow>> {
        TableColumn("Block", value: \.blockTime) { row in TimeCell(row.blockDisplay) }
            .width(min: 48, ideal: 56)
        TableColumn("Night", value: \.nightTime) { row in TimeCell(row.nightDisplay) }
            .width(min: 48, ideal: 56)
        TableColumn("P1", value: \.p1Time) { row in TimeCell(row.p1Display) }
            .width(min: 44, ideal: 52)
        TableColumn("P1s", value: \.p1usTime) { row in TimeCell(row.p1usDisplay) }
            .width(min: 44, ideal: 52)
        TableColumn("P2", value: \.p2Time) { row in TimeCell(row.p2Display) }
            .width(min: 44, ideal: 52)
        TableColumn("Sim", value: \.simTime) { row in TimeCell(row.simDisplay) }
            .width(min: 44, ideal: 52)
    }

    @TableColumnBuilder<MacFlightRow, KeyPathComparator<MacFlightRow>>
    private func aircraftColumns() -> some TableColumnContent<MacFlightRow, KeyPathComparator<MacFlightRow>> {
        TableColumn("Type", value: \.aircraftType) { row in MonoCell(row.aircraftType) }
            .width(min: 52, ideal: 64)
        TableColumn("Reg", value: \.aircraftReg) { row in MonoCell(row.aircraftReg) }
            .width(min: 64, ideal: 76)
        TableColumn("T/O") { row in
            TakeoffLandingCell(day: row.dayTakeoffs, night: row.nightTakeoffs)
        }
        .width(min: 36, ideal: 44)
        TableColumn("Ldg") { row in
            TakeoffLandingCell(day: row.dayLandings, night: row.nightLandings)
        }
        .width(min: 36, ideal: 44)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 16) {
            Text("\(viewModel.filteredFlights.count) entries")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            if !selection.isEmpty {
                Text("Selected: \(selection.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let totalBlock = MacFlightRow.hhmmDisplay(viewModel.totalBlockHours)
            Text("Total Block: \(totalBlock)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var tableToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                NotificationCenter.default.post(name: .macNewFlight, object: nil)
            } label: {
                Label("New Flight", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task { await viewModel.reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}

// MARK: - Cell Views

private struct MonoCell: View {
    let text: String
    var italic: Bool = false

    init(_ text: String, italic: Bool = false) {
        self.text = text
        self.italic = italic
    }

    var body: some View {
        Text(text.isEmpty ? "—" : text)
            .font(.system(size: 12, design: .monospaced))
            .italic(italic)
            .foregroundStyle(text.isEmpty ? .tertiary : .primary)
            .lineLimit(1)
    }
}

private struct TimeCell: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.isEmpty ? "—" : text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(text.isEmpty ? .tertiary : .primary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .lineLimit(1)
    }
}

private struct TakeoffLandingCell: View {
    let day: Int
    let night: Int

    var body: some View {
        HStack(spacing: 2) {
            if day > 0 || night > 0 {
                Text("\(day + night)")
                    .font(.system(size: 12, design: .monospaced))
                if night > 0 {
                    Text("N")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
