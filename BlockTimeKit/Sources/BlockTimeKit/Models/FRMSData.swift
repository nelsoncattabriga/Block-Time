//
//  FRMSData.swift
//
//  FRMS (Fatigue Risk Management System) Data Models
//  Based on Qantas FRMS Ruleset Rev 4.1 (A320/B737) and Rev 4 (A380/A330/B787)
//

import Foundation

// MARK: - FRMS Fleet Type

public enum FRMSFleet: String, Codable, CaseIterable, Sendable {
    case a320B737 = "A320/B737"
    case a380A330B787 = "A380/A330/B787"

    public var shortName: String {
        switch self {
        case .a320B737: return "Shorthaul"
        case .a380A330B787: return "Longhaul"
        }
    }

    public var fullDescription: String {
        return self.rawValue
    }

    public var maxFlightTime7Days: Double? {
        switch self {
        case .a320B737: return nil
        case .a380A330B787: return 30.0
        }
    }

    public var maxFlightTime28Days: Double {
        switch self {
        case .a320B737: return 100.0
        case .a380A330B787: return 100.0
        }
    }

    public var flightTimePeriodDays: Int {
        switch self {
        case .a320B737: return 28
        case .a380A330B787: return 28
        }
    }

    public var maxFlightTime365Days: Double {
        switch self {
        case .a320B737: return 1000.0
        case .a380A330B787: return 1000.0
        }
    }

    public var maxDutyTime7Days: Double {
        switch self {
        case .a320B737: return 60.0
        case .a380A330B787: return 60.0
        }
    }

    public var maxDutyTime14DaysInitial: Double? {
        switch self {
        case .a320B737: return 90.0
        case .a380A330B787: return nil
        }
    }

    public var maxDutyTime14Days: Double {
        switch self {
        case .a320B737: return 100.0
        case .a380A330B787: return 100.0
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
    case none
    case class2
    case class1
    case mixed
    case oneClass2OneSeat
    case oneClass1OneSeat

    public var description: String {
        switch self {
        case .class1:           return "Class 1 Rest"
        case .class2:           return "Class 2 Rest"
        case .mixed:            return "Mixed (Class 1 & 2)"
        case .none:             return "No Rest Facility"
        case .oneClass2OneSeat: return "1× Class 2 & Seat in Pax"
        case .oneClass1OneSeat: return "1× Class 1 & Seat in Pax"
        }
    }
}

// MARK: - Duty Type

public enum DutyType: String, Codable, Sendable {
    case operating
    case deadheading
    case standby
    case simulator
    case instructor
    case ground

    public var icon: String {
        switch self {
        case .operating:    return "airplane"
        case .deadheading:  return "airplane.departure"
        case .standby:      return "clock"
        case .simulator:    return "gamecontroller"
        case .instructor:   return "person.fill.checkmark"
        case .ground:       return "building.2"
        }
    }
}

// MARK: - Operation Time of Day Classification

public enum OperationTimeClass: String, Codable, Sendable {
    case day
    case lateNight
    case backOfClock

    public static func classify(signOn: Date, signOff: Date, homeBaseTimeZone: TimeZone) -> OperationTimeClass {
        var calendar = Calendar.current
        calendar.timeZone = homeBaseTimeZone

        var hasLateNight = false
        var backOfClockMinutes = 0

        var currentTime = signOn
        while currentTime < signOff {
            let hour = calendar.component(.hour, from: currentTime)
            let minute = calendar.component(.minute, from: currentTime)

            if hour >= 23 || hour < 5 || (hour == 5 && minute < 30) {
                hasLateNight = true
            }

            if hour >= 1 && hour < 5 {
                let nextTime = calendar.date(byAdding: .minute, value: 1, to: currentTime) ?? currentTime
                if nextTime <= signOff {
                    backOfClockMinutes += 1
                }
            }

            currentTime = calendar.date(byAdding: .minute, value: 1, to: currentTime) ?? currentTime
        }

        if backOfClockMinutes >= 120 {
            return .backOfClock
        }

        if hasLateNight {
            let lateNightDuration = calculateLateNightDuration(signOn: signOn, signOff: signOff, homeBaseTimeZone: homeBaseTimeZone)
            if lateNightDuration > 0.5 {
                return .lateNight
            }
        }

        return .day
    }

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

public enum FRMSLimitType: String, Codable, Sendable {
    case planning
    case operational

    public var description: String {
        switch self {
        case .planning:    return "Planning Limits"
        case .operational: return "Operational Limits"
        }
    }
}

// MARK: - FRMS Compliance Status

public enum FRMSComplianceStatus: Codable, Sendable {
    case compliant
    case warning(message: String)
    case violation(message: String)

    public var color: String {
        switch self {
        case .compliant:  return "green"
        case .warning:    return "orange"
        case .violation:  return "red"
        }
    }

    public var icon: String {
        switch self {
        case .compliant:  return "checkmark.circle.fill"
        case .warning:    return "exclamationmark.triangle.fill"
        case .violation:  return "xmark.circle.fill"
        }
    }
}

// MARK: - FRMS Duty Summary

public struct FRMSDuty: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let dutyType: DutyType
    public let crewComplement: CrewComplement
    public let restFacility: RestFacilityClass
    public let signOn: Date
    public let signOff: Date
    public let flightTime: Double
    public let simSessionTime: Double
    public let dutyTime: Double
    public let nightTime: Double
    public let sectors: Int
    public let timeClass: OperationTimeClass
    public let isInternational: Bool
    public let hasActualINTime: Bool
    public let toAirport: String

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
        self.dutyTime = signOff.timeIntervalSince(signOn).toDecimalHours
        self.timeClass = OperationTimeClass.classify(signOn: signOn, signOff: signOff, homeBaseTimeZone: homeBaseTimeZone)
    }
}

// MARK: - FRMS Cumulative Totals

public struct FRMSCumulativeTotals: Codable, Sendable {
    public let flightTime7Days: Double
    public let flightTime28Or30Days: Double
    public let flightTime365Days: Double
    public let dutyTime7Days: Double
    public let dutyTime14Days: Double
    public let daysOff28Days: Int
    public let consecutiveDuties: Int
    public let consecutiveEarlyStarts: Int
    public let consecutiveLateNights: Int
    public let dutyDaysIn11Days: Int
    public let fleet: FRMSFleet
    public let homeBase: String

