//
//  TimeStringConverter.swift
//  Block-Time
//
//  Pure-function converter from v1 String time fields to v2 TimeInterval.
//  Lives in the app target (D-03 — migration code stays in app target, not BlockTimeKit).
//  Plan 01-02 (FOUND-10)
//

import Foundation
import os

/// Converts v1 time-string storage format to `TimeInterval` (seconds).
///
/// V1 stores all time fields as `String?`. This converter handles every format
/// variant found in production data and must be correct before any migration
/// attempt — a silent zero from a non-zero source is permanent data loss.
///
/// **Duration formats handled (`toSeconds`):**
/// - `nil`, `""`, `"0"`, `"0.0"` → `0`
/// - Decimal hours: `"4.53"`, `"4.5"`, `"4"` → seconds
/// - HH:MM / H:MM / HH:M: `"4:32"`, `"9:05"`, `"4:5"` → seconds
/// - Malformed: `"-"`, `"N/A"` → `0` + os.Logger warning
/// - Whitespace: `"  4.53  "` → trimmed then parsed
///
/// **Clock formats handled (`clockStringToSecondsFromMidnight`):**
/// - `"HH:mm"` → seconds from midnight
/// - `"HHmm"` (no colon) → seconds from midnight
/// - Out-of-range / malformed → `nil`
enum TimeStringConverter {

    nonisolated(unsafe) private static let logger = Logger(
        subsystem: "com.thezoolab.blocktime",
        category: "Migration.TimeStringConverter"
    )

    // MARK: - Duration Strings → Seconds

    /// Converts a v1 duration string to `TimeInterval` (seconds).
    ///
    /// Returns `0` for nil, empty, explicit zero, or malformed input.
    /// Logs an `os.Logger` warning for malformed non-empty, non-zero strings
    /// so that data-loss risks are visible in Console.app during migration.
    ///
    /// - Parameter raw: The raw string from a v1 Core Data time field.
    /// - Returns: Duration in seconds, or `0` if input is absent or malformed.
    nonisolated static func toSeconds(_ raw: String?) -> TimeInterval {
        guard let raw else { return 0 }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Nil-equivalent values — not errors, just absent data
        guard !trimmed.isEmpty, trimmed != "0", trimmed != "0.0" else { return 0 }

        if trimmed.contains(":") {
            // HH:MM / H:MM / HH:M format
            let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let hours = Int(parts[0]),
                  let minutes = Int(parts[1]),
                  hours >= 0,
                  minutes >= 0,
                  minutes < 60 else {
                logger.warning("TimeStringConverter.toSeconds: malformed HH:MM '\(trimmed, privacy: .public)'")
                return 0
            }
            return TimeInterval(hours * 3600 + minutes * 60)
        } else {
            // Decimal hours format: "4.53", "4.5", "4", etc.
            guard let hours = Double(trimmed), hours.isFinite, hours >= 0 else {
                logger.warning("TimeStringConverter.toSeconds: malformed decimal '\(trimmed, privacy: .public)'")
                return 0
            }
            return hours * 3600.0
        }
    }

    // MARK: - Clock Strings → Seconds from Midnight

    /// Converts a v1 clock string to seconds from midnight UTC.
    ///
    /// Accepts `"HH:mm"` (e.g. `"09:15"`) and `"HHmm"` without colon (e.g. `"0915"`).
    /// Returns `nil` for nil, empty, malformed, or out-of-range input.
    ///
    /// - Parameter raw: The raw string from a v1 outTime / inTime / scheduledDeparture / scheduledArrival field.
    /// - Returns: Seconds from midnight UTC, or `nil` if input is absent or invalid.
    nonisolated static func clockStringToSecondsFromMidnight(_ raw: String?) -> TimeInterval? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Normalise: strip colon to get 4-digit string "HHMM"
        let clean = trimmed.replacingOccurrences(of: ":", with: "")
        guard clean.count == 4,
              let hours = Int(clean.prefix(2)),
              let minutes = Int(clean.suffix(2)),
              hours >= 0,
              hours < 24,
              minutes >= 0,
              minutes < 60 else {
            return nil
        }

        return TimeInterval(hours * 3600 + minutes * 60)
    }
}
