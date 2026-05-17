//
//  FRMSData.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) Data Models
//  Based on Qantas FRMS Ruleset Rev 4.1 (A320/B737) and Rev 4 (A380/A330/B787)
//
//  Domain value types (FRMSDuty, FRMSConfiguration, FRMSCumulativeTotals, enums, etc.)
//  have moved to BlockTimeKit/Sources/BlockTimeDomain/FRMSTypes.swift (D-03).
//  This file retains UI/presentation types used only by FRMSViewModel.
//

import Foundation
import BlockTimeDomain

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

    /// True when the day contains at least one simulator duty (affects duty time factoring display)
    var hasSimulatorDuty: Bool {
        duties.contains { $0.dutyType == .simulator }
    }

    /// Sum of raw sim session time (not duty time) for display purposes
    var totalSimDutyTime: Double {
        duties.reduce(0.0) { $0 + $1.simSessionTime }
    }

    /// Duty time with 1.5× applied to simulator portions, matching the cumulative FRMS calculation
    var factoredDutyTime: Double {
        guard hasSimulatorDuty else { return totalDutyTime }
        // Apply 1.5× to each simulator duty's contribution, raw time for others
        return duties.reduce(0.0) { $0 + ($1.dutyType == .simulator ? $1.dutyTime * 1.5 : $1.dutyTime) }
    }

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
