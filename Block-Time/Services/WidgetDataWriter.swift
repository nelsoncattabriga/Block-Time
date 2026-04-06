//
//  WidgetDataWriter.swift
//  Block-Time
//
//  Fetches the next upcoming flight from Core Data and writes a lightweight
//  JSON snapshot to the shared App Group UserDefaults so the widget can read it.
//  This runs entirely on the main actor via FlightDatabaseService.viewContext.
//

import Foundation
import CoreData
import WidgetKit

@MainActor
final class WidgetDataWriter {

    static let shared = WidgetDataWriter()
    private init() {}


    // MARK: - Public API

    /// Fetches the next 5 future flights, writes snapshot array, and reloads the widget timeline.
    /// Safe to call as often as needed — WidgetCenter coalesces rapid calls.
    func updateWidgetSnapshot() {
        let context = FlightDatabaseService.shared.viewContext
        let snapshots = buildSnapshots(context: context)

        let defaults = UserDefaults(suiteName: WidgetFlightEntry.appGroupID)
        if !snapshots.isEmpty, let encoded = try? JSONEncoder().encode(snapshots) {
            defaults?.set(encoded, forKey: WidgetFlightEntry.listDefaultsKey)
        } else {
            defaults?.removeObject(forKey: WidgetFlightEntry.listDefaultsKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "BlockTimeWidget")
    }

    // MARK: - Private

    /// Returns up to 5 upcoming flights (departure >= now), sorted ascending.
    private func buildSnapshots(context: NSManagedObjectContext) -> [WidgetFlightEntry] {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        // FlightEntity.date is stored as UTC midnight, so use a UTC calendar here to
        // avoid including yesterday's flights for users in positive UTC offsets.
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let startOfToday = utcCal.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "date >= %@", startOfToday as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FlightEntity.date, ascending: true),
            NSSortDescriptor(keyPath: \FlightEntity.scheduledDeparture, ascending: true)
        ]
        request.fetchLimit = 20   // fetch extra so we can filter by effective departure time

        guard let flights = try? context.fetch(request), !flights.isEmpty else { return [] }

        let now = Date()
        let useIATA = UserDefaults.standard.bool(forKey: "useIATACodes")
        var results: [WidgetFlightEntry] = []

        for entity in flights {
            guard let flightDate = entity.date else { continue }
            let depDatetime = buildDatetime(flightDate: flightDate, timeString: entity.scheduledDeparture)
            let effectiveTime = depDatetime ?? flightDate
            guard effectiveTime >= now else { continue }

            let arrDatetime = buildDatetime(flightDate: flightDate, timeString: entity.scheduledArrival)
            results.append(WidgetFlightEntry(
                flightNumber:      (entity.flightNumber ?? "").trimmingCharacters(in: .whitespaces),
                fromAirport:       (entity.fromAirport ?? "").uppercased(),
                toAirport:         (entity.toAirport ?? "").uppercased(),
                flightDate:        flightDate,
                departureDatetime: depDatetime,
                arrivalDatetime:   arrDatetime,
                useIATACodes:      useIATA,
                snapshotDate:      Date()
            ))

            if results.count == 5 { break }
        }

        return results
    }

}

// MARK: - File-level helpers (nonisolated, callable from performAndWait closures)

private let _widgetTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

/// Combines a UTC flight date with a "HH:MM" time string into a full UTC Date.
private func buildDatetime(flightDate: Date, timeString: String?) -> Date? {
    guard let raw = timeString, raw.count == 5,
          let timeDate = _widgetTimeFormatter.date(from: raw) else { return nil }

    var utcCal = Calendar(identifier: .gregorian)
    utcCal.timeZone = TimeZone(secondsFromGMT: 0)!

    let timeComponents = utcCal.dateComponents([.hour, .minute], from: timeDate)
    let dateComponents = utcCal.dateComponents([.year, .month, .day], from: flightDate)

    var combined = DateComponents()
    combined.year     = dateComponents.year
    combined.month    = dateComponents.month
    combined.day      = dateComponents.day
    combined.hour     = timeComponents.hour
    combined.minute   = timeComponents.minute
    combined.second   = 0
    combined.timeZone = TimeZone(secondsFromGMT: 0)

    return utcCal.date(from: combined)
}
