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
    let flight: WidgetFlightEntry?               // nil = no upcoming flights at all
    let countdownLabel: String                   // Pre-computed label e.g. "3 Days", "1 Hr"
    var sameDayFlights: [WidgetFlightEntry] = [] // All flights on the same day as `flight` (large widget)
    /// True when today had flights but all have now departed — large widget bottom shows "No More Flights Today"
    var noMoreFlightsToday: Bool = false
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
            // No flights at all — show empty state and let WidgetKit refresh naturally
            let entry = NextFlightTimelineEntry(date: now, flight: nil, countdownLabel: "", configuration: configuration)
            return Timeline(entries: [entry], policy: .atEnd)
        }

        // Checkpoints before departure at which the countdown label changes.
        // Each offset is unique — no duplicates.
        let checkpointOffsets: [(offset: TimeInterval, label: String)] = [
            (-3600 * 24 * 7, "7 Days"),
            (-3600 * 24 * 6, "6 Days"),
            (-3600 * 24 * 5, "5 Days"),
            (-3600 * 24 * 4, "4 Days"),
            (-3600 * 24 * 3, "3 Days"),
            (-3600 * 24 * 2, "2 Days"),
            (-3600 * 24,     "24 Hrs"),
            (-3600 * 18,     "18 Hrs"),
            (-3600 * 12,     "12 Hrs"),
            (-3600 * 6,      "6 Hrs"),
            (-3600 * 3,      "3 Hrs"),
            (-3600 * 2,      "2 Hrs"),
            (-3600 * 1,      "1 Hr"),
        ]

        let cal = Calendar.current
        var entries: [NextFlightTimelineEntry] = []

        for (index, flight) in flights.enumerated() {
            let departure = flight.departureDatetime ?? flight.flightDate
            let nextFlight: WidgetFlightEntry? = index + 1 < flights.count ? flights[index + 1] : nil
            let sameDay = Self.sameDayFlights(as: flight, from: flights)

            // Countdown checkpoint entries leading up to this departure
            for (offset, label) in checkpointOffsets {
                let entryDate = departure.addingTimeInterval(offset)
                if entryDate >= now {
                    entries.append(NextFlightTimelineEntry(
                        date: entryDate, flight: flight,
                        countdownLabel: label, sameDayFlights: sameDay,
                        configuration: configuration
                    ))
                }
            }

            // Seed a "now" entry if nothing yet covers the present moment
            let hasPresentCoverage = entries.contains { $0.date <= now }
            if !hasPresentCoverage {
                let currentLabel = Self.label(for: departure, at: now)
                entries.insert(NextFlightTimelineEntry(
                    date: now, flight: flight,
                    countdownLabel: currentLabel, sameDayFlights: sameDay,
                    configuration: configuration
                ), at: 0)
            }

            // Midnight rollovers — add an entry for every midnight between now and departure
            // so "Tomorrow" → "Today" (and "Mon 7th" → "Today") flips correctly for any flight.
            var scanFrom = now
            while let midnight = cal.nextDate(
                after: scanFrom,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ), midnight < departure {
                let midnightLabel = Self.label(for: departure, at: midnight)
                entries.append(NextFlightTimelineEntry(
                    date: midnight, flight: flight,
                    countdownLabel: midnightLabel, sameDayFlights: sameDay,
                    configuration: configuration
                ))
                scanFrom = midnight
            }

            // 30 mins after departure: advance to next flight.
            // - If there is a next flight, show it (main card) with its own same-day companions.
            // - If today had more same-day flights that are now all gone, set noMoreFlightsToday=true
            //   so the large widget bottom can say "No More Flights Today" while the main card
            //   shows the next future flight (which may be on a different day).
            // - If there is no next flight at all, flight=nil → full empty state.
            let switchDate = departure.addingTimeInterval(30 * 60)

            if let next = nextFlight {
                // Are next flight's same-day companions on a DIFFERENT day to the flight just departed?
                let nextIsNewDay = !cal.isDate(
                    next.departureDatetime ?? next.flightDate,
                    inSameDayAs: departure
                )
                // If the next flight is on a new day, today's flights are all gone.
                let noMoreToday = nextIsNewDay && !sameDay.isEmpty

                let nextSameDay = Self.sameDayFlights(as: next, from: flights)
                let switchLabel = Self.label(for: next.departureDatetime ?? next.flightDate, at: switchDate)
                entries.append(NextFlightTimelineEntry(
                    date: switchDate, flight: next,
                    countdownLabel: switchLabel, sameDayFlights: nextSameDay,
                    noMoreFlightsToday: noMoreToday,
                    configuration: configuration
                ))
            } else {
                // Last flight has departed — no future flights remain
                entries.append(NextFlightTimelineEntry(
                    date: switchDate, flight: nil,
                    countdownLabel: "", sameDayFlights: [],
                    configuration: configuration
                ))
            }
        }

        // Use .atEnd so WidgetKit refreshes as soon as entries are exhausted.
        // The main app calls reloadTimelines whenever flight data changes, so this
        // is the correct policy rather than a hard-coded time in the future.
        return Timeline(entries: entries, policy: .atEnd)
    }

    // MARK: - Same-day flights helper

    /// Returns all flights from `allFlights` that share the same local calendar day as `anchor`,
    /// sorted ascending by departure time.
    static func sameDayFlights(as anchor: WidgetFlightEntry, from allFlights: [WidgetFlightEntry]) -> [WidgetFlightEntry] {
        let cal = Calendar.current
        let anchorDate = anchor.departureDatetime ?? anchor.flightDate
        return allFlights
            .filter { f in
                let fDate = f.departureDatetime ?? f.flightDate
                return cal.isDate(fDate, inSameDayAs: anchorDate)
            }
            .sorted { ($0.departureDatetime ?? $0.flightDate) < ($1.departureDatetime ?? $1.flightDate) }
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
