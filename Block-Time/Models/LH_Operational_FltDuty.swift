//
//  LH_Operational_FltDuty.swift
//  Block-Time
//
//  FRMS Ruleset A380/A330/B787 — Revision 4 — 26 June 2023
//  Chapter 1B: Flight and Duty Limitations (Operational) — FD10
//
//  Source: Qantas Airways Limited Fatigue Risk Management System Ruleset A380/A330/B787

import Foundation

// MARK: - Enums

/// Crew complement for the duty period.
enum LH_CrewComplement: String, Codable, CaseIterable {
    case twoPilot   = "2 Pilot"
    case threePilot = "3 Pilot"
    case fourPilot  = "4 Pilot"
}

/// Class of onboard crew rest facility.
enum CrewRestFacility: String, Codable, CaseIterable {
    case seatInPassengerCompartment = "Seat in Passenger Compartment"
    case class2                    = "Class 2 Rest"
    case class1                    = "Class 1 Rest"
    case twoClass2                 = "2 × Class 2 Rest"
    case oneClass1OneClass2        = "1 × Class 1 & 1 × Class 2 Rest"
    case twoClass1                 = "2 × Class 1 Rest"
    case twoClass1FD34             = "2 × Class 1 Rest (>18 hrs per FD3.4)"
}

/// Role context for Relevant Sector disruption rest.
enum RelevantSectorRole: String, Codable {
    case captainOrFO              = "Captain OR First Officer"
    case captainOrFO_DPOver20     = "Captain OR First Officer (DP > 20 hrs)"
    case captainAndFO             = "Captain AND First Officer"
    case dpUnder18                = "Duty Period < 18 hrs"
    case dpOver18NextSectorUnder4 = "Duty Period > 18 hrs, next sector FT < 4 hrs"
}

/// Context for post–Relevant Sector rest inbound to AU/NZ.
enum InboundAUNZContext: String, Codable {
    case sameTimeZoneDestination = "Returning to same time zone destination"
    case domesticOrTransTasman   = "Domestic or trans-Tasman sector"
}

// MARK: - Data Models

/// A single flight time / duty period limit row.
struct DutyLimit: Codable {
    let crewComplement: LH_CrewComplement
    let restFacility: CrewRestFacility?
    let dutyPeriodLimitPlanned: Double?
    let dutyPeriodLimitDiscretion: Double?
    let flightTimeLimit: Double?
    let flightTimeLimitNote: String?
    let requirements: String?
}

/// A minimum rest requirement row (pre- or post-duty).
struct RestRequirement: Codable {
    let crewComplement: LH_CrewComplement
    let direction: RestDirection
    let dutyPeriodThreshold: String
    let minimumRestHours: Double?
    let minimumRestFormula: String?
    let requirements: String?
}

enum RestDirection: String, Codable {
    case preDuty  = "Pre-Duty"
    case postDuty = "Post-Duty"
}

/// Disruption rest for Relevant Sectors (FD3.4 / FD10.1).
struct RelevantSectorDisruptionRest: Codable {
    let condition: String
    let minimumRestHours: Double?
    let note: String?
}

/// Post–Relevant Sector rest inbound to AU/NZ.
struct InboundAUNZRest: Codable {
    let context: InboundAUNZContext
    let minimumRestHours: Double
}

/// The 2-pilot consecutive duty footnote (*1).
struct TwoPilotConsecutiveDutyNote: Codable {
    let text: String
}

/// An aircraft type with its crew rest classification and optional configuration note (FD10.2.2).
struct CrewRestAircraftDefinition {
    let aircraft: String
    let configuration: String?
}

// MARK: - LH_Operational_FltDuty

/// All Chapter 1B (FD10) Operational limits for A380/A330/B787.
enum LH_Operational_FltDuty {

    static let rulesetRevision = 4
    static let issueDate = "26 June 2023"
    static let applicableFleets = ["A380", "A330", "B787"]
    static let chapter = "1B"
    static let reference = "FD10"

    // =========================================================================
    // MARK: - Flight & Duty Time Limits (FD10.1)
    // =========================================================================

