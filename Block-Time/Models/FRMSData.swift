//
//  FRMSData.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) Data Models
//  Based on Qantas FRMS Ruleset Rev 4.1 (A320/B737) and Rev 4 (A380/A330/B787)
//

import Foundation

// MARK: - FRMS Fleet Type

enum FRMSFleet: String, Codable, CaseIterable, Sendable {
    case a320B737 = "A320/B737"
    case a380A330B787 = "A380/A330/B787"

    /// Short display name for UI (e.g., picker menus)
    var shortName: String {
        switch self {
        case .a320B737: return "Shorthaul"
        case .a380A330B787: return "Longhaul"
        }
    }

    /// Full description for subtext
    var fullDescription: String {
        return self.rawValue
    }

    var maxFlightTime7Days: Double? {
        switch self {
        case .a320B737: return nil  // No 7-day flight time limit for narrowbody
        case .a380A330B787: return 30.0
        }
    }

    var maxFlightTime28Days: Double {
        switch self {
        case .a320B737: return 100.0
        case .a380A330B787: return 100.0  // Actually uses 30 days, but limit is still 100
        }
    }

    /// Returns the rolling period in days for flight time limits (28 or 30)
    var flightTimePeriodDays: Int {
        switch self {
        case .a320B737: return 28
        case .a380A330B787: return 30
        }
    }

    var maxFlightTime365Days: Double {
        switch self {
        case .a320B737: return 1000.0
        case .a380A330B787: return 900.0
        }
    }

    var maxDutyTime7Days: Double {
        switch self {
        case .a320B737: return 60.0
        case .a380A330B787: return 60.0  // FD6.4.2: 60 hours in any consecutive 7 days
        }
    }

    var maxDutyTime14Days: Double {
        switch self {
        case .a320B737: return 100.0  // Can be extended from 90 with agreement
        case .a380A330B787: return 100.0  // FD6.4.3: 100 hours in any consecutive 14 days
        }
    }
}

// MARK: - Crew Complement

enum CrewComplement: Int, Codable, Sendable {
    case twoPilot = 2
    case threePilot = 3
    case fourPilot = 4

    var description: String {
        "\(rawValue) Pilot"
    }
}

// MARK: - Rest Facility Class (for augmented operations)

enum RestFacilityClass: String, Codable, Sendable {
    case none           // 2-pilot operations
    case class2         // Seat in cabin with full screen
    case class1         // Bunk or berth
    case mixed          // 1x Class1 + 1x Class2

    var description: String {
        switch self {
        case .class1: return "Class 1 Rest"
        case .class2: return "Class 2 Rest"
        case .mixed: return "Mixed (Class 1 & 2)"
        case .none: return "No Rest Facility"
        }
    }
}

// MARK: - Duty Type

enum DutyType: String, Codable, Sendable {
    case operating      // Flying as operating crew
    case deadheading    // Positioning flight
    case standby        // On standby duty
    case simulator      // Simulator training
    case ground         // Ground duties/admin

    var icon: String {
        switch self {
        case .operating: return "airplane"
        case .deadheading: return "airplane.departure"
        case .standby: return "clock"
        case .simulator: return "gamecontroller"
        case .ground: return "building.2"
        }
    }
}

// MARK: - Operation Time of Day Classification

enum OperationTimeClass: String, Codable, Sendable {
    case day            // Not a late night operation
    case lateNight      // Contains >30 min between 2300-0530
    case backOfClock    // Contains 2+ hours between 0100-0459

