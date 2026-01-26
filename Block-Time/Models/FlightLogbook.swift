//
//  FlightLogbook.swift
//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//

import Foundation

// MARK: - Global Validation Function
/// Global function to validate time strings - use this in CSV import and data entry
/// Handles numeric values and gracefully converts invalid/boolean-like values to 0.0
func validateTimeString(_ timeString: String) -> String {
    let cleanString = timeString.trimmingCharacters(in: .whitespacesAndNewlines)

    // Empty string = 0.0
    guard !cleanString.isEmpty else {
        return "0.0"
    }

    // Try to parse as numeric value
    guard let value = Double(cleanString), value.isFinite, value >= 0 else {
        // Not a valid number - could be boolean-like text ("sim", "true", etc.)
        // Log warning and return 0.0 for resilience
        LogManager.shared.warning("Invalid time value '\(cleanString)' - treating as 0.0")
        return "0.0"
    }

    return String(format: "%.1f", value)
}

// MARK: - Updated Flight Logbook Data Models
struct FlightSector: Identifiable, Codable, Hashable {
    // Cached date formatters for performance - shared across all instances
    private static let cachedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC timezone to match AirportService
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    private static let cachedMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC timezone to match cachedDateFormatter
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    private static let cachedUTCDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC timezone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    let id: UUID
    var date: String
    var flightNumber: String
    var aircraftReg: String
    var aircraftType: String
    var fromAirport: String
    var toAirport: String
    var captainName: String
    var foName: String
    var so1Name: String?
    var so2Name: String?
    var blockTime: String
    var nightTime: String
    var p1Time: String
    var p1usTime: String
    var p2Time: String
    var instrumentTime: String
    var simTime: String
    var isPilotFlying: Bool
    var isPositioning: Bool
    var isAIII: Bool
    var isRNP: Bool
    var isILS: Bool
    var isGLS: Bool
    var isNPA: Bool
    var remarks: String
    var dayTakeoffs: Int
    var dayLandings: Int
    var nightTakeoffs: Int
    var nightLandings: Int
    var outTime: String
    var inTime: String
    var scheduledDeparture: String  // STD - Scheduled Time of Departure (HHMM format)
    var scheduledArrival: String    // STA - Scheduled Time of Arrival (HHMM format)

    // MARK: - Validate and clean time string values
    private static func validateTimeString(_ timeString: String) -> String {
        let cleanString = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(cleanString), value.isFinite, value >= 0 else {
            return "0.00"
        }
        // Use 2 decimal places for precision to minimize rounding errors
        // This allows accurate representation of times (e.g., 13:40 = 13.67 hrs)
        return String(format: "%.2f", value)
    }
    
    init(id: UUID? = nil, date: String, flightNumber: String, aircraftReg: String, aircraftType: String,
         fromAirport: String, toAirport: String, captainName: String, foName: String,
         so1Name: String? = nil, so2Name: String? = nil, blockTime: String,
         nightTime: String, p1Time: String, p1usTime: String, p2Time: String = "0.0", instrumentTime: String,
         simTime: String, isPilotFlying: Bool, isPositioning: Bool = false, isAIII: Bool = false, isRNP: Bool = false,
         isILS: Bool = false, isGLS: Bool = false, isNPA: Bool = false, remarks: String = "",
         dayTakeoffs: Int = 0, dayLandings: Int = 0, nightTakeoffs: Int = 0, nightLandings: Int = 0,
         outTime: String = "", inTime: String = "", scheduledDeparture: String = "", scheduledArrival: String = "") {
        self.id = id ?? UUID()
        self.date = date
        self.flightNumber = flightNumber
        self.aircraftReg = aircraftReg
        self.aircraftType = aircraftType
        self.fromAirport = fromAirport
        self.toAirport = toAirport
        self.captainName = captainName
        self.foName = foName
        self.so1Name = so1Name
        self.so2Name = so2Name
        self.blockTime = FlightSector.validateTimeString(blockTime)
        self.nightTime = FlightSector.validateTimeString(nightTime)
        self.p1Time = FlightSector.validateTimeString(p1Time)
        self.p1usTime = FlightSector.validateTimeString(p1usTime)
        self.p2Time = FlightSector.validateTimeString(p2Time)
        self.instrumentTime = FlightSector.validateTimeString(instrumentTime)
        self.simTime = FlightSector.validateTimeString(simTime)
        self.isPilotFlying = isPilotFlying
        self.isPositioning = isPositioning
        self.isAIII = isAIII
        self.isRNP = isRNP
        self.isILS = isILS
        self.isGLS = isGLS
        self.isNPA = isNPA
        self.remarks = remarks
        self.dayTakeoffs = dayTakeoffs
        self.dayLandings = dayLandings
        self.nightTakeoffs = nightTakeoffs
        self.nightLandings = nightLandings
        self.outTime = outTime
        self.inTime = inTime
        self.scheduledDeparture = scheduledDeparture
        self.scheduledArrival = scheduledArrival

        // MARK: - Development validation
        #if DEBUG
        if let blockVal = Double(self.blockTime), blockVal > 0,
           let simVal = Double(self.simTime), simVal > 0,
           self.flightNumber != "SUMMARY" {  // Exclude Summary Rows (legitimate dual-field entries)
            LogManager.shared.warning("⚠️ FlightSector created with BOTH blockTime and simTime > 0: date=\(date), flight=\(flightNumber), block=\(self.blockTime), sim=\(self.simTime)")
        }
        #endif
    }

