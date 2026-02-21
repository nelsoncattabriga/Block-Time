//
//  FRMSDutyStripCard.swift
//  Block-Time
//
//  Compact horizontal ring-gauge strip for duty time limits (7d / 14d).
//  Mirrors the layout and styling of FRMSFlightStripCard.
//  Used on iPhone where FRMSLimitsCard's vertical grid is not shown.
//

import SwiftUI

struct FRMSDutyStripCard: View {
    let flightStrip: NDFRMSStripData
    @ObservedObject var frmsViewModel: FRMSViewModel

    private var totals: FRMSCumulativeTotals? { frmsViewModel.cumulativeTotals }
    private var fleet: FRMSFleet { flightStrip.fleet }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Duty Time Limits", icon: "briefcase.fill")

            if frmsViewModel.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Loading FRMS…")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            } else if totals == nil {
                Text("Duty data will appear after FRMS loads.")
                    .font(.system(size: 10)).foregroundStyle(.secondary).italic()
            } else {
                HStack(spacing: 0) {
                    ringGauge(
                        label: "7 Days",
                        hours: totals?.dutyTime7Days ?? 0,
                        max: fleet.maxDutyTime7Days
                    )
                    Divider().frame(height: 72).padding(.horizontal, 8)
                    ringGauge(
                        label: "14 Days",
                        hours: totals?.dutyTime14Days ?? 0,
                        max: fleet.maxDutyTime14Days
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .appCardStyle()
        .task { await triggerFRMSLoadIfNeeded() }
    }

    @MainActor
    private func triggerFRMSLoadIfNeeded() async {
        guard frmsViewModel.cumulativeTotals == nil, !frmsViewModel.isLoading else { return }
        let raw      = UserDefaults.standard.string(forKey: "flightTimePosition") ?? ""
        let position = FlightTimePosition(rawValue: raw) ?? .captain
        frmsViewModel.loadFlightData(crewPosition: position)
    }

    @ViewBuilder
    private func ringGauge(label: String, hours: Double, max: Double) -> some View {
        let ratio = max > 0 ? min(hours / max, 1.0) : 0
        let color = gaugeColor(hours: hours, max: max)

        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: ratio)

                VStack(spacing: 1) {
                    Text(String(format: "%.1f", hours))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("hrs")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 74, height: 74)

            VStack(spacing: 2) {
                Text(label)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text("/ \(Int(max))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func gaugeColor(hours: Double, max: Double) -> Color {
        let r = max > 0 ? min(hours / max, 1.0) : 0
        if r >= 0.9 { return .red }
        if r >= 0.8 { return .orange }
        return .green
    }
}
