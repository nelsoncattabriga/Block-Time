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
        NextFlightTimelineEntry(date: .now, flight: .placeholder)
    }

    // MARK: Snapshot (shown in widget picker preview)
    func snapshot(for configuration: NextFlightIntent, in context: Context) async -> NextFlightTimelineEntry {
        let flights = readSnapshots()
        let flight = flights.first ?? .placeholder
        let sameDay = Self.sameDayFlights(as: flight, from: flights)
        return NextFlightTimelineEntry(date: .now, flight: flight, sameDayFlights: sameDay, configuration: configuration)
    }

    // MARK: Timeline
    func timeline(for configuration: NextFlightIntent, in context: Context) async -> Timeline<NextFlightTimelineEntry> {
        let now = Date()
        let flights = readSnapshots()

        guard !flights.isEmpty else {
            let entry = NextFlightTimelineEntry(date: now, flight: nil, configuration: configuration)
            return Timeline(entries: [entry], policy: .atEnd)
        }

        return configuration.displayMode == .countdown
            ? countdownTimeline(flights: flights, now: now, configuration: configuration)
            : flightInfoTimeline(flights: flights, now: now, configuration: configuration)
    }

    // MARK: - Flight Info timeline (existing behaviour)

    private func flightInfoTimeline(
        flights: [WidgetFlightEntry],
        now: Date,
        configuration: NextFlightIntent
    ) -> Timeline<NextFlightTimelineEntry> {
        let cal = Calendar.current
        var entries: [NextFlightTimelineEntry] = []

        for (index, flight) in flights.enumerated() {
            let departure = flight.departureDatetime ?? flight.flightDate
            let nextFlight: WidgetFlightEntry? = index + 1 < flights.count ? flights[index + 1] : nil
            let sameDay = Self.sameDayFlights(as: flight, from: flights)

            if !entries.contains(where: { $0.date <= now }) {
                entries.insert(NextFlightTimelineEntry(
                    date: now, flight: flight,
                    sameDayFlights: sameDay,
                    configuration: configuration
                ), at: 0)
            }

            // Midnight rollovers so "Tomorrow" → "Today" flips correctly.
            var scanFrom = now
            while let midnight = cal.nextDate(
                after: scanFrom,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ), midnight < departure {
                entries.append(NextFlightTimelineEntry(
                    date: midnight, flight: flight,
                    sameDayFlights: sameDay,
                    configuration: configuration
                ))
                scanFrom = midnight
            }

            let switchDate = departure.addingTimeInterval(30 * 60)

            if let next = nextFlight {
                let nextIsNewDay = !cal.isDate(
                    next.departureDatetime ?? next.flightDate,
                    inSameDayAs: departure
                )
                let noMoreToday = nextIsNewDay && !sameDay.isEmpty
                let nextSameDay = Self.sameDayFlights(as: next, from: flights)
                entries.append(NextFlightTimelineEntry(
                    date: switchDate, flight: next,
                    sameDayFlights: nextSameDay,
                    noMoreFlightsToday: noMoreToday,
                    configuration: configuration
                ))

                let nextDeparture = next.departureDatetime ?? next.flightDate
                var scanNext = switchDate
                while let midnight = cal.nextDate(
                    after: scanNext,
                    matching: DateComponents(hour: 0, minute: 0, second: 0),
                    matchingPolicy: .nextTime
                ), midnight < nextDeparture {
                    entries.append(NextFlightTimelineEntry(
                        date: midnight, flight: next,
                        sameDayFlights: nextSameDay,
                        noMoreFlightsToday: false,
                        configuration: configuration
                    ))
                    scanNext = midnight
                }
            } else {
                entries.append(NextFlightTimelineEntry(
                    date: switchDate, flight: nil,
                    configuration: configuration
                ))
            }
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

    // MARK: - Countdown timeline
    // Two entries per flight: one at `now` (or switchDate of previous), one at dep+30min.
    // Text(.relative) drives the live countdown — no extra entries needed.

    private func countdownTimeline(
        flights: [WidgetFlightEntry],
        now: Date,
        configuration: NextFlightIntent
    ) -> Timeline<NextFlightTimelineEntry> {
        var entries: [NextFlightTimelineEntry] = []
        var entryDate = now

        for (index, flight) in flights.enumerated() {
            let departure = flight.departureDatetime ?? flight.flightDate
            let nextFlight: WidgetFlightEntry? = index + 1 < flights.count ? flights[index + 1] : nil

            entries.append(NextFlightTimelineEntry(
                date: entryDate, flight: flight,
                configuration: configuration
            ))

            let switchDate = departure.addingTimeInterval(30 * 60)

            if nextFlight == nil {
                entries.append(NextFlightTimelineEntry(
                    date: switchDate, flight: nil,
                    configuration: configuration
                ))
            }

            entryDate = switchDate
        }

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