    // MARK: - Safe Numeric Conversion Methods
    
    /// Safely convert string to Double, returning 0.0 for invalid values
    private func safeDoubleValue(_ string: String) -> Double {
        let cleanString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanString.isEmpty, let value = Double(cleanString) else {
            return 0.0
        }
        guard value.isFinite else { // Checks for NaN and infinity
            return 0.0
        }
        return max(0.0, value) // Ensure non-negative
    }
    
    // MARK: - Safe Numeric Accessors
    
    /// Safe numeric accessors that prevent NaN errors
    var blockTimeValue: Double {
        return safeDoubleValue(blockTime)
    }
    
    var nightTimeValue: Double {
        return safeDoubleValue(nightTime)
    }
    
    var p1TimeValue: Double {
        return safeDoubleValue(p1Time)
    }
    
    var p1usTimeValue: Double {
        return safeDoubleValue(p1usTime)
    }

    var p2TimeValue: Double {
        return safeDoubleValue(p2Time)
    }

    var instrumentTimeValue: Double {
        return safeDoubleValue(instrumentTime)
    }
    
    var simTimeValue: Double {
        return safeDoubleValue(simTime)
    }
    
    // MARK: - Database Integration Methods
    
    /// Create FlightSector from Core Data entity
    static func from(entity: FlightEntity) -> FlightSector? {
        guard let id = entity.id,
              let date = entity.date,
              let flightNumber = entity.flightNumber,
              let aircraftReg = entity.aircraftReg,
              let aircraftType = entity.aircraftType,
              let fromAirport = entity.fromAirport,
              let toAirport = entity.toAirport,
              let captainName = entity.captainName,
              let foName = entity.foName,
              let blockTime = entity.blockTime,
              let nightTime = entity.nightTime,
              let p1Time = entity.p1Time,
              let p1usTime = entity.p1usTime,
              let instrumentTime = entity.instrumentTime,
              let simTime = entity.simTime else {
            return nil
        }

        // Convert Date object to string format for FlightSector
        // IMPORTANT: Database stores dates in UTC, so we must use UTC timezone when formatting
        let dateString = Self.cachedUTCDateFormatter.string(from: date)

        return FlightSector(
            id: id,
            date: dateString,
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: fromAirport,
            toAirport: toAirport,
            captainName: captainName,
            foName: foName,
            so1Name: entity.so1Name,
            so2Name: entity.so2Name,
            blockTime: blockTime,
            nightTime: nightTime,
            p1Time: p1Time,
            p1usTime: p1usTime,
            p2Time: entity.p2Time ?? "0.0",
            instrumentTime: instrumentTime,
            simTime: simTime,
            isPilotFlying: entity.isPilotFlying,
            isPositioning: entity.isPositioning,
            isAIII: entity.isAIII,
            isRNP: entity.isRNP,
            isILS: entity.isILS,
            isGLS: entity.isGLS,
            isNPA: entity.isNPA,
            remarks: entity.remarks ?? "",
            dayTakeoffs: Int(entity.dayTakeoffs),
            dayLandings: Int(entity.dayLandings),
            nightTakeoffs: Int(entity.nightTakeoffs),
            nightLandings: Int(entity.nightLandings),
            outTime: entity.outTime ?? "",
            inTime: entity.inTime ?? "",
            scheduledDeparture: entity.scheduledDeparture ?? "",
            scheduledArrival: entity.scheduledArrival ?? ""
        )
    }
    
    // MARK: - Computed properties for display with validation
    var formattedDate: String {
        if let date = Self.cachedDateFormatter.date(from: date) {
            return Self.cachedMonthYearFormatter.string(from: date).uppercased()
        }
        return date
    }

    var dayOfMonth: String {
        let components = date.split(separator: "/")
        return components.first.map(String.init) ?? ""
    }

