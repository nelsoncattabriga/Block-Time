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
    let countdownLabel: String       // Pre-computed label for this entry e.g. "3 Days", "1 Hr"
}

// MARK: - Provider

struct NextFlightProvider: TimelineProvider {

    // MARK: Placeholder (shown while widget loads / in gallery)
    func placeholder(in context: Context) -> NextFlightTimelineEntry {
        NextFlightTimelineEntry(date: .now, flight: .placeholder, countdownLabel: "6 Hrs")
    }

    // MARK: Snapshot (shown in widget picker preview)
    func getSnapshot(in context: Context, completion: @escaping (NextFlightTimelineEntry) -> Void) {
        let flight = readSnapshot() ?? .placeholder
        let label = Self.label(for: flight.departureDatetime ?? flight.flightDate, at: .now)
        completion(NextFlightTimelineEntry(date: .now, flight: flight, countdownLabel: label))
    }

    // MARK: Timeline
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextFlightTimelineEntry>) -> Void) {
        let now = Date()
        let snapshot = readSnapshot()

        guard let flight = snapshot,
              let departure = flight.departureDatetime ?? Optional(flight.flightDate) else {
            // No flight — check again in 1 hour
            let entry = NextFlightTimelineEntry(date: now, flight: nil, countdownLabel: "")
            let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
            completion(Timeline(entries: [entry], policy: .after(refresh)))
            return
        }

        // Checkpoints as (offset from departure, label shown from that point)
        let checkpoints: [(offset: TimeInterval, label: String)] = [
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

        for (offset, label) in checkpoints {
            let entryDate = departure.addingTimeInterval(offset)
            if entryDate >= now {
                entries.append(NextFlightTimelineEntry(date: entryDate, flight: flight, countdownLabel: label))
            }
        }

        // Always include a current entry with the appropriate label
        if entries.isEmpty || entries.first!.date > now {
            let currentLabel = Self.label(for: departure, at: now)
            entries.insert(NextFlightTimelineEntry(date: now, flight: flight, countdownLabel: currentLabel), at: 0)
        }

        // Refresh 1 hour after departure to pick up the next flight
        let refreshDate = departure.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
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
