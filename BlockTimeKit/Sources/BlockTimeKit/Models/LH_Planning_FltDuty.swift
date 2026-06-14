//
//  LH_Planning_FltDuty.swift
//
//  FRMS Ruleset A380/A330/B787 — Revision 5 — 15 June 2026
//  Chapter 1A: Flight and Duty Limitations (Planning) — FD3
//
//  Source: Qantas Airways Limited Fatigue Risk Management System Ruleset A380/A330/B787

import Foundation

// MARK: - Planning-Specific Enums

public enum SignOnWindow: String, Codable, CaseIterable, Sendable {
    case w0500_0759 = "0500–0759"
    case w0800_1359 = "0800–1359"
    case w1400_1559 = "1400–1559"
    case w1600_0459 = "1600–0459"
}

public enum DeadheadDutyType: String, Codable, CaseIterable, Sendable {
    case solelyDeadhead                    = "Solely deadhead"
    case operateThenDeadheadNotHome        = "Operate then deadhead (other than to home base or posting)"
    case operateThenDeadheadToHome         = "Operate then deadhead (to home base or posting)"
}

// MARK: - Planning Data Models

public struct TwoPilotPlanningLimit: Codable, Sendable {
    public let signOnWindow: SignOnWindow
    public let dutyPeriodLimit: Double
    public let flightTimeLimit: Double?
    public let sectorLimit: String

    public init(signOnWindow: SignOnWindow, dutyPeriodLimit: Double, flightTimeLimit: Double?, sectorLimit: String) {
        self.signOnWindow = signOnWindow
        self.dutyPeriodLimit = dutyPeriodLimit
        self.flightTimeLimit = flightTimeLimit
        self.sectorLimit = sectorLimit
    }
}

public struct ThreePilotPlanningLimit: Codable, Sendable {
    public let restFacility: CrewRestFacility
    public let dutyPeriodLimit: Double
    public let flightTimeLimit: Double?
    public let sectorLimit: String

    public init(restFacility: CrewRestFacility, dutyPeriodLimit: Double, flightTimeLimit: Double?, sectorLimit: String) {
        self.restFacility = restFacility
        self.dutyPeriodLimit = dutyPeriodLimit
        self.flightTimeLimit = flightTimeLimit
        self.sectorLimit = sectorLimit
    }
}

public struct FourPilotPlanningLimit: Codable, Sendable {
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

public struct DeadheadPlanningLimit: Codable, Sendable {
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

public struct PlanningRestRequirement: Codable, Sendable {
    public let crewComplement: CrewComplement
    public let direction: RestDirection
    public let dutyPeriodThreshold: String
    public let minimumRestHours: Double
    public let requirements: String?

    public init(crewComplement: CrewComplement, direction: RestDirection,
                dutyPeriodThreshold: String, minimumRestHours: Double, requirements: String?) {
        self.crewComplement = crewComplement
        self.direction = direction
        self.dutyPeriodThreshold = dutyPeriodThreshold
        self.minimumRestHours = minimumRestHours
        self.requirements = requirements
    }
}

// MARK: - LH_Planning_FltDuty

public enum LH_Planning_FltDuty {

    public static let rulesetRevision = 5
    public static let issueDate = "15 June 2026"
    public static let applicableFleets = ["A380", "A330", "B787"]
    public static let chapter = "1A"
    public static let reference = "FD3"

    // =========================================================================
    // MARK: - 2 Pilot (Planning) — FD3.1
    // =========================================================================

    public static let twoPilotLimits: [TwoPilotPlanningLimit] = [
        TwoPilotPlanningLimit(signOnWindow: .w0500_0759, dutyPeriodLimit: 11, flightTimeLimit: nil,
            sectorLimit: "1 Sector if Flight Time > 6 hrs, otherwise 4 Sectors."),
        TwoPilotPlanningLimit(signOnWindow: .w0800_1359, dutyPeriodLimit: 11, flightTimeLimit: nil,
            sectorLimit: "1 Sector if Flight Time > 6 hrs, otherwise 4 Sectors."),
        TwoPilotPlanningLimit(signOnWindow: .w0800_1359, dutyPeriodLimit: 12, flightTimeLimit: nil,
            sectorLimit: "Day Pattern ONLY, maximum 4 sectors"),
        TwoPilotPlanningLimit(signOnWindow: .w1400_1559, dutyPeriodLimit: 11, flightTimeLimit: nil,
            sectorLimit: "1 Sector if Flight Time > 6 hrs, otherwise 4 Sectors."),
        TwoPilotPlanningLimit(signOnWindow: .w1600_0459, dutyPeriodLimit: 10, flightTimeLimit: nil,
            sectorLimit: "1 Sector if Flight Time > 6 hrs; 2 Sectors if sign-on 2100–0300 LT; 2 Sectors if Flight Time > 2 hrs, otherwise 3 Sectors"),
    ]

