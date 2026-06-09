import Foundation

// MARK: - SH NZ Planning Flight & Duty Limits
// Source: FRMS Ruleset A320/B737, Revision 5, 15 June 2026
// Chapter 4A: New Zealand-Based Flight and Duty Limitations (Planning) FD47–FD55
// Applies to NZ-based crew (homeBase == "NZ"). Australia-based crew use SH_Planning_FltDuty.

struct SH_NZ_Planning_FltDuty {

    // MARK: - Maximum Duty Periods – 2 Pilot Operations (FD49.1)
    // Same bands and values as SH_Planning_FltDuty (AU Chapter 1A).

    static let twoPilotDutyLimits: [SH_Planning_FltDuty.DutyPeriodLimit] = [
        .init(localStartTime: .early,     maxDutySectors1to4: 12, maxDutySectors5or6: 11),
        .init(localStartTime: .afternoon, maxDutySectors1to4: 11, maxDutySectors5or6: 10),
        .init(localStartTime: .night,     maxDutySectors1to4: 10, maxDutySectors5or6: 10),
    ]

    // MARK: - Maximum Duty Periods – 3 Pilot Operations (FD49.1)
    // Same values as AU planning. Max 2 sectors. Min 2 h total rest period.

    static let threePilotDutyLimits: [SH_Planning_FltDuty.ThreePilotDutyLimit] = [
        .init(band: .early,     class2: 14, businessSeat: 14),
        .init(band: .afternoon, class2: 14, businessSeat: 13),
        .init(band: .night,     class2: 14, businessSeat: 12),
    ]

    static let threePilotMaxSectors = 2
    static let threePilotMinTotalRestHours = 2.0

    // MARK: - Lookup Helpers

    static func maxDutyHours(localStartTime: SH_Planning_FltDuty.LocalStartTime, sectors: Int) -> Double? {
        guard let limit = twoPilotDutyLimits.first(where: { $0.localStartTime == localStartTime }) else {
            return nil
        }
        switch sectors {
        case 1...4: return limit.maxDutySectors1to4
        case 5...6: return limit.maxDutySectors5or6
        default:    return nil
        }
    }

    static func maxDutyHoursThreePilot(band: SH_Planning_FltDuty.LocalStartTime, rest: SH_Planning_FltDuty.ThreePilotRest) -> Double? {
        guard let limit = threePilotDutyLimits.first(where: { $0.band == band }) else { return nil }
        return rest == .class2 ? limit.class2 : limit.businessSeat
    }

    // =========================================================================
    // MARK: - Cumulative Flight Time Limits (FD47)
    // =========================================================================

    static let cumulativeFlightTime28DaysHours: Double = 100
    static let cumulativeFlightTime365DaysHours: Double = 1_000

    // =========================================================================
    // MARK: - Cumulative Duty Time Limits (FD48)
    // =========================================================================

    /// FD48.1(a) — initial roster publication limit for 7 consecutive days.
    static let cumulativeDutyTime7DaysHours: Double = 55

    /// FD48.1(b) — initial roster publication limit for 14 consecutive days.
    static let cumulativeDutyTime14DaysInitialHours: Double = 95

    /// FD48.1(c) — initial roster publication limit for 28 consecutive days.
    static let cumulativeDutyTime28DaysHours: Double = 190

    /// FD48.2(a) — after roster publication, 7-day limit may be extended.
    static let cumulativeDutyTime7DaysExtendedHours: Double = 60

    /// FD48.2(b) — after roster publication, 14-day limit may be extended.
    static let cumulativeDutyTime14DaysExtendedHours: Double = 100

    /// FD48.5 — duty multiplier for simulator/training (excludes line training, line checks, deadheading).
    static let simulatorTrainingDutyFactor: Double = 1.5

    // =========================================================================
    // MARK: - Rostered Days Off (FD42)
    // =========================================================================

    /// FD42.1 — minimum RDOs per 28-day roster period (NZ: 11; AU: 10).
    static let minRDOsPerRosterPeriod: Int = 11

