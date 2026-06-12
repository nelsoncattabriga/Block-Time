import Foundation

// MARK: - SH NZ Planning Flight & Duty Limits
// Source: FRMS Ruleset A320/B737, Revision 5, 15 June 2026
// Chapter 4A: New Zealand-Based Flight and Duty Limitations (Planning) FD47–FD55
// Applies to NZ-based crew (homeBase == "NZ"). Australia-based crew use SH_Planning_FltDuty.

public struct SH_NZ_Planning_FltDuty {

    public static let twoPilotDutyLimits: [SH_Planning_FltDuty.DutyPeriodLimit] = [
        .init(localStartTime: .early,     maxDutySectors1to4: 12, maxDutySectors5or6: 11),
        .init(localStartTime: .afternoon, maxDutySectors1to4: 11, maxDutySectors5or6: 10),
        .init(localStartTime: .night,     maxDutySectors1to4: 10, maxDutySectors5or6: 10),
    ]

    public static let threePilotDutyLimits: [SH_Planning_FltDuty.ThreePilotDutyLimit] = [
        .init(band: .early,     class2: 14, businessSeat: 14),
        .init(band: .afternoon, class2: 14, businessSeat: 13),
        .init(band: .night,     class2: 14, businessSeat: 12),
    ]

    public static let threePilotMaxSectors = 2
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
    // MARK: - Cumulative Flight Time Limits (FD47)
    // =========================================================================

    public static let cumulativeFlightTime28DaysHours: Double = 100
    public static let cumulativeFlightTime365DaysHours: Double = 1_000

    // =========================================================================
    // MARK: - Cumulative Duty Time Limits (FD48)
    // =========================================================================

    public static let cumulativeDutyTime7DaysHours: Double = 55
    public static let cumulativeDutyTime14DaysInitialHours: Double = 95
    public static let cumulativeDutyTime28DaysHours: Double = 190
    public static let cumulativeDutyTime7DaysExtendedHours: Double = 60
    public static let cumulativeDutyTime14DaysExtendedHours: Double = 100
    public static let simulatorTrainingDutyFactor: Double = 1.5

    // =========================================================================
    // MARK: - Rostered Days Off (FD42)
    // =========================================================================

    public static let minRDOsPerRosterPeriod: Int = 11
    public static let minRDOsAgreedReduction: Int = 9
    public static let minRDODurationHours: Double = 36

    // =========================================================================
    // MARK: - Consecutive Early Starts (FD49.3)
    // =========================================================================

    public static let maxConsecutiveEarlyStarts: Int = 4
    public static let earlyStartSignOnThreshold: Int = 706

    // =========================================================================
    // MARK: - Back of Clock Next Sign-On (FD49.4)
    // =========================================================================

    public static let bocEarliestNextSignOnLocalHHMM: Int = 1000

    // =========================================================================
    // MARK: - Reserve Duty (FD51)
    // =========================================================================

    public static let reserveDutyMaxConsecutiveHours: Double = 12
    public static let reserveMinRestHours: Double = 12

    // =========================================================================
    // MARK: - Time Free from Duty — 2 Pilot (FD55.1–55.2)
    // =========================================================================

    public static let minRestAwayHours: Double = 11
    public static let minRestAwayReducedHours: Double = 10
    public static let minRestHomeBaseHours: Double = 12
    public static let minRestHomeBaseReducedHours: Double = 10
    public static let restExtendedDutyThresholdHours: Double = 12
    public static let restExtendedBaseHours: Double = 12
    public static let restExtendedMultiplier: Double = 1.5

    // =========================================================================
    // MARK: - 3-Pilot Post-Pattern Rest (FD55)
    // =========================================================================

    public static let threePilotPatternRestPlanning: [SH_Planning_FltDuty.AugmentedPatternRest] = [
        .init(tafbMaxHours: 52,  dayReturn: 14.5, multiDay: 15,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: 124, dayReturn: nil,  multiDay: 22,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: nil, dayReturn: nil,  multiDay: 32,  nextDutyDayMinHours: nil),
    ]

    // =========================================================================
    // MARK: - Time Free from Duty — All Operations (FD55.3–55.4)
    // =========================================================================

    public static let minHoursFreeIn7Days: Double = 36

    public struct DaysFreeRequirement: Sendable {
        public let description: String
        public let minDaysFree: Int
        public let inConsecutiveDays: Int

        public init(description: String, minDaysFree: Int, inConsecutiveDays: Int) {
            self.description = description
            self.minDaysFree = minDaysFree
            self.inConsecutiveDays = inConsecutiveDays
        }
    }

    public static let daysFreeRequirements: [DaysFreeRequirement] = [
        .init(description: "Min free days in any 28 consecutive days",          minDaysFree: 7,  inConsecutiveDays: 28),
        .init(description: "Min free days in any 84 consecutive days",          minDaysFree: 24, inConsecutiveDays: 84),
        .init(description: "Min free days per calendar month",                   minDaysFree: 8,  inConsecutiveDays: 0),
        .init(description: "Min free days in any 3 consecutive calendar months", minDaysFree: 26, inConsecutiveDays: 0),
    ]
}
