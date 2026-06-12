//
//  PunctualityCard.swift
//  Block-Time
//
//  Departure and arrival punctuality stats (STD vs OUT, STA vs IN).
//  On time = within 15 min of schedule (IATA A15 standard).
//

import SwiftUI
import BlockTimeKit

private enum PunctualityPeriod: String, CaseIterable {
    case oneMonth     = "1 Month"
    case twelveMonths = "12 Months"
}

private enum PunctualityViewMode: String, CaseIterable {
    case summary = "Summary"
    case detail  = "Detail"
}

private struct PunctualityStats {
    var totalWithData: Int = 0
    var onTime: Int = 0
    var delayed: Int = 0
    var medianDelayedMin: Double = 0
    var mostDelayedRoute: String = ""
    var mostDelayedRoutePct: Double = 0
    var bestOTPRoute: String = ""
    var bestOTPRoutePct: Double = 0

    var onTimePct: Double  { totalWithData > 0 ? Double(onTime)  / Double(totalWithData) : 0 }
    var delayedPct: Double { totalWithData > 0 ? Double(delayed) / Double(totalWithData) : 0 }

    var onTimeColor: Color {
        if onTimePct >= 0.80 { return .green }
        if onTimePct >= 0.60 { return .orange }
        return .red
    }

    static let empty = PunctualityStats()
}

private struct FlightDelay: Identifiable {
    let id = UUID()
    let route: String
    let date: String
    let delayMin: Int
}

struct PunctualityCard: View {
    @AppStorage("punctualityCard_period") private var period: PunctualityPeriod = .twelveMonths
    @AppStorage("punctualityCard_viewMode2") private var viewMode: PunctualityViewMode = .summary
    @AppStorage("useIATACodes") private var useIATACodes: Bool = true
    @State private var depStats: PunctualityStats = .empty
    @State private var arrStats: PunctualityStats = .empty
    @State private var depDelays: [FlightDelay] = []
    @State private var arrDelays: [FlightDelay] = []
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var hasAnyData: Bool { depStats.totalWithData > 0 || arrStats.totalWithData > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "OTP Stats", icon: "clock.badge.checkmark.fill", iconColor: .red) {
                HStack(spacing: 4) {
                    Menu {
                        ForEach(PunctualityPeriod.allCases, id: \.self) { option in
                            Button(option.rawValue) { period = option }
                        }
                    } label: {
                        CardFilterChip(title: period.rawValue)
                    }
                    Menu {
                        ForEach(PunctualityViewMode.allCases, id: \.self) { option in
                            Button(option.rawValue) { viewMode = option }
                        }
                    } label: {
                        CardFilterChip(title: viewMode.rawValue)
                    }
                }
                .tint(.primary)
            }

