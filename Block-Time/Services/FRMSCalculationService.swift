//
//  FRMSCalculationService.swift
//  Block-Time
//
//  FRMS Calculation Engine
//  Implements Qantas FRMS Ruleset calculations for flight and duty time limitations
//

import Foundation

class FRMSCalculationService {

    // MARK: - Properties

    private let configuration: FRMSConfiguration

    // Cached date formatters to avoid expensive recreation
    private static let cachedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    private static let cachedTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HHmm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    // MARK: - Initialization

    init(configuration: FRMSConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Local Time Zone Helper

    /// Get the timezone for the crew's home base
    /// Uses AirportService to look up timezone from airports.dat.txt database
    func getHomeBaseTimeZone() -> TimeZone {
        // Convert to ICAO code (handles both IATA and ICAO inputs)
        let icaoCode = AirportService.shared.convertToICAO(configuration.homeBase)

        // Get timezone offset from AirportService
        if let offsetHours = AirportService.shared.getTimezoneOffset(for: icaoCode) {
            let offsetSeconds = Int(offsetHours * 3600)
            return TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone(secondsFromGMT: 10 * 3600)!
        }

        // Fallback to Sydney time if airport not found
        return TimeZone(identifier: "Australia/Sydney") ?? TimeZone(secondsFromGMT: 10 * 3600)!
    }

    /// Convert a UTC date to local time at home base
    /// Uses AirportService to get timezone offset including DST handling
    private func convertToLocalTime(_ utcDate: Date) -> Date {
        // Convert to ICAO code (handles both IATA and ICAO inputs)
        let icaoCode = AirportService.shared.convertToICAO(configuration.homeBase)

        // Get timezone offset from AirportService
        guard let offsetHours = AirportService.shared.getTimezoneOffset(for: icaoCode) else {
            // Fallback: use Sydney timezone
            let sydneyTimeZone = TimeZone(identifier: "Australia/Sydney") ?? TimeZone(secondsFromGMT: 10 * 3600)!
            let utcOffset = TimeZone(secondsFromGMT: 0)!.secondsFromGMT(for: utcDate)
            let localOffset = sydneyTimeZone.secondsFromGMT(for: utcDate)
            let offsetDifference = localOffset - utcOffset
            return utcDate.addingTimeInterval(TimeInterval(offsetDifference))
        }

        // Apply the offset to get local time
        let offsetSeconds = offsetHours * 3600
        return utcDate.addingTimeInterval(offsetSeconds)
    }

    // MARK: - Crew Complement Detection

    /// Infer crew complement from filled crew names
    func inferCrewComplement(captainName: String?,
                            foName: String?,
                            so1Name: String?,
                            so2Name: String?) -> CrewComplement {

        var count = 0
        if captainName?.isEmpty == false { count += 1 }
        if foName?.isEmpty == false { count += 1 }
        if so1Name?.isEmpty == false { count += 1 }
        if so2Name?.isEmpty == false { count += 1 }

        // Default to 2 if no names filled or only 1
        if count <= 2 { return .twoPilot }
        if count == 3 { return .threePilot }
        return .fourPilot
    }

    // MARK: - Sign-On/Sign-Off Calculation

    /// Calculate sign-on time using configured minutes before STD (or OUT if STD not available)
    /// - Parameters:
    ///   - stdTime: Scheduled Time of Departure (if available)
    ///   - outTime: Actual departure time (fallback if STD not available)
    ///   - isFirstFlightOfDay: Whether this is the first flight of the duty day
    ///   - isPositioning: Whether this is a positioning (PAX) flight
    ///   - fromAirport: Departure airport code (ICAO or IATA)
    ///   - toAirport: Arrival airport code (ICAO or IATA)
    /// - Returns: Sign-on time
    func calculateSignOn(stdTime: Date?, outTime: Date, isFirstFlightOfDay: Bool = false, isPositioning: Bool = false, fromAirport: String? = nil, toAirport: String? = nil) -> Date {
        // Use STD (Scheduled Time of Departure) for sign-on calculation when available
        // Only fall back to OUT (actual departure) if STD is not available
        let departureTime: Date
        if let std = stdTime {
            departureTime = std  // Always use STD when available
        } else {
            departureTime = outTime  // No STD available, use OUT
        }
        var minutesBefore = configuration.signOnMinutesBeforeSTD

        // Special case: First flight of the day that is a positioning flight between two Australian ports
        // uses 30 minutes instead of 60 minutes (e.g., YSSY-YBBN = 30 min, but YSSY-NZAA = 60 min)
        if isFirstFlightOfDay && isPositioning, let from = fromAirport, let to = toAirport {
            if AirportService.shared.isAustralianAirport(from) && AirportService.shared.isAustralianAirport(to) {
                minutesBefore = 30
            }
        }

        return Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: departureTime) ?? departureTime
    }

    /// Calculate sign-off time using configured minutes after actual IN
    /// - Parameters:
    ///   - inTime: Actual arrival time
    /// - Returns: Sign-off time
    func calculateSignOff(inTime: Date) -> Date {
        let minutesAfter = configuration.signOffMinutesAfterIN
        let signOffTime = Calendar.current.date(byAdding: .minute, value: minutesAfter, to: inTime) ?? inTime
        return signOffTime
    }

    // MARK: - Cumulative Totals Calculation

    /// Calculate cumulative totals from a list of duties and flights
    /// - Parameters:
    ///   - duties: Consolidated duties (used for duty time calculations based on sign-on date)
    ///   - flights: Individual flight sectors (used for flight time calculations based on flight date)
    ///   - date: The reference date for calculating periods (defaults to now)
    /// - Returns: Cumulative totals including flight times and duty times
    func calculateCumulativeTotals(duties: [FRMSDuty], flights: [FlightSector]? = nil, asOf date: Date = Date()) -> FRMSCumulativeTotals {

        // Use home base timezone for user-facing date ranges (consistent with Dashboard and FlightsView)
        let homeTimeZone = getHomeBaseTimeZone()
        var calendar = Calendar.current
        calendar.timeZone = homeTimeZone

        // Calculate range: all of today back to N days ago (inclusive)
        // e.g., Last 28 Days = today back to 27 days ago (28 days total including today)
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        let startOfToday = calendar.startOfDay(for: date)

        // Calculate start dates (all inclusive of the full day range)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -13, to: startOfToday) ?? startOfToday

        // Use fleet-specific period (28 days for 737, 30 days for A380/A330/B787)
        let flightTimePeriodDays = configuration.fleet.flightTimePeriodDays
        let flightTimePeriodAgo = calendar.date(byAdding: .day, value: -(flightTimePeriodDays - 1), to: startOfToday) ?? startOfToday

        let threeSixtyFiveDaysAgo = calendar.date(byAdding: .day, value: -364, to: startOfToday) ?? startOfToday

        // Filter duties in each period for DUTY TIME calculations
        // Duties are filtered by their date (which is based on sign-on time)
        let duties7Days = duties.filter {
            $0.date >= sevenDaysAgo && $0.date <= endOfToday
        }
        let duties14Days = duties.filter {
            $0.date >= fourteenDaysAgo && $0.date <= endOfToday
        }
        let dutiesFlightTimePeriod = duties.filter {
            $0.date >= flightTimePeriodAgo && $0.date <= endOfToday
        }
        let duties365Days = duties.filter {
            $0.date >= threeSixtyFiveDaysAgo && $0.date <= endOfToday
        }

        // Calculate FLIGHT TIME totals from individual flights (if provided)
        // This ensures flight times are counted by flight date, not duty date
        let flightTime7Days: Double
        let flightTime28Or30Days: Double
        let flightTime365Days: Double

        if let flights = flights {
            // Filter flights by their actual flight date (dd/MM/yyyy string from database)
            // Database stores dates as UTC, so we need to parse and compare in home base timezone
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            dateFormatter.timeZone = homeTimeZone  // Use home base timezone for consistency

            // Convert date range to string format for comparison
            let flights7Days = flights.filter {
                guard let flightDate = dateFormatter.date(from: $0.date) else { return false }
                return flightDate >= sevenDaysAgo && flightDate <= endOfToday
            }
            let flightsFlightTimePeriod = flights.filter {
                guard let flightDate = dateFormatter.date(from: $0.date) else { return false }
                return flightDate >= flightTimePeriodAgo && flightDate <= endOfToday
            }
            let flights365Days = flights.filter {
                guard let flightDate = dateFormatter.date(from: $0.date) else { return false }
                return flightDate >= threeSixtyFiveDaysAgo && flightDate <= endOfToday
            }

            // Sum flight times from individual flights
            flightTime7Days = flights7Days.reduce(0.0) { $0 + ($1.blockTimeValue > 0 ? $1.blockTimeValue : $1.simTimeValue) }
            flightTime28Or30Days = flightsFlightTimePeriod.reduce(0.0) { $0 + ($1.blockTimeValue > 0 ? $1.blockTimeValue : $1.simTimeValue) }
            flightTime365Days = flights365Days.reduce(0.0) { $0 + ($1.blockTimeValue > 0 ? $1.blockTimeValue : $1.simTimeValue) }

        } else {
            // Fallback to duty-based calculation if flights not provided (for backward compatibility)
            flightTime7Days = duties7Days.reduce(0.0) { $0 + $1.flightTime }
            flightTime28Or30Days = dutiesFlightTimePeriod.reduce(0.0) { $0 + $1.flightTime }
            flightTime365Days = duties365Days.reduce(0.0) { $0 + $1.flightTime }
        }

        // Calculate duty time totals
        let dutyTime7Days = duties7Days.reduce(0.0) { $0 + $1.dutyTime }
        let dutyTime14Days = duties14Days.reduce(0.0) { $0 + $1.dutyTime }

        // Count days off in the flight time period using home base timezone dates
        // (counts unique local calendar days with duty)
        let daysWithDuty = Set(dutiesFlightTimePeriod.map { calendar.startOfDay(for: $0.signOn) })
        let daysOff28Or30Days = flightTimePeriodDays - daysWithDuty.count

        // Count consecutive duties, early starts, late nights
        let sortedDuties = duties.sorted { $0.date < $1.date }
        let (consecutiveDuties, consecutiveEarlyStarts, consecutiveLateNights) = calculateConsecutiveInfo(duties: sortedDuties, asOf: date)

        // Calculate duty days in rolling 11-day period (FD12.2a) using home base timezone
        // Include all of today back to 10 days ago (11 days total including today)
        let elevenDaysAgo = calendar.date(byAdding: .day, value: -10, to: startOfToday) ?? startOfToday
        let duties11Days = duties.filter {
            let dutyLocalDate = calendar.startOfDay(for: $0.signOn)
            return dutyLocalDate >= elevenDaysAgo && dutyLocalDate <= endOfToday
        }
        let dutyDaysIn11Days = Set(duties11Days.map { calendar.startOfDay(for: $0.signOn) }).count

        return FRMSCumulativeTotals(
            flightTime7Days: flightTime7Days,
            flightTime28Or30Days: flightTime28Or30Days,
            flightTime365Days: flightTime365Days,
            dutyTime7Days: dutyTime7Days,
            dutyTime14Days: dutyTime14Days,
            daysOff28Days: daysOff28Or30Days,
            consecutiveDuties: consecutiveDuties,
            consecutiveEarlyStarts: consecutiveEarlyStarts,
            consecutiveLateNights: consecutiveLateNights,
            dutyDaysIn11Days: dutyDaysIn11Days,
            fleet: configuration.fleet
        )
    }

