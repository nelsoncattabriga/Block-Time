//
//  FlightAwareService.swift
//  Block-Time
//
//  Created by Nelson
//

import Foundation
import SwiftUI

struct FlightAwareData {
    let origin: String
    let destination: String
    let departureTime: String  // Actual departure time - Format: HH:MM
    let arrivalTime: String    // Actual arrival time - Format: HH:MM
    let scheduledDepartureTime: String?  // Scheduled departure time - Format: HH:MM
    let scheduledArrivalTime: String?    // Scheduled arrival time - Format: HH:MM
    let flightDate: String     // Format: dd/MM/yyyy

    var displayDescription: String {
        "\(origin) → \(destination) • Dep: \(departureTime) • Arr: \(arrivalTime)"
    }
}

enum FlightAwareError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError
    case flightNotFound
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid FlightAware URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Unable to parse flight data from FlightAware"
        case .flightNotFound:
            return "No flight found for the selected date"
        case .invalidDate:
            return "Invalid date format"
        }
    }
}

class FlightAwareService {
    static let shared = FlightAwareService()

    private init() {}

    /// Fetches flight data from FlightAware for a specific flight number and date
    /// - Parameters:
    ///   - flightNumber: The flight number in FlightAware format (e.g., "QFA933")
    ///   - date: The flight date in "dd/MM/yyyy" format
    /// - Returns: Array of FlightAwareData containing all matching flights
    func fetchFlightData(flightNumber: String, date: String) async throws -> [FlightAwareData] {
        LogManager.shared.info("FlightAware lookup started: \(flightNumber) on \(date)")

        guard let url = URL(string: "https://www.flightaware.com/live/flight/\(flightNumber)/history") else {
            LogManager.shared.error("Invalid FlightAware URL for flight: \(flightNumber)")
            throw FlightAwareError.invalidURL
        }

        // Convert date from dd/MM/yyyy to components for matching
        guard let targetDate = parseDate(date) else {
            LogManager.shared.error("Invalid date format: \(date)")
            throw FlightAwareError.invalidDate
        }

        do {
            LogManager.shared.debug("Fetching data from FlightAware URL: \(url.absoluteString)")
            // Fetch the HTML content
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let html = String(data: data, encoding: .utf8) else {
                LogManager.shared.error("Failed to decode FlightAware HTML response")
                throw FlightAwareError.parsingError
            }

            LogManager.shared.debug("Successfully fetched HTML (\(data.count) bytes), parsing flight data")
            // Parse the HTML to extract flight data
            let flights = try await parseFlightData(from: html, targetDate: targetDate, originalDateString: date)
            LogManager.shared.info("FlightAware lookup successful: Found \(flights.count) flight(s) for \(flightNumber)")
            return flights
        } catch let error as FlightAwareError {
            LogManager.shared.info("FlightAware lookup failed: \(error.localizedDescription)")
            throw error
        } catch {
            LogManager.shared.error("FlightAware network error: \(error.localizedDescription)")
            throw FlightAwareError.networkError(error)
        }
    }

    private func parseDate(_ dateString: String) -> DateComponents? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        guard let date = formatter.date(from: dateString) else {
            return nil
        }

