//
//  LH_Planning_FltDuty.swift
//  Block-Time
//
//  FRMS Ruleset A380/A330/B787 — Revision 4 — 26 June 2023
//  Chapter 1A: Flight and Duty Limitations (Planning) — FD3
//
//  Source: Qantas Airways Limited Fatigue Risk Management System Ruleset A380/A330/B787
//  
//

import Foundation

// MARK: - Planning-Specific Enums

/// Local sign-on time window (applies to 2 Pilot Planning only).
enum SignOnWindow: String, Codable, CaseIterable {
    case w0500_0759 = "0500–0759"
    case w0800_1359 = "0800–1359"
    case w1400_1559 = "1400–1559"
    case w1600_0459 = "1600–0459"
}

/// Deadheading duty type (Planning).
enum DeadheadDutyType: String, Codable, CaseIterable {
    case solelyDeadhead                    = "Solely deadhead"
    case operateThenDeadheadNotHome        = "Operate then deadhead (other than to home base or posting)"
    case operateThenDeadheadToHome         = "Operate then deadhead (to home base or posting)"
}

// MARK: - Planning Data Models

/// 2 Pilot flight/duty limit row — varies by sign-on time.
struct TwoPilotPlanningLimit: Codable {
    let signOnWindow: SignOnWindow
    let dutyPeriodLimit: Double
    let flightTimeLimit: Double
    let sectorLimit: String
}

/// 3 Pilot flight/duty limit row — varies by crew rest facility.
struct ThreePilotPlanningLimit: Codable {
    let restFacility: CrewRestFacility
    let dutyPeriodLimit: Double
    let flightTimeLimit: Double
    let sectorLimit: String
}

/// 4 Pilot flight/duty limit row — varies by crew rest facility combination.
struct FourPilotPlanningLimit: Codable {
    let restFacility: CrewRestFacility
    let dutyPeriodLimit: Double
    let flightTimeLimitNote: String
    let sectorLimit: String
}

/// Deadheading duty limit row (Planning).
struct DeadheadPlanningLimit: Codable {
    let dutyType: DeadheadDutyType
    let dutyPeriodLimit: Double
    let sectorLimit: String
    let requirements: String?
}

/// A minimum rest requirement row (pre- or post-duty) for Planning.
struct PlanningRestRequirement: Codable {
    let crewComplement: CrewComplement
    let direction: RestDirection
    let dutyPeriodThreshold: String
    let minimumRestHours: Double
    let requirements: String?
}

// MARK: - LH_Planning_FltDuty

/// All Chapter 1A (FD3) Planning limits for A380/A330/B787.
enum LH_Planning_FltDuty {

    static let rulesetRevision = 4
    static let issueDate = "26 June 2023"
    static let applicableFleets = ["A380", "A330", "B787"]
    static let chapter = "1A"
    static let reference = "FD3"

    // =========================================================================
    // MARK: - 2 Pilot (Planning) — FD3.1
    // =========================================================================

    static let twoPilotLimits: [TwoPilotPlanningLimit] = [
        // 0500–0759
        TwoPilotPlanningLimit(
            signOnWindow: .w0500_0759,
            dutyPeriodLimit: 11,
            flightTimeLimit: 8,
            sectorLimit: "1 if any sector flight time > 6, otherwise 4"
        ),
        // 0800–1359 (standard)
        TwoPilotPlanningLimit(
            signOnWindow: .w0800_1359,
            dutyPeriodLimit: 11,
            flightTimeLimit: 8.5,
            sectorLimit: "1 if any sector flight time > 6, otherwise 4"
        ),
        // 0800–1359 (1 day pattern only)
        TwoPilotPlanningLimit(
            signOnWindow: .w0800_1359,
            dutyPeriodLimit: 12,
            flightTimeLimit: 9.5,
            sectorLimit: "1 DAY PATTERN ONLY, maximum 4 sectors"
        ),
        // 1400–1559
        TwoPilotPlanningLimit(
            signOnWindow: .w1400_1559,
            dutyPeriodLimit: 11,
            flightTimeLimit: 8.5,
            sectorLimit: "1 if any sector flight time > 6, otherwise 4"
        ),
        // 1600–0459
        TwoPilotPlanningLimit(
            signOnWindow: .w1600_0459,
            dutyPeriodLimit: 10,
            flightTimeLimit: 8,
            sectorLimit: "1 if any sector flight time > 6; 2 if sign-on 2100–0300 LT; 2 if any sector flight time > 2, otherwise 3"
        ),
    ]

