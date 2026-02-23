//
//  CareerMilestonesCard.swift
//  Block-Time
//
//  Career stats and progress toward the next flight hour milestone.
//

import SwiftUI

struct CareerMilestonesCard: View {
    let stats: NDCareerStats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Career Overview", icon: "trophy.fill")

            // Top stats row
            HStack(spacing: 0) {
                statBlock(
                    value: String(format: "%.0f", stats.totalHours),
                    label: "Total Hours",
                    icon: "clock.fill",
                    color: .blue
                )
                Divider().frame(height: 44).padding(.horizontal, 8)
                statBlock(
                    value: "\(stats.totalSectors)",
                    label: "Sectors",
                    icon: "airplane",
                    color: .green
                )
                Divider().frame(height: 44).padding(.horizontal, 8)
                statBlock(
                    value: "\(stats.totalAircraftTypes)",
                    label: "A/C Types",
                    icon: "airplane.circle.fill",
                    color: .purple
                )
                Divider().frame(height: 44).padding(.horizontal, 8)
                statBlock(
                    value: String(format: "%.1f yrs", stats.yearsOfData),
                    label: "Over",
                    icon: "calendar",
                    color: .orange
                )
            }
            .frame(maxWidth: .infinity)

            // Start date
            if let firstDate = stats.firstFlightDate {
                HStack {
                    Image(systemName: "flag.fill")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Logbook started \(firstDate.formatted(.dateTime.day().month(.wide).year()))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }

    @ViewBuilder
    private func statBlock(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline).foregroundStyle(color)
            Text(value)
                .iPadScaledFont(.subheadline)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