    // MARK: - Consecutive Info Helper

    private func calculateConsecutiveInfo(duties: [FRMSDuty], asOf date: Date) -> (consecutive: Int, earlyStarts: Int, lateNights: Int) {
        guard !duties.isEmpty else { return (0, 0, 0) }

        // Get home base timezone - use LOCAL dates for consecutive duty counting
        let homeTimeZone = getHomeBaseTimeZone()
        var localCalendar = Calendar.current
        localCalendar.timeZone = homeTimeZone

        // Get the reference date (today) in local timezone
        let todayLocal = localCalendar.startOfDay(for: date)

        // Get the most recent duty date
        guard let mostRecentDuty = duties.last else { return (0, 0, 0) }
        let mostRecentDutyDate = localCalendar.startOfDay(for: mostRecentDuty.signOn)

        // Check if there's a gap between today and the most recent duty
        // If the most recent duty was more than 1 day ago, consecutive count should be 0
        let daysSinceLastDuty = localCalendar.dateComponents([.day], from: mostRecentDutyDate, to: todayLocal).day ?? 0
        if daysSinceLastDuty > 1 {
            return (0, 0, 0)
        }

        // Start from the most recent duty date
        var currentDate = mostRecentDutyDate

        // Track unique consecutive days (not individual duties)
        var consecutiveDays = Set<Date>()

        // Track day characteristics for early starts and late nights
        var dayHasEarlyStart: [Date: Bool] = [:]
        var dayHasLateNight: [Date: Bool] = [:]

        // First pass: collect all duties and their day characteristics
        for duty in duties.reversed() {
            let dutyLocalDate = localCalendar.startOfDay(for: duty.signOn)

            // Check if this duty is consecutive (same day or previous day in LOCAL TIME)
            if dutyLocalDate == currentDate || dutyLocalDate == localCalendar.date(byAdding: .day, value: -1, to: currentDate) {
                // Add this day to the set of consecutive days
                consecutiveDays.insert(dutyLocalDate)

                // Check for early start (sign-on before 0700 LOCAL TIME)
                let signOnHour = localCalendar.component(.hour, from: duty.signOn)
                if signOnHour < 7 {
                    dayHasEarlyStart[dutyLocalDate] = true
                }

                // Check for late night operation
                if duty.timeClass == .lateNight || duty.timeClass == .backOfClock {
                    dayHasLateNight[dutyLocalDate] = true
                }

                currentDate = dutyLocalDate
            } else {
                // Gap in duties, stop counting
                break
            }
        }

        // Second pass: count consecutive early starts and late nights from the collected days
        var consecutiveEarlyStarts = 0
        var consecutiveLateNights = 0

        // Sort days in descending order (most recent first)
        let sortedDays = consecutiveDays.sorted(by: >)

        for day in sortedDays {
            // Check consecutive early starts
            if dayHasEarlyStart[day] == true {
                consecutiveEarlyStarts += 1
            } else {
                break  // Stop counting if this day doesn't have early start
            }
        }

        for day in sortedDays {
            // Check consecutive late nights
            if dayHasLateNight[day] == true {
                consecutiveLateNights += 1
            } else {
                break  // Stop counting if this day doesn't have late night
            }
        }

        return (consecutiveDays.count, consecutiveEarlyStarts, consecutiveLateNights)
    }

    // MARK: - Maximum Next Duty Calculation

    /// Calculate maximum allowable next duty based on current state and previous duty
    func calculateMaximumNextDuty(previousDuty: FRMSDuty?,
                                  cumulativeTotals: FRMSCumulativeTotals,
                                  limitType: FRMSLimitType,
                                  proposedCrewComplement: CrewComplement,
                                  proposedRestFacility: RestFacilityClass = .none) -> FRMSMaximumNextDuty {

        var restrictions: [String] = []
        var maxDutyPeriod: Double = 12.0
        var maxFlightTime: Double = 10.5
        var maxSectors: Int = 4
        var minimumRest: Double = 12.0
        var earliestSignOn: Date? = nil

        // Get base limits for crew complement
        let baseLimits = getBaseLimits(crewComplement: proposedCrewComplement,
                                      restFacility: proposedRestFacility,
                                      limitType: limitType)

        maxDutyPeriod = baseLimits.maxDuty
        maxFlightTime = baseLimits.maxFlight
        maxSectors = baseLimits.maxSectors

        // Calculate minimum rest based on previous duty
        if let prevDuty = previousDuty {
            minimumRest = calculateMinimumRest(afterDuty: prevDuty, limitType: limitType)

            // Calculate earliest sign-on using standard rounding for minutes
            let restMinutes = Int(round(minimumRest * 60))
            earliestSignOn = Calendar.current.date(byAdding: .minute, value: restMinutes, to: prevDuty.signOff)

            // Apply restrictions based on previous duty characteristics
            if prevDuty.dutyTime > 12 {
                restrictions.append("Previous duty exceeded 12 hours")
            }

            // Back-of-clock early sign-on restriction (applies to both fleets)
            if prevDuty.timeClass == .backOfClock {
                // For back-of-clock, next duty in Australia can't start before 1000
                if let proposedSignOn = earliestSignOn {
                    let calendar = Calendar.current
                    var components = calendar.dateComponents([.year, .month, .day], from: proposedSignOn)
                    components.hour = 10
                    components.minute = 0
                    if let tenAM = calendar.date(from: components), proposedSignOn < tenAM {
                        earliestSignOn = tenAM
                    }
                }
            }

            // Fleet-specific consecutive duty restrictions (A320/B737 only)
            if configuration.fleet == .a320B737 {
                // Consecutive duty days restriction (max 6) - FD12.2b
                if cumulativeTotals.consecutiveDuties >= 6 {
                    restrictions.append("Maximum 6 consecutive duty days reached")
                }

                // Duty days in 11-day period restriction (max 9) - FD12.2a
                if cumulativeTotals.dutyDaysIn11Days >= 9 {
                    restrictions.append("Maximum 9 duty days in 11-day period reached")
                }

                // Consecutive early starts restriction (max 4)
                if cumulativeTotals.consecutiveEarlyStarts >= 4 {
                    restrictions.append("Maximum 4 consecutive early starts reached")
                }

                // Consecutive late nights restriction (max 4 in 7 days, or 5 once per 28 days)
                if cumulativeTotals.consecutiveLateNights >= 4 {
                    restrictions.append("Late night operations limit approaching")
                }
            }

            // A380/A330/B787 specific restrictions
            if configuration.fleet == .a380A330B787 {
                // Back of clock restriction for widebody
                if prevDuty.timeClass == .backOfClock {
                    restrictions.append("Back-of-clock operation: next duty in Australia limited to after 1000LT")
                }
            }
        }

        // Apply cumulative limit restrictions (fleet-specific)
        let remainingFlightTime28Or30Days = configuration.fleet.maxFlightTime28Days - cumulativeTotals.flightTime28Or30Days
        let remainingDutyTime7Days = configuration.fleet.maxDutyTime7Days - cumulativeTotals.dutyTime7Days
        let remainingDutyTime14Days = configuration.fleet.maxDutyTime14Days - cumulativeTotals.dutyTime14Days

        // For widebody, also check 7-day flight time limit
        var constraintsForFlight: [Double] = [remainingFlightTime28Or30Days]
        if let flightLimit7Days = configuration.fleet.maxFlightTime7Days {
            let remainingFlightTime7Days = flightLimit7Days - cumulativeTotals.flightTime7Days
            constraintsForFlight.append(remainingFlightTime7Days)

            if remainingFlightTime7Days < 10 {
                restrictions.append("Limited by 7-day flight time limit")
            }
        }

        // Constrain by remaining limits
        maxFlightTime = min(maxFlightTime, constraintsForFlight.min() ?? maxFlightTime)
        maxDutyPeriod = min(maxDutyPeriod, remainingDutyTime7Days, remainingDutyTime14Days)

        let periodDays = configuration.fleet.flightTimePeriodDays
        if remainingFlightTime28Or30Days < 20 {
            restrictions.append("Limited by \(periodDays)-day flight time limit")
        }

        if remainingDutyTime7Days < 20 {
            restrictions.append("Limited by 7-day duty time limit")
        }

        // Ensure no negative values
        maxDutyPeriod = max(0, maxDutyPeriod)
        maxFlightTime = max(0, maxFlightTime)

        // Get sign-on based limits for A380/A330/B787 fleet
        var signOnBasedLimits: [SignOnTimeRange]? = nil
        if configuration.fleet == .a380A330B787 {
            switch proposedCrewComplement {
            case .twoPilot:
                signOnBasedLimits = getSignOnBasedLimits2PilotA380A330B787(limitType: limitType)
            case .threePilot:
                signOnBasedLimits = getSignOnBasedLimits3PilotA380A330B787(restFacility: proposedRestFacility, limitType: limitType)
            case .fourPilot:
                signOnBasedLimits = getSignOnBasedLimits4PilotA380A330B787(restFacility: proposedRestFacility, limitType: limitType)
            }
        }

        return FRMSMaximumNextDuty(
            maxDutyPeriod: maxDutyPeriod,
            maxFlightTime: maxFlightTime,
            maxSectors: maxSectors,
            minimumRest: minimumRest,
            earliestSignOn: earliestSignOn,
            restrictions: restrictions,
            limitType: limitType,
            signOnBasedLimits: signOnBasedLimits,
            mbtt: nil  // MBTT will be calculated separately based on trip parameters
        )
    }

