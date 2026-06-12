//
//  FlyingActivityChartCard.swift
//  Block-Time
//
//  Monthly flying activity bar chart with time-range picker.
//

import SwiftUI
import Charts
import BlockTimeKit

private enum DisplayMode: String, CaseIterable {
    case hours = "Hours"
    case sectors = "Flights"
}

private enum ChartMonths: String, CaseIterable, RawRepresentable {
    case six = "6 Months"
    case twelve = "12 Months"
    case fiveYear = "5 Years"
    var intValue: Int {
        switch self { case .six: return 6; case .twelve: return 12; case .fiveYear: return 60 }
    }
}

private struct ChartBar: Identifiable {
    let id = UUID()
    let month: Date
    let value: Double
}

struct FlyingActivityChartCard: View {
    let data: [NDMonthlyActivity]

    @AppStorage("flyingActivityCard_months") private var chartMonths: ChartMonths = .twelve
    @AppStorage("flyingActivityCard_displayMode") private var displayMode: DisplayMode = .hours
    @AppStorage("showTimesInHoursMinutes") private var showTimesInHoursMinutes = false

    @State private var chartData: [ChartBar] = []
    @State private var axisCount: Int = 1
    @State private var totalValue: Double = 0
    @State private var avgValue: Double = 0

    private var axisStride: Calendar.Component { .month }

    private func recompute() {
        let cutoff = Calendar.current.date(byAdding: .month, value: -chartMonths.intValue, to: Date()) ?? Date()
        let filtered = data.filter { $0.month >= cutoff }
        axisCount = filtered.count > 18 ? 3 : 1
        chartData = filtered.map { item in
            let value = displayMode == .hours ? item.blockHours : Double(item.sectorCount)
            return ChartBar(month: item.month, value: value)
        }
        let total = displayMode == .hours
            ? filtered.reduce(0) { $0 + $1.blockHours }
            : Double(filtered.reduce(0) { $0 + $1.sectorCount })
        totalValue = total
        avgValue = filtered.isEmpty ? 0 : total / Double(filtered.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Flying Activity", icon: "chart.bar.fill", iconColor: .purple) {
                HStack(spacing: 4) {
                    Menu {
                        ForEach(ChartMonths.allCases, id: \.self) { option in
                            Button(option.rawValue) { chartMonths = option }
                        }
                    } label: {
                        CardFilterChip(title: chartMonths.rawValue)
                    }
                    Menu {
                        ForEach(DisplayMode.allCases, id: \.self) { option in
                            Button(option.rawValue) { displayMode = option }
                        }
                    } label: {
                        CardFilterChip(title: displayMode.rawValue)
                    }
                }
                .tint(.primary)
            }

            if chartData.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "airplane",
                    description: Text("No flights recorded in this period")
                )
                .frame(height: 180)
            } else {
                Chart(chartData) { item in
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value(displayMode == .hours ? "Hours" : "Flights", item.value)
                    )
                    .foregroundStyle(Color.blue.gradient)
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
                .animation(.spring(response: 0.4), value: chartMonths)
                .animation(.spring(response: 0.4), value: displayMode)
            }

            if !chartData.isEmpty {
                if displayMode == .hours {
                    HStack {
                        summaryChip(label: "Monthly Avg", value: formatHours(avgValue), color: .blue)
                        Spacer()
                        summaryChip(label: "Period Total", value: formatHours(totalValue), color: .blue)
                    }
                } else {
                    HStack {
                        summaryChip(label: "Monthly Avg", value: String(format: "%.0f flights", avgValue), color: .blue)
                        Spacer()
                        summaryChip(label: "Period Total", value: "\(Int(totalValue)) flights", color: .blue)
                    }
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { recompute() }
        .onChange(of: chartMonths) { recompute() }
        .onChange(of: displayMode) { recompute() }
        .onChange(of: data.count) { recompute() }
    }

    private func formatHours(_ h: Double) -> String {
        showTimesInHoursMinutes ? FlightSector.decimalToHHMM(h) : String(format: "%.1f hrs", h)
    }

    @ViewBuilder
    private func summaryChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).iPadScaledFont(.caption).foregroundStyle(.secondary)
            Text(value).iPadScaledFont(.footnote).fontWeight(.semibold).foregroundStyle(color)
        }
    }
}
