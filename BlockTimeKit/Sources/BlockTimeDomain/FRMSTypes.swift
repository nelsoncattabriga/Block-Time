//
//  FRMSTypes.swift
//  BlockTimeDomain
//
//  FRMS domain value types moved from Block-Time/Models/FRMSData.swift (D-03).
//  Based on Qantas FRMS Ruleset Rev 4.1 (A320/B737) and Rev 4 (A380/A330/B787).
//

import Foundation

// MARK: - FRMS Fleet Type

public enum FRMSFleet: String, Codable, CaseIterable, Sendable {
    case a320B737 = "A320/B737"
    case a380A330B787 = "A380/A330/B787"

    /// Short display name for UI (e.g., picker menus)
    public var shortName: String {
        switch self {
        case .a320B737: return "Shorthaul"
        case .a380A330B787: return "Longhaul"
        }
    }

    /// Full description for subtext
    public var fullDescription: String {
        return self.rawValue
    }

    public var maxFlightTime7Days: Double? {
        switch self {
        case .a320B737: return nil  // No 7-day flight time limit for narrowbody
        case .a380A330B787: return 30.0
        }
    }

    public var maxFlightTime28Days: Double {
        switch self {
        case .a320B737: return 100.0
        case .a380A330B787: return 100.0  // Actually uses 30 days, but limit is still 100
        }
    }

    /// Returns the rolling period in days for flight time limits (28 or 30)
    public var flightTimePeriodDays: Int {
        switch self {
        case .a320B737: return 28
        case .a380A330B787: return 30
        }
    }

    public var maxFlightTime365Days: Double {
        switch self {
        case .a320B737: return 1000.0
        case .a380A330B787: return 900.0
        }
    }

    public var maxDutyTime7Days: Double {
        switch self {
        case .a320B737: return 60.0
        case .a380A330B787: return 60.0  // FD6.4.2: 60 hours in any consecutive 7 days
        }
    }

    /// Initial 14-day duty limit (at roster publication, no agreement required).
    /// SH only: 90 hrs (FD12/FD22). LH has a single limit of 100 hrs.
    public var maxDutyTime14DaysInitial: Double? {
        switch self {
        case .a320B737: return 90.0
        case .a380A330B787: return nil
        }
    }

    /// Hard maximum 14-day duty limit (requires pilot agreement or open time bid for SH).
    public var maxDutyTime14Days: Double {
        switch self {
        case .a320B737: return 100.0
        case .a380A330B787: return 100.0  // FD6.4.3
        }
    }
}

// MARK: - Crew Complement

public enum CrewComplement: Int, Codable, Sendable {
    case twoPilot = 2
    case threePilot = 3
    case fourPilot = 4

    public var description: String {
        "\(rawValue) Pilot"
    }
}

// MARK: - Rest Facility Class (for augmented operations)

public enum RestFacilityClass: String, Codable, Sendable {
    case none           // 2-pilot operations
    case class2         // Seat in cabin with full screen
    case class1         // Bunk or berth
    case mixed          // 1x Class1 + 1x Class2

    public var description: String {
        switch self {
        case .class1: return "Class 1 Rest"
        case .class2: return "Class 2 Rest"
        case .mixed: return "Mixed (Class 1 & 2)"
        case .none: return "No Rest Facility"
        }
    }
}

// MARK: - Crew Rest Facility (LH augmented operations — moved from LH_Operational_FltDuty.swift)
// Moved here (alongside SignOnTimeRange) so BlockTimeDomain has no dependency on BlockTimeCalculators.

public enum CrewRestFacility: String, Codable, CaseIterable, Sendable {
    case seatInPassengerCompartment = "Seat in Passenger Compartment"
    case class2                    = "Class 2 Rest"
    case class1                    = "Class 1 Rest"
    case twoClass2                 = "2 × Class 2 Rest"
    case oneClass1OneClass2        = "1 × Class 1 & 1 × Class 2 Rest"
    case twoClass1                 = "2 × Class 1 Rest"
    case twoClass1FD34             = "2 × Class 1 Rest (>18 hrs per FD3.4)"
}

// MARK: - Duty Type

