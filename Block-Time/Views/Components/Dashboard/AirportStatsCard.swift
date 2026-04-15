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
    let city: String?
    let departures: Int
    let arrivals: Int
    let firstDate: Date?
    let lastDate: Date?

    static let empty = AirportVisitStats(
        icao: "", iata: nil, city: nil, departures: 0, arrivals: 0, firstDate: nil, lastDate: nil
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
            VStack(alignment: .leading, spacing: 3) {
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
                if let city = stats.city {
                    Text(city)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
        // fetchAllFlights uses viewContext — must be called on main thread.
        let flights = FlightDatabaseService.shared.fetchAllFlights()
        let airports = AirportService.shared

        Task.detached(priority: .userInitiated) {
            var depCounts: [String: Int] = [:]
            var arrCounts: [String: Int] = [:]

            for f in flights {
                guard let bt = Double(f.blockTime), bt > 0 else { continue }
                if !f.fromAirport.isEmpty {
                    let icao = airports.convertToICAO(f.fromAirport)
                    depCounts[icao, default: 0] += 1
                }
                if !f.toAirport.isEmpty {
                    let icao = airports.convertToICAO(f.toAirport)
                    arrCounts[icao, default: 0] += 1
                }
            }

            let allICAOs = Set(depCounts.keys).union(arrCounts.keys)
            let counts: [String: Int] = Dictionary(uniqueKeysWithValues: allICAOs.map {
                ($0, max(depCounts[$0, default: 0], arrCounts[$0, default: 0]))
            })
            let sorted = allICAOs.sorted()

            await MainActor.run {
                self.visitCounts = counts
                self.allAirports = sorted

                if !self.selectedICAO.isEmpty {
                    let normalised = airports.convertToICAO(self.selectedICAO)
                    if normalised != self.selectedICAO { self.selectedICAO = normalised }
                }
                if self.selectedICAO.isEmpty, let first = sorted.first {
                    self.selectedICAO = first
                }
            }
        }
    }

    private func loadStats() {
        guard !selectedICAO.isEmpty else { return }
        let apt = selectedICAO
        // fetchAllFlights uses viewContext — must be called on main thread.
        let flights = FlightDatabaseService.shared.fetchAllFlights()
        let airports = AirportService.shared

        Task.detached(priority: .userInitiated) {
            let aptIATA = airports.convertToIATA(apt)
            let fmt: DateFormatter = {
                let f = DateFormatter()
                f.dateFormat = "dd/MM/yyyy"
                return f
            }()

            var deps = 0, arrs = 0
            var firstDate: Date?
            var lastDate: Date?

            for f in flights {
                guard let bt = Double(f.blockTime), bt > 0 else { continue }
                let isDep = f.fromAirport == apt || (aptIATA != nil && f.fromAirport == aptIATA)
                let isArr = f.toAirport   == apt || (aptIATA != nil && f.toAirport   == aptIATA)
                guard isDep || isArr else { continue }
                if isDep { deps += 1 }
                if isArr { arrs += 1 }
                if let d = fmt.date(from: f.date) {
                    if firstDate == nil || d < firstDate! { firstDate = d }
                    if lastDate  == nil || d > lastDate!  { lastDate  = d }
                }
            }

            let newStats = AirportVisitStats(
                icao: apt,
                iata: aptIATA,
                city: airports.getCity(for: apt),
                departures: deps,
                arrivals: arrs,
                firstDate: firstDate,
                lastDate: lastDate
            )

            await MainActor.run {
                self.stampScale = 0.8
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { self.stampScale = 1.0 }
                self.contentOpacity = 0
                withAnimation(.easeIn(duration: 0.15)) { self.contentOpacity = 1 }
                self.stats = newStats
            }
        }
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
    @AppStorage("useIATACodes") private var useIATACodes: Bool = true

    private var sorted: [String] {
        switch sortOrder {
        case .alpha:  return airports.sorted {
            AirportService.shared.getDisplayCode($0, useIATA: useIATACodes) <
            AirportService.shared.getDisplayCode($1, useIATA: useIATACodes)
        }
        case .visits: return airports.sorted { (visitCounts[$0] ?? 0) > (visitCounts[$1] ?? 0) }
        }
    }

    private var filtered: [String] {
        guard !search.isEmpty else { return sorted }
        let q = search.uppercased()
        return sorted.filter { icao in
            if icao.contains(q) { return true }
            if let iata = AirportService.shared.convertToIATA(icao) { return iata.contains(q) }
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
                        Text(AirportService.shared.getDisplayCode(icao, useIATA: useIATACodes))
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
