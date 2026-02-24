//
//  SH_Operational_FltDuty.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) - Short Haul Operational Limits
//  Source: FRMS Ruleset A320/B737, Revision 4.1, 1 October 2024
//  Chapter 1B: Operations Flight and Duty Limitations (FD21–FD28)
//

import Foundation

// MARK: - SH Operational Flight & Duty Limits (FD23)

struct SH_Operational_FltDuty {

    // MARK: - Types

    enum LocalStartTime: String, CaseIterable {
        case early   = "0500–1459"
        case afternoon = "1500–1959"
        case night   = "2000–0459"

        var range: ClosedRange<Int> {
            switch self {
            case .early:     return 500...1459
            case .afternoon: return 1500...1959
            case .night:     return 2000...2459 // wraps to 0459
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
            if timeAsInt >= 500 && timeAsInt <= 1459 {
                return .early
            } else if timeAsInt >= 1500 && timeAsInt <= 1959 {
                return .afternoon
            } else {
                return .night  // 2000-0459
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

    // MARK: - Maximum Duty Periods – Augmented Crew (FD23.1)

    struct AugmentedDutyLimit {
        let restFacility: AugmentedRestFacility
        let maxDutyHours: Double
        let maxSectors: Int? // nil if no sector restriction stated
    }

    static let augmentedDutyLimits: [AugmentedDutyLimit] = [
        AugmentedDutyLimit(
            restFacility: .separateScreenedSeat,
            maxDutyHours: 16,
            maxSectors: 2 // max 2 sectors if FDP exceeds 14 hours
        ),
        AugmentedDutyLimit(
            restFacility: .passengerCompartmentSeat,
            maxDutyHours: 14,
            maxSectors: nil
        ),
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

    // =========================================================================
    // MARK: - Late Night Operations (FD24)
    // =========================================================================

    /// FD24.1 — max consecutive nights with late night ops in any 7-night period.
    static let lateNightMaxConsecutiveNights: Int = 4
    /// FD24.2 — once per 28 consecutive days: max late night nights in any 7-night period.
    static let lateNightMaxConsecutiveNightsException: Int = 5
    static let lateNightExceptionPeriodDays: Int = 28
    /// FD24.3(a) — max duty hours in a 7-night period when >2 LNO duties are present.
    static let lateNightMaxDutyHoursIn7NightPeriod: Double = 40
    /// FD24.3(b) — max duty periods in that 7-night period (except per FD24.2).
    static let lateNightMaxDutyPeriodsIn7NightPeriod: Int = 4
    /// FD24.3(c) — min hours free before any non-LNO duty after consecutive late nights.
    static let lateNightRecoveryMinFreeHours: Double = 24
    // Note: FD24.4 back-of-clock restriction is not present in operational limits.

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
}
