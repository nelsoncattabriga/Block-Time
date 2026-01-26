//
//  TimeCalculationManager.swift
//  Block-Time
//
//  Created by Nelson on 21/10/2025.
//  Extracted from FlightTimeExtractorViewModel for better separation of concerns
//

import Foundation

/// Cached context for flight calculations to avoid redundant parsing and lookups
struct FlightCalculationContext {
    let fromAirport: String
    let toAirport: String
    let fromCoordinates: (latitude: Double, longitude: Double)
    let toCoordinates: (latitude: Double, longitude: Double)
    let flightDate: Date
    let departureTime: Date
    let arrivalTime: Date
    let blockTimeHours: Double
}

/// Manages all time-related calculations for flight data
/// Handles block time calculation, night time calculation, and time validation
class TimeCalculationManager {

    // MARK: - Dependencies

    private let nightCalcService: NightCalcService

    // MARK: - Initialization

    init(nightCalcService: NightCalcService = NightCalcService()) {
        self.nightCalcService = nightCalcService
    }

    // MARK: - Context Building

    /// Build a calculation context from flight data
    /// This parses all values once and caches them for reuse in multiple calculations
    /// - Parameters:
    ///   - fromAirport: Departure airport ICAO code
    ///   - toAirport: Arrival airport ICAO code
    ///   - outTime: Departure time in "HH:mm" format
    ///   - blockTime: Flight duration as string (decimal hours or "HH:mm")
    ///   - flightDate: Flight date string in "dd/MM/yyyy" format
    /// - Returns: Context with all parsed values, or nil if required data is missing/invalid
    func buildCalculationContext(
        fromAirport: String,
        toAirport: String,
        outTime: String,
        blockTime: String,
        flightDate: String
    ) -> FlightCalculationContext? {
        // Validate required fields
        guard !fromAirport.isEmpty, !toAirport.isEmpty,
              !outTime.isEmpty, !blockTime.isEmpty, !flightDate.isEmpty else {
            return nil
        }

        // Get airport coordinates (these are expensive lookups)
        guard let fromCoords = nightCalcService.getAirportCoordinates(for: fromAirport),
              let toCoords = nightCalcService.getAirportCoordinates(for: toAirport) else {
            return nil
        }

        // Parse flight date from DD/MM/YYYY format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let parsedFlightDate = dateFormatter.date(from: flightDate) else {
            return nil
        }

        // Parse departure time
        guard let departureTime = parseUTCTimeOnDate(outTime, on: parsedFlightDate) else {
            return nil
        }

        // Parse block time to hours
        guard let blockTimeHours = timeStringToHours(blockTime), blockTimeHours > 0 else {
            return nil
        }

        // Calculate arrival time
        let arrivalTime = departureTime.addingTimeInterval(blockTimeHours * 3600)

