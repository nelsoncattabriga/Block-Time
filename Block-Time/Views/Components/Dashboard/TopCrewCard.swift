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
    case oneMonth     = "1 Month"
    case twelveMonths = "12 Months"
    case all          = "ALL"
}

private enum CrewRoleFilter: String, CaseIterable {
    case all     = "ALL"
    case captain = "CPT"
    case fo      = "F/O"
    case so      = "S/O"
}

private enum CrewDisplayMode: String, CaseIterable {
    case hours   = "Hours"
    case sectors = "Flights"
}

private struct CrewFrequency: Identifiable {
    let id = UUID()
    var name: String
    var hours: Double
    var sectors: Int
}

struct TopCrewCard: View {
    @AppStorage("crewFrequencyCard_period") private var period: CrewPeriod = .twelveMonths
    @AppStorage("topCrewCard_role") private var roleFilter: CrewRoleFilter = .all
    @AppStorage("topCrewCard_displayMode") private var displayMode: CrewDisplayMode = .sectors
    @State private var crew: [CrewFrequency] = []
    @State private var isExpanded: Bool = false
    @State private var showSheet: Bool = false

    private static let collapsedCount = 5
    private static let expandedCount  = 10

    /// Names that represent the logbook owner and must never appear as crew —
    /// the literal "self" plus whatever the user set as their Default crew names.
    static func ownNames() -> Set<String> {
        let settings = UserDefaultsService().loadSettings()
        return Set(
            ["self",
             settings.defaultCaptainName,
             settings.defaultCoPilotName,
             settings.defaultSOName]
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
        )
    }

    private var sorted: [CrewFrequency] {
        displayMode == .hours
            ? crew.sorted { $0.hours > $1.hours }
            : crew.sorted { $0.sectors > $1.sectors }
    }

    private var visible: [CrewFrequency] {
        if isExpanded { return Array(sorted.prefix(Self.expandedCount)) }
        return Array(sorted.prefix(Self.collapsedCount))
    }

    private var maxValue: Double {
        let top = isExpanded ? Array(sorted.prefix(Self.expandedCount)) : Array(sorted.prefix(Self.collapsedCount))
        return displayMode == .hours
            ? (top.map { $0.hours }.max() ?? 1)
            : Double(top.map { $0.sectors }.max() ?? 1)
    }

