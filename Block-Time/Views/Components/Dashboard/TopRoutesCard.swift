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
    @State private var period: RoutesPeriod = .oneMonth
    @State private var routes: [NDRouteFrequency] = []

    private var maxSectors: Double { Double(routes.map { $0.sectors }.max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Top 5 Routes", icon: "point.topleft.down.to.point.bottomright.curvepath.fill") {
                Picker("Period", selection: $period) {
                    ForEach(RoutesPeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
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
                    ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                        routeRow(index: index, route: route)
                    }
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { loadRoutes() }
        .onChange(of: period) { loadRoutes() }
    }

    private func loadRoutes() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let now = Date()
        let endDate = formatter.string(from: now)

        let flights: [FlightSector]
        switch period {
        case .all:
            flights = FlightDatabaseService.shared.fetchAllFlights()
        case .oneMonth:
            let start = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            flights = FlightDatabaseService.shared.fetchFlights(from: formatter.string(from: start), to: endDate)
        case .twelveMonths:
            let start = Calendar.current.date(byAdding: .month, value: -12, to: now)!
            flights = FlightDatabaseService.shared.fetchFlights(from: formatter.string(from: start), to: endDate)
        }

        var counts: [String: (from: String, to: String, n: Int)] = [:]
        for f in flights {
            let from = f.fromAirport; let to = f.toAirport
            guard !from.isEmpty, !to.isEmpty else { continue }
            let key = "\(from)-\(to)"
            counts[key] = (from, to, (counts[key]?.n ?? 0) + 1)
        }
        routes = counts.values.sorted { $0.n > $1.n }.prefix(5)
            .map { NDRouteFrequency(from: $0.from, to: $0.to, sectors: $0.n) }
    }

    @ViewBuilder
    private func routeRow(index: Int, route: NDRouteFrequency) -> some View {
        HStack(spacing: 10) {
            // Rank badge
            Text("\(index + 1)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(rankColor(index).gradient, in: Circle())

            // Route label
            Text(route.routeString)
                .iPadScaledFont(.caption).fontWeight(.semibold)
                .foregroundStyle(.primary)

            // Bar + count
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(rankColor(index).gradient)
                        .frame(width: geo.size.width * CGFloat(Double(route.sectors) / maxSectors))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: route.sectors)
                }
            }
            .frame(height: 12)
            .frame(minWidth: 60, maxWidth: .infinity )

            Text("\(route.sectors)")
                .iPadScaledFont(.caption).fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .indigo
        case 2: return .green
        default: return .blue
        }
    }
}
