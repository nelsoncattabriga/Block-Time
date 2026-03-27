//
//  AirportStatsCard.swift
//  Block-Time
//
//  Airport Stats — visit count, dep/arr split, and top aircraft for any
//  airport in the logbook. Airport codes displayed as ICAO / IATA.
//

import SwiftUI

// MARK: - Data model

private struct AirportVisitStats {
    let icao: String
    let iata: String?             // nil if unknown
    let totalVisits: Int
    let departures: Int
    let arrivals: Int
    let topReg: (reg: String, count: Int)?  // single top registration

    static let empty = AirportVisitStats(
        icao: "", iata: nil, totalVisits: 0, departures: 0, arrivals: 0, topReg: nil
    )

    /// Display string: "YPPH / PER" or just "YPPH"
    var displayCode: String {
        if let iata { return "\(icao) / \(iata)" }
        return icao
    }
}

// MARK: - ICAO → IATA lookup (loaded once, shared across instances)

private final class AirportCodeCache {
    static let shared = AirportCodeCache()
    private init() {}

    /// Maps ICAO → IATA (e.g. "YPPH" → "PER")
    private var icaoToIata: [String: String] = [:]
    /// Maps IATA → ICAO (e.g. "PER" → "YPPH") for normalising logbook codes
    private var iataToIcao: [String: String] = [:]
    private var loaded = false

    func iata(for icao: String) -> String? {
        if !loaded { load() }
        return icaoToIata[icao]
    }

    /// Normalise any stored code to ICAO.
    /// If the logbook stored an IATA code (e.g. "BNE"), returns the ICAO ("YBBN").
    /// If already ICAO or unknown, returns the code unchanged.
    func toICAO(_ code: String) -> String {
        if !loaded { load() }
        // 3-letter codes are IATA; look up the ICAO equivalent
        if code.count == 3, let icao = iataToIcao[code] { return icao }
        return code
    }

    /// Build a display string: "YPPH / PER" or just the raw code if unknown.
    func displayString(for icao: String) -> String {
        if !loaded { load() }
        if let iata = icaoToIata[icao] { return "\(icao) / \(iata)" }
        return icao
    }

    private func load() {
        loaded = true
        guard let url = Bundle.main.url(forResource: "airports.dat", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        for line in content.components(separatedBy: .newlines) where !line.isEmpty {
            let fields = parseCSV(line)
            guard fields.count >= 14 else { continue }
            let iata = fields[4].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let icao = fields[5].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard !icao.isEmpty, icao != "\\N",
                  !iata.isEmpty, iata != "\\N" else { continue }
            icaoToIata[icao] = iata
            iataToIcao[iata] = icao
        }
    }

    private func parseCSV(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle() }
            else if ch == "," && !inQuotes { fields.append(current); current = "" }
            else { current.append(ch) }
        }
        fields.append(current)
        return fields
    }
}

// MARK: - Card

struct AirportStatsCard: View {

    @State private var allAirports: [String] = []   // ICAO codes from logbook
    @AppStorage("airportStatsCard_selectedICAO") private var selectedICAO: String = ""
    @State private var stats: AirportVisitStats = .empty
    @State private var showPicker: Bool = false

    @State private var stampScale: CGFloat = 1
    @State private var contentOpacity: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            CardHeader(title: "Airport Stats", icon: "building.columns.fill", iconColor: .teal) {
                airportPickerButton
            }

            Spacer().frame(height: 14)

            if selectedICAO.isEmpty {
                emptyState
            } else {
                statsContent
                    .opacity(contentOpacity)
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { buildAirportList() }
        .sheet(isPresented: $showPicker) {
            AirportStatsPickerSheet(airports: allAirports, selected: $selectedICAO)
                .presentationDetents([.large])
        }
        .onChange(of: selectedICAO) { loadStats() }
    }

    // MARK: - Picker button

