//
//  ApproachTypesCard.swift
//  Block-Time
//
//  Horizontal bar chart showing approach type frequency breakdown.
//

import SwiftUI
import Charts

private enum ApproachPeriod: String, CaseIterable {
    case oneMonth     = "1M"
    case twelveMonths = "12M"
    case all          = "ALL"
}

struct ApproachTypesCard: View {
    @AppStorage("logApproaches") private var logApproaches = true
    @State private var period: ApproachPeriod = .oneMonth
    @State private var data: [NDApproachTypeStat] = []

    private var maxCount: Double { Double(data.map { $0.count }.max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Approach Types", icon: "scope") {
                if logApproaches {
                    Picker("Period", selection: $period) {
                        ForEach(ApproachPeriod.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }

            if !logApproaches {
                ContentUnavailableView(
                    "Approaches Disabled",
                    systemImage: "scope",
                    description: Text("Enable Log Approaches in Flight Information Settings")
                )
                .frame(height: 120)
            } else if data.isEmpty {
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
        .onAppear { if logApproaches { loadData() } }
        .onChange(of: period) { loadData() }
        .onChange(of: logApproaches) { if logApproaches { loadData() } else { data = [] } }
    }

    private func loadData() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let now = Date()
        let endDate = formatter.string(from: now)

        let flights: [FlightSector]
        switch period {
        case .all:
            flights = FlightDatabaseService.shared.fetchAllFlights()
        case .oneMonth:
            let start = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            flights = FlightDatabaseService.shared.fetchFlights(from: formatter.string(from: start), to: endDate)
        case .twelveMonths:
            let start = Calendar.current.date(byAdding: .month, value: -12, to: now)!
            flights = FlightDatabaseService.shared.fetchFlights(from: formatter.string(from: start), to: endDate)
        }

        var aiii = 0, ils = 0, rnp = 0, gls = 0, npa = 0, total = 0
        for f in flights {
            guard (f.dayLandings + f.nightLandings) > 0 else { continue }
            total += 1
            if f.isAIII { aiii += 1 }
            if f.isILS  { ils  += 1 }
            if f.isRNP  { rnp  += 1 }
            if f.isGLS  { gls  += 1 }
            if f.isNPA  { npa  += 1 }
        }
        guard total > 0 else { data = []; return }

        let d = Double(total)
        let raw: [(String, Int, Color)] = [
            ("AIII", aiii, .blue),
            ("ILS",  ils,  .green),
            ("RNP",  rnp,  .orange),
            ("GLS",  gls,  .purple),
            ("NPA",  npa,  .red)
        ]
        data = raw.filter { $0.1 > 0 }
            .map { NDApproachTypeStat(typeName: $0.0, count: $0.1, percentage: Double($0.1) / d * 100, color: $0.2) }
            .sorted { $0.count > $1.count }
    }

    @ViewBuilder
    private func approachRow(item: NDApproachTypeStat) -> some View {
        HStack(spacing: 10) {
            Text(item.typeName)
                .iPadScaledFont(.caption).fontWeight(.bold)
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

            Text("\(item.count)")
                .iPadScaledFont(.caption).fontWeight(.semibold)
            
//            HStack(spacing: 4) {
//                Text("\(item.count)")
//                    .iPadScaledFont(.caption).fontWeight(.semibold)
                Text(String(format: "(%.0f%%)", item.percentage))
                    .iPadScaledFont(.caption).foregroundStyle(.secondary)
//            }
            .frame(width: 48, alignment: .trailing)
        }
    }
}
