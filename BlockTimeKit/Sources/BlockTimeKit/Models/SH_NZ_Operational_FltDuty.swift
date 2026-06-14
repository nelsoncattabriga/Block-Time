import Foundation

// MARK: - SH NZ Operational Flight & Duty Limits
// Source: FRMS Ruleset A320/B737, Revision 5, 15 June 2026
// Chapter 4B: New Zealand-Based Flight and Duty Limitations (Operational) FD60–FD68
// Applies to NZ-based crew (homeBase == "NZ"). Australia-based crew use SH_Operational_FltDuty.

public struct SH_NZ_Operational_FltDuty {

    public struct DutyPeriodLimit: Sendable {
        public let localStartTime: SH_Planning_FltDuty.LocalStartTime
        public let maxDutySectors1to4: Double
        public let maxDutySectors5or6: Double

        public init(localStartTime: SH_Planning_FltDuty.LocalStartTime, maxDutySectors1to4: Double, maxDutySectors5or6: Double) {
            self.localStartTime = localStartTime
            self.maxDutySectors1to4 = maxDutySectors1to4
            self.maxDutySectors5or6 = maxDutySectors5or6
        }
    }

    public static let twoPilotDutyLimits: [DutyPeriodLimit] = [
        .init(localStartTime: .early,     maxDutySectors1to4: 14, maxDutySectors5or6: 12),
        .init(localStartTime: .afternoon, maxDutySectors1to4: 13, maxDutySectors5or6: 11),
        .init(localStartTime: .night,     maxDutySectors1to4: 12, maxDutySectors5or6: 11),
    ]

    public static let threePilotDutyLimits: [SH_Planning_FltDuty.ThreePilotDutyLimit] = [
        .init(band: .early,     class2: 16, businessSeat: 14.5),
        .init(band: .afternoon, class2: 16, businessSeat: 13.5),
        .init(band: .night,     class2: 16, businessSeat: 12.5),
    ]

    public static let threePilotMaxSectors = 3
    public static let threePilotMinTotalRestHours = 2.0

    public static func maxDutyHours(localStartTime: SH_Planning_FltDuty.LocalStartTime, sectors: Int) -> Double? {
        guard let limit = twoPilotDutyLimits.first(where: { $0.localStartTime == localStartTime }) else { return nil }
        switch sectors {
        case 1...4: return limit.maxDutySectors1to4
        case 5...6: return limit.maxDutySectors5or6
        default:    return nil
        }
    }

    public static func maxDutyHoursThreePilot(band: SH_Planning_FltDuty.LocalStartTime, rest: SH_Planning_FltDuty.ThreePilotRest) -> Double? {
        guard let limit = threePilotDutyLimits.first(where: { $0.band == band }) else { return nil }
        return rest == .class2 ? limit.class2 : limit.businessSeat
    }

    // =========================================================================
    // MARK: - Cumulative Flight Time Limits (FD60)
    // =========================================================================

    public static let cumulativeFlightTime28DaysHours: Double = 100
    public static let cumulativeFlightTime365DaysHours: Double = 1_000

    // =========================================================================
    // MARK: - Cumulative Duty Time Limits (FD61)
    // =========================================================================

    public static let cumulativeDutyTime7DaysHours: Double = 55
    public static let cumulativeDutyTime14DaysInitialHours: Double = 95
    public static let cumulativeDutyTime28DaysHours: Double = 190
    public static let cumulativeDutyTime7DaysExtendedHours: Double = 60
    public static let cumulativeDutyTime14DaysExtendedHours: Double = 100
    public static let simulatorTrainingDutyFactor: Double = 1.5

    // =========================================================================
    // MARK: - Back of Clock Next Sign-On (FD62.5)
    // =========================================================================

    public static let bocEarliestNextSignOnLocalHHMM: Int = 1000

    // =========================================================================
    // MARK: - Reserve Duty (FD64)
    // =========================================================================

    public static let reserveDutyMaxConsecutiveHours: Double = 12
    public static let reserveMinRestHours: Double = 12

    // =========================================================================
    // MARK: - Time Free from Duty — 2 Pilot (FD68.1–68.2)
    // =========================================================================

    public static let minRestAwayHours: Double = 11
    public static let minRestAwayReducedHours: Double = 10
    public static let minRestHomeBaseHours: Double = 12
    public static let minRestHomeBaseReducedHours: Double = 10
    public static let restExtendedDutyThresholdHours: Double = 12
    public static let restExtendedBaseHours: Double = 12
    public static let restExtendedMultiplier: Double = 1.5

    // =========================================================================
    // MARK: - 3-Pilot Post-Pattern Rest (FD68)
    // =========================================================================

    public static let threePilotPatternRestOperational: [SH_Operational_FltDuty.ThreePilotPatternRest] = [
        .init(tafbMaxHours: 52,  dayReturn: 12.0, multiDay: 12.0, formulaIfOver12: true,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: 124, dayReturn: nil,  multiDay: nil,  formulaIfOver12: true,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: nil, dayReturn: nil,  multiDay: 22.0, formulaIfOver12: false, nextDutyDayMinHours: 9.59),
    ]
}
