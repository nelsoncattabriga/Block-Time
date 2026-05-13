//
//  CrewFrequencyCard.swift
//  Block-Time
//
//  Ranked list of most-flown crew members (captains and first officers).
//

import SwiftUI

private enum CrewPeriod: String, CaseIterable {
    case oneMonth     = "1M"
    case twelveMonths = "12M"
    case all          = "ALL"
}

private enum CrewRole: String, CaseIterable {
    case all    = "All"
    case captain = "Captain"
    case fo      = "FO"
}

private struct CrewFrequency: Identifiable {
    let id = UUID()
    var name: String
    var sectors: Int
    var role: CrewRole
}

struct CrewFrequencyCard: View {
    @AppStorage("crewFrequencyCard_period") private var period: CrewPeriod = .twelveMonths
    @AppStorage("crewFrequencyCard_role") private var role: CrewRole = .all
    @State private var crew: [CrewFrequency] = []
    @State private var isExpanded: Bool = false

    private static let collapsedCount = 5
    private static let expandedCount  = 10

    private var visible: [CrewFrequency] {
        Array(crew.prefix(isExpanded ? Self.expandedCount : Self.collapsedCount))
    }

    private var maxSectors: Double {
        Double(visible.map { $0.sectors }.max() ?? 1)
    }

    private var needsExpandButton: Bool { crew.count > Self.collapsedCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Crew Frequency", icon: "person.2.fill", iconColor: .purple) {
                Picker("Period", selection: $period) {
                    ForEach(CrewPeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            Picker("Role", selection: $role) {
                ForEach(CrewRole.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)

            if crew.isEmpty {
                ContentUnavailableView(
                    "No Crew Data",
                    systemImage: "person.2",
                    description: Text("Captain and FO names appear once you log flights with crew")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, member in
                        crewRow(index: index, member: member)
                    }
                }
                .animation(.spring(response: 0.4), value: isExpanded)
                .animation(.spring(response: 0.4), value: role)

                if needsExpandButton {
                    Button {
                        withAnimation(.spring(response: 0.35)) { isExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Show Less" : "Show More")
                                .iPadScaledFont(.caption, phoneFont: .footnote)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .imageScale(.small)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { loadCrew() }
        .onChange(of: period) { loadCrew() }
        .onChange(of: role) { loadCrew() }
    }

    @ViewBuilder
    private func crewRow(index: Int, member: CrewFrequency) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(rankColor(index).opacity(barOpacity(index)).gradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(member.name)
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if role == .all {
                    Text(member.role == .captain ? "Captain" : "First Officer")
                        .iPadScaledFont(.caption, phoneFont: .caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(rankColor(index).opacity(barOpacity(index)).gradient)
                        .frame(width: geo.size.width * CGFloat(Double(member.sectors) / maxSectors))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: member.sectors)
                }
            }
            .frame(height: 12)
            .frame(minWidth: 60, maxWidth: .infinity)

            Text("\(member.sectors)")
                .iPadScaledFont(.caption, phoneFont: .footnote)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
    }

    private func loadCrew() {
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

        var counts: [String: (name: String, role: CrewRole, n: Int)] = [:]
        for f in flights {
            if role == .all || role == .captain {
                let name = f.captainName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty, name.lowercased() != "self" {
                    counts[name] = (name, .captain, (counts[name]?.n ?? 0) + 1)
                }
            }
            if role == .all || role == .fo {
                let name = f.foName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty, name.lowercased() != "self" {
                    let key = "FO_\(name)"
                    counts[key] = (name, .fo, (counts[key]?.n ?? 0) + 1)
                }
            }
        }

        crew = counts.values
            .sorted { $0.n > $1.n }
            .map { CrewFrequency(name: $0.name, sectors: $0.n, role: $0.role) }
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .indigo
        case 2: return .cyan
        case 3: return .purple
        case 4: return .green
        default: return .blue
        }
    }

    private func barOpacity(_ index: Int) -> Double {
        guard index >= Self.collapsedCount else { return 1.0 }
        let step = index - Self.collapsedCount
        let maxSteps = Self.expandedCount - Self.collapsedCount
        return max(0.35, 1.0 - Double(step) / Double(maxSteps) * 0.65)
    }
}