public enum DutyType: String, Codable, Sendable {
    case operating      // Flying as operating crew
    case deadheading    // Positioning flight
    case standby        // On standby duty
    case simulator      // Simulator training (1.5× duty factor applies)
    case instructor     // Sp/Ins instructor in simulator (no 1.5× factor, no flight time)
    case ground         // Ground duties/admin

    public var icon: String {
        switch self {
        case .operating: return "airplane"
        case .deadheading: return "airplane.departure"
        case .standby: return "clock"
        case .simulator: return "gamecontroller"
        case .instructor: return "person.fill.checkmark"
        case .ground: return "building.2"
        }
    }
}

// MARK: - Operation Time of Day Classification

public enum OperationTimeClass: String, Codable, Sendable {
    case day            // Not a late night operation
    case lateNight      // Contains >30 min between 2300-0530
    case backOfClock    // Contains 2+ hours between 0100-0459

    /// Determines time class from duty period using HOME BASE local time
    /// - Parameters:
    ///   - signOn: Sign-on time in UTC
    ///   - signOff: Sign-off time in UTC
    ///   - homeBaseTimeZone: The timezone of the crew's home base (e.g., Australia/Sydney, Australia/Perth)
    /// - Returns: The operation time class (day, lateNight, or backOfClock)
    public static func classify(signOn: Date, signOff: Date, homeBaseTimeZone: TimeZone) -> OperationTimeClass {
        // Create calendar with home base timezone (use gregorian — not Calendar.current — for deterministic results)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = homeBaseTimeZone

        var hasLateNight = false
        var backOfClockMinutes = 0

        // Check each minute of the duty period in LOCAL TIME
        var currentTime = signOn
        while currentTime < signOff {
            let hour = calendar.component(.hour, from: currentTime)
            let minute = calendar.component(.minute, from: currentTime)

            // Check for late night (2300-0530 LOCAL TIME)
            if hour >= 23 || hour < 5 || (hour == 5 && minute < 30) {
                hasLateNight = true
            }

            // Count back of clock time (0100-0459 LOCAL TIME)
            if hour >= 1 && hour < 5 {
                let nextTime = calendar.date(byAdding: .minute, value: 1, to: currentTime) ?? currentTime
                if nextTime <= signOff {
                    backOfClockMinutes += 1
                }
            }

            currentTime = calendar.date(byAdding: .minute, value: 1, to: currentTime) ?? currentTime
        }

        // Back of clock if 2+ hours (120+ minutes)
        if backOfClockMinutes >= 120 {
            return .backOfClock
        }

        // Late night if >30 min between 2300-0530
        if hasLateNight {
            let lateNightDuration = calculateLateNightDuration(signOn: signOn, signOff: signOff, homeBaseTimeZone: homeBaseTimeZone)
            if lateNightDuration > 0.5 { // >30 minutes
                return .lateNight
            }
        }

        return .day
    }

    /// Calculate hours spent in late night window (2300-0530 LOCAL TIME)
    private static func calculateLateNightDuration(signOn: Date, signOff: Date, homeBaseTimeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = homeBaseTimeZone

        var lateNightMinutes = 0

        var currentTime = signOn
        while currentTime < signOff {
            let hour = calendar.component(.hour, from: currentTime)
            let minute = calendar.component(.minute, from: currentTime)

            if hour >= 23 || hour < 5 || (hour == 5 && minute < 30) {
                lateNightMinutes += 1
            }

            currentTime = calendar.date(byAdding: .minute, value: 1, to: currentTime) ?? currentTime
        }

        return Double(lateNightMinutes) / 60.0
    }
}

// MARK: - FRMS Limit Type (Planning vs Operational)

public enum FRMSLimitType: String, Codable, Sendable {
    case planning       // Scheduled limits (roster planning)
    case operational    // Actual limits (with pilot discretion to extend)

    public var description: String {
        switch self {
        case .planning: return "Planning Limits"
        case .operational: return "Operational Limits"
        }
    }
}

// MARK: - FRMS Compliance Status

public enum FRMSComplianceStatus: Codable, Sendable {
    case compliant              // Within limits
    case warning(message: String)  // Approaching limits
    case violation(message: String) // Exceeds limits

    public var color: String {
        switch self {
        case .compliant: return "green"
        case .warning: return "orange"
        case .violation: return "red"
        }
    }

    public var icon: String {
        switch self {
        case .compliant: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .violation: return "xmark.circle.fill"
        }
    }
}

