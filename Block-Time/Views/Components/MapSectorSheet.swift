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
    @State private var cachedDepartures: Int = 0
    @State private var cachedArrivals: Int = 0
    @State private var cachedDateRange: String? = nil

    private var totalVisits: Int { max(cachedDepartures, cachedArrivals) }

    private static let storedDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f
    }()
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f
    }()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    statsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if !sectors.isEmpty {
                        flightsToggle
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        if showingFlights {
                            flightsList
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(AirportService.shared.getCity(for: airport.icao) ?? airport.id)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { loadSectors() }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Airport + city
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
            .padding(.bottom, 14)

            Divider()
                .padding(.bottom, 14)

            // Visits + dep/arr
            HStack(alignment: .center) {
                // Left — visit count
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(totalVisits)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text(totalVisits == 1 ? "visit" : "visits")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let range = cachedDateRange {
                        Text(range)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Right — dep/arr pills
                VStack(alignment: .trailing, spacing: 6) {
                    statPill(icon: "airplane.departure", value: cachedDepartures, label: "dep")
                    statPill(icon: "airplane.arrival",   value: cachedArrivals,   label: "arr")
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statPill(icon: String, value: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(value) \(label)")
                .font(.subheadline)
                .monospacedDigit()
        }
    }

    // MARK: - Flights toggle

    private var flightsToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showingFlights.toggle() }
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
                    .animation(.easeInOut(duration: 0.2), value: showingFlights)
            }
            .foregroundStyle(.primary)
            .padding(14)
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
            format: "fromAirport ==[c] %@ OR fromAirport ==[c] %@ OR toAirport ==[c] %@ OR toAirport ==[c] %@",
            icao, iata, icao, iata
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)]
        guard let results = try? context.fetch(request) else { return }
        let loaded = results
            .compactMap { FlightSector.from(entity: $0) }
            .filter { $0.blockTimeValue > 0 }

        // Cache derived stats so they aren't recomputed on every render
        cachedDepartures = loaded.filter { AirportService.shared.convertToICAO($0.fromAirport) == icao }.count
        cachedArrivals   = loaded.filter { AirportService.shared.convertToICAO($0.toAirport)   == icao }.count

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
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f
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
        HStack(spacing: 8) {
            // Date
            Text(displayDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize()

            // Flight number
            Text(sector.flightNumberFormatted)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .fixedSize()

            // Sector
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

            // Rego
            Text(sector.aircraftReg)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize()

            // Type
            Text(sector.aircraftType)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemGroupedBackground), in: shape)
    }
}
