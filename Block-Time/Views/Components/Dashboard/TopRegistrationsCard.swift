//
//  TopRegistrationsCard.swift
//  Block-Time
//
//  Ranked list of most-flown aircraft registrations by hours or sectors.
//

import SwiftUI

private enum RegPeriod: String, CaseIterable {
    case oneMonth     = "1M"
    case twelveMonths = "12M"
    case all          = "ALL"
}

private enum RegDisplayMode: String, CaseIterable {
    case hours   = "Hours"
    case sectors = "Sectors"
}

struct TopRegistrationsCard: View {
    @State private var period: RegPeriod = .oneMonth
    @State private var displayMode: RegDisplayMode = .hours
    @State private var registrations: [NDRegistrationHours] = []

    private var maxValue: Double {
        displayMode == .hours
            ? (registrations.map { $0.hours }.max() ?? 1)
            : Double(registrations.map { $0.sectors }.max() ?? 1)
    }

    private var sorted: [NDRegistrationHours] {
        let s = displayMode == .hours
            ? registrations.sorted { $0.hours > $1.hours }
            : registrations.sorted { $0.sectors > $1.sectors }
        return Array(s.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Top 5 Registrations", icon: "airplane") {
                Picker("Period", selection: $period) {
                    ForEach(RegPeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            Picker("Display", selection: $displayMode) {
                ForEach(RegDisplayMode.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)

            if registrations.isEmpty {
                ContentUnavailableView(
                    "No Registration Data",
                    systemImage: "airplane.slash",
                    description: Text("Log aircraft registrations to see your most-flown tails")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, reg in
                        regRow(index: index, reg: reg)
                    }
                }
                .animation(.spring(response: 0.4), value: displayMode)
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { loadRegistrations() }
        .onChange(of: period) { loadRegistrations() }
    }

    private func loadRegistrations() {
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

        var data: [String: (reg: String, type: String, hours: Double, sectors: Int)] = [:]
        for f in flights {
            let reg = f.aircraftReg
            guard !reg.isEmpty else { continue }
            let current = data[reg]
            data[reg] = (reg, f.aircraftType, (current?.hours ?? 0) + (Double(f.blockTime) ?? 0), (current?.sectors ?? 0) + 1)
        }
        registrations = data.values
            .map { NDRegistrationHours(registration: $0.reg, aircraftType: $0.type, hours: $0.hours, sectors: $0.sectors) }
    }

    @ViewBuilder
    private func regRow(index: Int, reg: NDRegistrationHours) -> some View {
        HStack(spacing: 10) {
            // Rank
            Text("\(index + 1)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(rankColor(index).gradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(reg.registration)
                    .iPadScaledFont(.caption).fontWeight(.bold).foregroundStyle(.primary)
                Text(reg.aircraftType)
                    .iPadScaledFont(.caption).foregroundStyle(.secondary)
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(rankColor(index).gradient)
                        .frame(width: geo.size.width * CGFloat(
                            displayMode == .hours
                                ? reg.hours / maxValue
                                : Double(reg.sectors) / maxValue
                        ))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayMode)
                }
            }
            .frame(height: 12)
            .frame(minWidth: 60, maxWidth: .infinity)
            
            if displayMode == .hours {
                Text(String(format: "%.0f hrs", reg.hours))
                    .iPadScaledFont(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            } else {
                Text("\(reg.sectors) sectors")
                    .iPadScaledFont(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            }
        }
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .indigo
        case 2: return .green
        default: return .blue
        }
    }
}
