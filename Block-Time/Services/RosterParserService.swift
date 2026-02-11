//
//  RosterParserService.swift
//  Block-Time
//
//  Created by Nelson on 18/10/2025.
//

import Foundation

/// Service to parse Qantas crew roster files and extract flight information
class RosterParserService {

    // MARK: - Data Models

    /// Represents a parsed flight from a roster
    struct ParsedFlight {
        let date: Date
        let flightNumber: String
        let departureAirport: String
        let arrivalAirport: String
        let departureTime: String  // HHmm format (e.g., "1239")
        let arrivalTime: String    // HHmm format (e.g., "1517")
        let aircraftType: String   // Converted from equipment code (e.g., "B738")
        let role: String           // "Captain" or "First Officer"
        let isPositioning: Bool    // True if marked with "P"
        let bidPeriod: String      // e.g., "3711"
        let dutyCode: String?      // e.g., "5017A2" (optional)
    }

    /// Result of parsing a roster file
    struct ParseResult {
        let flights: [ParsedFlight]
        let pilotName: String
        let staffNumber: String
        let bidPeriod: String
        let base: String
        let category: String  // e.g., "CPT-B737"
    }

    // MARK: - Equipment Code Mapping

    /// Map roster equipment codes to ICAO aircraft types
    private static let equipmentMapping: [String: String] = [
        "73H": "B738",  // 737-800
        "73J": "B738",  // 737-800
        "73W": "B739",  // 737-900
        "73X": "B38M",  // 737 MAX 8
        "333": "A333",  // A330-300
        "332": "A332",  // A330-200
        "388": "A388",  // A380-800
        "789": "B789",  // 787-9
        "788": "B788",  // 787-8
        "223": "A220",  // A220-300
        "E90": "E190",  // E190
        "E95": "E190",  // E190
    ]

    // MARK: - Parsing Methods

    /// Parse a roster file and extract flight information
    static func parseRoster(from fileURL: URL) throws -> ParseResult {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try parseRoster(from: content)
    }