    /// 2 Pilot (Operational) — FD10.1
    static let twoPilotLimits: [DutyLimit] = [
        DutyLimit(
            crewComplement: .twoPilot,
            restFacility: nil,
            dutyPeriodLimitPlanned: 11,
            dutyPeriodLimitDiscretion: 12,
            flightTimeLimit: 9.5,
            flightTimeLimitNote: nil,
            requirements: "If more than 7 hours of flight time conducted in darkness"
        ),
        DutyLimit(
            crewComplement: .twoPilot,
            restFacility: nil,
            dutyPeriodLimitPlanned: 11,
            dutyPeriodLimitDiscretion: 12,
            flightTimeLimit: 10,
            flightTimeLimitNote: nil,
            requirements: "If greater than 1 sector is rostered"
        ),
        DutyLimit(
            crewComplement: .twoPilot,
            restFacility: nil,
            dutyPeriodLimitPlanned: 11,
            dutyPeriodLimitDiscretion: 12,
            flightTimeLimit: 10.5,
            flightTimeLimitNote: nil,
            requirements: nil
        ),
    ]

    /// 3 Pilot (Operational) — FD10.1
    static let threePilotLimits: [DutyLimit] = [
        DutyLimit(
            crewComplement: .threePilot,
            restFacility: .seatInPassengerCompartment,
            dutyPeriodLimitPlanned: 14,
            dutyPeriodLimitDiscretion: nil,
            flightTimeLimit: nil,
            flightTimeLimitNote: "8 consecutive hrs of active duty",
            requirements: nil
        ),
        DutyLimit(
            crewComplement: .threePilot,
            restFacility: .class2,
            dutyPeriodLimitPlanned: 16,
            dutyPeriodLimitDiscretion: nil,
            flightTimeLimit: nil,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            requirements: "≤ 2 sectors if duty period was scheduled to exceed 14"
        ),
        DutyLimit(
            crewComplement: .threePilot,
            restFacility: .class1,
            dutyPeriodLimitPlanned: 18,
            dutyPeriodLimitDiscretion: nil,
            flightTimeLimit: nil,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            requirements: "≤ 2 sectors if duty period was scheduled to exceed 14"
        ),
    ]

    /// 4 Pilot (Operational) — FD10.1
    static let fourPilotLimits: [DutyLimit] = [
        DutyLimit(
            crewComplement: .fourPilot,
            restFacility: .seatInPassengerCompartment,
            dutyPeriodLimitPlanned: 14,
            dutyPeriodLimitDiscretion: nil,
            flightTimeLimit: nil,
            flightTimeLimitNote: "8 consecutive hrs of active duty",
            requirements: nil
        ),
        DutyLimit(
            crewComplement: .fourPilot,
            restFacility: .twoClass2,
            dutyPeriodLimitPlanned: 16,
            dutyPeriodLimitDiscretion: nil,
            flightTimeLimit: nil,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            requirements: "≤ 2 sectors if duty period was scheduled to exceed 14 hours"
        ),
        DutyLimit(
            crewComplement: .fourPilot,
            restFacility: .oneClass1OneClass2,
            dutyPeriodLimitPlanned: 20,
            dutyPeriodLimitDiscretion: nil,
            flightTimeLimit: nil,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            requirements: "≤ 2 sectors if duty period was scheduled to exceed 14 hours"
        ),
        DutyLimit(
            crewComplement: .fourPilot,
            restFacility: .twoClass1,
            dutyPeriodLimitPlanned: 20,
            dutyPeriodLimitDiscretion: nil,
            flightTimeLimit: nil,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            requirements: "≤ 2 sectors if duty period was scheduled to exceed 14 hours"
        ),
        DutyLimit(
            crewComplement: .fourPilot,
            restFacility: .twoClass1FD34,
            dutyPeriodLimitPlanned: 21,
            dutyPeriodLimitDiscretion: nil,
            flightTimeLimit: nil,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            requirements: "A380 & B787 only. >18 hours as per FD3.4"
        ),
    ]

    /// All duty limits combined.
    static var allDutyLimits: [DutyLimit] {
        twoPilotLimits + threePilotLimits + fourPilotLimits
    }

    // =========================================================================
    // MARK: - Rest Requirements (FD10.1)
    // =========================================================================

    // MARK: 2 Pilot Rest

    static let twoPilotPreDutyRest: [RestRequirement] = [
        RestRequirement(
            crewComplement: .twoPilot,
            direction: .preDuty,
            dutyPeriodThreshold: "≤ 11",
            minimumRestHours: 10,
            minimumRestFormula: nil,
            requirements: nil
        ),
        RestRequirement(
            crewComplement: .twoPilot,
            direction: .preDuty,
            dutyPeriodThreshold: "> 11",
            minimumRestHours: 12,
            minimumRestFormula: nil,
            requirements: nil
        ),
        RestRequirement(
            crewComplement: .twoPilot,
            direction: .preDuty,
            dutyPeriodThreshold: "Within a 7 day period",
            minimumRestHours: nil,
            minimumRestFormula: nil,
            requirements: "1 continuous period embracing 2200 and 0600 on 2 consecutive nights"
        ),
    ]

