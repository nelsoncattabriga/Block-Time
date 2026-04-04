//
//  NextFlightProvider.swift
//  BlockTimeWidget
//
//  WidgetKit timeline provider for the Next Flight widget.
//  Reads the JSON snapshot written by WidgetDataWriter in the main app.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct NextFlightTimelineEntry: TimelineEntry {
    let date: Date                               // When WidgetKit should render this entry
    let flight: WidgetFlightEntry?               // nil = no upcoming flights
    let countdownLabel: String                   // Pre-computed label e.g. "3 Days", "1 Hr"
    var sameDayFlights: [WidgetFlightEntry] = [] // All flights on the same day as `flight` (large widget)
    var configuration: NextFlightIntent = NextFlightIntent()
}

// MARK: - Provider

struct NextFlightProvider: AppIntentTimelineProvider {
    typealias Intent = NextFlightIntent

    // MARK: Placeholder (shown while widget loads / in gallery)
    func placeholder(in context: Context) -> NextFlightTimelineEntry {
        NextFlightTimelineEntry(date: .now, flight: .placeholder, countdownLabel: "6 Hrs")
    }

    // MARK: Snapshot (shown in widget picker preview)
    func snapshot(for configuration: NextFlightIntent, in context: Context) async -> NextFlightTimelineEntry {
        let flights = readSnapshots()
        let flight = flights.first ?? .placeholder
        let label = Self.label(for: flight.departureDatetime ?? flight.flightDate, at: .now)
        let sameDay = Self.sameDayFlights(as: flight, from: flights)
        return NextFlightTimelineEntry(date: .now, flight: flight, countdownLabel: label, sameDayFlights: sameDay, configuration: configuration)
    }