    public static let twoPilotPreDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .preDuty, dutyPeriodThreshold: "≤ 11", minimumRestHours: 11, requirements: "flight time < 8"),
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .preDuty, dutyPeriodThreshold: "≤ 11", minimumRestHours: 22, requirements: nil),
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .preDuty, dutyPeriodThreshold: "> 11", minimumRestHours: 11, requirements: "operate ≤ 11 duty then pax to base or posting"),
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .preDuty, dutyPeriodThreshold: "> 11", minimumRestHours: 22, requirements: nil),
    ]

    public static let twoPilotPostDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .postDuty, dutyPeriodThreshold: "≤ 11", minimumRestHours: 11, requirements: "flight time < 8"),
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .postDuty, dutyPeriodThreshold: "≤ 11", minimumRestHours: 22, requirements: nil),
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .postDuty, dutyPeriodThreshold: "> 11", minimumRestHours: 22, requirements: nil),
    ]

    public static let twoPilotPostDutyDeadheadNote =
        "If the next duty period is solely deadheading then the minimum pre-duty deadheading limits apply."

    // =========================================================================
    // MARK: - 3 Pilot (Planning) — FD3.1
    // =========================================================================

    public static let threePilotLimits: [ThreePilotPlanningLimit] = [
        ThreePilotPlanningLimit(restFacility: .class2, dutyPeriodLimit: 12, flightTimeLimit: nil,
            sectorLimit: "3 if duty period > 11, otherwise maximum 4"),
        ThreePilotPlanningLimit(restFacility: .class1, dutyPeriodLimit: 14, flightTimeLimit: nil,
            sectorLimit: "3 if duty period > 11, otherwise maximum 4"),
    ]

    public static let threePilotPreDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(crewComplement: .threePilot, direction: .preDuty, dutyPeriodThreshold: "≤ 12", minimumRestHours: 12, requirements: nil),
        PlanningRestRequirement(crewComplement: .threePilot, direction: .preDuty, dutyPeriodThreshold: "> 12", minimumRestHours: 12, requirements: "operate ≤ 12 duty then pax to base or posting"),
        PlanningRestRequirement(crewComplement: .threePilot, direction: .preDuty, dutyPeriodThreshold: "> 12", minimumRestHours: 22, requirements: nil),
    ]

    public static let threePilotPostDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(crewComplement: .threePilot, direction: .postDuty, dutyPeriodThreshold: "≤ 12", minimumRestHours: 12, requirements: "flight time < 9"),
        PlanningRestRequirement(crewComplement: .threePilot, direction: .postDuty, dutyPeriodThreshold: "≤ 12", minimumRestHours: 18, requirements: nil),
        PlanningRestRequirement(crewComplement: .threePilot, direction: .postDuty, dutyPeriodThreshold: "> 12", minimumRestHours: 22, requirements: "acclimated crew"),
        PlanningRestRequirement(crewComplement: .threePilot, direction: .postDuty, dutyPeriodThreshold: "> 12", minimumRestHours: 32, requirements: nil),
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
        FourPilotPlanningLimit(restFacility: .twoClass2, dutyPeriodLimit: 16,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            sectorLimit: "≤ 2 rostered sectors if duty period was scheduled to exceed 14 hrs"),
        FourPilotPlanningLimit(restFacility: .oneClass1OneClass2, dutyPeriodLimit: 17.5,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            sectorLimit: "≤ 2 rostered sectors if duty period was scheduled to exceed 14 hrs"),
        FourPilotPlanningLimit(restFacility: .twoClass1, dutyPeriodLimit: 20,
            flightTimeLimitNote: "Max 8 hrs continuous & 14 hrs total on flight deck.",
            sectorLimit: "1 rostered sector if duty period was scheduled to exceed 16 hours"),
    ]

    public static let fourPilotPreDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .preDuty, dutyPeriodThreshold: "≤ 14", minimumRestHours: 12, requirements: nil),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .preDuty, dutyPeriodThreshold: "> 14 ≤ 16", minimumRestHours: 12, requirements: "operate ≤ 14 duty then pax to base or posting"),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .preDuty, dutyPeriodThreshold: "> 14 ≤ 16", minimumRestHours: 22, requirements: nil),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .preDuty, dutyPeriodThreshold: "> 16", minimumRestHours: 32, requirements: "within West Coast North America"),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .preDuty, dutyPeriodThreshold: "> 16", minimumRestHours: 48, requirements: nil),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .preDuty, dutyPeriodThreshold: "> 16", minimumRestHours: 22, requirements: "Only if prior duty was deadheading."),
    ]

    public static let fourPilotPostDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .postDuty, dutyPeriodThreshold: "≤ 12", minimumRestHours: 12, requirements: "flight time ≤ 9.5"),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .postDuty, dutyPeriodThreshold: "≤ 12", minimumRestHours: 18, requirements: nil),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .postDuty, dutyPeriodThreshold: "> 12", minimumRestHours: 22, requirements: "acclimated crew OR between two 4 Pilot duties OR next duty is to home base or posting augmented crew and duty period < 5 hours"),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .postDuty, dutyPeriodThreshold: "> 12", minimumRestHours: 32, requirements: nil),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .postDuty, dutyPeriodThreshold: "> 14", minimumRestHours: 22, requirements: "acclimated crew OR next duty is to home base or posting augmented crew and duty period < 5 hours"),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .postDuty, dutyPeriodThreshold: "> 14", minimumRestHours: 32, requirements: nil),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .postDuty, dutyPeriodThreshold: "> 16", minimumRestHours: 22, requirements: "next duty is to home base or posting augmented crew and duty period < 5 hours"),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .postDuty, dutyPeriodThreshold: "> 16", minimumRestHours: 32, requirements: "within West Coast North America"),
        PlanningRestRequirement(crewComplement: .fourPilot, direction: .postDuty, dutyPeriodThreshold: "> 16", minimumRestHours: 48, requirements: nil),
    ]

    public static let fourPilotPostDutyDeadheadNote =
        "If the next duty period is solely deadheading then the minimum pre-duty deadheading limits apply."

    // =========================================================================
    // MARK: - Deadheading (Planning) — FD3.1
    // =========================================================================

    public static let deadheadLimits: [DeadheadPlanningLimit] = [
        DeadheadPlanningLimit(dutyType: .solelyDeadhead, dutyPeriodLimit: 26, sectorLimit: "2", requirements: nil),
        DeadheadPlanningLimit(dutyType: .operateThenDeadheadNotHome, dutyPeriodLimit: 14.5,
            sectorLimit: "additional paxing sector above operate only limit",
            requirements: "PAX then operate duty OR the operate portion of 'Operate then PAX' duty — same duty period limits and flight time limits apply as operate only"),
        DeadheadPlanningLimit(dutyType: .operateThenDeadheadToHome, dutyPeriodLimit: 18,
            sectorLimit: "additional paxing sector above operate only limit",
            requirements: "PAX then operate duty OR the operate portion of 'Operate then PAX' duty — same duty period limits and flight time limits apply as operate only"),
    ]

    public static let deadheadPreDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .preDuty, dutyPeriodThreshold: "≤ 12", minimumRestHours: 11, requirements: nil),
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .preDuty, dutyPeriodThreshold: "> 12", minimumRestHours: 12, requirements: "Pax to base or posting"),
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .preDuty, dutyPeriodThreshold: "> 12", minimumRestHours: 18, requirements: nil),
    ]

    public static let deadheadPreDutyRestNote =
        "Solely deadhead only. Any duty period which involves operating — the 2, 3 or 4 PILOT limits apply."

    public static let deadheadPostDutyRest: [PlanningRestRequirement] = [
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .postDuty, dutyPeriodThreshold: "≤ 12", minimumRestHours: 11, requirements: nil),
        PlanningRestRequirement(crewComplement: .twoPilot, direction: .postDuty, dutyPeriodThreshold: "> 12", minimumRestHours: 18, requirements: nil),
    ]

    public static let deadheadPostDutyRestNote =
        "Solely deadhead only. Any duty period which involves operating — the operate only limits apply."

    // =========================================================================
    // MARK: - Relevant Sectors — Patterns > 18 Hours (FD3.4)
    // =========================================================================

    public static let relevantSectors: [String] = [
        "Any planned duty period greater than 18 hours",
        "Sydney to Dallas and vice versa",
        "Melbourne to Dallas and vice versa",
        "Perth to London and vice versa",
        "Auckland to New York and vice versa",
        "Perth to Paris and vice versa",
    ]

    public static let relevantSectorMinimumCrew = 4
    public static let relevantSectorMBTTIncrease = "MBTT in FD9 will be increased by 1 local night"
    public static let relevantSectorHomeTransport = "A pilot who operates a pattern that includes a planned duty greater than 18 hours will be provided with home transport."

    // =========================================================================
    // MARK: - Convenience Accessors
    // =========================================================================

    public static var allRestRequirements: [PlanningRestRequirement] {
        twoPilotPreDutyRest + twoPilotPostDutyRest +
        threePilotPreDutyRest + threePilotPostDutyRest +
        fourPilotPreDutyRest + fourPilotPostDutyRest +
        deadheadPreDutyRest + deadheadPostDutyRest
    }
}
