//
//  ActivityChartCard.swift
//  Block-Time
//
//  Monthly flying activity bar chart with time-range picker.
//

import SwiftUI
import Charts

private struct StackedBar: Identifiable {
    let id = UUID()
    let month: Date
    let series: String
    let hours: Double
}

struct ActivityChartCard: View {
    let data: [NDMonthlyActivity]

    @State private var selectedMonths = 12
    @State private var showSIM = false

    private var filtered: [NDMonthlyActivity] {
        guard selectedMonths > 0 else { return data }
        let cutoff = Calendar.current.date(byAdding: .month, value: -selectedMonths, to: Date()) ?? Date()
        return data.filter { $0.month >= cutoff }
    }

    private var stackedData: [StackedBar] {
        filtered.flatMap { item -> [StackedBar] in
            var bars: [StackedBar] = [StackedBar(month: item.month, series: "Block", hours: item.blockHours)]
            if showSIM && item.simHours > 0 {
                bars.append(StackedBar(month: item.month, series: "SIM", hours: item.simHours))
            }
            return bars
        }
    }

    private var axisStride: Calendar.Component { .month }
    private var axisCount: Int { filtered.count > 18 ? 3 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Flying Activity", systemImage: "chart.bar.fill")
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $selectedMonths) {
                    Text("12M").tag(12)
                    Text("6M").tag(6)
                    Text("All").tag(0)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            Toggle("Include SIM", isOn: $showSIM)
                .font(.caption)
                .foregroundStyle(.secondary)
                .tint(.cyan)

            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "airplane.slash",
                    description: Text("No flights recorded in this period")
                )
                .frame(height: 180)
            } else {
                Chart(stackedData) { item in
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(by: .value("Series", item.series))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale(["Block": Color.blue.gradient, "SIM": Color.cyan.gradient])
                .chartLegend(showSIM ? .visible : .hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: axisStride, count: axisCount)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
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
                .animation(.spring(response: 0.4), value: showSIM)
            }

            // Summary row
            if !filtered.isEmpty {
                let totalBlock = filtered.reduce(0) { $0 + $1.blockHours }
                let avg = totalBlock / Double(filtered.count)
                HStack {
                    summaryChip(label: "Total", value: String(format: "%.0f hrs", totalBlock), color: .blue)
                    Spacer()
                    summaryChip(label: "Monthly Avg", value: String(format: "%.1f hrs", avg), color: .secondary)
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }

    @ViewBuilder
    private func summaryChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption).fontWeight(.semibold).foregroundStyle(color)
        }
    }
}
