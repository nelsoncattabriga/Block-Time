//
//  CustomCountCard.swift
//  Block-Time
//
//  Dashboard card showing total custom counter (e.g. PAX carried).
//  Excludes positioning flights. Period-selectable: 1M / 12M / ALL.
//

import SwiftUI

private enum CCPeriod: String, CaseIterable {
    case oneMonth     = "1 Month"
    case twelveMonths = "12 Months"
    case all          = "ALL"
}

struct CustomCountCard: View {
    @AppStorage("customCountCard_period") private var period: CCPeriod = .oneMonth
    @AppStorage("customCountLabel") private var label: String = "Passengers"

    @State private var total: Int = 0
    @State private var flightCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: label, icon: "person.2.fill", iconColor: .teal) {
                Picker("Period", selection: $period) {
                    ForEach(CCPeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(total)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.teal)

                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if flightCount > 0 && total > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.0f", Double(total) / Double(flightCount)))
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.teal.opacity(0.8))

                        Text("avg per flight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if flightCount > 0 {
                Text("\(flightCount) flight\(flightCount == 1 ? "" : "s") logged")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No data logged.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { loadStats() }
        .onChange(of: period) { loadStats() }
    }

    private func loadStats() {
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

        let eligible = flights.filter {
            !$0.isPositioning && (Int($0.counterEntries[1] ?? "") ?? 0) > 0
        }
        total = eligible.reduce(0) { $0 + (Int($1.counterEntries[1] ?? "") ?? 0) }
        flightCount = eligible.count
    }
}
