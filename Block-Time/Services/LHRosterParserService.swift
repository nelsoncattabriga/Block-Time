//
//  LHRosterParserService.swift
//  Block-Time
//
//  Created by Nelson on 31/10/2025.
//


import Foundation

/// Service to parse Qantas Long Haul crew roster files and extract flight information
class LHRosterParserService {

    // MARK: - Data Models

    /// Represents a parsed flight from a roster
    struct ParsedFlight {
        let date: Date
        let flightNumber: String
        let departureAirport: String
        let arrivalAirport: String
        let departureTime: String  // HHmm format in local time (e.g., "1239")
        let arrivalTime: String    // HHmm format in local time (e.g., "1517")
        let aircraftType: String   // Extracted from category (e.g., "B787")
        let role: String           // "Captain", "First Officer", or "Second Officer"
        let isPositioning: Bool    // True if marked with "PAX"
        let bidPeriod: String      // e.g., "356"
        let patternCode: String?   // e.g., "EN04X011" (optional)
    }

    /// Result of parsing a roster file
    struct ParseResult {
        let flights: [ParsedFlight]
        let pilotName: String
        let staffNumber: String
        let bidPeriod: String
        let base: String
        let category: String  // e.g., "F/O-B787"
    }

    /// Represents a duty entry from the calendar section
    private struct DutyEntry {
        let date: Date
        let dutyCode: String
    }

    /// Represents a trip (grouped consecutive duty entries with same duty code)
    private struct Trip {
        let dutyCode: String
        let startDate: Date
        let endDate: Date
    }

    /// Represents a pattern definition from the bottom section
    private struct PatternDefinition {
        let code: String
        let flights: [PatternFlight]
    }

    /// Represents a flight within a pattern
    private struct PatternFlight {
        let service: String
        let isPax: Bool
        let sectors: String  // e.g., "BNE/SYD"
        let dayOfWeek: String  // e.g., "MO", "TU", "WE"
        let departureTimeLocal: String
        let arrivalTimeLocal: String
    }

    // MARK: - Parsing Methods

    /// Parse a roster file and extract flight information
    static func parseRoster(from fileURL: URL) throws -> ParseResult {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try parseRoster(from: content)
    }

