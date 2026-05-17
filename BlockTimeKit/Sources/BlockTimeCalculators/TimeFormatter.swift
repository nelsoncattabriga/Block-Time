// TimeFormatter.swift
// Pure-function namespace for time format conversions.
// No DateFormatter, no locale, no I/O. Foundation only.

import Foundation

/// Pure-function namespace for converting between Int minutes and display strings.
/// All call sites in the app target are rewired in Phase 4/5 (D-12).
public enum TimeFormatter {

    /// Converts minutes to HH:MM string. Example: 90 → "1:30", 0 → "0:00".
    /// Negative input is clamped to "0:00".
    public static func minutesToHHMM(_ minutes: Int) -> String {
        guard minutes >= 0 else { return "0:00" }
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }

    /// Converts minutes to decimal hours string. Example: 90 → "1.50", 0 → "0.00".
    /// Negative input is clamped to "0.00".
    public static func minutesToDecimalHours(_ minutes: Int) -> String {
        guard minutes >= 0 else { return "0.00" }
        return String(format: "%.2f", Double(minutes) / 60.0)
    }

    /// Parses "H:MM" or "HH:MM" to total minutes. Returns nil for malformed input.
    /// Hours are unbounded; minutes must be 0..<60.
    /// Examples: "1:30" → 90, "01:30" → 90, "1:99" → nil, "abc" → nil, "" → nil.
    public static func hhmmToMinutes(_ string: String) -> Int? {
        let parts = string.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2,
              !parts[0].isEmpty, !parts[1].isEmpty,
              let h = Int(parts[0]), let m = Int(parts[1]),
              h >= 0, m >= 0, m < 60 else { return nil }
        return h * 60 + m
    }

    /// Parses a decimal-hours string or HH:MM string to total minutes. Returns nil for malformed
    /// or negative input. Delegates to hhmmToMinutes when ":" is present.
    /// Examples: "1.5" → 90, "1:30" → 90, "abc" → nil, "-1.5" → nil, "" → nil.
    public static func decimalHoursStringToMinutes(_ string: String) -> Int? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.contains(":") { return hhmmToMinutes(s) }
        guard let hours = Double(s), hours.isFinite, hours >= 0 else { return nil }
        return Int(hours * 60)
    }
}
