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
                    .environment(\.hidePhotoCapture, true)
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

    // MARK: - Legend strip

    private var legendStrip: some View {
        HStack(spacing: 8) {
            Spacer()
            legendPill("PAX",     color: .orange)
            legendPill("SIM",     color: .purple)
            legendPill("Sp/Ins",  color: .red)
            Spacer()
        }
        .padding(.vertical, 5)
        .background(.bar)
    }

    private func legendPill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                color.opacity(0.85),
                in: RoundedRectangle(cornerRadius: 5)
            )
    }

    // MARK: - Spreadsheet

    private var spreadsheet: some View {
        VStack(spacing: 0) {
            legendStrip
            Divider()
            FrozenColumnSpreadsheetView(
                flights: flights,
                highlightedFlightID: highlightedFlight?.id,
                displayConfig: SpreadsheetDisplayConfig(
                    useLocalTime: viewModel.displayFlightsInLocalTime,
                    useIATA:      viewModel.useIATACodes,
                    showHHMM:     viewModel.showTimesInHoursMinutes,
                    roundingMode: viewModel.decimalRoundingMode
                )
            ) { tappedFlight in
                if highlightedFlight?.id == tappedFlight.id {
                    viewModel.loadFlightForEditing(tappedFlight)
                    selectedFlight = tappedFlight
                } else {
                    highlightedFlight = tappedFlight
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Helpers

    private func reload() {
        Task { @MainActor in
            await Task.yield()
            var loaded = initialFlights ?? databaseService.fetchAllFlights()
            let cal = Calendar.current
            let df = DateFormatter()
            df.dateFormat = "dd/MM/yyyy"
            loaded.sort { a, b in
                let dayA = df.date(from: a.date).map { cal.startOfDay(for: $0) }
                let dayB = df.date(from: b.date).map { cal.startOfDay(for: $0) }
                guard let da = dayA, let db = dayB else { return false }
                if da != db { return da > db }
                let ta = a.outTime.isEmpty ? a.scheduledDeparture : a.outTime
                let tb = b.outTime.isEmpty ? b.scheduledDeparture : b.outTime
                if ta.isEmpty && tb.isEmpty {
                    return (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
                }
                guard !ta.isEmpty, !tb.isEmpty else { return !ta.isEmpty }
                let parse: (String) -> Int? = { t in
                    let c = t.replacingOccurrences(of: ":", with: "")
                    guard let n = Int(c), c.count >= 3 else { return nil }
                    return (n / 100) * 60 + (n % 100)
                }
                if let ma = parse(ta), let mb = parse(tb) { return ma > mb }
                return false
            }
            flights = loaded
            isLoading = false
        }
    }
}