// MARK: - FRMS Duty Summary

/// Represents a complete duty period for FRMS calculations
public struct FRMSDuty: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let dutyType: DutyType
    public let crewComplement: CrewComplement
    public let restFacility: RestFacilityClass
    public let signOn: Date
    public let signOff: Date
    public let flightTime: Double          // Hours (operating block time only)
    public let simSessionTime: Double      // Hours (raw SIM session time, 0 for non-SIM duties)
    public let dutyTime: Double            // Hours
    public let nightTime: Double           // Hours of flight time in darkness
    public let sectors: Int
    public let timeClass: OperationTimeClass
    public let isInternational: Bool
    public let hasActualINTime: Bool   // true when built from entered OUT/IN times (not scheduled STA)
    public let toAirport: String       // ICAO code of the last sector's destination

    public init(id: UUID = UUID(),
         date: Date,
         dutyType: DutyType,
         crewComplement: CrewComplement,
         restFacility: RestFacilityClass = .none,
         signOn: Date,
         signOff: Date,
         flightTime: Double,
         simSessionTime: Double = 0,
         nightTime: Double = 0,
         sectors: Int,
         isInternational: Bool = false,
         hasActualINTime: Bool = false,
         toAirport: String = "",
         homeBaseTimeZone: TimeZone = TimeZone(identifier: "Australia/Sydney")!) {

        self.id = id
        self.date = date
        self.dutyType = dutyType
        self.crewComplement = crewComplement
        self.restFacility = restFacility
        self.signOn = signOn
        self.signOff = signOff
        self.flightTime = flightTime
        self.simSessionTime = simSessionTime
        self.nightTime = nightTime
        self.sectors = sectors
        self.isInternational = isInternational
        self.hasActualINTime = hasActualINTime
        self.toAirport = toAirport

        // Calculate duty time (sign-on to sign-off) using standardized conversion
        self.dutyTime = signOff.timeIntervalSince(signOn).toDecimalHours

        // Classify time of day using HOME BASE local time
        self.timeClass = OperationTimeClass.classify(signOn: signOn, signOff: signOff, homeBaseTimeZone: homeBaseTimeZone)
    }
}

// MARK: - FRMS Cumulative Totals

/// Rolling totals for various time periods
public struct FRMSCumulativeTotals: Codable, Sendable {
    // Flight Time Totals
    public let flightTime7Days: Double
    public let flightTime28Or30Days: Double  // 28 days for 737, 30 days for A380/A330/B787
    public let flightTime365Days: Double

    // Duty Time Totals
    public let dutyTime7Days: Double
    public let dutyTime14Days: Double

    // Days Off
    public let daysOff28Days: Int

    // Consecutive Duty Info
    public let consecutiveDuties: Int
    public let consecutiveEarlyStarts: Int      // Sign-on before 0700
    public let consecutiveLateNights: Int

    // FD12.2a - Duty days in rolling 11-day period
    public let dutyDaysIn11Days: Int            // Max 9 days in any 11-day period

    // Fleet configuration for limit checking
    public let fleet: FRMSFleet

    public init(flightTime7Days: Double,
                flightTime28Or30Days: Double,
                flightTime365Days: Double,
                dutyTime7Days: Double,
                dutyTime14Days: Double,
                daysOff28Days: Int,
                consecutiveDuties: Int,
                consecutiveEarlyStarts: Int,
                consecutiveLateNights: Int,
                dutyDaysIn11Days: Int,
                fleet: FRMSFleet) {
        self.flightTime7Days = flightTime7Days
        self.flightTime28Or30Days = flightTime28Or30Days
        self.flightTime365Days = flightTime365Days
        self.dutyTime7Days = dutyTime7Days
        self.dutyTime14Days = dutyTime14Days
        self.daysOff28Days = daysOff28Days
        self.consecutiveDuties = consecutiveDuties
        self.consecutiveEarlyStarts = consecutiveEarlyStarts
        self.consecutiveLateNights = consecutiveLateNights
        self.dutyDaysIn11Days = dutyDaysIn11Days
        self.fleet = fleet
    }

    // MARK: - Consecutive Duty Limits (FD12.2 - A320/B737 Only)

