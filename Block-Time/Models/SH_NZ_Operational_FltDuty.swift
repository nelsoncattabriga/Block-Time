import Foundation

// MARK: - SH NZ Operational Flight & Duty Limits
// Source: FRMS Ruleset A320/B737, Revision 5, 15 June 2026
// Chapter 4B: New Zealand-Based Flight and Duty Limitations (Operational) FD60–FD68
// Applies to NZ-based crew (homeBase == "NZ"). Australia-based crew use SH_Operational_FltDuty.

struct SH_NZ_Operational_FltDuty {

    // MARK: - Maximum Duty Periods – 2 Pilot Operations (FD62.1)

    struct DutyPeriodLimit {
        let localStartTime: SH_Planning_FltDuty.LocalStartTime
        let maxDutySectors1to4: Double
        let maxDutySectors5or6: Double
    }

    static let twoPilotDutyLimits: [DutyPeriodLimit] = [
        .init(localStartTime: .early,     maxDutySectors1to4: 14, maxDutySectors5or6: 12),
        .init(localStartTime: .afternoon, maxDutySectors1to4: 13, maxDutySectors5or6: 11),
        .init(localStartTime: .night,     maxDutySectors1to4: 12, maxDutySectors5or6: 11),
    ]

    // MARK: - Maximum Duty Periods – 3 Pilot Operations (FD62.1)
    // Same values as AU operational. Max 3 sectors. Min 2 h total rest.

    static let threePilotDutyLimits: [SH_Planning_FltDuty.ThreePilotDutyLimit] = [
        .init(band: .early,     class2: 16, businessSeat: 14.5),
        .init(band: .afternoon, class2: 16, businessSeat: 13.5),
        .init(band: .night,     class2: 16, businessSeat: 12.5),
    ]

    static let threePilotMaxSectors = 3
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
    // MARK: - Cumulative Flight Time Limits (FD60)
    // =========================================================================

    static let cumulativeFlightTime28DaysHours: Double = 100
    static let cumulativeFlightTime365DaysHours: Double = 1_000

    // =========================================================================
    // MARK: - Cumulative Duty Time Limits (FD61)
    // Same initial/extended limits as Chapter 4A planning.
    // =========================================================================

    static let cumulativeDutyTime7DaysHours: Double = 55
    static let cumulativeDutyTime14DaysInitialHours: Double = 95
    static let cumulativeDutyTime28DaysHours: Double = 190
    static let cumulativeDutyTime7DaysExtendedHours: Double = 60
    static let cumulativeDutyTime14DaysExtendedHours: Double = 100
    static let simulatorTrainingDutyFactor: Double = 1.5

    // =========================================================================
    // MARK: - Back of Clock Next Sign-On (FD62.5)
    // =========================================================================

    /// FD62.5 — after a BOC flying duty, next NZ flying duty must sign on no
    /// earlier than this local time (HHMM). Pilot may waive.
    static let bocEarliestNextSignOnLocalHHMM: Int = 1000

    // =========================================================================
    // MARK: - Reserve Duty (FD64)
    // =========================================================================

    static let reserveDutyMaxConsecutiveHours: Double = 12
    static let reserveMinRestHours: Double = 12

    // =========================================================================
    // MARK: - Time Free from Duty — 2 Pilot (FD68.1–68.2)
    // =========================================================================

    static let minRestAwayHours: Double = 11
    static let minRestAwayReducedHours: Double = 10
    static let minRestHomeBaseHours: Double = 12
    static let minRestHomeBaseReducedHours: Double = 10
    static let restExtendedDutyThresholdHours: Double = 12
    static let restExtendedBaseHours: Double = 12
    static let restExtendedMultiplier: Double = 1.5

    // =========================================================================
    // MARK: - 3-Pilot Post-Pattern Rest (FD68)
    // =========================================================================

    // FD68 operational table. formulaIfOver12: ≤52 and 52–<124 brackets apply
    // 12 + 1.5×(duty-12) when last duty > 12 h. Note 1: Refer to FD62.5.

    static let threePilotPatternRestOperational: [SH_Operational_FltDuty.ThreePilotPatternRest] = [
        .init(tafbMaxHours: 52,  dayReturn: 12.0, multiDay: 12.0, formulaIfOver12: true,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: 124, dayReturn: nil,  multiDay: nil,  formulaIfOver12: true,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: nil, dayReturn: nil,  multiDay: 22.0, formulaIfOver12: false, nextDutyDayMinHours: 9.59),
    ]
}
