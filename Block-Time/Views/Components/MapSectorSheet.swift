//
//  MapSectorSheet.swift
//  Block-Time
//

import SwiftUI
import CoreData

struct MapSectorSheet: View {
    let airport: FlightMapViewModel.AirportPin
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useIATACodes") private var useIATACodes: Bool = false
    @State private var sectors: [FlightSector] = []
    @State private var showingFlights = false
    @State private var cachedDateRange: String? = nil
    @State private var selectedDetent: PresentationDetent = .fraction(0.42)

    private static let storedDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f
    }()
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f
    }()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header area
            VStack(spacing: 0) {
                // Done button row
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }

                statsCard
                    .padding(.horizontal, 16)

                if !sectors.isEmpty {
                    flightsToggle
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, showingFlights ? 0 : 16)
                }
            }

            // Scrollable flights list (only visible when expanded)
            if showingFlights {
                ScrollView {
                    flightsList
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.fraction(0.42), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onChange(of: showingFlights) { _, showing in
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedDetent = showing ? .large : .fraction(0.42)
            }
        }
        .onAppear { loadSectors() }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        HStack(alignment: .center) {
            // Left — airport code + city
            VStack(alignment: .leading, spacing: 3) {
                Text(airportDisplayTitle)
                    .font(.system(.title2, design: .monospaced, weight: .black))
                    .foregroundStyle(.teal)
                if let city = AirportService.shared.getCity(for: airport.icao) {
                    Text(city)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Right — visit count + date range
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(sectors.count)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(sectors.count == 1 ? "visit" : "visits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let range = cachedDateRange {
                    Text(range)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Flights toggle

    private var flightsToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { showingFlights.toggle() }
        } label: {
            HStack {
                Text(showingFlights ? "Hide Flights" : "Show Flights")
                    .fontWeight(.medium)
                Spacer()
                Text("\(sectors.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showingFlights ? 90 : 0))
                    .animation(.easeInOut(duration: 0.25), value: showingFlights)
            }
            .foregroundStyle(.primary)
            .padding(showingFlights ? EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
                                    : EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Flights list

    private var flightsList: some View {
        LazyVStack(spacing: 1) {
            ForEach(Array(sectors.enumerated()), id: \.element.id) { index, sector in
                MapFlightRow(
                    sector: sector,
                    useIATACodes: useIATACodes,
                    isFirst: index == 0,
                    isLast: index == sectors.count - 1
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var airportDisplayTitle: String {
        if let iata = AirportService.shared.convertToIATA(airport.icao) {
            return "\(airport.icao) / \(iata)"
        }
        return airport.icao
    }

    private func loadSectors() {
        let icao = airport.icao
        let iata = AirportService.shared.convertToIATA(icao) ?? icao
        let context = FlightDatabaseService.shared.viewContext
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "toAirport ==[c] %@ OR toAirport ==[c] %@",
            icao, iata
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)]
        guard let results = try? context.fetch(request) else { return }
        let loaded = results
            .compactMap { FlightSector.from(entity: $0) }
            .filter { $0.blockTimeValue > 0 }

        let dates = loaded.compactMap { Self.storedDateFormatter.date(from: $0.date) }
        if let first = dates.min(), let last = dates.max() {
            let from = Self.monthYearFormatter.string(from: first)
            let to   = Self.monthYearFormatter.string(from: last)
            cachedDateRange = from == to ? from : "\(from) – \(to)"
        }

        sectors = loaded
    }
}

// MARK: - Compact flight row for map context

private struct MapFlightRow: View {
    let sector: FlightSector
    let useIATACodes: Bool
    let isFirst: Bool
    let isLast: Bool

    private static let storedFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f
    }()
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd MMM yyyy"; return f
    }()

    private var displayDate: String {
        guard let d = Self.storedFormatter.date(from: sector.date) else { return sector.date }
        return Self.displayFormatter.string(from: d)
    }

    private var fromCode: String {
        AirportService.shared.getDisplayCode(sector.fromAirport, useIATA: useIATACodes)
    }
    private var toCode: String {
        AirportService.shared.getDisplayCode(sector.toAirport, useIATA: useIATACodes)
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius:     isFirst ? 12 : 0,
            bottomLeadingRadius:  isLast  ? 12 : 0,
            bottomTrailingRadius: isLast  ? 12 : 0,
            topTrailingRadius:    isFirst ? 12 : 0
        )
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // Compact single-line layout (normal Dynamic Type sizes)
            HStack(spacing: 8) {
                Text(displayDate)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                
                Spacer()
                
                Text(sector.flightNumberFormatted)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .fixedSize()
                HStack(spacing: 3) {
                    Text(fromCode)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(toCode)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                }
                .fixedSize()
                Spacer()
//                Text(sector.aircraftReg)
//                    .font(.system(.footnote, design: .monospaced))
//                    .foregroundStyle(.secondary)
//                    .fixedSize()
                Text(sector.aircraftType)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            // Stacked two-line fallback (large Accessibility sizes)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayDate)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(sector.flightNumberFormatted)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    HStack(spacing: 3) {
                        Text(fromCode)
                            .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(toCode)
                            .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    }
                }
                HStack(spacing: 6) {
//                    Text(sector.aircraftReg)
//                        .font(.system(.footnote, design: .monospaced))
//                        .foregroundStyle(.secondary)
                    Text(sector.aircraftType)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemGroupedBackground), in: shape)
    }
}