    // MARK: - MBTT Calculation (A380/A330/B787)

    /// Calculate Minimum Base Turnaround Time based on trip pattern
    /// - Parameters:
    ///   - daysAway: Number of days away from base on the trip
    ///   - creditedFlightHours: Total credited flight hours for the trip pattern
    ///   - hadPlannedDutyOver18Hours: Whether the trip pattern contained a planned duty >18 hours
    /// - Returns: MBTT requirements or nil if not applicable
    func calculateMBTT(daysAway: Int, creditedFlightHours: Double, hadPlannedDutyOver18Hours: Bool = false) -> FRMSMinimumBaseTurnaroundTime? {
        // Only applicable to widebody fleet
        guard configuration.fleet == .a380A330B787 else { return nil }

        var localNights = 1
        var minHours: Double? = nil
        var reason = ""
        var reasons: [String] = []

        // Base MBTT rules by days away
        if daysAway == 1 {
            minHours = 12.0
            localNights = 0
            reasons.append("1 day away: 12 hours")
        } else if daysAway >= 2 && daysAway <= 4 {
            localNights = 1
            reasons.append("\(daysAway) days away: 1 local night")
        } else if daysAway >= 5 && daysAway <= 8 {
            localNights = 2
            reasons.append("\(daysAway) days away: 2 local nights")
        } else if daysAway >= 9 && daysAway <= 12 {
            localNights = 3
            reasons.append("\(daysAway) days away: 3 local nights")
        } else if daysAway > 12 {
            localNights = 4
            reasons.append(">\(daysAway) days away: 4 local nights")
        }

        // Additional nights based on credited flight hours
        if creditedFlightHours > 60 {
            localNights = max(localNights, 4)
            reasons.append(">60 credited flight hours: 4 local nights")
            minHours = nil  // Override hours with nights
        } else if creditedFlightHours > 40 {
            localNights = max(localNights, 3)
            reasons.append(">40 credited flight hours: 3 local nights")
            minHours = nil
        } else if creditedFlightHours > 20 {
            localNights = max(localNights, 2)
            reasons.append(">20 credited flight hours: 2 local nights")
            minHours = nil
        }

        // Additional night if pattern contained planned duty >18 hours
        if hadPlannedDutyOver18Hours {
            localNights += 1
            reasons.append("Planned duty >18 hours: +1 local night")
            minHours = nil
        }

        // Use the most restrictive requirement
        reason = reasons.joined(separator: " • ")

        return FRMSMinimumBaseTurnaroundTime(
            daysAway: daysAway,
            creditedFlightHours: creditedFlightHours,
            localNightsRequired: localNights,
            minHours: minHours,
            reason: reason
        )
    }

    // MARK: - Base Limits Lookup

    private func getBaseLimits(crewComplement: CrewComplement,
                              restFacility: RestFacilityClass,
                              limitType: FRMSLimitType) -> (maxDuty: Double, maxFlight: Double, maxSectors: Int) {

        // Return fleet-specific limits
        switch configuration.fleet {
        case .a320B737:
            return getBaseLimitsA320B737(crewComplement: crewComplement, restFacility: restFacility, limitType: limitType)
        case .a380A330B787:
            return getBaseLimitsA380A330B787(crewComplement: crewComplement, restFacility: restFacility, limitType: limitType)
        }
    }

    // MARK: - A380/A330/B787 Sign-On Time Based Limits (2-Pilot)

    /// Get all sign-on time based limits for 2-pilot A380/A330/B787 operations.
    /// Operational (FD10): ALL sign-on times, single row.
    /// Planning (FD3): One row per sign-on window from LH_Planning_FltDuty.
    private func getSignOnBasedLimits2PilotA380A330B787(limitType: FRMSLimitType) -> [SignOnTimeRange] {

        if limitType == .operational {
            // FD10.1 — ALL sign-on times, duty 11/12 hrs.
            // Flight time: 9.5 (>7 hrs darkness), 10.0 (>1 sector), 10.5 (standard).
            // Pre-duty rest: 10 hrs (duty ≤11), 12 hrs (duty >11).
            // Post-duty rest: 10 hrs (duty ≤11); formula if extended; 24 hrs if extreme extension.
            return [
                SignOnTimeRange(
                    timeRange: "All sign-on times",
                    maxDutyPeriod: 11.0,
                    maxDutyPeriodOperational: 12.0,
                    maxFlightTime: 10.5,
                    maxFlightTimeOperational: 10.5,
                    preRestRequired: 10.0,
                    postRestRequired: 10.0,
                    notes: "Max Flight Time: 10.5 hrs\n9.5hrs if  > 7 hrs darkness\n10 hrs if >1 sector",
                    sectorLimit: nil,
                    restFacility: nil
                )
            ]
        } else {
            // FD3.1 — One row per sign-on window (5 rows including both 0800-1359 variants).
            // Pre/post rest: 11 hrs (if FT < 8), 22 hrs otherwise.
            return LH_Planning_FltDuty.twoPilotLimits.map { limit in
                let isDayPattern = limit.sectorLimit.contains("DAY PATTERN")
                return SignOnTimeRange(
                    timeRange: limit.signOnWindow.rawValue,
                    maxDutyPeriod: limit.dutyPeriodLimit,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: limit.flightTimeLimit,
                    maxFlightTimeOperational: nil,
                    preRestRequired: limit.flightTimeLimit < 8.5 ? 11.0 : 22.0,
                    postRestRequired: limit.flightTimeLimit < 8.5 ? 11.0 : 22.0,
                    notes: isDayPattern ? "Day Pattern Only" : nil,
                    sectorLimit: limit.sectorLimit,
                    restFacility: nil
                )
            }
        }
    }

    /// Get all sign-on time based limits for 3-pilot A380/A330/B787 operations.
    /// Returns ALL rest facility options so the view can display the complete table.
    /// Operational (FD10): Seat in Pax, Class 2, Class 1.
    /// Planning (FD3): Class 2, Class 1.
    private func getSignOnBasedLimits3PilotA380A330B787(restFacility: RestFacilityClass, limitType: FRMSLimitType) -> [SignOnTimeRange] {

        if limitType == .operational {
            // FD10.1 — Pre-duty rest: 10 or 12 hrs. Post-duty rest: 12 (≤16 hrs), 24 (>16 hrs).
            return [
                SignOnTimeRange(
                    timeRange: "Seat in Passenger Compartment",
                    maxDutyPeriod: 14.0,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: 8.0,
                    maxFlightTimeOperational: nil,
                    preRestRequired: 12.0,
                    postRestRequired: 12.0,
                    notes: "8 consecutive hrs of active duty in flight deck",
                    sectorLimit: nil,
                    restFacility: .seatInPassengerCompartment
                ),
                SignOnTimeRange(
                    timeRange: "Class 2 Rest",
                    maxDutyPeriod: 16.0,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: 14.0,
                    maxFlightTimeOperational: nil,
                    preRestRequired: 12.0,
                    postRestRequired: 12.0,
                    notes: "Max 8 hrs continuous & 14 hrs total on flight deck",
                    sectorLimit: "Max 2 sectors if Scheduled Duty > 14 hrs",
                    restFacility: .class2
                ),
                SignOnTimeRange(
                    timeRange: "Class 1 Rest",
                    maxDutyPeriod: 18.0,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: 14.0,
                    maxFlightTimeOperational: nil,
                    preRestRequired: 12.0,
                    postRestRequired: 24.0,
                    notes: "Max 8 hrs continuous & 14 hrs total on flight deck",
                    sectorLimit: "Max 2 sectors if Scheduled Duty > 14 hrs",
                    restFacility: .class1
                ),
            ]
        } else {
            // FD3.1 Planning — Class 2 and Class 1 only.
            return LH_Planning_FltDuty.threePilotLimits.map { limit in
                let postRest = limit.flightTimeLimit < 9.0 ? 12.0 : 18.0
                return SignOnTimeRange(
                    timeRange: limit.restFacility.rawValue,
                    maxDutyPeriod: limit.dutyPeriodLimit,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: limit.flightTimeLimit,
                    maxFlightTimeOperational: nil,
                    preRestRequired: 12.0,
                    postRestRequired: postRest,
                    notes: "Max 8 hrs continuous & 14 hrs total on flight deck",
                    sectorLimit: limit.sectorLimit,
                    restFacility: limit.restFacility
                )
            }
        }
    }

