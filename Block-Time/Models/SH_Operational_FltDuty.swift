//
//  SH_Operational_FltDuty.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) - Short Haul Operational Limits
//  Source: FRMS Ruleset A320/B737, Revision 5, 15 June 2026
//  Chapter 1B: Operations Flight and Duty Limitations (FD21–FD28)
//  Applies to Australia-based crew. NZ-based crew use SH_NZ_* (Chapter 4A/4B).
//

import Foundation

// MARK: - SH Operational Flight & Duty Limits (FD23)

struct SH_Operational_FltDuty {

    // MARK: - Types

    // Rev 5 (FD23.1): start-time bands shifted. Hour values unchanged.
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

            // Check ranges (note: night wraps around midnight) — Rev 5 bands
            if timeAsInt >= 500 && timeAsInt <= 1259 {
                return .early
            } else if timeAsInt >= 1300 && timeAsInt <= 1759 {
                return .afternoon
            } else {
                return .night  // 1800-0459
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
        DutyPeriodLimit(localStartTime: .early,      maxDutySectors1to4: 14, maxDutySectors5: 13, maxDutySectors6: 12),
        DutyPeriodLimit(localStartTime: .afternoon,  maxDutySectors1to4: 13, maxDutySectors5: 12, maxDutySectors6: 11),
        DutyPeriodLimit(localStartTime: .night,      maxDutySectors1to4: 12, maxDutySectors5: 12, maxDutySectors6: 11),
    ]

    // MARK: - Maximum Duty Periods – 3 Pilot Operations (FD23.1, Rev 5)
    // Start-time-banded Class 2 vs Business Seat table. Max 3 sectors. Min 2 h total rest.

    struct ThreePilotDutyLimit {
        let band: LocalStartTime
        let class2: Double       // hours
        let businessSeat: Double // hours
    }

    static let threePilotDutyLimits: [ThreePilotDutyLimit] = [
        .init(band: .early,     class2: 16, businessSeat: 14.5),
        .init(band: .afternoon, class2: 16, businessSeat: 13.5),
        .init(band: .night,     class2: 16, businessSeat: 12.5),
    ]

    static let threePilotMaxSectors = 3           // FD23.1 operational
    static let threePilotMinTotalRestHours = 2.0  // FD23.1 table note

    // MARK: - Lookup Helpers

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

    /// Returns the max duty for a 3-pilot operation by band and rest type.
    static func maxDutyHoursThreePilot(band: LocalStartTime, rest: SH_Planning_FltDuty.ThreePilotRest) -> Double? {
        guard let limit = threePilotDutyLimits.first(where: { $0.band == band }) else { return nil }
        return rest == .class2 ? limit.class2 : limit.businessSeat
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
    // MARK: - Reserve Duty (FD23.3–23.5, Rev 5)
    // =========================================================================

    /// FD23.3 — max consecutive reserve duty hours.
    static let reserveDutyMaxConsecutiveHours: Double = 12

    /// FD23.4 — max combined reserve + flying duty hours after call-out.
    /// Exceptions: (a) augmented; (b) split per FD27; (c) 18 h operational necessity.
    static let reserveCallOutMaxCombinedHours: Double = 16
    static let reserveCallOutMaxCombinedHoursOpNecessity: Double = 18

    /// FD23.5 — reserve starting in this window does not count toward FD23.4 until contacted.
    static let reserveNightWindowStartHHMM = 2300
    static let reserveNightWindowEndHHMM   = 600

    // =========================================================================
    // MARK: - Late Night Operations / Back of Clock (FD24, Rev 5)
    // =========================================================================

    /// FD24.1 — >2 consecutive LNO flying duties triggers 24 h free of duty.
    static let lnoConsecutiveTriggerCount = 2
    static let lnoPostExcessFreeHours: Double = 24

    /// FD24.2 — max LNO flying duty periods in any 168-hour rolling window.
    static let lnoMaxPeriodsIn168h = 4

    /// FD24.3 — FD24.1 and FD24.2 do NOT apply to reserve duty periods.
    // (no numeric constant — handled in engine logic)

    /// FD24.4 — max BOC flying duty periods in any 168-hour rolling window (pilot may waive).
    /// FD24.5 — back of clock: next duty in Australia sign-on no earlier than 1000 local.
    static let bocMaxPeriodsIn168h = 2

    /// Shared rolling window for both LNO and BOC caps.
    static let lnoRollingWindowHours = 168

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

    // MARK: - 3-Pilot Post-Pattern Rest (FD28, Rev 5)
    // tafbMaxHours nil = 124+ bracket. Refer FD24.5.

    struct ThreePilotPatternRest {
        let tafbMaxHours: Double?   // upper bound of TAFB bracket; nil = 124+
        let dayReturn: Double?      // min rest day-return; nil = not applicable
        let multiDay: Double?       // min rest multi-day pattern
        let formulaIfOver12: Bool   // true = apply 12 + 1.5×(duty-12) instead of flat figure
        let nextDutyDayMinHours: Double?
    }

    // ≤52: day 12, multi 12 (or 12+1.5×excess if last duty >12); 52–<124: same formula; 124+: 22.
    static let threePilotPatternRestOperational: [ThreePilotPatternRest] = [
        .init(tafbMaxHours: 52,  dayReturn: 12.0, multiDay: 12.0, formulaIfOver12: true,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: 124, dayReturn: nil,  multiDay: nil,  formulaIfOver12: true,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: nil, dayReturn: nil,  multiDay: 22.0, formulaIfOver12: false, nextDutyDayMinHours: 9.59),
    ]
}