    /// Determines time class from duty period using HOME BASE local time
    /// - Parameters:
    ///   - signOn: Sign-on time in UTC
    ///   - signOff: Sign-off time in UTC
    ///   - homeBaseTimeZone: The timezone of the crew's home base (e.g., Australia/Sydney, Australia/Perth)
    /// - Returns: The operation time class (day, lateNight, or backOfClock)
    static func classify(signOn: Date, signOff: Date, homeBaseTimeZone: TimeZone) -> OperationTimeClass {
        // Create calendar with home base timezone
        var calendar = Calendar.current
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
        var calendar = Calendar.current
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

enum FRMSLimitType: String, Codable {
    case planning       // Scheduled limits (roster planning)
    case operational    // Actual limits (with pilot discretion to extend)

    var description: String {
        switch self {
        case .planning: return "Planning Limits"
        case .operational: return "Operational Limits"
        }
    }
}

// MARK: - FRMS Compliance Status

enum FRMSComplianceStatus: Codable, Sendable {
    case compliant              // Within limits
    case warning(message: String)  // Approaching limits
    case violation(message: String) // Exceeds limits

    var color: String {
        switch self {
        case .compliant: return "green"
        case .warning: return "orange"
        case .violation: return "red"
        }
    }

    var icon: String {
        switch self {
        case .compliant: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .violation: return "xmark.circle.fill"
        }
    }
}

// MARK: - FRMS Duty Summary

/// Represents a complete duty period for FRMS calculations
struct FRMSDuty: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let dutyType: DutyType
    let crewComplement: CrewComplement
    let restFacility: RestFacilityClass
    let signOn: Date
    let signOff: Date
    let flightTime: Double          // Hours
    let dutyTime: Double            // Hours
    let nightTime: Double           // Hours of flight time in darkness
    let sectors: Int
    let timeClass: OperationTimeClass
    let isInternational: Bool

    init(id: UUID = UUID(),
         date: Date,
         dutyType: DutyType,
         crewComplement: CrewComplement,
         restFacility: RestFacilityClass = .none,
         signOn: Date,
         signOff: Date,
         flightTime: Double,
         nightTime: Double = 0,
         sectors: Int,
         isInternational: Bool = false,
         homeBaseTimeZone: TimeZone = TimeZone(identifier: "Australia/Sydney")!) {

        self.id = id
        self.date = date
        self.dutyType = dutyType
        self.crewComplement = crewComplement
        self.restFacility = restFacility
        self.signOn = signOn
        self.signOff = signOff
        self.flightTime = flightTime
        self.nightTime = nightTime
        self.sectors = sectors
        self.isInternational = isInternational

        // Calculate duty time (sign-on to sign-off) using standardized conversion
        self.dutyTime = signOff.timeIntervalSince(signOn).toDecimalHours

        // Classify time of day using HOME BASE local time
        self.timeClass = OperationTimeClass.classify(signOn: signOn, signOff: signOff, homeBaseTimeZone: homeBaseTimeZone)
    }
}

// MARK: - FRMS Cumulative Totals

/// Rolling totals for various time periods
struct FRMSCumulativeTotals: Codable, Sendable {
    // Flight Time Totals
    let flightTime7Days: Double
    let flightTime28Or30Days: Double  // 28 days for 737, 30 days for A380/A330/B787
    let flightTime365Days: Double

    // Duty Time Totals
    let dutyTime7Days: Double
    let dutyTime14Days: Double

    // Days Off
    let daysOff28Days: Int

    // Consecutive Duty Info
    let consecutiveDuties: Int
    let consecutiveEarlyStarts: Int      // Sign-on before 0700
    let consecutiveLateNights: Int

    // FD12.2a - Duty days in rolling 11-day period
    let dutyDaysIn11Days: Int            // Max 9 days in any 11-day period

    // Fleet configuration for limit checking
    let fleet: FRMSFleet

    // MARK: - Consecutive Duty Limits (FD12.2 - A320/B737 Only)

    /// Whether consecutive duty tracking applies to this fleet
    var hasConsecutiveDutyLimits: Bool {
        switch fleet {
        case .a320B737: return true
        case .a380A330B787: return false  // Widebody fleet does not have FD12.2 consecutive duty limits
        }
    }

    /// Maximum 6 consecutive duty days (FD12.2b - A320/B737 only)
    var maxConsecutiveDuties: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 6
    }