    public init(flightTime7Days: Double, flightTime28Or30Days: Double, flightTime365Days: Double,
                dutyTime7Days: Double, dutyTime14Days: Double, daysOff28Days: Int,
                consecutiveDuties: Int, consecutiveEarlyStarts: Int, consecutiveLateNights: Int,
                dutyDaysIn11Days: Int, fleet: FRMSFleet, homeBase: String) {
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
        self.homeBase = homeBase
    }

    public var hasConsecutiveDutyLimits: Bool {
        switch fleet {
        case .a320B737:       return true
        case .a380A330B787:   return false
        }
    }

    public var maxConsecutiveDuties: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 6
    }

    public var maxConsecutiveEarlyStarts: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 4
    }

    public var maxConsecutiveLateNights: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return SH_Planning_FltDuty.lnoConsecutiveTriggerCount + 1
    }

    public var maxDutyDaysIn11Days: Int? {
        guard hasConsecutiveDutyLimits else { return nil }
        return 9
    }

    public func status7Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        guard let limit = fleet.maxFlightTime7Days else { return .compliant }
        if flightTime7Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) hours in 7 days")
        } else if flightTime7Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour limit")
        }
        return .compliant
    }

    public var status7Days: FRMSComplianceStatus { status7Days(for: fleet) }

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

    public var status28Days: FRMSComplianceStatus { status28Or30Days(for: fleet) }

    public func status365Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let limit = fleet.maxFlightTime365Days
        if flightTime365Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) hours in 365 days")
        } else if flightTime365Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour limit")
        }
        return .compliant
    }

    public var status365Days: FRMSComplianceStatus { status365Days(for: fleet) }

    public func dutyStatus7Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let limit = homeBase == "NZ" ? SH_NZ_Planning_FltDuty.cumulativeDutyTime7DaysHours : fleet.maxDutyTime7Days
        if dutyTime7Days > limit {
            return .violation(message: "Exceeded \(Int(limit)) duty hours in 7 days")
        } else if dutyTime7Days > (limit * 0.9) {
            return .warning(message: "Approaching \(Int(limit))-hour duty limit")
        }
        return .compliant
    }

    public var dutyStatus7Days: FRMSComplianceStatus { dutyStatus7Days(for: fleet) }

    public func dutyStatus14Days(for fleet: FRMSFleet) -> FRMSComplianceStatus {
        let hardLimit = fleet.maxDutyTime14Days
        if dutyTime14Days > hardLimit {
            return .violation(message: "Exceeded \(Int(hardLimit)) duty hours in 14 days")
        }
        let initialLimit: Double?
        if homeBase == "NZ" {
            initialLimit = SH_NZ_Planning_FltDuty.cumulativeDutyTime14DaysInitialHours
        } else {
            initialLimit = fleet.maxDutyTime14DaysInitial
        }
        if let initialLimit {
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

    public var dutyStatus14Days: FRMSComplianceStatus { dutyStatus14Days(for: fleet) }

    public var consecutiveDutiesStatus: FRMSComplianceStatus {
        guard let limit = maxConsecutiveDuties else { return .compliant }
        if consecutiveDuties >= limit {
            return .violation(message: "Maximum \(limit) consecutive duty days reached")
        } else if consecutiveDuties >= limit - 1 {
            return .warning(message: "Approaching \(limit)-day consecutive duty limit")
        }
        return .compliant
    }

    public var consecutiveEarlyStartsStatus: FRMSComplianceStatus {
        guard let limit = maxConsecutiveEarlyStarts else { return .compliant }
        if consecutiveEarlyStarts >= limit {
            return .violation(message: "Maximum \(limit) consecutive early starts reached")
        } else if consecutiveEarlyStarts >= limit - 1 {
            return .warning(message: "Approaching \(limit) consecutive early start limit")
        }
        return .compliant
    }

    public var consecutiveLateNightsStatus: FRMSComplianceStatus {
        guard let limit = maxConsecutiveLateNights else { return .compliant }
        if consecutiveLateNights >= limit {
            return .violation(message: "\(consecutiveLateNights) consecutive late nights — 24 h free of duty required")
        } else if consecutiveLateNights >= limit - 1 {
            return .warning(message: "\(consecutiveLateNights) consecutive late nights — next LNO triggers 24 h rest")
        }
        return .compliant
    }

    public var dutyDaysIn11DaysStatus: FRMSComplianceStatus {
        guard let limit = maxDutyDaysIn11Days else { return .compliant }
        if dutyDaysIn11Days >= limit {
            return .violation(message: "Maximum \(limit) duty days in 11-day period reached")
        } else if dutyDaysIn11Days >= limit - 1 {
            return .warning(message: "Approaching \(limit) duty days in 11-day period limit")
        }
        return .compliant
    }
}

// MARK: - Maximum Next Duty

public struct FRMSMaximumNextDuty: Codable, Sendable {
    public let maxDutyPeriod: Double
    public let maxFlightTime: Double
    public let maxSectors: Int
    public let minimumRest: Double
    public let earliestSignOn: Date?
    public let restrictions: [String]
    public let limitType: FRMSLimitType
    public let signOnBasedLimits: [SignOnTimeRange]?
    public let mbtt: FRMSMinimumBaseTurnaroundTime?

    public init(maxDutyPeriod: Double, maxFlightTime: Double, maxSectors: Int, minimumRest: Double,
                earliestSignOn: Date?, restrictions: [String], limitType: FRMSLimitType,
                signOnBasedLimits: [SignOnTimeRange]?, mbtt: FRMSMinimumBaseTurnaroundTime?) {
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

    public var hasSevereRestrictions: Bool { maxDutyPeriod < 10 || maxFlightTime < 8 }
    public var formattedMaxDutyPeriod: String { String(format: "%.1f hours", maxDutyPeriod) }
    public var formattedMaxFlightTime: String { String(format: "%.1f hours", maxFlightTime) }
    public var formattedMinimumRest: String { String(format: "%.1f hours", minimumRest) }
}

// MARK: - Sign-On Time Range Limits

public struct SignOnTimeRange: Codable, Sendable {
    public let timeRange: String
    public let maxDutyPeriod: Double
    public let maxDutyPeriodOperational: Double?
    public let maxFlightTime: Double?
    public let maxFlightTimeOperational: Double?
    public let preRestRequired: Double
    public let postRestRequired: Double
    public let notes: String?
    public let sectorLimit: String?
    public let restFacility: CrewRestFacility?

    public init(timeRange: String, maxDutyPeriod: Double, maxDutyPeriodOperational: Double?,
                maxFlightTime: Double?, maxFlightTimeOperational: Double?,
                preRestRequired: Double, postRestRequired: Double, notes: String?,
                sectorLimit: String?, restFacility: CrewRestFacility?) {
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
        if limitType == .operational, let operational = maxDutyPeriodOperational { return operational }
        return maxDutyPeriod
    }

    public func getMaxFlight(for limitType: FRMSLimitType) -> Double? {
        if limitType == .operational, let operational = maxFlightTimeOperational { return operational }
        return maxFlightTime
    }
}

// MARK: - Minimum Base Turnaround Time (MBTT)

public struct FRMSMinimumBaseTurnaroundTime: Codable, Sendable {
    public let daysAway: Int?
    public let creditedFlightHours: Double?
    public let localNightsRequired: Int
    public let minHours: Double?
    public let reason: String

    public init(daysAway: Int?, creditedFlightHours: Double?, localNightsRequired: Int, minHours: Double?, reason: String) {
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

// MARK: - Daily Duty Summary

public struct DailyDutySummary: Identifiable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let duties: [FRMSDuty]
    public let totalFlightTime: Double
    public let totalDutyTime: Double
    public let totalSectors: Int
    public let earliestSignOn: Date?
    public let latestSignOff: Date?

    public var hasSimulatorDuty: Bool { duties.contains { $0.dutyType == .simulator } }

    public var totalSimDutyTime: Double { duties.reduce(0.0) { $0 + $1.simSessionTime } }

    public var factoredDutyTime: Double {
        guard hasSimulatorDuty else { return totalDutyTime }
        return duties.reduce(0.0) { $0 + ($1.dutyType == .simulator ? $1.dutyTime * 1.5 : $1.dutyTime) }
    }

    public init(date: Date, duties: [FRMSDuty]) {
        self.id = UUID()
        self.date = date
        self.duties = duties
        self.totalFlightTime = duties.reduce(0.0) { $0 + $1.flightTime }
        self.totalSectors = duties.reduce(0) { $0 + $1.sectors }
        self.earliestSignOn = duties.map { $0.signOn }.min()
        self.latestSignOff = duties.map { $0.signOff }.max()

        if let earliest = self.earliestSignOn, let latest = self.latestSignOff {
            self.totalDutyTime = latest.timeIntervalSince(earliest).toDecimalHours
        } else {
            self.totalDutyTime = 0.0
        }
    }
}

// MARK: - A320/B737 Next Duty Limits

public struct DutyTimeWindow: Codable, Sendable {
    public let timeRange: String
    public let displayName: String
    public let startHour: Int
    public let endHour: Int
    public let localStartTime: String
    public let isCurrentlyAvailable: Bool
    public let limitType: FRMSLimitType

    public init(timeRange: String, displayName: String, startHour: Int, endHour: Int,
                localStartTime: String, isCurrentlyAvailable: Bool, limitType: FRMSLimitType) {
        self.timeRange = timeRange
        self.displayName = displayName
        self.startHour = startHour
        self.endHour = endHour
        self.localStartTime = localStartTime
        self.isCurrentlyAvailable = isCurrentlyAvailable
        self.limitType = limitType
    }

    public var limits: DutyLimits {
        DutyLimits(localStartTime: localStartTime, limitType: limitType)
    }
}

public struct DutyLimits: Codable, Sendable {
    public let localStartTime: String
    public let limitType: FRMSLimitType

    public init(localStartTime: String, limitType: FRMSLimitType) {
        self.localStartTime = localStartTime
        self.limitType = limitType
    }

    private var operationalMaxDutySectors1to4: Double {
        guard let startTime = SH_Operational_FltDuty.LocalStartTime(rawValue: localStartTime),
              let dutyLimit = SH_Operational_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 12.0
        }
        return dutyLimit.maxDutySectors1to4
    }

    private var operationalMaxDutySectors5: Double {
        guard let startTime = SH_Operational_FltDuty.LocalStartTime(rawValue: localStartTime),
              let dutyLimit = SH_Operational_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 12.0
        }
        return dutyLimit.maxDutySectors5
    }

    private var operationalMaxDutySectors6: Double {
        guard let startTime = SH_Operational_FltDuty.LocalStartTime(rawValue: localStartTime),
              let dutyLimit = SH_Operational_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 11.0
        }
        return dutyLimit.maxDutySectors6
    }

    private var planningMaxDutySectors1to4: Double {
        guard let startTime = SH_Planning_FltDuty.LocalStartTime(rawValue: localStartTime),
              let limit = SH_Planning_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 10.0
        }
        return limit.maxDutySectors1to4
    }

    private var planningMaxDutySectors5or6: Double {
        guard let startTime = SH_Planning_FltDuty.LocalStartTime(rawValue: localStartTime),
              let limit = SH_Planning_FltDuty.twoPilotDutyLimits.first(where: { $0.localStartTime == startTime }) else {
            return 10.0
        }
        return limit.maxDutySectors5or6
    }

    public var maxDutySectors1to4: Double {
        limitType == .operational ? operationalMaxDutySectors1to4 : planningMaxDutySectors1to4
    }

    public var maxDutySectors5: Double {
        limitType == .operational ? operationalMaxDutySectors5 : planningMaxDutySectors5or6
    }

    public var maxDutySectors6: Double {
        limitType == .operational ? operationalMaxDutySectors6 : planningMaxDutySectors5or6
    }

    public var maxFlightTimeDescription: String {
        if limitType == .operational {
            return "10.5 hrs (1 Sector) or 10 hrs (Multi Sectors) or 9.5hrs (> 7 hrs night)"
        } else {
            return "10 hrs (9.5 hrs if >7 hrs night)"
        }
    }

    public var maxFlightTime: Double {
        limitType == .operational ? 10.5 : 10.0
    }

    public func maxDuty(forSectors sectors: Int) -> Double {
        if sectors >= 6 { return maxDutySectors6 }
        else if sectors >= 5 { return maxDutySectors5 }
        else { return maxDutySectors1to4 }
    }
}

