//
//  CalendarExportService.swift
//  Block-Time
//

import Foundation

final class CalendarExportService {

    static let shared = CalendarExportService()
    private init() {}

    // MARK: - Public API

    /// Generates an iCalendar (.ics) string from an array of flights.
    /// Each flight becomes one VEVENT. Times are stored as UTC.
    func generateICS(from flights: [FlightSector]) -> String {
        var lines: [String] = []

        lines += [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Block-Time//Flight Logbook//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:Block-Time Flights",
            "X-WR-TIMEZONE:UTC",
        ]

        for flight in flights {
            if let event = buildEvent(for: flight) {
                lines += event
            }
        }

        lines.append("END:VCALENDAR")

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Private

    private func buildEvent(for flight: FlightSector) -> [String]? {
        // Determine start/end times.
        // Prefer OUT/IN (actual gate times), fall back to scheduled, then date-only.
        let (dtStart, dtEnd, isAllDay) = resolveTimes(for: flight)

        guard let dtStart, let dtEnd else { return nil }

        let title = eventTitle(for: flight)
        let description = eventDescription(for: flight)
        let uid = flight.id.uuidString + "@block-time"
        let now = iCalTimestamp(Date())

        var lines: [String] = ["BEGIN:VEVENT"]
        lines.append("UID:\(uid)")
        lines.append("DTSTAMP:\(now)")
        lines.append("SUMMARY:\(icsEscape(title))")

        if isAllDay {
            lines.append("DTSTART;VALUE=DATE:\(dtStart)")
            lines.append("DTEND;VALUE=DATE:\(dtEnd)")
        } else {
            lines.append("DTSTART:\(dtStart)")
            lines.append("DTEND:\(dtEnd)")
        }

        if !description.isEmpty {
            lines.append("DESCRIPTION:\(icsEscape(description))")
        }

        lines.append("END:VEVENT")
        return lines
    }

    // MARK: - Time Resolution

    /// Returns (dtStart, dtEnd, isAllDay).
    /// dtStart/dtEnd are either "YYYYMMDDTHHmmSSZ" (UTC) or "YYYYMMDD" (all-day).
    private func resolveTimes(for flight: FlightSector) -> (String?, String?, Bool) {
        guard let date = parseFlightDate(flight.date) else { return (nil, nil, false) }

        // Try OUT time first, then STD, then fall back to all-day
        let depTimeStr = firstNonEmpty(flight.outTime, flight.scheduledDeparture)
        let arrTimeStr = firstNonEmpty(flight.inTime, flight.scheduledArrival)

        if let depStr = depTimeStr, let arrStr = arrTimeStr,
           let dtStart = utcDateTimeString(date: date, hhmm: depStr),
           var dtEnd   = utcDateTimeString(date: date, hhmm: arrStr) {
            // Handle overnight: if arrival is before departure, add one day
            if dtEnd < dtStart {
                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) {
                    dtEnd = utcDateTimeString(date: tomorrow, hhmm: arrStr) ?? dtEnd
                }
            }
            return (dtStart, dtEnd, false)
        }

        // All-day fallback
        let startStr = allDayString(date)
        // End date in iCal all-day is exclusive, so +1 day
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        let endStr = allDayString(endDate)
        return (startStr, endStr, true)
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values.first(where: { ($0 ?? "").count == 5 && ($0 ?? "").contains(":") })?.flatMap { $0 }
    }

    // Overload for non-optional strings
    private func firstNonEmpty(_ a: String, _ b: String) -> String? {
        if a.count == 5 && a.contains(":") { return a }
        if b.count == 5 && b.contains(":") { return b }
        return nil
    }

    // MARK: - Event Content

    private func eventTitle(for flight: FlightSector) -> String {
        let fn = flight.flightNumber.isEmpty ? "" : "\(flight.flightNumber) "
        return "\(fn)\(flight.fromAirport) → \(flight.toAirport)"
    }

    private func eventDescription(for flight: FlightSector) -> String {
        var parts: [String] = []

        if !flight.aircraftReg.isEmpty  { parts.append("Aircraft: \(flight.aircraftReg)") }
        if !flight.aircraftType.isEmpty { parts.append("Type: \(flight.aircraftType)") }

        let block = Double(flight.blockTime) ?? 0
        if block > 0 { parts.append("Block: \(formatHours(block))") }

        let roles = roleString(for: flight)
        if !roles.isEmpty { parts.append("Role: \(roles)") }

        if !flight.remarks.isEmpty { parts.append("Remarks: \(flight.remarks)") }

        return parts.joined(separator: "\\n")
    }

    private func roleString(for flight: FlightSector) -> String {
        if flight.isPositioning { return "Positioning" }
        if flight.isPilotFlying  { return "PF" }
        return "PM"
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return String(format: "%d:%02d", h, m)
    }

    // MARK: - Date/Time Helpers

    private static let flightDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func parseFlightDate(_ dateStr: String) -> Date? {
        CalendarExportService.flightDateFormatter.date(from: dateStr)
    }

    /// "YYYYMMDD" for all-day events
    private func allDayString(_ date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year!, c.month!, c.day!)
    }

    /// "YYYYMMDDTHHmmSSZ" from a base date + "HH:MM" string (UTC)
    private func utcDateTimeString(date: Date, hhmm: String) -> String? {
        let parts = hhmm.components(separatedBy: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              h >= 0, h <= 23, m >= 0, m <= 59 else { return nil }

        var comps = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day], from: date
        )
        comps.hour   = h
        comps.minute = m
        comps.second = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)

        guard let dt = Calendar(identifier: .gregorian).date(from: comps) else { return nil }
        return iCalTimestamp(dt)
    }

    /// "YYYYMMDDTHHmmSSZ"
    private func iCalTimestamp(_ date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
        return String(format: "%04d%02d%02dT%02d%02d%02dZ",
                      comps.year!, comps.month!, comps.day!,
                      comps.hour!, comps.minute!, comps.second!)
    }

    /// Escape special iCal characters in text values
    private func icsEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";",  with: "\\;")
            .replacingOccurrences(of: ",",  with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
