//
//  SH_Operational_FltDuty.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) - Short Haul Operational Limits
//  Source: FRMS Ruleset A320/B737, Revision 4.1, 1 October 2024
//  Chapter 1B: Operations Flight and Duty Limitations (Operational)
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
}
