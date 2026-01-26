//
//  AirportService.swift
//  Block-Time
//
//  Created by Nelson on 4/10/2025.
//

import Foundation

/// Service for looking up airport information from airports.dat.txt
class AirportService {
    static let shared = AirportService()

    private var airportData: [String: AirportInfo] = [:]
    private var iataToIcaoMap: [String: String] = [:]
    private var icaoToIataMap: [String: String] = [:]
    private var isLoaded = false

    // Cached date formatter for performance - reused across all conversions
    private let cachedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    // Cached UTC calendar for performance - reused across all conversions
    private let cachedUTCCalendar: Calendar = {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private init() {
        loadAirportData()
    }

    struct AirportInfo {
        let icaoCode: String
        let iataCode: String?
        let timezoneOffset: Double
        let dstCode: String
    }

    enum DSTCode: String {
        case europe = "E"
        case usCanada = "A"
        case southAmerica = "S"
        case australia = "O"
        case newZealand = "Z"
        case none = "N"
        case unknown = "U"
    }

    /// Load airport data from airports.dat.txt
    private func loadAirportData() {
        guard let fileURL = Bundle.main.url(forResource: "airports.dat", withExtension: "txt") else {
            LogManager.shared.error("ERROR: airports.dat.txt not found in bundle")
            return
        }

        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for line in lines {
                guard !line.isEmpty else { continue }

                // Parse CSV line properly handling quoted fields with commas
                let components = parseCSVLine(line)
                guard components.count >= 11 else { continue }

                // Remove quotes from IATA code (field 5, index 4)
                let iataCode = components[4].trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                // Remove quotes from ICAO code (field 6, index 5)
                let icaoCode = components[5].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                guard !icaoCode.isEmpty, icaoCode != "\\N" else { continue }

                // Parse timezone offset (field 10, index 9)
                guard let timezoneOffset = Double(components[9]) else { continue }

                // Parse DST code (field 11, index 10)
                let dstCode = components[10].trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                // Store IATA code if valid
                let validIataCode = (iataCode.isEmpty || iataCode == "\\N") ? nil : iataCode

                // Build bidirectional mapping for IATA/ICAO conversion
                if let validIata = validIataCode {
                    iataToIcaoMap[validIata] = icaoCode
                    icaoToIataMap[icaoCode] = validIata
                }

                airportData[icaoCode] = AirportInfo(icaoCode: icaoCode, iataCode: validIataCode, timezoneOffset: timezoneOffset, dstCode: dstCode)
            }

            isLoaded = true
            LogManager.shared.debug("Loaded \(airportData.count) airports with timezone data")
            LogManager.shared.debug("Loaded \(iataToIcaoMap.count) IATA/ICAO mappings")
        } catch {
            LogManager.shared.error("ERROR: Failed to load airports.dat.txt: \(error)")
        }
    }

    /// Parse a CSV line properly handling quoted fields that may contain commas
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        fields.append(currentField)

