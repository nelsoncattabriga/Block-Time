import Foundation

// MARK: - SH Planning Flight & Duty Limits
// Source: FRMS Ruleset A320/B737, Revision 5, 15 June 2026
// Chapter 1A: Planning Flight and Duty Limitations (FD11–FD20)
// Applies to Australia-based crew. NZ-based crew use SH_NZ_* (Chapter 4A/4B).

public struct SH_Planning_FltDuty {

    // MARK: - Types

    public enum LocalStartTime: String, CaseIterable, Sendable {
        case early     = "0500–1259"
        case afternoon = "1300–1759"
        case night     = "1800–0459"

        public var range: ClosedRange<Int> {
            switch self {
            case .early:     return 500...1259
            case .afternoon: return 1300...1759
            case .night:     return 1800...2459
            }
        }
    }

    // MARK: - Maximum Duty Periods – 2 Pilot Operations (FD13.1)

    public struct DutyPeriodLimit: Sendable {
        public let localStartTime: LocalStartTime
        public let maxDutySectors1to4: Double
        public let maxDutySectors5or6: Double

        public init(localStartTime: LocalStartTime, maxDutySectors1to4: Double, maxDutySectors5or6: Double) {
            self.localStartTime = localStartTime
            self.maxDutySectors1to4 = maxDutySectors1to4
            self.maxDutySectors5or6 = maxDutySectors5or6
        }
    }

    public static let twoPilotDutyLimits: [DutyPeriodLimit] = [
        DutyPeriodLimit(localStartTime: .early,      maxDutySectors1to4: 12, maxDutySectors5or6: 11),
        DutyPeriodLimit(localStartTime: .afternoon,  maxDutySectors1to4: 11, maxDutySectors5or6: 10),
        DutyPeriodLimit(localStartTime: .night,      maxDutySectors1to4: 10, maxDutySectors5or6: 10),
    ]

    // MARK: - Maximum Duty Periods – 3 Pilot Operations (FD13.1, Rev 5)

    public enum ThreePilotRest: Sendable { case class2, businessSeat }

    public struct ThreePilotDutyLimit: Sendable {
        public let band: LocalStartTime
        public let class2: Double
        public let businessSeat: Double

        public init(band: LocalStartTime, class2: Double, businessSeat: Double) {
            self.band = band
            self.class2 = class2
            self.businessSeat = businessSeat
        }
    }

    public static let threePilotDutyLimits: [ThreePilotDutyLimit] = [
        .init(band: .early,     class2: 14, businessSeat: 14),
        .init(band: .afternoon, class2: 14, businessSeat: 13),
        .init(band: .night,     class2: 14, businessSeat: 12),
    ]

    public static let threePilotMaxSectors = 2
    public static let threePilotMinTotalRestHours = 2.0

    // MARK: - Lookup Helpers

    public static func maxDutyHours(localStartTime: LocalStartTime, sectors: Int) -> Double? {
        guard let limit = twoPilotDutyLimits.first(where: { $0.localStartTime == localStartTime }) else {
            return nil
        }
        switch sectors {
        case 1...4: return limit.maxDutySectors1to4
        case 5...6: return limit.maxDutySectors5or6
        default:    return nil
        }
    }

    public static func maxDutyHoursThreePilot(band: LocalStartTime, rest: ThreePilotRest) -> Double? {
        guard let limit = threePilotDutyLimits.first(where: { $0.band == band }) else { return nil }
        return rest == .class2 ? limit.class2 : limit.businessSeat
    }

    // =========================================================================
    // MARK: - Cumulative Flight Time Limits (FD11.1)
    // =========================================================================

    public static let cumulativeFlightTime28DaysHours: Double = 100
    public static let cumulativeFlightTime365DaysHours: Double = 1_000
    public static let cumulativeFlightTime13BidPeriodsHours: Double = 950

    // =========================================================================
    // MARK: - Cumulative Duty Time Limits (FD12)
    // =========================================================================

    public static let cumulativeDutyTime7DaysHours: Double = 60
    public static let cumulativeDutyTime14DaysInitialHours: Double = 90
    public static let cumulativeDutyTime14DaysExtendedHours: Double = 100
    public static let simulatorTrainingDutyFactor: Double = 1.5
    public static let maxDutyDaysIn11Days: Int = 9
    public static let maxConsecutiveDutyDays: Int = 6
    public static let minHoursFreeIn7ConsecutiveDays: Double = 36

    // =========================================================================
    // MARK: - Emergency Procedures Training Extension (FD13.2)
    // =========================================================================

    public static let emergencyProceduresTrainingMaxDutyHours: Double = 15

    // =========================================================================
    // MARK: - Reserve Duty (FD13.3–13.5, Rev 5)
    // =========================================================================

    public static let reserveDutyMaxConsecutiveHours: Double = 12
    public static let reserveCallOutMaxCombinedHours: Double = 16
    public static let reserveNightWindowStartHHMM = 2300
    public static let reserveNightWindowEndHHMM   = 600

    // =========================================================================
    // MARK: - Consecutive Early Starts (FD14.6)
    // =========================================================================

    public static let maxConsecutiveEarlyStarts: Int = 4
    public static let earlyStartSignOnThreshold: Int = 706

    // =========================================================================
    // MARK: - Late Night Operations / Back of Clock (FD14, Rev 5)
    // =========================================================================