public struct BackOfClockRestriction: Codable, Sendable {
    public let earliestSignOn: Date
    public let reason: String
    public let appliesTo: String

    public init(earliestSignOn: Date, reason: String, appliesTo: String) {
        self.earliestSignOn = earliestSignOn
        self.reason = reason
        self.appliesTo = appliesTo
    }
}

public struct LateNightStatus: Codable, Sendable {
    public let consecutiveLateNights: Int
    public let lnoCountIn168h: Int
    public let maxLnoIn168h: Int
    public let bocCountIn168h: Int
    public let maxBocIn168h: Int
    public let recoveryOption: LateNightRecoveryOption

    public init(consecutiveLateNights: Int, lnoCountIn168h: Int, maxLnoIn168h: Int,
                bocCountIn168h: Int, maxBocIn168h: Int, recoveryOption: LateNightRecoveryOption) {
        self.consecutiveLateNights = consecutiveLateNights
        self.lnoCountIn168h = lnoCountIn168h
        self.maxLnoIn168h = maxLnoIn168h
        self.bocCountIn168h = bocCountIn168h
        self.maxBocIn168h = maxBocIn168h
        self.recoveryOption = recoveryOption
    }

    public var hasActiveRestriction: Bool {
        recoveryOption == .require24HoursOff || lnoCountIn168h >= maxLnoIn168h || bocCountIn168h >= maxBocIn168h
    }
}