    /// Get all sign-on time based limits for 4-pilot A380/A330/B787 operations.
    /// Returns ALL rest facility options so the view can display the complete table.
    /// Operational (FD10): Seat in Pax, 2×Class 2, Mixed, 2×Class 1, 2×Class 1 FD3.4.
    /// Planning (FD3): 2×Class 2, Mixed (1×C1+1×C2), 2×Class 1.
    private func getSignOnBasedLimits4PilotA380A330B787(restFacility: RestFacilityClass, limitType: FRMSLimitType) -> [SignOnTimeRange] {

        if limitType == .operational {
            // FD10.1 — Pre-duty rest: 10 or 12 hrs. Post-duty rest: 12 (≤16), 24 (>16).
            return [
                SignOnTimeRange(
                    timeRange: "Seats in Passenger Compartment",
                    maxDutyPeriod: 14.0,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: 8.0,
                    maxFlightTimeOperational: nil,
                    preRestRequired: 12.0,
                    postRestRequired: 12.0,
                    notes: "8 consecutive hrs of active duty in flight deck",
                    sectorLimit: nil,
                    restFacility: .seatInPassengerCompartment
                ),
                SignOnTimeRange(
                    timeRange: "2 × Class 2 Rest",
                    maxDutyPeriod: 16.0,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: 14.0,
                    maxFlightTimeOperational: nil,
                    preRestRequired: 12.0,
                    postRestRequired: 12.0,
                    notes: "Max 8 hrs continuous & 14 hrs total on flight deck",
                    sectorLimit: "Max 2 sectors if Scheduled Duty > 14 hrs",
                    restFacility: .twoClass2
                ),
                SignOnTimeRange(
                    timeRange: "1 × Class 1 & 1 × Class 2 Rest",
                    maxDutyPeriod: 20.0,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: 14.0,
                    maxFlightTimeOperational: nil,
                    preRestRequired: 12.0,
                    postRestRequired: 24.0,
                    notes: "Max 8 hrs continuous & 14 hrs total on flight deck. Priority higher class for landing crew.",
                    sectorLimit: "Max 2 sectors if Scheduled Duty > 14 hrs",
                    restFacility: .oneClass1OneClass2
                ),
                SignOnTimeRange(
                    timeRange: "2 × Class 1 Rest",
                    maxDutyPeriod: 20.0,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: 14.0,
                    maxFlightTimeOperational: nil,
                    preRestRequired: 12.0,
                    postRestRequired: 24.0,
                    notes: "Max 8 hrs continuous & 14 hrs total on flight deck",
                    sectorLimit: "Max 2 sectors if Scheduled Duty > 14 hrs",
                    restFacility: .twoClass1
                ),
                SignOnTimeRange(
                    timeRange: "2 × Class 1 Rest (>18 hrs — FD3.4)",
                    maxDutyPeriod: 21.0,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: 14.0,
                    maxFlightTimeOperational: nil,
                    preRestRequired: 22.0,
                    postRestRequired: 27.0,
                    notes: "A380 & B787 only. Relevant Sector disruption limits apply — see below.",
                    sectorLimit: nil,
                    restFacility: .twoClass1FD34
                ),
            ]
        } else {
            // FD3.1 Planning — 2×Class 2, Mixed, 2×Class 1.
            return LH_Planning_FltDuty.fourPilotLimits.map { limit in
                let preRest: Double = limit.dutyPeriodLimit <= 16.0 ? 12.0 : 22.0
                let postRest: Double = limit.dutyPeriodLimit <= 16.0 ? 12.0 : 22.0
                return SignOnTimeRange(
                    timeRange: limit.restFacility.rawValue,
                    maxDutyPeriod: limit.dutyPeriodLimit,
                    maxDutyPeriodOperational: nil,
                    maxFlightTime: 14.0,
                    maxFlightTimeOperational: nil,
                    preRestRequired: preRest,
                    postRestRequired: postRest,
                    notes: limit.flightTimeLimitNote,
                    sectorLimit: limit.sectorLimit,
                    restFacility: limit.restFacility
                )
            }
        }
    }

    // MARK: - A380/A330/B787 Duty and Flight Time Helpers

    /// Get LH duty limit from FD10.1 operational limits
    /// - Parameters:
    ///   - crewComplement: Crew complement
    ///   - restFacility: Rest facility class
    ///   - limitType: Planning or operational limits
    /// - Returns: Duty limit or nil if not found
    private func getLHDutyLimit(crewComplement: CrewComplement,
                                restFacility: RestFacilityClass,
                                limitType: FRMSLimitType) -> DutyLimit? {

        // Map CrewComplement to LH_CrewComplement
        let lhCrewComp: LH_CrewComplement
        switch crewComplement {
        case .twoPilot: lhCrewComp = .twoPilot
        case .threePilot: lhCrewComp = .threePilot
        case .fourPilot: lhCrewComp = .fourPilot
        }

        // Map RestFacilityClass to CrewRestFacility (context-aware based on crew complement)
        let lhRestFacility: CrewRestFacility?
        switch (crewComplement, restFacility) {
        // 2-pilot operations
        case (.twoPilot, _):
            lhRestFacility = nil  // All 2-pilot limits have nil rest facility

        // 3-pilot operations
        case (.threePilot, .none):
            lhRestFacility = .seatInPassengerCompartment
        case (.threePilot, .class1):
            lhRestFacility = .class1
        case (.threePilot, .class2):
            lhRestFacility = .class2
        case (.threePilot, .mixed):
            lhRestFacility = .class1  // Use class1 as fallback for 3-pilot mixed

        // 4-pilot operations
        case (.fourPilot, .none):
            lhRestFacility = .seatInPassengerCompartment
        case (.fourPilot, .class1):
            lhRestFacility = .twoClass1  // 4-pilot with class1 = 2× Class 1 Rest
        case (.fourPilot, .class2):
            lhRestFacility = .twoClass2  // 4-pilot with class2 = 2× Class 2 Rest
        case (.fourPilot, .mixed):
            lhRestFacility = .oneClass1OneClass2  // 1× Class 1 & 1× Class 2 Rest
        }

        // Get duty limits based on crew complement
        let limits: [DutyLimit]
        switch lhCrewComp {
        case .twoPilot: limits = LH_Operational_FltDuty.twoPilotLimits
        case .threePilot: limits = LH_Operational_FltDuty.threePilotLimits
        case .fourPilot: limits = LH_Operational_FltDuty.fourPilotLimits
        }

        // Find matching limits
        let matchingLimits = limits.filter { limit in
            limit.crewComplement == lhCrewComp && limit.restFacility == lhRestFacility
        }

        // For 2-pilot operations, there are multiple entries with different requirements
        // Return the baseline entry (nil requirements = most permissive)
        // For augmented operations, there should be only one match
        if crewComplement == .twoPilot {
            // Return the entry with no requirements (baseline limits)
            return matchingLimits.first { $0.requirements == nil } ?? matchingLimits.first
        } else {
            return matchingLimits.first
        }
    }

    /// Get LH rest requirement from FD10.1 operational limits
    /// - Parameters:
    ///   - crewComplement: Crew complement
    ///   - direction: Pre-duty or post-duty
    ///   - dutyHours: Duty hours to determine applicable threshold
    /// - Returns: Rest requirement or nil if not found
    private func getLHRestRequirement(crewComplement: CrewComplement,
                                      direction: RestDirection,
                                      dutyHours: Double) -> RestRequirement? {

        // Map CrewComplement to LH_CrewComplement
        let lhCrewComp: LH_CrewComplement
        switch crewComplement {
        case .twoPilot: lhCrewComp = .twoPilot
        case .threePilot: lhCrewComp = .threePilot
        case .fourPilot: lhCrewComp = .fourPilot
        }

        // Get rest requirements based on crew complement and direction
        let requirements: [RestRequirement]
        switch (lhCrewComp, direction) {
        case (.twoPilot, .preDuty): requirements = LH_Operational_FltDuty.twoPilotPreDutyRest
        case (.twoPilot, .postDuty): requirements = LH_Operational_FltDuty.twoPilotPostDutyRest
        case (.threePilot, .preDuty): requirements = LH_Operational_FltDuty.threePilotPreDutyRest
        case (.threePilot, .postDuty): requirements = LH_Operational_FltDuty.threePilotPostDutyRest
        case (.fourPilot, .preDuty): requirements = LH_Operational_FltDuty.fourPilotPreDutyRest
        case (.fourPilot, .postDuty): requirements = LH_Operational_FltDuty.fourPilotPostDutyRest
        }

        // Find matching requirement based on duty threshold
        // This is a simplified approach - actual threshold matching would need more complex logic
        for requirement in requirements {
            if requirement.minimumRestHours != nil {
                // Simple threshold matching for common cases
                if requirement.dutyPeriodThreshold.contains("≤ 11") && dutyHours <= 11 {
                    return requirement
                } else if requirement.dutyPeriodThreshold.contains("> 11") && requirement.dutyPeriodThreshold.contains("≤") == false && dutyHours > 11 {
                    return requirement
                } else if requirement.dutyPeriodThreshold.contains("≤ 12") && dutyHours <= 12 {
                    return requirement
                } else if requirement.dutyPeriodThreshold.contains("≤ 16") && dutyHours <= 16 {
                    return requirement
                } else if requirement.dutyPeriodThreshold.contains("> 16") && dutyHours > 16 {
                    return requirement
                } else if requirement.dutyPeriodThreshold == "—" {
                    return requirement  // Default case
                }
            } else if requirement.minimumRestFormula != nil {
                // Formula-based rest (e.g., for extensions)
                return requirement
            }
        }

        // Return first requirement as fallback
        return requirements.first
    }

