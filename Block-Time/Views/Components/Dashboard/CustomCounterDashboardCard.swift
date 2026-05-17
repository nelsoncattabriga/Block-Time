//
//  CustomCounterDashboardCard.swift
//  Block-Time
//
//  Dashboard card showing period totals for a user-defined custom counter.
//  Supports .time (HH:MM sum), .decimal (summed Double), and .integer (summed Int) types.
//

import SwiftUI
import CoreData

private enum CCIPeriod: String, CaseIterable {
    case oneMonth     = "1M"
    case twelveMonths = "12M"
    case all          = "ALL"
}

struct CustomCounterDashboardCard: View {
    let counterID: UUID

    // Period stored per-counter so each card remembers its own selection
    @AppStorage private var periodRaw: String
    private var period: CCIPeriod {
        get { CCIPeriod(rawValue: periodRaw) ?? .twelveMonths }
    }

    @AppStorage("showTimesInHoursMinutes") private var showTimesInHoursMinutes: Bool = false
    @State private var displayValue: String = "—"
    @State private var flightCount: Int = 0

    init(counterID: UUID) {
        self.counterID = counterID
        _periodRaw = AppStorage(wrappedValue: CCIPeriod.twelveMonths.rawValue,
                                "customCounter_\(counterID.uuidString)_period")
    }

    var body: some View {
        let service = CustomCounterService.shared
        let definition = service.definition(for: counterID)

        VStack(alignment: .leading, spacing: 14) {

            // Header
            CardHeader(
                title: definition?.label ?? "Counter",
                icon: iconForType(definition?.type),
                iconColor: colorForType(definition?.type)
            ) {
                Picker("Period", selection: Binding(
                    get: { CCIPeriod(rawValue: periodRaw) ?? .twelveMonths },
                    set: { periodRaw = $0.rawValue }
                )) {
                    ForEach(CCIPeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if let definition {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayValue)
                            .font(.title)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(colorForType(definition.type))

                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
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
            } else {
                Text("Counter unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear { loadStats() }
        .onChange(of: periodRaw) { loadStats() }
        .onChange(of: showTimesInHoursMinutes) { loadStats() }
    }

    // MARK: - Data loading

    private func loadStats() {
        guard let definition = CustomCounterService.shared.definition(for: counterID) else {
            displayValue = "—"
            flightCount = 0
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let now = Date()
        let endDate = formatter.string(from: now)

        let flights: [FlightSector]
        let currentPeriod = CCIPeriod(rawValue: periodRaw) ?? .twelveMonths
        switch currentPeriod {
        case .all:
            flights = FlightDatabaseService.shared.fetchAllFlights()
        case .oneMonth:
            let start = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            flights = FlightDatabaseService.shared.fetchFlights(from: formatter.string(from: start), to: endDate)
        case .twelveMonths:
            let start = Calendar.current.date(byAdding: .month, value: -12, to: now)!
            flights = FlightDatabaseService.shared.fetchFlights(from: formatter.string(from: start), to: endDate)
        }

        let uuidString = counterID.uuidString
        let eligible = flights.filter { $0.counterEntries[uuidString] != nil }
        flightCount = eligible.count

        switch definition.type {
        case .time:
            let total = eligible.reduce(0.0) { sum, sector in
                let raw = sector.counterEntries[uuidString] ?? ""
                return sum + parseTimeValue(raw)
            }
            if showTimesInHoursMinutes {
                displayValue = formatMinutes(Int(round(total * 60)))
            } else {
                displayValue = String(format: "%.1f", total)
            }

        case .decimal:
            let total = eligible.reduce(0.0) { sum, sector in
                let raw = sector.counterEntries[uuidString] ?? ""
                return sum + (Double(raw) ?? 0.0)
            }
            displayValue = String(format: "%.1f", total)

        case .integer:
            let total = eligible.reduce(0) { sum, sector in
                let raw = sector.counterEntries[uuidString] ?? ""
                return sum + (Int(raw) ?? 0)
            }
            displayValue = "\(total)"
        }
    }

    /// Parse a stored counter value as decimal hours.
    /// Accepts both decimal ("1.5") and HH:MM ("1:30") formats.
    private func parseTimeValue(_ raw: String) -> Double {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(":") {
            return FlightSector.hhmmToDecimal(trimmed) ?? 0.0
        }
        return Double(trimmed) ?? 0.0
    }

    /// Convert total minutes to H:MM display string.
    private func formatMinutes(_ totalMinutes: Int) -> String {
        guard totalMinutes > 0 else { return "0:00" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }

    // MARK: - Helpers

    private func iconForType(_ type: CounterType?) -> String {
        switch type {
        case .time:    return "clock.fill"
        case .decimal: return "number.circle.fill"
        case .integer: return "number.square.fill"
        case nil:      return "questionmark.circle"
        }
    }

    private func colorForType(_ type: CounterType?) -> Color {
        switch type {
        case .time:    return .blue
        case .decimal: return .orange
        case .integer: return .teal
        case nil:      return .gray
        }
    }
}
