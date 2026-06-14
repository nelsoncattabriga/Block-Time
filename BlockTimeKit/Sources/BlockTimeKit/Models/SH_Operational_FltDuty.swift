import Foundation

// MARK: - SH Operational Flight & Duty Limits (FD23)
// Source: FRMS Ruleset A320/B737, Revision 5, 15 June 2026
// Chapter 1B: Operations Flight and Duty Limitations (FD21–FD28)
// Applies to Australia-based crew. NZ-based crew use SH_NZ_* (Chapter 4A/4B).

public struct SH_Operational_FltDuty {

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

        public var displayName: String {
            switch self {
            case .early:     return "Early Morning"
            case .afternoon: return "Afternoon"
            case .night:     return "Night"
            }
        }

        public static func classify(signOn: Date, homeBaseTimeZone: TimeZone) -> LocalStartTime {
            var calendar = Calendar.current
            calendar.timeZone = homeBaseTimeZone
            let hour = calendar.component(.hour, from: signOn)
            let minute = calendar.component(.minute, from: signOn)
            let timeAsInt = hour * 100 + minute
            if timeAsInt >= 500 && timeAsInt <= 1259 {
                return .early
            } else if timeAsInt >= 1300 && timeAsInt <= 1759 {
                return .afternoon
            } else {
                return .night
            }
        }
    }

    // MARK: - Maximum Duty Periods – 2 Pilot Operations (FD23.1)

    public struct DutyPeriodLimit: Sendable {
        public let localStartTime: LocalStartTime
        public let maxDutySectors1to4: Double
        public let maxDutySectors5: Double
        public let maxDutySectors6: Double

        public init(localStartTime: LocalStartTime, maxDutySectors1to4: Double, maxDutySectors5: Double, maxDutySectors6: Double) {
            self.localStartTime = localStartTime
            self.maxDutySectors1to4 = maxDutySectors1to4
            self.maxDutySectors5 = maxDutySectors5
            self.maxDutySectors6 = maxDutySectors6
        }
    }

    public static let twoPilotDutyLimits: [DutyPeriodLimit] = [
        DutyPeriodLimit(localStartTime: .early,      maxDutySectors1to4: 14, maxDutySectors5: 13, maxDutySectors6: 12),
        DutyPeriodLimit(localStartTime: .afternoon,  maxDutySectors1to4: 13, maxDutySectors5: 12, maxDutySectors6: 11),
        DutyPeriodLimit(localStartTime: .night,      maxDutySectors1to4: 12, maxDutySectors5: 12, maxDutySectors6: 11),
    ]

    // MARK: - Maximum Duty Periods – 3 Pilot Operations (FD23.1, Rev 5)

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
        .init(band: .early,     class2: 16, businessSeat: 14.5),
        .init(band: .afternoon, class2: 16, businessSeat: 13.5),
        .init(band: .night,     class2: 16, businessSeat: 12.5),
    ]

    public static let threePilotMaxSectors = 3
    public static let threePilotMinTotalRestHours = 2.0

    // MARK: - Lookup Helpers

    public static func maxDutyHours(localStartTime: LocalStartTime, sectors: Int) -> Double? {
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

    public static func maxDutyHoursThreePilot(band: LocalStartTime, rest: SH_Planning_FltDuty.ThreePilotRest) -> Double? {
        guard let limit = threePilotDutyLimits.first(where: { $0.band == band }) else { return nil }
        return rest == .class2 ? limit.class2 : limit.businessSeat
    }

    // =========================================================================
    // MARK: - Cumulative Flight Time Limits (FD21.1)
    // =========================================================================

    public static let cumulativeFlightTime28DaysHours: Double = 100
    public static let cumulativeFlightTime365DaysHours: Double = 1_000

    // =========================================================================
    // MARK: - Cumulative Duty Time Limits (FD22)
    // =========================================================================

    public static let cumulativeDutyTime7DaysHours: Double = 60
    public static let cumulativeDutyTime14DaysInitialHours: Double = 90
    public static let cumulativeDutyTime14DaysExtendedHours: Double = 100
    public static let simulatorTrainingDutyFactor: Double = 1.5
    public static let maxDutyDaysIn11Days: Int = 9
    public static let maxConsecutiveDutyDays: Int = 6
    public static let minHoursFreeIn7ConsecutiveDays: Double = 36
    public static let minConsecutiveLocalNightsIn8Nights: Int = 2

    // =========================================================================
    // MARK: - Emergency Procedures Training Extension (FD23.2)
    // =========================================================================

    public static let emergencyProceduresTrainingMaxDutyHours: Double = 15

    // =========================================================================
    // MARK: - Reserve Duty (FD23.3–23.5, Rev 5)
    // =========================================================================

    public static let reserveDutyMaxConsecutiveHours: Double = 12
    public static let reserveCallOutMaxCombinedHours: Double = 16
    public static let reserveCallOutMaxCombinedHoursOpNecessity: Double = 18
    public static let reserveNightWindowStartHHMM = 2300
    public static let reserveNightWindowEndHHMM   = 600

    // =========================================================================
    // MARK: - Late Night Operations / Back of Clock (FD24, Rev 5)
    // =========================================================================

    public static let lnoConsecutiveTriggerCount = 2
    public static let lnoPostExcessFreeHours: Double = 24
    public static let lnoMaxPeriodsIn168h = 4
    public static let bocMaxPeriodsIn168h = 2
    public static let lnoRollingWindowHours = 168

    // =========================================================================
    // MARK: - Deadheading Following a Flight Duty (FD25)
    // =========================================================================

    public static let deadheadingAbsoluteMaxDutyHours: Double = 16

    // =========================================================================
    // MARK: - Split Duty (FD27)
    // =========================================================================

    public enum SplitDutyAccommodation: Sendable {
        case sleeping
        case resting
    }

    public struct SplitDutyRules: Sendable {
        public let accommodation: SplitDutyAccommodation
        public let minRestHours: Double
        public let maxDutyIncreaseHours: Double
        public let maxTotalDutyHours: Double?
        public let restDiscountFraction: Double?
        public let maxRestDiscountHours: Double?
        public let nightWindowStart: String
        public let nightWindowEnd: String
        public let nightRestMinUninterruptedHours: Double
        public let nightRestMaxTotalDutyHours: Double
        public let nightRestDiscountPermitted: Bool

        public init(accommodation: SplitDutyAccommodation, minRestHours: Double, maxDutyIncreaseHours: Double,
                    maxTotalDutyHours: Double?, restDiscountFraction: Double?, maxRestDiscountHours: Double?,
                    nightWindowStart: String, nightWindowEnd: String, nightRestMinUninterruptedHours: Double,
                    nightRestMaxTotalDutyHours: Double, nightRestDiscountPermitted: Bool) {
            self.accommodation = accommodation
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

    public static let splitDutyRulesBySleeping = SplitDutyRules(
        accommodation: .sleeping, minRestHours: 6, maxDutyIncreaseHours: 4,
        maxTotalDutyHours: 16, restDiscountFraction: 0.5, maxRestDiscountHours: 4,
        nightWindowStart: "2300", nightWindowEnd: "0530",
        nightRestMinUninterruptedHours: 7, nightRestMaxTotalDutyHours: 16, nightRestDiscountPermitted: false
    )

    public static let splitDutyRulesByResting = SplitDutyRules(
        accommodation: .resting, minRestHours: 6, maxDutyIncreaseHours: 2,
        maxTotalDutyHours: nil, restDiscountFraction: nil, maxRestDiscountHours: nil,
        nightWindowStart: "2300", nightWindowEnd: "0530",
        nightRestMinUninterruptedHours: 7, nightRestMaxTotalDutyHours: 16, nightRestDiscountPermitted: false
    )

    // =========================================================================
    // MARK: - Time Free from Duty (FD28)
    // =========================================================================

    public struct TimeFreeWithinPatternFormula: Sendable {
        public let dutyThresholdHours: Double
        public let minFreeHours: Double
        public let baseHours: Double
        public let multiplier: Double
        public let reducedRestMinHours: Double
        public let reducedRestMaxDutyHours: Double
        public let reducedRestWindowStart: String
        public let reducedRestWindowEnd: String
        public let standbyNoCalloutMinRestHours: Double

        public init(dutyThresholdHours: Double, minFreeHours: Double, baseHours: Double, multiplier: Double,
                    reducedRestMinHours: Double, reducedRestMaxDutyHours: Double,
                    reducedRestWindowStart: String, reducedRestWindowEnd: String,
                    standbyNoCalloutMinRestHours: Double) {
            self.dutyThresholdHours = dutyThresholdHours
            self.minFreeHours = minFreeHours
            self.baseHours = baseHours
            self.multiplier = multiplier
            self.reducedRestMinHours = reducedRestMinHours
            self.reducedRestMaxDutyHours = reducedRestMaxDutyHours
            self.reducedRestWindowStart = reducedRestWindowStart
            self.reducedRestWindowEnd = reducedRestWindowEnd
            self.standbyNoCalloutMinRestHours = standbyNoCalloutMinRestHours
        }
    }

    public static let timeFreeFromDuty = TimeFreeWithinPatternFormula(
        dutyThresholdHours: 12, minFreeHours: 10, baseHours: 12, multiplier: 1.5,
        reducedRestMinHours: 9, reducedRestMaxDutyHours: 10,
        reducedRestWindowStart: "2200", reducedRestWindowEnd: "0600",
        standbyNoCalloutMinRestHours: 10
    )

    public static let minHoursFreeIn7Days: Double = 36
    public static let minConsecutiveLocalNightsIn8NightsFree: Int = 2

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
        DaysFreeRequirement(description: "Min free days in any 28 consecutive days",          minDaysFree: 7,  inConsecutiveDays: 28),
        DaysFreeRequirement(description: "Min free days in any 84 consecutive days",          minDaysFree: 24, inConsecutiveDays: 84),
        DaysFreeRequirement(description: "Min free days per calendar month",                   minDaysFree: 8,  inConsecutiveDays: 0),
        DaysFreeRequirement(description: "Min free days in any 3 consecutive calendar months", minDaysFree: 26, inConsecutiveDays: 0),
    ]

    // MARK: - 3-Pilot Post-Pattern Rest (FD28, Rev 5)

    public struct ThreePilotPatternRest: Sendable {
        public let tafbMaxHours: Double?
        public let dayReturn: Double?
        public let multiDay: Double?
        public let formulaIfOver12: Bool
        public let nextDutyDayMinHours: Double?

        public init(tafbMaxHours: Double?, dayReturn: Double?, multiDay: Double?, formulaIfOver12: Bool, nextDutyDayMinHours: Double?) {
            self.tafbMaxHours = tafbMaxHours
            self.dayReturn = dayReturn
            self.multiDay = multiDay
            self.formulaIfOver12 = formulaIfOver12
            self.nextDutyDayMinHours = nextDutyDayMinHours
        }
    }

    public static let threePilotPatternRestOperational: [ThreePilotPatternRest] = [
        .init(tafbMaxHours: 52,  dayReturn: 12.0, multiDay: 12.0, formulaIfOver12: true,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: 124, dayReturn: nil,  multiDay: nil,  formulaIfOver12: true,  nextDutyDayMinHours: 9.59),
        .init(tafbMaxHours: nil, dayReturn: nil,  multiDay: 22.0, formulaIfOver12: false, nextDutyDayMinHours: 9.59),
    ]
}