    /// Whether consecutive duty tracking applies to this fleet
    public var hasConsecutiveDutyLimits: Bool {
        switch fleet {
        case .a320B737: return true
        case .a380A330B787: return false  // Widebody fleet does not have FD12.2 consecutive duty limits
        }
    }

    /// Maximum 6 consecutive duty days (FD12.2b - A320/B737 only)
    public var maxConsecutiveDuties: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 6
    }

    /// Maximum 4 consecutive early starts (FD13.6 - A320/B737 only)
    public var maxConsecutiveEarlyStarts: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 4
    }

    /// Maximum 4 consecutive late nights (FD14.1 - A320/B737 only)
    public var maxConsecutiveLateNights: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 4
    }

    /// Maximum 9 duty days in any 11-day period (FD12.2a - A320/B737 only)
    public var maxDutyDaysIn11Days: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 9
    }

    public func status7Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        // Only widebody has 7-day flight time limit
        guard let limit = fleet.maxFlightTime7Days else {
            return .compliant  // No limit for this fleet
        }

        if flightTime7Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) hours in 7 days")
        } else if flightTime7Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour limit")
        }
        return .compliant
    }

    public var status7Days: FRMSComplianceStatus {
        return status7Days(for: fleet)
    }

    public func status28Or30Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let limit = fleet.maxFlightTime28Days
        let periodDays = fleet.flightTimePeriodDays
        if flightTime28Or30Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) hours in \(periodDays) days")
        } else if flightTime28Or30Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour limit")
        }
        return .compliant
    }

    public var status28Days: FRMSComplianceStatus {
        return status28Or30Days(for: fleet)
    }

    public func status365Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let limit = fleet.maxFlightTime365Days
        if flightTime365Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) hours in 365 days")
        } else if flightTime365Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour limit")
        }
        return .compliant
    }

    public var status365Days: FRMSComplianceStatus {
        return status365Days(for: fleet)
    }

    public func dutyStatus7Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let limit = fleet.maxDutyTime7Days
        if dutyTime7Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) duty hours in 7 days")
        } else if dutyTime7Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour duty limit")
        }
        return .compliant
    }

    public var dutyStatus7Days: FRMSComplianceStatus {
        return dutyStatus7Days(for: fleet)
    }

    public func dutyStatus14Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let hardLimit = fleet.maxDutyTime14Days
        if dutyTime14Days > hardLimit {
            return .violation(message: "Exceeded \(Int(hardLimit)) duty hours in 14 days")
        }
        if let initialLimit = fleet.maxDutyTime14DaysInitial {
            // SH: warn when approaching or exceeding the 90 hr initial roster limit
            if dutyTime14Days > initialLimit {
                return .warning(message: "Exceeds \(Int(initialLimit))-hr initial limit — pilot agreement required")
            } else if dutyTime14Days > initialLimit * 0.9 {
                return .warning(message: "Approaching \(Int(initialLimit))-hour duty limit")
            }
        } else {
            if dutyTime14Days > hardLimit * 0.9 {
                return .warning(message: "Approaching \(Int(hardLimit))-hour duty limit")
            }
        }
        return .compliant
    }

    public var dutyStatus14Days: FRMSComplianceStatus {
        return dutyStatus14Days(for: fleet)
    }

    // MARK: - Consecutive Duty Status Checks (A320/B737 Only)

    public var consecutiveDutiesStatus: FRMSComplianceStatus {
        guard let limit = maxConsecutiveDuties else {
            return .compliant  // No limit for this fleet
        }
        if consecutiveDuties >= limit {
            return .violation(message: "Maximum \(limit) consecutive duty days reached")
        } else if consecutiveDuties >= limit - 1 {
            return .warning(message: "Approaching \(limit)-day consecutive duty limit")
        }
        return .compliant
    }

    public var consecutiveEarlyStartsStatus: FRMSComplianceStatus {
        guard let limit = maxConsecutiveEarlyStarts else {
            return .compliant  // No limit for this fleet
        }
        if consecutiveEarlyStarts >= limit {
            return .violation(message: "Maximum \(limit) consecutive early starts reached")
        } else if consecutiveEarlyStarts >= limit - 1 {
            return .warning(message: "Approaching \(limit) consecutive early start limit")
        }
        return .compliant
    }

    public var consecutiveLateNightsStatus: FRMSComplianceStatus {
        guard let limit = maxConsecutiveLateNights else {
            return .compliant  // No limit for this fleet
        }
        if consecutiveLateNights >= limit {
            return .violation(message: "Maximum \(limit) consecutive late nights reached")
        } else if consecutiveLateNights >= limit - 1 {
            return .warning(message: "Approaching \(limit) consecutive late night limit")
        }
        return .compliant
    }

    public var dutyDaysIn11DaysStatus: FRMSComplianceStatus {
        guard let limit = maxDutyDaysIn11Days else {
            return .compliant  // No limit for this fleet
        }
        if dutyDaysIn11Days >= limit {
            return .violation(message: "Maximum \(limit) duty days in 11-day period reached")
        } else if dutyDaysIn11Days >= limit - 1 {
            return .warning(message: "Approaching \(limit) duty days in 11-day period limit")
        }
        return .compliant
    }
}