    /// Parse roster content from a string
    static func parseRoster(from content: String) throws -> ParseResult {
        let lines = content.components(separatedBy: .newlines)

        LogManager.shared.debug("Starting LH roster parsing from \(lines.count) lines")

        // Extract header information
        let pilotInfo = extractPilotInfo(from: lines)

                LogManager.shared.debug("📋 Extracted pilot info:")
                LogManager.shared.debug("   Name: \(pilotInfo.name)")
                LogManager.shared.debug("   Staff: \(pilotInfo.staffNumber)")
                LogManager.shared.debug("   BP: \(pilotInfo.bidPeriod)")
                LogManager.shared.debug("   Base: \(pilotInfo.base)")
                LogManager.shared.debug("   Category: \(pilotInfo.category)")

        // Get BP date range
        guard let bpNumber = Int(pilotInfo.bidPeriod),
              let bpDates = bpDates(bp: bpNumber) else {
            throw NSError(domain: "LHRosterParserService", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid bid period: \(pilotInfo.bidPeriod)"])
        }

                LogManager.shared.debug("BP \(pilotInfo.bidPeriod) date range: \(formatDate(bpDates.startDate)) to \(formatDate(bpDates.endDate))")

        // Extract duty entries from calendar
        let dutyEntries = extractDutyEntries(from: lines, bpStartDate: bpDates.startDate)
                LogManager.shared.debug("Found \(dutyEntries.count) duty entries in calendar")

        // Extract pattern definitions
        let patterns = extractPatternDefinitions(from: lines)
                LogManager.shared.debug("✈️  Found \(patterns.count) pattern definitions:")
        for (code, pattern) in patterns {
                    LogManager.shared.debug("   - \(code): \(pattern.flights.count) flights")
        }

        // Match duties to patterns and create flights
        let flights = createFlights(
            from: dutyEntries,
            patterns: patterns,
            pilotInfo: pilotInfo
        )

                LogManager.shared.debug("🎯 Total flights extracted: \(flights.count)")

        // Sort flights by date and departure time to ensure correct chronological order
        let sortedFlights = flights.sorted { flight1, flight2 in
            // First compare by date
            if flight1.date != flight2.date {
                return flight1.date < flight2.date
            }
            // If same date, compare by departure time (HHmm format as strings works for comparison)
            return flight1.departureTime < flight2.departureTime
        }

        return ParseResult(
            flights: sortedFlights,
            pilotName: pilotInfo.name,
            staffNumber: pilotInfo.staffNumber,
            bidPeriod: pilotInfo.bidPeriod,
            base: pilotInfo.base,
            category: pilotInfo.category
        )
    }

    // MARK: - Header Parsing

    private struct PilotInfo {
        let name: String
        let staffNumber: String
        let bidPeriod: String
        let base: String
        let category: String
        let role: String  // Extracted from category
        let aircraftType: String  // Extracted from category
    }

    private static func extractPilotInfo(from lines: [String]) -> PilotInfo {
        var name = ""
        var staffNumber = ""
        var bidPeriod = ""
        var base = ""
        var category = ""

        for line in lines {
            // Extract bid period from header (e.g., "OPERATIONS ROSTER FOR BID PERIOD  356")
            if line.contains("OPERATIONS ROSTER FOR BID PERIOD") {
                let pattern = #"BID PERIOD\s+(\d+)"#
                if let match = line.range(of: pattern, options: .regularExpression) {
                    let matched = String(line[match])
                    if let bpMatch = matched.range(of: #"\d+"#, options: .regularExpression) {
                        bidPeriod = String(matched[bpMatch])
                                LogManager.shared.debug("📋 Detected bid period: \(bidPeriod)")
                    }
                }
            }

            // Extract pilot name (e.g., "Name: CATTABRIGA   NELSON")
            if line.contains("Name:") {
                let pattern = #"Name:\s+([\w\s]+)\s+Staff No:"#
                if let match = line.range(of: pattern, options: .regularExpression) {
                    let matched = String(line[match])
                    let namePattern = #"Name:\s+([\w\s]+)\s+Staff"#
                    if let nameMatch = matched.range(of: namePattern, options: .regularExpression) {
                        let nameStr = String(matched[nameMatch])
                        name = nameStr
                            .replacingOccurrences(of: "Name:", with: "")
                            .replacingOccurrences(of: "Staff", with: "")
                            .trimmingCharacters(in: .whitespaces)
                    }
                }
            }

            // Extract staff number (e.g., "Staff No: 965200")
            if line.contains("Staff No:") {
                let pattern = #"Staff No:\s+(\d+)"#
                if let match = line.range(of: pattern, options: .regularExpression) {
                    let matched = String(line[match])
                    if let numMatch = matched.range(of: #"\d+"#, options: .regularExpression) {
                        staffNumber = String(matched[numMatch])
                    }
                }
            }

            // Extract category and base (e.g., "Category: F/O-B787  Status: F/O  Line: PLH  Seniority: 0880  Base: BNE")
            if line.contains("Category:") {
                let categoryPattern = #"Category:\s+([\w/-]+)"#
                if let match = line.range(of: categoryPattern, options: .regularExpression) {
                    let matched = String(line[match])
                    category = matched
                        .replacingOccurrences(of: "Category:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }

                let basePattern = #"Base:\s+(\w+)"#
                if let match = line.range(of: basePattern, options: .regularExpression) {
                    let matched = String(line[match])
                    base = matched
                        .replacingOccurrences(of: "Base:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Extract role and aircraft type from category
        let (role, aircraftType) = extractRoleAndAircraft(from: category)

        return PilotInfo(
            name: name,
            staffNumber: staffNumber,
            bidPeriod: bidPeriod,
            base: base,
            category: category,
            role: role,
            aircraftType: aircraftType
        )
    }

    /// Extract role and aircraft type from category string
    /// e.g., "F/O-B787" -> ("First Officer", "B787")
    /// e.g., "CPT-B787" -> ("Captain", "B787")
    /// e.g., "S/O-B787" -> ("Second Officer", "B787")
    private static func extractRoleAndAircraft(from category: String) -> (role: String, aircraftType: String) {
        var role = "First Officer"  // Default
        var aircraftType = "B787"   // Default

        if category.contains("CPT") {
            role = "Captain"
        } else if category.contains("F/O") {
            role = "First Officer"
        } else if category.contains("S/O") {
            role = "Second Officer"
        }

        // Extract aircraft type (everything after the dash)
        if let dashIndex = category.lastIndex(of: "-") {
            let typeStart = category.index(after: dashIndex)
            aircraftType = String(category[typeStart...])
                .trimmingCharacters(in: .whitespaces)
        }

        return (role, aircraftType)
    }

    // MARK: - Calendar Parsing

    /// Extract duty entries from the calendar section
    private static func extractDutyEntries(from lines: [String], bpStartDate: Date) -> [DutyEntry] {
        var entries: [DutyEntry] = []

        // Find the calendar section (starts after the dashed line after "Protection")
        var inCalendar = false

        for line in lines {
            // Start of calendar section
            if line.contains("Date    Duty      Detail  Rept End   Credit") {
                inCalendar = true
                continue
            }

            // End of calendar section
            if inCalendar && line.contains("Carry Out") {
                break
            }

            if !inCalendar {
                continue
            }

            // Calendar is formatted in 3 columns separated by |
            // Split the line by | and process each column
            let columns = line.components(separatedBy: "|")

            for column in columns {
                // Parse calendar lines
                // Format: "28/04 F EN04X011  AW16    0515        66:00"
                // Pattern: DD/MM D DUTYCODE ...
                let pattern = #"(\d{2})/(\d{2})\s+\w\s+(\w+)"#

                if let match = column.range(of: pattern, options: .regularExpression) {
                    let matched = String(column[match])
                    let components = matched.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

                            LogManager.shared.debug("   Matched line: \(matched)")
                            LogManager.shared.debug("   Components: \(components)")

                    if components.count >= 3 {
                        let dateStr = components[0]  // e.g., "28/04"
                        let dutyCode = components[2]  // e.g., "EN04X011"

                        // Skip non-flight duties (single letters, or specific codes)
                        // Note: GRT01, GRT02, etc. with suffixes are patterns, but GRT2D, GRT3D are ground training
                        let isGroundTrainingDay = dutyCode.hasPrefix("GRT") && dutyCode.contains("D")
                        let isStandby = dutyCode.hasPrefix("SFL")

                        if dutyCode.count < 3 || dutyCode == "AL" || dutyCode == "SR" || dutyCode.hasPrefix("SIM") || dutyCode.hasPrefix("HFC") || dutyCode.hasPrefix("EP") || isGroundTrainingDay || isStandby {
                                    LogManager.shared.debug("   ⏭️  Skipping non-flight duty: \(dutyCode)")
                            continue
                        }

                        // Convert date string to Date using BP start date
                        if let date = convertCalendarDate(dateStr, bpStartDate: bpStartDate) {
                            entries.append(DutyEntry(date: date, dutyCode: dutyCode))
                                    LogManager.shared.debug("   Calendar entry: \(formatDate(date)) - \(dutyCode)")
                        } else {
                                    LogManager.shared.debug("   Failed to convert date: \(dateStr)")
                        }
                    }
                }
            }
        }

        // Sort entries by date to ensure chronological order
        // (entries may be out of order due to multi-column calendar layout)
        let sortedEntries = entries.sorted { $0.date < $1.date }

        return sortedEntries
    }

    /// Convert calendar date string (DD/MM) to Date using BP start date for year context
    private static func convertCalendarDate(_ dateString: String, bpStartDate: Date) -> Date? {
        let parts = dateString.components(separatedBy: "/")
        guard parts.count == 2,
              let day = Int(parts[0]),
              let month = Int(parts[1]) else {
            return nil
        }

        let calendar = Calendar.current
        let bpYear = calendar.component(.year, from: bpStartDate)
        let bpMonth = calendar.component(.month, from: bpStartDate)

        // Handle year boundary - if month is less than BP start month, it's next year
        var year = bpYear
        if month < bpMonth {
            year += 1
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0

        return calendar.date(from: components)
    }

    // MARK: - Pattern Parsing

    /// Extract pattern definitions from the bottom section
    private static func extractPatternDefinitions(from lines: [String]) -> [String: PatternDefinition] {
        var patterns: [String: PatternDefinition] = [:]

        var currentPattern: String?
        var currentFlights: [PatternFlight] = []

        for (_, line) in lines.enumerated() {
            // Detect pattern header
            // Format: "|* Pattern: EN04X011   INT  Base: BNE   Route Code: JFK12   Weeks: 1..."
            // or: "Pattern: EN04X011   INT  Base: BNE   Route Code: JFK12   Weeks: 1..."
            if line.contains("Pattern:") {
                // Save previous pattern if exists
                if let pattern = currentPattern, !currentFlights.isEmpty {
                    patterns[pattern] = PatternDefinition(code: pattern, flights: currentFlights)
                            LogManager.shared.debug("✈️  Pattern \(pattern): \(currentFlights.count) flights")
                }

                // Extract new pattern code - handle both formats
                let patternPattern = #"Pattern:\s+(\w+)"#
                if let match = line.range(of: patternPattern, options: .regularExpression) {
                    let matched = String(line[match])
                    currentPattern = matched
                        .replacingOccurrences(of: "Pattern:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    currentFlights = []
                }
                continue
            }

            // Parse flight lines within pattern
            // Format: "QFA0509   PAX   BNE/SYD              0630     TU    0715   2115    TU    0950   2250"
            // Service   T Pax    Sectors             Time     Day    LT    UTC     Day    LT    UTC
            if currentPattern != nil && line.contains("QFA") {
                if let flight = parsePatternFlight(line) {
                    currentFlights.append(flight)
                }
            }
        }

        // Save last pattern
        if let pattern = currentPattern, !currentFlights.isEmpty {
            patterns[pattern] = PatternDefinition(code: pattern, flights: currentFlights)
                    LogManager.shared.debug("✈️  Pattern \(pattern): \(currentFlights.count) flights")
        }

        return patterns
    }

    /// Parse a single flight line from a pattern definition
    private static func parsePatternFlight(_ line: String) -> PatternFlight? {
        // Split by multiple spaces to get columns
        let columns = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

                LogManager.shared.debug("      Parsing flight line: \(line)")
                LogManager.shared.debug("      Columns (\(columns.count)): \(columns)")

        guard columns.count >= 8 else {
                    LogManager.shared.debug("      Not enough columns (need at least 8, got \(columns.count))")
            return nil
        }

        var index = 0

        // Service number (e.g., "QFA0119")
        let service = columns[index]
        index += 1

        // Check for PAX marker or other single-letter flags (like N, L, etc.)
        var isPax = false
        while index < columns.count && !columns[index].contains("/") {
            if columns[index] == "PAX" {
                isPax = true
            }
            // Skip single-letter flags (N, L, C, etc.) or PAX
            index += 1
        }

        // Get sectors (e.g., "BNE/AKL")
        guard index < columns.count && columns[index].contains("/") else {
                    LogManager.shared.debug("      Expected sectors at index \(index)")
            return nil
        }
        let sectors = columns[index]
        index += 1

        // Skip ground training or non-flight services (same departure/arrival airport)
        let airports = sectors.components(separatedBy: "/")
        if airports.count == 2 && airports[0] == airports[1] {
                    LogManager.shared.debug("      ⏭️  Skipping ground training/non-flight service: \(sectors)")
            return nil
        }

        // Skip report time if present (4 digits before the day abbreviation)
        // We need to find the first 2-letter day abbreviation
        while index < columns.count {
            let col = columns[index]
            // Check if this is a day abbreviation (2 letters: MO, TU, WE, TH, FR, SA, SU)
            if col.count == 2 && ["MO", "TU", "WE", "TH", "FR", "SA", "SU"].contains(col) {
                break
            }
            // Skip report time or other columns
            index += 1
        }

        // Get departure day (e.g., "FR")
        guard index < columns.count else {
                    LogManager.shared.debug("      No departure day found")
            return nil
        }
        let depDay = columns[index]
        index += 1

        // Get departure local time (4 digits)
        guard index < columns.count && columns[index].count == 4 else {
                    LogManager.shared.debug("      No departure local time found at index \(index)")
            return nil
        }
        let depTimeLocal = columns[index]
        index += 1

        // Skip departure UTC time (4 digits)
        if index < columns.count && columns[index].count == 4 && Int(columns[index]) != nil {
            index += 1
        }

        // Skip arrival day (should be another 2-letter abbreviation)
        if index < columns.count && columns[index].count == 2 {
            index += 1
        }

        // Get arrival local time (4 digits)
        guard index < columns.count && columns[index].count == 4 else {
                    LogManager.shared.debug("      Failed to get arrival local time at index \(index)")
            return nil
        }
        let arrTimeLocal = columns[index]

        let flight = PatternFlight(
            service: service,
            isPax: isPax,
            sectors: sectors,
            dayOfWeek: depDay,
            departureTimeLocal: depTimeLocal,
            arrivalTimeLocal: arrTimeLocal
        )

                LogManager.shared.debug("      Parsed flight: \(service) \(sectors) on \(depDay), dep: \(depTimeLocal)LT, arr: \(arrTimeLocal)LT, isPax: \(isPax)")

        return flight
    }

    // MARK: - Flight Creation

    /// Group consecutive duty entries with the same duty code into trips
    /// This prevents creating duplicate flights when a multi-day pattern spans several calendar days
    private static func groupDutyEntriesIntoTrips(_ dutyEntries: [DutyEntry]) -> [Trip] {
        var trips: [Trip] = []

        guard !dutyEntries.isEmpty else { return trips }

        var currentDutyCode = dutyEntries[0].dutyCode
        var tripStartDate = dutyEntries[0].date
        var previousDate = dutyEntries[0].date

        let calendar = Calendar.current

        for i in 1..<dutyEntries.count {
            let entry = dutyEntries[i]

            // Check if this entry is part of the same trip
            // Same trip = same duty code AND consecutive days (within 1 day)
            let daysBetween = calendar.dateComponents([.day], from: previousDate, to: entry.date).day ?? 0

                    LogManager.shared.debug("   Comparing: \(currentDutyCode) on \(formatDate(previousDate)) vs \(entry.dutyCode) on \(formatDate(entry.date)) (days between: \(daysBetween))")

            if entry.dutyCode == currentDutyCode && daysBetween <= 1 {
                // Continue the current trip
                        LogManager.shared.debug("      ➡️  Continuing same trip")
                previousDate = entry.date
            } else {
                // End current trip and start a new one
                let trip = Trip(
                    dutyCode: currentDutyCode,
                    startDate: tripStartDate,
                    endDate: previousDate
                )
                trips.append(trip)
                        LogManager.shared.debug("      Completed trip: \(currentDutyCode) from \(formatDate(tripStartDate)) to \(formatDate(previousDate))")

                currentDutyCode = entry.dutyCode
                tripStartDate = entry.date
                previousDate = entry.date
                        LogManager.shared.debug("      🆕 Starting new trip: \(currentDutyCode) on \(formatDate(tripStartDate))")
            }
        }

        // Add the last trip
        let lastTrip = Trip(
            dutyCode: currentDutyCode,
            startDate: tripStartDate,
            endDate: previousDate
        )
        trips.append(lastTrip)
                LogManager.shared.debug("   Completed final trip: \(currentDutyCode) from \(formatDate(tripStartDate)) to \(formatDate(previousDate))")

        return trips
    }

    /// Create flights by matching duty entries with pattern definitions
    private static func createFlights(
        from dutyEntries: [DutyEntry],
        patterns: [String: PatternDefinition],
        pilotInfo: PilotInfo
    ) -> [ParsedFlight] {
        var flights: [ParsedFlight] = []

        // Group consecutive duty entries with the same duty code into trips
        let trips = groupDutyEntriesIntoTrips(dutyEntries)

                LogManager.shared.debug("📦 Grouped \(dutyEntries.count) duty entries into \(trips.count) trips")

        for trip in trips {
                    LogManager.shared.debug("\n🔎 Looking for pattern for trip: \(trip.dutyCode)")

            // Find pattern definition for this duty code
            guard let pattern = findPattern(for: trip.dutyCode, in: patterns) else {
                        LogManager.shared.debug("    No pattern found for duty code: \(trip.dutyCode)")
                        LogManager.shared.debug("   Available patterns: \(patterns.keys.sorted())")
                continue
            }

                    LogManager.shared.debug("   Found pattern: \(pattern.code)")
                    LogManager.shared.debug("📋 Processing trip \(trip.dutyCode) from \(formatDate(trip.startDate)) to \(formatDate(trip.endDate)) with pattern \(pattern.code)")

            // Create flights for each flight in the pattern
            for (flightIndex, patternFlight) in pattern.flights.enumerated() {
                // Calculate actual date for this flight based on day of week
                guard let flightDate = calculateFlightDate(
                    patternStartDate: trip.startDate,
                    dayOfWeek: patternFlight.dayOfWeek,
                    flightIndex: flightIndex,
                    allFlightsInPattern: pattern.flights
                ) else {
                            LogManager.shared.debug("    Could not calculate date for flight \(flightIndex) (day: \(patternFlight.dayOfWeek))")
                    continue
                }

                // Extract departure and arrival airports from sectors
                let airports = patternFlight.sectors.components(separatedBy: "/")
                guard airports.count == 2 else {
                            LogManager.shared.debug("    Invalid sectors format: \(patternFlight.sectors)")
                    continue
                }

                let flight = ParsedFlight(
                    date: flightDate,
                    flightNumber: extractFlightNumber(from: patternFlight.service),
                    departureAirport: airports[0],
                    arrivalAirport: airports[1],
                    departureTime: patternFlight.departureTimeLocal,
                    arrivalTime: patternFlight.arrivalTimeLocal,
                    aircraftType: pilotInfo.aircraftType,
                    role: pilotInfo.role,
                    isPositioning: patternFlight.isPax,
                    bidPeriod: pilotInfo.bidPeriod,
                    patternCode: trip.dutyCode
                )

                flights.append(flight)
                        LogManager.shared.debug("   Flight: \(flight.flightNumber) \(flight.departureAirport)-\(flight.arrivalAirport) on \(formatDate(flightDate)) \(flight.departureTime)LT")
            }
        }

        return flights
    }

    /// Find pattern definition for a duty code
    /// Handles exact matches and base pattern matches
    private static func findPattern(for dutyCode: String, in patterns: [String: PatternDefinition]) -> PatternDefinition? {
        // First try exact match
        if let pattern = patterns[dutyCode] {
            return pattern
        }

        // Try to find base pattern (remove suffixes like X011, Y082, etc.)
        // Pattern codes typically have a base like "EN04" and may have suffixes
        var baseCode = dutyCode

        // Remove common suffixes
        if let xIndex = baseCode.firstIndex(of: "X") {
            baseCode = String(baseCode[..<xIndex])
        } else if let yIndex = baseCode.firstIndex(of: "Y") {
            baseCode = String(baseCode[..<yIndex])
        }

        // Try to match any pattern that starts with the base code
        for (patternCode, pattern) in patterns {
            if patternCode.hasPrefix(baseCode) || baseCode.hasPrefix(patternCode) {
                return pattern
            }
        }

        return nil
    }

    /// Calculate the actual date of a flight based on the pattern start date and day of week
    /// Maps weekday abbreviations to actual dates by tracking the current week position
    private static func calculateFlightDate(
        patternStartDate: Date,
        dayOfWeek: String,
        flightIndex: Int,
        allFlightsInPattern: [PatternFlight]
    ) -> Date? {
        let calendar = Calendar.current

        // Map day abbreviations to weekday numbers (1 = Sunday, 2 = Monday, etc.)
        let dayMap: [String: Int] = [
            "SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7
        ]

        guard let targetWeekday = dayMap[dayOfWeek] else {
                    LogManager.shared.debug("      Unknown day of week: \(dayOfWeek)")
            return nil
        }

        // For the first flight, establish the reference date
        if flightIndex == 0 {
            let startWeekday = calendar.component(.weekday, from: patternStartDate)
            var daysToAdd = 0

            if targetWeekday >= startWeekday {
                daysToAdd = targetWeekday - startWeekday
            } else {
                daysToAdd = 7 - startWeekday + targetWeekday
            }

            let calculatedDate = calendar.date(byAdding: .day, value: daysToAdd, to: patternStartDate)
                    LogManager.shared.debug("      First flight: pattern start \(formatDate(patternStartDate)) (weekday \(startWeekday)) + \(daysToAdd) days → \(calculatedDate.map { formatDate($0) } ?? "nil") for day \(dayOfWeek) (weekday \(targetWeekday))")
            return calculatedDate
        }

        // For subsequent flights, calculate from the previous flight's date
        let previousFlight = allFlightsInPattern[flightIndex - 1]
        guard let previousWeekday = dayMap[previousFlight.dayOfWeek],
              let previousDate = calculateFlightDate(
                  patternStartDate: patternStartDate,
                  dayOfWeek: previousFlight.dayOfWeek,
                  flightIndex: flightIndex - 1,
                  allFlightsInPattern: allFlightsInPattern
              ) else {
                    LogManager.shared.debug("      Failed to calculate previous flight date")
            return nil
        }

        var daysToAdd = 0

        if targetWeekday == previousWeekday {
            // Same weekday = same date (multiple flights on same day)
            daysToAdd = 0
                    LogManager.shared.debug("      Flight \(flightIndex): same day as previous (\(dayOfWeek)) → \(formatDate(previousDate))")
        } else if targetWeekday > previousWeekday {
            // Later in the same week (e.g., FR→MO = 3 days)
            daysToAdd = targetWeekday - previousWeekday
            let calculatedDate = calendar.date(byAdding: .day, value: daysToAdd, to: previousDate)
                    LogManager.shared.debug("      Flight \(flightIndex): \(previousFlight.dayOfWeek) (weekday \(previousWeekday)) → \(dayOfWeek) (weekday \(targetWeekday)) = +\(daysToAdd) days → \(calculatedDate.map { formatDate($0) } ?? "nil")")
        } else {
            // Earlier in the week = next week (e.g., TU→FR wraps to next week)
            daysToAdd = 7 - previousWeekday + targetWeekday
            let calculatedDate = calendar.date(byAdding: .day, value: daysToAdd, to: previousDate)
                    LogManager.shared.debug("      Flight \(flightIndex): \(previousFlight.dayOfWeek) (weekday \(previousWeekday)) → \(dayOfWeek) (weekday \(targetWeekday)) = +\(daysToAdd) days (next week) → \(calculatedDate.map { formatDate($0) } ?? "nil")")
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: previousDate)
    }

    /// Extract flight number from service code (e.g., "QFA0509" -> "509", "QFA0003" -> "3")
    private static func extractFlightNumber(from service: String) -> String {
        // Remove "QFA" prefix if present
        var flightNum = service.replacingOccurrences(of: "QFA", with: "")
        flightNum = flightNum.trimmingCharacters(in: .whitespaces)

        // Remove leading zeros
        if let number = Int(flightNum) {
            return String(number)
        }

        return flightNum
    }

    // MARK: - BP Date Calculation

    /// Calculate start and end dates for a bid period
    private static func bpDates(bp: Int) -> (startDate: Date, endDate: Date)? {
        let calendar = Calendar.current
        let bpString = String(abs(bp))
        let digitCount = bpString.count

        // 56-day BP (3 digits)
        if digitCount == 3 {
            let epochBP = 1
            let epochDate = calendar.date(from: DateComponents(year: 1969, month: 1, day: 13))!
            let diffBP = bp - epochBP

            guard let startDate = calendar.date(byAdding: .day, value: 56 * diffBP, to: epochDate),
                  let endDate = calendar.date(byAdding: .day, value: 55, to: startDate) else {
                return nil
            }

            return (startDate, endDate)
        }

        // 28-day BP (4 digits)
        else if digitCount == 4 {
            let lastDigit = bpString.last!

            let epochBP: Int
            let epochDate: Date

            if lastDigit == "1" {
                epochBP = 11
                epochDate = calendar.date(from: DateComponents(year: 1969, month: 1, day: 13))!
            } else {
                epochBP = 15
                epochDate = calendar.date(from: DateComponents(year: 1969, month: 2, day: 10))!
            }

            let diffBP = (bp - epochBP) / 5

            guard let startDate = calendar.date(byAdding: .day, value: 28 * diffBP, to: epochDate),
                  let endDate = calendar.date(byAdding: .day, value: 27, to: startDate) else {
                return nil
            }

            return (startDate, endDate)
        }

        return nil
    }

    // MARK: - Filtering

    /// Filter flights to only include future flights (after today)
    static func futureFlights(from flights: [ParsedFlight]) -> [ParsedFlight] {
        let today = Calendar.current.startOfDay(for: Date())
        return flights.filter { flight in
            flight.date >= today
        }
    }

    /// Filter out positioning flights if desired
    static func nonPositioningFlights(from flights: [ParsedFlight]) -> [ParsedFlight] {
        return flights.filter { !$0.isPositioning }
    }

    // MARK: - Helper Methods

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}
