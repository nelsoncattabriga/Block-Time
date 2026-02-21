//
//  InsightsSidebarView.swift
//  Block-Time
//
//  iPad-only sidebar showing FRMS cumulative flight & duty time limits
//  in a 2×2 ring gauge layout.
//

import SwiftUI

struct InsightsSidebarView: View {
    let flightStrip: NDFRMSStripData
    let careerStats: NDCareerStats
    let flightStatistics: FlightStatistics
    @ObservedObject var frmsViewModel: FRMSViewModel

    @State private var showTimesInHoursMinutes: Bool =
        UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")

    private var totals: FRMSCumulativeTotals? { frmsViewModel.cumulativeTotals }
    private let fleet: FRMSFleet

    init(flightStrip: NDFRMSStripData, careerStats: NDCareerStats, flightStatistics: FlightStatistics, frmsViewModel: FRMSViewModel) {
        self.flightStrip = flightStrip
        self.careerStats = careerStats
        self.flightStatistics = flightStatistics
        self.frmsViewModel = frmsViewModel
        self.fleet = flightStrip.fleet
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── Header ─────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("FRMS Limits")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                        .kerning(1.2)
                    Text(fleet.shortName)
                        .font(.headline).fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

                // ── Flight Time ────────────────────────────────────
                sectionRings(
                    heading: "Flight Time Hours",
                    icon: "airplane",
                    rings: [
                        RingData(
                            label: "\(flightStrip.periodDays) Days",
                            sublabel: "/ \(Int(flightStrip.max28d))",
                            hours: flightStrip.hours28d,
                            max: flightStrip.max28d,
                            color: flightStrip.limitColor(hours: flightStrip.hours28d, max: flightStrip.max28d)
                        ),
                        RingData(
                            label: "365 Days",
                            sublabel: "/ \(Int(flightStrip.max365d))",
                            hours: flightStrip.hours365d,
                            max: flightStrip.max365d,
                            color: flightStrip.limitColor(hours: flightStrip.hours365d, max: flightStrip.max365d)
                        )
                    ]
                )

                // ── Duty Time ──────────────────────────────────────
                let duty7d  = totals?.dutyTime7Days  ?? 0
                let duty14d = totals?.dutyTime14Days ?? 0
                let max7d   = fleet.maxDutyTime7Days
                let max14d  = fleet.maxDutyTime14Days

                sectionRings(
                    heading: "Duty Time Hours",
                    icon: "briefcase.fill",
                    rings: [
                        RingData(
                            label: "7 Days",
                            sublabel: "/ \(Int(max7d))",
                            hours: duty7d,
                            max: max7d,
                            color: gaugeColor(hours: duty7d, max: max7d)
                        ),
                        RingData(
                            label: "14 Days",
                            sublabel: "/ \(Int(max14d))",
                            hours: duty14d,
                            max: max14d,
                            color: gaugeColor(hours: duty14d, max: max14d)
                        )
                    ]
                )

                if frmsViewModel.isLoading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("Loading FRMS…")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                } else if totals == nil {
                    Text("Duty data will appear after FRMS loads.")
                        .font(.system(size: 10)).foregroundStyle(.secondary).italic()
                }

                // ── Total Time ─────────────────────────────────────
                Divider()

                StatCard(
                    title: "Total Time",
                    value: flightStatistics.formattedTotalFlightTime(asHoursMinutes: showTimesInHoursMinutes),
                    subtitle: "\(flightStatistics.totalSectors) sectors",
                    color: .blue,
                    icon: "clock.fill"
                )
                .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                    showTimesInHoursMinutes = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .task { await triggerFRMSLoadIfNeeded() }
    }

    // MARK: - Ring Section

    private struct RingData {
        let label: String
        let sublabel: String
        let hours: Double
        let max: Double
        let color: Color
    }

    @ViewBuilder
    private func sectionRings(heading: String, icon: String, rings: [RingData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(heading, systemImage: icon)
                .font(.footnote).fontWeight(.semibold)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 12
            ) {
                ForEach(rings.indices, id: \.self) { i in
                    ring(data: rings[i])
                }
            }
        }
    }

    @ViewBuilder
    private func ring(data: RingData) -> some View {
        let ratio = data.max > 0 ? min(data.hours / data.max, 1.0) : 0

        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(data.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: ratio)

                VStack(spacing: 1) {
                    Text(String(format: "%.1f", data.hours))
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                    Text(data.sublabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
//                    
//                    Text("hrs")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 90)

            VStack(spacing: 2) {
                Text(data.label)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
//                Text(data.sublabel)
//                    .font(.system(size: 9))
//                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func gaugeColor(hours: Double, max: Double) -> Color {
        let r = max > 0 ? min(hours / max, 1.0) : 0
        if r >= 0.9 { return .red }
        if r >= 0.8 { return .orange }
        return .green
    }

    @MainActor
    private func triggerFRMSLoadIfNeeded() async {
        guard frmsViewModel.cumulativeTotals == nil, !frmsViewModel.isLoading else { return }
        let raw      = UserDefaults.standard.string(forKey: "flightTimePosition") ?? ""
        let position = FlightTimePosition(rawValue: raw) ?? .captain
        frmsViewModel.loadFlightData(crewPosition: position)
    }
}
