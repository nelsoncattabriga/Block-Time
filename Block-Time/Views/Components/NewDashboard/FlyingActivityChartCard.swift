//
//  FlyingActivityChartCard.swift
//  Block-Time
//
//  Monthly flying activity bar chart with time-range picker.
//

import SwiftUI
import Charts

private enum DisplayMode: String, CaseIterable {
    case hours = "Hours"
    case sectors = "Sectors"
}

private struct ChartBar: Identifiable {
    let id = UUID()
    let month: Date
    let value: Double
}

struct FlyingActivityChartCard: View {
    let data: [NDMonthlyActivity]

    @State private var selectedMonths = 12
    @State private var displayMode: DisplayMode = .hours

    private var filtered: [NDMonthlyActivity] {
        guard selectedMonths > 0 else { return data }
        let cutoff = Calendar.current.date(byAdding: .month, value: -selectedMonths, to: Date()) ?? Date()
        return data.filter { $0.month >= cutoff }
    }

    private var chartData: [ChartBar] {
        filtered.map { item in
            let value = displayMode == .hours ? item.blockHours : Double(item.sectorCount)
            return ChartBar(month: item.month, value: value)
        }
    }

    private var axisStride: Calendar.Component { .month }
    private var axisCount: Int { filtered.count > 18 ? 3 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Flying Activity", icon: "chart.bar.fill") {
                Picker("", selection: $selectedMonths) {
                    Text("6M").tag(6)
                    Text("12M").tag(12)
                    Text("5Y").tag(60)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            Picker("Display", selection: $displayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "airplane.slash",
                    description: Text("No flights recorded in this period")
                )
                .frame(height: 180)
            } else {
                Chart(chartData) { item in
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value(displayMode == .hours ? "Hours" : "Sectors", item.value)
                    )
                    .foregroundStyle(displayMode == .hours ? Color.blue.gradient : Color.orange.gradient)
                    .cornerRadius(3)
                }
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: axisStride, count: axisCount)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
                .animation(.spring(response: 0.4), value: selectedMonths)
                .animation(.spring(response: 0.4), value: displayMode)
            }

            // Summary row
            if !filtered.isEmpty {
                if displayMode == .hours {
                    let totalBlock = filtered.reduce(0) { $0 + $1.blockHours }
                    let avg = totalBlock / Double(filtered.count)
                    HStack {
                        summaryChip(label: "Monthly Avg", value: String(format: "%.1f hrs", avg), color: .blue)
                        Spacer()
                        summaryChip(label: "Period Total", value: String(format: "%.1f hrs", totalBlock), color: .blue)
                    }
                } else {
                    let totalSectors = filtered.reduce(0) { $0 + $1.sectorCount }
                    let avg = Double(totalSectors) / Double(filtered.count)
                    HStack {
                        summaryChip(label: "Monthly Avg", value: String(format: "%.0f sectors", avg), color: .orange)
                        Spacer()
                        summaryChip(label: "Period Total", value: "\(totalSectors) sectors", color: .orange)
                    }
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }

    @ViewBuilder
    private func summaryChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.footnote).fontWeight(.semibold).foregroundStyle(color)
        }
    }
}