public enum LateNightRecoveryOption: String, Codable, Sendable {
    case continueOnLateNights = "Continue on late night operations"
    case require24HoursOff    = "Require ≥24 hours off before day duty"
    case noRestriction        = "No restriction"
}

public struct ConsecutiveDutyStatus: Codable, Sendable {
    public let consecutiveDuties: Int
    public let maxConsecutiveDuties: Int
    public let dutyDaysIn11Days: Int
    public let maxDutyDaysIn11Days: Int
    public let consecutiveEarlyStarts: Int
    public let maxConsecutiveEarlyStarts: Int

    public init(consecutiveDuties: Int, maxConsecutiveDuties: Int, dutyDaysIn11Days: Int,
                maxDutyDaysIn11Days: Int, consecutiveEarlyStarts: Int, maxConsecutiveEarlyStarts: Int) {
        self.consecutiveDuties = consecutiveDuties
        self.maxConsecutiveDuties = maxConsecutiveDuties
        self.dutyDaysIn11Days = dutyDaysIn11Days
        self.maxDutyDaysIn11Days = maxDutyDaysIn11Days
        self.consecutiveEarlyStarts = consecutiveEarlyStarts
        self.maxConsecutiveEarlyStarts = maxConsecutiveEarlyStarts
    }

    public var hasActiveRestrictions: Bool {
        consecutiveDuties >= maxConsecutiveDuties ||
        dutyDaysIn11Days >= maxDutyDaysIn11Days ||
        consecutiveEarlyStarts >= maxConsecutiveEarlyStarts
    }
}

