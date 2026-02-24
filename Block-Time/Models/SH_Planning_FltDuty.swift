import Foundation

// MARK: - SH Planning Flight & Duty Limits
// Source: FRMS Ruleset A320/B737, Revision 4.1, 1 October 2024
// Chapter 1A: Planning Flight and Duty Limitations (FD11–FD20)

struct SH_Planning_FltDuty {

    // MARK: - Types

    enum LocalStartTime: String, CaseIterable {
        case early     = "0500–1459"
        case afternoon = "1500–1959"
        case night     = "2000–0459"

        var range: ClosedRange<Int> {
            switch self {
            case .early:     return 500...1459
            case .afternoon: return 1500...1959
            case .night:     return 2000...2459 // wraps to 0459
            }
        }
    }

    enum CrewConfig {
        case twoPilot
        case augmented
    }

    enum AugmentedRestFacility: String {
        /// Comfortable seat, separate from and screened from flight deck
        /// and passenger compartment, environmentally conducive to rest
        case separateScreenedSeat
        /// Comfortable seat in passenger compartment
        case passengerCompartmentSeat
    }

    // MARK: - Maximum Duty Periods – 2 Pilot Operations (FD13.1)

    struct DutyPeriodLimit {
        let localStartTime: LocalStartTime
        let maxDutySectors1to4: Double // hours
        let maxDutySectors5or6: Double // hours
    }

    static let twoPilotDutyLimits: [DutyPeriodLimit] = [
        DutyPeriodLimit(localStartTime: .early,     maxDutySectors1to4: 12, maxDutySectors5or6: 11),
        DutyPeriodLimit(localStartTime: .afternoon,  maxDutySectors1to4: 11, maxDutySectors5or6: 10),
        DutyPeriodLimit(localStartTime: .night,      maxDutySectors1to4: 10, maxDutySectors5or6: 10),
    ]

    // MARK: - Maximum Duty Periods – Augmented Crew (FD13.1)

    struct AugmentedDutyLimit {
        let restFacility: AugmentedRestFacility
        let maxDutyHours: Double
        let maxSectors: Int? // nil if no sector restriction stated
    }

    static let augmentedDutyLimits: [AugmentedDutyLimit] = [
        AugmentedDutyLimit(
            restFacility: .separateScreenedSeat,
            maxDutyHours: 16,
            maxSectors: 2 // max 2 sectors if FDP scheduled to exceed 14 hours
        ),
        AugmentedDutyLimit(
            restFacility: .passengerCompartmentSeat,
            maxDutyHours: 14,
            maxSectors: nil
        ),
    ]

    // MARK: - Flight Time Limits – 2 Pilot Operations (FD13.3)

    struct FlightTimeLimit {
        let condition: String
        let maxFlightTimeHours: Double
    }

    static let twoPilotFlightTimeLimits: [FlightTimeLimit] = [
        FlightTimeLimit(
            condition: "More than 7 hours of flight time in a duty period conducted in darkness",
            maxFlightTimeHours: 9.5
        ),
        FlightTimeLimit(
            condition: "More than 1 sector scheduled",
            maxFlightTimeHours: 10
        ),
        FlightTimeLimit(
            condition: "All other occasions",
            maxFlightTimeHours: 10.5
        ),
    ]

    // MARK: - Flight Time Limits – More Than 2 Pilots (FD13.4)

    static let augmentedFlightTimeLimitHours: Double = 10.5

    // MARK: - Lookup Helpers

    /// Returns the maximum duty period in hours for a 2-pilot operation
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

    /// Returns the applicable flight time limit in hours for a 2-pilot operation
    static func maxFlightTimeHours(sectorsScheduled: Int, darknessFlightTimeExceeds7Hours: Bool) -> Double {
        if darknessFlightTimeExceeds7Hours {
            return 9.5
        } else if sectorsScheduled > 1 {
            return 10
        } else {
            return 10.5
        }
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
    // MARK: - Reserve Duty (FD13.5)
    // =========================================================================

    /// Max consecutive reserve duty hours. Pilot must have access to suitable
    /// sleeping accommodation and be free from all employment duties.
    static let reserveDutyMaxConsecutiveHours: Double = 12

    // =========================================================================
    // MARK: - Consecutive Early Starts (FD13.6)
    // =========================================================================

    /// Max consecutive duties with sign-on prior to earlyStartSignOnThreshold.
    static let maxConsecutiveEarlyStarts: Int = 4
    /// Sign-on time threshold for early starts, local time (HHMM integer).
    static let earlyStartSignOnThreshold: Int = 706

    // =========================================================================
    // MARK: - Late Night Operations (FD14)
    // =========================================================================

    /// FD14.1 — max consecutive nights with late night ops in any 7-night period.
    static let lateNightMaxConsecutiveNights: Int = 4
    /// FD14.2 — once per 28 consecutive days: max late night nights in any 7-night period.
    static let lateNightMaxConsecutiveNightsException: Int = 5
    static let lateNightExceptionPeriodDays: Int = 28
    /// FD14.3(a) — max duty hours in a 7-night period when >2 LNO duties are present.
    static let lateNightMaxDutyHoursIn7NightPeriod: Double = 40
    /// FD14.3(b) — max duty periods in that 7-night period (except per FD14.2).
    static let lateNightMaxDutyPeriodsIn7NightPeriod: Int = 4
    /// FD14.3(c) — min hours free before any non-LNO duty after consecutive late nights.
    static let lateNightRecoveryMinFreeHours: Double = 24
    /// FD14.4 — back of clock: ≥2 hrs between 0100–0459 local at departure.
    static let backOfClockMinutesThreshold: Int = 120
    /// FD14.4 — next duty in Australia: sign-on no earlier than this local time (HHMM).
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
