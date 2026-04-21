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
    @AppStorage("topRegistrationsCard_period") private var period: RegPeriod = .oneMonth
    @AppStorage("topRegistrationsCard_displayMode") private var displayMode: RegDisplayMode = .hours
    @State private var registrations: [NDRegistrationHours] = []
    @State private var isExpanded: Bool = false
    @State private var showSheet: Bool = false

    private static let collapsedCount = 5
    private static let expandedCount  = 10

    private var sorted: [NDRegistrationHours] {
        displayMode == .hours
            ? registrations.sorted { $0.hours > $1.hours }
            : registrations.sorted { $0.sectors > $1.sectors }
    }

    private var visibleRows: [NDRegistrationHours] {
        if isExpanded { return Array(sorted.prefix(Self.expandedCount)) }
        return Array(sorted.prefix(Self.collapsedCount))
    }

    private var maxValue: Double {
        let topRows = isExpanded ? Array(sorted.prefix(Self.expandedCount)) : Array(sorted.prefix(Self.collapsedCount))
        return displayMode == .hours
            ? (topRows.map { $0.hours }.max() ?? 1)
            : Double(topRows.map { $0.sectors }.max() ?? 1)
    }

    private var needsExpandButton: Bool { sorted.count > Self.collapsedCount }
    private var needsSheetButton:  Bool { isExpanded && sorted.count > Self.expandedCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Top Registrations", icon: "airplane") {
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
                    systemImage: "airplane",
                    description: Text("Log aircraft registrations to see your most-flown tails")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, reg in
                        regRow(index: index, reg: reg)
                    }
                }
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
        .onAppear { loadRegistrations() }
        .onChange(of: period) {
            loadRegistrations()
        }
        .sheet(isPresented: $showSheet) {
            RegistrationsSheetView(period: period, displayMode: displayMode)
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
            Text("\(index + 1)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(rankColor(index).opacity(barOpacity(index)).gradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(reg.registration)
                    .iPadScaledFont(.caption, phoneFont: .footnote).fontWeight(.bold).foregroundStyle(.primary)
                Text(reg.aircraftType)
                    .iPadScaledFont(.caption, phoneFont: .footnote).foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(rankColor(index).opacity(barOpacity(index)).gradient)
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
                    .iPadScaledFont(.caption, phoneFont: .footnote).fontWeight(.semibold).foregroundStyle(.secondary)
            } else {
                Text("\(reg.sectors) sectors")
                    .iPadScaledFont(.caption, phoneFont: .footnote).fontWeight(.semibold).foregroundStyle(.secondary)
            }
        }
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

    // Fades bars from rank 5 onwards: 1.0 → 0.35 across 10 overflow slots
    private func barOpacity(_ index: Int) -> Double {
        guard index >= Self.collapsedCount else { return 1.0 }
        let step = index - Self.collapsedCount
        let maxSteps = Self.expandedCount - Self.collapsedCount
        return max(0.35, 1.0 - Double(step) / Double(maxSteps) * 0.65)
    }
}

// MARK: - All-time sheet

private struct RegistrationsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var period: RegPeriod
    @State private var displayMode: RegDisplayMode
    @State private var registrations: [NDRegistrationHours] = []

    init(period: RegPeriod, displayMode: RegDisplayMode) {
        _period = State(initialValue: period)
        _displayMode = State(initialValue: displayMode)
    }

    private var sorted: [NDRegistrationHours] {
        displayMode == .hours
            ? registrations.sorted { $0.hours > $1.hours }
            : registrations.sorted { $0.sectors > $1.sectors }
    }

    private var maxValue: Double {
        displayMode == .hours
            ? (sorted.map { $0.hours }.max() ?? 1)
            : Double(sorted.map { $0.sectors }.max() ?? 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Period", selection: $period) {
                        ForEach(RegPeriod.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Display", selection: $displayMode) {
                        ForEach(RegDisplayMode.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    if registrations.isEmpty {
                        ContentUnavailableView(
                            "No Registration Data",
                            systemImage: "airplane",
                            description: Text("Log aircraft registrations to see your most-flown tails")
                        )
                        .frame(height: 160)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(sorted, id: \.id) { reg in
                                regRow(reg: reg)
                            }
                        }
                        .animation(.spring(response: 0.4), value: displayMode)
                    }
                }
                .padding(16)
            }
            .navigationTitle("\(registrations.count) Registrations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { loadAllRegistrations() }
        .onChange(of: period) { loadAllRegistrations() }
        .onChange(of: displayMode) { loadAllRegistrations() }
    }

    @ViewBuilder
    private func regRow(reg: NDRegistrationHours) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(reg.registration)
                    .iPadScaledFont(.caption, phoneFont: .footnote).fontWeight(.bold).foregroundStyle(.primary)
                Text(reg.aircraftType)
                    .iPadScaledFont(.caption, phoneFont: .footnote).foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.gradient)
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
                    .iPadScaledFont(.caption, phoneFont: .footnote).fontWeight(.semibold).foregroundStyle(.secondary)
            } else {
                Text("\(reg.sectors) sectors")
                    .iPadScaledFont(.caption, phoneFont: .footnote).fontWeight(.semibold).foregroundStyle(.secondary)
            }
        }
    }

    private func loadAllRegistrations() {
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
}
