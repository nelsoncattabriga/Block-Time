//
//  LogbookSpreadsheetView.swift
//  Block-Time
//

import SwiftUI

struct LogbookSpreadsheetView: View {
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @Environment(\.dismiss) private var dismiss

    private let databaseService = FlightDatabaseService.shared

    @State private var flights: [FlightSector] = []
    @State private var selectedFlight: FlightSector?
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
            .navigationTitle("Raw Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(flights.count) entries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                            viewModel.loadFlightForEditing(flight)
                            selectedFlight = flight
                        } label: {
                            dataRow(flight: flight, index: index)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                } header: {
                    columnHeaderRow
                }
            }
        }
    }

    // MARK: - Column header row (pinned)

    private var columnHeaderRow: some View {
        HStack(spacing: 0) {
            headerCell("Date",            width: Layout.colDate)
            headerCell("Flight Number",   width: Layout.colFlight)
            headerCell("Aircraft Reg",    width: Layout.colReg)
            headerCell("Aircraft Type",   width: Layout.colType)
            headerCell("From Airport",    width: Layout.colAirport)
            headerCell("To Airport",      width: Layout.colAirport)
            headerCell("Captain Name",    width: Layout.colCrew)
            headerCell("F/O Name",        width: Layout.colCrew)
            headerCell("S/O1 Name",       width: Layout.colCrew)
            headerCell("S/O2 Name",       width: Layout.colCrew)
            headerCell("STD",             width: Layout.colSTD)
            headerCell("STA",             width: Layout.colSTA)
            headerCell("OUT Time",        width: Layout.colOUT)
            headerCell("IN Time",         width: Layout.colIN)
            headerCell("Block Time",      width: Layout.colBlock)
            headerCell("Night Time",      width: Layout.colNight)
            headerCell("P1 Time",         width: Layout.colP1)
            headerCell("P1US Time",       width: Layout.colP1US)
            headerCell("P2 Time",         width: Layout.colP2)
            headerCell("Instrument Time", width: Layout.colInstr)
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

    // MARK: - Data row

    private func dataRow(flight: FlightSector, index: Int) -> some View {
        HStack(spacing: 0) {
            dataCell(flight.date,                              width: Layout.colDate,     mono: true)
            dataCell(flight.flightNumber,                      width: Layout.colFlight,   mono: true)
            dataCell(flight.aircraftReg,                       width: Layout.colReg,      mono: true)
            dataCell(flight.aircraftType,                      width: Layout.colType)
            dataCell(flight.fromAirport,                       width: Layout.colAirport,  mono: true)
            dataCell(flight.toAirport,                         width: Layout.colAirport,  mono: true)
            dataCell(flight.captainName,                       width: Layout.colCrew)
            dataCell(flight.foName,                            width: Layout.colCrew)
            dataCell(flight.so1Name ?? "",                     width: Layout.colCrew)
            dataCell(flight.so2Name ?? "",                     width: Layout.colCrew)
            dataCell(flight.scheduledDeparture,                width: Layout.colSTD,      mono: true)
            dataCell(flight.scheduledArrival,                  width: Layout.colSTA,      mono: true)
            dataCell(flight.outTime,                           width: Layout.colOUT,      mono: true)
            dataCell(flight.inTime,                            width: Layout.colIN,       mono: true)
            dataCell(flight.blockTime,                         width: Layout.colBlock,    mono: true)
            dataCell(flight.nightTime,                         width: Layout.colNight,    mono: true)
            dataCell(flight.p1Time,                            width: Layout.colP1,       mono: true)
            dataCell(flight.p1usTime,                          width: Layout.colP1US,     mono: true)
            dataCell(flight.p2Time,                            width: Layout.colP2,       mono: true)
            dataCell(flight.instrumentTime,                    width: Layout.colInstr,    mono: true)
            dataCell(flight.simTime,                           width: Layout.colSIM,      mono: true)
            dataCell(flight.spInsTime,                         width: Layout.colSpIns,    mono: true)
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
        .background(rowBackground(index: index))
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
        static let colFlight: CGFloat    = 110  // "Flight Number"
        static let colReg: CGFloat       = 100  // "Aircraft Reg"
        static let colType: CGFloat      = 100  // "Aircraft Type"
        static let colAirport: CGFloat   = 96   // "From Airport" / "To Airport"
        static let colCrew: CGFloat      = 120  // "Captain Name" / "F/O Name" — header drives width; data truncates
        static let colSTD: CGFloat       = 52   // "STD"
        static let colSTA: CGFloat       = 52   // "STA"
        static let colOUT: CGFloat       = 76   // "OUT Time"
        static let colIN: CGFloat        = 68   // "IN Time"
        static let colBlock: CGFloat     = 84   // "Block Time"
        static let colNight: CGFloat     = 84   // "Night Time"
        static let colP1: CGFloat        = 68   // "P1 Time"
        static let colP1US: CGFloat      = 76   // "P1US Time"
        static let colP2: CGFloat        = 68   // "P2 Time"
        static let colInstr: CGFloat     = 112  // "Instrument Time"
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
        static let colRemarks: CGFloat   = 750  // "Remarks"
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
                Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 0.5)
            }
    }

    private func flagCell(_ value: Bool, width: CGFloat) -> some View {
        Text(value ? "1" : "")
            .font(.caption.monospacedDigit())
            .foregroundStyle(value ? .primary : .tertiary)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: .center)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 0.5)
            }
    }

    private func dataCell(_ value: String, width: CGFloat, mono: Bool = false) -> some View {
        let display = isBlankValue(value) ? "" : value
        return Text(display)
            .font(mono ? .caption.monospacedDigit() : .caption)
            .foregroundStyle(display.isEmpty ? .tertiary : .primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 0.5)
            }
    }

    // MARK: - Helpers

    private func rowBackground(index: Int) -> Color {
        index.isMultiple(of: 2) ? Color(.systemBackground) : Color(.secondarySystemBackground)
    }

    private func isBlankValue(_ value: String) -> Bool {
        value.isEmpty || value == "0.00" || value == "0.0" || value == "0"
    }

    private func countString(_ value: Int) -> String {
        value == 0 ? "" : String(value)
    }

    private func reload() {
        flights = databaseService.fetchAllFlights()
        isLoading = false
    }
}
