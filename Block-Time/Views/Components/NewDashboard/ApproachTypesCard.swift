//
//  ApproachTypesCard.swift
//  Block-Time
//
//  Horizontal bar chart showing approach type frequency breakdown.
//

import SwiftUI
import Charts

struct ApproachTypesCard: View {
    let data: [NDApproachTypeStat]

    private var maxCount: Double { Double(data.map { $0.count }.max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Approach Types", icon: "scope")

            if data.isEmpty {
                ContentUnavailableView(
                    "No Approach Data",
                    systemImage: "scope",
                    description: Text("Log approach types when adding flights")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 10) {
                    ForEach(data) { item in
                        approachRow(item: item)
                    }
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }

    @ViewBuilder
    private func approachRow(item: NDApproachTypeStat) -> some View {
        HStack(spacing: 10) {
            Text(item.typeName)
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(item.color)
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.color.gradient)
                        .frame(width: geo.size.width * CGFloat(Double(item.count) / maxCount))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: item.count)
                }
            }
            .frame(height: 16)

            HStack(spacing: 4) {
                Text("\(item.count)")
                    .font(.caption).fontWeight(.semibold)
                Text(String(format: "%.0f%%", item.percentage))
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .frame(width: 54, alignment: .trailing)
        }
    }
}
