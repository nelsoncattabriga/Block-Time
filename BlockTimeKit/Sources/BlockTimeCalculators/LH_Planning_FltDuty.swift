//
//  LH_Planning_FltDuty.swift
//  BlockTimeCalculators
//
//  FRMS Ruleset A380/A330/B787 — Revision 4 — 26 June 2023
//  Chapter 1A: Flight and Duty Limitations (Planning) — FD3
//
//  Source: Qantas Airways Limited Fatigue Risk Management System Ruleset A380/A330/B787
//  Moved from Block-Time/Models/ to BlockTimeKit (D-04, Plan 03-04).
//

import Foundation
import BlockTimeDomain

// MARK: - Planning-Specific Enums

/// Local sign-on time window (applies to 2 Pilot Planning only).
public enum SignOnWindow: String, Codable, CaseIterable {
    case w0500_0759 = "0500–0759"
    case w0800_1359 = "0800–1359"
    case w1400_1559 = "1400–1559"
    case w1600_0459 = "1600–0459"
}

/// Deadheading duty type (Planning).
public enum DeadheadDutyType: String, Codable, CaseIterable {
    case solelyDeadhead                    = "Solely deadhead"
    case operateThenDeadheadNotHome        = "Operate then deadhead (other than to home base or posting)"
    case operateThenDeadheadToHome         = "Operate then deadhead (to home base or posting)"
}

// MARK: - Planning Data Models

/// 2 Pilot flight/duty limit row — varies by sign-on time.
public struct TwoPilotPlanningLimit: Codable {
    public let signOnWindow: SignOnWindow
    public let dutyPeriodLimit: Double
    public let flightTimeLimit: Double
    public let sectorLimit: String

    public init(signOnWindow: SignOnWindow, dutyPeriodLimit: Double, flightTimeLimit: Double, sectorLimit: String) {
        self.signOnWindow = signOnWindow
        self.dutyPeriodLimit = dutyPeriodLimit
        self.flightTimeLimit = flightTimeLimit
        self.sectorLimit = sectorLimit
    }
}

/// 3 Pilot flight/duty limit row — varies by crew rest facility.
public struct ThreePilotPlanningLimit: Codable {
    public let restFacility: CrewRestFacility
    public let dutyPeriodLimit: Double
    public let flightTimeLimit: Double
    public let sectorLimit: String

    public init(restFacility: CrewRestFacility, dutyPeriodLimit: Double, flightTimeLimit: Double, sectorLimit: String) {
        self.restFacility = restFacility
        self.dutyPeriodLimit = dutyPeriodLimit
        self.flightTimeLimit = flightTimeLimit
        self.sectorLimit = sectorLimit
    }
}

/// 4 Pilot flight/duty limit row — varies by crew rest facility combination.
public struct FourPilotPlanningLimit: Codable {
    public let restFacility: CrewRestFacility
    public let dutyPeriodLimit: Double
    public let flightTimeLimitNote: String
    public let sectorLimit: String

    public init(restFacility: CrewRestFacility, dutyPeriodLimit: Double, flightTimeLimitNote: String, sectorLimit: String) {
        self.restFacility = restFacility
        self.dutyPeriodLimit = dutyPeriodLimit
        self.flightTimeLimitNote = flightTimeLimitNote
        self.sectorLimit = sectorLimit
    }
}

/// Deadheading duty limit row (Planning).
public struct DeadheadPlanningLimit: Codable {
    public let dutyType: DeadheadDutyType
    public let dutyPeriodLimit: Double
    public let sectorLimit: String
    public let requirements: String?

    public init(dutyType: DeadheadDutyType, dutyPeriodLimit: Double, sectorLimit: String, requirements: String?) {
        self.dutyType = dutyType
        self.dutyPeriodLimit = dutyPeriodLimit
        self.sectorLimit = sectorLimit
        self.requirements = requirements
    }
}

