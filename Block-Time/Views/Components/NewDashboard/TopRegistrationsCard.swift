//
//  TopRegistrationsCard.swift
//  Block-Time
//
//  Ranked list of most-flown aircraft registrations by hours.
//

import SwiftUI

struct TopRegistrationsCard: View {
    let registrations: [NDRegistrationHours]

    private var maxHours: Double { registrations.map { $0.hours }.max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Most Flown Tails", systemImage: "tag.fill")
                .font(.headline).fontWeight(.bold)
                .foregroundStyle(.secondary)

            if registrations.isEmpty {
                ContentUnavailableView(
                    "No Registration Data",
                    systemImage: "airplane.slash",
                    description: Text("Log aircraft registrations to see your most-flown tails")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(registrations.enumerated()), id: \.element.id) { index, reg in
                        regRow(index: index, reg: reg)
                    }
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }

    @ViewBuilder
    private func regRow(index: Int, reg: NDRegistrationHours) -> some View {
        HStack(spacing: 10) {
            // Rank
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue.opacity(index == 0 ? 1.0 : 0.5 - Double(index) * 0.04).gradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(reg.registration)
                    .font(.caption).fontWeight(.bold).foregroundStyle(.primary)
                Text(reg.aircraftType)
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.gradient)
                        .frame(width: geo.size.width * CGFloat(reg.hours / maxHours))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: reg.hours)
                }
            }
            .frame(width: 70, height: 12)

            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.0f hrs", reg.hours))
                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                Text("\(reg.sectors) sectors")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
    }
}