    // MARK: - A380/A330/B787 Specific Limits

    private func getBaseLimitsA380A330B787(crewComplement: CrewComplement,
                                          restFacility: RestFacilityClass,
                                          limitType: FRMSLimitType) -> (maxDuty: Double, maxFlight: Double, maxSectors: Int) {

        // Get duty limit from LH_Operational_FltDuty - must always succeed
        guard let dutyLimit = getLHDutyLimit(crewComplement: crewComplement, restFacility: restFacility, limitType: limitType) else {
            // This should never happen if LH_Operational_FltDuty is complete
            LogManager.shared.error("FRMS: Failed to find LH duty limit for \(crewComplement.description) with \(restFacility.description)")
            fatalError("LH_Operational_FltDuty lookup failed - data structure incomplete")
        }

        let maxDuty: Double
        let maxFlight: Double
        let maxSectors: Int

        // Use planning or operational (discretion) limits - these must exist
        if limitType == .planning {
            guard let planned = dutyLimit.dutyPeriodLimitPlanned else {
                LogManager.shared.error("FRMS: No planned duty limit in LH_Operational_FltDuty")
                fatalError("LH_Operational_FltDuty missing planned duty limit")
            }
            maxDuty = planned
        } else {
            // Operational: use discretion limit if available, otherwise planned limit
            guard let operational = dutyLimit.dutyPeriodLimitDiscretion ?? dutyLimit.dutyPeriodLimitPlanned else {
                LogManager.shared.error("FRMS: No operational/planned duty limit in LH_Operational_FltDuty")
                fatalError("LH_Operational_FltDuty missing operational duty limit")
            }
            maxDuty = operational
        }

        // Flight time limit
        // Note: Augmented crew operations (3/4-pilot) don't have simple flight time limits
        // Instead they limit total duty in flight deck (14 hours max per FD10.1)
        // This is captured in flightTimeLimitNote, not flightTimeLimit
        if let flightLimit = dutyLimit.flightTimeLimit {
            maxFlight = flightLimit
        } else {
            // Augmented operations: use 14.0 (max total duty in flight deck per FD10.1)
            maxFlight = 14.0
        }

        // Sectors: 2-pilot = 4 sectors, augmented = typically 2 sectors
        maxSectors = crewComplement == .twoPilot ? 4 : 2

        return (maxDuty: maxDuty, maxFlight: maxFlight, maxSectors: maxSectors)
    }

    // MARK: - A320/B737 Duty and Flight Time Helpers

    /// Get maximum duty hours for A320/B737 based on local start time and sectors
    /// - Parameters:
    ///   - signOn: Sign-on time
    ///   - sectors: Number of sectors
    ///   - crewComplement: Crew complement
    ///   - limitType: Planning (FD13.1) or Operational (FD23.1) limits
    /// - Returns: Maximum duty hours or nil if not applicable
    private func getA320B737MaxDutyHours(signOn: Date, sectors: Int, crewComplement: CrewComplement, limitType: FRMSLimitType) -> Double? {
        guard crewComplement == .twoPilot else {
            return nil  // Use base limits for augmented crews
        }

        // Classify local start time using home base timezone
        // Note: Time window classification is the same for both planning and operational
        let homeTimeZone = getHomeBaseTimeZone()
        let localStartTime = SH_Operational_FltDuty.LocalStartTime.classify(signOn: signOn, homeBaseTimeZone: homeTimeZone)

        // Get max duty from planning or operational rules
        if limitType == .planning {
            // Convert to planning enum (same time ranges)
            let planningStartTime = SH_Planning_FltDuty.LocalStartTime(rawValue: localStartTime.rawValue) ?? .night
            return SH_Planning_FltDuty.maxDutyHours(localStartTime: planningStartTime, sectors: sectors)
        } else {
            return SH_Operational_FltDuty.maxDutyHours(localStartTime: localStartTime, sectors: sectors)
        }
    }

    /// Get maximum flight time for A320/B737 based on sectors and darkness
    /// - Parameters:
    ///   - sectors: Number of sectors scheduled
    ///   - nightTime: Hours of flight time in darkness
    ///   - crewComplement: Crew complement
    ///   - limitType: Planning (FD13.3/13.4) or Operational (FD23.3/23.4) limits
    /// - Returns: Maximum flight time hours
    private func getA320B737MaxFlightTime(sectors: Int, nightTime: Double, crewComplement: CrewComplement, limitType: FRMSLimitType) -> Double {
        // Check if more than 7 hours of flight time in darkness
        let darknessExceeds7Hours = nightTime > 7.0

        // Get max flight time from planning or operational rules
        // NOTE: For A320/B737, flight time limits are identical in planning (FD13) and operational (FD23)
        if crewComplement == .twoPilot {
            if limitType == .planning {
                return SH_Planning_FltDuty.maxFlightTimeHours(
                    sectorsScheduled: sectors,
                    darknessFlightTimeExceeds7Hours: darknessExceeds7Hours
                )
            } else {
                return SH_Operational_FltDuty.maxFlightTimeHours(
                    sectorsScheduled: sectors,
                    darknessFlightTimeExceeds7Hours: darknessExceeds7Hours
                )
            }
        } else {
            // Augmented crews: Same limit for planning (FD13.4) and operational (FD23.4)
            return limitType == .planning ?
                SH_Planning_FltDuty.augmentedFlightTimeLimitHours :
                SH_Operational_FltDuty.augmentedFlightTimeLimitHours
        }
    }

    // MARK: - A320/B737 Specific Limits

    private func getBaseLimitsA320B737(crewComplement: CrewComplement,
                                      restFacility: RestFacilityClass,
                                      limitType: FRMSLimitType) -> (maxDuty: Double, maxFlight: Double, maxSectors: Int) {

        switch crewComplement {
        case .twoPilot:
            // A320/B737 2-pilot limits from SH_Planning_FltDuty (FD13) or SH_Operational_FltDuty (FD23)
            // NOTE: These are baseline values. Actual limits vary by local start time.
            // Use the most restrictive baseline (night operations) for general calculations
            if limitType == .operational {
                // Operational (FD23): Night window baseline (most restrictive)
                // Max duty: 12h (1-4 sectors), 12h (5 sectors), 11h (6 sectors)
                // Max flight: 10h (multi-sector), 10.5h (single sector), 9.5h (>7h darkness)
                return (maxDuty: 12.0, maxFlight: 10.0, maxSectors: 6)
            } else {
                // Planning (FD13): Night window baseline (most restrictive)
                // Max duty: 10h (1-4 sectors), 10h (5-6 sectors)
                // Max flight: 10h (multi-sector), 10.5h (single sector), 9.5h (>7h darkness)
                return (maxDuty: 10.0, maxFlight: 10.0, maxSectors: 6)
            }

        case .threePilot:
            // A320/B737 augmented crew (3-pilot) limits depend on rest facility
            // NOTE: Planning (FD13.1) and Operational (FD23.1) augmented limits are identical
            // Map RestFacilityClass to AugmentedRestFacility for SH rules
            let shRestFacility: SH_Operational_FltDuty.AugmentedRestFacility
            switch restFacility {
            case .class1:
                shRestFacility = .separateScreenedSeat  // Class 1 = separate screened seat
            case .class2, .mixed, .none:
                shRestFacility = .passengerCompartmentSeat  // Class 2 = passenger compartment seat
            }

            // Get limits from SH_Operational_FltDuty (same values in SH_Planning_FltDuty)
            if let augmentedLimit = SH_Operational_FltDuty.augmentedDutyLimits.first(where: { $0.restFacility == shRestFacility }) {
                // Flight time limit is 10.5h for augmented operations (FD13.4 & FD23.4)
                return (maxDuty: augmentedLimit.maxDutyHours,
                       maxFlight: SH_Operational_FltDuty.augmentedFlightTimeLimitHours,
                       maxSectors: augmentedLimit.maxSectors ?? 6)
            }

            // Fallback to conservative values
            return (maxDuty: 14.0, maxFlight: 10.5, maxSectors: 6)

        case .fourPilot:
            // A320/B737 4-pilot operations are rare but follow similar augmented rules
            // NOTE: Planning (FD13.1) and Operational (FD23.1) augmented limits are identical
            // Use most generous augmented limit (separate screened seat)
            if let augmentedLimit = SH_Operational_FltDuty.augmentedDutyLimits.first(where: { $0.restFacility == .separateScreenedSeat }) {
                return (maxDuty: augmentedLimit.maxDutyHours,
                       maxFlight: SH_Operational_FltDuty.augmentedFlightTimeLimitHours,
                       maxSectors: augmentedLimit.maxSectors ?? 2)
            }

            // Fallback
            return (maxDuty: 16.0, maxFlight: 10.5, maxSectors: 2)
        }
    }

    // MARK: - Minimum Rest Calculation

    private func calculateMinimumRest(afterDuty duty: FRMSDuty, limitType: FRMSLimitType) -> Double {

        // Fleet-specific rest requirements
        switch configuration.fleet {
        case .a320B737:
            return calculateMinimumRestA320B737(afterDuty: duty, limitType: limitType)
        case .a380A330B787:
            return calculateMinimumRestA380A330B787(afterDuty: duty, limitType: limitType)
        }
    }

    // MARK: - A380/A330/B787 Minimum Rest

