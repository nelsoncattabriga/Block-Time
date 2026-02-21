//
//  FRMSLimitsCard.swift
//  Block-Time
//
//  Standalone card showing the 4-ring FRMS gauge grid (2×2):
//  flight time 28d/365d + duty time 7d/14d.
//  Extracted from InsightsSidebarView so it can appear in any Insights slot.
//

import SwiftUI

struct FRMSLimitsCard: View {
    let flightStrip: NDFRMSStripData
    @ObservedObject var frmsViewModel: FRMSViewModel
    var showFlight: Bool = true
    var showDuty: Bool = true

    private var totals: FRMSCumulativeTotals? { frmsViewModel.cumulativeTotals }
    private var fleet: FRMSFleet { flightStrip.fleet }

    private var headerTitle: String {
        switch (showFlight, showDuty) {
        case (true, false): return "Flight Time Limits"
        case (false, true): return "Duty Time Limits"
        default:            return "FRMS Limits"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // ── Header ─────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                Text(fleet.shortName)
                    .font(.headline).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)

            // ── Flight Time ────────────────────────────────────────────────
            if showFlight {
                sectionRings(
                    heading: "Flight Time Hours",
                    icon: "airplane",
                    rings: flightRings
                )
            }

            // ── Duty Time ─────────────────────────────────────────────────
            if showDuty {
                sectionRings(
                    heading: "Duty Time Hours",
                    icon: "briefcase.fill",
                    rings: dutyRings
                )
            }

            if showDuty {
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
            }
        }
        .padding(16)
        .appCardStyle()
    }

    // MARK: - Ring Data Helpers

    private var flightRings: [RingData] {
        [
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
    }

    private var dutyRings: [RingData] {
        let duty7d  = totals?.dutyTime7Days  ?? 0
        let duty14d = totals?.dutyTime14Days ?? 0
        let max7d   = fleet.maxDutyTime7Days
        let max14d  = fleet.maxDutyTime14Days
        return [
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
                    ringView(data: rings[i])
                }
            }
        }
    }

    @ViewBuilder
    private func ringView(data: RingData) -> some View {
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
                }
            }
            .frame(width: 90, height: 90)

            Text(data.label)
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func gaugeColor(hours: Double, max: Double) -> Color {
        let r = max > 0 ? min(hours / max, 1.0) : 0
        if r >= 0.9 { return .red }
        if r >= 0.8 { return .orange }
        return .green
    }
}
