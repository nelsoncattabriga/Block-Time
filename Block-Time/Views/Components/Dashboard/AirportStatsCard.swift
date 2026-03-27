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
    let iata: String?
    let departures: Int
    let arrivals: Int
    let firstDate: Date?
    let lastDate: Date?

    static let empty = AirportVisitStats(
        icao: "", iata: nil, departures: 0, arrivals: 0, firstDate: nil, lastDate: nil
    )

    /// visits = max(dep, arr) — handles asymmetric deadhead/positioning sectors
    var totalVisits: Int { max(departures, arrivals) }

    var displayCode: String {
        if let iata { return "\(icao) / \(iata)" }
        return icao
    }

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var dateRangeString: String? {
        guard let first = firstDate, let last = lastDate else { return nil }
        let from = Self.monthYearFormatter.string(from: first)
        let to   = Self.monthYearFormatter.string(from: last)
        return from == to ? from : "\(from) – \(to)"
    }
}

// MARK: - ICAO ↔ IATA cache (loaded once, process-wide)

private final class AirportCodeCache {
    static let shared = AirportCodeCache()
    private init() {}

    private var icaoToIata: [String: String] = [:]
    private var iataToIcao: [String: String] = [:]
    private var loaded = false

    func iata(for icao: String) -> String? {
        if !loaded { load() }
        return icaoToIata[icao]
    }

    /// Normalise a stored code to ICAO (converts 3-letter IATA → ICAO).
    func toICAO(_ code: String) -> String {
        if !loaded { load() }
        if code.count == 3, let icao = iataToIcao[code] { return icao }
        return code
    }

    /// "YPPH / PER" or just the ICAO if no IATA known.
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
            guard !icao.isEmpty, icao != "\\N", !iata.isEmpty, iata != "\\N" else { continue }
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

    @State private var allAirports: [String] = []          // normalised ICAO codes
    @State private var visitCounts: [String: Int] = [:]    // ICAO → visit count (for picker sort)
    @AppStorage("airportStatsCard_selectedICAO") private var selectedICAO: String = ""
    @State private var stats: AirportVisitStats = .empty
    @State private var showPicker: Bool = false

    @State private var stampScale: CGFloat = 1
    @State private var contentOpacity: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            CardHeader(title: "Airport Stats", icon: "building.columns.fill", iconColor: .teal)

            Spacer().frame(height: 14)

            if selectedICAO.isEmpty {
                emptyState
            } else {
                statsContent
                    .opacity(contentOpacity)
                    .onTapGesture { showPicker = true }
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear {
            buildAirportList()
            loadStats()
        }
        .sheet(isPresented: $showPicker) {
            AirportStatsPickerSheet(
                airports: allAirports,
                visitCounts: visitCounts,
                selected: $selectedICAO
            )
            .presentationDetents([.large])
        }
        .onChange(of: selectedICAO) { loadStats() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No Airport Selected",
            systemImage: "building.columns",
            description: Text("Tap here to choose an airport from your logbook")
        )
        .frame(height: 120)
        .onTapGesture { showPicker = true }
    }

    // MARK: - Stats content

    @ViewBuilder
    private var statsContent: some View {
        heroBanner
    }

    // MARK: - Hero banner

    private var heroBanner: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 5) {
                Text(stats.displayCode)
                    .font(.system(.title2, design: .monospaced, weight: .black))
                    .foregroundStyle(.teal)
                    .scaleEffect(stampScale, anchor: .leading)
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: stampScale)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.teal.opacity(0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(stats.totalVisits)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("visits")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let range = stats.dateRangeString {
                    Text(range)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Data loading

    private func buildAirportList() {
        let cache = AirportCodeCache.shared
        let flights = FlightDatabaseService.shared.fetchAllFlights()

        // Count deps and arrs per normalised ICAO
        var depCounts: [String: Int] = [:]
        var arrCounts: [String: Int] = [:]

        for f in flights {
            if !f.fromAirport.isEmpty {
                let icao = cache.toICAO(f.fromAirport)
                depCounts[icao, default: 0] += 1
            }
            if !f.toAirport.isEmpty {
                let icao = cache.toICAO(f.toAirport)
                arrCounts[icao, default: 0] += 1
            }
        }

        // visits = max(dep, arr) per airport
        let allICAOs = Set(depCounts.keys).union(arrCounts.keys)
        var counts: [String: Int] = [:]
        for icao in allICAOs {
            counts[icao] = max(depCounts[icao, default: 0], arrCounts[icao, default: 0])
        }

        visitCounts = counts
        allAirports = allICAOs.sorted()

        // Normalise any persisted IATA code
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
        let aptIATA = AirportCodeCache.shared.iata(for: apt)
        let flights = FlightDatabaseService.shared.fetchAllFlights()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        var deps = 0, arrs = 0
        var firstDate: Date? = nil
        var lastDate: Date?  = nil

        for f in flights {
            let from = f.fromAirport
            let to   = f.toAirport
            let isDep = from == apt || (aptIATA != nil && from == aptIATA)
            let isArr = to   == apt || (aptIATA != nil && to   == aptIATA)
            guard isDep || isArr else { continue }
            if isDep { deps += 1 }
            if isArr { arrs += 1 }
            if let d = dateFormatter.date(from: f.date) {
                if firstDate == nil || d < firstDate! { firstDate = d }
                if lastDate  == nil || d > lastDate!  { lastDate  = d }
            }
        }

        let newStats = AirportVisitStats(
            icao: apt,
            iata: AirportCodeCache.shared.iata(for: apt),
            departures: deps,
            arrivals: arrs,
            firstDate: firstDate,
            lastDate: lastDate
        )

        stampScale = 0.8
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { stampScale = 1.0 }
        contentOpacity = 0
        withAnimation(.easeIn(duration: 0.15)) { contentOpacity = 1 }

        stats = newStats
    }
}

// MARK: - Picker sheet

private enum AirportSortOrder: String {
    case alpha    = "ABC"
    case visits   = "123"
}

private struct AirportStatsPickerSheet: View {
    let airports: [String]              // normalised ICAO codes
    let visitCounts: [String: Int]      // ICAO → visit count
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    @State private var search: String = ""
    @State private var sortOrder: AirportSortOrder = .alpha

    private var sorted: [String] {
        switch sortOrder {
        case .alpha:  return airports.sorted()
        case .visits: return airports.sorted { (visitCounts[$0] ?? 0) > (visitCounts[$1] ?? 0) }
        }
    }

    private var filtered: [String] {
        guard !search.isEmpty else { return sorted }
        let q = search.uppercased()
        return sorted.filter { icao in
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
                        if sortOrder == .visits, let count = visitCounts[icao] {
                            Text("\(count)")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        if icao == selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.teal)
                                .fontWeight(.semibold)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search ICAO or IATA…")
            .navigationTitle("Select Airport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Picker("Sort", selection: $sortOrder) {
                        Text("ABC").tag(AirportSortOrder.alpha)
                        Text("123").tag(AirportSortOrder.visits)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
