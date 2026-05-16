// FlightEntityMigrationPolicy.swift
// Custom NSEntityMigrationPolicy for V1→V2 FlightDataModel migration.
// Converts decimal-hour / "HH:MM" time strings to Int16 minutes (D-01)
// and UTC "HH:MM" gate strings to UTC Date? (D-05).
// Nil or malformed inputs → 0 (time fields) or nil (gate fields) per D-06.

import CoreData
import Foundation

final class FlightEntityMigrationPolicy: NSEntityMigrationPolicy {

    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: source, in: mapping, manager: manager)

        guard let destination = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [source]
        ).first else { return }

        // Time string columns → Int16 minutes.
        // SOURCE keys = legacy v1 attribute names (still String? in V1).
        // DESTINATION keys = new Int16 scalar columns in V2 (canonical names).
        let timeFields: [(src: String, dst: String)] = [
            ("blockTime", "blockTime"),
            ("simTime", "simTime"),
            ("nightTime", "nightTime"),
            ("p1Time", "p1Time"),
            ("p1usTime", "p1usTime"),
            ("p2Time", "p2Time"),
            ("instrumentTime", "instrumentTime"),
            ("spInsTime", "spInsTime")
        ]
        for (srcKey, dstKey) in timeFields {
            let raw = source.value(forKey: srcKey) as? String
            destination.setValue(Self.stringToMinutes(raw), forKey: dstKey)
        }

        // Gate string columns → Date? using flight date (UTC midnight).
        let flightDate = source.value(forKey: "date") as? Date ?? Date(timeIntervalSince1970: 0)
        let gateFields: [(src: String, dst: String)] = [
            ("outTime", "outTime"),
            ("inTime", "inTime"),
            ("scheduledDeparture", "scheduledDeparture"),
            ("scheduledArrival", "scheduledArrival")
        ]
        for (srcKey, dstKey) in gateFields {
            let raw = source.value(forKey: srcKey) as? String
            destination.setValue(Self.stringToDate(raw, on: flightDate), forKey: dstKey)
        }

        // dualTime defaults to 0 via the V2 model default — no action needed.
    }

    // MARK: - Inline conversion (D-01: inline, no external dependency)

    /// Decimal-hour or "HH:MM" string → Int16 minutes. Nil/malformed → 0.
    private static func stringToMinutes(_ raw: String?) -> Int16 {
        guard let raw else { return 0 }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s != "0", s != "0.0" else { return 0 }
        if s.contains(":") {
            let parts = s.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let h = Int(parts[0]), let m = Int(parts[1]),
                  h >= 0, m >= 0, m < 60 else { return 0 }
            return Int16(min(h * 60 + m, Int(Int16.max)))
        } else {
            guard let hours = Double(s), hours.isFinite, hours >= 0 else { return 0 }
            return Int16(min(Int(hours * 60), Int(Int16.max)))
        }
    }

    /// "HH:MM" or "HHMM" UTC string + UTC-midnight Date → UTC Date?. Nil/malformed → nil. (D-05)
    private static func stringToDate(_ raw: String?, on utcMidnight: Date) -> Date? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = s.replacingOccurrences(of: ":", with: "")
        guard clean.count == 4,
              let hours = Int(clean.prefix(2)),
              let minutes = Int(clean.suffix(2)),
              hours >= 0, hours < 24,
              minutes >= 0, minutes < 60 else { return nil }
        return utcMidnight.addingTimeInterval(TimeInterval(hours * 3600 + minutes * 60))
    }
}
