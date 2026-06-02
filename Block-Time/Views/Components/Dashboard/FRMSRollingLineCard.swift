//
//  FRMSRollingLineCard.swift
//  Block-Time
//
//  Option 1: Rolling-total line/area chart for FRMS limits.
//
//  Shows the rolling total (e.g. 28-day flight hours) as a continuous
//  area + line over the past 90 days, transitioning to a dashed projected
//  line for future rostered duties.
//
//  A horizontal limit line and shaded warning band give immediate
//  risk context without needing to read numbers.
//
//  Limit picker: 28d Flight / 365d Flight / 7d Duty / 14d Duty (+ 7d Flight for LH)
//

import SwiftUI
import Charts

// MARK: - Limit selector (shared with FRMSRollingBarsCard)

enum FRMSRollingLimit: String, CaseIterable {
    case flight7   = "FLT - 7 Days"
    case flight28  = "FLT - 28 Days"
    case flight365 = "FLT - 365 Days"
    case duty7     = "DUTY - 7 Days"
    case duty14    = "DUTY - 14 Days"
}

// MARK: - Card

struct FRMSRollingLineCard: View {
    let data: NDFRMSRollingData

    @AppStorage("frmsRollingLine_limit") private var selectedLimit: FRMSRollingLimit = .flight28
    @AppStorage("showTimesInHoursMinutes") private var showTimesInHoursMinutes = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var series: NDFRMSRollingSeries {
        switch selectedLimit {
        case .flight7:   return data.flight7d ?? data.flight28d
        case .flight28:  return data.flight28d
        case .flight365: return data.flight365d
        case .duty7:     return data.duty7d
        case .duty14:    return data.duty14d
        }
    }

    private var actualPoints: [NDFRMSRollingPoint] {
        series.points.filter { !$0.isProjected }
    }

    private var projectedPoints: [NDFRMSRollingPoint] {
        // Include the last actual point as the join so the lines connect
        let last = actualPoints.last
        let future = series.points.filter { $0.isProjected }
        if let last { return [last] + future }
        return future
    }

    private var hasProjected: Bool { series.points.contains { $0.isProjected } }

    private var currentTotal: Double { actualPoints.last?.total ?? 0 }
    private var peakProjected: Double { projectedPoints.map(\.total).max() ?? 0 }

    private var yMax: Double {
        let dataMax = series.points.map(\.total).max() ?? 0
        return max(dataMax, series.limit) * 1.05
    }

    // Color for the current total
    private var statusColor: Color {
        let r = series.limit > 0 ? currentTotal / series.limit : 0
        if r >= 1.0 { return .red }
        if r >= series.warnAt / series.limit { return .orange }
        return .blue
    }