// MARK: - Maximum Next Duty

/// Represents what the pilot can do in their next duty
public struct FRMSMaximumNextDuty: Codable, Sendable {
    public let maxDutyPeriod: Double           // Hours
    public let maxFlightTime: Double           // Hours
    public let maxSectors: Int
    public let minimumRest: Double             // Hours
    public let earliestSignOn: Date?
    public let restrictions: [String]
    public let limitType: FRMSLimitType

    // Sign-on time based limits (for A380/A330/B787 2-pilot ops)
    public let signOnBasedLimits: [SignOnTimeRange]?

    // Minimum Base Turnaround Time (MBTT) - applicable after returning to base
    public let mbtt: FRMSMinimumBaseTurnaroundTime?

    public init(maxDutyPeriod: Double,
                maxFlightTime: Double,
                maxSectors: Int,
                minimumRest: Double,
                earliestSignOn: Date?,
                restrictions: [String],
                limitType: FRMSLimitType,
                signOnBasedLimits: [SignOnTimeRange]?,
                mbtt: FRMSMinimumBaseTurnaroundTime?) {
        self.maxDutyPeriod = maxDutyPeriod
        self.maxFlightTime = maxFlightTime
        self.maxSectors = maxSectors
        self.minimumRest = minimumRest
        self.earliestSignOn = earliestSignOn
        self.restrictions = restrictions
        self.limitType = limitType
        self.signOnBasedLimits = signOnBasedLimits
        self.mbtt = mbtt
    }

    public var hasSevereRestrictions: Bool {
        maxDutyPeriod < 10 || maxFlightTime < 8
    }

    public var formattedMaxDutyPeriod: String {
        String(format: "%.1f hours", maxDutyPeriod)
    }

    public var formattedMaxFlightTime: String {
        String(format: "%.1f hours", maxFlightTime)
    }

    public var formattedMinimumRest: String {
        String(format: "%.1f hours", minimumRest)
    }
}

// MARK: - Sign-On Time Range Limits

/// Represents duty and flight time limits for a specific sign-on time range
public struct SignOnTimeRange: Codable, Sendable {
    public let timeRange: String               // e.g., "0500-0759" or rest facility name for augmented ops
    public let maxDutyPeriod: Double           // Hours (planning)
    public let maxDutyPeriodOperational: Double? // Hours (operational, if different)
    public let maxFlightTime: Double           // Hours (planning)
    public let maxFlightTimeOperational: Double? // Hours (operational, if different)
    public let preRestRequired: Double         // Hours (minimum/baseline)
    public let postRestRequired: Double        // Hours (minimum/baseline)
    public let notes: String?                  // e.g., "Max 8 hrs continuous & 14 hrs total on flight deck / 14 hrs total in flight deck"
    public let sectorLimit: String?            // e.g., "≤2 sectors if DP > 14 hrs"
    public let restFacility: CrewRestFacility? // nil for 2-pilot (sign-on window rows)

    public init(timeRange: String,
                maxDutyPeriod: Double,
                maxDutyPeriodOperational: Double?,
                maxFlightTime: Double,
                maxFlightTimeOperational: Double?,
                preRestRequired: Double,
                postRestRequired: Double,
                notes: String?,
                sectorLimit: String?,
                restFacility: CrewRestFacility?) {
        self.timeRange = timeRange
        self.maxDutyPeriod = maxDutyPeriod
        self.maxDutyPeriodOperational = maxDutyPeriodOperational
        self.maxFlightTime = maxFlightTime
        self.maxFlightTimeOperational = maxFlightTimeOperational
        self.preRestRequired = preRestRequired
        self.postRestRequired = postRestRequired
        self.notes = notes
        self.sectorLimit = sectorLimit
        self.restFacility = restFacility
    }