    /// FD42.2 — pilot may agree to fewer; minimum is 9 RDOs.
    static let minRDOsAgreedReduction: Int = 9

    /// FD42.3 — a single RDO must be at least 36 consecutive hours free of duty.
    static let minRDODurationHours: Double = 36

    // =========================================================================
    // MARK: - Consecutive Early Starts (FD49.3)
    // =========================================================================

    /// Max consecutive duties with sign-on prior to earlyStartSignOnThreshold.
    static let maxConsecutiveEarlyStarts: Int = 4
    /// Sign-on time threshold for early starts, local time (HHMM integer).
    static let earlyStartSignOnThreshold: Int = 706

    // =========================================================================
    // MARK: - Back of Clock Next Sign-On (FD49.4)
    // =========================================================================

    /// FD49.4 — after a BOC flying duty, next NZ flying duty must sign on no
    /// earlier than this local time (HHMM). Pilot may waive.
    static let bocEarliestNextSignOnLocalHHMM: Int = 1000

    // =========================================================================
    // MARK: - Reserve Duty (FD51)
    // =========================================================================

    /// FD51.2 — max reserve duty hours.
    static let reserveDutyMaxConsecutiveHours: Double = 12

    /// FD51.3 — min rest between reserve periods or between duty and reserve.
    static let reserveMinRestHours: Double = 12

    // =========================================================================
    // MARK: - Time Free from Duty — 2 Pilot (FD55.1–55.2)
    // =========================================================================

    /// FD55.1 — min rest overnight away from home base.
    static let minRestAwayHours: Double = 11
    /// FD55.1 — reducible to this minimum when duty ≤ 12 h (delay/disruption, 1 sector return only).
    static let minRestAwayReducedHours: Double = 10
    /// FD55.1 — min rest at home base.
    static let minRestHomeBaseHours: Double = 12
    /// FD55.1 — reducible to this minimum for operational recovery when duty ≤ 12 h.
    static let minRestHomeBaseReducedHours: Double = 10
    /// FD55.2 — duty threshold above which extended rest formula applies.
    static let restExtendedDutyThresholdHours: Double = 12
    /// FD55.2 — base hours for extended formula.
    static let restExtendedBaseHours: Double = 12
    /// FD55.2 — multiplier for excess over threshold.
    static let restExtendedMultiplier: Double = 1.5

    // =========================================================================
    // MARK: - 3-Pilot Post-Pattern Rest (FD55)
    // =========================================================================

    // FD55 planning table: tafbMaxHours nil = no upper bound.
    // Note 1: Refer to FD49.4 (BOC next duty day must start ≥ 0959 local).

    static let threePilotPatternRestPlanning: [SH_Planning_FltDuty.AugmentedPatternRest] = [
        .init(tafbMaxHours: 52,  dayReturn: 14.5, multiDay: 15,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: 124, dayReturn: nil,  multiDay: 22,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: nil, dayReturn: nil,  multiDay: 32,  nextDutyDayMinHours: nil),
    ]

    // =========================================================================
    // MARK: - Time Free from Duty — All Operations (FD55.3–55.4)
    // =========================================================================

    /// FD55.3(a) — min period free in any 7 consecutive days.
    static let minHoursFreeIn7Days: Double = 36

    struct DaysFreeRequirement {
        let description: String
        let minDaysFree: Int
        let inConsecutiveDays: Int  // 0 = calendar-based
    }

    /// FD55.4 — minimum days free requirements.
    static let daysFreeRequirements: [DaysFreeRequirement] = [
        .init(description: "Min free days in any 28 consecutive days",          minDaysFree: 7,  inConsecutiveDays: 28),
        .init(description: "Min free days in any 84 consecutive days",          minDaysFree: 24, inConsecutiveDays: 84),
        .init(description: "Min free days per calendar month",                   minDaysFree: 8,  inConsecutiveDays: 0),
        .init(description: "Min free days in any 3 consecutive calendar months", minDaysFree: 26, inConsecutiveDays: 0),
    ]
}
