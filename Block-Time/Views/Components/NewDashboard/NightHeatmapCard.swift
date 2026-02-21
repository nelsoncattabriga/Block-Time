//
//  NightHeatmapCard.swift
//  Block-Time
//
//  Calendar-style heatmap of night flying hours by month.
//  Rows = years, columns = Jan–Dec, intensity = night hours.
//

import SwiftUI

private let monthAbbreviations = ["J","F","M","A","M","J","J","A","S","O","N","D"]

struct NightHeatmapCard: View {
    let data: [NDMonthlyNight]

    private var years: [Int] {
        let cal = Calendar.current
        return Array(Set(data.map { cal.component(.year, from: $0.month) })).sorted()
    }

    private var maxNight: Double {
        data.map { $0.nightHours }.max() ?? 1
    }

    private func nightHours(year: Int, month: Int) -> Double {
        let cal = Calendar.current
        return data.first(where: {
            cal.component(.year, from: $0.month)  == year &&
            cal.component(.month, from: $0.month) == month
        })?.nightHours ?? 0
    }

    private func cellColor(hours: Double) -> Color {
        guard hours > 0 else { return Color.secondary.opacity(0.08) }
        let intensity = min(hours / maxNight, 1.0)
        return Color.indigo.opacity(0.18 + intensity * 0.78)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Night Flying", systemImage: "moon.stars.fill")
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Spacer()
                // Legend
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                    ForEach([0.1, 0.3, 0.55, 0.8, 1.0], id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.indigo.opacity(0.18 + intensity * 0.78))
                            .frame(width: 12, height: 12)
                    }
                    Text("More")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }

            if data.isEmpty {
                ContentUnavailableView(
                    "No Night Data",
                    systemImage: "moon.slash",
                    description: Text("Log night time to see your heatmap")
                )
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 3) {
                        // Month header
                        HStack(spacing: 3) {
                            Text("").frame(width: 34) // year label placeholder
                            ForEach(0..<12, id: \.self) { i in
                                Text(monthAbbreviations[i])
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .center)
                            }
                        }

                        // Year rows
                        ForEach(years, id: \.self) { year in
                            HStack(spacing: 3) {
                                Text(String(year))
                                    .font(.system(size: 9)).foregroundStyle(.secondary)
                                    .frame(width: 34, alignment: .trailing)

                                ForEach(1...12, id: \.self) { month in
                                    let hrs = nightHours(year: year, month: month)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(cellColor(hours: hrs))
                                        .frame(width: 24, height: 20)
                                        .overlay {
                                            if hrs >= 1 {
                                                Text(String(format: "%.0f", hrs))
                                                    .font(.system(size: 7, weight: .medium))
                                                    .foregroundStyle(.white.opacity(hrs / maxNight > 0.4 ? 1 : 0))
                                            }
                                        }
                                }
                            }
                        }
                    }
                }

                // Total night hours summary
                let totalNight = data.reduce(0) { $0 + $1.nightHours }
                HStack {
                    Image(systemName: "moon.fill")
                        .font(.caption2).foregroundStyle(.indigo)
                    Text(String(format: "%.0f total night hours across %d months", totalNight, data.filter { $0.nightHours > 0 }.count))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }
}