    /// Maximum 4 consecutive early starts (FD13.6 - A320/B737 only)
    var maxConsecutiveEarlyStarts: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 4
    }

    /// Maximum 4 consecutive late nights (FD14.1 - A320/B737 only)
    var maxConsecutiveLateNights: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 4
    }

    /// Maximum 9 duty days in any 11-day period (FD12.2a - A320/B737 only)
    var maxDutyDaysIn11Days: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 9
    }

    func status7Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
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

    var status7Days: FRMSComplianceStatus {
        return status7Days(for: fleet)
    }

    func status28Or30Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let limit = fleet.maxFlightTime28Days
        let periodDays = fleet.flightTimePeriodDays
        if flightTime28Or30Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) hours in \(periodDays) days")
        } else if flightTime28Or30Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour limit")
        }
        return .compliant
    }

    var status28Days: FRMSComplianceStatus {
        return status28Or30Days(for: fleet)
    }

    func status365Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let limit = fleet.maxFlightTime365Days
        if flightTime365Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) hours in 365 days")
        } else if flightTime365Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour limit")
        }
        return .compliant
    }

    var status365Days: FRMSComplianceStatus {
        return status365Days(for: fleet)
    }

    func dutyStatus7Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let limit = fleet.maxDutyTime7Days
        if dutyTime7Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) duty hours in 7 days")
        } else if dutyTime7Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour duty limit")
        }
        return .compliant
    }

    var dutyStatus7Days: FRMSComplianceStatus {
        return dutyStatus7Days(for: fleet)
    }

    func dutyStatus14Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let limit = fleet.maxDutyTime14Days
        if dutyTime14Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) duty hours in 14 days")
        } else if dutyTime14Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour duty limit")
        }
        return .compliant
    }

    var dutyStatus14Days: FRMSComplianceStatus {
        return dutyStatus14Days(for: fleet)
    }

    // MARK: - Consecutive Duty Status Checks (A320/B737 Only)

    var consecutiveDutiesStatus: FRMSComplianceStatus {
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

    var consecutiveEarlyStartsStatus: FRMSComplianceStatus {
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

    var consecutiveLateNightsStatus: FRMSComplianceStatus {
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

    var dutyDaysIn11DaysStatus: FRMSComplianceStatus {
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
struct FRMSMaximumNextDuty: Codable, Sendable {
    let maxDutyPeriod: Double           // Hours
    let maxFlightTime: Double           // Hours
    let maxSectors: Int
    let minimumRest: Double             // Hours
    let earliestSignOn: Date?
    let restrictions: [String]
    let limitType: FRMSLimitType

    // Sign-on time based limits (for A380/A330/B787 2-pilot ops)
    let signOnBasedLimits: [SignOnTimeRange]?

    // Minimum Base Turnaround Time (MBTT) - applicable after returning to base
    let mbtt: FRMSMinimumBaseTurnaroundTime?

    var hasSevereRestrictions: Bool {
        maxDutyPeriod < 10 || maxFlightTime < 8
    }

    var formattedMaxDutyPeriod: String {
        String(format: "%.1f hours", maxDutyPeriod)
    }

    var formattedMaxFlightTime: String {
        String(format: "%.1f hours", maxFlightTime)
    }

    var formattedMinimumRest: String {
        String(format: "%.1f hours", minimumRest)
    }
}

// MARK: - Sign-On Time Range Limits

/// Represents duty and flight time limits for a specific sign-on time range
struct SignOnTimeRange: Codable {
    let timeRange: String               // e.g., "0500-0759" or rest facility name for augmented ops
    let maxDutyPeriod: Double           // Hours (planning)
    let maxDutyPeriodOperational: Double? // Hours (operational, if different)
    let maxFlightTime: Double           // Hours (planning)
    let maxFlightTimeOperational: Double? // Hours (operational, if different)
    let preRestRequired: Double         // Hours (minimum/baseline)
    let postRestRequired: Double        // Hours (minimum/baseline)
    let notes: String?                  // e.g., "Max 8 hrs continuous & 14 hrs total on flight deck / 14 hrs total in flight deck"
    let sectorLimit: String?            // e.g., "≤2 sectors if DP > 14 hrs"
    let restFacility: CrewRestFacility? // nil for 2-pilot (sign-on window rows)

    func getMaxDuty(for limitType: FRMSLimitType) -> Double {
        if limitType == .operational, let operational = maxDutyPeriodOperational {
            return operational
        }
        return maxDutyPeriod
    }

    func getMaxFlight(for limitType: FRMSLimitType) -> Double {
        if limitType == .operational, let operational = maxFlightTimeOperational {
            return operational
        }
        return maxFlightTime
    }
}

// MARK: - Minimum Base Turnaround Time (MBTT)

/// Represents the minimum base turnaround time requirements
struct FRMSMinimumBaseTurnaroundTime: Codable {
    let daysAway: Int?                  // Days away from base (if applicable)
    let creditedFlightHours: Double?    // Credited flight hours in trip (if applicable)
    let localNightsRequired: Int        // Number of local nights required at base
    let minHours: Double?               // Minimum hours if not specified as nights (e.g., 12 hours for 1 day away)
    let reason: String                  // Explanation of why this MBTT applies

    var description: String {
        if let hours = minHours {
            return String(format: "%.0f hours", hours)
        } else {
            return "\(localNightsRequired) local night\(localNightsRequired == 1 ? "" : "s")"
        }
    }
}

// MARK: - Daily Duty Summary

/// Represents a day's worth of duties grouped together
struct DailyDutySummary: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date                  // Local date at home base
    let duties: [FRMSDuty]
    let totalFlightTime: Double     // Sum of all flight times for the day
    let totalDutyTime: Double       // Continuous duty period: earliest sign-on to latest sign-off
    let totalSectors: Int           // Total number of sectors
    let earliestSignOn: Date?       // Earliest sign-on time
    let latestSignOff: Date?        // Latest sign-off time

    init(date: Date, duties: [FRMSDuty]) {
        self.id = UUID()
        self.date = date
        self.duties = duties
        self.totalFlightTime = duties.reduce(0.0) { $0 + $1.flightTime }
        self.totalSectors = duties.reduce(0) { $0 + $1.sectors }
        self.earliestSignOn = duties.map { $0.signOn }.min()
        self.latestSignOff = duties.map { $0.signOff }.max()

        // Calculate duty time as continuous period from earliest sign-on to latest sign-off
        // This is the correct FRMS calculation (not sum of individual duties)
        if let earliest = self.earliestSignOn, let latest = self.latestSignOff {
            self.totalDutyTime = latest.timeIntervalSince(earliest).toDecimalHours
        } else {
            self.totalDutyTime = 0.0
        }
    }
}

// MARK: - A320/B737 Next Duty Limits

/// Sign-on time window with duty and flight limits
/// This structure wraps SH_Operational_FltDuty and SH_Planning_FltDuty rules for UI display
struct DutyTimeWindow: Codable {
    let timeRange: String           // e.g., "0500-1459"
    let displayName: String         // e.g., "Early Morning"
    let startHour: Int              // e.g., 5 for 0500
    let endHour: Int                // e.g., 14 for 1459 (use 24 for wraparound)
    let localStartTime: String      // Maps to SH_Operational_FltDuty.LocalStartTime rawValue
    let isCurrentlyAvailable: Bool  // Based on earliest sign-on time
    let limitType: FRMSLimitType    // Planning or Operational

    // Computed property that pulls limits from SH_Operational_FltDuty or SH_Planning_FltDuty
    var limits: DutyLimits {
        DutyLimits(localStartTime: localStartTime, limitType: limitType)
    }
}

/// Duty and flight time limits for different sector counts
/// Supports both OPERATIONAL and PLANNING limits from SH_Operational_FltDuty and SH_Planning_FltDuty
struct DutyLimits: Codable {
    let localStartTime: String      // SH_Operational_FltDuty.LocalStartTime rawValue
    let limitType: FRMSLimitType    // Planning or Operational

    // MARK: - Operational Limits (from SH_Operational_FltDuty - FD23)

    private var operationalMaxDutySectors1to4: Double {
        guard let startTime = SH_Operational_FltDuty.LocalStartTime(rawValue: localStartTime),
              let dutyLimit = SH_Operational_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 12.0  // Fallback
        }
        return dutyLimit.maxDutySectors1to4
    }

    private var operationalMaxDutySectors5: Double {
        guard let startTime = SH_Operational_FltDuty.LocalStartTime(rawValue: localStartTime),
              let dutyLimit = SH_Operational_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 12.0  // Fallback
        }
        return dutyLimit.maxDutySectors5
    }

    private var operationalMaxDutySectors6: Double {
        guard let startTime = SH_Operational_FltDuty.LocalStartTime(rawValue: localStartTime),
              let dutyLimit = SH_Operational_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 11.0  // Fallback
        }
        return dutyLimit.maxDutySectors6
    }

    // MARK: - Planning Limits (from SH_Planning_FltDuty - FD13)

    private var planningMaxDutySectors1to4: Double {
        guard let startTime = SH_Planning_FltDuty.LocalStartTime(rawValue: localStartTime),
              let limit = SH_Planning_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 10.0  // Fallback
        }
        return limit.maxDutySectors1to4
    }

    private var planningMaxDutySectors5or6: Double {
        guard let startTime = SH_Planning_FltDuty.LocalStartTime(rawValue: localStartTime),
              let limit = SH_Planning_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 10.0  // Fallback
        }
        return limit.maxDutySectors5or6
    }

    // MARK: - Public Interface (returns appropriate limit based on limitType)

    var maxDutySectors1to4: Double {
        limitType == .operational ? operationalMaxDutySectors1to4 : planningMaxDutySectors1to4
    }

    var maxDutySectors5: Double {
        limitType == .operational ? operationalMaxDutySectors5 : planningMaxDutySectors5or6
    }

    var maxDutySectors6: Double {
        limitType == .operational ? operationalMaxDutySectors6 : planningMaxDutySectors5or6
    }

    /// Maximum flight time with darkness conditional
    /// Returns: "10h (9.5h if >7h darkness)" or "10.5h (9.5h if >7h darkness)"
    var maxFlightTimeDescription: String {
        if limitType == .operational {
            // FD23.3: Multi-sector: 10h, Single-sector: 10.5h, >7h darkness: 9.5h
            return "10.5 hrs (1 Sector) or 10 hrs (Multi Sectors) or 9.5hrs (> 7 hrs night)"
        } else {
            // FD13.3: Planning limits are more restrictive
            return "10 hrs (9.5 hrs if >7 hrs night)"
        }
    }

    /// Base maximum flight time (without darkness consideration)
    var maxFlightTime: Double {
        if limitType == .operational {
            return 10.5  // Single sector max (FD23.3)
        } else {
            return 10.0  // Planning limit (FD13.3)
        }
    }

    func maxDuty(forSectors sectors: Int) -> Double {
        if sectors >= 6 {
            return maxDutySectors6
        } else if sectors >= 5 {
            return maxDutySectors5
        } else {
            return maxDutySectors1to4
        }
    }
}