    private var projectedColor: Color {
        let r = series.limit > 0 ? peakProjected / series.limit : 0
        if r >= 1.0 { return .red }
        if r >= series.warnAt / series.limit { return .orange }
        return .teal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            CardHeader(title: "FRMS Rolling Total", icon: "chart.line.uptrend.xyaxis", iconColor: .blue) {
                Menu {
                    ForEach(availableLimits, id: \.self) { option in
                        Button(label(for: option)) { selectedLimit = option }
                    }
                } label: {
                    CardFilterChip(title: label(for: selectedLimit))
                }
                .tint(.primary)
                .onChange(of: data.flight7d == nil) { _, isNil in
                    if isNil && selectedLimit == .flight7 {
                        selectedLimit = .flight28
                    }
                }
            }

            if series.points.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(height: 180)
            } else {
                chart
                    .frame(height: 180)

                summaryRow
            }
        }
        .padding(16)
        .appCardStyle()
    }

    // MARK: - Limit helpers

    private func label(for limit: FRMSRollingLimit) -> String {
        if limit == .flight28 {
            return "FLT - \(data.flight28d.fleet.flightTimePeriodDays) Days"
        }
        return limit.rawValue
    }

    private var availableLimits: [FRMSRollingLimit] {
        FRMSRollingLimit.allCases.filter { $0 != .flight7 || data.flight7d != nil }
    }

    // MARK: - Chart

    private var isCompact: Bool { sizeClass == .compact }

    // x-axis stride adapts to both the selected limit and available width
    private var xAxisStride: Calendar.Component {
        switch selectedLimit {
        case .flight7:   return .day
        case .duty7:     return .day
        case .duty14:    return .day
        case .flight28:  return .weekOfYear
        case .flight365: return .month
        }
    }

    private var xAxisStrideCount: Int {
        switch selectedLimit {
        case .flight7:   return isCompact ? 2 : 1
        case .duty7:     return isCompact ? 2 : 1   // compact: every 2 days; wide: every day
        case .duty14:    return isCompact ? 4 : 2   // compact: every 4 days; wide: every 2 days
        case .flight28:  return 1                   // weekly ticks work fine at all widths
        case .flight365: return isCompact ? 3 : 2   // compact: every 3 months; wide: every 2 months
        }
    }

    private var xAxisLabelFormat: Date.FormatStyle {
        switch selectedLimit {
        case .flight7:            return .dateTime.day().month(.abbreviated)
        case .duty7:              return .dateTime.day().month(.abbreviated)
        case .duty14:             return .dateTime.day()   // month shown separately in custom label
        case .flight28:           return .dateTime.day().month(.abbreviated)
        case .flight365:          return .dateTime.month(.abbreviated)
        }
    }

    private var chart: some View {
        Chart {
            // Warning zone band
            RectangleMark(
                xStart: .value("Start", series.chartStart),
                xEnd: .value("End", series.chartEnd),
                yStart: .value("Warn", series.warnAt),
                yEnd: .value("Limit", series.limit)
            )
            .foregroundStyle(Color.orange.opacity(0.06))

            // Limit line
            RuleMark(y: .value("Limit", series.limit))
                .foregroundStyle(Color.red.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            // Warning threshold line
            RuleMark(y: .value("Warn", series.warnAt))
                .foregroundStyle(Color.orange.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))

            // Actual area fill
            ForEach(actualPoints) { pt in
                AreaMark(
                    x: .value("Date", pt.date),
                    y: .value("Hours", pt.total)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [statusColor.opacity(0.25), statusColor.opacity(0.03)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }

            // Actual line
            ForEach(actualPoints) { pt in
                LineMark(
                    x: .value("Date", pt.date),
                    y: .value("Hours", pt.total)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(statusColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Projected dashed line (joins from last actual point)
            ForEach(projectedPoints) { pt in
                LineMark(
                    x: .value("Date", pt.date),
                    y: .value("Hours", pt.total)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(projectedColor)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }

            // Today marker
            RuleMark(x: .value("Today", Date()))
                .foregroundStyle(Color.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    Text("Today")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
        }
        .chartXScale(domain: series.chartStart...series.chartEnd)
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStride, count: xAxisStrideCount)) { value in
                AxisGridLine()
                if selectedLimit == .duty14, let date = value.as(Date.self) {
                    AxisValueLabel(centered: true) {
                        VStack(spacing: 0) {
                            Text(date.formatted(.dateTime.day()))
                                .font(.caption2)
                            Text(date.formatted(.dateTime.month(.abbreviated)))
                                .font(.caption2)
                                
                        }
                    }
                } else {
                    AxisValueLabel(format: xAxisLabelFormat, centered: true)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYScale(domain: 0...yMax)
    }

    // MARK: - Summary Row

    private func formatHours(_ h: Double) -> String {
        showTimesInHoursMinutes ? FlightSector.decimalToHHMM(h) : String(format: "%.1f hrs", h)
    }

    private var summaryRow: some View {
        HStack {
            summaryChip(
                label: "Now",
                value: formatHours(currentTotal),
                color: statusColor
            )
            Spacer()
            if hasProjected && peakProjected > currentTotal {
                summaryChip(
                    label: "Peak (rostered)",
                    value: formatHours(peakProjected),
                    color: projectedColor
                )
                Spacer()
            }
            summaryChip(
                label: "Limit",
                value: formatHours(series.limit),
                color: .secondary
            )
        }
    }

    private func summaryChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .iPadScaledFont(.caption, phoneFont: .footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}
