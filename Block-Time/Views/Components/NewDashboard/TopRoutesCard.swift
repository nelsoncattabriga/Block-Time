//
//  TopRoutesCard.swift
//  Block-Time
//
//  Ranked list of most frequently flown routes.
//

import SwiftUI

struct TopRoutesCard: View {
    let routes: [NDRouteFrequency]

    private var maxSectors: Double { Double(routes.map { $0.sectors }.max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Top Routes", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                .font(.headline).fontWeight(.bold)
                .foregroundStyle(.secondary)

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
    }

    @ViewBuilder
    private func routeRow(index: Int, route: NDRouteFrequency) -> some View {
        HStack(spacing: 10) {
            // Rank badge
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(rankColor(index).gradient, in: Circle())

            // Route label
            Text(route.routeString)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

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
            .frame(width: 80, height: 12)

            Text("\(route.sectors)")
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .gray
        case 2: return .brown
        default: return .blue
        }
    }
}