public struct PatternEndRequirement: Codable, Sendable {
    public let patternDays: Int
    public let minimumRestHours: Double
    public let reason: String

    public init(patternDays: Int, minimumRestHours: Double, reason: String) {
        self.patternDays = patternDays
        self.minimumRestHours = minimumRestHours
        self.reason = reason
    }
}

public struct WeeklyRestStatus: Codable, Sendable {
    public let hasRequired36Hours: Bool
    public let hasRequired2Nights: Bool
    public let nextRequiredBy: Date?
    public let isCompliant: Bool

    public init(hasRequired36Hours: Bool, hasRequired2Nights: Bool, nextRequiredBy: Date?, isCompliant: Bool) {
        self.hasRequired36Hours = hasRequired36Hours
        self.hasRequired2Nights = hasRequired2Nights
        self.nextRequiredBy = nextRequiredBy
        self.isCompliant = isCompliant
    }
}

public struct RestCalculationBreakdown: Codable, Sendable {
    public let previousDutyHours: Double
    public let formula: String
    public let minimumRestHours: Double
    public let reducedRestAvailable: Bool
    public let reducedRestConditions: String?

    public init(previousDutyHours: Double, formula: String, minimumRestHours: Double,
                reducedRestAvailable: Bool, reducedRestConditions: String?) {
        self.previousDutyHours = previousDutyHours
        self.formula = formula
        self.minimumRestHours = minimumRestHours
        self.reducedRestAvailable = reducedRestAvailable
        self.reducedRestConditions = reducedRestConditions
    }
}

