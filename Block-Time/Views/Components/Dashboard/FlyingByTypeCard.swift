//
//  FlyingByTypeCard.swift
//  Block-Time
//
//  Donut chart showing hours or sectors broken down by aircraft type.
//  Time by Fleet

import SwiftUI
import Charts
import BlockTimeKit

private enum FleetDisplayMode: String, CaseIterable {
    case hours = "Hours"
    case sectors = "Flights"
}

private enum FleetGroupMode: String, CaseIterable {
    case type = "Type"
    case family = "Family"
}

// Position-based palette — guarantees no two slices share a colour
private let fleetPalette: [Color] = [
    .blue, .orange, .green, .purple, .red, .teal, .yellow, .pink, .indigo, .mint
]

private func fleetColor(at index: Int) -> Color {
    fleetPalette[index % fleetPalette.count]
}

private struct OverflowMaxWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct FlyingByTypeCard: View {
    let data: [NDFleetHours]

    @AppStorage("timeByTypeCard_displayMode") private var displayMode: FleetDisplayMode = .hours
    @AppStorage("timeByTypeCard_groupMode") private var groupMode: FleetGroupMode = .type
    @State private var showAll: Bool = false
    @State private var overflowNameWidth: CGFloat = 0

    private static let topCount = 5

    // Collapse individual types into family names when groupMode is .family
    private var resolvedData: [NDFleetHours] {
        guard groupMode == .family else { return data }
        var hoursByLabel: [String: Double] = [:]
        var sectorsByLabel: [String: Int] = [:]
        for item in data {
            let label = AircraftFleetService.familyName(for: item.aircraftType) ?? item.aircraftType
            hoursByLabel[label, default: 0] += item.hours
            sectorsByLabel[label, default: 0] += item.sectors
        }
        return hoursByLabel.map { NDFleetHours(aircraftType: $0.key, hours: $0.value, sectors: sectorsByLabel[$0.key] ?? 0) }
    }

    // All rows sorted by active mode
    private var sortedData: [NDFleetHours] {
        displayMode == .hours
            ? resolvedData.sorted { $0.hours > $1.hours }
            : resolvedData.sorted { $0.sectors > $1.sectors }
    }

    // Top-5 slices for the donut + "Other" for the tail
    private var chartData: [NDFleetHours] {
        let top = Array(sortedData.prefix(Self.topCount))
        guard sortedData.count > Self.topCount else { return top }
        let tail = sortedData.dropFirst(Self.topCount)
        let other = NDFleetHours(
            aircraftType: "Other (\(tail.count))",
            hours: tail.reduce(0) { $0 + $1.hours },
            sectors: tail.reduce(0) { $0 + $1.sectors }
        )
        return top + [other]
    }

    // All items shown as bars when expanded
    private var overflowData: [NDFleetHours] {
        sortedData
    }

    private var hasMore: Bool { sortedData.count > Self.topCount }
    private var totalHours: Double { data.reduce(0) { $0 + $1.hours } }
    private var totalSectors: Int { data.reduce(0) { $0 + $1.sectors } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Flying by Type", icon: "airplane.circle.fill", iconColor: .indigo) {
                HStack(spacing: 4) {
                    Menu {
                        ForEach(FleetGroupMode.allCases, id: \.self) { option in
                            Button(option.rawValue) { groupMode = option }
                        }
                    } label: {
                        CardFilterChip(title: groupMode.rawValue)
                    }
                    Menu {
                        ForEach(FleetDisplayMode.allCases, id: \.self) { option in
                            Button(option.rawValue) { displayMode = option }
                        }
                    } label: {
                        CardFilterChip(title: displayMode.rawValue)
                    }
                }
                .tint(.primary)
            }

            if data.isEmpty {
                ContentUnavailableView("No Data", systemImage: "airplane")
                    .frame(height: 160)
            } else {
                donutChart

                if showAll && !overflowData.isEmpty {
                    overflowBars
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }

    // MARK: - Donut + legend (always visible)

    private var donutChart: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Chart(Array(chartData.enumerated()), id: \.element.id) { index, item in
                        SectorMark(
                            angle: .value(
                                displayMode == .hours ? "Hours" : "Flights",
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
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Text("HRS")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(totalSectors)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Text("FLTS")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 140, height: 140)
                .animation(.spring(response: 0.4), value: displayMode)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(chartData.enumerated()), id: \.element.id) { index, item in
                        legendRow(item: item, index: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.spring(response: 0.4), value: displayMode)
            }

            if hasMore {
                showAllButton
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Overflow bars (below donut when expanded)

    private var overflowBars: some View {
        let maxValue: Double = displayMode == .hours
            ? (sortedData.first?.hours ?? 1)
            : Double(sortedData.first?.sectors ?? 1)

        return VStack(alignment: .leading, spacing: 8) {
            Divider()

            ForEach(Array(overflowData.enumerated()), id: \.element.id) { offset, item in
                let index = offset
                let value: Double = displayMode == .hours ? item.hours : Double(item.sectors)
                let label: String = displayMode == .hours
                    ? String(format: "%.0f", item.hours)
                    : "\(item.sectors)"

                HStack(spacing: 10) {
                    Text(item.aircraftType)
                        .iPadScaledFont(.caption, phoneFont: .footnote)
                        .bold()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize()
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: OverflowMaxWidthKey.self, value: geo.size.width)
                            }
                        )
                        .frame(width: overflowNameWidth > 0 ? overflowNameWidth : nil, alignment: .leading)

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.1))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(fleetColor(at: index))
                            .frame(maxWidth: .infinity)
                            .scaleEffect(x: value / maxValue, anchor: .leading)
                    }
                    .frame(height: 6)
                    .frame(minWidth: 60, maxWidth: .infinity)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayMode)

                    Text(label)
                        .iPadScaledFont(.caption, phoneFont: .footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onPreferenceChange(OverflowMaxWidthKey.self) { overflowNameWidth = $0 }
        .animation(.spring(response: 0.4), value: displayMode)
    }

    // MARK: - Show all button

    private var showAllButton: some View {
        Button {
            withAnimation(.spring(response: 0.35)) { showAll.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(showAll ? "Show Less" : "Show All")
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                Image(systemName: showAll ? "chevron.up" : "chevron.down")
                    .imageScale(.small)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func legendRow(item: NDFleetHours, index: Int) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fleetColor(at: index))
                .frame(width: 10, height: 10)

            Text(item.aircraftType)
                .iPadScaledFont(.caption, phoneFont: .footnote)
                .bold()
                .foregroundStyle(.primary)

            Spacer()

            Text(displayMode == .hours
                 ? String(format: "%.0f hrs", item.hours)
                 : "\(item.sectors)")
                .iPadScaledFont(.caption, phoneFont: .footnote)
                .foregroundStyle(.secondary)
        }
    }
}
