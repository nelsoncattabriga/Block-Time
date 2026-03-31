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
    let date: Date                   // When WidgetKit should render this entry
    let flight: WidgetFlightEntry?   // nil = no upcoming flights
}

// MARK: - Provider

struct NextFlightProvider: TimelineProvider {

    // MARK: Placeholder (shown while widget loads / in gallery)
    func placeholder(in context: Context) -> NextFlightTimelineEntry {
        NextFlightTimelineEntry(date: .now, flight: .placeholder)
    }

    // MARK: Snapshot (shown in widget picker preview)
    func getSnapshot(in context: Context, completion: @escaping (NextFlightTimelineEntry) -> Void) {
        let entry = NextFlightTimelineEntry(date: .now, flight: readSnapshot() ?? .placeholder)
        completion(entry)
    }

    // MARK: Timeline
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextFlightTimelineEntry>) -> Void) {
        let now = Date()
        let snapshot = readSnapshot()

        guard let flight = snapshot,
              let departure = flight.departureDatetime ?? Optional(flight.flightDate) else {
            // No flight — check again in 1 hour
            let entry = NextFlightTimelineEntry(date: now, flight: nil)
            let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
            completion(Timeline(entries: [entry], policy: .after(refresh)))
            return
        }

        // Build entries at strategic intervals before departure
        var entries: [NextFlightTimelineEntry] = []
        let checkpoints: [TimeInterval] = [
            0,          // now
            -3600 * 24, // T-24h
            -3600 * 6,  // T-6h
            -3600 * 1,  // T-1h
            -60 * 30,   // T-30min
        ]

        for offset in checkpoints {
            let entryDate = departure.addingTimeInterval(offset)
            if entryDate >= now {
                entries.append(NextFlightTimelineEntry(date: entryDate, flight: flight))
            }
        }

        // Always include a current entry
        if entries.isEmpty || entries.first!.date > now {
            entries.insert(NextFlightTimelineEntry(date: now, flight: flight), at: 0)
        }

        // Refresh 1 hour after departure to pick up the next flight
        let refreshDate = departure.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    // MARK: - Read from App Group

    private func readSnapshot() -> WidgetFlightEntry? {
        guard let defaults = UserDefaults(suiteName: WidgetFlightEntry.appGroupID),
              let data = defaults.data(forKey: WidgetFlightEntry.defaultsKey),
              let entry = try? JSONDecoder().decode(WidgetFlightEntry.self, from: data) else {
            return nil
        }
        return entry
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