    // MARK: 2 Pilot Rest (Planning)

    static let twoPilotPreDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .preDuty,
            dutyPeriodThreshold: "≤ 11",
            minimumRestHours: 11,
            requirements: "flight time < 8"
        ),
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .preDuty,
            dutyPeriodThreshold: "≤ 11",
            minimumRestHours: 22,
            requirements: nil
        ),
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .preDuty,
            dutyPeriodThreshold: "> 11",
            minimumRestHours: 11,
            requirements: "operate ≤ 11 duty then pax to base or posting"
        ),
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .preDuty,
            dutyPeriodThreshold: "> 11",
            minimumRestHours: 22,
            requirements: nil
        ),
    ]

    static let twoPilotPostDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .postDuty,
            dutyPeriodThreshold: "≤ 11",
            minimumRestHours: 11,
            requirements: "flight time < 8"
        ),
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .postDuty,
            dutyPeriodThreshold: "≤ 11",
            minimumRestHours: 22,
            requirements: nil
        ),
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .postDuty,
            dutyPeriodThreshold: "> 11",
            minimumRestHours: 22,
            requirements: nil
        ),
    ]

    static let twoPilotPostDutyDeadheadNote =
        "If the next duty period is solely deadheading then the minimum pre-duty deadheading limits apply."

    // =========================================================================
    // MARK: - 3 Pilot (Planning) — FD3.1
    // =========================================================================

    static let threePilotLimits: [ThreePilotPlanningLimit] = [
        ThreePilotPlanningLimit(
            restFacility: .class2,
            dutyPeriodLimit: 12,
            flightTimeLimit: 8.5,
            sectorLimit: "3 if duty period > 11, otherwise maximum 4"
        ),
        ThreePilotPlanningLimit(
            restFacility: .class1,
            dutyPeriodLimit: 14,
            flightTimeLimit: 12.5,
            sectorLimit: "3 if duty period > 11, otherwise maximum 4"
        ),
    ]

    // MARK: 3 Pilot Rest (Planning)

    static let threePilotPreDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(
            crewComplement: .threePilot, direction: .preDuty,
            dutyPeriodThreshold: "≤ 12",
            minimumRestHours: 12,
            requirements: nil
        ),
        PlanningRestRequirement(
            crewComplement: .threePilot, direction: .preDuty,
            dutyPeriodThreshold: "> 12",
            minimumRestHours: 12,
            requirements: "operate ≤ 12 duty then pax to base or posting"
        ),
        PlanningRestRequirement(
            crewComplement: .threePilot, direction: .preDuty,
            dutyPeriodThreshold: "> 12",
            minimumRestHours: 22,
            requirements: nil
        ),
    ]

    static let threePilotPostDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(
            crewComplement: .threePilot, direction: .postDuty,
            dutyPeriodThreshold: "≤ 12",
            minimumRestHours: 12,
            requirements: "flight time < 9"
        ),
        PlanningRestRequirement(
            crewComplement: .threePilot, direction: .postDuty,
            dutyPeriodThreshold: "≤ 12",
            minimumRestHours: 18,
            requirements: nil
        ),
        PlanningRestRequirement(
            crewComplement: .threePilot, direction: .postDuty,
            dutyPeriodThreshold: "> 12",
            minimumRestHours: 22,
            requirements: "acclimated crew"
        ),
        PlanningRestRequirement(
            crewComplement: .threePilot, direction: .postDuty,
            dutyPeriodThreshold: "> 12",
            minimumRestHours: 32,
            requirements: nil
        ),
    ]

    static let threePilotPostDutyDeadheadNote =
        "If the next duty period is solely deadheading then the minimum pre-duty deadheading limits apply."

    // =========================================================================
    // MARK: - 4 Pilot (Planning) — FD3.1
    // =========================================================================

    static let fourPilotFlightTimeLimitNote =
        "A pilot cannot spend more than 8 continuous hours on duty in the flight deck and no more than 14 hours total duty in the flight deck."

    static let fourPilotMixedRestNote =
        "*1: Consideration to be given to the management of mixed crew rest facilities with priority of the higher class of rest facility for the landing crew."

    static let fourPilotLimits: [FourPilotPlanningLimit] = [
        FourPilotPlanningLimit(
            restFacility: .twoClass2,
            dutyPeriodLimit: 16,
            flightTimeLimitNote: "A pilot cannot spend more than 8 continuous hours on duty in the flight deck and no more than 14 hours total duty in the flight deck.",
            sectorLimit: "≤ 2 rostered sectors if duty period was scheduled to exceed 14 hrs"
        ),
        FourPilotPlanningLimit(
            restFacility: .oneClass1OneClass2,
            dutyPeriodLimit: 17.5,
            flightTimeLimitNote: "A pilot cannot spend more than 8 continuous hours on duty in the flight deck and no more than 14 hours total duty in the flight deck.",
            sectorLimit: "≤ 2 rostered sectors if duty period was scheduled to exceed 14 hrs"
        ),
        FourPilotPlanningLimit(
            restFacility: .twoClass1,
            dutyPeriodLimit: 20,
            flightTimeLimitNote: "A pilot cannot spend more than 8 continuous hours on duty in the flight deck and no more than 14 hours total duty in the flight deck.",
            sectorLimit: "1 rostered sector if duty period was scheduled to exceed 16 hours"
        ),
    ]

    // MARK: 4 Pilot Rest (Planning)

    static let fourPilotPreDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .preDuty,
            dutyPeriodThreshold: "≤ 14",
            minimumRestHours: 12,
            requirements: nil
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .preDuty,
            dutyPeriodThreshold: "> 14 ≤ 16",
            minimumRestHours: 12,
            requirements: "operate ≤ 14 duty then pax to base or posting"
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .preDuty,
            dutyPeriodThreshold: "> 14 ≤ 16",
            minimumRestHours: 22,
            requirements: nil
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .preDuty,
            dutyPeriodThreshold: "> 16",
            minimumRestHours: 32,
            requirements: "within West Coast North America"
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .preDuty,
            dutyPeriodThreshold: "> 16",
            minimumRestHours: 48,
            requirements: nil
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .preDuty,
            dutyPeriodThreshold: "> 16",
            minimumRestHours: 22,
            requirements: "Only if prior duty was deadheading."
        ),
    ]

    static let fourPilotPostDutyRest: [PlanningRestRequirement] = [
        // ≤ 12
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .postDuty,
            dutyPeriodThreshold: "≤ 12",
            minimumRestHours: 12,
            requirements: "flight time ≤ 9.5"
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .postDuty,
            dutyPeriodThreshold: "≤ 12",
            minimumRestHours: 18,
            requirements: nil
        ),
        // > 12
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .postDuty,
            dutyPeriodThreshold: "> 12",
            minimumRestHours: 22,
            requirements: "acclimated crew OR between two 4 Pilot duties OR next duty is to home base or posting augmented crew and duty period < 5 hours"
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .postDuty,
            dutyPeriodThreshold: "> 12",
            minimumRestHours: 32,
            requirements: nil
        ),
        // > 14
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .postDuty,
            dutyPeriodThreshold: "> 14",
            minimumRestHours: 22,
            requirements: "acclimated crew OR next duty is to home base or posting augmented crew and duty period < 5 hours"
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .postDuty,
            dutyPeriodThreshold: "> 14",
            minimumRestHours: 32,
            requirements: nil
        ),
        // > 16
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .postDuty,
            dutyPeriodThreshold: "> 16",
            minimumRestHours: 22,
            requirements: "next duty is to home base or posting augmented crew and duty period < 5 hours"
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .postDuty,
            dutyPeriodThreshold: "> 16",
            minimumRestHours: 32,
            requirements: "within West Coast North America"
        ),
        PlanningRestRequirement(
            crewComplement: .fourPilot, direction: .postDuty,
            dutyPeriodThreshold: "> 16",
            minimumRestHours: 48,
            requirements: nil
        ),
    ]

    static let fourPilotPostDutyDeadheadNote =
        "If the next duty period is solely deadheading then the minimum pre-duty deadheading limits apply."

    // =========================================================================
    // MARK: - Deadheading (Planning) — FD3.1
    // =========================================================================

    static let deadheadLimits: [DeadheadPlanningLimit] = [
        DeadheadPlanningLimit(
            dutyType: .solelyDeadhead,
            dutyPeriodLimit: 26,
            sectorLimit: "2",
            requirements: nil
        ),
        DeadheadPlanningLimit(
            dutyType: .operateThenDeadheadNotHome,
            dutyPeriodLimit: 14.5,
            sectorLimit: "additional paxing sector above operate only limit",
            requirements: "PAX then operate duty OR the operate portion of 'Operate then PAX' duty — same duty period limits and flight time limits apply as operate only"
        ),
        DeadheadPlanningLimit(
            dutyType: .operateThenDeadheadToHome,
            dutyPeriodLimit: 18,
            sectorLimit: "additional paxing sector above operate only limit",
            requirements: "PAX then operate duty OR the operate portion of 'Operate then PAX' duty — same duty period limits and flight time limits apply as operate only"
        ),
    ]

    // MARK: Deadheading Rest (Planning)

    static let deadheadPreDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .preDuty,
            dutyPeriodThreshold: "≤ 12",
            minimumRestHours: 11,
            requirements: nil
        ),
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .preDuty,
            dutyPeriodThreshold: "> 12",
            minimumRestHours: 12,
            requirements: "Pax to base or posting"
        ),
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .preDuty,
            dutyPeriodThreshold: "> 12",
            minimumRestHours: 18,
            requirements: nil
        ),
    ]

    static let deadheadPreDutyRestNote =
        "Solely deadhead only. Any duty period which involves operating — the 2, 3 or 4 PILOT limits apply."

    static let deadheadPostDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .postDuty,
            dutyPeriodThreshold: "≤ 12",
            minimumRestHours: 11,
            requirements: nil
        ),
        PlanningRestRequirement(
            crewComplement: .twoPilot, direction: .postDuty,
            dutyPeriodThreshold: "> 12",
            minimumRestHours: 18,
            requirements: nil
        ),
    ]

    static let deadheadPostDutyRestNote =
        "Solely deadhead only. Any duty period which involves operating — the operate only limits apply."

    // =========================================================================
    // MARK: - Relevant Sectors — Patterns > 18 Hours (FD3.4)
    //         A380 & B787 Only
    // =========================================================================

    /// Named sectors that qualify as Relevant Sectors.
    static let relevantSectors: [String] = [
        "Any planned duty period greater than 18 hours",
        "Sydney to Dallas and vice versa",
        "Melbourne to Dallas and vice versa",
        "Perth to London and vice versa",
        "Auckland to New York and vice versa",
    ]

    /// FD3.4.1
    static let relevantSectorMinimumCrew = 4

    /// FD3.4.2
    static let relevantSectorMBTTIncrease = "MBTT in FD9 will be increased by 1 local night"

    /// FD3.4.3
    static let relevantSectorHomeTransport = "A pilot who operates a pattern that includes a planned duty greater than 18 hours will be provided with home transport."

    /// FD3.4.4 — Minimum rest prior to operating a Relevant Sector (downline disruption).
    static let relevantSectorPreDutyRestHours: Double = 22

    /// FD3.4.4(b) — Rest after operating a Relevant Sector (downline disruption).
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

    /// FD3.4.4(c) — Rest after a Relevant Sector inbound to Australia or New Zealand.
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
    // MARK: - Convenience Accessors
    // =========================================================================

    /// All planning rest requirements combined.
    static var allRestRequirements: [PlanningRestRequirement] {
        twoPilotPreDutyRest + twoPilotPostDutyRest +
        threePilotPreDutyRest + threePilotPostDutyRest +
        fourPilotPreDutyRest + fourPilotPostDutyRest +
        deadheadPreDutyRest + deadheadPostDutyRest
    }
}
