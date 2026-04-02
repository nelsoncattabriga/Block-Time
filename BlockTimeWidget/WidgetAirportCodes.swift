//
//  WidgetAirportCodes.swift
//  BlockTimeWidget
//
//  Lightweight ICAO→IATA and ICAO→TimeZone lookup for use in the widget extension.
//  Parses the same airports.dat.txt file used by AirportService.
//  Add airports.dat.txt to the widget extension target in Build Phases → Copy Bundle Resources.
//

import Foundation

enum WidgetAirportCodes {

    private struct AirportRecord {
        let iata: String?
        let timezoneOffset: Double  // raw UTC offset in hours (without DST)
        let dstCode: String
    }

    // Parsed once, lazily, and cached for the widget's lifetime
    private static let records: [String: AirportRecord] = buildRecords()
    private static let iataMap: [String: String] = {
        records.compactMapValues { $0.iata }
    }()

    // MARK: - Public API

    /// Returns the IATA code for an ICAO code, or nil if unknown.
    static func iataFor(icao: String) -> String? {
        iataMap[icao.uppercased()]
    }

    /// Returns a TimeZone for an ICAO code with correct DST applied for the given date.
    /// Falls back to the device's local timezone if the airport is not found.
    static func timeZone(for icao: String, on date: Date) -> TimeZone {
        guard let record = records[icao.uppercased()] else { return .current }
        var offset = record.timezoneOffset
        if isDSTActive(on: date, dstCode: record.dstCode) {
            offset += 1.0
        }
        return TimeZone(secondsFromGMT: Int(offset * 3600)) ?? .current
    }

    // MARK: - Parser

    private static func buildRecords() -> [String: AirportRecord] {
        guard let url = Bundle.main.url(forResource: "airports.dat", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }

        var result: [String: AirportRecord] = [:]
        result.reserveCapacity(10_000)

        content.enumerateLines { line, _ in
            let parts = parseCSVLine(line)
            guard parts.count >= 11 else { return }

            let iata = parts[4].trimmingCharacters(in: .init(charactersIn: "\" "))
            let icao = parts[5].trimmingCharacters(in: .init(charactersIn: "\" "))
            guard icao.count == 4, icao != "\\N" else { return }

            guard let offset = Double(parts[9]) else { return }
            let dstCode = parts[10].trimmingCharacters(in: .init(charactersIn: "\" "))
            let validIata = (iata.count == 3 && iata != "\\N") ? iata : nil

            result[icao] = AirportRecord(iata: validIata, timezoneOffset: offset, dstCode: dstCode)
        }

        return result
    }

    /// Minimal CSV line parser that handles quoted fields containing commas.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - DST logic (ported from AirportService)

    private static func isDSTActive(on date: Date, dstCode: String) -> Bool {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)

        switch dstCode {
        case "E": // Europe: last Sun Mar → last Sun Oct
            return date >= lastSunday(month: 3, year: year) && date < lastSunday(month: 10, year: year)
        case "A": // US/Canada: 2nd Sun Mar → 1st Sun Nov
            return date >= nthSunday(month: 3, year: year, n: 2) && date < nthSunday(month: 11, year: year, n: 1)
        case "S": // South America: 3rd Sun Oct → 3rd Sun Mar
            if month >= 10 { return date >= nthSunday(month: 10, year: year, n: 3) }
            if month <= 3  { return date < nthSunday(month: 3, year: year, n: 3) }
            return false
        case "O": // Australia: 1st Sun Oct → 1st Sun Apr
            if month >= 10 { return date >= nthSunday(month: 10, year: year, n: 1) }
            if month <= 4  { return date < nthSunday(month: 4, year: year, n: 1) }
            return false
        case "Z": // New Zealand: last Sun Sep → 1st Sun Apr
            if month >= 9 { return date >= lastSunday(month: 9, year: year) }
            if month <= 4 { return date < nthSunday(month: 4, year: year, n: 1) }
            return false
        default: // N, U, unknown
            return false
        }
    }

    private static func lastSunday(month: Int, year: Int) -> Date {
        let cal = Calendar.current
        var c = DateComponents(); c.year = year; c.month = month + 1; c.day = 1
        guard let firstOfNext = cal.date(from: c),
              let lastDay = cal.date(byAdding: .day, value: -1, to: firstOfNext) else { return .distantPast }
        let weekday = cal.component(.weekday, from: lastDay) // 1=Sun
        let sub = (weekday + 6) % 7
        return cal.date(byAdding: .day, value: -sub, to: lastDay) ?? .distantPast
    }

    private static func nthSunday(month: Int, year: Int, n: Int) -> Date {
        let cal = Calendar.current
        var c = DateComponents(); c.year = year; c.month = month; c.day = 1
        guard let firstOfMonth = cal.date(from: c) else { return .distantPast }
        let weekday = cal.component(.weekday, from: firstOfMonth) // 1=Sun
        let daysToFirst = (8 - weekday) % 7
        guard let firstSunday = cal.date(byAdding: .day, value: daysToFirst, to: firstOfMonth) else { return .distantPast }
        return cal.date(byAdding: .day, value: (n - 1) * 7, to: firstSunday) ?? .distantPast
    }
}