/// A minimum rest requirement row (pre- or post-duty) for Planning.
public struct PlanningRestRequirement: Codable {
    public let crewComplement: CrewComplement
    public let direction: RestDirection
    public let dutyPeriodThreshold: String
    public let minimumRestHours: Double
    public let requirements: String?

    public init(crewComplement: CrewComplement, direction: RestDirection, dutyPeriodThreshold: String, minimumRestHours: Double, requirements: String?) {
        self.crewComplement = crewComplement
        self.direction = direction
        self.dutyPeriodThreshold = dutyPeriodThreshold
        self.minimumRestHours = minimumRestHours
        self.requirements = requirements
    }
}

// MARK: - LH_Planning_FltDuty

/// All Chapter 1A (FD3) Planning limits for A380/A330/B787.
public enum LH_Planning_FltDuty {

    public static let rulesetRevision = 4
    public static let issueDate = "26 June 2023"
    public static let applicableFleets = ["A380", "A330", "B787"]
    public static let chapter = "1A"
    public static let reference = "FD3"

    // =========================================================================
    // MARK: - 2 Pilot (Planning) — FD3.1
    // =========================================================================

    public static let twoPilotLimits: [TwoPilotPlanningLimit] = [
        // 0500–0759
        TwoPilotPlanningLimit(
            signOnWindow: .w0500_0759,
            dutyPeriodLimit: 11,
            flightTimeLimit: 8,
            sectorLimit: "1 Sector if Flight Time > 6 hrs, otherwise 4 Sectors."
        ),
        // 0800–1359 (standard)
        TwoPilotPlanningLimit(
            signOnWindow: .w0800_1359,
            dutyPeriodLimit: 11,
            flightTimeLimit: 8.5,
            sectorLimit: "1 Sector if Flight Time > 6 hrs, otherwise 4 Sectors."
        ),
        // 0800–1359 (1 day pattern only)
        TwoPilotPlanningLimit(
            signOnWindow: .w0800_1359,
            dutyPeriodLimit: 12,
            flightTimeLimit: 9.5,
            sectorLimit: "Day Pattern ONLY, maximum 4 sectors"
        ),
        // 1400–1559
        TwoPilotPlanningLimit(
            signOnWindow: .w1400_1559,
            dutyPeriodLimit: 11,
            flightTimeLimit: 8.5,
            sectorLimit: "1 Sector if Flight Time > 6 hrs, otherwise 4 Sectors."
        ),
        // 1600–0459
        TwoPilotPlanningLimit(
            signOnWindow: .w1600_0459,
            dutyPeriodLimit: 10,
            flightTimeLimit: 8,
            sectorLimit: "1 Sector if Flight Time > 6 hrs; 2 Sectors if sign-on 2100–0300 LT; 2 Sectors if Flight Time > 2 hrs, otherwise 3 Sectors"
        ),
    ]

    // MARK: 2 Pilot Rest (Planning)

