//
//  CalendarExportService.swift
//  Block-Time
//

import Foundation

@MainActor
final class CalendarExportService {

    static let shared = CalendarExportService()
    private init() {}

    // MARK: - Public API

    /// Generates an iCalendar (.ics) string from an array of flights.
    /// Events are grouped by duty day. Mode controls whether all-day, sector, or both
    /// event types are emitted.
    func generateICS(from flights: [FlightSector], settings: CalendarExportSettings) -> String {
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

        // Group flights by date string, sorted chronologically
        let grouped = groupByDate(flights)

        for (dateStr, dayFlights) in grouped {
            let sortedFlights = sortByDeparture(dayFlights)

            if settings.mode == .allDayOnly || settings.mode == .both {
                if let event = buildDailyEvent(date: dateStr, flights: sortedFlights, settings: settings) {
                    lines += event
                }
            }

            if settings.mode == .sectorsOnly || settings.mode == .both {
                for flight in sortedFlights {
                    if let event = buildSectorEvent(for: flight, settings: settings) {
                        lines += event
                    }
                }
            }
        }

        lines.append("END:VCALENDAR")

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Title Builders (internal for preview access in CalendarFormatSheet)

    func buildSectorTitle(for flight: FlightSector, settings: CalendarExportSettings) -> String {
        let enabled = settings.enabledSector()
        var tokens: [String] = []

        let fromToken = flight.fromAirport
        let toToken   = flight.toAirport
        let fnRaw     = flight.flightNumber.isEmpty ? nil : flight.flightNumber

        let flightNumberEnabled = enabled.contains(.flightNumber)

        for component in enabled {
            switch component {
            case .std:
                if let s = sectorSTD(flight) { tokens.append(s) }
            case .flightNumber:
                if let fn = fnRaw { tokens.append(fn) }
            case .from:
                tokens.append(fromToken)
            case .to:
                tokens.append(toToken)
            case .sta:
                if let s = sectorSTA(flight) { tokens.append(s) }
            case .paxIndicator:
                guard flight.isPositioning else { break }
                if flightNumberEnabled, let fn = fnRaw, let idx = tokens.firstIndex(of: fn) {
                    // Merge PAX before the already-appended flight number token
                    tokens[idx] = "PAX \(fn)"
                } else {
                    tokens.append("PAX")
                }
            }
        }

        // Collapse adjacent from -> to into "FROM -> TO"
        tokens = collapseFromTo(tokens, fromToken: fromToken, toToken: toToken, enabled: enabled)

        return tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    func buildDailyTitle(for flights: [FlightSector], settings: CalendarExportSettings) -> String {
        guard !flights.isEmpty else { return "" }
        let enabled = settings.enabledAllDay()
        var tokens: [String] = []

        let flightNumbersEnabled = enabled.contains(.flightNumbers)
        let routeEnabled         = enabled.contains(.route)

        for component in enabled {
            switch component {
            case .firstSTD:
                if let t = dailyFirstSTD(flights) { tokens.append(t) }
            case .route:
                let routeStr = buildRouteChain(flights, includeFlightNumbers: flightNumbersEnabled)
                if !routeStr.isEmpty { tokens.append(routeStr) }
            case .lastSTA:
                if let t = dailyLastSTA(flights) { tokens.append(t) }
            case .flightNumbers:
                // Only emit standalone when route is disabled; otherwise already embedded in route
                if !routeEnabled {
                    let routeStr = buildRouteChain(flights, includeFlightNumbers: true)
                    if !routeStr.isEmpty { tokens.append(routeStr) }
                }
            }
        }

        return tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private Event Builders

    private func buildSectorEvent(for flight: FlightSector, settings: CalendarExportSettings) -> [String]? {
        let (dtStart, dtEnd, isAllDay) = resolveTimes(for: flight)
        guard let dtStart, let dtEnd else { return nil }

        let title = buildSectorTitle(for: flight, settings: settings)
        let uid   = flight.id.uuidString + "@block-time-sector"
        let now   = iCalTimestamp(Date())

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

        lines.append("END:VEVENT")
        return lines
    }

    private func buildDailyEvent(date: String, flights: [FlightSector], settings: CalendarExportSettings) -> [String]? {
        guard let parsedDate = parseFlightDate(date) else { return nil }
        let startStr = allDayString(parsedDate)
        let endDate  = Calendar.current.date(byAdding: .day, value: 1, to: parsedDate) ?? parsedDate
        let endStr   = allDayString(endDate)

        let title   = buildDailyTitle(for: flights, settings: settings)
        let uidDate = allDayString(parsedDate)
        let uid     = "\(uidDate)@block-time-daily"
        let now     = iCalTimestamp(Date())

        var lines: [String] = ["BEGIN:VEVENT"]
        lines.append("UID:\(uid)")
        lines.append("DTSTAMP:\(now)")
        lines.append("SUMMARY:\(icsEscape(title))")
        lines.append("DTSTART;VALUE=DATE:\(startStr)")
        lines.append("DTEND;VALUE=DATE:\(endStr)")
        lines.append("END:VEVENT")
        return lines
    }

    // MARK: - Grouping + Sorting

    private func groupByDate(_ flights: [FlightSector]) -> [(String, [FlightSector])] {
        var dict: [String: [FlightSector]] = [:]
        for flight in flights {
            dict[flight.date, default: []].append(flight)
        }
        return dict.sorted { a, b in
            let da = parseFlightDate(a.key) ?? .distantPast
            let db = parseFlightDate(b.key) ?? .distantPast
            return da < db
        }
    }

    private func sortByDeparture(_ flights: [FlightSector]) -> [FlightSector] {
        flights.sorted { a, b in
            let ta = hhmmStripColon(firstNonEmpty(a.scheduledDeparture, a.outTime) ?? "9999")
            let tb = hhmmStripColon(firstNonEmpty(b.scheduledDeparture, b.outTime) ?? "9999")
            return ta < tb
        }
    }

    // MARK: - Sector time helpers

    private func sectorSTD(_ flight: FlightSector) -> String? {
        if !flight.scheduledDeparture.isEmpty, let colon = hhmmToColon(flight.scheduledDeparture) {
            return colon
        }
        if flight.outTime.count == 5 && flight.outTime.contains(":") {
            return flight.outTime
        }
        return nil
    }

    private func sectorSTA(_ flight: FlightSector) -> String? {
        if !flight.scheduledArrival.isEmpty, let colon = hhmmToColon(flight.scheduledArrival) {
            return colon
        }
        if flight.inTime.count == 5 && flight.inTime.contains(":") {
            return flight.inTime
        }
        return nil
    }

    // MARK: - All-day time helpers

    private func dailyFirstSTD(_ flights: [FlightSector]) -> String? {
        let stds = flights.compactMap { f -> String? in
            if !f.scheduledDeparture.isEmpty { return f.scheduledDeparture }
            if f.outTime.count == 5 && f.outTime.contains(":") { return hhmmStripColon(f.outTime) }
            return nil
        }
        guard let earliest = stds.min() else { return nil }
        return hhmmStripColon(earliest)
    }

    private func dailyLastSTA(_ flights: [FlightSector]) -> String? {
        let stas = flights.compactMap { f -> String? in
            if !f.scheduledArrival.isEmpty { return f.scheduledArrival }
            if f.inTime.count == 5 && f.inTime.contains(":") { return hhmmStripColon(f.inTime) }
            return nil
        }
        guard let latest = stas.max() else { return nil }
        return hhmmStripColon(latest)
    }

    // MARK: - Route chain builder

    /// Builds a route chain for an all-day event.
    /// Without flight numbers: "BNE -> SYD -> MEL -> BNE"
    /// With flight numbers: "QF101 BNE -> SYD -> QF203 MEL -> BNE"
    /// PAX sectors prefix the flight number with "PAX ".
    private func buildRouteChain(_ flights: [FlightSector], includeFlightNumbers: Bool) -> String {
        guard !flights.isEmpty else { return "" }

        guard includeFlightNumbers else {
            // Simple deduped airport chain
            var airports: [String] = []
            for flight in flights {
                if airports.last != flight.fromAirport {
                    airports.append(flight.fromAirport)
                }
                if airports.last != flight.toAirport {
                    airports.append(flight.toAirport)
                }
            }
            return airports.joined(separator: " -> ")
        }

        // Annotated chain: "QF101 BNE -> SYD -> QF203 MEL -> BNE"
        // Build as a flat list of tokens then join with " -> "
        var segments: [String] = []
        var lastTo: String = ""

        for flight in flights {
            let fn        = flight.flightNumber.isEmpty ? nil : flight.flightNumber
            let fnDisplay = fn.map { flight.isPositioning ? "PAX \($0)" : $0 }

            let from = flight.fromAirport
            let to   = flight.toAirport

            if lastTo != from || lastTo.isEmpty {
                // Need to include from airport
                if let label = fnDisplay {
                    segments.append("\(label) \(from)")
                } else {
                    segments.append(from)
                }
            } else {
                // from is continuation of previous toAirport — insert annotation before from if needed
                if let label = fnDisplay {
                    segments.append("\(label) \(from)")
                }
                // else: the previous segment's to already covers this from, no repeat
            }

            segments.append(to)
            lastTo = to
        }

        return segments.joined(separator: " -> ")
    }

    // MARK: - from->to collapsing

    private func collapseFromTo(
        _ tokens: [String],
        fromToken: String,
        toToken: String,
        enabled: [SectorComponent]
    ) -> [String] {
        guard enabled.contains(.from) && enabled.contains(.to) else { return tokens }
        guard !fromToken.isEmpty && !toToken.isEmpty else { return tokens }

        var result: [String] = []
        var i = 0
        while i < tokens.count {
            let t = tokens[i]
            // Match plain fromToken or PAX-prefixed fromToken equivalent
            if (t == fromToken || t.hasSuffix(" \(fromToken)") == false) &&
                t == fromToken &&
                i + 1 < tokens.count &&
                tokens[i + 1] == toToken {
                result.append("\(fromToken) -> \(toToken)")
                i += 2
            } else {
                result.append(t)
                i += 1
            }
        }
        return result
    }

    // MARK: - HHMM helpers

    /// Converts "0900" -> "09:00". Returns nil if not exactly 4 digits.
    func hhmmToColon(_ s: String) -> String? {
        guard s.count == 4, s.allSatisfy({ $0.isNumber }) else { return nil }
        let h = s.prefix(2)
        let m = s.suffix(2)
        return "\(h):\(m)"
    }

    /// Converts "09:00" or "0900" -> "0900".
    func hhmmStripColon(_ s: String) -> String {
        s.replacingOccurrences(of: ":", with: "")
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
        let endDate  = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        let endStr   = allDayString(endDate)
        return (startStr, endStr, true)
    }

    /// firstNonEmpty: accepts HH:MM (colon, len 5) or HHMM (4 digits) — converts HHMM to HH:MM.
    private func firstNonEmpty(_ a: String, _ b: String) -> String? {
        if a.count == 5 && a.contains(":") { return a }
        if a.count == 4 && a.allSatisfy({ $0.isNumber }), let colon = hhmmToColon(a) { return colon }
        if b.count == 5 && b.contains(":") { return b }
        if b.count == 4 && b.allSatisfy({ $0.isNumber }), let colon = hhmmToColon(b) { return colon }
        return nil
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