    /// Parse roster content from a string
    static func parseRoster(from content: String) throws -> ParseResult {
        let lines = content.components(separatedBy: .newlines)

        // Extract header information
        let pilotInfo = extractPilotInfo(from: lines)

        // Extract flights from Pattern Details section
        let flights = extractFlights(from: lines, pilotInfo: pilotInfo)

        return ParseResult(
            flights: flights,
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
        let year: Int  // Year for date conversion
    }

    private static func extractPilotInfo(from lines: [String]) -> PilotInfo {
        var name = ""
        var staffNumber = ""
        var bidPeriod = ""
        var base = ""
        var category = ""
        var year = Calendar.current.component(.year, from: Date())

        for line in lines {
            // Extract bid period from header (e.g., "Bid Period 3711", "Bid Period 3715")
            // Also extract year from the date in header (e.g., "15Oct25 1605")
            if line.contains("QANTAS AIRWAYS LIMITED") {
                // Look for date pattern like "15Oct25 1605" or "17Oct25 1605"
                let datePattern = #"\d{2}\w{3}(\d{2})\s+\d{4}"#
                if let match = line.range(of: datePattern, options: .regularExpression) {
                    let matched = String(line[match])
                    // Extract the year digits (e.g., "25" from "15Oct25 1605")
                    let yearPattern = #"\d{2}\w{3}(\d{2})"#
                    if let yearMatch = matched.range(of: yearPattern, options: .regularExpression) {
                        let yearStr = String(matched[yearMatch])
                        // Get last 2 characters (the year)
                        let yearDigitsStr = String(yearStr.suffix(2))
                        if let yearDigits = Int(yearDigitsStr) {
                            year = 2000 + yearDigits
                                            LogManager.shared.debug("Detected year from header: 20\(yearDigitsStr) = \(year)")
                        }
                    }
                }
            }

            if line.contains("Bid Period") {
                let pattern = #"Bid Period (\d{4})"#
                if let match = line.range(of: pattern, options: .regularExpression) {
                    bidPeriod = String(line[match]).replacingOccurrences(of: "Bid Period ", with: "")
                                    LogManager.shared.debug("📋 Detected bid period: \(bidPeriod)")
                }
            }

            // Extract pilot name
            if line.contains("Name    :") {
                let components = line.components(separatedBy: ":")
                if components.count >= 2 {
                    let nameSection = components[1].trimmingCharacters(in: .whitespaces)
                    name = nameSection.components(separatedBy: "Category")[0].trimmingCharacters(in: .whitespaces)
                }

                // Extract category from same line
                if line.contains("Category:") {
                    let categoryComponents = line.components(separatedBy: "Category:")
                    if categoryComponents.count >= 2 {
                        category = categoryComponents[1].trimmingCharacters(in: .whitespaces)
                    }
                }
            }

            // Extract staff number
            if line.contains("Staff No:") {
                let components = line.components(separatedBy: ":")
                if components.count >= 2 {
                    let staffSection = components[1].trimmingCharacters(in: .whitespaces)
                    staffNumber = staffSection.components(separatedBy: .whitespaces)[0]
                }

                // Extract base from same line
                if line.contains("Base    :") {
                    let baseComponents = line.components(separatedBy: "Base    :")
                    if baseComponents.count >= 2 {
                        base = baseComponents[1].trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        return PilotInfo(
            name: name,
            staffNumber: staffNumber,
            bidPeriod: bidPeriod,
            base: base,
            category: category,
            year: year
        )
    }

    // MARK: - Flight Parsing

    private static func extractFlights(from lines: [String], pilotInfo: PilotInfo) -> [ParsedFlight] {
        var flights: [ParsedFlight] = []
        var currentRole = "Captain"  // Default role
        var currentDutyCode: String?

                        LogManager.shared.debug("Starting flight extraction from \(lines.count) lines")

        for (index, line) in lines.enumerated() {
            // Detect role from section headers
            if line.contains("1-CPT") {
                currentRole = "Captain"
                                LogManager.shared.debug("👨‍✈️ Role detected: Captain (line \(index))")
            } else if line.contains("1-F/O") {
                currentRole = "First Officer"
                                LogManager.shared.debug("👨‍✈️ Role detected: First Officer (line \(index))")
            }

            // Extract duty code from reason lines (e.g., "5017A2 DATED 06Oct25")
            if line.contains("DATED") {
                let pattern = #"(\w+)\s+DATED"#
                if let match = line.range(of: pattern, options: .regularExpression) {
                    let matched = String(line[match])
                    currentDutyCode = matched.replacingOccurrences(of: " DATED", with: "").trimmingCharacters(in: .whitespaces)
                                    LogManager.shared.debug("📋 Duty code detected: \(currentDutyCode ?? "nil") (line \(index))")
                }
            }

            // Parse flight lines
            // Format examples:
            // 03Nov       613  BNE  0800 MEL  1125  73H   2:25   1:05          ( 1
            // 09Nov P     510  SYD  0910 BNE  0940  73H   0:00                 ( 2
            // Pattern: Date [P] Flight Dept Time Arr Time Eq ...
            let pattern = #"^(\d{2}\w{3})\s+(P)?\s*(\d{3,4})\s+([A-Z]{3})\s+(\d{4})\s+([A-Z]{3})\s+(\d{4})\s+([A-Z0-9]{3})"#

            if let match = line.range(of: pattern, options: .regularExpression) {
                LogManager.shared.debug("✈️  Line \(index): \(line.trimmingCharacters(in: .whitespaces))")

                let matched = String(line[match])
                let components = matched.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

                LogManager.shared.debug("   Components: \(components)")

                guard components.count >= 7 else {
                    LogManager.shared.debug("    Not enough components (need 7+, got \(components.count))")
                    continue
                }

                let dateString = components[0]  // e.g., "03Nov"

                // Check if second component is "P" for positioning
                let isPositioning = components[1] == "P"
                let flightIndex = isPositioning ? 2 : 1

                let flightNumber = components[flightIndex]
                let departureAirport = components[flightIndex + 1]
                let departureTime = components[flightIndex + 2]
                let arrivalAirport = components[flightIndex + 3]
                let arrivalTime = components[flightIndex + 4]
                let equipmentCode = components[flightIndex + 5]

                LogManager.shared.debug("   Date: \(dateString)")
                LogManager.shared.debug("   ✈️  Flight: \(flightNumber)")
                LogManager.shared.debug("   🛫 From: \(departureAirport) at \(departureTime)")
                LogManager.shared.debug("   🛬 To: \(arrivalAirport) at \(arrivalTime)")
                LogManager.shared.debug("   🛩️  Aircraft: \(equipmentCode)")
                LogManager.shared.debug("   🅿️  Positioning: \(isPositioning)")

                // Convert date string to Date
                if let date = convertDate(dateString, year: pilotInfo.year) {
                    // Convert equipment code to ICAO type
                    let aircraftType = equipmentMapping[equipmentCode] ?? equipmentCode

                    let flight = ParsedFlight(
                        date: date,
                        flightNumber: flightNumber,
                        departureAirport: departureAirport,
                        arrivalAirport: arrivalAirport,
                        departureTime: departureTime,
                        arrivalTime: arrivalTime,
                        aircraftType: aircraftType,
                        role: currentRole,
                        isPositioning: isPositioning,
                        bidPeriod: pilotInfo.bidPeriod,
                        dutyCode: currentDutyCode
                    )

                    flights.append(flight)
                                    LogManager.shared.debug("   Flight added! Total flights: \(flights.count)")
                } else {
                                    LogManager.shared.debug("   Failed to convert date: \(dateString)")
                }
            }
        }

                        LogManager.shared.debug("🎯 Total flights extracted: \(flights.count)")
        return flights
    }

    // MARK: - Date Conversion

    /// Convert roster date string (e.g., "06Oct") to Date using provided year
    /// Handles year boundary crossing when roster spans December/January
    /// If we're in December (month 12) and see a January flight (month 1), it's next year
    private static func convertDate(_ dateString: String, year: Int) -> Date? {
        // Format: "06Oct" = day + month abbreviation
        let dayString = String(dateString.prefix(2))
        let monthString = String(dateString.suffix(3))

        guard let day = Int(dayString) else { return nil }

        // Month abbreviation to number mapping
        let monthMap: [String: Int] = [
            "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
            "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12
        ]

        guard let month = monthMap[monthString] else { return nil }

        // Handle year-spanning rosters (Dec-Jan boundary)
        // If we extracted year from a December roster (e.g., "15Dec25" -> 2025)
        // but see a January flight, it should be January 2026
        var adjustedYear = year

        // Get the roster header month (from the year we extracted)
        // If the roster is dated in December (month 12) and we see Jan/Feb flights,
        // those are in the next year
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)

        // Simple heuristic: if we're in month 12 and flight is in month 1-2, add a year
        // This handles the December-January boundary case
        if currentMonth == 12 && month <= 2 {
            adjustedYear = year + 1
        }

        var components = DateComponents()
        components.year = adjustedYear
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0

        return Calendar.current.date(from: components)
    }

    // MARK: - Filtering

    /// Filter flights to only include future flights (after today)
    static func futureFights(from flights: [ParsedFlight]) -> [ParsedFlight] {
        let today = Calendar.current.startOfDay(for: Date())
        return flights.filter { flight in
            flight.date >= today
        }
    }

    /// Filter out positioning flights if desired
    static func nonPositioningFlights(from flights: [ParsedFlight]) -> [ParsedFlight] {
        return flights.filter { !$0.isPositioning }
    }
}
