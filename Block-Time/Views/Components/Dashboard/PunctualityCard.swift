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
    @AppStorage("punctualityCard_viewMode") private var showDetail: Bool = false
    @AppStorage("useIATACodes") private var useIATACodes: Bool = true
    @State private var depStats: PunctualityStats = .empty
    @State private var arrStats: PunctualityStats = .empty
    @State private var depDelays: [FlightDelay] = []
    @State private var arrDelays: [FlightDelay] = []
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

            Picker("View", selection: $showDetail) {
                Text("Summary").tag(false)
                Text("Details").tag(true)
            }
            .pickerStyle(.segmented)
            .animation(.spring(response: 0.35), value: showDetail)

            if !hasAnyData {
                ContentUnavailableView(
                    "No Schedule Data",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Log STD/OUT and STA/IN times to see OTP stats")
                )
                .frame(height: 120)
            } else if showDetail {
                VStack(spacing: 14) {
                    delayDetailSection(label: "Departures", delays: depDelays)
                    Divider()
                    delayDetailSection(label: "Arrivals", delays: arrDelays)
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 14) {
                    punctualityColumn(label: "Departures", stats: depStats)
                    Divider()
                    punctualityColumn(label: "Arrivals", stats: arrStats)
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
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(label)
                        .iPadScaledFont(.caption, phoneFont: .subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    if stats.delayed > 0 && sizeClass != .regular {
                        Text("·")
                            .iPadScaledFont(.caption2, phoneFont: .footnote)
                            .foregroundStyle(.secondary)
                        Text("Avg Delay")
                            .iPadScaledFont(.caption2, phoneFont: .footnote)
                            .foregroundStyle(.secondary)
                        Text("\(Int(stats.medianDelayedMin)) min")
                            .iPadScaledFont(.caption2, phoneFont: .footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)

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

                let showDelayed = !stats.mostDelayedRoute.isEmpty
                let showBest    = !stats.bestOTPRoute.isEmpty
                let isCompact   = sizeClass != .regular
                if showDelayed || showBest {
                    HStack(spacing: 4) {
                        Spacer()
                        if showBest {
                            if !isCompact {
                                Text("Best OTP")
                                    .iPadScaledFont(.caption2, phoneFont: .footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Text(stats.bestOTPRoute)
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                            Text(String(format: "%.0f%%", stats.bestOTPRoutePct * 100))
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                        if showDelayed && showBest {
                            Text("·")
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .foregroundStyle(.secondary)
                        }
                        if showDelayed {
                            if !isCompact {
                                Text("Worst OTP")
                                    .iPadScaledFont(.caption2, phoneFont: .footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Text(stats.mostDelayedRoute)
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                            Text(String(format: "%.0f%%", stats.mostDelayedRoutePct * 100))
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                        if !isCompact && stats.delayed > 0 {
                            Text("·")
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .foregroundStyle(.secondary)
                            Text("Avg Delay")
                                .iPadScaledFont(.caption2, phoneFont: .footnote)
                                .foregroundStyle(.secondary)
                            Text("\(Int(stats.medianDelayedMin)) min")
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