        return FlightCalculationContext(
            fromAirport: fromAirport,
            toAirport: toAirport,
            fromCoordinates: fromCoords,
            toCoordinates: toCoords,
            flightDate: parsedFlightDate,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            blockTimeHours: blockTimeHours
        )
    }

    // MARK: - Time Parsing

    /// Parse a UTC time string (HH:mm or HHmm) on a specific date
    /// - Parameters:
    ///   - timeStr: Time string in "HH:mm" or "HHmm" format
    ///   - date: The date to parse the time on
    /// - Returns: Date object with time set in UTC timezone, or nil if invalid
    func parseUTCTimeOnDate(_ timeStr: String, on date: Date) -> Date? {
        let clean = timeStr.replacingOccurrences(of: ":", with: "")

        // Handle both 3-digit (e.g., "710" for 07:10) and 4-digit (e.g., "0710") formats
        let hour: Int
        let minute: Int

        if clean.count == 3 {
            guard let h = Int(clean.prefix(1)),
                  let m = Int(clean.suffix(2)) else {
                return nil
            }
            hour = h
            minute = m
        } else if clean.count == 4 {
            guard let h = Int(clean.prefix(2)),
                  let m = Int(clean.suffix(2)) else {
                return nil
            }
            hour = h
            minute = m
        } else {
            return nil
        }

        guard hour < 24, minute < 60 else {
            return nil
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0

        guard let result = cal.date(from: comps) else { return nil }

        // Handle next day rollover if time has passed
        if result < date {
            return cal.date(byAdding: .day, value: 1, to: result)
        }
        return result
    }

    // MARK: - Block Time Calculation

    /// Calculate flight time (block time) from OUT and IN times
    /// - Parameters:
    ///   - outTime: Departure time in "HH:mm" format
    ///   - inTime: Arrival time in "HH:mm" format
    /// - Returns: Flight time in decimal hours with 2 decimal precision (e.g., "4.53"), or "0.0" if invalid
    func calculateFlightTime(outTime: String, inTime: String) -> String {
        guard !outTime.isEmpty && !inTime.isEmpty else { return "0.0" }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let outTimeDate = formatter.date(from: outTime),
              let inTimeDate = formatter.date(from: inTime) else {
            return "0.0"
        }

        var flightDuration = inTimeDate.timeIntervalSince(outTimeDate)

        // Handle overnight flights
        if flightDuration < 0 {
            flightDuration += 24 * 60 * 60
        }

        let totalSeconds = Int(flightDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds - (hours * 3600)) / 60
        let decimalHours = Double(hours) + (Double(minutes) / 60.0)

        // Format with 2 decimal places for precision (e.g., 4:32 = 4.53 hours, not 4.5)
        return String(format: "%.2f", decimalHours)
    }

    // MARK: - Time Validation

    /// Validate time in HH:mm (24-hour) format
    /// - Parameter timeString: Time string to validate
    /// - Returns: true if valid HH:mm format, false otherwise
    func isValidTimeHHmm(_ timeString: String) -> Bool {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return false }
        return true
    }

    // MARK: - Night Time Calculation

    /// Calculate night time for a flight
    /// - Parameters:
    ///   - fromAirport: Departure airport ICAO code
    ///   - toAirport: Arrival airport ICAO code
    ///   - outTime: Departure time in "HH:mm" format
    ///   - blockTime: Flight duration as string (decimal hours or "HH:mm")
    ///   - flightDate: Flight date string in "dd/MM/yyyy" format
    ///   - isEditingMode: Whether in editing mode (preserves existing night time if outTime is empty)
    ///   - existingNightTime: Existing night time value (for editing mode)
    /// - Returns: Night time in decimal hours with 2 decimal precision, or empty string if cannot calculate
    func calculateNightTime(
        fromAirport: String,
        toAirport: String,
        outTime: String,
        blockTime: String,
        flightDate: String,
        isEditingMode: Bool = false,
        existingNightTime: String = ""
    ) -> String {
        // If we're in editing mode and don't have outTime, preserve existing nightTime
        // (imported flights may only have blockTime and nightTime stored)
        if isEditingMode && outTime.isEmpty {
            // Don't recalculate - keep the stored night time value
            return existingNightTime
        }

        // For new flights, require all necessary fields for calculation
        guard !fromAirport.isEmpty, !toAirport.isEmpty, !outTime.isEmpty, !blockTime.isEmpty else {
            // Only clear nightTime if NOT in editing mode
            return isEditingMode ? existingNightTime : ""
        }

        let departureUTC = outTime.replacingOccurrences(of: ":", with: "")

        guard let flightTimeHours = timeStringToHours(blockTime) else {
            LogManager.shared.debug("DEBUG: TimeCalculationManager.calculateNightTime failed to convert blockTime '\(blockTime)' to hours")
            return ""
        }

        // Parse the flight date from DD/MM/YYYY format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let parsedFlightDate = dateFormatter.date(from: flightDate) ?? Date()

        LogManager.shared.debug("DEBUG: Calling calculateNightTime with from=\(fromAirport), to=\(toAirport), departureUTC=\(departureUTC), flightTimeHours=\(flightTimeHours), flightDate=\(flightDate) -> \(parsedFlightDate)")

        if let nightHours = nightCalcService.calculateNightTime(
            from: fromAirport,
            to: toAirport,
            departureUTC: departureUTC,
            flightTimeHours: flightTimeHours,
            flightDate: parsedFlightDate
        ) {
            LogManager.shared.debug("DEBUG: calculateNightTime returned \(nightHours) hours")
            // Ensure night time doesn't exceed block time due to rounding/precision
            let cappedNightHours = min(nightHours, flightTimeHours)

            // Format with 2 decimal places for consistency with storage precision
            return String(format: "%.2f", cappedNightHours)
        } else {
            return ""
        }
    }

    /// Calculate night time using a pre-built calculation context (PERFORMANCE OPTIMIZED)
    /// This method reuses already-parsed values from the context, eliminating redundant:
    /// - Airport coordinate lookups
    /// - Date parsing
    /// - Time parsing
    /// - Arrival time calculation
    /// - Parameter context: Pre-built flight calculation context
    /// - Returns: Night time in decimal hours with 2 decimal precision
    func calculateNightTime(using context: FlightCalculationContext) -> String {
        // Extract UTC hour/minute using UTC calendar (not local timezone!)
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let hour = utcCalendar.component(.hour, from: context.departureTime)
        let minute = utcCalendar.component(.minute, from: context.departureTime)

        LogManager.shared.debug("calculateNightTime(using context): departureTime=\(context.departureTime), extracted hour=\(hour), minute=\(minute)")

        let departureUTC = String(format: "%02d%02d", hour, minute)

        if let nightHours = nightCalcService.calculateNightTime(
            from: context.fromAirport,
            to: context.toAirport,
            departureUTC: departureUTC,
            flightTimeHours: context.blockTimeHours,
            flightDate: context.flightDate
        ) {
            // Ensure night time doesn't exceed block time
            let cappedNightHours = min(nightHours, context.blockTimeHours)
            return String(format: "%.2f", cappedNightHours)
        } else {
            return ""
        }
    }

    // MARK: - Helper Methods

    /// Convert time string to decimal hours
    /// Handles both "HH:mm" format and decimal format
    /// - Parameter timeString: Time string (e.g., "13:40" or "13.67")
    /// - Returns: Time in decimal hours, or nil if invalid
    /// - Note: Uses Int parsing for HH:mm format to match calculateFlightTime precision (truncates seconds)
    private func timeStringToHours(_ timeString: String) -> Double? {
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(":") {
            let components = trimmed.split(separator: ":")
            guard components.count == 2,
                  let hours = Int(components[0]),
                  let minutes = Int(components[1]) else { return nil }
            return Double(hours) + (Double(minutes) / 60.0)
        } else {
            guard let value = Double(trimmed), value.isFinite, value >= 0 else { return nil }
            return value
        }
    }
}