    public static let lnoConsecutiveTriggerCount = 2
    public static let lnoPostExcessFreeHours: Double = 24
    public static let lnoMaxPeriodsIn168h = 4
    public static let bocMaxPeriodsIn168h = 2
    public static let lnoRollingWindowHours = 168
    public static let backOfClockMinutesThreshold: Int = 120
    public static let backOfClockEarliestSignOnLocalHHMM: Int = 1000

    // =========================================================================
    // MARK: - Deadheading Following a Flight Duty (FD15)
    // =========================================================================

    public static let deadheadingAbsoluteMaxDutyHours: Double = 16

    // =========================================================================
    // MARK: - Split Duty (FD17)
    // =========================================================================

    public struct SplitDutyRules: Sendable {
        public let minRestHours: Double
        public let maxDutyIncreaseHours: Double
        public let maxTotalDutyHours: Double
        public let restDiscountFraction: Double
        public let maxRestDiscountHours: Double
        public let nightWindowStart: String
        public let nightWindowEnd: String
        public let nightRestMinUninterruptedHours: Double
        public let nightRestMaxTotalDutyHours: Double
        public let nightRestDiscountPermitted: Bool

        public init(minRestHours: Double, maxDutyIncreaseHours: Double, maxTotalDutyHours: Double,
                    restDiscountFraction: Double, maxRestDiscountHours: Double,
                    nightWindowStart: String, nightWindowEnd: String,
                    nightRestMinUninterruptedHours: Double, nightRestMaxTotalDutyHours: Double,
                    nightRestDiscountPermitted: Bool) {
            self.minRestHours = minRestHours
            self.maxDutyIncreaseHours = maxDutyIncreaseHours
            self.maxTotalDutyHours = maxTotalDutyHours
            self.restDiscountFraction = restDiscountFraction
            self.maxRestDiscountHours = maxRestDiscountHours
            self.nightWindowStart = nightWindowStart
            self.nightWindowEnd = nightWindowEnd
            self.nightRestMinUninterruptedHours = nightRestMinUninterruptedHours
            self.nightRestMaxTotalDutyHours = nightRestMaxTotalDutyHours
            self.nightRestDiscountPermitted = nightRestDiscountPermitted
        }
    }

    public static let splitDutyRules = SplitDutyRules(
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

    public struct TimeFreeWithinPatternFormula: Sendable {
        public let dutyThresholdHours: Double
        public let minFreeHours: Double
        public let baseHours: Double
        public let multiplier: Double

        public init(dutyThresholdHours: Double, minFreeHours: Double, baseHours: Double, multiplier: Double) {
            self.dutyThresholdHours = dutyThresholdHours
            self.minFreeHours = minFreeHours
            self.baseHours = baseHours
            self.multiplier = multiplier
        }
    }

    public static let timeFreeWithinPattern = TimeFreeWithinPatternFormula(
        dutyThresholdHours: 12,
        minFreeHours: 10,
        baseHours: 12,
        multiplier: 1.5
    )

    // =========================================================================
    // MARK: - Time Free from Duty — Following a Pattern (FD19)
    // =========================================================================

    public struct PatternTimeFreeRequirement: Sendable {
        public let patternDescription: String
        public let minTimeFreeHours: Double

        public init(patternDescription: String, minTimeFreeHours: Double) {
            self.patternDescription = patternDescription
            self.minTimeFreeHours = minTimeFreeHours
        }
    }

    public static let patternTimeFreeRequirements: [PatternTimeFreeRequirement] = [
        PatternTimeFreeRequirement(patternDescription: "1 or 2 day pattern", minTimeFreeHours: 12),
        PatternTimeFreeRequirement(patternDescription: "3 or 4 day pattern", minTimeFreeHours: 15),
    ]

    public struct AugmentedPatternRest: Sendable {
        public let tafbMaxHours: Double?
        public let dayReturn: Double?
        public let multiDay: Double?
        public let nextDutyDayMinHours: Double?

        public init(tafbMaxHours: Double?, dayReturn: Double?, multiDay: Double?, nextDutyDayMinHours: Double?) {
            self.tafbMaxHours = tafbMaxHours
            self.dayReturn = dayReturn
            self.multiDay = multiDay
            self.nextDutyDayMinHours = nextDutyDayMinHours
        }
    }

    public static let threePilotPatternRestPlanning: [AugmentedPatternRest] = [
        .init(tafbMaxHours: 52,  dayReturn: 14.5, multiDay: 15,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: 124, dayReturn: nil,  multiDay: 22,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: nil, dayReturn: nil,  multiDay: 32,  nextDutyDayMinHours: nil),
    ]

    // =========================================================================
    // MARK: - Time Free from Duty (FD20)
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
        DaysFreeRequirement(description: "Min free days in any 28 consecutive days",         minDaysFree: 7,  inConsecutiveDays: 28),
        DaysFreeRequirement(description: "Min free days in any 84 consecutive days",         minDaysFree: 24, inConsecutiveDays: 84),
        DaysFreeRequirement(description: "Min free days per calendar month",                  minDaysFree: 8,  inConsecutiveDays: 0),
        DaysFreeRequirement(description: "Min free days in any 3 consecutive calendar months", minDaysFree: 26, inConsecutiveDays: 0),
    ]
}