/// Back of clock operation restriction
struct BackOfClockRestriction: Codable {
    let earliestSignOn: Date        // 1000 local time restriction
    let reason: String
    let appliesTo: String           // "Australia only" or "All operations"
}

/// Late night operation status and restrictions
struct LateNightStatus: Codable {
    let consecutiveLateNights: Int
    let maxConsecutiveLateNights: Int     // 4 normally, 5 if exception used
    let dutyHoursIn7Nights: Double
    let maxDutyHoursIn7Nights: Double     // 40 hours
    let canUse5NightException: Bool       // Once per 28 days
    let recoveryOption: LateNightRecoveryOption
}

enum LateNightRecoveryOption: String, Codable {
    case continueOnLateNights = "Continue on late night operations"
    case require24HoursOff = "Require ≥24 hours off before day duty"
    case noRestriction = "No restriction"
}

/// Consecutive duty tracking
struct ConsecutiveDutyStatus: Codable {
    let consecutiveDuties: Int
    let maxConsecutiveDuties: Int           // 6
    let dutyDaysIn11Days: Int
    let maxDutyDaysIn11Days: Int           // 9
    let consecutiveEarlyStarts: Int
    let maxConsecutiveEarlyStarts: Int     // 4

    var hasActiveRestrictions: Bool {
        consecutiveDuties >= maxConsecutiveDuties ||
        dutyDaysIn11Days >= maxDutyDaysIn11Days ||
        consecutiveEarlyStarts >= maxConsecutiveEarlyStarts
    }
}