    private var needsExpandButton: Bool { sorted.count > Self.collapsedCount }
    private var needsSheetButton:  Bool { isExpanded && sorted.count > Self.expandedCount }
    @State private var nameColumnWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Top Crew", icon: "person.2.fill", iconColor: .purple) {
                HStack(spacing: 4) {
                    Menu {
                        ForEach(CrewRoleFilter.allCases, id: \.self) { option in
                            Button(option.rawValue) { roleFilter = option }
                        }
                    } label: {
                        CardFilterChip(title: roleFilter.rawValue)
                    }

                    Menu {
                        ForEach(CrewDisplayMode.allCases, id: \.self) { option in
                            Button(option.rawValue) { displayMode = option }
                        }
                    } label: {
                        CardFilterChip(title: displayMode.rawValue)
                    }

                    Menu {
                        ForEach(CrewPeriod.allCases, id: \.self) { option in
                            Button(option.rawValue) { period = option }
                        }
                    } label: {
                        CardFilterChip(title: period.rawValue)
                    }
                }
                .tint(.primary)
            }

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
                .animation(.spring(response: 0.4), value: displayMode)
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
            CrewSheetView(period: period, roleFilter: roleFilter, displayMode: displayMode)
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
                        .frame(width: geo.size.width * CGFloat(
                            displayMode == .hours
                                ? member.hours / maxValue
                                : Double(member.sectors) / maxValue
                        ))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayMode)
                }
            }
            .frame(height: 12)
            .frame(minWidth: 60, maxWidth: .infinity)

            if displayMode == .hours {
                Text(String(format: "%.0f", member.hours))
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(member.sectors)")
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
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

        var counts: [String: (name: String, hours: Double, n: Int)] = [:]
        let ownNames = Self.ownNames()
        // When viewing all roles, merge a person across every seat into one row.
        // For a specific role filter, keep the role-prefixed key so behaviour is unchanged.
        let mergeByName = (roleFilter == .all)

        func tally(rolePrefix: String, name: String, blockTime: Double) {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !ownNames.contains(trimmed.lowercased()) else { return }
            let key = mergeByName ? trimmed.lowercased() : "\(rolePrefix)\(trimmed.lowercased())"
            counts[key] = (trimmed, (counts[key]?.hours ?? 0) + blockTime, (counts[key]?.n ?? 0) + 1)
        }

        for f in flights {
            let bt = Double(f.blockTime) ?? 0
            if roleFilter == .all || roleFilter == .captain {
                tally(rolePrefix: "CPT_", name: f.captainName, blockTime: bt)
            }
            if roleFilter == .all || roleFilter == .fo {
                tally(rolePrefix: "FO_", name: f.foName, blockTime: bt)
            }
            if roleFilter == .all || roleFilter == .so {
                if let n = f.so1Name { tally(rolePrefix: "SO_", name: n, blockTime: bt) }
                if let n = f.so2Name { tally(rolePrefix: "SO_", name: n, blockTime: bt) }
            }
        }

        crew = counts.values
            .map { CrewFrequency(name: $0.name, hours: $0.hours, sectors: $0.n) }
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
    @State private var displayMode: CrewDisplayMode
    @State private var crew: [CrewFrequency] = []
    @State private var nameColumnWidth: CGFloat = 0

    init(period: CrewPeriod, roleFilter: CrewRoleFilter, displayMode: CrewDisplayMode) {
        _period = State(initialValue: period)
        _roleFilter = State(initialValue: roleFilter)
        _displayMode = State(initialValue: displayMode)
    }

    private var sorted: [CrewFrequency] {
        displayMode == .hours
            ? crew.sorted { $0.hours > $1.hours }
            : crew.sorted { $0.sectors > $1.sectors }
    }

    private var maxValue: Double {
        displayMode == .hours
            ? (sorted.map { $0.hours }.max() ?? 1)
            : Double(sorted.map { $0.sectors }.max() ?? 1)
    }

    @ViewBuilder
    private var filterRow: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach(CrewRoleFilter.allCases, id: \.self) { option in
                    Button(option.rawValue) { roleFilter = option }
                }
            } label: {
                CardFilterChip(title: roleFilter.rawValue)
            }
            Menu {
                ForEach(CrewDisplayMode.allCases, id: \.self) { option in
                    Button(option.rawValue) { displayMode = option }
                }
            } label: {
                CardFilterChip(title: displayMode.rawValue)
            }
            Menu {
                ForEach(CrewPeriod.allCases, id: \.self) { option in
                    Button(option.rawValue) { period = option }
                }
            } label: {
                CardFilterChip(title: period.rawValue)
            }
            Spacer()
        }
        .tint(.primary)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    filterRow

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
                            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, member in
                                sheetRow(index: index, member: member)
                            }
                        }
                        .onPreferenceChange(MaxWidthKey.self) { nameColumnWidth = $0 }
                        .animation(.spring(response: 0.4), value: displayMode)
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
        .onChange(of: displayMode) { loadCrew() }
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
                        .frame(width: geo.size.width * CGFloat(
                            displayMode == .hours
                                ? member.hours / maxValue
                                : Double(member.sectors) / maxValue
                        ))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayMode)
                }
            }
            .frame(height: 12)
            .frame(minWidth: 60, maxWidth: .infinity)

            if displayMode == .hours {
                Text(String(format: "%.0f", member.hours))
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(member.sectors)")
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
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

        var counts: [String: (name: String, hours: Double, n: Int)] = [:]
        let ownNames = TopCrewCard.ownNames()
        let mergeByName = (roleFilter == .all)

        func tally(rolePrefix: String, name: String, blockTime: Double) {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !ownNames.contains(trimmed.lowercased()) else { return }
            let key = mergeByName ? trimmed.lowercased() : "\(rolePrefix)\(trimmed.lowercased())"
            counts[key] = (trimmed, (counts[key]?.hours ?? 0) + blockTime, (counts[key]?.n ?? 0) + 1)
        }

        for f in flights {
            let bt = Double(f.blockTime) ?? 0
            if roleFilter == .all || roleFilter == .captain {
                tally(rolePrefix: "CPT_", name: f.captainName, blockTime: bt)
            }
            if roleFilter == .all || roleFilter == .fo {
                tally(rolePrefix: "FO_", name: f.foName, blockTime: bt)
            }
            if roleFilter == .all || roleFilter == .so {
                if let n = f.so1Name { tally(rolePrefix: "SO_", name: n, blockTime: bt) }
                if let n = f.so2Name { tally(rolePrefix: "SO_", name: n, blockTime: bt) }
            }
        }

        crew = counts.values
            .map { CrewFrequency(name: $0.name, hours: $0.hours, sectors: $0.n) }
    }
}