public struct SpecialScenarios: Codable, Sendable {
    public let simulatorRestrictions: SimulatorRestrictions?
    public let daysOffRequirements: DaysOffRequirements?
    public let annualLeaveRestrictions: AnnualLeaveRestrictions?
    public let reserveDutyRules: ReserveDutyRules?
    public let deadheadingLimitations: DeadheadingLimitations?

    public init(simulatorRestrictions: SimulatorRestrictions?, daysOffRequirements: DaysOffRequirements?,
                annualLeaveRestrictions: AnnualLeaveRestrictions?, reserveDutyRules: ReserveDutyRules?,
                deadheadingLimitations: DeadheadingLimitations?) {
        self.simulatorRestrictions = simulatorRestrictions
        self.daysOffRequirements = daysOffRequirements
        self.annualLeaveRestrictions = annualLeaveRestrictions
        self.reserveDutyRules = reserveDutyRules
        self.deadheadingLimitations = deadheadingLimitations
    }
}

public struct SimulatorRestrictions: Codable, Sendable {
    public let dayBeforeRestriction: String?
    public let restBeforeSimulator: Double?
    public let sameDayProhibition: String?
    public let applicableRegion: String

    public init(dayBeforeRestriction: String?, restBeforeSimulator: Double?,
                sameDayProhibition: String?, applicableRegion: String) {
        self.dayBeforeRestriction = dayBeforeRestriction
        self.restBeforeSimulator = restBeforeSimulator
        self.sameDayProhibition = sameDayProhibition
        self.applicableRegion = applicableRegion
    }
}