    public func getMaxDuty(for limitType: FRMSLimitType) -> Double {
        if limitType == .operational, let operational = maxDutyPeriodOperational {
            return operational
        }
        return maxDutyPeriod
    }

    public func getMaxFlight(for limitType: FRMSLimitType) -> Double {
        if limitType == .operational, let operational = maxFlightTimeOperational {
            return operational
        }
        return maxFlightTime
    }
}

// MARK: - Minimum Base Turnaround Time (MBTT)

/// Represents the minimum base turnaround time requirements
public struct FRMSMinimumBaseTurnaroundTime: Codable, Sendable {
    public let daysAway: Int?                  // Days away from base (if applicable)
    public let creditedFlightHours: Double?    // Credited flight hours in trip (if applicable)
    public let localNightsRequired: Int        // Number of local nights required at base
    public let minHours: Double?               // Minimum hours if not specified as nights (e.g., 12 hours for 1 day away)
    public let reason: String                  // Explanation of why this MBTT applies

    public init(daysAway: Int?,
                creditedFlightHours: Double?,
                localNightsRequired: Int,
                minHours: Double?,
                reason: String) {
        self.daysAway = daysAway
        self.creditedFlightHours = creditedFlightHours
        self.localNightsRequired = localNightsRequired
        self.minHours = minHours
        self.reason = reason
    }

    public var description: String {
        if let hours = minHours {
            return String(format: "%.0f hours", hours)
        } else {
            return "\(localNightsRequired) local night\(localNightsRequired == 1 ? "" : "s")"
        }
    }
}

// MARK: - FRMS Configuration

/// Settings for FRMS calculations
public struct FRMSConfiguration: Codable, Sendable {
    public var isEnabled: Bool           // FRMS Compliance is always enabled
    public var showFRMS: Bool            // Show FRMS tab (always visible)
    public var fleet: FRMSFleet
    public var homeBase: String          // e.g., "SYD", "MEL", "PER"
    public var defaultLimitType: FRMSLimitType  // Deprecated: kept for backward compatibility, always use .operational
    public var showWarningsAtPercentage: Double // e.g., 0.9 = warn at 90% of limit

    // Sign-on/Sign-off time margins (in minutes)
    public var signOnMinutesBeforeSTD: Int      // Minutes before scheduled departure for sign-on
    public var signOffMinutesAfterIN: Int       // Minutes after actual arrival for sign-off

    public init(isEnabled: Bool = true,
         showFRMS: Bool = true,
         fleet: FRMSFleet = .a320B737,
         homeBase: String = "SYD",
         defaultLimitType: FRMSLimitType = .operational,  // Always operational now
         showWarningsAtPercentage: Double = 0.9,
         signOnMinutesBeforeSTD: Int? = nil,
         signOffMinutesAfterIN: Int? = nil) {

        self.isEnabled = true  // Always enabled
        self.showFRMS = true   // Always visible
        self.fleet = fleet
        self.homeBase = homeBase
        self.defaultLimitType = .operational  // Always use operational limits
        self.showWarningsAtPercentage = showWarningsAtPercentage

        // Set fleet-specific defaults if not provided
        if let signOn = signOnMinutesBeforeSTD {
            self.signOnMinutesBeforeSTD = signOn
        } else {
            // Both fleets use 60 minutes
            self.signOnMinutesBeforeSTD = 60
        }

        if let signOff = signOffMinutesAfterIN {
            self.signOffMinutesAfterIN = signOff
        } else {
            // Fleet-specific defaults
            switch fleet {
            case .a320B737:
                self.signOffMinutesAfterIN = 15  // Narrowbody: 15 minutes
            case .a380A330B787:
                self.signOffMinutesAfterIN = 30  // Widebody: 30 minutes
            }
        }
    }

    /// Update sign-off time when fleet changes
    public mutating func updateSignOffForFleet() {
        switch fleet {
        case .a320B737:
            self.signOffMinutesAfterIN = 15
        case .a380A330B787:
            self.signOffMinutesAfterIN = 30
        }
    }
}