    static let twoPilotPostDutyRest: [RestRequirement] = [
        RestRequirement(
            crewComplement: .twoPilot,
            direction: .postDuty,
            dutyPeriodThreshold: "≤ 11",
            minimumRestHours: 10,
            minimumRestFormula: nil,
            requirements: nil
        ),
        RestRequirement(
            crewComplement: .twoPilot,
            direction: .postDuty,
            dutyPeriodThreshold: "DP > 11 or FT > 8 (extension beyond planned)",
            minimumRestHours: nil,
            minimumRestFormula: "10 + 1 additional hour for each 15 minutes or part thereof when TOD exceeded 11 hours",
            requirements: "If next duty period includes operating sectors. However, if next duty is solely deadheading, only 12 hours rest is required."
        ),
        RestRequirement(
            crewComplement: .twoPilot,
            direction: .postDuty,
            dutyPeriodThreshold: "DP > 12 or FT > 9 (extension beyond planned)",
            minimumRestHours: 24,
            minimumRestFormula: nil,
            requirements: nil
        ),
    ]

    /// 2 Pilot consecutive duty footnote (*1) from FD10.1.
    static let twoPilotConsecutiveDutyNote = TwoPilotConsecutiveDutyNote(
        text: """
        If a pilot has completed 2 consecutive duty periods, the aggregate of which exceeds \
        8 hours flight time or 11 hours duty period, and the intervening rest period is less than: \
        a) 12 consecutive hours embracing the hours between 2200 and 0600 local time; or \
        b) 24 consecutive hours, if not embracing the hours between 2200 and 0600 local time; \
        The pilot shall have a rest period on the ground of at least 12 consecutive hours embracing \
        the hours between 2200 and 0600 local time or 24 consecutive hours, prior to commencing \
        a further duty period. The 12 consecutive hours embracing the hours between 2200 and 0600 \
        local time may commence from 2300 provided the succeeding duty period does not exceed \
        6 hours and the pilot was scheduled to be free of duty no later than 2200 local time and \
        the aircraft was delayed beyond that time.
        """
    )

    // MARK: 3 Pilot Rest

    static let threePilotPreDutyRest: [RestRequirement] = [
        RestRequirement(
            crewComplement: .threePilot,
            direction: .preDuty,
            dutyPeriodThreshold: "—",
            minimumRestHours: 10,
            minimumRestFormula: nil,
            requirements: "If 12 hours rest was rostered between 2 consecutive duties and the first duty does not exceed 11 hours and the total of both duties do not exceed 24 hours"
        ),
        RestRequirement(
            crewComplement: .threePilot,
            direction: .preDuty,
            dutyPeriodThreshold: "—",
            minimumRestHours: 12,
            minimumRestFormula: nil,
            requirements: nil
        ),
    ]

    static let threePilotPostDutyRest: [RestRequirement] = [
        RestRequirement(
            crewComplement: .threePilot,
            direction: .postDuty,
            dutyPeriodThreshold: "≤ 16",
            minimumRestHours: 12,
            minimumRestFormula: nil,
            requirements: nil
        ),
        RestRequirement(
            crewComplement: .threePilot,
            direction: .postDuty,
            dutyPeriodThreshold: "> 16",
            minimumRestHours: 24,
            minimumRestFormula: nil,
            requirements: nil
        ),
    ]

    // MARK: 4 Pilot Rest

    static let fourPilotPreDutyRest: [RestRequirement] = [
        RestRequirement(
            crewComplement: .fourPilot,
            direction: .preDuty,
            dutyPeriodThreshold: "—",
            minimumRestHours: 10,
            minimumRestFormula: nil,
            requirements: "If 12 hours rest was rostered between 2 consecutive duties and the first duty does not exceed 11 hours and the total of both duties do not exceed 24 hours"
        ),
        RestRequirement(
            crewComplement: .fourPilot,
            direction: .preDuty,
            dutyPeriodThreshold: "—",
            minimumRestHours: 12,
            minimumRestFormula: nil,
            requirements: nil
        ),
        RestRequirement(
            crewComplement: .fourPilot,
            direction: .preDuty,
            dutyPeriodThreshold: "> 18 Hours as per FD3.4",
            minimumRestHours: nil,
            minimumRestFormula: nil,
            requirements: "Refer to Relevant Sector disruption limits"
        ),
    ]