    public static let twoPilotPreDutyRest: [PlanningRestRequirement] = [
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

    public static let twoPilotPostDutyRest: [PlanningRestRequirement] = [
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

    public static let twoPilotPostDutyDeadheadNote =
        "If the next duty period is solely deadheading then the minimum pre-duty deadheading limits apply."

    // =========================================================================
    // MARK: - 3 Pilot (Planning) — FD3.1
    // =========================================================================

    public static let threePilotLimits: [ThreePilotPlanningLimit] = [
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

    public static let threePilotPreDutyRest: [PlanningRestRequirement] = [
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

    public static let threePilotPostDutyRest: [PlanningRestRequirement] = [
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

    public static let threePilotPostDutyDeadheadNote =
        "If the next duty period is solely deadheading then the minimum pre-duty deadheading limits apply."

    // =========================================================================
    // MARK: - 4 Pilot (Planning) — FD3.1
    // =========================================================================

    public static let fourPilotFlightTimeLimitNote =
        "Max 8 hrs continuous & 14 hrs total on flight deck."

    public static let fourPilotMixedRestNote =
        "*1: Consideration to be given to the management of mixed crew rest facilities with priority of the higher class of rest facility for the landing crew."

    public static let fourPilotLimits: [FourPilotPlanningLimit] = [
        FourPilotPlanningLimit(
            restFacility: .twoClass2,
            dutyPeriodLimit: 16,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            sectorLimit: "≤ 2 rostered sectors if duty period was scheduled to exceed 14 hrs"
        ),
        FourPilotPlanningLimit(
            restFacility: .oneClass1OneClass2,
            dutyPeriodLimit: 17.5,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            sectorLimit: "≤ 2 rostered sectors if duty period was scheduled to exceed 14 hrs"
        ),
        FourPilotPlanningLimit(
            restFacility: .twoClass1,
            dutyPeriodLimit: 20,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            sectorLimit: "1 rostered sector if duty period was scheduled to exceed 16 hours"
        ),
    ]

    // MARK: 4 Pilot Rest (Planning)

    public static let fourPilotPreDutyRest: [PlanningRestRequirement] = [
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

    public static let fourPilotPostDutyRest: [PlanningRestRequirement] = [
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

    public static let fourPilotPostDutyDeadheadNote =
        "If the next duty period is solely deadheading then the minimum pre-duty deadheading limits apply."

    // =========================================================================
    // MARK: - Deadheading (Planning) — FD3.1
    // =========================================================================

    public static let deadheadLimits: [DeadheadPlanningLimit] = [
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

    public static let deadheadPreDutyRest: [PlanningRestRequirement] = [
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

    public static let deadheadPreDutyRestNote =
        "Solely deadhead only. Any duty period which involves operating — the 2, 3 or 4 PILOT limits apply."

    public static let deadheadPostDutyRest: [PlanningRestRequirement] = [
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

    public static let deadheadPostDutyRestNote =
        "Solely deadhead only. Any duty period which involves operating — the operate only limits apply."

    // =========================================================================
    // MARK: - Relevant Sectors — Patterns > 18 Hours (FD3.4)
    //         A380 & B787 Only
    // =========================================================================

    /// Named sectors that qualify as Relevant Sectors.
    public static let relevantSectors: [String] = [
        "Any planned duty period greater than 18 hours",
        "Sydney to Dallas and vice versa",
        "Melbourne to Dallas and vice versa",
        "Perth to London and vice versa",
        "Auckland to New York and vice versa",
    ]

    /// FD3.4.1
    public static let relevantSectorMinimumCrew = 4

    /// FD3.4.2
    public static let relevantSectorMBTTIncrease = "MBTT in FD9 will be increased by 1 local night"

    /// FD3.4.3
    public static let relevantSectorHomeTransport = "A pilot who operates a pattern that includes a planned duty greater than 18 hours will be provided with home transport."

    /// FD3.4.4 — Minimum rest prior to operating a Relevant Sector (downline disruption).
    public static let relevantSectorPreDutyRestHours: Double = 22

    /// FD3.4.4(b) — Rest after operating a Relevant Sector (downline disruption).
    public static let relevantSectorPostDutyRest: [RelevantSectorDisruptionRest] = [
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
            note: "Chapter 1B Flight & Duty Lims Apply (FD10.1)"
        ),
        RelevantSectorDisruptionRest(
            condition: "Duty Period > 18 hours, at crew discretion, where next operating sector has a flight time < 4 hours",
            minimumRestHours: 24,
            note: "Min Rest 36 hrs"
        ),
    ]

    /// FD3.4.4(c) — Rest after a Relevant Sector inbound to Australia or New Zealand.
    public static let relevantSectorInboundAUNZRest: [InboundAUNZRest] = [
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
    public static var allRestRequirements: [PlanningRestRequirement] {
        twoPilotPreDutyRest + twoPilotPostDutyRest +
        threePilotPreDutyRest + threePilotPostDutyRest +
        fourPilotPreDutyRest + fourPilotPostDutyRest +
        deadheadPreDutyRest + deadheadPostDutyRest
    }
}
