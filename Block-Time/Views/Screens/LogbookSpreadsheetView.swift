//
//  LogbookSpreadsheetView.swift
//  Block-Time
//

import SwiftUI

struct LogbookSpreadsheetView: View {
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @Environment(\.dismiss) private var dismiss

    /// Pre-filtered flights passed from the caller. If nil, all flights are fetched.
    let initialFlights: [FlightSector]?

    init(flights: [FlightSector]? = nil) {
        self.initialFlights = flights
    }

    private let databaseService = FlightDatabaseService.shared

    @State private var flights: [FlightSector] = []
    @State private var highlightedFlight: FlightSector?  // tapped but not yet editing
    @State private var selectedFlight: FlightSector?     // pushed to AddFlightView
    @State private var isLoading = true
    @State private var showingDiscardAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if flights.isEmpty {
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "tablecells",
                        description: Text("No logbook entries found.")
                    )
                } else {
                    spreadsheet
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(initialFlights != nil ? "Logbook Data (Filtered)" : "Logbook Data")
                            .font(.headline)
                        Text("\(flights.count) \(flights.count == 1 ? "entry" : "entries")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .allowsHitTesting(false)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let flight = highlightedFlight {
                        Button("Edit") {
                            viewModel.loadFlightForEditing(flight)
                            selectedFlight = flight
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .navigationDestination(item: $selectedFlight) { _ in
                AddFlightView()
                    .environmentObject(viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                if viewModel.hasUnsavedChanges {
                                    showingDiscardAlert = true
                                } else {
                                    selectedFlight = nil
                                    viewModel.exitEditingMode()
                                }
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    .alert("Save Changes?", isPresented: $showingDiscardAlert) {
                        Button("Save") {
                            if viewModel.updateExistingFlight() {
                                selectedFlight = nil
                                viewModel.exitEditingMode()
                            }
                        }
                        Button("Discard", role: .destructive) {
                            selectedFlight = nil
                            viewModel.exitEditingMode()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text(viewModel.changesSummary)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
                        selectedFlight = nil
                        reload()
                    }
                    .onDisappear {
                        selectedFlight = nil
                        reload()
                    }
            }
        }
        .task {
            reload()
        }
    }

    // MARK: - Spreadsheet
    //
    // Single ScrollView([.horizontal, .vertical]). The column header row is a
    // pinned LazyVStack section header — sticks to the top on vertical scroll
    // and tracks horizontal scroll with the data rows automatically.

    private var spreadsheet: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(Array(flights.enumerated()), id: \.element.id) { index, flight in
                        Button {
                            if highlightedFlight?.id == flight.id {
                                // Second tap on same row — go straight to edit
                                viewModel.loadFlightForEditing(flight)
                                selectedFlight = flight
                            } else {
                                highlightedFlight = flight
                            }
                        } label: {
                            dataRow(flight: flight, index: index, highlighted: highlightedFlight?.id == flight.id)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                } header: {
                    VStack(spacing: 0) {
                        columnHeaderRow
                        columnFooterRow
                    }
                }
            }
        }
    }

    // MARK: - Column header row (pinned)

    private var columnHeaderRow: some View {
        HStack(spacing: 0) {
            headerCell("Date",            width: Layout.colDate)
            headerCell("Flt No",          width: Layout.colFlight)
            headerCell("Reg",         width: Layout.colReg)
            headerCell("Type",   width: Layout.colType)
            headerCell("From",            width: Layout.colAirport)
            headerCell("To",              width: Layout.colAirport)
            headerCell("STD",             width: Layout.colSTD)
            headerCell("STA",             width: Layout.colSTA)
            headerCell("OUT",             width: Layout.colOUT)
            headerCell("IN",              width: Layout.colIN)
            headerCell("Block Time",      width: Layout.colBlock)
            headerCell("Night Time",      width: Layout.colNight)
            headerCell("Captain",    width: Layout.colCrew)
            headerCell("F/O",        width: Layout.colCrew)
            headerCell("S/O1",       width: Layout.colCrew)
            headerCell("S/O2",       width: Layout.colCrew)
            headerCell("P1 Time",         width: Layout.colP1)
            headerCell("P1US Time",       width: Layout.colP1US)
            headerCell("P2 Time",         width: Layout.colP2)
            headerCell("Instrument",      width: Layout.colInstr)
            headerCell("SIM Time",        width: Layout.colSIM)
            headerCell("Sp/Ins Time",     width: Layout.colSpIns)
            headerCell("PAX",             width: Layout.colPAX)
            headerCell("Pilot Flying",    width: Layout.colPF)
            headerCell("AIII",            width: Layout.colAIII)
            headerCell("RNP",             width: Layout.colRNP)
            headerCell("ILS",             width: Layout.colILS)
            headerCell("GLS",             width: Layout.colGLS)
            headerCell("NPA",             width: Layout.colNPA)
            headerCell("Day T/O",         width: Layout.colDayTO)
            headerCell("Day Ldg",         width: Layout.colDayLdg)
            headerCell("Night T/O",       width: Layout.colNightTO)
            headerCell("Night Ldg",       width: Layout.colNightLdg)
            headerCell("Custom Count",    width: Layout.colCustom)
            headerCell("Remarks",         width: Layout.colRemarks)
        }
        .frame(height: Layout.headerHeight)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Column footer row (pinned)

    private var columnFooterRow: some View {
        HStack(spacing: 0) {
            totalLabelCell("Totals -->",           width: Layout.colDate)
            emptyFooterCell(                   width: Layout.colFlight)
            emptyFooterCell(                   width: Layout.colReg)
            emptyFooterCell(                   width: Layout.colType)
            emptyFooterCell(                   width: Layout.colAirport)
            emptyFooterCell(                   width: Layout.colAirport)
            emptyFooterCell(                   width: Layout.colSTD)
            emptyFooterCell(                   width: Layout.colSTA)
            emptyFooterCell(                   width: Layout.colOUT)
            emptyFooterCell(                   width: Layout.colIN)
            totalTimeCell(sumTime(\.blockTime),      width: Layout.colBlock)
            totalTimeCell(sumTime(\.nightTime),      width: Layout.colNight)
            emptyFooterCell(                   width: Layout.colCrew)
            emptyFooterCell(                   width: Layout.colCrew)
            emptyFooterCell(                   width: Layout.colCrew)
            emptyFooterCell(                   width: Layout.colCrew)
            totalTimeCell(sumTime(\.p1Time),         width: Layout.colP1)
            totalTimeCell(sumTime(\.p1usTime),       width: Layout.colP1US)
            totalTimeCell(sumTime(\.p2Time),         width: Layout.colP2)
            totalTimeCell(sumTime(\.instrumentTime), width: Layout.colInstr)
            totalTimeCell(sumTime(\.simTime),        width: Layout.colSIM)
            totalTimeCell(sumTime(\.spInsTime),      width: Layout.colSpIns)
            emptyFooterCell(                   width: Layout.colPAX)
            emptyFooterCell(                   width: Layout.colPF)
            emptyFooterCell(                   width: Layout.colAIII)
            emptyFooterCell(                   width: Layout.colRNP)
            emptyFooterCell(                   width: Layout.colILS)
            emptyFooterCell(                   width: Layout.colGLS)
            emptyFooterCell(                   width: Layout.colNPA)
            totalCountCell(sumInt(\.dayTakeoffs),   width: Layout.colDayTO)
            totalCountCell(sumInt(\.dayLandings),   width: Layout.colDayLdg)
            totalCountCell(sumInt(\.nightTakeoffs), width: Layout.colNightTO)
            totalCountCell(sumInt(\.nightLandings), width: Layout.colNightLdg)
            totalCountCell(sumInt(\.customCount),   width: Layout.colCustom)
            emptyFooterCell(                   width: Layout.colRemarks)
        }
        .frame(height: Layout.headerHeight)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.15)).frame(height: 0.5)
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Data row

    private func dataRow(flight: FlightSector, index: Int, highlighted: Bool = false) -> some View {
        let useLocal = viewModel.displayFlightsInLocalTime
        let useIATA  = viewModel.useIATACodes
        let hhmm     = viewModel.showTimesInHoursMinutes
        let rounding = viewModel.decimalRoundingMode
        return HStack(spacing: 0) {
            dataCell(flight.getDisplayDate(useLocalTime: useLocal),                                           width: Layout.colDate,     mono: true)
            dataCell(flight.flightNumber,                                                                     width: Layout.colFlight,   mono: true)
            dataCell(flight.aircraftReg,                                                                      width: Layout.colReg,      mono: true)
            dataCell(flight.aircraftType,                                                                     width: Layout.colType)
            dataCell(AirportService.shared.getDisplayCode(flight.fromAirport, useIATA: useIATA),              width: Layout.colAirport,  mono: true)
            dataCell(AirportService.shared.getDisplayCode(flight.toAirport,   useIATA: useIATA),              width: Layout.colAirport,  mono: true)
            dataCell(flight.getSTD(useLocalTime: useLocal),                                                   width: Layout.colSTD,      mono: true)
            dataCell(flight.getSTA(useLocalTime: useLocal),                                                   width: Layout.colSTA,      mono: true)
            dataCell(flight.getOutTime(useLocalTime: useLocal),                                               width: Layout.colOUT,      mono: true)
            dataCell(flight.getInTime(useLocalTime: useLocal),                                                width: Layout.colIN,       mono: true)
            dataCell(timeValue(flight.getFormattedBlockTime(asHoursMinutes: hhmm, roundingMode: rounding)),    width: Layout.colBlock,    mono: true, bold: true)
            dataCell(timeValue(flight.getFormattedNightTime(asHoursMinutes: hhmm, roundingMode: rounding)),   width: Layout.colNight,    mono: true)
            dataCell(flight.captainName,                                                                      width: Layout.colCrew)
            dataCell(flight.foName,                                                                           width: Layout.colCrew)
            dataCell(flight.so1Name ?? "",                                                                    width: Layout.colCrew)
            dataCell(flight.so2Name ?? "",                                                                    width: Layout.colCrew)
            dataCell(timeValue(FlightSector.formatTime(flight.p1TimeValue,         asHoursMinutes: hhmm)),    width: Layout.colP1,       mono: true)
            dataCell(timeValue(FlightSector.formatTime(flight.p1usTimeValue,       asHoursMinutes: hhmm)),    width: Layout.colP1US,     mono: true)
            dataCell(timeValue(FlightSector.formatTime(flight.p2TimeValue,         asHoursMinutes: hhmm)),    width: Layout.colP2,       mono: true)
            dataCell(timeValue(FlightSector.formatTime(flight.instrumentTimeValue, asHoursMinutes: hhmm)),    width: Layout.colInstr,    mono: true)
            dataCell(timeValue(flight.getFormattedSimTime(asHoursMinutes: hhmm)),                              width: Layout.colSIM,      mono: true)
            dataCell(timeValue(flight.getFormattedSpInsTime(asHoursMinutes: hhmm)),                            width: Layout.colSpIns,    mono: true)
            flagCell(flight.isPositioning,                     width: Layout.colPAX)
            flagCell(flight.isPilotFlying,                     width: Layout.colPF)
            flagCell(flight.isAIII,                            width: Layout.colAIII)
            flagCell(flight.isRNP,                             width: Layout.colRNP)
            flagCell(flight.isILS,                             width: Layout.colILS)
            flagCell(flight.isGLS,                             width: Layout.colGLS)
            flagCell(flight.isNPA,                             width: Layout.colNPA)
            dataCell(countString(flight.dayTakeoffs),          width: Layout.colDayTO,    mono: true)
            dataCell(countString(flight.dayLandings),          width: Layout.colDayLdg,   mono: true)
            dataCell(countString(flight.nightTakeoffs),        width: Layout.colNightTO,  mono: true)
            dataCell(countString(flight.nightLandings),        width: Layout.colNightLdg, mono: true)
            dataCell(flight.customCount > 0 ? String(flight.customCount) : "", width: Layout.colCustom, mono: true)
            dataCell(flight.remarks,                           width: Layout.colRemarks)
        }
        .frame(height: Layout.rowHeight)
        .background(highlighted ? Color.accentColor.opacity(0.3) : rowBackground(index: index))
        .contentShape(Rectangle())
    }

    // MARK: - Layout constants
    //
    // Each width is sized to fit its header label at .caption semibold + 12pt horizontal
    // padding, with a minimum wide enough for typical data values.

    private enum Layout {
        static let headerHeight: CGFloat = 36
        static let rowHeight: CGFloat    = 44
        static let colDate: CGFloat      = 92   // "Date" — data is "dd/MM/yyyy" (10 chars)
        static let colFlight: CGFloat    = 72   // "Flt No"
        static let colReg: CGFloat       = 72   // "A/C Reg"
        static let colType: CGFloat      = 72  // "Aircraft Type"
        static let colAirport: CGFloat   = 52   // "From" / "To"
        static let colCrew: CGFloat      = 120  // "Captain Name" / "F/O Name" — header drives width; data truncates
        static let colSTD: CGFloat       = 52   // "STD"
        static let colSTA: CGFloat       = 52   // "STA"
        static let colOUT: CGFloat       = 52   // "OUT"
        static let colIN: CGFloat        = 52   // "IN"
        static let colBlock: CGFloat     = 84   // "Block Time"
        static let colNight: CGFloat     = 84   // "Night Time"
        static let colP1: CGFloat        = 84   // "P1 Time"
        static let colP1US: CGFloat      = 84   // "P1US Time"
        static let colP2: CGFloat        = 84   // "P2 Time"
        static let colInstr: CGFloat     = 84  // "Instrument"
        static let colSIM: CGFloat       = 76   // "SIM Time"
        static let colSpIns: CGFloat     = 84   // "Sp/Ins Time"
        static let colPAX: CGFloat       = 48   // "PAX"
        static let colPF: CGFloat        = 84   // "Pilot Flying"
        static let colAIII: CGFloat      = 48   // "AIII"
        static let colRNP: CGFloat       = 44   // "RNP"
        static let colILS: CGFloat       = 40   // "ILS"
        static let colGLS: CGFloat       = 44   // "GLS"
        static let colNPA: CGFloat       = 44   // "NPA"
        static let colDayTO: CGFloat     = 68   // "Day T/O"
        static let colDayLdg: CGFloat    = 68   // "Day Ldg"
        static let colNightTO: CGFloat   = 76   // "Night T/O"
        static let colNightLdg: CGFloat  = 76   // "Night Ldg"
        static let colCustom: CGFloat    = 100  // "Custom Count"
        static let colRemarks: CGFloat   = 500  // "Remarks"
    }

    // MARK: - Cell builders

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.25)).frame(width: 0.5)
            }
    }

    private func flagCell(_ value: Bool, width: CGFloat) -> some View {
        Text(value ? "1" : "")
            .font(.caption.monospacedDigit())
            .foregroundStyle(value ? .primary : .tertiary)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: .center)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.25)).frame(width: 0.5)
            }
    }

    private func dataCell(_ value: String, width: CGFloat, mono: Bool = false, bold: Bool = false) -> some View {
        let display = isBlankValue(value) ? "" : value
        let baseFont: Font = mono ? .caption.monospacedDigit() : .caption
        return Text(display)
            .font(bold ? baseFont.weight(.semibold) : baseFont)
            .foregroundStyle(display.isEmpty ? .tertiary : .primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.25)).frame(width: 0.5)
            }
    }

    // MARK: - Footer cell builders

    private func totalLabelCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.25)).frame(width: 0.5)
            }
    }

    private func emptyFooterCell(width: CGFloat) -> some View {
        Color.clear
            .frame(width: width)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.25)).frame(width: 0.5)
            }
    }

    private func totalTimeCell(_ value: String, width: CGFloat) -> some View {
        Text(value.isEmpty ? "" : value)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(value.isEmpty ? .tertiary : .primary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.25)).frame(width: 0.5)
            }
    }

    private func totalCountCell(_ value: Int, width: CGFloat) -> some View {
        Text(value == 0 ? "" : String(value))
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(value == 0 ? .tertiary : .primary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.25)).frame(width: 0.5)
            }
    }

    // MARK: - Totals computation

    private func sumTime(_ keyPath: KeyPath<FlightSector, String>) -> String {
        let total = flights.reduce(0.0) { $0 + (Double($1[keyPath: keyPath]) ?? 0.0) }
        guard total > 0 else { return "" }
        if viewModel.showTimesInHoursMinutes {
            return FlightSector.decimalToHHMM(total)
        }
        return String(format: "%.1f", total)
    }

    private func sumInt(_ keyPath: KeyPath<FlightSector, Int>) -> Int {
        flights.reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    // MARK: - Helpers

    private func rowBackground(index: Int) -> Color {
        index.isMultiple(of: 2) ? Color(.systemBackground) : Color(.secondarySystemBackground)
    }

    private func timeValue(_ value: String) -> String {
        value.replacingOccurrences(of: " hrs", with: "")
    }

    private func isBlankValue(_ value: String) -> Bool {
        value.isEmpty || value == "0.00" || value == "0.0" || value == "0" || value == "0:00"
    }

    private func countString(_ value: Int) -> String {
        value == 0 ? "" : String(value)
    }

    private func reload() {
        Task { @MainActor in
            // Yield so the ProgressView renders before the fetch blocks the main thread
            await Task.yield()
            flights = initialFlights ?? databaseService.fetchAllFlights()
            isLoading = false
        }
    }
}
