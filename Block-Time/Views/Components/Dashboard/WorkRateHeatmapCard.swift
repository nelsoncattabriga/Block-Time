//
//  WorkRateHeatmapCard.swift
//  Block-Time
//
//  Rate-of-work heatmap.
//  28D / 56D → raw daily grid (7 cols, 4 or 8 rows), no weekday alignment.
//  5Y → year × month grid.
//

import SwiftUI

// MARK: - Period

private enum HeatmapPeriod: String, CaseIterable {
    case twentyEightDays = "28 Days"
    case fiftyFiveDays   = "56 Days"
    case fiveYears       = "5 Years"
}

// MARK: - Card

struct WorkRateHeatmapCard: View {
    let monthlyActivity: [NDMonthlyActivity]
    let dailyActivity: [NDDailyActivity]

    @AppStorage("workRateCard_period") private var period: HeatmapPeriod = .twentyEightDays

    private let accentColor          = Color.orange
    private let spacing: CGFloat     = 3
    private let labelWidth: CGFloat  = 18
    private let cellHeightMonthly: CGFloat = 28
    private let cellHeightDaily: CGFloat   = 28
    private let dateStripHeight: CGFloat   = 14
    private let monthLabels = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    private static let dateStripFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd"
        return f
    }()

    // MARK: - Derived data

    private var dayCount: Int {
        period == .fiftyFiveDays ? 56 : 28
    }

    private var rowCount: Int { dayCount / 7 }

    private var calendarDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(dayCount - 1), to: today) else { return [] }
        return (0..<dayCount).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var filteredMonthly: [NDMonthlyActivity] {
        guard period == .fiveYears else { return [] }
        let cal = Calendar.current
        let now = Date()
        guard let nowMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let cutoff = cal.date(byAdding: .month, value: -59, to: nowMonthStart) else {
            return monthlyActivity
        }
        return monthlyActivity.filter { $0.month >= cutoff }
    }

    private var yearsInRange: [Int] {
        let cal = Calendar.current
        return Array(Set(filteredMonthly.map { cal.component(.year, from: $0.month) })).sorted()
    }

    private var maxHours: Double {
        switch period {
        case .twentyEightDays, .fiftyFiveDays:
            return max(dailyActivity.map { $0.totalHours }.max() ?? 1, 1)
        case .fiveYears:
            return max(filteredMonthly.map { $0.totalHours }.max() ?? 1, 1)
        }
    }

    private var heatmapHeight: CGFloat {
        switch period {
        case .twentyEightDays, .fiftyFiveDays:
            let rowHeight = cellHeightDaily + spacing + dateStripHeight
            return CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * spacing
        case .fiveYears:
            let labelRow: CGFloat = 14 + spacing
            let rows = CGFloat(max(yearsInRange.count, 1))
            return labelRow + rows * cellHeightMonthly + (rows - 1) * spacing
        }
    }

    private var isEmpty: Bool {
        switch period {
        case .twentyEightDays, .fiftyFiveDays: return dailyActivity.isEmpty
        case .fiveYears:                        return filteredMonthly.isEmpty
        }
    }

    // MARK: - Helpers

    private func cellColor(hours: Double) -> Color {
        guard hours > 0 else { return Color.secondary.opacity(0.08) }
        let intensity = min(hours / maxHours, 1.0)
        return accentColor.opacity(0.18 + intensity * 0.78)
    }

    private func dailyHours(for day: Date) -> Double {
        let cal = Calendar.current
        return dailyActivity.first(where: { cal.isDate($0.day, inSameDayAs: day) })?.totalHours ?? 0
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Work Rate", icon: "chart.bar.xaxis", iconColor: .purple) {
                Menu {
                    ForEach(HeatmapPeriod.allCases, id: \.self) { option in
                        Button(option.rawValue) { period = option }
                    }
                } label: {
                    CardFilterChip(title: period.rawValue)
                }
                .tint(.primary)
            }

            if isEmpty {
                emptyState
            } else {
                GeometryReader { geo in
                    Group {
                        if period == .fiveYears {
                            monthlyHeatmap(width: geo.size.width)
                        } else {
                            dailyHeatmap(width: geo.size.width)
                        }
                    }
                }
                .frame(height: heatmapHeight)
                
                Text("UTC Departure Date")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)

                summaryRow
            }
        }
        .padding(16)
        .appCardStyle()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Flight Data",
            systemImage: "airplane",
            description: Text("Log flights to see your activity")
        )
        .frame(height: 100)
    }

    // MARK: - Daily Heatmap (28D / 56D)

    @ViewBuilder
    private func dailyHeatmap(width: CGFloat) -> some View {
        let cellW = (width - spacing * 6) / 7
        let days  = calendarDays

        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                VStack(alignment: .leading, spacing: spacing) {
                    HStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = days[row * 7 + col]
                            let h   = dailyHours(for: day)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cellColor(hours: h))
                                .frame(width: cellW, height: cellHeightDaily)
                        }
                    }
                    // Date strip
                    HStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { col in
                            let day     = days[row * 7 + col]
                            let isToday = Calendar.current.isDateInToday(day)
                            Text(Self.dateStripFormatter.string(from: day))
                                .font(.caption2)
                                .foregroundStyle(isToday ? accentColor : Color.secondary.opacity(0.8))
                                .fontWeight(isToday ? .semibold : .regular)
                                .frame(width: cellW, alignment: .center)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                    }
                    .frame(height: dateStripHeight)
                }
            }
        }
    }

    // MARK: - Monthly Heatmap (5Y)

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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: cellW, alignment: .center)
                }
            }
            .frame(height: 14)

            // Year rows
            ForEach(years, id: \.self) { year in
                HStack(spacing: spacing) {
                    Text(String(format: "%02d", year % 100))
                        .font(.caption)
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
        case .twentyEightDays, .fiftyFiveDays:
            let days   = calendarDays
            //let total  = days.reduce(0.0) { $0 + dailyHours(for: $1) }
            let active = days.filter { dailyHours(for: $0) > 0 }.count
            Label(String(format: "%d active days", active), systemImage: "airplane")
                .iPadScaledFont(.caption2, phoneFont: .footnote).foregroundStyle(.secondary)
        case .fiveYears:
            //let total  = filteredMonthly.reduce(0.0) { $0 + $1.totalHours }
            let active = filteredMonthly.filter { $0.totalHours > 0 }.count
            Label(String(format: "%d active months", active), systemImage: "airplane")
                .iPadScaledFont(.caption2, phoneFont: .footnote).foregroundStyle(.secondary)
        }
    }

    private var legendView: some View {
        HStack(spacing: 3) {
            Text("Less").font(.caption2).foregroundStyle(.secondary)
            ForEach([0.1, 0.3, 0.55, 0.8, 1.0], id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor.opacity(0.18 + i * 0.78))
                    .frame(width: 10, height: 10)
            }
            Text("More").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
