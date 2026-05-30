//
//  TopCrewCard.swift
//  Block-Time
//
//  Ranked list of most-flown crew members (captains and first officers).
//

import SwiftUI

private struct MaxWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum CrewPeriod: String, CaseIterable {
    case oneMonth     = "1M"
    case twelveMonths = "12M"
    case all          = "ALL"
}

private enum CrewRoleFilter: String, CaseIterable {
    case all     = "All"
    case captain = "Capt"
    case fo      = "FO"
    case so      = "SO"
}

private struct CrewFrequency: Identifiable {
    let id = UUID()
    var name: String
    var sectors: Int
}

struct TopCrewCard: View {
    @AppStorage("crewFrequencyCard_period") private var period: CrewPeriod = .twelveMonths
    @AppStorage("topCrewCard_role") private var roleFilter: CrewRoleFilter = .all
    @State private var crew: [CrewFrequency] = []
    @State private var isExpanded: Bool = false
    @State private var showSheet: Bool = false

    private static let collapsedCount = 5
    private static let expandedCount  = 10

    private var visible: [CrewFrequency] {
        if isExpanded { return Array(crew.prefix(Self.expandedCount)) }
        return Array(crew.prefix(Self.collapsedCount))
    }

    private var maxSectors: Double {
        Double(visible.map { $0.sectors }.max() ?? 1)
    }

    private var needsExpandButton: Bool { crew.count > Self.collapsedCount }
    private var needsSheetButton:  Bool { isExpanded && crew.count > Self.expandedCount }
    @State private var nameColumnWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Top Crew", icon: "person.2.fill", iconColor: .purple) {
                Picker("Period", selection: $period) {
                    ForEach(CrewPeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            Picker("Role", selection: $roleFilter) {
                ForEach(CrewRoleFilter.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)

            if crew.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Crew Data")
                        .font(.headline)
                    Text("Names need to be added to your flights to show here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, member in
                        crewRow(index: index, member: member)
                    }
                }
                .onPreferenceChange(MaxWidthKey.self) { nameColumnWidth = $0 }
                .animation(.spring(response: 0.4), value: isExpanded)

                if needsExpandButton {
                    expandButtons
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { loadCrew() }
        .onChange(of: period) { loadCrew() }
        .onChange(of: roleFilter) { loadCrew() }
        .sheet(isPresented: $showSheet) {
            CrewSheetView(period: period, roleFilter: roleFilter)
        }
    }

    @ViewBuilder
    private var expandButtons: some View {
        HStack(spacing: 16) {
            if isExpanded {
                Button {
                    withAnimation(.spring(response: 0.35)) { isExpanded = false }
                } label: {
                    expandButtonLabel("Show Less", icon: "chevron.up")
                }
                .buttonStyle(.plain)

                if needsSheetButton {
                    Button {
                        showSheet = true
                    } label: {
                        expandButtonLabel("Show All", icon: "arrow.up.right.square")
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.35)) { isExpanded = true }
                } label: {
                    expandButtonLabel("Show More", icon: "chevron.down")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func expandButtonLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .iPadScaledFont(.caption, phoneFont: .footnote)
            Image(systemName: icon)
                .imageScale(.small)
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func crewRow(index: Int, member: CrewFrequency) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: 20, height: 20)
                .background(rankColor(index).opacity(barOpacity(index)).gradient, in: Circle())

            Text(member.name)
                .iPadScaledFont(.caption, phoneFont: .footnote)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: MaxWidthKey.self, value: geo.size.width)
                    }
                )
                .frame(width: nameColumnWidth > 0 ? nameColumnWidth : nil, alignment: .leading)

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

        var counts: [String: (name: String, n: Int)] = [:]

        func tally(key: String, name: String) {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.lowercased() != "self" else { return }
            counts[key] = (trimmed, (counts[key]?.n ?? 0) + 1)
        }

        for f in flights {
            if roleFilter == .all || roleFilter == .captain {
                tally(key: f.captainName, name: f.captainName)
            }
            if roleFilter == .all || roleFilter == .fo {
                tally(key: "FO_\(f.foName)", name: f.foName)
            }
            if roleFilter == .all || roleFilter == .so {
                if let n = f.so1Name { tally(key: "SO1_\(n)", name: n) }
                if let n = f.so2Name { tally(key: "SO2_\(n)", name: n) }
            }
        }

        crew = counts.values
            .sorted { $0.n > $1.n }
            .map { CrewFrequency(name: $0.name, sectors: $0.n) }
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

private struct CrewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var period: CrewPeriod
    @State private var roleFilter: CrewRoleFilter
    @State private var crew: [CrewFrequency] = []
    @State private var nameColumnWidth: CGFloat = 0

    init(period: CrewPeriod, roleFilter: CrewRoleFilter) {
        _period = State(initialValue: period)
        _roleFilter = State(initialValue: roleFilter)
    }

    private var maxSectors: Double {
        Double(crew.map { $0.sectors }.max() ?? 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Period", selection: $period) {
                        ForEach(CrewPeriod.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Role", selection: $roleFilter) {
                        ForEach(CrewRoleFilter.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    if crew.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No Crew Data")
                                .font(.headline)
                            Text("Names need to be added to your flights to show here")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(crew.enumerated()), id: \.element.id) { index, member in
                                sheetRow(index: index, member: member)
                            }
                        }
                        .onPreferenceChange(MaxWidthKey.self) { nameColumnWidth = $0 }
                        .animation(.spring(response: 0.4), value: roleFilter)
                    }
                }
                .padding(16)
            }
            .navigationTitle("\(crew.count) Crew Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { loadCrew() }
        .onChange(of: period) { loadCrew() }
        .onChange(of: roleFilter) { loadCrew() }
    }

    @ViewBuilder
    private func sheetRow(index: Int, member: CrewFrequency) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: 20, height: 20)
                .background(Color.purple.opacity(index < 3 ? 1.0 : 0.5).gradient, in: Circle())

            Text(member.name)
                .iPadScaledFont(.caption, phoneFont: .footnote)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: MaxWidthKey.self, value: geo.size.width)
                    }
                )
                .frame(width: nameColumnWidth > 0 ? nameColumnWidth : nil, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.purple.opacity(index < 3 ? 1.0 : 0.5).gradient)
                        .frame(width: geo.size.width * CGFloat(Double(member.sectors) / maxSectors))
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

        var counts: [String: (name: String, n: Int)] = [:]

        func tally(key: String, name: String) {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.lowercased() != "self" else { return }
            counts[key] = (trimmed, (counts[key]?.n ?? 0) + 1)
        }

        for f in flights {
            if roleFilter == .all || roleFilter == .captain {
                tally(key: f.captainName, name: f.captainName)
            }
            if roleFilter == .all || roleFilter == .fo {
                tally(key: "FO_\(f.foName)", name: f.foName)
            }
            if roleFilter == .all || roleFilter == .so {
                if let n = f.so1Name { tally(key: "SO1_\(n)", name: n) }
                if let n = f.so2Name { tally(key: "SO2_\(n)", name: n) }
            }
        }

        crew = counts.values
            .sorted { $0.n > $1.n }
            .map { CrewFrequency(name: $0.name, sectors: $0.n) }
    }
}
