//
//  TimeByTypeCard.swift
//  Block-Time
//
//  Donut chart showing hours or sectors broken down by aircraft type.
//  Time by Fleet

import SwiftUI
import Charts

private enum FleetDisplayMode: String, CaseIterable {
    case hours = "Hours"
    case sectors = "Sectors"
}

// Position-based palette — guarantees no two slices share a colour
private let fleetPalette: [Color] = [
    .blue, .orange, .green, .purple, .red, .teal, .yellow, .pink, .indigo, .mint
]

private func fleetColor(at index: Int) -> Color {
    fleetPalette[index % fleetPalette.count]
}

struct TimeByTypeCard: View {
    let data: [NDFleetHours]

    @State private var displayMode: FleetDisplayMode = .hours

    // Sort by active mode, then collapse tail beyond top-5 into "Other"
    private var chartData: [NDFleetHours] {
        let sorted = displayMode == .hours
            ? data.sorted { $0.hours > $1.hours }
            : data.sorted { $0.sectors > $1.sectors }
        let top = Array(sorted.prefix(5))
        if sorted.count <= 5 { return top }
        let otherHours = sorted.dropFirst(5).reduce(0) { $0 + $1.hours }
        let otherSectors = sorted.dropFirst(5).reduce(0) { $0 + $1.sectors }
        let other = NDFleetHours(aircraftType: "Other", hours: otherHours, sectors: otherSectors)
        return top + [other]
    }

    private var totalHours: Double { data.reduce(0) { $0 + $1.hours } }
    private var totalSectors: Int { data.reduce(0) { $0 + $1.sectors } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Time by Type", icon: "airplane.circle.fill")

            Picker("Display", selection: $displayMode) {
                ForEach(FleetDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if data.isEmpty {
                ContentUnavailableView("No Data", systemImage: "airplane.slash")
                    .frame(height: 160)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    // Donut
                    ZStack {
                        Chart(Array(chartData.enumerated()), id: \.element.id) { index, item in
                            SectorMark(
                                angle: .value(
                                    displayMode == .hours ? "Hours" : "Sectors",
                                    displayMode == .hours ? item.hours : Double(item.sectors)
                                ),
                                innerRadius: .ratio(0.60),
                                angularInset: 1.5
                            )
                            .foregroundStyle(fleetColor(at: index))
                            .cornerRadius(4)
                        }

                        VStack(spacing: 2) {
                            if displayMode == .hours {
                                Text(String(format: "%.0f", totalHours))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Text("hrs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(totalSectors)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Text("sectors")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 140, height: 140)
                    .animation(.spring(response: 0.4), value: displayMode)

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(chartData.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(fleetColor(at: index))
                                    .frame(width: 10, height: 10)

                                Text(item.aircraftType)
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(displayMode == .hours
                                     ? String(format: "%.0f", item.hours)
                                     : "\(item.sectors)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.spring(response: 0.4), value: displayMode)
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }
}