public struct DaysOffRequirements: Codable, Sendable {
    public let dutyBeforeXDay: String
    public let dutyAfterXDay: String
    public let minimumDuration: Double
    public let operationalException: String?

    public init(dutyBeforeXDay: String, dutyAfterXDay: String, minimumDuration: Double, operationalException: String?) {
        self.dutyBeforeXDay = dutyBeforeXDay
        self.dutyAfterXDay = dutyAfterXDay
        self.minimumDuration = minimumDuration
        self.operationalException = operationalException
    }
}

public struct AnnualLeaveRestrictions: Codable, Sendable {
    public let beforeLeaveRestriction: String
    public let afterLeaveRestriction: String
    public let minimumLeaveDays: Int?
    public let canWaive: Bool
    public let applicableRegion: String

    public init(beforeLeaveRestriction: String, afterLeaveRestriction: String,
                minimumLeaveDays: Int?, canWaive: Bool, applicableRegion: String) {
        self.beforeLeaveRestriction = beforeLeaveRestriction
        self.afterLeaveRestriction = afterLeaveRestriction
        self.minimumLeaveDays = minimumLeaveDays
        self.canWaive = canWaive
        self.applicableRegion = applicableRegion
    }
}

public struct ReserveDutyRules: Codable, Sendable {
    public let afterCalloutRest: String
    public let withoutCalloutRest: String
    public let betweenReservePeriods: String

    public init(afterCalloutRest: String, withoutCalloutRest: String, betweenReservePeriods: String) {
        self.afterCalloutRest = afterCalloutRest
        self.withoutCalloutRest = withoutCalloutRest
        self.betweenReservePeriods = betweenReservePeriods
    }
}

public struct DeadheadingLimitations: Codable, Sendable {
    public let absoluteMaximum: Double
    public let restCalculationNote: String
    public let sectorCountingRule: String

    public init(absoluteMaximum: Double, restCalculationNote: String, sectorCountingRule: String) {
        self.absoluteMaximum = absoluteMaximum
        self.restCalculationNote = restCalculationNote
        self.sectorCountingRule = sectorCountingRule
    }
}

public struct WhatIfScenario: Codable, Sendable {
    public let proposedSignOn: Date
    public let estimatedSectors: Int
    public let estimatedDutyHours: Double
    public let estimatedFlightHours: Double

    public init(proposedSignOn: Date, estimatedSectors: Int, estimatedDutyHours: Double, estimatedFlightHours: Double) {
        self.proposedSignOn = proposedSignOn
        self.estimatedSectors = estimatedSectors
        self.estimatedDutyHours = estimatedDutyHours
        self.estimatedFlightHours = estimatedFlightHours
    }

    public var isValid: Bool { estimatedSectors > 0 && estimatedDutyHours > 0 && estimatedFlightHours > 0 }
}

public struct WhatIfResult: Codable, Sendable {
    public let scenario: WhatIfScenario
    public let isCompliant: Bool
    public let complianceStatus: FRMSComplianceStatus
    public let violations: [String]
    public let warnings: [String]
    public let applicableWindow: DutyTimeWindow?

    public init(scenario: WhatIfScenario, isCompliant: Bool, complianceStatus: FRMSComplianceStatus,
                violations: [String], warnings: [String], applicableWindow: DutyTimeWindow?) {
        self.scenario = scenario
        self.isCompliant = isCompliant
        self.complianceStatus = complianceStatus
        self.violations = violations
        self.warnings = warnings
        self.applicableWindow = applicableWindow
    }
}