    private var airportPickerButton: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 5) {
                Text(selectedICAO.isEmpty
                     ? "Select…"
                     : AirportCodeCache.shared.displayString(for: selectedICAO))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(selectedICAO.isEmpty ? Color.secondary : Color.teal)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.teal.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.teal.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No Airport Selected",
            systemImage: "building.columns",
            description: Text("Tap \"Select…\" above to choose an airport from your logbook")
        )
        .frame(height: 120)
    }

    // MARK: - Stats content

    @ViewBuilder
    private var statsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroBanner

            if let topReg = stats.topReg {
                Rectangle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(height: 1)
                topRegRow(topReg)
            }
        }
    }

    // MARK: - Hero banner

    private var heroBanner: some View {
        HStack(alignment: .center, spacing: 0) {

            // ICAO / IATA stamp
            VStack(alignment: .leading, spacing: 2) {
                Text(stats.displayCode)
                    .font(.system(.title2, design: .monospaced, weight: .black))
                    .foregroundStyle(.teal)
                    .scaleEffect(stampScale, anchor: .leading)
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: stampScale)

                Text("ICAO / IATA")
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }

            Spacer()

            // Visits + DEP / ARR
            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(stats.totalVisits)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("visits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    statPill(label: "DEP", value: stats.departures, color: .blue)
                    statPill(label: "ARR", value: stats.arrivals,   color: .green)
                }
            }
        }
    }

    private func statPill(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.1)))
    }

    // MARK: - Top registration (single)

    private func topRegRow(_ topReg: (reg: String, count: Int)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tag.fill")
                .font(.caption2).foregroundStyle(.secondary)
            Text("Top Aircraft")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            Spacer()
            Text(topReg.reg)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.teal)
            Text("· \(topReg.count) sectors")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data loading

    private func buildAirportList() {
        let cache = AirportCodeCache.shared
        let flights = FlightDatabaseService.shared.fetchAllFlights()
        var seen = Set<String>()
        for f in flights {
            if !f.fromAirport.isEmpty { seen.insert(cache.toICAO(f.fromAirport)) }
            if !f.toAirport.isEmpty   { seen.insert(cache.toICAO(f.toAirport))   }
        }
        allAirports = seen.sorted()
        // If the persisted value is an IATA code, normalise it once
        if !selectedICAO.isEmpty {
            let normalised = cache.toICAO(selectedICAO)
            if normalised != selectedICAO { selectedICAO = normalised }
        }
        if selectedICAO.isEmpty, let first = allAirports.first {
            selectedICAO = first
        }
    }

    private func loadStats() {
        guard !selectedICAO.isEmpty else { return }
        let apt = selectedICAO
        // Also match the IATA equivalent in case some flights were stored that way
        let aptIATA = AirportCodeCache.shared.iata(for: apt)
        let flights = FlightDatabaseService.shared.fetchAllFlights()

        var deps = 0, arrs = 0
        var regCounts: [String: Int] = [:]

        for f in flights {
            let from = f.fromAirport
            let to   = f.toAirport
            let isDep = from == apt || (aptIATA != nil && from == aptIATA)
            let isArr = to   == apt || (aptIATA != nil && to   == aptIATA)
            guard isDep || isArr else { continue }
            if isDep { deps += 1 }
            if isArr { arrs += 1 }
            let reg = f.aircraftReg
            if !reg.isEmpty { regCounts[reg, default: 0] += 1 }
        }

        let topReg = regCounts.sorted { $0.value > $1.value }.first
            .map { (reg: $0.key, count: $0.value) }

        let iata = AirportCodeCache.shared.iata(for: apt)

        let newStats = AirportVisitStats(
            icao: apt,
            iata: iata,
            totalVisits: deps + arrs,
            departures: deps,
            arrivals: arrs,
            topReg: topReg
        )

        stampScale = 0.8
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { stampScale = 1.0 }
        contentOpacity = 0
        withAnimation(.easeIn(duration: 0.15)) { contentOpacity = 1 }

        stats = newStats
    }
}

// MARK: - Picker sheet

private struct AirportStatsPickerSheet: View {
    let airports: [String]      // ICAO codes
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""

    private var filtered: [String] {
        guard !search.isEmpty else { return airports }
        let q = search.uppercased()
        return airports.filter { icao in
            if icao.contains(q) { return true }
            if let iata = AirportCodeCache.shared.iata(for: icao) { return iata.contains(q) }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { icao in
                Button {
                    selected = icao
                    dismiss()
                } label: {
                    HStack {
                        Text(AirportCodeCache.shared.displayString(for: icao))
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        if icao == selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.teal)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search ICAO or IATA…")
            .navigationTitle("Select Airport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
