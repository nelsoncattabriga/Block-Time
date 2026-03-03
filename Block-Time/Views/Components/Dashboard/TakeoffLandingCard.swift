//
//  TakeoffLandingCard.swift
//  Block-Time
//
//  Career takeoff and landing counters with day/night split.
//

import SwiftUI

private enum TLPeriod: String, CaseIterable {
    case oneMonth   = "1M"
    case twelveMonths = "12M"
    case all         = "ALL"
}

struct TakeoffLandingCard: View {
    @State private var period: TLPeriod = .oneMonth
    @State private var stats: NDTakeoffLandingStats = .empty

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "T/O & LDGs", icon: "airplane") {
                Picker("Period", selection: $period) {
                    ForEach(TLPeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

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
        .onAppear { loadStats() }
        .onChange(of: period) { loadStats() }
    }

    private func loadStats() {
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

        var dTO = 0, nTO = 0, dLDG = 0, nLDG = 0
        for f in flights {
            dTO  += f.dayTakeoffs;  nTO  += f.nightTakeoffs
            dLDG += f.dayLandings;  nLDG += f.nightLandings
        }
        stats = NDTakeoffLandingStats(dayTakeoffs: dTO, nightTakeoffs: nTO, dayLandings: dLDG, nightLandings: nLDG)
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
        let dayPct = 1 - nightPct

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .iPadScaledFont(.caption).foregroundStyle(color)
                Text(label)
                    .iPadScaledFont(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 10) {
                Text("\(total)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(color)

                // Stacked horizontal bar
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        if dayPct > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.yellow.opacity(0.85))
                                .frame(width: max(0, geo.size.width * dayPct - 0.5))
                        }
                        if nightPct > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.indigo.opacity(0.85))
                                .frame(width: max(0, geo.size.width * nightPct - 0.5))
                        }
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 3) {
                legendRow(label: "Day",   count: day,   pct: dayPct,   color: .yellow)
                legendRow(label: "Night", count: night, pct: nightPct, color: .indigo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func legendRow(label: String, count: Int, pct: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(label)
                .iPadScaledFont(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .iPadScaledFont(.caption).fontWeight(.semibold)
            Text(String(format: "(%.0f%%)", pct * 100))
                .iPadScaledFont(.caption).foregroundStyle(.secondary)
        }
    }
}
