import Foundation

// MARK: - SH Planning Flight & Duty Limits
// Source: FRMS Ruleset A320/B737, Revision 5, 15 June 2026
// Chapter 1A: Planning Flight and Duty Limitations (FD11–FD20)
// Applies to Australia-based crew. NZ-based crew use SH_NZ_* (Chapter 4A/4B).

struct SH_Planning_FltDuty {

    // MARK: - Types

    // Rev 5 (FD13.1): start-time bands shifted. Hour values unchanged.
    enum LocalStartTime: String, CaseIterable {
        case early     = "0500–1259"
        case afternoon = "1300–1759"
        case night     = "1800–0459"

        var range: ClosedRange<Int> {
            switch self {
            case .early:     return 500...1259
            case .afternoon: return 1300...1759
            case .night:     return 1800...2459 // wraps to 0459
            }
        }
    }

    // MARK: - Maximum Duty Periods – 2 Pilot Operations (FD13.1)

    struct DutyPeriodLimit {
        let localStartTime: LocalStartTime
        let maxDutySectors1to4: Double // hours
        let maxDutySectors5or6: Double // hours
    }

    static let twoPilotDutyLimits: [DutyPeriodLimit] = [
        DutyPeriodLimit(localStartTime: .early,      maxDutySectors1to4: 12, maxDutySectors5or6: 11),
        DutyPeriodLimit(localStartTime: .afternoon,  maxDutySectors1to4: 11, maxDutySectors5or6: 10),
        DutyPeriodLimit(localStartTime: .night,      maxDutySectors1to4: 10, maxDutySectors5or6: 10),
    ]

    // MARK: - Maximum Duty Periods – 3 Pilot Operations (FD13.1, Rev 5)
    // Replaces old augmented model. Start-time-banded Class 2 vs Business Seat table.
    // Max 2 sectors. Min 2 h total rest period (table note).

    enum ThreePilotRest { case class2, businessSeat }

    struct ThreePilotDutyLimit {
        let band: LocalStartTime
        let class2: Double       // hours
        let businessSeat: Double // hours
    }

    static let threePilotDutyLimits: [ThreePilotDutyLimit] = [
        .init(band: .early,     class2: 14, businessSeat: 14),
        .init(band: .afternoon, class2: 14, businessSeat: 13),
        .init(band: .night,     class2: 14, businessSeat: 12),
    ]

    static let threePilotMaxSectors = 2           // FD13.1 planning
    static let threePilotMinTotalRestHours = 2.0  // FD13.1 table note

    // MARK: - Lookup Helpers

    static func maxDutyHours(localStartTime: LocalStartTime, sectors: Int) -> Double? {
        guard let limit = twoPilotDutyLimits.first(where: { $0.localStartTime == localStartTime }) else {
            return nil
        }
        switch sectors {
        case 1...4: return limit.maxDutySectors1to4
        case 5...6: return limit.maxDutySectors5or6
        default:    return nil
        }
    }

    static func maxDutyHoursThreePilot(band: LocalStartTime, rest: ThreePilotRest) -> Double? {
        guard let limit = threePilotDutyLimits.first(where: { $0.band == band }) else { return nil }
        return rest == .class2 ? limit.class2 : limit.businessSeat
    }

    // =========================================================================
    // MARK: - Cumulative Flight Time Limits (FD11.1)
    // =========================================================================

    static let cumulativeFlightTime28DaysHours: Double = 100
    static let cumulativeFlightTime365DaysHours: Double = 1_000
    /// Roster-construction limit only — not an operational limit.
    static let cumulativeFlightTime13BidPeriodsHours: Double = 950

    // =========================================================================
    // MARK: - Cumulative Duty Time Limits (FD12)
    // =========================================================================

    static let cumulativeDutyTime7DaysHours: Double = 60
    /// FD12 — initial roster publication limit.
    static let cumulativeDutyTime14DaysInitialHours: Double = 90
    /// FD12 — maximum with pilot agreement or open time bid.
    static let cumulativeDutyTime14DaysExtendedHours: Double = 100
    /// FD12.1 — duty multiplier for simulator/training flights for trainee and
    /// support pilot (excludes line training, line checks, deadheading).
    static let simulatorTrainingDutyFactor: Double = 1.5
    /// FD12.2 — max duty days in any 11-day period.
    static let maxDutyDaysIn11Days: Int = 9
    /// FD12.2 — max consecutive duty days.
    static let maxConsecutiveDutyDays: Int = 6
    /// FD12.3 — min hours free of all duty in any 7 consecutive days.
    static let minHoursFreeIn7ConsecutiveDays: Double = 36

