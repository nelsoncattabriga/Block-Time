//
//  RoleDistributionCard.swift
//  Block-Time
//
//  Stacked monthly bar chart showing P1 / ICUS / F/O time split.
//

import SwiftUI
import Charts

struct RoleDistributionCard: View {
    let data: [NDMonthlyRoleHours]

    @State private var selectedMonths = 12

    private var filtered: [NDMonthlyRoleHours] {
        guard selectedMonths > 0 else { return data }
        let cutoff = Calendar.current.date(byAdding: .month, value: -selectedMonths, to: Date()) ?? Date()
        return data.filter { $0.month >= cutoff }
    }

    private let roleColors: KeyValuePairs<String, Color> = [
        "Captain": .blue,
        "ICUS":    .orange,
        "F/O":     .green
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Role Distribution", systemImage: "person.3.fill")
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
                ContentUnavailableView(
                    "No Data",
                    systemImage: "person.slash",
                    description: Text("No role data in this period")
                )
                .frame(height: 180)
            } else {
                Chart(filtered) { item in
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(by: .value("Role", item.role))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale([
                    "Captain": Color.blue,
                    "ICUS":    Color.orange,
                    "F/O":     Color.green
                ])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: filtered.count > 18 ? 3 : 1)) { _ in
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
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 200)
                .animation(.spring(response: 0.4), value: selectedMonths)
            }

            // Career totals summary
            careerTotals
        }
        .padding(16)
        .appCardStyle()
    }

    private func hoursForRole(_ role: String) -> Double {
        data.filter { $0.role == role }.reduce(0.0) { acc, item in acc + item.hours }
    }
    private var captainHrs: Double { hoursForRole("Captain") }
    private var icusHrs: Double    { hoursForRole("ICUS") }
    private var foHrs: Double      { hoursForRole("F/O") }
    private var roleTotal: Double  { captainHrs + icusHrs + foHrs }

    @ViewBuilder
    private var careerTotals: some View {
        if roleTotal > 0 {
            HStack(spacing: 12) {
                rolePill(label: "Captain", hours: captainHrs, total: roleTotal, color: .blue)
                rolePill(label: "ICUS",    hours: icusHrs,    total: roleTotal, color: .orange)
                rolePill(label: "F/O",     hours: foHrs,      total: roleTotal, color: .green)
            }
        }
    }

    @ViewBuilder
    private func rolePill(label: String, hours: Double, total: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "%.0f", hours))
                .font(.caption).fontWeight(.bold).foregroundStyle(color)
            Text(String(format: "%.0f%%", hours / total * 100))
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