    private func calculateMinimumRestA380A330B787(afterDuty duty: FRMSDuty, limitType: FRMSLimitType) -> Double {

        // Get rest requirement from LH_Operational_FltDuty - must always succeed
        guard let restReq = getLHRestRequirement(crewComplement: duty.crewComplement,
                                                  direction: .postDuty,
                                                  dutyHours: duty.dutyTime) else {
            // This should never happen if LH_Operational_FltDuty is complete
            LogManager.shared.error("FRMS: Failed to find LH rest requirement for \(duty.crewComplement.description) after \(String(format: "%.1f", duty.dutyTime))h duty")
            fatalError("LH_Operational_FltDuty rest lookup failed - data structure incomplete")
        }

        // Check if formula-based rest applies (2-pilot duty/flight time extensions)
        if restReq.minimumRestFormula != nil && duty.crewComplement == .twoPilot {
            // Formula: "10 + 1 additional hour for each 15 minutes or part thereof when TOD exceeded 11 hours"
            if duty.dutyTime > 11 || duty.flightTime > 8 {
                let excessMinutes = (duty.dutyTime - 11.0) * 60.0
                let additionalHours = ceil(excessMinutes / 15.0)
                return 10.0 + additionalHours
            }
        }

        // Use minimum rest hours from rest requirement
        if let minRest = restReq.minimumRestHours {
            // Apply planning vs operational logic
            if limitType == .planning {
                // For 2-pilot, consider flight time limit for special cases
                if duty.crewComplement == .twoPilot && duty.dutyTime <= 11 {
                    // Planning: 11 hours if flight time ≤ 8, otherwise use table value
                    // This is from FD10.1 2-pilot pre-duty rest requirements
                    return duty.flightTime <= 8.0 ? 11.0 : minRest
                }
                return minRest
            } else {
                // Operational: use the minimum from table
                return minRest
            }
        }

        // Special cases where minimumRestHours is nil (e.g., Relevant Sectors >18 hours)
        // These have special requirements defined in the requirements field
        if let requirements = restReq.requirements, requirements.contains("Relevant Sector") {
            // For >18 hour duties (Relevant Sectors), use special rest from LH_Operational_FltDuty
            // Pre-duty: 22 hours (relevantSectorPreDutyRestHours)
            // Post-duty: 27-36 hours depending on crew (relevantSectorPostDutyRest)
            if restReq.direction == .preDuty {
                return LH_Operational_FltDuty.relevantSectorPreDutyRestHours
            } else {
                // Post-duty for relevant sectors: use minimum from table (27 hours)
                return LH_Operational_FltDuty.relevantSectorPostDutyRest.first?.minimumRestHours ?? 27.0
            }
        }

        // Default to 12 hours for any unhandled cases (standard minimum rest)
        LogManager.shared.warning("FRMS: Using default 12h rest for unhandled case: \(restReq.dutyPeriodThreshold)")
        return 12.0
    }

    // MARK: - A320/B737 Next Duty Limits Calculation

    /// Calculate complete A320/B737 next duty limits with all restrictions
    func calculateA320B737NextDutyLimits(previousDuty: FRMSDuty?,
                                         cumulativeTotals: FRMSCumulativeTotals,
                                         limitType: FRMSLimitType,
                                         duties: [FRMSDuty] = []) -> A320B737NextDutyLimits? {

        // Only applicable to A320/B737 fleet
        guard configuration.fleet == .a320B737 else { return nil }

        // Calculate earliest sign-on and rest requirements
        var earliestSignOn = Date()
        var restCalculation: RestCalculationBreakdown

        if let prevDuty = previousDuty {
            let minimumRest = calculateMinimumRestA320B737(afterDuty: prevDuty, limitType: limitType)
            // Calculate earliest sign-on using standard rounding for minutes
            let restMinutes = Int(round(minimumRest * 60))
            earliestSignOn = Calendar.current.date(byAdding: .minute, value: restMinutes, to: prevDuty.signOff) ?? Date()

            // Build rest calculation breakdown
            let formula: String
            let reducedRestAvailable: Bool
            let reducedRestConditions: String?

            if prevDuty.dutyTime <= 12 {
                formula = "MAX(\(String(format: "%.1f", prevDuty.dutyTime)), 10.0) hours"

                // Check if reduced rest is available (FD28.2)
                if limitType == .operational && prevDuty.dutyTime <= 10 {
                    reducedRestAvailable = true
                    reducedRestConditions = "9 hours if rest includes 2200-0600 local time"
                } else {
                    reducedRestAvailable = false
                    reducedRestConditions = nil
                }
            } else {
                let excess = prevDuty.dutyTime - 12.0
                formula = "12 + (1.5 × \(String(format: "%.1f", excess))) = \(String(format: "%.1f", minimumRest)) hours"
                reducedRestAvailable = false
                reducedRestConditions = nil
            }

            restCalculation = RestCalculationBreakdown(
                previousDutyHours: prevDuty.dutyTime,
                formula: formula,
                minimumRestHours: minimumRest,
                reducedRestAvailable: reducedRestAvailable,
                reducedRestConditions: reducedRestConditions
            )

            // Apply back-of-clock restriction if applicable (FD14.4)
            if prevDuty.timeClass == .backOfClock {
                let homeTimeZone = getHomeBaseTimeZone()
                var localCalendar = Calendar.current
                localCalendar.timeZone = homeTimeZone

                var components = localCalendar.dateComponents([.year, .month, .day], from: earliestSignOn)
                components.hour = 10
                components.minute = 0

                if let tenAM = localCalendar.date(from: components), earliestSignOn < tenAM {
                    earliestSignOn = tenAM
                }
            }
        } else {
            // No previous duty
            restCalculation = RestCalculationBreakdown(
                previousDutyHours: 0,
                formula: "No previous duty",
                minimumRestHours: 0,
                reducedRestAvailable: false,
                reducedRestConditions: nil
            )
        }

        // Build sign-on time windows using FD23 (Operational) or FD13 (Planning) Limits
        // Windows now pull limits from SH_Operational_FltDuty or SH_Planning_FltDuty based on limitType

        let earlyWindow = buildA320B737DutyWindow(
            localStartTime: .early,
            earliestSignOn: earliestSignOn,
            limitType: limitType
        )

        let afternoonWindow = buildA320B737DutyWindow(
            localStartTime: .afternoon,
            earliestSignOn: earliestSignOn,
            limitType: limitType
        )

        let nightWindow = buildA320B737DutyWindow(
            localStartTime: .night,
            earliestSignOn: earliestSignOn,
            limitType: limitType
        )

        // Check for back-of-clock restriction
        var backOfClockRestriction: BackOfClockRestriction? = nil
        if let prevDuty = previousDuty, prevDuty.timeClass == .backOfClock {
            backOfClockRestriction = BackOfClockRestriction(
                earliestSignOn: earliestSignOn,
                reason: "Previous duty included ≥2 hours between 0100-0459",
                appliesTo: "Australia only"
            )
        }

        // Build late night status
        var lateNightStatus: LateNightStatus? = nil
        if cumulativeTotals.consecutiveLateNights > 0 {
            // Calculate duty hours in 7-night period from duties involving late night operations
            // Per FD14.3(a) & FD24.3(a): Only count duties that are classified as late night or back of clock
            let homeTimeZone = getHomeBaseTimeZone()
            var calendar = Calendar.current
            calendar.timeZone = homeTimeZone

            let now = Date()
            let startOfToday = calendar.startOfDay(for: now)
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
            let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

            // Filter duties in last 7 days that involve late night operations
            let lateNightDutiesIn7Days = duties.filter { duty in
                // Check if duty is in the 7-day window
                let dutyDate = duty.date
                guard dutyDate >= sevenDaysAgo && dutyDate <= endOfToday else { return false }

                // Check if duty is classified as late night or back of clock
                return duty.timeClass == .lateNight || duty.timeClass == .backOfClock
            }

            // Sum duty hours from late night duties only
            let dutyHours7Nights = lateNightDutiesIn7Days.reduce(0.0) { $0 + $1.dutyTime }

            let recoveryOption: LateNightRecoveryOption
            if cumulativeTotals.consecutiveLateNights >= 4 {
                recoveryOption = .require24HoursOff
            } else if cumulativeTotals.consecutiveLateNights >= 2 {
                recoveryOption = .continueOnLateNights
            } else {
                recoveryOption = .noRestriction
            }

            lateNightStatus = LateNightStatus(
                consecutiveLateNights: cumulativeTotals.consecutiveLateNights,
                maxConsecutiveLateNights: 4,
                dutyHoursIn7Nights: dutyHours7Nights,
                maxDutyHoursIn7Nights: 40.0,
                canUse5NightException: true, // Would need to track 28-day usage
                recoveryOption: recoveryOption
            )
        }

        // Build consecutive duty status
        let consecutiveDutyStatus = ConsecutiveDutyStatus(
            consecutiveDuties: cumulativeTotals.consecutiveDuties,
            maxConsecutiveDuties: 6,
            dutyDaysIn11Days: cumulativeTotals.dutyDaysIn11Days,
            maxDutyDaysIn11Days: 9,
            consecutiveEarlyStarts: cumulativeTotals.consecutiveEarlyStarts,
            maxConsecutiveEarlyStarts: 4
        )

        // Pattern end requirement (simplified - would need pattern tracking)
        var patternEndRequirement: PatternEndRequirement? = nil
        if cumulativeTotals.consecutiveDuties >= 3 {
            patternEndRequirement = PatternEndRequirement(
                patternDays: cumulativeTotals.consecutiveDuties,
                minimumRestHours: cumulativeTotals.consecutiveDuties >= 3 ? 15.0 : 12.0,
                reason: cumulativeTotals.consecutiveDuties >= 3 ? "3-4 day pattern" : "1-2 day pattern"
            )
        }

        // Weekly rest status (FD12.3)
        // This is simplified - would need detailed tracking of rest periods
        let weeklyRestStatus = WeeklyRestStatus(
            hasRequired36Hours: true, // Placeholder
            hasRequired2Nights: true, // Placeholder
            nextRequiredBy: nil,
            isCompliant: true
        )

        // Determine overall status
        var overallStatus: FRMSComplianceStatus = .compliant
        if consecutiveDutyStatus.hasActiveRestrictions {
            overallStatus = .warning(message: "Consecutive duty limits approaching")
        }
        if backOfClockRestriction != nil {
            overallStatus = .warning(message: "Back-of-clock restrictions apply")
        }

        // Build special scenarios
        let specialScenarios = buildA320B737SpecialScenarios()

        return A320B737NextDutyLimits(
            earlyWindow: earlyWindow,
            afternoonWindow: afternoonWindow,
            nightWindow: nightWindow,
            backOfClockRestriction: backOfClockRestriction,
            lateNightStatus: lateNightStatus,
            consecutiveDutyStatus: consecutiveDutyStatus,
            restCalculation: restCalculation,
            earliestSignOn: earliestSignOn,
            patternEndRequirement: patternEndRequirement,
            weeklyRestStatus: weeklyRestStatus,
            specialScenarios: specialScenarios,
            overallStatus: overallStatus
        )
    }