    /// Get local date based on departure airport timezone
    /// - Parameter useLocalTime: Whether to convert to local time
    /// - Returns: Date string in "dd/MM/yyyy" format
    func getDisplayDate(useLocalTime: Bool) -> String {
        guard useLocalTime else {
            return date
        }

        // Use outTime if available, otherwise use scheduledDeparture for rostered flights
        let timeToUse = !outTime.isEmpty ? outTime : scheduledDeparture

        let localDate = AirportService.shared.convertToLocalDate(
            utcDateString: date,
            utcTimeString: timeToUse,
            airportICAO: fromAirport
        )

        return localDate
    }

    /// Get formatted date (MMM yyyy) based on local/UTC setting
    func getFormattedDate(useLocalTime: Bool) -> String {
        let displayDate = getDisplayDate(useLocalTime: useLocalTime)
        if let date = Self.cachedDateFormatter.date(from: displayDate) {
            return Self.cachedMonthYearFormatter.string(from: date).uppercased()
        }
        return displayDate
    }

    /// Get day of month based on local/UTC setting
    func getDayOfMonth(useLocalTime: Bool) -> String {
        let displayDate = getDisplayDate(useLocalTime: useLocalTime)
        let components = displayDate.split(separator: "/")
        return components.first.map(String.init) ?? ""
    }

    /// Get out time in local timezone of departure airport
    /// - Parameter useLocalTime: Whether to convert to local time
    /// - Returns: Time string in "HHMM" format (without colon)
    func getOutTime(useLocalTime: Bool) -> String {
        // Most common case: actual flights with outTime
        if !outTime.isEmpty {
            if useLocalTime {
                let time = AirportService.shared.convertToLocalTime(
                    utcDateString: date,
                    utcTimeString: outTime,
                    airportICAO: fromAirport
                )
                return time.replacingOccurrences(of: ":", with: "")
            }
            return outTime.replacingOccurrences(of: ":", with: "")
        }

        // Less common: rostered flights with scheduledDeparture
        if !scheduledDeparture.isEmpty {
            if useLocalTime {
                let time = AirportService.shared.convertToLocalTime(
                    utcDateString: date,
                    utcTimeString: scheduledDeparture,
                    airportICAO: fromAirport
                )
                return time.replacingOccurrences(of: ":", with: "")
            }
            return scheduledDeparture.replacingOccurrences(of: ":", with: "")
        }

        return ""
    }

    /// Get in time in local timezone of arrival airport
    /// - Parameter useLocalTime: Whether to convert to local time
    /// - Returns: Time string in "HHMM" format (without colon)
    func getInTime(useLocalTime: Bool) -> String {
        // Most common case: actual flights with inTime
        if !inTime.isEmpty {
            if useLocalTime {
                let time = AirportService.shared.convertToLocalTime(
                    utcDateString: date,
                    utcTimeString: inTime,
                    airportICAO: toAirport
                )
                return time.replacingOccurrences(of: ":", with: "")
            }
            return inTime.replacingOccurrences(of: ":", with: "")
        }

        // Less common: rostered flights with scheduledArrival
        if !scheduledArrival.isEmpty {
            if useLocalTime {
                let time = AirportService.shared.convertToLocalTime(
                    utcDateString: date,
                    utcTimeString: scheduledArrival,
                    airportICAO: toAirport
                )
                return time.replacingOccurrences(of: ":", with: "")
            }
            return scheduledArrival.replacingOccurrences(of: ":", with: "")
        }

        return ""
    }

    var blockTimeFormatted: String {
        let value = blockTimeValue
        return value > 0 ? String(format: "%.1f hrs", value) : "0.0 hrs"
    }

    // MARK: - Time Conversion Utilities

    /// Convert decimal hours to HH:MM format
    /// - Parameter decimalHours: Time in decimal hours (e.g., 13.67)
    /// - Returns: Time in HH:MM format (e.g., "13:40")
    static func decimalToHHMM(_ decimalHours: Double) -> String {
        guard decimalHours > 0 else { return "0:00" }

        let totalMinutes = Int(round(decimalHours * 60.0))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        return String(format: "%d:%02d", hours, minutes)
    }