    // =========================================================================
    // MARK: - Emergency Procedures Training Extension (FD13.2)
    // =========================================================================

    /// Max duty for a pilot not based in SYD or MEL undertaking EPT at another base.
    static let emergencyProceduresTrainingMaxDutyHours: Double = 15

    // =========================================================================
    // MARK: - Reserve Duty (FD13.3–13.5, Rev 5)
    // =========================================================================

    /// FD13.3 — max consecutive reserve duty hours.
    static let reserveDutyMaxConsecutiveHours: Double = 12

    /// FD13.4 — max combined reserve + flying duty hours after call-out.
    /// Exceptions: (a) augmented crew operation; (b) split duty per FD17.
    static let reserveCallOutMaxCombinedHours: Double = 16

    /// FD13.5 — reserve starting in this window does not count toward FD13.4 combined limit
    /// until the crew member is contacted (local HHMM).
    static let reserveNightWindowStartHHMM = 2300
    static let reserveNightWindowEndHHMM   = 600

    // =========================================================================
    // MARK: - Consecutive Early Starts (FD14.6)
    // =========================================================================

    /// Max consecutive duties with sign-on prior to earlyStartSignOnThreshold.
    static let maxConsecutiveEarlyStarts: Int = 4
    /// Sign-on time threshold for early starts, local time (HHMM integer).
    static let earlyStartSignOnThreshold: Int = 706

    // =========================================================================
    // MARK: - Late Night Operations / Back of Clock (FD14, Rev 5)
    // =========================================================================

    /// FD14.1 — >2 consecutive LNO flying duties triggers 24 h free of duty.
    static let lnoConsecutiveTriggerCount = 2
    static let lnoPostExcessFreeHours: Double = 24

    /// FD14.2 — max LNO flying duty periods in any 168-hour rolling window.
    static let lnoMaxPeriodsIn168h = 4

    /// FD14.3 — FD14.1 and FD14.2 do NOT apply to reserve duty periods.
    // (no numeric constant — handled in engine logic)

    /// FD14.4 — max BOC flying duty periods in any 168-hour rolling window (pilot may waive).
    static let bocMaxPeriodsIn168h = 2

    /// Shared rolling window for both LNO and BOC caps.
    static let lnoRollingWindowHours = 168

    /// FD14.5 — back of clock: ≥2 hrs between 0100–0459 local at departure.
    static let backOfClockMinutesThreshold: Int = 120
    /// FD14.5 — next duty in Australia: sign-on no earlier than this local time (HHMM).
    static let backOfClockEarliestSignOnLocalHHMM: Int = 1000

    // =========================================================================
    // MARK: - Deadheading Following a Flight Duty (FD15)
    // =========================================================================

    /// FD15.6 — no duty period that includes flight duty may exceed this total.
    static let deadheadingAbsoluteMaxDutyHours: Double = 16

    // =========================================================================
    // MARK: - Split Duty (FD17)
    // =========================================================================

    struct SplitDutyRules {
        /// FD17 — min rest at suitable sleeping accommodation.
        let minRestHours: Double
        /// FD17 — max additional duty beyond FD13.1 base limits.
        let maxDutyIncreaseHours: Double
        /// FD17 — total duty must not exceed this.
        let maxTotalDutyHours: Double
        /// FD17.3 — rest discount fraction (50%).
        let restDiscountFraction: Double
        /// FD17.3 — maximum discount in hours.
        let maxRestDiscountHours: Double
        /// FD17.4 — if rest includes any period in this window, stricter rules apply.
        let nightWindowStart: String
        let nightWindowEnd: String
        /// FD17.4 — rest must be uninterrupted for at least this duration.
        let nightRestMinUninterruptedHours: Double
        /// FD17.4 — max total duty when night window rule applies.
        let nightRestMaxTotalDutyHours: Double
        /// FD17.4 — rest discounting not permitted when night window rule applies.
        let nightRestDiscountPermitted: Bool
    }

