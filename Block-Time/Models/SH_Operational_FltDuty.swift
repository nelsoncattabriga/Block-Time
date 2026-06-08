//
//  SH_Operational_FltDuty.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) - Short Haul Operational Limits
//  Source: FRMS Ruleset A320/B737, Revision 5, 15 June 2026
//  Chapter 1B: Operations Flight and Duty Limitations (FD21–FD28)
//

import Foundation

// MARK: - SH Operational Flight & Duty Limits (FD23)

struct SH_Operational_FltDuty {

    // MARK: - Types

    enum LocalStartTime: String, CaseIterable {
        case early   = "0500–1259"
        case afternoon = "1300–1759"
        case night   = "1800–0459"

        var range: ClosedRange<Int> {
            switch self {
            case .early:     return 500...1259
            case .afternoon: return 1300...1759
            case .night:     return 1800...2459 // wraps to 0459
            }
        }

        /// Display name for UI
        var displayName: String {
            switch self {
            case .early: return "Early Morning"
            case .afternoon: return "Afternoon"
            case .night: return "Night"
            }
        }

        /// Determine LocalStartTime from a given time in home base timezone
        /// - Parameter time: The sign-on time
        /// - Parameter homeBaseTimeZone: The crew's home base timezone
        /// - Returns: The LocalStartTime classification
        static func classify(signOn: Date, homeBaseTimeZone: TimeZone) -> LocalStartTime {
            var calendar = Calendar.current
            calendar.timeZone = homeBaseTimeZone

            let hour = calendar.component(.hour, from: signOn)
            let minute = calendar.component(.minute, from: signOn)
            let timeAsInt = hour * 100 + minute

            // Check ranges (note: night wraps around midnight)
            if timeAsInt >= 500 && timeAsInt <= 1259 {
                return .early
            } else if timeAsInt >= 1300 && timeAsInt <= 1759 {
                return .afternoon
            } else {
                return .night  // 1800-0459
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

        var description: String {
            switch self {
            case .separateScreenedSeat: return "Separate Screened Seat"
            case .passengerCompartmentSeat: return "Passenger Compartment Seat"
            }
        }
    }

    // MARK: - Maximum Duty Periods – 2 Pilot Operations (FD23.1)

    struct DutyPeriodLimit {
        let localStartTime: LocalStartTime
        let maxDutySectors1to4: Double // hours
        let maxDutySectors5: Double    // hours
        let maxDutySectors6: Double    // hours
    }

    static let twoPilotDutyLimits: [DutyPeriodLimit] = [
        DutyPeriodLimit(localStartTime: .early,     maxDutySectors1to4: 14, maxDutySectors5: 13, maxDutySectors6: 12),
        DutyPeriodLimit(localStartTime: .afternoon,  maxDutySectors1to4: 13, maxDutySectors5: 12, maxDutySectors6: 11),
        DutyPeriodLimit(localStartTime: .night,      maxDutySectors1to4: 12, maxDutySectors5: 12, maxDutySectors6: 11),
    ]

    // MARK: - Maximum Duty Periods – 3 Pilot Operations (FD23.1)
    // Rev 5: limits vary by both rest facility and local start time band. Max 3 sectors.

    struct ThreePilotDutyLimit {
        let localStartTime: LocalStartTime
        let class2RestHours: Double      // Class 2 = separate screened seat
        let businessSeatHours: Double    // Business Seat = passenger compartment seat
        static let maxSectors: Int = 3
    }

    static let threePilotDutyLimits: [ThreePilotDutyLimit] = [
        ThreePilotDutyLimit(localStartTime: .early,     class2RestHours: 16,   businessSeatHours: 14.5),
        ThreePilotDutyLimit(localStartTime: .afternoon, class2RestHours: 16,   businessSeatHours: 13.5),
        ThreePilotDutyLimit(localStartTime: .night,     class2RestHours: 16,   businessSeatHours: 12.5),
    ]

    static func threePilotMaxDutyHours(localStartTime: LocalStartTime, restFacility: AugmentedRestFacility) -> Double {
        let limit = threePilotDutyLimits.first(where: { $0.localStartTime == localStartTime })
            ?? threePilotDutyLimits.last(where: { $0.localStartTime == .night })!
        return restFacility == .separateScreenedSeat ? limit.class2RestHours : limit.businessSeatHours
    }

    // MARK: - Maximum Duty Periods – Augmented Crew (FD23.1)
    // Legacy flat limits retained for 4-pilot fallback use.

    struct AugmentedDutyLimit {
        let restFacility: AugmentedRestFacility
        let maxDutyHours: Double
        let maxSectors: Int?
    }

    static let augmentedDutyLimits: [AugmentedDutyLimit] = [
        AugmentedDutyLimit(restFacility: .separateScreenedSeat,     maxDutyHours: 16, maxSectors: 2),
        AugmentedDutyLimit(restFacility: .passengerCompartmentSeat, maxDutyHours: 14, maxSectors: nil),
    ]

    // MARK: - Flight Time Limits – 2 Pilot Operations (FD23.3)

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

    // MARK: - Flight Time Limits – More Than 2 Pilots (FD23.4)

    static let augmentedFlightTimeLimitHours: Double = 10.5

    // MARK: - Lookup Helpers

    /// Returns the maximum duty period in hours for a 2-pilot operation
    /// - Parameters:
    ///   - localStartTime: The local start time classification
    ///   - sectors: Number of sectors
    /// - Returns: Maximum duty hours, or nil if sectors exceed limit
    static func maxDutyHours(localStartTime: LocalStartTime, sectors: Int) -> Double? {
        guard let limit = twoPilotDutyLimits.first(where: { $0.localStartTime == localStartTime }) else {
            return nil
        }
        switch sectors {
        case 1...4: return limit.maxDutySectors1to4
        case 5:     return limit.maxDutySectors5
        case 6:     return limit.maxDutySectors6
        default:    return nil
        }
    }

    /// Returns the applicable flight time limit in hours for a 2-pilot operation
    /// - Parameters:
    ///   - sectorsScheduled: Number of sectors scheduled
    ///   - darknessFlightTimeExceeds7Hours: Whether flight time in darkness exceeds 7 hours
    /// - Returns: Maximum flight time in hours
    static func maxFlightTimeHours(sectorsScheduled: Int, darknessFlightTimeExceeds7Hours: Bool) -> Double {
        if darknessFlightTimeExceeds7Hours {
            return 9.5
        } else if sectorsScheduled > 1 {
            return 10
        } else {
            return 10.5
        }
    }

    /// Returns the maximum duty period in hours for augmented crew operations
    /// - Parameters:
    ///   - restFacility: The type of rest facility available
    ///   - sectors: Number of sectors (used to check sector restrictions)
    ///   - dutyHours: Proposed duty hours (used to check sector restrictions)
    /// - Returns: Maximum duty hours, or nil if not compliant with sector restrictions
    static func maxDutyHoursAugmented(restFacility: AugmentedRestFacility, sectors: Int, dutyHours: Double) -> Double? {
        guard let limit = augmentedDutyLimits.first(where: { $0.restFacility == restFacility }) else {
            return nil
        }

        // Check sector restrictions for separate screened seat
        if restFacility == .separateScreenedSeat {
            // If FDP exceeds 14 hours, max 2 sectors allowed
            if dutyHours > 14 && sectors > 2 {
                return nil  // Not compliant
            }
        }

        return limit.maxDutyHours
    }

    // =========================================================================
    // MARK: - Cumulative Flight Time Limits (FD21.1)
    // =========================================================================

    static let cumulativeFlightTime28DaysHours: Double = 100
    static let cumulativeFlightTime365DaysHours: Double = 1_000

    // =========================================================================
    // MARK: - Cumulative Duty Time Limits (FD22)
    // =========================================================================

    static let cumulativeDutyTime7DaysHours: Double = 60
    /// FD22 — initial roster publication limit.
    static let cumulativeDutyTime14DaysInitialHours: Double = 90
    /// FD22 — maximum with pilot agreement or open time bid.
    static let cumulativeDutyTime14DaysExtendedHours: Double = 100
    /// FD22.1 — duty multiplier for simulator/training flights for trainee and
    /// support pilot (excludes line training, line checks, deadheading).
    static let simulatorTrainingDutyFactor: Double = 1.5
    /// FD22.2 — max duty days in any 11-day period.
    static let maxDutyDaysIn11Days: Int = 9
    /// FD22.2 — max consecutive duty days.
    static let maxConsecutiveDutyDays: Int = 6
    /// FD22.3 — min hours free of all duty in any 7 consecutive days.
    static let minHoursFreeIn7ConsecutiveDays: Double = 36
    /// FD22.3 — alternative: 2 consecutive local nights in any 8 consecutive nights.
    /// A local night is no later than 22:00 and no earlier than 05:00.
    static let minConsecutiveLocalNightsIn8Nights: Int = 2

    // =========================================================================
    // MARK: - Emergency Procedures Training Extension (FD23.2)
    // =========================================================================

    /// Max duty for a pilot not based in SYD or MEL undertaking EPT at another base.
    static let emergencyProceduresTrainingMaxDutyHours: Double = 15

    // =========================================================================
    // MARK: - Reserve Duty (FD23.5)
    // =========================================================================

    /// Max consecutive reserve duty hours. Pilot must have access to suitable
    /// sleeping accommodation and be free from all employment duties.
    static let reserveDutyMaxConsecutiveHours: Double = 12
    /// FD23.4(c) (Rev 5) — when operationally necessary and pilot fit, combined reserve + duty max.
    static let reserveCombinedMaxDutyHoursOperationalNecessity: Double = 18

    // =========================================================================
    // MARK: - Late Night Operations (FD24)
    // =========================================================================

    /// FD24.1 — max consecutive nights with late night ops in any 7-night period.
    static let lateNightMaxConsecutiveNights: Int = 4
    /// FD24.3 (Rev 5) — max LNO duty periods (late night or back-of-clock) in any 168-hour window.
    static let lateNightMaxDutiesIn168Hours: Int = 4
    /// FD24.3(c) — min hours free before any non-LNO duty after consecutive late nights.
    static let lateNightRecoveryMinFreeHours: Double = 24
    /// FD24.4 (Rev 5) — max BOC duty periods in any 168-hour window.
    static let backOfClockMaxDutiesIn168Hours: Int = 2

    // =========================================================================
    // MARK: - Deadheading Following a Flight Duty (FD25)
    // =========================================================================

    /// FD25.6 — no duty period that includes flight duty may exceed this total.
    static let deadheadingAbsoluteMaxDutyHours: Double = 16

    // =========================================================================
    // MARK: - Split Duty (FD27)
    // =========================================================================

    /// FD27 operational split duty has two accommodation types, each with
    /// different duty increase allowances.
    enum SplitDutyAccommodation {
        /// Suitable sleeping accommodation — allows +4 hrs and rest discounting.
        case sleeping
        /// Suitable resting accommodation — allows +2 hrs, no rest discounting.
        case resting
    }

    struct SplitDutyRules {
        let accommodation: SplitDutyAccommodation
        /// FD27 — min rest required.
        let minRestHours: Double
        /// FD27 — max additional duty beyond FD23.1 base limits.
        let maxDutyIncreaseHours: Double
        /// FD27 — total duty must not exceed this (nil = no stated max for resting).
        let maxTotalDutyHours: Double?
        /// FD27.2 — rest discount fraction (sleeping accommodation only).
        let restDiscountFraction: Double?
        /// FD27.2 — maximum discount in hours (sleeping accommodation only).
        let maxRestDiscountHours: Double?
        /// FD27.4 — if rest includes any period in this window, stricter rules apply.
        let nightWindowStart: String
        let nightWindowEnd: String
        /// FD27.4 — rest must be uninterrupted for at least this duration.
        let nightRestMinUninterruptedHours: Double
        /// FD27.4 — max total duty when night window rule applies.
        let nightRestMaxTotalDutyHours: Double
        /// FD27.4 — rest discounting not permitted when night window rule applies.
        let nightRestDiscountPermitted: Bool
    }

    static let splitDutyRulesBySleeping = SplitDutyRules(
        accommodation: .sleeping,
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

    static let splitDutyRulesByResting = SplitDutyRules(
        accommodation: .resting,
        minRestHours: 6,
        maxDutyIncreaseHours: 2,
        maxTotalDutyHours: nil,
        restDiscountFraction: nil,
        maxRestDiscountHours: nil,
        nightWindowStart: "2300",
        nightWindowEnd: "0530",
        nightRestMinUninterruptedHours: 7,
        nightRestMaxTotalDutyHours: 16,
        nightRestDiscountPermitted: false
    )

    // =========================================================================
    // MARK: - Time Free from Duty (FD28)
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
        /// FD28 — reduced minimum when duty ≤ reducedRestMaxDutyHours and
        /// rest period includes the specified overnight window.
        let reducedRestMinHours: Double
        /// FD28 — duty must not exceed this for the reduced rest option to apply.
        let reducedRestMaxDutyHours: Double
        /// FD28 — window that must be included in rest for reduction to apply.
        let reducedRestWindowStart: String
        let reducedRestWindowEnd: String
        /// FD28 — minimum rest after a standby with no call-out.
        let standbyNoCalloutMinRestHours: Double
    }

    /// FD28 — duty ≤ 12 hrs: min free = max(10, duty); duty > 12 hrs: 12 + 1.5 × (duty − 12).
    /// Additional: duty ≤ 10 hrs with 2200–0600 overnight → may reduce to 9 hrs.
    /// Standby with no call-out → 10 hrs minimum.
    static let timeFreeFromDuty = TimeFreeWithinPatternFormula(
        dutyThresholdHours: 12,
        minFreeHours: 10,
        baseHours: 12,
        multiplier: 1.5,
        reducedRestMinHours: 9,
        reducedRestMaxDutyHours: 10,
        reducedRestWindowStart: "2200",
        reducedRestWindowEnd: "0600",
        standbyNoCalloutMinRestHours: 10
    )

    /// FD28 — min hours free of all duty in any 7 consecutive days.
    static let minHoursFreeIn7Days: Double = 36
    /// FD28 — alternative: 2 consecutive local nights in any 8 consecutive nights
    /// (no later than 22:00 – no earlier than 05:00).
    static let minConsecutiveLocalNightsIn8NightsFree: Int = 2

    struct DaysFreeRequirement {
        let description: String
        let minDaysFree: Int
        /// 0 = calendar-based period rather than rolling consecutive days.
        let inConsecutiveDays: Int
    }

    /// FD28.5 — minimum days free requirements (either option (a) or option (b)+(c)).
    static let daysFreeRequirements: [DaysFreeRequirement] = [
        DaysFreeRequirement(description: "Min free days in any 28 consecutive days",          minDaysFree: 7,  inConsecutiveDays: 28),
        DaysFreeRequirement(description: "Min free days in any 84 consecutive days",          minDaysFree: 24, inConsecutiveDays: 84),
        DaysFreeRequirement(description: "Min free days per calendar month",                   minDaysFree: 8,  inConsecutiveDays: 0),
        DaysFreeRequirement(description: "Min free days in any 3 consecutive calendar months", minDaysFree: 26, inConsecutiveDays: 0),
    ]

    // =========================================================================
    // MARK: - 3-Pilot Post-Pattern Rest (FD28, Rev 5)
    // =========================================================================

    /// Encodes one row of the Rev 5 FD28 augmented post-pattern rest table.
    struct ThreePilotPatternRest {
        /// Lower bound of TAFB range (inclusive), in hours.
        let tafbFromHours: Double
        /// Upper bound of TAFB range (exclusive), or .infinity for the open-ended last row.
        let tafbToHours: Double
        /// Whether this row applies to a same-day return pattern.
        let isDayReturn: Bool
        /// Minimum post-pattern free hours. For duty > 12 hrs, use the formula instead.
        let minRestHours: Double
        /// When true, apply 12 + 1.5 × (lastDuty − 12) if lastDuty > 12 hrs.
        let applyExtendedFormula: Bool
        /// This rest requirement only applies when the next duty day exceeds this threshold (hrs).
        /// nil = applies unconditionally.
        let appliesWhenNextDutyDayExceedsHours: Double?
    }

    /// FD28 (Rev 5) — 3-pilot operational post-pattern rest table.
    /// Rows are ordered; use the first matching row.
    static let threePilotPatternRestRequirements: [ThreePilotPatternRest] = [
        // TAFB ≤ 52 hrs, day return
        ThreePilotPatternRest(tafbFromHours: 0,    tafbToHours: 52,       isDayReturn: true,  minRestHours: 12,  applyExtendedFormula: false, appliesWhenNextDutyDayExceedsHours: nil),
        // TAFB ≤ 52 hrs, multi-day — 12 hrs; or 12 + 1.5× over 12 if last duty > 12 hrs (next duty day > 9.59 hrs)
        ThreePilotPatternRest(tafbFromHours: 0,    tafbToHours: 52,       isDayReturn: false, minRestHours: 12,  applyExtendedFormula: true,  appliesWhenNextDutyDayExceedsHours: 9.983),
        // TAFB 52–124 hrs, multi-day only (same formula)
        ThreePilotPatternRest(tafbFromHours: 52,   tafbToHours: 124,      isDayReturn: false, minRestHours: 12,  applyExtendedFormula: true,  appliesWhenNextDutyDayExceedsHours: 9.983),
        // TAFB ≥ 124 hrs, multi-day — 22 hrs flat
        ThreePilotPatternRest(tafbFromHours: 124,  tafbToHours: .infinity, isDayReturn: false, minRestHours: 22, applyExtendedFormula: false, appliesWhenNextDutyDayExceedsHours: 9.983),
    ]

    /// Calculate minimum post-pattern rest for a 3-pilot operational duty.
    /// - Parameters:
    ///   - tafbHours: Time Away From Base in hours for the completed pattern.
    ///   - isDayReturn: True if the crew returns on the same day the pattern started.
    ///   - lastDutyHours: Actual duration of the last duty period in the pattern.
    ///   - nextDutyDayHours: Planned duration of the next duty day (to test the >9.59 trigger).
    /// - Returns: Minimum free hours required, or nil if no augmented rule matches.
    static func threePilotMinPostPatternRestHours(tafbHours: Double,
                                                  isDayReturn: Bool,
                                                  lastDutyHours: Double,
                                                  nextDutyDayHours: Double?) -> Double? {
        guard let row = threePilotPatternRestRequirements.first(where: {
            tafbHours >= $0.tafbFromHours &&
            tafbHours < $0.tafbToHours &&
            isDayReturn == $0.isDayReturn
        }) else { return nil }

        if let threshold = row.appliesWhenNextDutyDayExceedsHours,
           let next = nextDutyDayHours,
           next <= threshold {
            return nil
        }

        guard row.applyExtendedFormula && lastDutyHours > 12 else {
            return row.minRestHours
        }
        return 12 + 1.5 * (lastDutyHours - 12)
    }
}