            if !hasAnyData {
                ContentUnavailableView(
                    "No Schedule Data",
                    systemImage: "clock.badge.questionmark",
                    description: Text("STD/STA and OUT/IN Times Required")
                )
                .frame(height: 120)
            } else if viewMode == .detail {
                VStack(spacing: 14) {
                    delayDetailSection(label: "Departures", delays: depDelays)
                    Divider()
                    delayDetailSection(label: "Arrivals", delays: arrDelays)
                }
                .transition(.opacity)
            } else if sizeClass == .regular {
                HStack(spacing: 16) {
                    punctualityColumn(label: "Departures", stats: depStats, icon: "airplane.departure", iconColor: .blue)
                    Divider()
                    punctualityColumn(label: "Arrivals", stats: arrStats, icon: "airplane.arrival", iconColor: .green)
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 14) {
                    punctualityColumn(label: "Departures", stats: depStats, icon: "airplane.departure", iconColor: .blue)
                    Divider()
                    punctualityColumn(label: "Arrivals", stats: arrStats, icon: "airplane.arrival", iconColor: .green)
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { loadStats() }
        .onChange(of: period) { loadStats() }
    }

    // MARK: - Summary view

    @ViewBuilder
    private func punctualityColumn(label: String, stats: PunctualityStats, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .foregroundStyle(iconColor)
                Text(label)
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            if stats.totalWithData == 0 {
                Text("No data")
                    .iPadScaledFont(.caption, phoneFont: .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .center, spacing: 10) {
                    Text(String(format: "%.0f%%", stats.onTimePct * 100))
                        .font(.system(sizeClass == .regular ? .title : .headline, design: .rounded, weight: .bold))
                        .foregroundStyle(stats.onTimeColor)

                    punctualityBar(stats: stats)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if !stats.bestOTPRoute.isEmpty {
                        otpFooterRow(label: "Best OTP", route: stats.bestOTPRoute, pct: stats.bestOTPRoutePct, color: .green)
                    }
                    if !stats.mostDelayedRoute.isEmpty {
                        otpFooterRow(label: "Worst OTP", route: stats.mostDelayedRoute, pct: stats.mostDelayedRoutePct, color: .red)
                    }
                    if stats.delayed > 0 {
                        HStack(spacing: 6) {
                            Circle().fill(Color.orange.opacity(0.8)).frame(width: 6, height: 6)
                            Text("Avg Delay")
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(stats.medianDelayedMin)) min")
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func otpFooterRow(label: String, route: String, pct: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color.opacity(0.8)).frame(width: 6, height: 6)
            Text(label)
                .iPadScaledFont(.caption2, phoneFont: .footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(route)
                .iPadScaledFont(.caption2, phoneFont: .footnote)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(String(format: "%.0f%%", pct * 100))
                .iPadScaledFont(.caption2, phoneFont: .footnote)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
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

    // MARK: - Detail view

    @ViewBuilder
    private func delayDetailSection(label: String, delays: [FlightDelay]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .iPadScaledFont(.caption, phoneFont: .subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if delays.isEmpty {
                Text("No delays recorded")
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .foregroundStyle(.secondary)
            } else {
                let maxDelay = Double(delays.first?.delayMin ?? 1)
                VStack(spacing: 6) {
                    ForEach(delays) { item in
                        delayRow(item: item, maxDelay: maxDelay)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func delayRow(item: FlightDelay, maxDelay: Double) -> some View {
        HStack(spacing: 10) {
            Text(item.route)
                .font(.system(sizeClass == .regular ? .body : .footnote, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)
                .fixedSize()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red.opacity(0.75).gradient)
                        .frame(width: geo.size.width * CGFloat(Double(item.delayMin) / maxDelay))
                }
            }
            .frame(height: 12)
            .frame(minWidth: 40, maxWidth: .infinity)

            Text(item.date)
                .iPadScaledFont(.caption2, phoneFont: .footnote)
                .foregroundStyle(.secondary)
                .fixedSize()

            Text("+\(item.delayMin)m")
                .iPadScaledFont(.caption, phoneFont: .footnote)
                .fontWeight(.bold)
                .foregroundStyle(.red)
                .fixedSize()
        }
    }

    // MARK: - Data loading

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

        let (dStats, dDelays) = compute(flights: flights, scheduled: \.scheduledDeparture, actual: \.outTime)
        let (aStats, aDelays) = compute(flights: flights, scheduled: \.scheduledArrival,   actual: \.inTime)
        depStats  = dStats;  depDelays  = dDelays
        arrStats  = aStats;  arrDelays  = aDelays
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
    ) -> (PunctualityStats, [FlightDelay]) {
        var result = PunctualityStats()
        var delayedMinutes: [Int] = []
        var routeCounts: [String: (total: Int, delayed: Int, display: String)] = [:]
        var allDelays: [FlightDelay] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d MMM"

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

                let displayDate: String
                if let d = dateFormatter.date(from: f.date) {
                    displayDate = displayFormatter.string(from: d)
                } else {
                    displayDate = f.date
                }
                allDelays.append(FlightDelay(route: "\(from)-\(to)", date: displayDate, delayMin: delayMin))
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

        let qualified = routeCounts.values.filter { $0.total >= 3 }

        if let worst = qualified.max(by: { Double($0.delayed) / Double($0.total) < Double($1.delayed) / Double($1.total) }) {
            result.mostDelayedRoute = worst.display
            result.mostDelayedRoutePct = Double(worst.delayed) / Double(worst.total)
        }

        if let best = qualified.max(by: { Double($0.total - $0.delayed) / Double($0.total) < Double($1.total - $1.delayed) / Double($1.total) }) {
            result.bestOTPRoute = best.display
            result.bestOTPRoutePct = Double(best.total - best.delayed) / Double(best.total)
        }

        let topDelays = Array(allDelays.sorted { $0.delayMin > $1.delayMin }.prefix(5))
        return (result, topDelays)
    }
}