    // MARK: Timeline
    func timeline(for configuration: NextFlightIntent, in context: Context) async -> Timeline<NextFlightTimelineEntry> {
        let now = Date()
        let flights = readSnapshots()

        guard !flights.isEmpty else {
            // No flights — check again in 1 hour
            let entry = NextFlightTimelineEntry(date: now, flight: nil, countdownLabel: "", configuration: configuration)
            let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
            return Timeline(entries: [entry], policy: .after(refresh))
        }

        // Checkpoints before departure at which the countdown label changes
        let checkpointOffsets: [(offset: TimeInterval, label: String)] = [
            (-3600 * 24 * 7, "7 Days"),
            (-3600 * 24 * 6, "6 Days"),
            (-3600 * 24 * 5, "5 Days"),
            (-3600 * 24 * 4, "4 Days"),
            (-3600 * 24 * 3, "3 Days"),
            (-3600 * 24 * 2, "2 Days"),
            (-3600 * 24 * 1, "1 Day"),
            (-3600 * 24,     "24 Hrs"),
            (-3600 * 18,     "18 Hrs"),
            (-3600 * 12,     "12 Hrs"),
            (-3600 * 6,      "6 Hrs"),
            (-3600 * 3,      "3 Hrs"),
            (-3600 * 2,      "2 Hrs"),
            (-3600 * 1,      "1 Hr"),
        ]

        var entries: [NextFlightTimelineEntry] = []

        for (index, flight) in flights.enumerated() {
            let departure = flight.departureDatetime ?? flight.flightDate
            let nextFlight: WidgetFlightEntry? = index + 1 < flights.count ? flights[index + 1] : nil
            let sameDay = Self.sameDayFlights(as: flight, from: flights)

            // Countdown checkpoint entries leading up to this departure
            for (offset, label) in checkpointOffsets {
                let entryDate = departure.addingTimeInterval(offset)
                if entryDate >= now {
                    entries.append(NextFlightTimelineEntry(date: entryDate, flight: flight, countdownLabel: label, sameDayFlights: sameDay, configuration: configuration))
                }
            }

            // Current entry (if this is the first flight and no checkpoint covers now)
            if index == 0 && (entries.isEmpty || entries.first!.date > now) {
                let currentLabel = Self.label(for: departure, at: now)
                entries.insert(NextFlightTimelineEntry(date: now, flight: flight, countdownLabel: currentLabel, sameDayFlights: sameDay, configuration: configuration), at: 0)
            }

            // Midnight rollover — ensures "Tomorrow" flips to "Today" at 00:00
            let cal = Calendar.current
            if let midnight = cal.nextDate(after: now,
                                           matching: DateComponents(hour: 0, minute: 0, second: 0),
                                           matchingPolicy: .nextTime),
               midnight < departure {
                let midnightLabel = Self.label(for: departure, at: midnight)
                entries.append(NextFlightTimelineEntry(date: midnight, flight: flight, countdownLabel: midnightLabel, sameDayFlights: sameDay, configuration: configuration))
            }

            // 30 mins after departure: switch to next flight (or show departed if last)
            let switchDate = departure.addingTimeInterval(30 * 60)
            let switchLabel = nextFlight != nil ? Self.label(for: nextFlight!.departureDatetime ?? nextFlight!.flightDate, at: switchDate) : "Departed"
            let switchSameDay = nextFlight != nil ? Self.sameDayFlights(as: nextFlight!, from: flights) : sameDay
            entries.append(NextFlightTimelineEntry(date: switchDate, flight: nextFlight ?? flight, countdownLabel: switchLabel, sameDayFlights: switchSameDay, configuration: configuration))
        }

        // After the last flight departs, refresh in 1 hour to pick up any new data
        let lastDeparture = (flights.last?.departureDatetime ?? flights.last?.flightDate) ?? now
        let refreshDate = lastDeparture.addingTimeInterval(3600)
        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    // MARK: - Same-day flights helper

    /// Returns all flights from `allFlights` that share the same local calendar day as `anchor`.
    static func sameDayFlights(as anchor: WidgetFlightEntry, from allFlights: [WidgetFlightEntry]) -> [WidgetFlightEntry] {
        let cal = Calendar.current
        let anchorDate = anchor.departureDatetime ?? anchor.flightDate
        return allFlights.filter { f in
            let fDate = f.departureDatetime ?? f.flightDate
            return cal.isDate(fDate, inSameDayAs: anchorDate)
        }
    }

    // MARK: - Derive label for arbitrary point in time

    static func label(for departure: Date, at now: Date) -> String {
        let interval = departure.timeIntervalSince(now)
        guard interval > 0 else { return "Departed" }
        switch interval {
        case ..<3600:           return "1 Hr"
        case ..<7200:           return "2 Hrs"
        case ..<10800:          return "3 Hrs"
        case ..<21600:          return "6 Hrs"
        case ..<43200:          return "12 Hrs"
        case ..<64800:          return "18 Hrs"
        case ..<86400:          return "24 Hrs"
        case ..<172800:         return "1 Day"
        case ..<259200:         return "2 Days"
        case ..<345600:         return "3 Days"
        case ..<432000:         return "4 Days"
        case ..<518400:         return "5 Days"
        case ..<604800:         return "6 Days"
        case ..<691200:         return "7 Days"
        default:                return "Over a Week"
        }
    }

    // MARK: - Read from App Group

    private func readSnapshots() -> [WidgetFlightEntry] {
        guard let defaults = UserDefaults(suiteName: WidgetFlightEntry.appGroupID),
              let data = defaults.data(forKey: WidgetFlightEntry.listDefaultsKey),
              let entries = try? JSONDecoder().decode([WidgetFlightEntry].self, from: data) else {
            return []
        }
        return entries
    }
}

// MARK: - Placeholder data

extension WidgetFlightEntry {
    static let placeholder = WidgetFlightEntry(
        flightNumber:      "QF063",
        fromAirport:       "FAOR",
        toAirport:         "YSSY",
        flightDate:        Date().addingTimeInterval(3600 * 6),
        departureDatetime: Date().addingTimeInterval(3600 * 6),
        arrivalDatetime:   Date().addingTimeInterval(3600 * 17),
        useIATACodes:      true,
        snapshotDate:      .now
    )
}
