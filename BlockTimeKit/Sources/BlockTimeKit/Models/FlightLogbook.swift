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
public func validateTimeString(_ timeString: String) -> String {
    let cleanString = timeString.trimmingCharacters(in: .whitespacesAndNewlines)

    // Empty string = 0.0
    guard !cleanString.isEmpty else {
        return "0.0"
    }

    // Try to parse as numeric value
    guard let value = Double(cleanString), value.isFinite, value >= 0 else {
        // Not a valid number - could be boolean-like text ("sim", "true", etc.)
        // Log warning and return 0.0 for resilience
        print("Invalid time value '\(cleanString)' - treating as 0.0")
        return "0.0"
    }

    return String(format: "%.1f", value)
}

// MARK: - Updated Flight Logbook Data Models
public struct FlightSector: Identifiable, Codable, Hashable {
    // Thread-local date formatters — DateFormatter is not thread-safe, so each thread
    // gets its own instance via threadDictionary to avoid ICU clone contention.
    private static var cachedDateFormatter: DateFormatter {
        let key = "FlightSector.dateFormatter"
        if let existing = Thread.current.threadDictionary[key] as? DateFormatter { return existing }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_AU")
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    private static var cachedMonthYearFormatter: DateFormatter {
        let key = "FlightSector.monthYearFormatter"
        if let existing = Thread.current.threadDictionary[key] as? DateFormatter { return existing }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_AU")
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    static var cachedUTCDateFormatter: DateFormatter {
        let key = "FlightSector.utcDateFormatter"
        if let existing = Thread.current.threadDictionary[key] as? DateFormatter { return existing }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    public let id: UUID
    public var date: String
    public var flightNumber: String
    public var aircraftReg: String
    public var aircraftType: String
    public var fromAirport: String
    public var toAirport: String
    public var captainName: String
    public var foName: String
    public var so1Name: String?
    public var so2Name: String?
    public var blockTime: String
    public var nightTime: String
    public var p1Time: String
    public var p1usTime: String
    public var p2Time: String
    public var instrumentTime: String
    public var simTime: String
    public var spInsTime: String
    public var isPilotFlying: Bool
    public var isPositioning: Bool
    public var isAIII: Bool
    public var isRNP: Bool
    public var isILS: Bool
    public var isGLS: Bool
    public var isNPA: Bool
    public var remarks: String
    public var dayTakeoffs: Int
    public var dayLandings: Int
    public var nightTakeoffs: Int
    public var nightLandings: Int
    public var outTime: String
    public var inTime: String
    public var scheduledDeparture: String  // STD - Scheduled Time of Departure (HHMM format)
    public var scheduledArrival: String    // STA - Scheduled Time of Arrival (HHMM format)
    public var counterEntries: [Int: String] = [:]  // columnIndex → raw value
    public var createdAt: Date?
    public let parsedDate: Date?

    private enum CodingKeys: String, CodingKey {
        case id, date, flightNumber, aircraftReg, aircraftType, fromAirport, toAirport
        case captainName, foName, so1Name, so2Name
        case blockTime, nightTime, p1Time, p1usTime, p2Time, instrumentTime, simTime, spInsTime
        case isPilotFlying, isPositioning, isAIII, isRNP, isILS, isGLS, isNPA
        case remarks, dayTakeoffs, dayLandings, nightTakeoffs, nightLandings
        case outTime, inTime, scheduledDeparture, scheduledArrival, counterEntries, createdAt
    }

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
    public init(id: UUID? = nil, date: String, flightNumber: String, aircraftReg: String, aircraftType: String,
         fromAirport: String, toAirport: String, captainName: String, foName: String,
         so1Name: String? = nil, so2Name: String? = nil, blockTime: String,
         nightTime: String, p1Time: String, p1usTime: String, p2Time: String = "0.0", instrumentTime: String,
         simTime: String, spInsTime: String = "", isPilotFlying: Bool, isPositioning: Bool = false, isAIII: Bool = false, isRNP: Bool = false,
         isILS: Bool = false, isGLS: Bool = false, isNPA: Bool = false, remarks: String = "",
         dayTakeoffs: Int = 0, dayLandings: Int = 0, nightTakeoffs: Int = 0, nightLandings: Int = 0,
         outTime: String = "", inTime: String = "", scheduledDeparture: String = "", scheduledArrival: String = "",
         counterEntries: [Int: String] = [:], createdAt: Date? = nil) {
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
        self.spInsTime = FlightSector.validateTimeString(spInsTime)
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
        self.counterEntries = counterEntries
        self.createdAt = createdAt
        self.parsedDate = FlightSector.cachedDateFormatter.date(from: date)

        // MARK: - Development validation
        #if DEBUG
        if let blockVal = Double(self.blockTime), blockVal > 0,
           let simVal = Double(self.simTime), simVal > 0,
           self.flightNumber != "SUMMARY" {  // Exclude Summary Rows (legitimate dual-field entries)
            print(" FlightSector created with BOTH blockTime and simTime > 0: date=\(date), flight=\(flightNumber), block=\(self.blockTime), sim=\(self.simTime)")
        }
        #endif
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(String.self, forKey: .date)
        flightNumber = try c.decode(String.self, forKey: .flightNumber)
        aircraftReg = try c.decode(String.self, forKey: .aircraftReg)
        aircraftType = try c.decode(String.self, forKey: .aircraftType)
        fromAirport = try c.decode(String.self, forKey: .fromAirport)
        toAirport = try c.decode(String.self, forKey: .toAirport)
        captainName = try c.decode(String.self, forKey: .captainName)
        foName = try c.decode(String.self, forKey: .foName)
        so1Name = try c.decodeIfPresent(String.self, forKey: .so1Name)
        so2Name = try c.decodeIfPresent(String.self, forKey: .so2Name)
        blockTime = try c.decode(String.self, forKey: .blockTime)
        nightTime = try c.decode(String.self, forKey: .nightTime)
        p1Time = try c.decode(String.self, forKey: .p1Time)
        p1usTime = try c.decode(String.self, forKey: .p1usTime)
        p2Time = try c.decode(String.self, forKey: .p2Time)
        instrumentTime = try c.decode(String.self, forKey: .instrumentTime)
        simTime = try c.decode(String.self, forKey: .simTime)
        spInsTime = try c.decode(String.self, forKey: .spInsTime)
        isPilotFlying = try c.decode(Bool.self, forKey: .isPilotFlying)
        isPositioning = try c.decode(Bool.self, forKey: .isPositioning)
        isAIII = try c.decode(Bool.self, forKey: .isAIII)
        isRNP = try c.decode(Bool.self, forKey: .isRNP)
        isILS = try c.decode(Bool.self, forKey: .isILS)
        isGLS = try c.decode(Bool.self, forKey: .isGLS)
        isNPA = try c.decode(Bool.self, forKey: .isNPA)
        remarks = try c.decode(String.self, forKey: .remarks)
        dayTakeoffs = try c.decode(Int.self, forKey: .dayTakeoffs)
        dayLandings = try c.decode(Int.self, forKey: .dayLandings)
        nightTakeoffs = try c.decode(Int.self, forKey: .nightTakeoffs)
        nightLandings = try c.decode(Int.self, forKey: .nightLandings)
        outTime = try c.decode(String.self, forKey: .outTime)
        inTime = try c.decode(String.self, forKey: .inTime)
        scheduledDeparture = try c.decode(String.self, forKey: .scheduledDeparture)
        scheduledArrival = try c.decode(String.self, forKey: .scheduledArrival)
        counterEntries = (try? c.decodeIfPresent([Int: String].self, forKey: .counterEntries)) ?? [:]
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        parsedDate = FlightSector.cachedDateFormatter.date(from: date)
    }

    // MARK: - Safe Numeric Conversion Methods
    /// Safely convert string to Double, returning 0.0 for invalid values
    private nonisolated func safeDoubleValue(_ string: String) -> Double {
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
    public nonisolated var blockTimeValue: Double { safeDoubleValue(blockTime) }
    public nonisolated var nightTimeValue: Double { safeDoubleValue(nightTime) }
    public nonisolated var p1TimeValue: Double { safeDoubleValue(p1Time) }
    public nonisolated var p1usTimeValue: Double { safeDoubleValue(p1usTime) }
    public nonisolated var p2TimeValue: Double { safeDoubleValue(p2Time) }
    public nonisolated var instrumentTimeValue: Double { safeDoubleValue(instrumentTime) }
    public nonisolated var simTimeValue: Double { safeDoubleValue(simTime) }
    public nonisolated var spInsTimeValue: Double { safeDoubleValue(spInsTime) }

    public nonisolated var isSpInsOnly: Bool {
        spInsTimeValue > 0 && blockTimeValue < 0.01
    }

    public nonisolated var isAircraftInstruction: Bool {
        spInsTimeValue > 0 && blockTimeValue > 0
    }

    // MARK: - Computed properties for display with validation
    public var formattedDate: String {
        if let date = Self.cachedDateFormatter.date(from: date) {
            return Self.cachedMonthYearFormatter.string(from: date).uppercased()
        }
        return date
    }

    public var dayOfMonth: String {
        let components = date.split(separator: "/")
        return components.first.map(String.init) ?? ""
    }

    /// Get local date based on departure airport timezone
    /// - Parameter useLocalTime: Whether to convert to local time
    /// - Returns: Date string in "dd/MM/yyyy" format
    public func getDisplayDate(useLocalTime: Bool) -> String {
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
    public func getFormattedDate(useLocalTime: Bool) -> String {
        let displayDate = getDisplayDate(useLocalTime: useLocalTime)
        if let date = Self.cachedDateFormatter.date(from: displayDate) {
            return Self.cachedMonthYearFormatter.string(from: date).uppercased()
        }
        return displayDate
    }

    /// Get day of month based on local/UTC setting
    public func getDayOfMonth(useLocalTime: Bool) -> String {
        let displayDate = getDisplayDate(useLocalTime: useLocalTime)
        let components = displayDate.split(separator: "/")
        return components.first.map(String.init) ?? ""
    }

    /// Get out time in local timezone of departure airport
    /// - Parameter useLocalTime: Whether to convert to local time
    /// - Returns: Time string in "HHMM" format (without colon)
    public func getOutTime(useLocalTime: Bool) -> String {
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
    public func getInTime(useLocalTime: Bool) -> String {
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

    public func getSTD(useLocalTime: Bool) -> String {
        guard !scheduledDeparture.isEmpty else { return "" }
        if useLocalTime {
            return AirportService.shared.convertToLocalTime(
                utcDateString: date,
                utcTimeString: scheduledDeparture,
                airportICAO: fromAirport
            ).replacingOccurrences(of: ":", with: "")
        }
        return scheduledDeparture.replacingOccurrences(of: ":", with: "")
    }

    public func getSTA(useLocalTime: Bool) -> String {
        guard !scheduledArrival.isEmpty else { return "" }
        if useLocalTime {
            return AirportService.shared.convertToLocalTime(
                utcDateString: date,
                utcTimeString: scheduledArrival,
                airportICAO: toAirport
            ).replacingOccurrences(of: ":", with: "")
        }
        return scheduledArrival.replacingOccurrences(of: ":", with: "")
    }

    public var blockTimeFormatted: String {
        let value = blockTimeValue
        return value > 0 ? String(format: "%.1f hrs", value) : "0.0 hrs"
    }

    // MARK: - Time Conversion Utilities

    /// Convert decimal hours to HH:MM format
    /// - Parameter decimalHours: Time in decimal hours (e.g., 13.67)
    /// - Returns: Time in HH:MM format (e.g., "13:40")
    public static func decimalToHHMM(_ decimalHours: Double) -> String {
        guard decimalHours > 0 else { return "0:00" }

        let totalMinutes = Int(round(decimalHours * 60.0))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        return String(format: "%d:%02d", hours, minutes)
    }

    /// Convert HH:MM format to decimal hours
    /// - Parameter hhmmString: Time in HH:MM format (e.g., "13:40")
    /// - Returns: Time in decimal hours (e.g., 13.67)
    public nonisolated static func hhmmToDecimal(_ hhmmString: String) -> Double? {
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
    public func formatTimeAsHoursMinutes(_ decimalHours: Double) -> String {
        return FlightSector.decimalToHHMM(decimalHours)
    }

    /// Get formatted block time (either decimal or HH:MM based on setting)
    public func getFormattedBlockTime(asHoursMinutes: Bool, roundingMode: RoundingMode = .standard) -> String {
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
    public func getFormattedNightTime(asHoursMinutes: Bool, roundingMode: RoundingMode = .standard) -> String {
        let value = nightTimeValue
        guard value > 0 else { return asHoursMinutes ? "0:00" : "0.0 hrs" }

        if asHoursMinutes {
            return FlightSector.decimalToHHMM(value)
        } else {
            let rounded = roundingMode.apply(to: value, decimalPlaces: 1)
            return String(format: "%.1f hrs", rounded)
        }
    }

    /// Get formatted Sp/Ins time (either decimal or HH:MM based on setting)
    public func getFormattedSpInsTime(asHoursMinutes: Bool) -> String {
        let value = spInsTimeValue
        guard value > 0 else { return asHoursMinutes ? "0:00" : "0.0 hrs" }

        if asHoursMinutes {
            return FlightSector.decimalToHHMM(value)
        } else {
            return String(format: "%.1f hrs", value)
        }
    }

    /// Get formatted sim time (either decimal or HH:MM based on setting)
    public func getFormattedSimTime(asHoursMinutes: Bool) -> String {
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
    public static func formatTime(_ decimalValue: Double, asHoursMinutes: Bool, includeUnits: Bool = false) -> String {
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

    public var flightNumberFormatted: String {
        // For simulator flights, don't modify the flight number (preserve leading zeros, custom formats like SIM06B, etc.)
        if simTimeValue > 0 {
            return flightNumber
        }
        // For regular flights, remove leading zero if present
        return flightNumber.hasPrefix("0") ? String(flightNumber.dropFirst()) : flightNumber
    }
    /// Get validated formatted times for display
    /// - Parameter roundingMode: Rounding mode to apply to block and night times
    public func safeFormattedTimes(roundingMode: RoundingMode = .standard) -> (block: String, night: String, p1: String, p1us: String, p2: String) {
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
public extension FlightSector {
    /// Create a FlightSector from ACARS capture data with validation
    public static func fromACARSCapture(
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

public extension FlightSector {
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

        let dateString = cachedUTCDateFormatter.string(from: date)

        var counterEntries: [Int: String] = [:]
        for index in 1...10 {
            if let value = entity.counterValue(at: index), !value.isEmpty {
                counterEntries[index] = value
            }
        }

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
            spInsTime: entity.spInsTime ?? "",
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
            scheduledArrival: entity.scheduledArrival ?? "",
            counterEntries: counterEntries
        )
    }
}

