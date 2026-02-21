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
            Label("Career Overview", systemImage: "trophy.fill")
                .font(.headline).fontWeight(.bold)
                .foregroundStyle(.secondary)

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
                    value: String(format: "%.1f yrs", stats.yearsOfData),
                    label: "Logbook Span",
                    icon: "calendar",
                    color: .orange
                )
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Milestone progress
            if let nextMilestone = stats.nextMilestone {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Next milestone")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f / %.0f hrs", stats.totalHours, nextMilestone))
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.primary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.12))

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(stats.milestoneProgress))
                                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: stats.milestoneProgress)
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        Text(String(format: "%.0f hrs", stats.previousMilestone))
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                        Spacer()
                        let remaining = nextMilestone - stats.totalHours
                        Text(String(format: "%.0f hrs to go", remaining))
                            .font(.system(size: 10)).fontWeight(.medium).foregroundStyle(.purple)
                        Spacer()
                        Text(String(format: "%.0f hrs", nextMilestone))
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("All major milestones reached!")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
            }

            // Start date
            if let firstDate = stats.firstFlightDate {
                HStack {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                    Text("Logbook started \(firstDate.formatted(.dateTime.day().month(.wide).year()))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
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
                .font(.caption2).foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
