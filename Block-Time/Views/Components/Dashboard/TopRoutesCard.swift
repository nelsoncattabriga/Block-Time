//
//  TopRoutesCard.swift
//  Block-Time
//
//  Ranked list of most frequently flown routes.
//

import SwiftUI

private enum RoutesPeriod: String, CaseIterable {
    case oneMonth     = "1M"
    case twelveMonths = "12M"
    case all          = "ALL"
}

struct TopRoutesCard: View {
    @AppStorage("topRoutesCard_period") private var period: RoutesPeriod = .oneMonth
    @AppStorage("useIATACodes") private var useIATACodes: Bool = true
    @State private var routes: [NDRouteFrequency] = []
    @State private var isExpanded: Bool = false
    @State private var showSheet: Bool = false

    private static let collapsedCount = 5
    private static let expandedCount  = 10

    private var visibleRoutes: [NDRouteFrequency] {
        if isExpanded { return Array(routes.prefix(Self.expandedCount)) }
        return Array(routes.prefix(Self.collapsedCount))
    }

    private var maxSectors: Double {
        Double(visibleRoutes.map { $0.sectors }.max() ?? 1)
    }

    private var needsExpandButton: Bool { routes.count > Self.collapsedCount }
    private var needsSheetButton:  Bool { isExpanded && routes.count > Self.expandedCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Top Routes", icon: "point.topleft.down.to.point.bottomright.curvepath.fill") {
                Menu {
                    ForEach(RoutesPeriod.allCases, id: \.self) { option in
                        Button(option.rawValue) { period = option }
                    }
                } label: {
                    CardFilterChip(title: period.rawValue)
                }
                .tint(.primary)
            }

            if routes.isEmpty {
                ContentUnavailableView(
                    "No Route Data",
                    systemImage: "map",
                    description: Text("Routes appear once you log flights with departure and arrival airports")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(visibleRoutes.enumerated()), id: \.element.id) { index, route in
                        routeRow(index: index, route: route)
                    }
                }
                .animation(.spring(response: 0.4), value: isExpanded)

                if needsExpandButton {
                    expandButtons
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .task(id: period) { await loadRoutes() }
        .sheet(isPresented: $showSheet) {
            RoutesSheetView(period: period)
        }
    }

    @ViewBuilder
    private var expandButtons: some View {
        HStack(spacing: 16) {
            if isExpanded {
                Button {
                    withAnimation(.spring(response: 0.35)) { isExpanded = false }
                } label: {
                    expandButtonLabel("Show Less", icon: "chevron.up")
                }
                .buttonStyle(.plain)

                if needsSheetButton {
                    Button {
                        showSheet = true
                    } label: {
                        expandButtonLabel("Show All", icon: "arrow.up.right.square")
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.35)) { isExpanded = true }
                } label: {
                    expandButtonLabel("Show More", icon: "chevron.down")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func expandButtonLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .iPadScaledFont(.caption, phoneFont: .footnote)
            Image(systemName: icon)
                .imageScale(.small)
        }
        .foregroundStyle(.secondary)
    }

    @MainActor
    private func loadRoutes() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let now = Date()
        let endDate = formatter.string(from: now)

        let flights: [FlightSector]
        switch period {
        case .all:
            flights = await FlightDatabaseService.shared.fetchAllFlightsAsync()
        case .oneMonth:
            let start = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            flights = await FlightDatabaseService.shared.fetchFlightsAsync(from: formatter.string(from: start), to: endDate)
        case .twelveMonths:
            let start = Calendar.current.date(byAdding: .month, value: -12, to: now)!
            flights = await FlightDatabaseService.shared.fetchFlightsAsync(from: formatter.string(from: start), to: endDate)
        }

        var counts: [String: (from: String, to: String, n: Int)] = [:]
        for f in flights {
            let from = f.fromAirport; let to = f.toAirport
            guard !from.isEmpty, !to.isEmpty else { continue }
            let key = "\(from)-\(to)"
            counts[key] = (from, to, (counts[key]?.n ?? 0) + 1)
        }
        routes = counts.values.sorted { $0.n > $1.n }
            .map { NDRouteFrequency(from: $0.from, to: $0.to, sectors: $0.n) }
    }