    static let fourPilotPostDutyRest: [RestRequirement] = [
        RestRequirement(
            crewComplement: .fourPilot,
            direction: .postDuty,
            dutyPeriodThreshold: "≤ 16",
            minimumRestHours: 12,
            minimumRestFormula: nil,
            requirements: nil
        ),
        RestRequirement(
            crewComplement: .fourPilot,
            direction: .postDuty,
            dutyPeriodThreshold: "> 16",
            minimumRestHours: 24,
            minimumRestFormula: nil,
            requirements: nil
        ),
        RestRequirement(
            crewComplement: .fourPilot,
            direction: .postDuty,
            dutyPeriodThreshold: "> 18 Hours as per FD3.4",
            minimumRestHours: nil,
            minimumRestFormula: nil,
            requirements: "Refer to Relevant Sector disruption limits"
        ),
    ]

    /// Note applying to 3 and 4 pilot post-duty rest.
    static let augmentedPostDutyDeadheadNote =
        "If the next duty period is solely deadheading then the minimum pre-duty deadheading limits apply."

    /// All rest requirements combined.
    static var allRestRequirements: [RestRequirement] {
        twoPilotPreDutyRest + twoPilotPostDutyRest +
        threePilotPreDutyRest + threePilotPostDutyRest +
        fourPilotPreDutyRest + fourPilotPostDutyRest
    }

    // =========================================================================
    // MARK: - Relevant Sectors — Patterns > 18 Hours (FD3.4 / FD10.1)
    //         A380 & B787 Only
    // =========================================================================

    /// Named sectors that qualify as Relevant Sectors.
    static let relevantSectors: [String] = [
        "Any planned duty period > 18 hours",
        "Sydney to Dallas and vice versa",
        "Melbourne to Dallas and vice versa",
        "Perth to London and vice versa",
        "Auckland to New York and vice versa",
    ]

    /// Minimum rest prior to operating a Relevant Sector (disruption).
    static let relevantSectorPreDutyRestHours: Double = 22

    /// Rest after operating a Relevant Sector (disruption).
    static let relevantSectorPostDutyRest: [RelevantSectorDisruptionRest] = [
        RelevantSectorDisruptionRest(
            condition: "Captain OR First Officer",
            minimumRestHours: 27,
            note: nil
        ),
        RelevantSectorDisruptionRest(
            condition: "Captain OR First Officer and a duty period > 20 hours",
            minimumRestHours: 36,
            note: nil
        ),
        RelevantSectorDisruptionRest(
            condition: "Captain AND First Officer",
            minimumRestHours: 36,
            note: nil
        ),
        RelevantSectorDisruptionRest(
            condition: "Duty Period < 18 hours",
            minimumRestHours: nil,
            note: "Chapter 1B Flight and Duty Limitations apply as per FD10.1"
        ),
        RelevantSectorDisruptionRest(
            condition: "Duty Period > 18 hours, at crew discretion, where next operating sector has a flight time < 4 hours",
            minimumRestHours: 24,
            note: "The minimum rest period before operating any Relevant Sector is to then be 36 hours."
        ),
    ]

    /// Rest after a Relevant Sector inbound to Australia or New Zealand.
    static let relevantSectorInboundAUNZRest: [InboundAUNZRest] = [
        InboundAUNZRest(
            context: .sameTimeZoneDestination,
            minimumRestHours: 36
        ),
        InboundAUNZRest(
            context: .domesticOrTransTasman,
            minimumRestHours: 22
        ),
    ]

    // =========================================================================
    // MARK: - Crew Rest Facility Definitions (FD10.2.2)
    // =========================================================================

    /// Aircraft types deemed to meet Class 1 crew rest requirements.
    static let class1Aircraft: [CrewRestAircraftDefinition] = [
        CrewRestAircraftDefinition(aircraft: "A380-800",  configuration: nil),
        CrewRestAircraftDefinition(aircraft: "B787-9",    configuration: nil),
        CrewRestAircraftDefinition(aircraft: "A330-300",  configuration: "International configuration, dedicated crew rest facility"),
        CrewRestAircraftDefinition(aircraft: "A330-200L", configuration: "International configuration, dedicated crew rest facility mid cabin"),
    ]

    /// Aircraft types deemed to meet Class 2 crew rest requirements.
    static let class2Aircraft: [CrewRestAircraftDefinition] = [
        CrewRestAircraftDefinition(aircraft: "A330-200L", configuration: "International configuration, dedicated crew rest area at seat 5A"),
    ]

    /// Statutory note from FD10.2.2.
    static let crewRestFacilityStatutoryNote =
        "Aviation Regulatory Authority requirements with respect to adequate rest facilities on board will apply in all relevant situations."
}
