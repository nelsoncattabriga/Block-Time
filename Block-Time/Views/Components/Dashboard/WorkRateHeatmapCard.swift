//
//  WorkRateHeatmapCard.swift
//  Block-Time
//
//  Rate-of-work heatmap.
//  1M → daily grid (Mon–Sun columns, 5-week rows).
//  12M / 5Y → year × month grid.
//  Cells fill the card width dynamically.
//

import SwiftUI

// MARK: - Period

private enum HeatmapPeriod: String, CaseIterable {
    case oneMonth     = "1M"
    case twelveMonths = "12M"
    case fiveYears    = "5Y"
}

// MARK: - Card

struct WorkRateHeatmapCard: View {
    let monthlyActivity: [NDMonthlyActivity]
    let dailyActivity: [NDDailyActivity]

    @State private var period: HeatmapPeriod = .oneMonth

    private let accentColor       = Color.orange
    private let spacing: CGFloat  = 3
    private let labelWidth: CGFloat = 36
    private let cellHeightMonthly: CGFloat = 18
    private let cellHeightDaily: CGFloat   = 28
    private let dayLabels   = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
    private let monthLabels = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    // MARK: - Derived data

    private var filteredMonthly: [NDMonthlyActivity] {
        let cal = Calendar.current
        let now = Date()
        guard let nowMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
            return monthlyActivity
        }
        switch period {
        case .oneMonth:
            return []
        case .twelveMonths:
            guard let cutoff = cal.date(byAdding: .month, value: -11, to: nowMonthStart) else {
                return monthlyActivity
            }
            return monthlyActivity.filter { $0.month >= cutoff }
        case .fiveYears:
            guard let cutoff = cal.date(byAdding: .month, value: -59, to: nowMonthStart) else {
                return monthlyActivity
            }
            return monthlyActivity.filter { $0.month >= cutoff }
        }
    }

    private var yearsInRange: [Int] {
        let cal = Calendar.current
        return Array(Set(filteredMonthly.map { cal.component(.year, from: $0.month) })).sorted()
    }

    private var maxHours: Double {
        switch period {
        case .oneMonth:
            return max(dailyActivity.map { $0.totalHours }.max() ?? 1, 1)
        default:
            return max(filteredMonthly.map { $0.totalHours }.max() ?? 1, 1)
        }
    }

    private var heatmapHeight: CGFloat {
        let labelRow: CGFloat = 14 + spacing
        switch period {
        case .oneMonth:
            return labelRow + 5 * cellHeightDaily + 4 * spacing
        default:
            let rows = CGFloat(max(yearsInRange.count, 1))
            return labelRow + rows * cellHeightMonthly + (rows - 1) * spacing
        }
    }

    // MARK: - Helpers

    private func cellColor(hours: Double) -> Color {
        guard hours > 0 else { return Color.secondary.opacity(0.08) }
        let intensity = min(hours / maxHours, 1.0)
        return accentColor.opacity(0.18 + intensity * 0.78)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Work Rate", icon: "chart.bar.xaxis", iconColor: accentColor) {
                Picker("Period", selection: $period) {
                    ForEach(HeatmapPeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            if isEmpty {
                emptyState
            } else {
                GeometryReader { geo in
                    Group {
                        if period == .oneMonth {
                            dailyHeatmap(width: geo.size.width)
                        } else {
                            monthlyHeatmap(width: geo.size.width)
                        }
                    }
                }
                .frame(height: heatmapHeight)

                summaryRow
            }
        }
        .padding(16)
        .appCardStyle()
    }

    private var isEmpty: Bool {
        switch period {
        case .oneMonth:     return dailyActivity.isEmpty
        default:            return filteredMonthly.isEmpty
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Flight Data",
            systemImage: "airplane.slash",
            description: Text("Log flights to see your activity")
        )
        .frame(height: 100)
    }

    // MARK: - Daily Heatmap (1M)

    /// 35-day window: the Monday 4 complete weeks before this week's Monday → this week's Sunday.
    private var calendarDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1=Sun … 7=Sat
        let daysFromMonday = (weekday + 5) % 7             // Mon=0 … Sun=6
        guard let startMonday = cal.date(byAdding: .day, value: -(daysFromMonday + 28), to: today) else {
            return []
        }
        return (0..<35).compactMap { cal.date(byAdding: .day, value: $0, to: startMonday) }
    }

    private func dailyHours(for day: Date) -> Double {
        let cal = Calendar.current
        return dailyActivity.first(where: { cal.isDate($0.day, inSameDayAs: day) })?.totalHours ?? 0
    }

    @ViewBuilder
    private func dailyHeatmap(width: CGFloat) -> some View {
        let cellW = (width - spacing * 6) / 7
        let days  = calendarDays
        let today = Calendar.current.startOfDay(for: Date())

        VStack(alignment: .leading, spacing: spacing) {
            // Day-of-week labels
            HStack(spacing: spacing) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: cellW, alignment: .center)
                }
            }
            .frame(height: 14)

            // Week rows
            ForEach(0..<5, id: \.self) { week in
                HStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { dayIdx in
                        let day     = days[week * 7 + dayIdx]
                        let isFuture = day > today
                        let h = isFuture ? 0.0 : dailyHours(for: day)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isFuture ? Color.clear : cellColor(hours: h))
                            .frame(width: cellW, height: cellHeightDaily)
                    }
                }
            }
        }
    }

    // MARK: - Monthly Heatmap (12M / 5Y)

    private func monthHours(year: Int, month: Int) -> Double {
        let cal = Calendar.current
        return filteredMonthly.first(where: {
            cal.component(.year,  from: $0.month) == year &&
            cal.component(.month, from: $0.month) == month
        })?.totalHours ?? 0
    }

    @ViewBuilder
    private func monthlyHeatmap(width: CGFloat) -> some View {
        let cellW = (width - labelWidth - spacing * 12) / 12
        let years = yearsInRange

        VStack(alignment: .leading, spacing: spacing) {
            // Month header
            HStack(spacing: spacing) {
                Color.clear.frame(width: labelWidth)
                ForEach(0..<12, id: \.self) { i in
                    Text(monthLabels[i])
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: cellW, alignment: .center)
                }
            }
            .frame(height: 14)

            // Year rows
            ForEach(years, id: \.self) { year in
                HStack(spacing: spacing) {
                    Text(String(year))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth, alignment: .leading)

                    ForEach(1...12, id: \.self) { month in
                        let h = monthHours(year: year, month: month)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cellColor(hours: h))
                            .frame(width: cellW, height: cellHeightMonthly)
                    }
                }
            }
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack {
            summaryLabel
            Spacer()
            legendView
        }
    }

    @ViewBuilder
    private var summaryLabel: some View {
        switch period {
        case .oneMonth:
            let total  = dailyActivity.reduce(0.0) { $0 + $1.totalHours }
            let active = dailyActivity.filter { $0.totalHours > 0 }.count
            Label("\(total.formatted(.number.precision(.fractionLength(0)))) hrs · \(active) active days", systemImage: "airplane")
                .font(.caption).foregroundStyle(.secondary)
        default:
            let total  = filteredMonthly.reduce(0.0) { $0 + $1.totalHours }
            let active = filteredMonthly.filter { $0.totalHours > 0 }.count
            Label("\(total.formatted(.number.precision(.fractionLength(0)))) hrs · \(active) months", systemImage: "airplane")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var legendView: some View {
        HStack(spacing: 3) {
            Text("Less").font(.system(size: 9)).foregroundStyle(.secondary)
            ForEach([0.1, 0.3, 0.55, 0.8, 1.0], id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor.opacity(0.18 + i * 0.78))
                    .frame(width: 10, height: 10)
            }
            Text("More").font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}