    static let splitDutyRules = SplitDutyRules(
        minRestHours: 6,
        maxDutyIncreaseHours: 4,
        maxTotalDutyHours: 16,
        restDiscountFraction: 0.5,
        maxRestDiscountHours: 4,
        nightWindowStart: "2300",
        nightWindowEnd: "0530",
        nightRestMinUninterruptedHours: 7,
        nightRestMaxTotalDutyHours: 16,
        nightRestDiscountPermitted: false
    )

    // =========================================================================
    // MARK: - Time Free from Duty — Within a Pattern (FD18.1)
    // =========================================================================

    struct TimeFreeWithinPatternFormula {
        /// Duty at or below this threshold uses the simpler rule.
        let dutyThresholdHours: Double
        /// Minimum free hours when duty ≤ threshold (or equal to duty, whichever is greater).
        let minFreeHours: Double
        /// Base hours for the extended formula when duty > threshold.
        let baseHours: Double
        /// Multiplier applied to the excess over threshold.
        let multiplier: Double
    }

    /// FD18.1 — duty ≤ 12 hrs: min free = max(10, duty); duty > 12 hrs: 12 + 1.5 × (duty − 12).
    static let timeFreeWithinPattern = TimeFreeWithinPatternFormula(
        dutyThresholdHours: 12,
        minFreeHours: 10,
        baseHours: 12,
        multiplier: 1.5
    )

    // =========================================================================
    // MARK: - Time Free from Duty — Following a Pattern (FD19)
    // =========================================================================

    struct PatternTimeFreeRequirement {
        let patternDescription: String
        let minTimeFreeHours: Double
    }

    static let patternTimeFreeRequirements: [PatternTimeFreeRequirement] = [
        PatternTimeFreeRequirement(patternDescription: "1 or 2 day pattern", minTimeFreeHours: 12),
        PatternTimeFreeRequirement(patternDescription: "3 or 4 day pattern", minTimeFreeHours: 15),
    ]

    // MARK: 3-Pilot Post-Pattern Rest (FD19, Rev 5)
    // tafbMaxHours: nil = no upper bound. dayReturn / multiDay: nil = not applicable.

    struct AugmentedPatternRest {
        let tafbMaxHours: Double?  // upper bound of TAFB bracket; nil = 124+ hrs
        let dayReturn: Double?     // min rest for day-return pattern
        let multiDay: Double?      // min rest for multi-day pattern
        let nextDutyDayMinHours: Double?  // required minimum next-duty-day length (nil if none)
    }

    // FD19 — next duty day must be > 9.59 h where noted (refer FD14.5).
    static let threePilotPatternRestPlanning: [AugmentedPatternRest] = [
        .init(tafbMaxHours: 52,  dayReturn: 14.5, multiDay: 15,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: 124, dayReturn: nil,  multiDay: 22,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: nil, dayReturn: nil,  multiDay: 32,  nextDutyDayMinHours: nil),
    ]

    // =========================================================================
    // MARK: - Time Free from Duty (FD20)
    // =========================================================================

    /// FD20 — min hours free of all duty in any 7 consecutive days.
    static let minHoursFreeIn7Days: Double = 36

    struct DaysFreeRequirement {
        let description: String
        let minDaysFree: Int
        /// 0 = calendar-based period rather than rolling consecutive days.
        let inConsecutiveDays: Int
    }

    /// FD20.2 — minimum days free requirements (either option (a) or option (b)+(c)).
    static let daysFreeRequirements: [DaysFreeRequirement] = [
        DaysFreeRequirement(description: "Min free days in any 28 consecutive days",         minDaysFree: 7,  inConsecutiveDays: 28),
        DaysFreeRequirement(description: "Min free days in any 84 consecutive days",         minDaysFree: 24, inConsecutiveDays: 84),
        DaysFreeRequirement(description: "Min free days per calendar month",                  minDaysFree: 8,  inConsecutiveDays: 0),
        DaysFreeRequirement(description: "Min free days in any 3 consecutive calendar months", minDaysFree: 26, inConsecutiveDays: 0),
    ]
}
