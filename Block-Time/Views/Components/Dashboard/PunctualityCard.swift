//
//  PunctualityCard.swift
//  Block-Time
//
//  Departure and arrival punctuality stats (STD vs OUT, STA vs IN).
//  On time = within 15 min of schedule (IATA A15 standard).
//

import SwiftUI

private enum PunctualityPeriod: String, CaseIterable {
    case oneMonth     = "1M"
    case twelveMonths = "12M"
    
}

private struct PunctualityStats {
    var totalWithData: Int = 0
    var onTime: Int = 0
    var delayed: Int = 0
    var medianDelayedMin: Double = 0
    var mostDelayedRoute: String = ""
    var mostDelayedRoutePct: Double = 0

    var onTimePct: Double  { totalWithData > 0 ? Double(onTime)  / Double(totalWithData) : 0 }
    var delayedPct: Double { totalWithData > 0 ? Double(delayed) / Double(totalWithData) : 0 }

    var onTimeColor: Color {
        if onTimePct >= 0.80 { return .green }
        if onTimePct >= 0.60 { return .orange }
        return .red
    }

    static let empty = PunctualityStats()
}

struct PunctualityCard: View {
    @AppStorage("punctualityCard_period") private var period: PunctualityPeriod = .twelveMonths
    @AppStorage("useIATACodes") private var useIATACodes: Bool = true
    @State private var depStats: PunctualityStats = .empty
    @State private var arrStats: PunctualityStats = .empty
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var hasAnyData: Bool { depStats.totalWithData > 0 || arrStats.totalWithData > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "OTP Stats", icon: "clock.badge.checkmark.fill", iconColor: .teal) {
                Picker("Period", selection: $period) {
                    ForEach(PunctualityPeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if !hasAnyData {
                ContentUnavailableView(
                    "No Schedule Data",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Log STD/OUT and STA/IN times to see OTP stats")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 14) {
                    punctualityColumn(label: "Departures", stats: depStats)
                    Divider()
                    punctualityColumn(label: "Arrivals", stats: arrStats)
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { loadStats() }
        .onChange(of: period) { loadStats() }
    }

    @ViewBuilder
    private func punctualityColumn(label: String, stats: PunctualityStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if stats.totalWithData == 0 {
                Text(label)
                    .iPadScaledFont(.caption, phoneFont: .subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text("No data")
                    .iPadScaledFont(.caption, phoneFont: .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(label)
                    .iPadScaledFont(.caption, phoneFont: .subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 10) {
                    Text(String(format: "%.0f%%", stats.onTimePct * 100))
                        .font(.system(sizeClass == .regular ? .title2 : .headline, design: .rounded, weight: .bold))
                        .foregroundStyle(stats.onTimeColor)

                    punctualityBar(stats: stats)

                    if stats.delayed > 0 {
                        Text(String(format: "%.0f%%", stats.delayedPct * 100))
                            .font(.system(sizeClass == .regular ? .title2 : .headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }

                if stats.delayed > 0 {
                    HStack(spacing: 4) {
                        Spacer()
                        Text("Avg Delay")
                            .iPadScaledFont(.caption2, phoneFont: .footnote)
                            .foregroundStyle(.secondary)
                        Text("\(Int(stats.medianDelayedMin)) min")
                            .iPadScaledFont(.caption2, phoneFont: .footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        if !stats.mostDelayedRoute.isEmpty {
                            Text("·")
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .foregroundStyle(.secondary)
                            Text("Most Delayed")
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .foregroundStyle(.secondary)
                            Text("\(stats.mostDelayedRoute)")
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                            Text(String(format: "%.0f%%", stats.mostDelayedRoutePct * 100))
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func punctualityBar(stats: PunctualityStats) -> some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                let onW  = geo.size.width * CGFloat(stats.onTimePct)
                let delW = geo.size.width * CGFloat(stats.delayedPct)
                if stats.onTimePct > 0 {
                    RoundedRectangle(cornerRadius: 3).fill(Color.green.opacity(0.85))
                        .frame(width: max(0, onW - 0.5))
                }
                if stats.delayedPct > 0 {
                    RoundedRectangle(cornerRadius: 3).fill(Color.red.opacity(0.85))
                        .frame(width: max(0, delW - 0.5))
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
    }

    private func loadStats() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let now = Date()
        let endDate = formatter.string(from: now)

        let flights: [FlightSector]
        switch period {
        case .oneMonth:
            let start = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            flights = FlightDatabaseService.shared.fetchFlights(from: formatter.string(from: start), to: endDate)
        case .twelveMonths:
            let start = Calendar.current.date(byAdding: .month, value: -12, to: now)!
            flights = FlightDatabaseService.shared.fetchFlights(from: formatter.string(from: start), to: endDate)
        }

        depStats = compute(flights: flights, scheduled: \.scheduledDeparture, actual: \.outTime)
        arrStats = compute(flights: flights, scheduled: \.scheduledArrival,   actual: \.inTime)
    }

    private func minutesFromHHMM(_ s: String) -> Int? {
        guard s.count == 5, s.contains(":") else { return nil }
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              h < 24, m < 60 else { return nil }
        return h * 60 + m
    }

    private func compute(
        flights: [FlightSector],
        scheduled: KeyPath<FlightSector, String>,
        actual: KeyPath<FlightSector, String>
    ) -> PunctualityStats {
        var result = PunctualityStats()
        var delayedMinutes: [Int] = []
        var routeCounts: [String: (total: Int, delayed: Int, display: String)] = [:]

        for f in flights {
            guard let sMin = minutesFromHHMM(f[keyPath: scheduled]),
                  let aMin = minutesFromHHMM(f[keyPath: actual]) else { continue }

            var delayMin = aMin - sMin
            if delayMin > 720  { delayMin -= 1440 }
            if delayMin < -720 { delayMin += 1440 }

            result.totalWithData += 1

            let from = AirportService.shared.getDisplayCode(f.fromAirport, useIATA: useIATACodes)
            let to   = AirportService.shared.getDisplayCode(f.toAirport,   useIATA: useIATACodes)
            let key  = "\(f.fromAirport)-\(f.toAirport)"
            let existing = routeCounts[key] ?? (0, 0, "\(from)-\(to)")
            let isDelayed = delayMin > 15

            if isDelayed {
                result.delayed += 1
                delayedMinutes.append(delayMin)
                routeCounts[key] = (existing.total + 1, existing.delayed + 1, existing.display)
            } else {
                result.onTime += 1
                routeCounts[key] = (existing.total + 1, existing.delayed, existing.display)
            }
        }

        if !delayedMinutes.isEmpty {
            let sorted = delayedMinutes.sorted()
            let mid = sorted.count / 2
            result.medianDelayedMin = sorted.count.isMultiple(of: 2)
                ? Double(sorted[mid - 1] + sorted[mid]) / 2
                : Double(sorted[mid])
        }

        // Most statistically delayed route — minimum 3 sectors to qualify
        if let worst = routeCounts.values
            .filter({ $0.total >= 3 })
            .max(by: { Double($0.delayed) / Double($0.total) < Double($1.delayed) / Double($1.total) }) {
            result.mostDelayedRoute = worst.display
            result.mostDelayedRoutePct = Double(worst.delayed) / Double(worst.total)
        }

        return result
    }
}
