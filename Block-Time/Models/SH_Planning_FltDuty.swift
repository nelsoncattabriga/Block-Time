import Foundation

// MARK: - SH Planning Flight & Duty Limits (FD13)
// Source: FRMS Ruleset A320/B737, Revision 4.1, 1 October 2024
// Chapter 1A: Planning Flight and Duty Limitations

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
}