        return fields
    }

    /// Get timezone offset for an airport ICAO code
    /// - Parameter icaoCode: 4-letter ICAO code (e.g., "YPPH")
    /// - Returns: Timezone offset in hours, or nil if not found
    func getTimezoneOffset(for icaoCode: String) -> Double? {
        return airportData[icaoCode.uppercased()]?.timezoneOffset
    }

    /// Check if an airport is in Australia
    /// - Parameter code: Airport ICAO or IATA code
    /// - Returns: true if the airport is in Australia (ICAO starts with YB, YM, YP, or YS)
    func isAustralianAirport(_ code: String) -> Bool {
        let icaoCode = convertToICAO(code).uppercased()

        // Australian airports have ICAO codes starting with YB, YM, YP, or YS
        if icaoCode.count >= 2 {
            let prefix = String(icaoCode.prefix(2))
            return prefix == "YB" || prefix == "YM" || prefix == "YP" || prefix == "YS"
        }

        return false
    }

    /// Convert UTC date to local date based on airport timezone
    /// - Parameters:
    ///   - utcDateString: Date in format "dd/MM/yyyy"
    ///   - utcTimeString: Time in format "HHMM" or "HH:MM"
    ///   - icaoCode: Airport ICAO code
    /// - Returns: Local date string in format "dd/MM/yyyy", or original date if conversion fails
    func convertToLocalDate(utcDateString: String, utcTimeString: String, airportICAO icaoCode: String) -> String {
        guard let timezoneOffset = getTimezoneOffset(for: icaoCode) else {
            return utcDateString // Return original if timezone not found
        }

        guard let utcDate = cachedDateFormatter.date(from: utcDateString) else {
            return utcDateString
        }

        // Parse time string (handle both "HHMM" and "HH:MM")
        let cleanTime = utcTimeString.replacingOccurrences(of: ":", with: "")
        guard cleanTime.count >= 3 else {
            return utcDateString
        }

        let hours: Int
        let minutes: Int

        if cleanTime.count == 4 {
            hours = Int(cleanTime.prefix(2)) ?? 0
            minutes = Int(cleanTime.suffix(2)) ?? 0
        } else if cleanTime.count == 3 {
            hours = Int(cleanTime.prefix(1)) ?? 0
            minutes = Int(cleanTime.suffix(2)) ?? 0
        } else {
            return utcDateString
        }

        // Combine date and time using cached calendar
        guard let utcDateTime = cachedUTCCalendar.date(bySettingHour: hours, minute: minutes, second: 0, of: utcDate) else {
            return utcDateString
        }

        // Add timezone offset to get local time
        let offsetSeconds = timezoneOffset * 3600
        let localDateTime = utcDateTime.addingTimeInterval(offsetSeconds)

        // Format local date
        let localDateString = cachedDateFormatter.string(from: localDateTime)

        return localDateString
    }

    /// Check if DST is active for a given date and DST code
    /// - Parameters:
    ///   - date: The date to check
    ///   - dstCode: The DST code (E, A, S, O, Z, N, U)
    /// - Returns: true if DST is active, false otherwise
    private func isDSTActive(on date: Date, dstCode: String) -> Bool {
        guard let dst = DSTCode(rawValue: dstCode) else { return false }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        switch dst {
        case .europe:
            // Starts last Sunday of March, ends last Sunday of October
            let marchStart = lastSundayOf(month: 3, year: year)
            let octoberEnd = lastSundayOf(month: 10, year: year)
            return date >= marchStart && date < octoberEnd

        case .usCanada:
            // Starts second Sunday of March, ends first Sunday of November
            let marchStart = nthSundayOf(month: 3, year: year, n: 2)
            let novemberEnd = nthSundayOf(month: 11, year: year, n: 1)
            return date >= marchStart && date < novemberEnd

        case .southAmerica:
            // Starts third Sunday of October, ends third Sunday of March
            let octoberStart = nthSundayOf(month: 10, year: year, n: 3)
            let marchEnd = nthSundayOf(month: 3, year: year, n: 3)
            // Southern hemisphere - DST spans across years
            if month >= 10 {
                return date >= octoberStart
            } else if month <= 3 {
                return date < marchEnd
            }
            return false

        case .australia:
            // Starts first Sunday of October, ends first Sunday of April
            let octoberStart = nthSundayOf(month: 10, year: year, n: 1)
            let aprilEnd = nthSundayOf(month: 4, year: year, n: 1)
            // Southern hemisphere - DST spans across years
            if month >= 10 {
                return date >= octoberStart
            } else if month <= 4 {
                return date < aprilEnd
            }
            return false

        case .newZealand:
            // Starts last Sunday of September, ends first Sunday of April
            let septemberStart = lastSundayOf(month: 9, year: year)
            let aprilEnd = nthSundayOf(month: 4, year: year, n: 1)
            // Southern hemisphere - DST spans across years
            if month >= 9 {
                return date >= septemberStart
            } else if month <= 4 {
                return date < aprilEnd
            }
            return false

        case .none, .unknown:
            return false
        }
    }

    /// Find the last Sunday of a given month and year
    private func lastSundayOf(month: Int, year: Int) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 1

        guard let firstOfNextMonth = calendar.date(from: components) else {
            return Date()
        }

        // Go back one day to get last day of the month
        guard let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: firstOfNextMonth) else {
            return Date()
        }

        // Find the last Sunday
        let weekday = calendar.component(.weekday, from: lastDayOfMonth)
        let daysToSubtract = (weekday + 6) % 7 // Sunday is 1

        guard let lastSunday = calendar.date(byAdding: .day, value: -daysToSubtract, to: lastDayOfMonth) else {
            return Date()
        }

        return lastSunday
    }

    /// Find the nth Sunday of a given month and year
    private func nthSundayOf(month: Int, year: Int, n: Int) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let firstOfMonth = calendar.date(from: components) else {
            return Date()
        }

        // Find the first Sunday
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let daysToAdd = (8 - weekday) % 7 // Sunday is 1

        guard let firstSunday = calendar.date(byAdding: .day, value: daysToAdd, to: firstOfMonth) else {
            return Date()
        }

        // Add (n-1) weeks to get the nth Sunday
        guard let nthSunday = calendar.date(byAdding: .weekOfYear, value: n - 1, to: firstSunday) else {
            return Date()
        }

        return nthSunday
    }

    // MARK: - IATA/ICAO Conversion Methods

    /// Convert any airport code (IATA or ICAO) to ICAO format
    /// - Parameter code: Airport code (3-letter IATA or 4-letter ICAO)
    /// - Returns: ICAO code if found, or original code if not found
    func convertToICAO(_ code: String) -> String {
        let upper = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !upper.isEmpty else { return code }

        // Check if already valid ICAO (4 characters and exists in database)
        if upper.count == 4 && airportData[upper] != nil {
            return upper
        }

        // Try IATA to ICAO conversion (3 characters)
        if upper.count == 3, let icao = iataToIcaoMap[upper] {
            return icao
        }

        // Return original if no conversion found (allows private airfields)
        return upper
    }

    /// Convert ICAO code to IATA code if available
    /// - Parameter icaoCode: 4-letter ICAO code
    /// - Returns: 3-letter IATA code if available, nil otherwise
    func convertToIATA(_ icaoCode: String) -> String? {
        return icaoToIataMap[icaoCode.uppercased()]
    }

    /// Get display code based on user preference
    /// - Parameters:
    ///   - icaoCode: The ICAO code stored in database
    ///   - useIATA: Whether to display as IATA code
    /// - Returns: IATA code if requested and available, otherwise ICAO code
    func getDisplayCode(_ icaoCode: String, useIATA: Bool) -> String {
        guard useIATA else { return icaoCode }
        return convertToIATA(icaoCode) ?? icaoCode
    }

    /// Check if an airport code is valid (exists in database)
    /// - Parameter code: Airport code (IATA or ICAO)
    /// - Returns: true if code exists in database
    func isValidCode(_ code: String) -> Bool {
        let upper = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Check ICAO
        if airportData[upper] != nil {
            return true
        }
        // Check IATA
        if iataToIcaoMap[upper] != nil {
            return true
        }
        return false
    }

    /// Convert UTC time to local time for a specific airport
    /// - Parameters:
    ///   - utcDateString: UTC date in format "dd/MM/yyyy"
    ///   - utcTimeString: UTC time in format "HHMM" or "HH:MM"
    ///   - icaoCode: Airport ICAO code
    /// - Returns: Local time in format "HHMM", or original time if conversion fails
    func convertToLocalTime(utcDateString: String, utcTimeString: String, airportICAO icaoCode: String) -> String {
        guard let airportInfo = airportData[icaoCode.uppercased()] else {
            return utcTimeString // Return original if airport not found
        }

        guard let utcDate = cachedDateFormatter.date(from: utcDateString) else {
            return utcTimeString
        }

        // Parse time string (handle both "HHMM" and "HH:MM")
        let cleanTime = utcTimeString.replacingOccurrences(of: ":", with: "")
        guard cleanTime.count >= 3 else {
            return utcTimeString
        }

        let hours: Int
        let minutes: Int

        if cleanTime.count == 4 {
            hours = Int(cleanTime.prefix(2)) ?? 0
            minutes = Int(cleanTime.suffix(2)) ?? 0
        } else if cleanTime.count == 3 {
            hours = Int(cleanTime.prefix(1)) ?? 0
            minutes = Int(cleanTime.suffix(2)) ?? 0
        } else {
            return utcTimeString
        }

        // Combine date and time using cached calendar
        guard let utcDateTime = cachedUTCCalendar.date(bySettingHour: hours, minute: minutes, second: 0, of: utcDate) else {
            return utcTimeString
        }

        // Calculate timezone offset including DST
        var totalOffset = airportInfo.timezoneOffset
        if isDSTActive(on: utcDateTime, dstCode: airportInfo.dstCode) {
            totalOffset += 1.0
        }

        // Add timezone offset to get local time
        let offsetSeconds = totalOffset * 3600
        let localDateTime = utcDateTime.addingTimeInterval(offsetSeconds)

        // Format local time as HHMM using cached calendar
        let localHour = cachedUTCCalendar.component(.hour, from: localDateTime)
        let localMinute = cachedUTCCalendar.component(.minute, from: localDateTime)

        return String(format: "%02d%02d", localHour, localMinute)
    }

    // MARK: - Convert FROM Local TO UTC (for roster import)

    /// Convert local date and time to UTC date based on airport timezone
    /// - Parameters:
    ///   - localDateString: Local date in format "dd/MM/yyyy"
    ///   - localTimeString: Local time in format "HHMM" or "HH:MM"
    ///   - icaoCode: Airport ICAO code
    /// - Returns: UTC date string in format "dd/MM/yyyy", or original date if conversion fails
    func convertFromLocalToUTCDate(localDateString: String, localTimeString: String, airportICAO icaoCode: String) -> String {
        guard let airportInfo = airportData[icaoCode.uppercased()] else {
            return localDateString // Return original if airport not found
        }

        // Parse time string (handle both "HHMM" and "HH:MM")
        let cleanTime = localTimeString.replacingOccurrences(of: ":", with: "")
        guard cleanTime.count >= 3 else {
            return localDateString
        }

        let hours: Int
        let minutes: Int

        if cleanTime.count == 4 {
            hours = Int(cleanTime.prefix(2)) ?? 0
            minutes = Int(cleanTime.suffix(2)) ?? 0
        } else if cleanTime.count == 3 {
            hours = Int(cleanTime.prefix(1)) ?? 0
            minutes = Int(cleanTime.suffix(2)) ?? 0
        } else {
            return localDateString
        }

        // Parse the date string into components
        let components = localDateString.split(separator: "/")
        guard components.count == 3,
              let day = Int(components[0]),
              let month = Int(components[1]),
              let year = Int(components[2]) else {
            return localDateString
        }

        // Create DateComponents representing the LOCAL date/time
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hours
        dateComponents.minute = minutes
        dateComponents.second = 0

        // Calculate the actual timezone offset including DST
        // Create a rough Date to check DST status
        let calendar = Calendar.current
        guard let roughDate = calendar.date(from: dateComponents) else {
            return localDateString
        }

        var totalOffset = airportInfo.timezoneOffset
        if isDSTActive(on: roughDate, dstCode: airportInfo.dstCode) {
            totalOffset += 1.0
        }

        // Create a timezone with the correct offset
        guard let localTimeZone = TimeZone(secondsFromGMT: Int(totalOffset * 3600)) else {
            return localDateString
        }

        // Use a calendar with the LOCAL timezone to interpret the date/time
        var localCalendar = Calendar.current
        localCalendar.timeZone = localTimeZone

        // Create the date in local timezone
        guard let localDateTime = localCalendar.date(from: dateComponents) else {
            return localDateString
        }

        // Convert to UTC by extracting components in UTC timezone
        // Format as UTC date using cached formatter
        return cachedDateFormatter.string(from: localDateTime)
    }

    /// Convert local time to UTC time for a specific airport
    /// - Parameters:
    ///   - localDateString: Local date in format "dd/MM/yyyy" (needed for DST calculation)
    ///   - localTimeString: Local time in format "HHMM" or "HH:MM"
    ///   - icaoCode: Airport ICAO code
    /// - Returns: UTC time in format "HH:MM", or original time if conversion fails
    func convertFromLocalToUTCTime(localDateString: String, localTimeString: String, airportICAO icaoCode: String) -> String {
        guard let airportInfo = airportData[icaoCode.uppercased()] else {
            return localTimeString // Return original if airport not found
        }

        // Parse time string (handle both "HHMM" and "HH:MM")
        let cleanTime = localTimeString.replacingOccurrences(of: ":", with: "")
        guard cleanTime.count >= 3 else {
            return localTimeString
        }

        let hours: Int
        let minutes: Int

        if cleanTime.count == 4 {
            hours = Int(cleanTime.prefix(2)) ?? 0
            minutes = Int(cleanTime.suffix(2)) ?? 0
        } else if cleanTime.count == 3 {
            hours = Int(cleanTime.prefix(1)) ?? 0
            minutes = Int(cleanTime.suffix(2)) ?? 0
        } else {
            return localTimeString
        }

        // Parse the date string into components
        let components = localDateString.split(separator: "/")
        guard components.count == 3,
              let day = Int(components[0]),
              let month = Int(components[1]),
              let year = Int(components[2]) else {
            return localTimeString
        }

        // Create DateComponents representing the LOCAL date/time
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hours
        dateComponents.minute = minutes
        dateComponents.second = 0

        // Calculate the actual timezone offset including DST
        // Create a rough Date to check DST status
        let calendar = Calendar.current
        guard let roughDate = calendar.date(from: dateComponents) else {
            return localTimeString
        }

        var totalOffset = airportInfo.timezoneOffset
        if isDSTActive(on: roughDate, dstCode: airportInfo.dstCode) {
            totalOffset += 1.0
        }

        // Create a timezone with the correct offset
        guard let localTimeZone = TimeZone(secondsFromGMT: Int(totalOffset * 3600)) else {
            return localTimeString
        }

        // Use a calendar with the LOCAL timezone to interpret the date/time
        var localCalendar = Calendar.current
        localCalendar.timeZone = localTimeZone

        // Create the date in local timezone
        guard let localDateTime = localCalendar.date(from: dateComponents) else {
            return localTimeString
        }

        // Extract UTC time components
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let utcHour = utcCalendar.component(.hour, from: localDateTime)
        let utcMinute = utcCalendar.component(.minute, from: localDateTime)

        return String(format: "%02d:%02d", utcHour, utcMinute)
    }
}
