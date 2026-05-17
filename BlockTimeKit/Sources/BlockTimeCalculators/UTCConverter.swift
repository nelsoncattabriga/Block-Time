// UTCConverter.swift
// Pure UTC ↔ local conversions. Caller resolves ICAO → TimeZone via AirportService (D-08, D-10).
// No Calendar.current, no TimeZone.current, no LogManager. Foundation only.

import Foundation

/// Pure-function namespace for UTC ↔ local timezone conversions.
/// All functions accept `TimeZone` directly — the caller resolves ICAO codes via AirportService.
public enum UTCConverter {

    /// Treats the wall-clock date components of `date` as belonging to `timeZone`,
    /// then returns the corresponding UTC instant.
    /// Example: date whose UTC components read "10:00 on 2026-06-01" + Sydney (UTC+10) → UTC 00:00.
    public static func localToUTC(date: Date, timeZone: TimeZone) -> Date {
        var src = Calendar(identifier: .gregorian)
        src.timeZone = timeZone
        let comps = src.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        var dst = Calendar(identifier: .gregorian)
        dst.timeZone = TimeZone(identifier: "UTC")!
        return dst.date(from: comps) ?? date
    }

    /// Inverse of localToUTC: takes a UTC instant and projects its components into `timeZone`,
    /// returning a Date whose UTC components match those local wall-clock components.
    /// `utcToLocal(localToUTC(d, tz), tz)` round-trips at minute precision.
    public static func utcToLocal(date: Date, timeZone: TimeZone) -> Date {
        var src = Calendar(identifier: .gregorian)
        src.timeZone = TimeZone(identifier: "UTC")!
        let comps = src.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        var dst = Calendar(identifier: .gregorian)
        dst.timeZone = timeZone
        return dst.date(from: comps) ?? date
    }

    /// Strict HH:MM / H:MM parser. Hours 0–23, minutes must be exactly two digits (0–59).
    /// Returns nil for any malformed input including "9:3" (single-digit minutes), "24:00", "".
    public static func parseHHMM(_ string: String) -> (hour: Int, minute: Int)? {
        let parts = string.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2,
              !parts[0].isEmpty,
              parts[1].count == 2,          // minutes must be exactly 2 digits
              let h = Int(parts[0]), let m = Int(parts[1]),
              h >= 0, h < 24,
              m >= 0, m < 60 else { return nil }
        return (h, m)
    }

    /// Combines a calendar date with a wall-clock "HH:MM" string in `timeZone` and returns
    /// the corresponding UTC `Date`. Returns nil when `hhmm` is malformed.
    /// Algorithm matches `FlightDatabaseService.swift` lines 2172-2183 (proven correct).
    public static func combineDateAndTime(date: Date, hhmm: String, timeZone: TimeZone) -> Date? {
        guard let (hours, minutes) = parseHHMM(hhmm) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = hours
        comps.minute = minutes
        comps.second = 0
        return cal.date(from: comps)
    }
}