    /// Convert HH:MM format to decimal hours
    /// - Parameter hhmmString: Time in HH:MM format (e.g., "13:40")
    /// - Returns: Time in decimal hours (e.g., 13.67)
    static func hhmmToDecimal(_ hhmmString: String) -> Double? {
        let trimmed = hhmmString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let components = trimmed.split(separator: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              hours >= 0, minutes >= 0, minutes < 60 else {
            return nil
        }

        let totalMinutes = Double(hours * 60 + minutes)
        return totalMinutes / 60.0
    }

    /// Format time value as HH:MM (convenience instance method)
    func formatTimeAsHoursMinutes(_ decimalHours: Double) -> String {
        return FlightSector.decimalToHHMM(decimalHours)
    }

    /// Get formatted block time (either decimal or HH:MM based on setting)
    func getFormattedBlockTime(asHoursMinutes: Bool, roundingMode: RoundingMode = .standard) -> String {
        let value = blockTimeValue
        guard value > 0 else { return asHoursMinutes ? "0:00" : "0.0 hrs" }

        if asHoursMinutes {
            return FlightSector.decimalToHHMM(value)
        } else {
            let rounded = roundingMode.apply(to: value, decimalPlaces: 1)
            return String(format: "%.1f hrs", rounded)
        }
    }

    /// Get formatted night time (either decimal or HH:MM based on setting)
    func getFormattedNightTime(asHoursMinutes: Bool, roundingMode: RoundingMode = .standard) -> String {
        let value = nightTimeValue
        guard value > 0 else { return asHoursMinutes ? "0:00" : "0.0 hrs" }

        if asHoursMinutes {
            return FlightSector.decimalToHHMM(value)
        } else {
            let rounded = roundingMode.apply(to: value, decimalPlaces: 1)
            return String(format: "%.1f hrs", rounded)
        }
    }

    /// Get formatted sim time (either decimal or HH:MM based on setting)
    func getFormattedSimTime(asHoursMinutes: Bool) -> String {
        let value = simTimeValue
        guard value > 0 else { return asHoursMinutes ? "0:00" : "0.0 hrs" }

        if asHoursMinutes {
            return FlightSector.decimalToHHMM(value)
        } else {
            return String(format: "%.1f hrs", value)
        }
    }

    /// Get formatted time value (either decimal or HH:MM based on setting)
    /// - Parameters:
    ///   - decimalValue: Time in decimal hours
    ///   - asHoursMinutes: Whether to display as HH:MM
    ///   - includeUnits: Whether to include "hrs" suffix for decimal format
    /// - Returns: Formatted time string
    static func formatTime(_ decimalValue: Double, asHoursMinutes: Bool, includeUnits: Bool = false) -> String {
        guard decimalValue > 0 else {
            return asHoursMinutes ? "0:00" : (includeUnits ? "0.0 hrs" : "0.0")
        }

        if asHoursMinutes {
            return decimalToHHMM(decimalValue)
        } else {
            let formatted = String(format: "%.1f", decimalValue)
            return includeUnits ? "\(formatted) hrs" : formatted
        }
    }

    var flightNumberFormatted: String {
        // For simulator flights, don't modify the flight number (preserve leading zeros, custom formats like SIM06B, etc.)
        if simTimeValue > 0 {
            return flightNumber
        }
        // For regular flights, remove leading zero if present
        return flightNumber.hasPrefix("0") ? String(flightNumber.dropFirst()) : flightNumber
    }
    
    /// Get validated formatted times for display
    /// - Parameter roundingMode: Rounding mode to apply to block and night times
    func safeFormattedTimes(roundingMode: RoundingMode = .standard) -> (block: String, night: String, p1: String, p1us: String, p2: String) {
        let roundedBlock = roundingMode.apply(to: blockTimeValue, decimalPlaces: 1)
        let roundedNight = roundingMode.apply(to: nightTimeValue, decimalPlaces: 1)

        return (
            block: String(format: "%.1f", roundedBlock),
            night: String(format: "%.1f", roundedNight),
            p1: String(format: "%.1f", p1TimeValue),
            p1us: String(format: "%.1f", p1usTimeValue),
            p2: String(format: "%.1f", p2TimeValue)
        )
    }
}

// MARK: - Flight Sector Creation
extension FlightSector {
    
    /// Create a FlightSector from ACARS capture data with validation
    static func fromACARSCapture(
        date: String,
        flightNumber: String,
        aircraftReg: String,
        fromAirport: String,
        toAirport: String,
        captainName: String,
        foName: String,
        blockTime: String,
        nightTime: String = "0.0",
        p1Time: String = "0.0",
        p1usTime: String = "0.0",
        p2Time: String = "0.0",
        isPilotFlying: Bool = false,
        isAIII: Bool = false,
        remarks: String = ""
    ) -> FlightSector {
        return FlightSector(
            date: date,
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            aircraftType: "B738", // Default aircraft type - can be configured
            fromAirport: fromAirport,
            toAirport: toAirport,
            captainName: captainName,
            foName: foName,
            blockTime: blockTime, // Will be validated in init
            nightTime: nightTime,
            p1Time: p1Time, // Will be validated in init
            p1usTime: p1usTime, // Will be validated in init
            p2Time: p2Time, // Will be validated in init
            instrumentTime: "0.0",
            simTime: "0.0",
            isPilotFlying: isPilotFlying,
            isAIII: isAIII,
            remarks: remarks
        )
    }
}

