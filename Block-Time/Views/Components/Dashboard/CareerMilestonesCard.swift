//
//  CareerMilestonesCard.swift
//  Block-Time
//
//  Career stats and progress toward the next flight hour milestone.
//

import SwiftUI

struct CareerMilestonesCard: View {
    let stats: NDCareerStats
    @AppStorage("countSimInTotal") private var countSimInTotal: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Career Overview", icon: "trophy.fill", iconColor: .yellow)

            // Top stats row
            HStack(spacing: 8) {
                statBlock(
                    value: String(format: "%.0f", stats.totalHours(includeSim: countSimInTotal)),
                    label: "Hours",
                    color: .blue
                )
                statBlock(
                    value: "\(stats.totalSectors)",
                    label: "Flights",
                    color: .green
                )
                statBlock(
                    value: "\(stats.totalAirports)",
                    label: "Airports",
                    color: .teal
                )
                statBlock(
                    value: "\(stats.totalAircraftTypes)",
                    label: "Types",
                    color: .purple
                )
            }

            // Footer: years logged + start date
            if let firstDate = stats.firstFlightDate {
                let years = Int(stats.yearsOfData)
                let yearLabel = years == 1 ? "year" : "years"
                HStack {
                    Image(systemName: "flag.fill")
                        .iPadScaledFont(.caption, phoneFont: .footnote).foregroundStyle(.secondary)
                    Text("Logged \(years) \(yearLabel) from \(firstDate.formatted(.dateTime.month(.wide).year()))")
                        .iPadScaledFont(.caption, phoneFont: .footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }

    @ViewBuilder
    private func statBlock(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .iPadScaledFont(.subheadline)
                .bold()
                .fontDesign(.rounded)
                .foregroundStyle(color)
            Text(label)
                .iPadScaledFont(.caption, phoneFont: .footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}