public struct A320B737NextDutyLimits: Codable, Sendable {
    public let earlyWindow: DutyTimeWindow
    public let afternoonWindow: DutyTimeWindow
    public let nightWindow: DutyTimeWindow
    public let backOfClockRestriction: BackOfClockRestriction?
    public let lateNightStatus: LateNightStatus?
    public let consecutiveDutyStatus: ConsecutiveDutyStatus
    public let restCalculation: RestCalculationBreakdown
    public let earliestSignOn: Date
    public let patternEndRequirement: PatternEndRequirement?
    public let weeklyRestStatus: WeeklyRestStatus
    public let specialScenarios: SpecialScenarios
    public let overallStatus: FRMSComplianceStatus

    public init(earlyWindow: DutyTimeWindow, afternoonWindow: DutyTimeWindow, nightWindow: DutyTimeWindow,
                backOfClockRestriction: BackOfClockRestriction?, lateNightStatus: LateNightStatus?,
                consecutiveDutyStatus: ConsecutiveDutyStatus, restCalculation: RestCalculationBreakdown,
                earliestSignOn: Date, patternEndRequirement: PatternEndRequirement?,
                weeklyRestStatus: WeeklyRestStatus, specialScenarios: SpecialScenarios,
                overallStatus: FRMSComplianceStatus) {
        self.earlyWindow = earlyWindow
        self.afternoonWindow = afternoonWindow
        self.nightWindow = nightWindow
        self.backOfClockRestriction = backOfClockRestriction
        self.lateNightStatus = lateNightStatus
        self.consecutiveDutyStatus = consecutiveDutyStatus
        self.restCalculation = restCalculation
        self.earliestSignOn = earliestSignOn
        self.patternEndRequirement = patternEndRequirement
        self.weeklyRestStatus = weeklyRestStatus
        self.specialScenarios = specialScenarios
        self.overallStatus = overallStatus
    }
}

// MARK: - FRMS Configuration

public struct FRMSConfiguration: Codable, Sendable {
    public var isEnabled: Bool = true
    public var showFRMS: Bool = true
    public var fleet: FRMSFleet
    public var homeBase: String
    public var defaultLimitType: FRMSLimitType
    public var showWarningsAtPercentage: Double
    public var signOnMinutesBeforeSTD: Int
    public var signOffMinutesAfterIN: Int

    public init(isEnabled: Bool = true,
                showFRMS: Bool = true,
                fleet: FRMSFleet = .a320B737,
                homeBase: String = "SYD",
                defaultLimitType: FRMSLimitType = .operational,
                showWarningsAtPercentage: Double = 0.9,
                signOnMinutesBeforeSTD: Int? = nil,
                signOffMinutesAfterIN: Int? = nil) {

        self.isEnabled = true
        self.showFRMS = true
        self.fleet = fleet
        self.homeBase = homeBase
        self.defaultLimitType = .operational
        self.showWarningsAtPercentage = showWarningsAtPercentage

        if let signOn = signOnMinutesBeforeSTD {
            self.signOnMinutesBeforeSTD = signOn
        } else {
            self.signOnMinutesBeforeSTD = 60
        }

        if let signOff = signOffMinutesAfterIN {
            self.signOffMinutesAfterIN = signOff
        } else {
            switch fleet {
            case .a320B737:       self.signOffMinutesAfterIN = 15
            case .a380A330B787:   self.signOffMinutesAfterIN = 30
            }
        }
    }

    public var isNZBased: Bool { homeBase == "NZ" }

    public var effectiveDutyLimit7Days: Double {
        isNZBased ? SH_NZ_Planning_FltDuty.cumulativeDutyTime7DaysHours : fleet.maxDutyTime7Days
    }

    public var effectiveDutyLimit14DaysInitial: Double? {
        if isNZBased { return SH_NZ_Planning_FltDuty.cumulativeDutyTime14DaysInitialHours }
        return fleet.maxDutyTime14DaysInitial
    }

    public var effectiveDutyLimit14Days: Double { fleet.maxDutyTime14Days }

    public mutating func updateSignOffForFleet() {
        switch fleet {
        case .a320B737:     self.signOffMinutesAfterIN = 15
        case .a380A330B787: self.signOffMinutesAfterIN = 30
        }
    }
}