/// Pattern end requirement (for 1-2 or 3-4 day patterns)
struct PatternEndRequirement: Codable {
    let patternDays: Int                   // 1-2 or 3-4
    let minimumRestHours: Double           // 12 or 15
    let reason: String
}

/// Weekly rest requirement status
struct WeeklyRestStatus: Codable {
    let hasRequired36Hours: Bool           // ≥36 consecutive hours in any 7 days
    let hasRequired2Nights: Bool           // 2 consecutive local nights in any 8 nights
    let nextRequiredBy: Date?              // When next rest is required
    let isCompliant: Bool
}

/// Rest calculation with breakdown
struct RestCalculationBreakdown: Codable {
    let previousDutyHours: Double
    let formula: String                    // e.g., "12 + (1.5 × 1.5)"
    let minimumRestHours: Double
    let reducedRestAvailable: Bool
    let reducedRestConditions: String?     // e.g., "9 hrs if previous duty ≤10hrs and rest includes 2200-0600"
}

/// Special scenario restrictions and requirements
struct SpecialScenarios: Codable {
    let simulatorRestrictions: SimulatorRestrictions?
    let daysOffRequirements: DaysOffRequirements?
    let annualLeaveRestrictions: AnnualLeaveRestrictions?
    let reserveDutyRules: ReserveDutyRules?
    let deadheadingLimitations: DeadheadingLimitations?
}

/// Simulator training restrictions
struct SimulatorRestrictions: Codable {
    let dayBeforeRestriction: String?          // e.g., "Sign-off ≤2000 day before simulator (Australia)"
    let restBeforeSimulator: Double?           // Hours required before simulator
    let sameDayProhibition: String?            // e.g., "Cannot have 2 duty periods in same 24-hour period"
    let applicableRegion: String               // "Australia", "New Zealand", or "All"
}

