//
//  TakeoffLandingCard.swift
//  Block-Time
//
//  Career takeoff and landing counters with day/night split.
//

import SwiftUI

struct TakeoffLandingCard: View {
    let stats: NDTakeoffLandingStats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Takeoffs & Landings", systemImage: "airplane.departure")
                .font(.headline).fontWeight(.bold)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                tlColumn(
                    icon: "airplane.departure",
                    label: "Takeoffs",
                    total: stats.totalTakeoffs,
                    day: stats.dayTakeoffs,
                    night: stats.nightTakeoffs,
                    nightPct: stats.nightTakeoffPct,
                    color: .blue
                )

                Divider()

                tlColumn(
                    icon: "airplane.arrival",
                    label: "Landings",
                    total: stats.totalLandings,
                    day: stats.dayLandings,
                    night: stats.nightLandings,
                    nightPct: stats.nightLandingPct,
                    color: .green
                )
            }
        }
        .padding(16)
        .appCardStyle()
    }

    @ViewBuilder
    private func tlColumn(
        icon: String,
        label: String,
        total: Int,
        day: Int,
        night: Int,
        nightPct: Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption).foregroundStyle(color)
                Text(label)
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            }

            Text("\(total)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                splitRow(label: "Day", count: day, pct: 1 - nightPct, color: .yellow)
                splitRow(label: "Night", count: night, pct: nightPct, color: .indigo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func splitRow(label: String, count: Int, pct: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption2).fontWeight(.semibold)
            Text(String(format: "%.0f%%", pct * 100))
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}
