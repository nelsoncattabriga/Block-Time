//
//  FleetDonutCard.swift
//  Block-Time
//
//  Donut chart showing total hours broken down by aircraft type.
//

import SwiftUI
import Charts

// Consistent palette for aircraft types
private func fleetColor(for type: String) -> Color {
    let t = type.uppercased()
    if t.contains("A320") || t.contains("A319") || t.contains("A321") { return .blue }
    if t.contains("737")  || t.contains("B737")                        { return .green }
    if t.contains("A380")                                              { return .orange }
    if t.contains("A330")                                              { return .red }
    if t.contains("787")  || t.contains("B787")                        { return .purple }
    if t.contains("A350")                                              { return .teal }
    if t.contains("SIM")  || t.contains("FSTD")                        { return .cyan }
    // fallback: stable hash-based hue
    let hue = Double(abs(type.hashValue) % 360) / 360.0
    return Color(hue: hue, saturation: 0.65, brightness: 0.75)
}

struct FleetDonutCard: View {
    let data: [NDFleetHours]

    // Collapse tail beyond top-5 into "Other"
    private var chartData: [NDFleetHours] {
        let top = Array(data.prefix(5))
        if data.count <= 5 { return top }
        let otherHours = data.dropFirst(5).reduce(0) { $0 + $1.hours }
        let otherSectors = data.dropFirst(5).reduce(0) { $0 + $1.sectors }
        let other = NDFleetHours(aircraftType: "Other", hours: otherHours, sectors: otherSectors)
        return top + [other]
    }

    private var totalHours: Double { data.reduce(0) { $0 + $1.hours } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Time by Fleet", systemImage: "airplane.circle.fill")
                .font(.headline).fontWeight(.bold)
                .foregroundStyle(.secondary)

            if data.isEmpty {
                ContentUnavailableView("No Data", systemImage: "airplane.slash")
                    .frame(height: 160)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    // Donut
                    ZStack {
                        Chart(chartData) { item in
                            SectorMark(
                                angle: .value("Hours", item.hours),
                                innerRadius: .ratio(0.60),
                                angularInset: 1.5
                            )
                            .foregroundStyle(fleetColor(for: item.aircraftType))
                            .cornerRadius(4)
                        }

                        VStack(spacing: 2) {
                            Text(String(format: "%.0f", totalHours))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("hrs")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 140, height: 140)

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chartData) { item in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(fleetColor(for: item.aircraftType))
                                    .frame(width: 10, height: 10)

                                Text(item.aircraftType)
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(String(format: "%.0f", item.hours))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }
}