        let calendar = Calendar.current
        return calendar.dateComponents([.day, .month, .year], from: date)
    }

    private func parseFlightData(from html: String, targetDate: DateComponents, originalDateString: String) async throws -> [FlightAwareData] {
        // Pattern 1: Look for JSON data (FlightAware often embeds flight data as JSON)
        let jsonFlights = extractAllFromJSON(html: html, targetDate: targetDate, originalDateString: originalDateString)
        if !jsonFlights.isEmpty {
            return jsonFlights
        }

        // Pattern 2: Parse HTML table rows
        let flightNumber = extractFlightNumber(from: html)
        let tableFlights = await extractAllFromHTMLTable(html: html, targetDate: targetDate, originalDateString: originalDateString, flightNumber: flightNumber)
        if !tableFlights.isEmpty {
            return tableFlights
        }

        throw FlightAwareError.flightNotFound
    }

    private func extractAllFromJSON(html: String, targetDate: DateComponents, originalDateString: String) -> [FlightAwareData] {
        let jsonPattern = #"trackpollBootstrap\s*=\s*(\{[^;]+\})"#
        guard let regex = try? NSRegularExpression(pattern: jsonPattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let jsonRange = Range(match.range(at: 1), in: html) else {
            return []
        }

        let jsonString = String(html[jsonRange])

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }

        // Navigate the JSON structure to find flight data
        if let flights = json["flights"] as? [[String: Any]] {
            return findAllMatchingFlights(in: flights, targetDate: targetDate, originalDateString: originalDateString)
        }

        return []
    }

    private func extractAllFromHTMLTable(html: String, targetDate: DateComponents, originalDateString: String, flightNumber: String) async -> [FlightAwareData] {
        let tableRowPattern = #"<tr[^>]*>.*?</tr>"#
        guard let regex = try? NSRegularExpression(pattern: tableRowPattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        var allFlights: [FlightAwareData] = []

        for match in matches {
            guard let rowRange = Range(match.range, in: html) else { continue }
            let row = String(html[rowRange])

            if let flightData = await parseTableRow(row, targetDate: targetDate, originalDateString: originalDateString, flightNumber: flightNumber) {
                allFlights.append(flightData)
            }
        }

        // Sort flights by departure time (earliest first)
        let sortedFlights = allFlights.sorted { flight1, flight2 in
            let time1 = flight1.departureTime.replacingOccurrences(of: ":", with: "")
            let time2 = flight2.departureTime.replacingOccurrences(of: ":", with: "")
            return time1 < time2
        }

        return sortedFlights
    }

    private func parseTableRow(_ row: String, targetDate: DateComponents, originalDateString: String, flightNumber: String) async -> FlightAwareData? {
        // Extract data from table cells
        // Look for patterns like: <td>YSSY</td><td>YMML</td><td>06:00</td><td>07:30</td>

        let cellPattern = #"<td[^>]*>(.*?)</td>"#
        guard let regex = try? NSRegularExpression(pattern: cellPattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(row.startIndex..., in: row)
        let matches = regex.matches(in: row, range: range)

        var cells: [String] = []
        for match in matches {
            guard let cellRange = Range(match.range(at: 1), in: row) else { continue }
            let cellContent = String(row[cellRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            cells.append(cellContent)
        }

        // Check if this row has enough cells
        // Expected format: [Date, Aircraft, Origin, Destination, Dep Time, Arr Time, Duration/Status]
        if cells.count >= 7 {
            let localDateCell = cells[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let originCell = cells[2]  // Origin with full name and codes
            let destCell = cells[3]    // Destination with full name and codes
            let depTimeCell = cells[4] // Departure time with timezone (e.g., "06:14 AEST")
            let arrTimeCell = cells[5] // Arrival time with timezone (e.g., "09:28 AWST")

            // Extract ICAO code (4-letter code after the /)
            guard let origin = extractICAOCode(from: originCell),
                  let destination = extractICAOCode(from: destCell) else {
                return nil
            }

            // Extract times (without timezone - we'll use airport ICAO codes for conversion)
            guard let depTime = extractTime(from: depTimeCell),
                  let arrTime = extractTime(from: arrTimeCell) else {
                return nil
            }

            // Convert departure time from local to UTC using origin airport
            guard let (utcDepDate, utcDepTime) = convertLocalToUTC(
                localDate: localDateCell,
                localTime: depTime,
                icaoCode: origin
            ) else {
                return nil
            }

            // Check if the UTC departure date matches the target date
            if utcDepDate != originalDateString {
                return nil
            }

            // Extract the data-target URL from the row HTML
            // Format: data-target='/live/flight/QFA933/history/20251023/2010Z/YBBN/YPPH'
            let dataTargetPattern = #"data-target='(/live/flight/[^']+)'"#
            var detailPagePath: String?

            if let regex = try? NSRegularExpression(pattern: dataTargetPattern),
               let match = regex.firstMatch(in: row, range: NSRange(row.startIndex..., in: row)),
               let pathRange = Range(match.range(at: 1), in: row) {
                detailPagePath = String(row[pathRange])
            }

            // If we couldn't extract the URL, construct it manually (fallback)
            if detailPagePath == nil {
                let dateComponents = utcDepDate.split(separator: "/")
                guard dateComponents.count == 3 else {
                    return nil
                }
                let yyyymmdd = "\(dateComponents[2])\(dateComponents[1])\(dateComponents[0])"
                let timeHHMMZ = utcDepTime.replacingOccurrences(of: ":", with: "") + "Z"
                detailPagePath = "/live/flight/\(flightNumber)/history/\(yyyymmdd)/\(timeHHMMZ)/\(origin)/\(destination)"
            }

            // Fetch the detail page and extract gate times
            if let detailData = try? await fetchFlightDetailPageByPath(
                path: detailPagePath!,
                targetDate: originalDateString,
                origin: origin,
                destination: destination
            ) {
                return detailData
            } else {
                // Convert arrival time from local to UTC using destination airport
                guard let (_, utcArrTime) = convertLocalToUTC(
                    localDate: localDateCell,
                    localTime: arrTime,
                    icaoCode: destination
                ) else {
                    return FlightAwareData(
                        origin: origin,
                        destination: destination,
                        departureTime: utcDepTime,
                        arrivalTime: "00:00",
                        scheduledDepartureTime: nil,
                        scheduledArrivalTime: nil,
                        flightDate: originalDateString
                    )
                }

                return FlightAwareData(
                    origin: origin,
                    destination: destination,
                    departureTime: utcDepTime,
                    arrivalTime: utcArrTime,
                    scheduledDepartureTime: nil,
                    scheduledArrivalTime: nil,
                    flightDate: originalDateString
                )
            }
        }

        return nil
    }

    private func extractGateTimesFromJSON(html: String, targetDate: String, origin: String, destination: String) -> FlightAwareData? {
        // Find trackpollBootstrap JSON
        let pattern = #"var trackpollBootstrap\s*=\s*(\{)"#

        guard let startRegex = try? NSRegularExpression(pattern: pattern),
              let startMatch = startRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let startRange = Range(startMatch.range(at: 1), in: html) else {
            return nil
        }

        // Extract JSON using brace matching
        let jsonStartIndex = startRange.lowerBound
        var braceCount = 0
        var jsonEndIndex = jsonStartIndex
        var inString = false
        var escapeNext = false

        for index in html[jsonStartIndex...].indices {
            let char = html[index]
            if escapeNext {
                escapeNext = false
                continue
            }
            if char == "\\" {
                escapeNext = true
                continue
            }
            if char == "\"" {
                inString.toggle()
                continue
            }
            if !inString {
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        jsonEndIndex = html.index(after: index)
                        break
                    }
                }
            }
        }

        let jsonString = String(html[jsonStartIndex..<jsonEndIndex])

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let flights = json["flights"] as? [String: Any] else {
            return nil
        }

        // Find the matching flight

        for (_, flightValue) in flights {
            guard let flightData = flightValue as? [String: Any],
                  let activityLog = flightData["activityLog"] as? [String: Any],
                  let flightsArray = activityLog["flights"] as? [[String: Any]] else {
                continue
            }

            for (_, flight) in flightsArray.enumerated() {

                // Check origin and destination first
                guard let flightOrigin = flight["origin"] as? [String: Any],
                      let flightOriginICAO = flightOrigin["icao"] as? String,
                      let flightDest = flight["destination"] as? [String: Any],
                      let flightDestICAO = flightDest["icao"] as? String else {
                    continue
                }

                // Skip if origin/destination don't match
                if flightOriginICAO != origin || flightDestICAO != destination {
                    continue
                }

                // Try to get timestamp - might be Int or might be nested
                var timestamp: Int?

                if let ts = flight["timestamp"] as? Int {
                    timestamp = ts
                } else if let ts = flight["roundedTimestamp"] as? Int {
                    timestamp = ts
                } else if let gateDepartureTimes = flight["gateDepartureTimes"] as? [String: Any],
                          let actual = gateDepartureTimes["actual"] as? Int {
                    // Use gate departure time as timestamp
                    timestamp = actual
                } else if let takeoffTimes = flight["takeoffTimes"] as? [String: Any],
                          let actual = takeoffTimes["actual"] as? Int {
                    // Use takeoff time as timestamp (for flights that have departed)
                    timestamp = actual
                } else if let landingTimes = flight["landingTimes"] as? [String: Any],
                          let actual = landingTimes["actual"] as? Int {
                    // Use landing time as timestamp (for completed flights)
                    timestamp = actual
                }

                guard let ts = timestamp else {
                    continue
                }

                let flightDate = Date(timeIntervalSince1970: TimeInterval(ts))
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                let flightDateString = formatter.string(from: flightDate)


                if flightDateString != targetDate {
                    continue
                }

                // Extract gate times (both actual and scheduled)
                var gateOutTime: String?
                var gateInTime: String?
                var takeoffTime: String?
                var landingTime: String?
                var scheduledGateOutTime: String?
                var scheduledGateInTime: String?

                // Extract gate departure time (actual and scheduled)
                if let gateDepartureTimes = flight["gateDepartureTimes"] as? [String: Any] {
                    // Extract ACTUAL time
                    var epochTimestamp: Int?

                    // Try as Int
                    if let actual = gateDepartureTimes["actual"] as? Int {
                        epochTimestamp = actual
                    }
                    // Try as nested dictionary with epoch key
                    else if let actualDict = gateDepartureTimes["actual"] as? [String: Any],
                            let epoch = actualDict["epoch"] as? Int {
                        epochTimestamp = epoch
                    }

                    if let timestamp = epochTimestamp {
                        let utcDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                        let utcFormatter = DateFormatter()
                        utcFormatter.dateFormat = "dd/MM/yyyy HH:mm"
                        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                        let utcTimeString = utcFormatter.string(from: utcDate)

                        let components = utcTimeString.split(separator: " ")
                        if components.count == 2 {
                            gateOutTime = String(components[1])
                        }
                    }

                    // Extract SCHEDULED time
                    var scheduledEpoch: Int?

                    if let scheduled = gateDepartureTimes["scheduled"] as? Int {
                        scheduledEpoch = scheduled
                    } else if let scheduledDict = gateDepartureTimes["scheduled"] as? [String: Any],
                              let epoch = scheduledDict["epoch"] as? Int {
                        scheduledEpoch = epoch
                    }

                    if let timestamp = scheduledEpoch {
                        let utcDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                        let utcFormatter = DateFormatter()
                        utcFormatter.dateFormat = "HH:mm"
                        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                        scheduledGateOutTime = utcFormatter.string(from: utcDate)
                    }
                }

                // Extract takeoff time
                if let takeoffTimes = flight["takeoffTimes"] as? [String: Any],
                   let actual = takeoffTimes["actual"] as? Int {
                    let utcDate = Date(timeIntervalSince1970: TimeInterval(actual))
                    let utcFormatter = DateFormatter()
                    utcFormatter.dateFormat = "dd/MM/yyyy HH:mm"
                    utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    let utcTimeString = utcFormatter.string(from: utcDate)

                    let components = utcTimeString.split(separator: " ")
                    if components.count == 2 {
                        takeoffTime = String(components[1])
                    }
                }

                // Extract landing time
                if let landingTimes = flight["landingTimes"] as? [String: Any],
                   let actual = landingTimes["actual"] as? Int {
                    let utcDate = Date(timeIntervalSince1970: TimeInterval(actual))
                    let utcFormatter = DateFormatter()
                    utcFormatter.dateFormat = "dd/MM/yyyy HH:mm"
                    utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    let utcTimeString = utcFormatter.string(from: utcDate)

                    let components = utcTimeString.split(separator: " ")
                    if components.count == 2 {
                        landingTime = String(components[1])
                    }
                }

                // Extract gate arrival time (actual and scheduled)
                if let gateArrivalTimes = flight["gateArrivalTimes"] as? [String: Any] {
                    // Extract ACTUAL time
                    var epochTimestamp: Int?

                    // Try as Int
                    if let actual = gateArrivalTimes["actual"] as? Int {
                        epochTimestamp = actual
                    }
                    // Try as nested dictionary with epoch key
                    else if let actualDict = gateArrivalTimes["actual"] as? [String: Any],
                            let epoch = actualDict["epoch"] as? Int {
                        epochTimestamp = epoch
                    }

                    if let timestamp = epochTimestamp {
                        let utcDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                        let utcFormatter = DateFormatter()
                        utcFormatter.dateFormat = "dd/MM/yyyy HH:mm"
                        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                        let utcTimeString = utcFormatter.string(from: utcDate)

                        let components = utcTimeString.split(separator: " ")
                        if components.count == 2 {
                            gateInTime = String(components[1])
                        }
                    }

                    // Extract SCHEDULED time
                    var scheduledEpoch: Int?

                    if let scheduled = gateArrivalTimes["scheduled"] as? Int {
                        scheduledEpoch = scheduled
                    } else if let scheduledDict = gateArrivalTimes["scheduled"] as? [String: Any],
                              let epoch = scheduledDict["epoch"] as? Int {
                        scheduledEpoch = epoch
                    }

                    if let timestamp = scheduledEpoch {
                        let utcDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                        let utcFormatter = DateFormatter()
                        utcFormatter.dateFormat = "HH:mm"
                        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                        scheduledGateInTime = utcFormatter.string(from: utcDate)
                    }
                }

                // Use gate times if available, otherwise fall back to runway times
                let finalOutTime = gateOutTime ?? takeoffTime
                let finalInTime = gateInTime ?? landingTime

                if let outTime = finalOutTime, let inTime = finalInTime {
                    return FlightAwareData(
                        origin: origin,
                        destination: destination,
                        departureTime: outTime,
                        arrivalTime: inTime,
                        scheduledDepartureTime: scheduledGateOutTime,
                        scheduledArrivalTime: scheduledGateInTime,
                        flightDate: targetDate
                    )
                }
            }
        }

        return nil
    }

    private func extractFlightNumber(from html: String) -> String {
        // Extract flight number from page title or heading
        // Look for patterns like "QFA933 Flight Activity History"
        let pattern = #"([A-Z]{2,3}\d{1,4})\s+Flight Activity History"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let flightRange = Range(match.range(at: 1), in: html) else {
            return "UNKNOWN"
        }
        return String(html[flightRange])
    }

    private func fetchFlightDetailPageByPath(path: String, targetDate: String, origin: String, destination: String) async throws -> FlightAwareData? {
        // Construct the full URL from the path
        let detailURL = "https://www.flightaware.com\(path)"


        guard let url = URL(string: detailURL) else {
            LogManager.shared.error("FlightAware Detail: Invalid URL")
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let html = String(data: data, encoding: .utf8) else {
                LogManager.shared.error("FlightAware Detail: Failed to decode HTML")
                return nil
            }

            // Extract gate times from JSON
            return extractGateTimesFromJSON(html: html, targetDate: targetDate, origin: origin, destination: destination)

        } catch {
            LogManager.shared.error("FlightAware Detail: Error - \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFlightDetailPageData(flightNumber: String, date: String, time: String, origin: String, destination: String, targetDate: String) async throws -> FlightAwareData? {
        // Construct the detail page URL
        let detailURL = "https://www.flightaware.com/live/flight/\(flightNumber)/history/\(date)/\(time)/\(origin)/\(destination)"


        guard let url = URL(string: detailURL) else {
            LogManager.shared.error("FlightAware Detail: Invalid URL")
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let html = String(data: data, encoding: .utf8) else {
                LogManager.shared.error("FlightAware Detail: Failed to decode HTML")
                return nil
            }

            // Extract gate times from JSON
            return extractGateTimesFromJSON(html: html, targetDate: targetDate, origin: origin, destination: destination)

        } catch {
            LogManager.shared.error("FlightAware Detail: Error - \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFlightDetailPage(flightNumber: String, date: String, time: String, origin: String, destination: String) async throws {
        // Construct the detail page URL
        // Format: /live/flight/QFA933/history/20251023/2010Z/YBBN/YPPH

        let detailURL = "https://www.flightaware.com/live/flight/\(flightNumber)/history/\(date)/\(time)/\(origin)/\(destination)"


        guard let url = URL(string: detailURL) else {
            LogManager.shared.error("FlightAware: Invalid detail page URL")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let html = String(data: data, encoding: .utf8) else {
                LogManager.shared.error("FlightAware Detail: Failed to decode HTML data")
                return
            }

            LogManager.shared.info("📄 FlightAware Detail: HTML length: \(html.count) characters")
            LogManager.shared.info(String(repeating: "=", count: 80))
            LogManager.shared.info("FLIGHT DETAIL PAGE ANALYSIS - Available Data:")
            LogManager.shared.info(String(repeating: "=", count: 80))

            // Look for JSON data structures
            analyzeJSONData(in: html)

            // Look for table structures
            analyzeTableData(in: html)

            // Look for metadata
            analyzeMetadata(in: html)

            LogManager.shared.info(String(repeating: "=", count: 80))

        } catch {
            LogManager.shared.error("FlightAware Detail: Error fetching page - \(error.localizedDescription)")
        }
    }

    private func analyzeJSONData(in html: String) {
        LogManager.shared.info("\nJSON DATA STRUCTURES:")

        // Look for trackpollBootstrap which contains the flight data
        // The JSON can be very large and complex, so we need to match it carefully
        let pattern = #"var trackpollBootstrap\s*=\s*(\{)"#

        guard let startRegex = try? NSRegularExpression(pattern: pattern),
              let startMatch = startRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let startRange = Range(startMatch.range(at: 1), in: html) else {
            LogManager.shared.info("  No 'trackpollBootstrap' found")
            return
        }

        // Find the start position of the JSON object
        let jsonStartIndex = startRange.lowerBound

        // Now we need to find the matching closing brace
        // Count braces to find where the JSON object ends
        var braceCount = 0
        var jsonEndIndex = jsonStartIndex
        var inString = false
        var escapeNext = false

        for index in html[jsonStartIndex...].indices {
            let char = html[index]

            if escapeNext {
                escapeNext = false
                continue
            }

            if char == "\\" {
                escapeNext = true
                continue
            }

            if char == "\"" {
                inString.toggle()
                continue
            }

            if !inString {
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        jsonEndIndex = html.index(after: index)
                        break
                    }
                }
            }
        }

        let jsonString = String(html[jsonStartIndex..<jsonEndIndex])
        LogManager.shared.info("  Found 'trackpollBootstrap' - Length: \(jsonString.count) characters")

        if let jsonData = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

            LogManager.shared.info("\n  Analyzing trackpollBootstrap structure:")
            LogManager.shared.info("     Top-level keys: \(json.keys.joined(separator: ", "))")

            // Navigate to flights data
            if let flights = json["flights"] as? [String: Any] {
                LogManager.shared.info("\n  ✈️ Found flights object with \(flights.count) entries")

                for (flightKey, flightValue) in flights {
                    LogManager.shared.info("\n  📋 Flight key: \(flightKey)")

                    guard let flightData = flightValue as? [String: Any] else { continue }

                    // Look for activityLog
                    if let activityLog = flightData["activityLog"] as? [String: Any],
                       let flightsArray = activityLog["flights"] as? [[String: Any]] {

                        LogManager.shared.info("     Found \(flightsArray.count) flight(s) in activityLog")

                        for (index, flight) in flightsArray.enumerated() {
                            LogManager.shared.info("\n     🛫 Flight \(index + 1):")
                            LogManager.shared.info("        Available keys: \(flight.keys.joined(separator: ", "))")

                            // Gate departure time (OUT)
                            if let gateDepartureTimes = flight["gateDepartureTimes"] as? [String: Any] {
                                LogManager.shared.info("        🔑 gateDepartureTimes keys: \(gateDepartureTimes.keys.joined(separator: ", "))")

                                // Try as dictionary
                                if let actual = gateDepartureTimes["actual"] as? [String: Any] {
                                    LogManager.shared.info("           🔑 actual (dict) keys: \(actual.keys.joined(separator: ", "))")
                                    if let localtime = actual["localtime"] as? String {
                                        LogManager.shared.info("        🚪 Gate Departure (OUT): \(localtime)")
                                    }
                                    if let epoch = actual["epoch"] as? Int {
                                        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "dd/MM/yyyy HH:mm"
                                        formatter.timeZone = TimeZone(identifier: "Australia/Brisbane")
                                        LogManager.shared.info("        🚪 Gate Departure (OUT) from epoch: \(formatter.string(from: date))")
                                    }
                                }
                                // Try as string (in case it's a direct time string)
                                else if let actualString = gateDepartureTimes["actual"] as? String {
                                    LogManager.shared.info("           🔑 actual (string): \(actualString)")
                                    LogManager.shared.info("        🚪 Gate Departure (OUT): \(actualString)")
                                }
                                // Try as number (epoch timestamp)
                                else if let actualEpoch = gateDepartureTimes["actual"] as? Int {
                                    let date = Date(timeIntervalSince1970: TimeInterval(actualEpoch))
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "dd/MM/yyyy HH:mm"
                                    formatter.timeZone = TimeZone(identifier: "Australia/Brisbane")
                                    LogManager.shared.info("        🚪 Gate Departure (OUT): \(formatter.string(from: date))")
                                }
                            }

                            // Runway departure time (OFF)
                            if let takeoffTimes = flight["takeoffTimes"] as? [String: Any] {
                                if let actual = takeoffTimes["actual"] as? [String: Any] {
                                    if let localtime = actual["localtime"] as? String {
                                        LogManager.shared.info("        🛫 Runway Departure (OFF): \(localtime)")
                                    }
                                }
                            }

                            // Runway arrival time (ON)
                            if let landingTimes = flight["landingTimes"] as? [String: Any] {
                                if let actual = landingTimes["actual"] as? [String: Any] {
                                    if let localtime = actual["localtime"] as? String {
                                        LogManager.shared.info("        🛬 Runway Arrival (ON): \(localtime)")
                                    }
                                }
                            }

                            // Gate arrival time (IN)
                            if let gateArrivalTimes = flight["gateArrivalTimes"] as? [String: Any] {
                                LogManager.shared.info("        🔑 gateArrivalTimes keys: \(gateArrivalTimes.keys.joined(separator: ", "))")

                                // Try as dictionary
                                if let actual = gateArrivalTimes["actual"] as? [String: Any] {
                                    LogManager.shared.info("           🔑 actual (dict) keys: \(actual.keys.joined(separator: ", "))")
                                    if let localtime = actual["localtime"] as? String {
                                        LogManager.shared.info("        🚪 Gate Arrival (IN): \(localtime)")
                                    }
                                    if let epoch = actual["epoch"] as? Int {
                                        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "dd/MM/yyyy HH:mm"
                                        formatter.timeZone = TimeZone(identifier: "Australia/Perth")
                                        LogManager.shared.info("        🚪 Gate Arrival (IN) from epoch: \(formatter.string(from: date))")
                                    }
                                }
                                // Try as string
                                else if let actualString = gateArrivalTimes["actual"] as? String {
                                    LogManager.shared.info("           🔑 actual (string): \(actualString)")
                                    LogManager.shared.info("        🚪 Gate Arrival (IN): \(actualString)")
                                }
                                // Try as number (epoch timestamp)
                                else if let actualEpoch = gateArrivalTimes["actual"] as? Int {
                                    let date = Date(timeIntervalSince1970: TimeInterval(actualEpoch))
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "dd/MM/yyyy HH:mm"
                                    formatter.timeZone = TimeZone(identifier: "Australia/Perth")
                                    LogManager.shared.info("        🚪 Gate Arrival (IN): \(formatter.string(from: date))")
                                }
                            }

                            // Origin and destination
                            if let origin = flight["origin"] as? [String: Any],
                               let originCode = origin["icao"] as? String {
                                LogManager.shared.info("        📍 Origin: \(originCode)")
                            }

                            if let destination = flight["destination"] as? [String: Any],
                               let destCode = destination["icao"] as? String {
                                LogManager.shared.info("        📍 Destination: \(destCode)")
                            }

                            // Timestamp for matching the correct flight
                            if let timestamp = flight["timestamp"] as? Int {
                                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                                let formatter = DateFormatter()
                                formatter.dateFormat = "dd/MM/yyyy HH:mm"
                                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                                LogManager.shared.info("        Flight timestamp (UTC): \(formatter.string(from: date))")
                            }
                        }
                    }
                }
            }
        } else {
            LogManager.shared.info("  Failed to parse trackpollBootstrap JSON")
        }
    }

    private func analyzeTableData(in html: String) {
        LogManager.shared.info("\n📋 TABLE DATA STRUCTURES:")

        // Look for tables with specific classes or IDs
        let tablePattern = #"<table[^>]*class="([^"]*)"[^>]*>(.*?)</table>"#
        if let regex = try? NSRegularExpression(pattern: tablePattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            LogManager.shared.info("  Found \(matches.count) tables")

            for (index, match) in matches.prefix(5).enumerated() {
                if let classRange = Range(match.range(at: 1), in: html) {
                    let className = String(html[classRange])
                    LogManager.shared.info("  Table \(index + 1): class=\"\(className)\"")
                }
            }
        }

        // Look for specific data labels
        let dataLabels = ["Departure", "Arrival", "Scheduled", "Actual", "Gate", "Runway", "Duration"]
        for label in dataLabels {
            if html.contains(label) {
                LogManager.shared.info("  Found label: '\(label)'")
            }
        }
    }

    private func analyzeMetadata(in html: String) {
        LogManager.shared.info("\n📝 METADATA:")

        // Look for meta tags
        let metaPattern = #"<meta\s+property="([^"]+)"\s+content="([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: metaPattern) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            LogManager.shared.info("  Found \(matches.count) meta tags")

            for match in matches.prefix(10) {
                if let propRange = Range(match.range(at: 1), in: html),
                   let contentRange = Range(match.range(at: 2), in: html) {
                    let prop = String(html[propRange])
                    let content = String(html[contentRange])
                    LogManager.shared.info("  \(prop): \(content)")
                }
            }
        }
    }

    private func extractICAOCode(from text: String) -> String? {
        // Extract ICAO code from text like "Brisbane (BNE / YBBN)" or "Los Angeles Intl (KLAX)"
        // We want the 4-letter code - either after the / or standalone in parentheses

        // First try: Pattern with forward slash - "BNE / YBBN" -> YBBN
        let patternWithSlash = #"/\s*([A-Z]{4})\)"#
        if let regex = try? NSRegularExpression(pattern: patternWithSlash),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let codeRange = Range(match.range(at: 1), in: text) {
            return String(text[codeRange])
        }

        // Second try: Pattern without slash - "(KLAX)" -> KLAX
        let patternWithoutSlash = #"\(([A-Z]{4})\)"#
        if let regex = try? NSRegularExpression(pattern: patternWithoutSlash),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let codeRange = Range(match.range(at: 1), in: text) {
            return String(text[codeRange])
        }

        return nil
    }

    private func extractTime(from text: String) -> String? {
        // Extract time from text like "06:14&nbsp;AEST" or "06:14 AEST"
        // Clean up &nbsp; entities first
        let cleanText = text.replacingOccurrences(of: "&nbsp;", with: " ")

        let pattern = #"(\d{2}:\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText)),
              let timeRange = Range(match.range(at: 1), in: cleanText) else {
            return nil
        }

        return String(cleanText[timeRange])
    }

    private func convertLocalToUTC(localDate: String, localTime: String, icaoCode: String) -> (date: String, time: String)? {
        // Use AirportService to convert local date/time to UTC
        // This properly handles DST and all timezones from airports.dat

        let airportService = AirportService.shared

        // Convert time format from "HH:MM" to "HHMM" for AirportService
        let timeForService = localTime.replacingOccurrences(of: ":", with: "")

        let utcDate = airportService.convertFromLocalToUTCDate(
            localDateString: localDate,
            localTimeString: timeForService,
            airportICAO: icaoCode
        )

        let utcTime = airportService.convertFromLocalToUTCTime(
            localDateString: localDate,
            localTimeString: timeForService,
            airportICAO: icaoCode
        )


        return (utcDate, utcTime)
    }

    private func findAllMatchingFlights(in flights: [[String: Any]], targetDate: DateComponents, originalDateString: String) -> [FlightAwareData] {
        var allFlights: [FlightAwareData] = []

        // Search through JSON flight array for matching date
        for flight in flights {

            // Extract origin, destination, and times
            guard let origin = flight["origin"] as? String ?? flight["originCode"] as? String,
                  let destination = flight["destination"] as? String ?? flight["destinationCode"] as? String,
                  let departureTime = flight["departureTime"] as? String ?? flight["gateDepartureTime"] as? String,
                  let arrivalTime = flight["arrivalTime"] as? String ?? flight["gateArrivalTime"] as? String else {
                continue
            }


            // Convert times to HH:MM format if needed
            let formattedDepTime = formatTime(departureTime)
            let formattedArrTime = formatTime(arrivalTime)

            allFlights.append(FlightAwareData(
                origin: origin,
                destination: destination,
                departureTime: formattedDepTime,
                arrivalTime: formattedArrTime,
                scheduledDepartureTime: nil,
                scheduledArrivalTime: nil,
                flightDate: originalDateString
            ))
        }


        // Sort flights by departure time (earliest first)
        let sortedFlights = allFlights.sorted { flight1, flight2 in
            // Parse times in HH:MM format for comparison
            let time1 = flight1.departureTime.replacingOccurrences(of: ":", with: "")
            let time2 = flight2.departureTime.replacingOccurrences(of: ":", with: "")
            return time1 < time2
        }

        return sortedFlights
    }

    private func isValidAirportCode(_ code: String) -> Bool {
        // ICAO codes are 4 letters, IATA codes are 3 letters
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.count == 3 || trimmed.count == 4) && trimmed.allSatisfy { $0.isLetter }
    }

    private func isValidTime(_ time: String) -> Bool {
        // Check if string looks like a time (HH:MM or similar)
        let timePattern = #"^\d{1,2}:\d{2}$"#
        guard let regex = try? NSRegularExpression(pattern: timePattern) else {
            return false
        }
        let range = NSRange(time.startIndex..., in: time)
        return regex.firstMatch(in: time, range: range) != nil
    }

    private func formatTime(_ time: String) -> String {
        // Ensure time is in HH:MM format
        let components = time.components(separatedBy: ":")
        guard components.count >= 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]) else {
            return time
        }

        return String(format: "%02d:%02d", hours, minutes)
    }
}
