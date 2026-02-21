//
//  PFRatioCard.swift
//  Block-Time
//
//  Line chart showing Pilot Flying ratio trend over time.
//

import SwiftUI
import Charts

struct PFRatioCard: View {
    let data: [NDMonthlyPFRatio]

    @State private var selectedMonths = 12

    private var filtered: [NDMonthlyPFRatio] {
        guard selectedMonths > 0 else { return data }
        let cutoff = Calendar.current.date(byAdding: .month, value: -selectedMonths, to: Date()) ?? Date()
        return data.filter { $0.month >= cutoff }
    }

    private var averagePF: Double {
        guard !filtered.isEmpty else { return 0 }
        return filtered.reduce(0) { $0 + $1.pfRatio } / Double(filtered.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("PF Ratio Trend", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $selectedMonths) {
                    Text("12M").tag(12)
                    Text("2Y").tag(24)
                    Text("All").tag(0)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            if filtered.isEmpty {
                ContentUnavailableView("No Data", systemImage: "airplane.slash")
                    .frame(height: 160)
            } else {
                Chart {
                    // Area fill
                    ForEach(filtered) { item in
                        AreaMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("PF %", item.pfRatio * 100)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    }

                    // Line
                    ForEach(filtered) { item in
                        LineMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("PF %", item.pfRatio * 100)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    // Average reference line
                    RuleMark(y: .value("Avg", averagePF * 100))
                        .foregroundStyle(Color.orange.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("Avg \(Int(averagePF * 100))%")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: filtered.count > 18 ? 3 : 1)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text("\(Int(v))%") }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)
                .animation(.spring(response: 0.4), value: selectedMonths)
            }

            // Summary
            HStack {
                statChip(label: "Average PF", value: String(format: "%.0f%%", averagePF * 100), color: .blue)
                Spacer()
                let totalSectors = filtered.reduce(0) { $0 + $1.totalSectors }
                statChip(label: "Sectors", value: "\(totalSectors)", color: .secondary)
            }
        }
        .padding(16)
        .appCardStyle()
    }

    @ViewBuilder
    private func statChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption).fontWeight(.semibold).foregroundStyle(color)
        }
    }
}
