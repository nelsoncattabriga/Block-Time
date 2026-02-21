//
//  FRMSFlightStripCard.swift
//  Block-Time
//
//  Compact ring-gauge strip showing flight time against rolling limits.
//

import SwiftUI

struct FRMSFlightStripCard: View {
    let data: NDFRMSStripData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Flight Time Limits", icon: "clock.badge.checkmark")

            HStack(spacing: 0) {
                if let max7d = data.max7d {
                    ringGauge(
                        label: "7 Days",
                        hours: data.hours7d,
                        max: max7d,
                        color: data.limitColor(hours: data.hours7d, max: max7d)
                    )
                    Divider().frame(height: 72).padding(.horizontal, 8)
                }

                ringGauge(
                    label: "\(data.periodDays) Days",
                    hours: data.hours28d,
                    max: data.max28d,
                    color: data.limitColor(hours: data.hours28d, max: data.max28d)
                )

                Divider().frame(height: 72).padding(.horizontal, 8)

                ringGauge(
                    label: "365 Days",
                    hours: data.hours365d,
                    max: data.max365d,
                    color: data.limitColor(hours: data.hours365d, max: data.max365d)
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .appCardStyle()
    }

    @ViewBuilder
    private func ringGauge(label: String, hours: Double, max: Double, color: Color) -> some View {
        let ratio = min(hours / max, 1.0)

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
}