    /// Build special scenarios for A320/B737
    private func buildA320B737SpecialScenarios() -> SpecialScenarios {
        // Simulator restrictions (FD7)
        let simulatorRestrictions = SimulatorRestrictions(
            dayBeforeRestriction: "Sign-off ≤2000 day before simulator (Australia)",
            restBeforeSimulator: 12.0,
            sameDayProhibition: "Cannot have 2 duty periods in same 24-hour period (Australia)",
            applicableRegion: "Australia/New Zealand"
        )

        // Days off requirements (FD5)
        let daysOffRequirements = DaysOffRequirements(
            dutyBeforeXDay: "Complete ≤2230 local (previous day)",
            dutyAfterXDay: "Earliest sign-on 0500 local",
            minimumDuration: 36.0,
            operationalException: "May extend to 2300 local for operational disruptions"
        )

        // Annual leave adjacency (FD9)
        let annualLeaveRestrictions = AnnualLeaveRestrictions(
            beforeLeaveRestriction: "Latest duty end: 2000 (day before) - Australia, 1800 (≥7 days) - NZ",
            afterLeaveRestriction: "Earliest duty start: 0800 (day after) - Australia only",
            minimumLeaveDays: 7,
            canWaive: true,
            applicableRegion: "Australia/New Zealand"
        )

        // Reserve duty rules (FD13.5, FD23.5, FD28.3, FD51.3, FD64.3)
        let reserveDutyRules = ReserveDutyRules(
            afterCalloutRest: "MAX(12 hours, actual duty length)",
            withoutCalloutRest: "10 hours free of all duty (operational)",
            betweenReservePeriods: "MAX(12 hours, previous duty length)"
        )

        // Deadheading limitations (FD15, FD25)
        let deadheadingLimitations = DeadheadingLimitations(
            absoluteMaximum: 16.0,
            restCalculationNote: "Deadheading included in total duty for rest calculation",
            sectorCountingRule: "Last sector deadheading doesn't count; before flight duty does count"
        )

        return SpecialScenarios(
            simulatorRestrictions: simulatorRestrictions,
            daysOffRequirements: daysOffRequirements,
            annualLeaveRestrictions: annualLeaveRestrictions,
            reserveDutyRules: reserveDutyRules,
            deadheadingLimitations: deadheadingLimitations
        )
    }

    /// Check What-If scenario compliance
    func checkWhatIfScenario(scenario: WhatIfScenario,
                             previousDuty: FRMSDuty?,
                             cumulativeTotals: FRMSCumulativeTotals,
                             a320B737Limits: A320B737NextDutyLimits,
                             limitType: FRMSLimitType) -> WhatIfResult {

        var violations: [String] = []
        var warnings: [String] = []

        // Determine which time window applies
        // Use device's current timezone (where you currently are)
        let calendar = Calendar.current
        let signOnHour = calendar.component(.hour, from: scenario.proposedSignOn)

        let applicableWindow: DutyTimeWindow
        if signOnHour >= 5 && signOnHour <= 14 {
            applicableWindow = a320B737Limits.earlyWindow
        } else if signOnHour >= 15 && signOnHour <= 19 {
            applicableWindow = a320B737Limits.afternoonWindow
        } else {
            applicableWindow = a320B737Limits.nightWindow
        }

        // Check if sign-on is before earliest allowed
        if scenario.proposedSignOn < a320B737Limits.earliestSignOn {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM HHmm"
            violations.append("Sign-on before earliest allowed: \(formatter.string(from: a320B737Limits.earliestSignOn))")
        }

        // Get limits based on selected limit type
        let limits = applicableWindow.limits
        let maxDuty = limits.maxDuty(forSectors: scenario.estimatedSectors)

        // Check duty time
        if scenario.estimatedDutyHours > maxDuty {
            violations.append("Duty time \(String(format: "%.1f", scenario.estimatedDutyHours))h exceeds max \(String(format: "%.1f", maxDuty))h for \(scenario.estimatedSectors) sectors")
        } else if scenario.estimatedDutyHours > (maxDuty * 0.9) {
            warnings.append("Duty time approaching limit (\(String(format: "%.1f", scenario.estimatedDutyHours))h of \(String(format: "%.1f", maxDuty))h)")
        }

        // Check flight time
        if scenario.estimatedFlightHours > limits.maxFlightTime {
            violations.append("Flight time \(String(format: "%.1f", scenario.estimatedFlightHours))h exceeds max \(String(format: "%.1f", limits.maxFlightTime))h")
        }

        // Check cumulative limits
        if scenario.estimatedFlightHours + cumulativeTotals.flightTime28Or30Days > configuration.fleet.maxFlightTime28Days {
            violations.append("Would exceed 28-day flight time limit")
        }

        if scenario.estimatedDutyHours + cumulativeTotals.dutyTime7Days > configuration.fleet.maxDutyTime7Days {
            violations.append("Would exceed 7-day duty time limit")
        }

        if scenario.estimatedDutyHours + cumulativeTotals.dutyTime14Days > configuration.fleet.maxDutyTime14Days {
            violations.append("Would exceed 14-day duty time limit")
        }

        // Check consecutive duty restrictions
        if a320B737Limits.consecutiveDutyStatus.consecutiveDuties >= 6 {
            violations.append("Maximum 6 consecutive duty days already reached")
        }

        if a320B737Limits.consecutiveDutyStatus.dutyDaysIn11Days >= 9 {
            violations.append("Maximum 9 duty days in 11-day period already reached")
        }

        // Determine compliance
        let isCompliant = violations.isEmpty
        let complianceStatus: FRMSComplianceStatus
        if !violations.isEmpty {
            complianceStatus = .violation(message: violations.joined(separator: "; "))
        } else if !warnings.isEmpty {
            complianceStatus = .warning(message: warnings.joined(separator: "; "))
        } else {
            complianceStatus = .compliant
        }

        return WhatIfResult(
            scenario: scenario,
            isCompliant: isCompliant,
            complianceStatus: complianceStatus,
            violations: violations,
            warnings: warnings,
            applicableWindow: applicableWindow
        )
    }

    /// Helper to build a duty time window from SH_Operational_FltDuty or SH_Planning_FltDuty rules
    /// - Parameters:
    ///   - localStartTime: The local start time classification (early/afternoon/night)
    ///   - earliestSignOn: Earliest sign-on time to determine availability
    ///   - limitType: Planning or Operational limits
    /// - Returns: DutyTimeWindow with limits calculated from FD23 (operational) or FD13 (planning) rules
    private func buildA320B737DutyWindow(localStartTime: SH_Operational_FltDuty.LocalStartTime,
                                         earliestSignOn: Date,
                                         limitType: FRMSLimitType) -> DutyTimeWindow {

        // Check if this window is currently available based on earliest sign-on
        let calendar = Calendar.current
        let signOnHour = calendar.component(.hour, from: earliestSignOn)

        // Get start and end hours from the LocalStartTime
        let range = localStartTime.range
        let startHour = range.lowerBound / 100
        let endHour = range.upperBound / 100

        // Check if sign-on hour falls within this window
        let isAvailable: Bool
        if endHour < startHour {
            // Wraps around midnight (e.g., 2000-0459)
            isAvailable = signOnHour >= startHour || signOnHour <= endHour
        } else {
            isAvailable = signOnHour >= startHour && signOnHour <= endHour
        }

        return DutyTimeWindow(
            timeRange: localStartTime.rawValue,
            displayName: localStartTime.displayName,
            startHour: startHour,
            endHour: endHour,
            localStartTime: localStartTime.rawValue,
            isCurrentlyAvailable: isAvailable,
            limitType: limitType
        )
    }

    // MARK: - A320/B737 Minimum Rest

    private func calculateMinimumRestA320B737(afterDuty duty: FRMSDuty, limitType: FRMSLimitType) -> Double {

        // Base rest calculation
        var minimumRest: Double

        if duty.dutyTime <= 12 {
            // FD18.1 (Planning) & FD28.1 (Operational): Same formula for both
            // Formula: MAX(10 hours, previous duty length)
            minimumRest = max(duty.dutyTime, 10.0)
        } else {
            // Over 12 hours: 12 + 1.5 * (duty - 12)
            let excess = duty.dutyTime - 12.0
            minimumRest = 12.0 + (1.5 * excess)
        }

        // Special rules for augmented crews
        if duty.crewComplement == .threePilot || duty.crewComplement == .fourPilot {
            if duty.dutyTime > 16 {
                minimumRest = max(minimumRest, 24.0)
            }
        }

        return minimumRest
    }

    // MARK: - Compliance Check

