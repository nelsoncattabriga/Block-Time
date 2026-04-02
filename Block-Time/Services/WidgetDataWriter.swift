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

    /// Fetches the next future flight, writes snapshot, and reloads the widget timeline.
    /// Safe to call as often as needed — WidgetCenter coalesces rapid calls.
    func updateWidgetSnapshot() {
        let context = FlightDatabaseService.shared.viewContext

        // viewContext is always on the main thread; class is @MainActor — call directly.
        let snapshot = buildSnapshot(context: context)

        if let snapshot, let encoded = try? JSONEncoder().encode(snapshot) {
            UserDefaults(suiteName: WidgetFlightEntry.appGroupID)?
                .set(encoded, forKey: WidgetFlightEntry.defaultsKey)
        } else {
            UserDefaults(suiteName: WidgetFlightEntry.appGroupID)?
                .removeObject(forKey: WidgetFlightEntry.defaultsKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "BlockTimeWidget")
    }

    // MARK: - Private

    /// Builds the snapshot entirely within a Core Data context queue (nonisolated).
    /// Returns nil if there is no suitable upcoming flight.
    private func buildSnapshot(context: NSManagedObjectContext) -> WidgetFlightEntry? {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "date >= %@", startOfToday as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: true)]
        request.fetchLimit = 10

        guard let flights = try? context.fetch(request), !flights.isEmpty else { return nil }

        let now = Date()
        var chosen: FlightEntity?

        for flight in flights {
            guard let flightDate = flight.date else { continue }
            let depDatetime = buildDatetime(flightDate: flightDate, timeString: flight.scheduledDeparture)
            let effectiveTime = depDatetime ?? flightDate
            if effectiveTime >= now {
                chosen = flight
                break
            }
        }

        guard let entity = chosen, let flightDate = entity.date else { return nil }

        let depDatetime = buildDatetime(flightDate: flightDate, timeString: entity.scheduledDeparture)
        let arrDatetime = buildDatetime(flightDate: flightDate, timeString: entity.scheduledArrival)
        let useIATA = UserDefaults.standard.bool(forKey: "useIATACodes")

        return WidgetFlightEntry(
            flightNumber:      (entity.flightNumber ?? "").trimmingCharacters(in: .whitespaces),
            fromAirport:       (entity.fromAirport ?? "").uppercased(),
            toAirport:         (entity.toAirport ?? "").uppercased(),
            flightDate:        flightDate,
            departureDatetime: depDatetime,
            arrivalDatetime:   arrDatetime,
            useIATACodes:      useIATA,
            snapshotDate:      Date()
        )
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
