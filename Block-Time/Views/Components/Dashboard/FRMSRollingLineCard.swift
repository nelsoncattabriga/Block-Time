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
    case flight28  = "28 Days Flt"
    case flight365 = "365 Days Flt"
    case duty7     = "7 Days Duty"
    case duty14    = "14 Days Duty"
}

// MARK: - Card

struct FRMSRollingLineCard: View {
    let data: NDFRMSRollingData

    @AppStorage("frmsRollingLine_limit") private var selectedLimit: FRMSRollingLimit = .flight28
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var series: NDFRMSRollingSeries {
        switch selectedLimit {
        case .flight28:  return data.flight28d
        case .flight365: return data.flight365d
        case .duty7:     return data.duty7d
        case .duty14:    return data.duty14d
        }
    }

    private var actualPoints: [NDFRMSRollingPoint] {
        var pts = series.points.filter { !$0.isProjected }
        // Ensure the last actual point lands exactly on today so the area fill
        // reaches the Today marker regardless of when the last flight was.
        let todayStart = Calendar.current.startOfDay(for: Date())
        if let last = pts.last, !Calendar.current.isDate(last.date, inSameDayAs: todayStart) {
            pts.append(NDFRMSRollingPoint(date: todayStart, total: last.total, isProjected: false))
        }
        return pts
    }

    private var projectedPoints: [NDFRMSRollingPoint] {
        // Include the last actual point as the join so the lines connect
        let last = actualPoints.last
        let future = series.points.filter { $0.isProjected }
        if let last { return [last] + future }
        return future
    }

    private var hasProjected: Bool { !projectedPoints.isEmpty }

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
                limitPicker
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

    // MARK: - Limit Picker

    private var limitPicker: some View {
        Picker("", selection: $selectedLimit) {
            ForEach(FRMSRollingLimit.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    // MARK: - Chart

    private var isCompact: Bool { sizeClass == .compact }

    // x-axis stride adapts to both the selected limit and available width
    private var xAxisStride: Calendar.Component {
        switch selectedLimit {
        case .duty7:     return .day
        case .duty14:    return .day
        case .flight28:  return .weekOfYear
        case .flight365: return .month
        }
    }

    private var xAxisStrideCount: Int {
        switch selectedLimit {
        case .duty7:     return isCompact ? 2 : 1   // compact: every 2 days; wide: every day
        case .duty14:    return isCompact ? 4 : 2   // compact: every 4 days; wide: every 2 days
        case .flight28:  return 1                   // weekly ticks work fine at all widths
        case .flight365: return isCompact ? 3 : 2   // compact: every 3 months; wide: every 2 months
        }
    }

    private var xAxisLabelFormat: Date.FormatStyle {
        switch selectedLimit {
        case .duty7:              return .dateTime.day().month(.abbreviated)
        case .duty14:             return isCompact ? .dateTime.day().month(.narrow) : .dateTime.day().month(.abbreviated)
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
            AxisMarks(values: .stride(by: xAxisStride, count: xAxisStrideCount)) {
                AxisGridLine()
                AxisValueLabel(format: xAxisLabelFormat, centered: true)
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

    private var summaryRow: some View {
        HStack {
            summaryChip(
                label: "Now",
                value: String(format: "%.1f hrs", currentTotal),
                color: statusColor
            )
            Spacer()
            if hasProjected && peakProjected > currentTotal {
                summaryChip(
                    label: "Peak (rostered)",
                    value: String(format: "%.1f hrs", peakProjected),
                    color: projectedColor
                )
                Spacer()
            }
            summaryChip(
                label: "Limit",
                value: String(format: "%.0f hrs", series.limit),
                color: .secondary
            )
        }
    }

    private func summaryChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}