    /// Check if a proposed duty would be compliant
    func checkCompliance(proposedDuty: FRMSDuty,
                        previousDuty: FRMSDuty?,
                        cumulativeTotals: FRMSCumulativeTotals) -> FRMSComplianceStatus {

        var violations: [String] = []

        // Check flight time limits (fleet-specific)
        if let flightLimit7Days = configuration.fleet.maxFlightTime7Days {
            if proposedDuty.flightTime + cumulativeTotals.flightTime7Days > flightLimit7Days {
                violations.append("Would exceed \(Int(flightLimit7Days)) hours in 7 days")
            }
        }

        let periodDays = configuration.fleet.flightTimePeriodDays
        if proposedDuty.flightTime + cumulativeTotals.flightTime28Or30Days > configuration.fleet.maxFlightTime28Days {
            violations.append("Would exceed \(Int(configuration.fleet.maxFlightTime28Days)) hours in \(periodDays) days")
        }

        // Check duty time limits (fleet-specific)
        if proposedDuty.dutyTime + cumulativeTotals.dutyTime7Days > configuration.fleet.maxDutyTime7Days {
            violations.append("Would exceed \(Int(configuration.fleet.maxDutyTime7Days)) duty hours in 7 days")
        }

        if proposedDuty.dutyTime + cumulativeTotals.dutyTime14Days > configuration.fleet.maxDutyTime14Days {
            violations.append("Would exceed \(Int(configuration.fleet.maxDutyTime14Days)) duty hours in 14 days")
        }

        // Check rest requirements
        if let prevDuty = previousDuty {
            let requiredRest = calculateMinimumRest(afterDuty: prevDuty, limitType: .operational)
            // Use standardized conversion with proper rounding
            let actualRest = proposedDuty.signOn.timeIntervalSince(prevDuty.signOff).toDecimalHours

            if actualRest < requiredRest {
                violations.append("Insufficient rest: \(String(format: "%.1f", actualRest))h (need \(String(format: "%.1f", requiredRest))h)")
            }
        }

        // Return status
        if !violations.isEmpty {
            return .violation(message: violations.joined(separator: "; "))
        }

        return .compliant
    }

    // MARK: - Convert FlightSector to FRMSDuty

    /// Helper to convert existing FlightSector to FRMSDuty for calculations
    /// - Parameters:
    ///   - flightSector: The flight sector to convert
    ///   - crewPosition: The crew position (captain/FO)
    ///   - isFirstFlightOfDay: Whether this is the first flight of the duty day (affects sign-on time for positioning flights)
    /// - Returns: FRMSDuty object or nil if conversion fails
    func createDuty(from flightSector: FlightSector,
                   crewPosition: FlightTimePosition,
                   isFirstFlightOfDay: Bool = false) -> FRMSDuty? {

        // Validate date format - ensure it can be parsed
        guard Self.cachedDateFormatter.date(from: flightSector.date) != nil else {
            // Only log if in recent years (2023-2025)
            if flightSector.date.contains("2023") || flightSector.date.contains("2024") || flightSector.date.contains("2025") {
                LogManager.shared.warning("FRMS: Skipping flight on \(flightSector.date) - invalid date format")
            }
            return nil
        }

        // Get flight time from sector
        // For simulator flights, use simTime; otherwise use blockTime
        let flightTime = flightSector.blockTimeValue > 0 ? flightSector.blockTimeValue : flightSector.simTimeValue

        // If no flight time at all, check if it's a positioning flight
        // Positioning flights may have zero blockTime but still contribute to duty time
        if flightTime == 0 && !flightSector.isPositioning {
            return nil
        }

        var signOn: Date
        var signOff: Date

        // Check if we have OUT and IN times
        if !flightSector.outTime.isEmpty && !flightSector.inTime.isEmpty {
            // Parse OUT and IN times (format: "HHMM" or "HH:MM")
            // We need to combine date + time to get proper Date objects
            let outTimeStr = flightSector.outTime.replacingOccurrences(of: ":", with: "")
            let inTimeStr = flightSector.inTime.replacingOccurrences(of: ":", with: "")

            // Use cached formatter
            guard let outDate = Self.cachedTimeFormatter.date(from: "\(flightSector.date) \(outTimeStr)"),
                  var inDate = Self.cachedTimeFormatter.date(from: "\(flightSector.date) \(inTimeStr)") else {
                // Only log if in recent years (2023-2025)
                if flightSector.date.contains("2023") || flightSector.date.contains("2024") || flightSector.date.contains("2025") {
                    LogManager.shared.warning("FRMS: Skipping flight on \(flightSector.date) - can't parse OUT(\(flightSector.outTime))/IN(\(flightSector.inTime)) times")
                }
                return nil
            }

            // If IN time is before OUT time, it crossed midnight - add a day
            if inDate < outDate {
                inDate = Calendar.current.date(byAdding: .day, value: 1, to: inDate) ?? inDate
            }

            // Parse scheduled times if available
            var stdDate: Date? = nil

            if !flightSector.scheduledDeparture.isEmpty {
                let stdTimeStr = flightSector.scheduledDeparture.replacingOccurrences(of: ":", with: "")
                stdDate = Self.cachedTimeFormatter.date(from: "\(flightSector.date) \(stdTimeStr)")
            }

            // Calculate sign-on and sign-off using configured margins
            // For completed flights, STD (if available) or OUT will be used for sign-on
            // Special case: First positioning flight between two Australian ports uses 30 min instead of 60 min
            signOn = calculateSignOn(
                stdTime: stdDate,
                outTime: outDate,
                isFirstFlightOfDay: isFirstFlightOfDay,
                isPositioning: flightSector.isPositioning,
                fromAirport: flightSector.fromAirport,
                toAirport: flightSector.toAirport
            )
            signOff = calculateSignOff(inTime: inDate)
        } else {
            // For flights without OUT/IN times:
            // - Try to use scheduled departure/arrival times
            // - For simulator flights without times, estimate duty from sim time

            // For future scheduled flights or simulators, use scheduled times
            var stdDate: Date? = nil
            var staDate: Date? = nil

            // Parse scheduled times if available using cached formatter
            if !flightSector.scheduledDeparture.isEmpty {
                let stdTimeStr = flightSector.scheduledDeparture.replacingOccurrences(of: ":", with: "")
                stdDate = Self.cachedTimeFormatter.date(from: "\(flightSector.date) \(stdTimeStr)")
            }

            if !flightSector.scheduledArrival.isEmpty {
                let staTimeStr = flightSector.scheduledArrival.replacingOccurrences(of: ":", with: "")
                staDate = Self.cachedTimeFormatter.date(from: "\(flightSector.date) \(staTimeStr)")
            }

            // If we have scheduled times, use them
            if let std = stdDate, let sta = staDate {
                // Handle overnight flights (STA before STD means next day)
                var adjustedSta = sta
                if sta < std {
                    adjustedSta = Calendar.current.date(byAdding: .day, value: 1, to: sta) ?? sta
                }

                signOn = calculateSignOn(
                    stdTime: std,
                    outTime: std,
                    isFirstFlightOfDay: isFirstFlightOfDay,
                    isPositioning: flightSector.isPositioning,
                    fromAirport: flightSector.fromAirport,
                    toAirport: flightSector.toAirport
                )
                signOff = calculateSignOff(inTime: adjustedSta)
            } else if let std = stdDate {
                // Only have STD, estimate from flight time
                signOn = calculateSignOn(
                    stdTime: std,
                    outTime: std,
                    isFirstFlightOfDay: isFirstFlightOfDay,
                    isPositioning: flightSector.isPositioning,
                    fromAirport: flightSector.fromAirport,
                    toAirport: flightSector.toAirport
                )
                let estimatedDutyMinutes = Int(flightTime * 60) + configuration.signOffMinutesAfterIN
                signOff = Calendar.current.date(byAdding: .minute, value: estimatedDutyMinutes, to: signOn) ?? signOn
            } else {
                // No scheduled times available - estimate duty times from the date
                // This handles simulator flights and rostered flights without times
                guard let baseDate = Self.cachedDateFormatter.date(from: flightSector.date) else {
                    return nil
                }

                // Use midnight UTC as sign-on for simplicity
                signOn = baseDate

                // For simulator flights, use simTime + 1.5 hours as duty time
                // For other flights, use flight time + 1.5 hours
                let dutyHours = flightTime + 1.5
                let dutyMinutes = Int(dutyHours * 60)
                signOff = Calendar.current.date(byAdding: .minute, value: dutyMinutes, to: signOn) ?? signOn
            }
        }

        // Infer crew complement from crew names
        let crewComplement = inferCrewComplement(
            captainName: flightSector.captainName,
            foName: flightSector.foName,
            so1Name: flightSector.so1Name,
            so2Name: flightSector.so2Name
        )

        // Determine if international (simplified - could be enhanced)
        let isInternational = flightSector.aircraftType.contains("A380") ||
                             flightSector.aircraftType.contains("A330") ||
                             flightSector.aircraftType.contains("B787")

        // Get night time
        let nightTime = flightSector.nightTimeValue

        // Duty type
        let dutyType: DutyType = flightSector.isPositioning ? .deadheading : .operating

        // Get home base timezone for time classification
        let homeTimeZone = getHomeBaseTimeZone()

        // Use the original database date (UTC midnight) for duty date
        // This ensures consistency with Dashboard calculations
        // The database stores dates as dd/MM/yyyy strings converted to UTC midnight
        guard let dbDate = Self.cachedDateFormatter.date(from: flightSector.date) else {
            return nil
        }

        return FRMSDuty(
            date: dbDate,
            dutyType: dutyType,
            crewComplement: crewComplement,
            restFacility: .none,  // Would need to determine this
            signOn: signOn,
            signOff: signOff,
            flightTime: flightTime,
            nightTime: nightTime,
            sectors: 1,  // Each FlightSector is 1 sector
            isInternational: isInternational,
            homeBaseTimeZone: homeTimeZone
        )
    }
}