/// Days off (X Days) requirements
struct DaysOffRequirements: Codable {
    let dutyBeforeXDay: String                 // e.g., "Complete ≤2230 local"
    let dutyAfterXDay: String                  // e.g., "Earliest sign-on 0500 local"
    let minimumDuration: Double                // Hours (e.g., 36)
    let operationalException: String?          // e.g., "May extend to 2300 for disruptions"
}

/// Annual leave adjacency restrictions
struct AnnualLeaveRestrictions: Codable {
    let beforeLeaveRestriction: String         // e.g., "Latest duty end: 2000 day before"
    let afterLeaveRestriction: String          // e.g., "Earliest duty start: 0800 day after"
    let minimumLeaveDays: Int?                 // e.g., 7 days for NZ crew
    let canWaive: Bool                         // Whether pilot can agree to waive
    let applicableRegion: String               // "Australia", "New Zealand", or "All"
}

/// Reserve duty rules
struct ReserveDutyRules: Codable {
    let afterCalloutRest: String               // e.g., "MAX(12 hours, actual duty length)"
    let withoutCalloutRest: String             // e.g., "10 hours free of all duty"
    let betweenReservePeriods: String          // e.g., "MAX(12 hours, previous duty length)"
}

/// Deadheading after flight duty limitations
struct DeadheadingLimitations: Codable {
    let absoluteMaximum: Double                // Total duty including deadheading (e.g., 16 hours)
    let restCalculationNote: String            // e.g., "Deadheading included in duty for rest calculation"
    let sectorCountingRule: String             // e.g., "Last sector deadheading doesn't count"
}

/// What-If scenario for compliance checking
struct WhatIfScenario: Codable {
    let proposedSignOn: Date
    let estimatedSectors: Int
    let estimatedDutyHours: Double
    let estimatedFlightHours: Double

    var isValid: Bool {
        estimatedSectors > 0 && estimatedDutyHours > 0 && estimatedFlightHours > 0
    }
}

/// Result of What-If scenario check
struct WhatIfResult: Codable {
    let scenario: WhatIfScenario
    let isCompliant: Bool
    let complianceStatus: FRMSComplianceStatus
    let violations: [String]
    let warnings: [String]
    let applicableWindow: DutyTimeWindow?
}

/// Complete A320/B737 next duty limitations
struct A320B737NextDutyLimits: Codable, Sendable {
    // Sign-on time windows
    let earlyWindow: DutyTimeWindow        // 0500-1459
    let afternoonWindow: DutyTimeWindow    // 1500-1959
    let nightWindow: DutyTimeWindow        // 2000-0459

    // Active restrictions
    let backOfClockRestriction: BackOfClockRestriction?
    let lateNightStatus: LateNightStatus?
    let consecutiveDutyStatus: ConsecutiveDutyStatus

    // Rest requirements
    let restCalculation: RestCalculationBreakdown
    let earliestSignOn: Date

    // Pattern and weekly rest
    let patternEndRequirement: PatternEndRequirement?
    let weeklyRestStatus: WeeklyRestStatus

    // Special scenarios
    let specialScenarios: SpecialScenarios

    // Overall status
    let overallStatus: FRMSComplianceStatus
}

// MARK: - FRMS Configuration

/// Settings for FRMS calculations
struct FRMSConfiguration: Codable, Sendable {
    var isEnabled: Bool = true           // FRMS Compliance is always enabled
    var showFRMS: Bool = true            // Show FRMS tab (always visible)
    var fleet: FRMSFleet
    var homeBase: String                 // e.g., "SYD", "MEL", "PER"
    var defaultLimitType: FRMSLimitType  // Deprecated: kept for backward compatibility, always use .operational
    var showWarningsAtPercentage: Double // e.g., 0.9 = warn at 90% of limit

    // Sign-on/Sign-off time margins (in minutes)
    var signOnMinutesBeforeSTD: Int      // Minutes before scheduled departure for sign-on
    var signOffMinutesAfterIN: Int       // Minutes after actual arrival for sign-off

    init(isEnabled: Bool = true,
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
    mutating func updateSignOffForFleet() {
        switch fleet {
        case .a320B737:
            self.signOffMinutesAfterIN = 15
        case .a380A330B787:
            self.signOffMinutesAfterIN = 30
        }
    }
}