    private func displayRoute(_ route: NDRouteFrequency) -> String {
        let from = AirportService.shared.getDisplayCode(route.from, useIATA: useIATACodes)
        let to   = AirportService.shared.getDisplayCode(route.to,   useIATA: useIATACodes)
        return "\(from) → \(to)"
    }

    @ViewBuilder
    private func routeRow(index: Int, route: NDRouteFrequency) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(rankColor(index).opacity(barOpacity(index)).gradient, in: Circle())

            Text(displayRoute(route))
                .font(.system(UIDevice.current.userInterfaceIdiom == .pad ? .body : .footnote, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(rankColor(index).opacity(barOpacity(index)).gradient)
                        .frame(width: geo.size.width * CGFloat(Double(route.sectors) / maxSectors))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: route.sectors)
                }
            }
            .frame(height: 12)
            .frame(minWidth: 60, maxWidth: .infinity)

            Text("\(route.sectors)")
                .iPadScaledFont(.caption, phoneFont: .footnote).fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .indigo
        case 2: return .cyan
        case 3: return .purple
        case 4: return .green
        default: return .blue
        }
    }

    private func barOpacity(_ index: Int) -> Double {
        guard index >= Self.collapsedCount else { return 1.0 }
        let step = index - Self.collapsedCount
        let maxSteps = Self.expandedCount - Self.collapsedCount
        return max(0.35, 1.0 - Double(step) / Double(maxSteps) * 0.65)
    }
}

// MARK: - All-time sheet

private struct RoutesSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useIATACodes") private var useIATACodes: Bool = true
    @State private var period: RoutesPeriod
    @State private var routes: [NDRouteFrequency] = []

    init(period: RoutesPeriod) {
        _period = State(initialValue: period)
    }

    private var maxSectors: Double { Double(routes.map { $0.sectors }.max() ?? 1) }

    private func displayRoute(_ route: NDRouteFrequency) -> String {
        let from = AirportService.shared.getDisplayCode(route.from, useIATA: useIATACodes)
        let to   = AirportService.shared.getDisplayCode(route.to,   useIATA: useIATACodes)
        return "\(from) → \(to)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 4) {
                        Menu {
                            ForEach(RoutesPeriod.allCases, id: \.self) { option in
                                Button(option.rawValue) { period = option }
                            }
                        } label: {
                            CardFilterChip(title: period.rawValue)
                        }
                    }
                    .tint(.primary)

                    VStack(spacing: 8) {
                        ForEach(routes, id: \.id) { route in
                            routeRow(route: route)
                        }
                    }
                    .animation(.spring(response: 0.4), value: routes.count)
                }
                .padding(16)
            }
            .navigationTitle("\(routes.count) Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: period) { await loadAllRoutes() }
    }

    @ViewBuilder
    private func routeRow(route: NDRouteFrequency) -> some View {
        HStack(spacing: 10) {
            Text(displayRoute(route))
                .font(.system(UIDevice.current.userInterfaceIdiom == .pad ? .body : .footnote, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.gradient)
                        .frame(width: geo.size.width * CGFloat(Double(route.sectors) / maxSectors))
                }
            }
            .frame(height: 12)
            .frame(minWidth: 60, maxWidth: .infinity)

            Text("\(route.sectors)")
                .iPadScaledFont(.caption, phoneFont: .footnote).fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func loadAllRoutes() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let now = Date()
        let endDate = formatter.string(from: now)

        let flights: [FlightSector]
        switch period {
        case .all:
            flights = await FlightDatabaseService.shared.fetchAllFlightsAsync()
        case .oneMonth:
            let start = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            flights = await FlightDatabaseService.shared.fetchFlightsAsync(from: formatter.string(from: start), to: endDate)
        case .twelveMonths:
            let start = Calendar.current.date(byAdding: .month, value: -12, to: now)!
            flights = await FlightDatabaseService.shared.fetchFlightsAsync(from: formatter.string(from: start), to: endDate)
        }

        var counts: [String: (from: String, to: String, n: Int)] = [:]
        for f in flights {
            let from = f.fromAirport; let to = f.toAirport
            guard !from.isEmpty, !to.isEmpty else { continue }
            let key = "\(from)-\(to)"
            counts[key] = (from, to, (counts[key]?.n ?? 0) + 1)
        }
        routes = counts.values.sorted { $0.n > $1.n }
            .map { NDRouteFrequency(from: $0.from, to: $0.to, sectors: $0.n) }
    }
}