// MARK: - Public API for ViewModel Integration

extension TimeCalculationManager {

    /// Recalculate block time from OUT/IN times
    /// - Parameters:
    ///   - outTime: Departure time
    ///   - inTime: Arrival time
    /// - Returns: Tuple of (blockTime, isValid) where blockTime is the calculated time or empty string if invalid
    func recalculateBlockTime(outTime: String, inTime: String) -> (blockTime: String, isValid: Bool) {
        let out = outTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let inT = inTime.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !out.isEmpty, !inT.isEmpty else {
            return ("", false)
        }

        guard isValidTimeHHmm(out), isValidTimeHHmm(inT) else {
            return ("", false)
        }

        let blockTime = calculateFlightTime(outTime: out, inTime: inT)
        return (blockTime, true)
    }

    /// Complete time recalculation including both block time and night time
    /// - Parameters:
    ///   - outTime: Departure time
    ///   - inTime: Arrival time
    ///   - fromAirport: Departure airport
    ///   - toAirport: Arrival airport
    ///   - flightDate: Flight date
    ///   - isEditingMode: Whether in editing mode
    ///   - existingNightTime: Existing night time value
    /// - Returns: Tuple of (blockTime, nightTime) - both as strings
    func recalculateTimes(
        outTime: String,
        inTime: String,
        fromAirport: String,
        toAirport: String,
        flightDate: String,
        isEditingMode: Bool = false,
        existingNightTime: String = ""
    ) -> (blockTime: String, nightTime: String) {
        let out = outTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let inT = inTime.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !out.isEmpty, !inT.isEmpty, isValidTimeHHmm(out), isValidTimeHHmm(inT) else {
            return ("", isEditingMode ? existingNightTime : "")
        }

        let blockTime = calculateFlightTime(outTime: out, inTime: inT)

        // PERFORMANCE OPTIMIZATION: Try to build context for cached calculation
        if let context = buildCalculationContext(
            fromAirport: fromAirport,
            toAirport: toAirport,
            outTime: out,
            blockTime: blockTime,
            flightDate: flightDate
        ) {
            LogManager.shared.debug("⚡️ recalculateTimes: Using CACHED context for night time calculation")
            let nightTime = calculateNightTime(using: context)
            return (blockTime, nightTime)
        } else {
            // Fallback to original method if context can't be built
            LogManager.shared.debug("recalculateTimes: Context unavailable, using ORIGINAL calculation")
            let nightTime = calculateNightTime(
                fromAirport: fromAirport,
                toAirport: toAirport,
                outTime: out,
                blockTime: blockTime,
                flightDate: flightDate,
                isEditingMode: isEditingMode,
                existingNightTime: existingNightTime
            )
            return (blockTime, nightTime)
        }
    }
}
