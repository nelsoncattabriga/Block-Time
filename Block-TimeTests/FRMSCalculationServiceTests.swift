//
//  FRMSCalculationServiceTests.swift
//  Block-TimeTests
//
//  Tests for FRMSCalculationService covering:
//  - inferCrewComplement
//  - calculateSignOn / calculateSignOff
//  - calculateMBTT (widebody minimum base turnaround)
//  - calculateMinimumRestA320B737 (via checkCompliance rest check)
//  - checkCompliance: flight/duty limit violations
//  - Fleet limit constants (FRMSFleet computed properties)
//

import Foundation
import Testing
@testable import Block_Time

// MARK: - Test Helpers

private func makeConfig(fleet: FRMSFleet) -> FRMSConfiguration {
    FRMSConfiguration(
        fleet: fleet,
        homeBase: "YSSY",
        defaultLimitType: .operational,
        showWarningsAtPercentage: 0.9,
        signOnMinutesBeforeSTD: 60,
        signOffMinutesAfterIN: fleet == .a320B737 ? 15 : 30
    )
}

private func makeSHService() -> FRMSCalculationService {
    FRMSCalculationService(configuration: makeConfig(fleet: .a320B737))
}

private func makeLHService() -> FRMSCalculationService {
    FRMSCalculationService(configuration: makeConfig(fleet: .a380A330B787))
}

/// Build a simple FRMSDuty for use in compliance/rest tests.
private func makeDuty(
    signOnHour: Int,
    durationHours: Double,
    flightTime: Double,
    dutyType: DutyType = .operating,
    crewComplement: CrewComplement = .twoPilot,
    nightTime: Double = 0,
    referenceDate: Date = Calendar.current.startOfDay(for: Date())
) -> FRMSDuty {
    let signOn = Calendar.current.date(byAdding: .hour, value: signOnHour, to: referenceDate)!
    let signOff = Calendar.current.date(byAdding: .minute, value: Int(durationHours * 60), to: signOn)!
    return FRMSDuty(
        date: referenceDate,
        dutyType: dutyType,
        crewComplement: crewComplement,
        restFacility: .none,
        signOn: signOn,
        signOff: signOff,
        flightTime: flightTime,
        nightTime: nightTime,
        sectors: 2,
        isInternational: false,
        hasActualINTime: true,
        toAirport: "YMML"
    )
}

/// Build zeroed cumulative totals.
private func zeroCumulatives(fleet: FRMSFleet = .a320B737) -> FRMSCumulativeTotals {
    FRMSCumulativeTotals(
        flightTime7Days: 0,
        flightTime28Or30Days: 0,
        flightTime365Days: 0,
        dutyTime7Days: 0,
        dutyTime14Days: 0,
        daysOff28Days: 8,
        consecutiveDuties: 0,
        consecutiveEarlyStarts: 0,
        consecutiveLateNights: 0,
        dutyDaysIn11Days: 0,
        fleet: fleet
    )
}

// MARK: - inferCrewComplement

struct InferCrewComplementTests {

    private let service = makeSHService()

    @Test func twoNames_returnsTwoPilot() {
        let result = service.inferCrewComplement(captainName: "Smith", foName: "Jones", so1Name: nil, so2Name: nil)
        #expect(result == .twoPilot)
    }

    @Test func oneNameOnly_returnsTwoPilot() {
        let result = service.inferCrewComplement(captainName: "Smith", foName: "", so1Name: nil, so2Name: nil)
        #expect(result == .twoPilot)
    }

    @Test func threeNames_returnsThreePilot() {
        let result = service.inferCrewComplement(captainName: "Smith", foName: "Jones", so1Name: "Williams", so2Name: nil)
        #expect(result == .threePilot)
    }

    @Test func fourNames_returnsFourPilot() {
        let result = service.inferCrewComplement(captainName: "Smith", foName: "Jones", so1Name: "Williams", so2Name: "Brown")
        #expect(result == .fourPilot)
    }

    @Test func allNil_returnsTwoPilot() {
        let result = service.inferCrewComplement(captainName: nil, foName: nil, so1Name: nil, so2Name: nil)
        #expect(result == .twoPilot)
    }

    @Test func emptyStrings_returnsTwoPilot() {
        let result = service.inferCrewComplement(captainName: "", foName: "", so1Name: "", so2Name: "")
        #expect(result == .twoPilot)
    }
}

// MARK: - calculateSignOn / calculateSignOff

struct SignOnOffTests {

    private let shService = makeSHService()
    private let lhService = makeLHService()
    private let baseDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10, minute: 0))!

    @Test func signOn_usesSTD_when_available() {
        let std = baseDate  // 10:00
        let out = Calendar.current.date(byAdding: .minute, value: 15, to: baseDate)!  // 10:15
        let signOn = shService.calculateSignOn(stdTime: std, outTime: out)
        // Should be 60 min before STD = 09:00
        let expected = Calendar.current.date(byAdding: .minute, value: -60, to: std)!
        #expect(signOn == expected)
    }

    @Test func signOn_fallsBackToOUT_when_noSTD() {
        let out = baseDate  // 10:00
        let signOn = shService.calculateSignOn(stdTime: nil, outTime: out)
        // 60 min before OUT
        let expected = Calendar.current.date(byAdding: .minute, value: -60, to: out)!
        #expect(signOn == expected)
    }

    @Test func signOn_sim_is45MinBefore() {
        let out = baseDate
        let signOn = shService.calculateSignOn(stdTime: nil, outTime: out, isSim: true)
        let expected = Calendar.current.date(byAdding: .minute, value: -45, to: out)!
        #expect(signOn == expected)
    }

    @Test func signOff_SH_is15MinAfter() {
        let inTime = baseDate
        let signOff = shService.calculateSignOff(inTime: inTime)
        let expected = Calendar.current.date(byAdding: .minute, value: 15, to: inTime)!
        #expect(signOff == expected)
    }

    @Test func signOff_LH_is30MinAfter() {
        let inTime = baseDate
        let signOff = lhService.calculateSignOff(inTime: inTime)
        let expected = Calendar.current.date(byAdding: .minute, value: 30, to: inTime)!
        #expect(signOff == expected)
    }

    @Test func signOff_sim_is30MinAfter() {
        let inTime = baseDate
        let signOff = shService.calculateSignOff(inTime: inTime, isSim: true)
        let expected = Calendar.current.date(byAdding: .minute, value: 30, to: inTime)!
        #expect(signOff == expected)
    }
}

// MARK: - calculateMBTT

struct CalculateMBTTTests {

    private let lhService = makeLHService()
    private let shService = makeSHService()

    // Only applicable to widebody
    @Test func notApplicable_toShorthaul() {
        let result = shService.calculateMBTT(daysAway: 3, creditedFlightHours: 15)
        #expect(result == nil)
    }

    // Base rules by days away
    @Test func oneDayAway_returns12Hours() {
        let result = lhService.calculateMBTT(daysAway: 1, creditedFlightHours: 5)
        #expect(result?.minHours == 12.0)
        #expect(result?.localNightsRequired == 0)
    }

    @Test func twoDaysAway_returns1LocalNight() {
        let result = lhService.calculateMBTT(daysAway: 2, creditedFlightHours: 5)
        #expect(result?.localNightsRequired == 1)
        #expect(result?.minHours == nil)
    }

    @Test func fourDaysAway_returns1LocalNight() {
        let result = lhService.calculateMBTT(daysAway: 4, creditedFlightHours: 5)
        #expect(result?.localNightsRequired == 1)
    }

    @Test func fiveDaysAway_returns2LocalNights() {
        let result = lhService.calculateMBTT(daysAway: 5, creditedFlightHours: 5)
        #expect(result?.localNightsRequired == 2)
    }

    @Test func eightDaysAway_returns2LocalNights() {
        let result = lhService.calculateMBTT(daysAway: 8, creditedFlightHours: 5)
        #expect(result?.localNightsRequired == 2)
    }

    @Test func nineDaysAway_returns3LocalNights() {
        let result = lhService.calculateMBTT(daysAway: 9, creditedFlightHours: 5)
        #expect(result?.localNightsRequired == 3)
    }

    @Test func thirteenDaysAway_returns4LocalNights() {
        let result = lhService.calculateMBTT(daysAway: 13, creditedFlightHours: 5)
        #expect(result?.localNightsRequired == 4)
    }

    // Credited flight hours override
    @Test func over20FH_bumpsTo2Nights() {
        // 2 days away = normally 1 night, but >20 FH = 2 nights
        let result = lhService.calculateMBTT(daysAway: 2, creditedFlightHours: 25)
        #expect(result?.localNightsRequired == 2)
    }

    @Test func over40FH_bumpsTo3Nights() {
        let result = lhService.calculateMBTT(daysAway: 2, creditedFlightHours: 45)
        #expect(result?.localNightsRequired == 3)
    }

    @Test func over60FH_bumpsTo4Nights() {
        let result = lhService.calculateMBTT(daysAway: 2, creditedFlightHours: 65)
        #expect(result?.localNightsRequired == 4)
    }

    // FH rule takes precedence over days-away rule
    @Test func fhRule_takesMax_overDaysAwayRule() {
        // 9 days away = 3 nights, but >60 FH = 4 nights → max = 4
        let result = lhService.calculateMBTT(daysAway: 9, creditedFlightHours: 65)
        #expect(result?.localNightsRequired == 4)
    }

    // Duty over 18h adds +1 night
    @Test func dutyOver18h_addsOneNight() {
        let result = lhService.calculateMBTT(daysAway: 3, creditedFlightHours: 10, hadPlannedDutyOver18Hours: true)
        // 3 days = 1 night + 1 for duty over 18h = 2
        #expect(result?.localNightsRequired == 2)
    }

    @Test func dutyOver18h_with1DayAway_addsOneNight_andClearsMinHours() {
        // 1 day away normally gives 12h minimum with 0 nights
        // +1 for >18h duty makes it 1 night (minHours cleared)
        let result = lhService.calculateMBTT(daysAway: 1, creditedFlightHours: 5, hadPlannedDutyOver18Hours: true)
        #expect(result?.localNightsRequired == 1)
        #expect(result?.minHours == nil)
    }
}

// MARK: - Minimum Rest Formula (A320/B737) via checkCompliance

struct MinimumRestA320B737Tests {

    private let service = makeSHService()

    /// Rest required after a duty of `dutyHours` is MAX(dutyHours, 10) for duty ≤12h.
    /// Verified via checkCompliance: if actual rest < required, we get a violation.

    @Test func dutyUnder10h_requires10hRest() {
        // 8h duty → requires 10h rest
        let prevDuty = makeDuty(signOnHour: 6, durationHours: 8.0, flightTime: 7.0)
        // Give exactly 10h rest (compliant)
        let signOn = prevDuty.signOff.addingTimeInterval(10 * 3600)
        // Manually build proposed with correct signOn
        let proposedDuty = FRMSDuty(
            date: signOn,
            dutyType: .operating,
            crewComplement: .twoPilot,
            restFacility: .none,
            signOn: signOn,
            signOff: signOn.addingTimeInterval(8 * 3600),
            flightTime: 7.0,
            nightTime: 0,
            sectors: 2,
            isInternational: false,
            hasActualINTime: true,
            toAirport: "YMML"
        )
        let result = service.checkCompliance(proposedDuty: proposedDuty, previousDuty: prevDuty, cumulativeTotals: zeroCumulatives())
        #expect({ if case .compliant = result { return true }; return false }())
    }

    @Test func dutyUnder10h_insufficientRest_isViolation() {
        // 8h duty → requires 10h rest. Give only 9h → violation.
        let prevDuty = makeDuty(signOnHour: 6, durationHours: 8.0, flightTime: 7.0)
        let signOn = prevDuty.signOff.addingTimeInterval(9 * 3600)
        let proposedDuty = FRMSDuty(
            date: signOn,
            dutyType: .operating,
            crewComplement: .twoPilot,
            restFacility: .none,
            signOn: signOn,
            signOff: signOn.addingTimeInterval(8 * 3600),
            flightTime: 7.0,
            nightTime: 0,
            sectors: 2,
            isInternational: false,
            hasActualINTime: true,
            toAirport: "YMML"
        )
        let result = service.checkCompliance(proposedDuty: proposedDuty, previousDuty: prevDuty, cumulativeTotals: zeroCumulatives())
        if case .violation = result { } else {
            Issue.record("Expected violation but got \(result)")
        }
    }

    @Test func dutyOver12h_usesExtendedFormula() {
        // 14h duty → rest = 12 + (1.5 × (14-12)) = 12 + 3 = 15h
        let prevDuty = makeDuty(signOnHour: 6, durationHours: 14.0, flightTime: 10.0)
        // Give exactly 15h rest (compliant)
        let signOn = prevDuty.signOff.addingTimeInterval(15 * 3600)
        let proposedDuty = FRMSDuty(
            date: signOn,
            dutyType: .operating,
            crewComplement: .twoPilot,
            restFacility: .none,
            signOn: signOn,
            signOff: signOn.addingTimeInterval(8 * 3600),
            flightTime: 7.0,
            nightTime: 0,
            sectors: 2,
            isInternational: false,
            hasActualINTime: true,
            toAirport: "YMML"
        )
        let result = service.checkCompliance(proposedDuty: proposedDuty, previousDuty: prevDuty, cumulativeTotals: zeroCumulatives())
        #expect({ if case .compliant = result { return true }; return false }())
    }

    @Test func dutyOver12h_insufficientRest_isViolation() {
        // 14h duty → needs 15h rest. Give 14h → violation.
        let prevDuty = makeDuty(signOnHour: 6, durationHours: 14.0, flightTime: 10.0)
        let signOn = prevDuty.signOff.addingTimeInterval(14 * 3600)
        let proposedDuty = FRMSDuty(
            date: signOn,
            dutyType: .operating,
            crewComplement: .twoPilot,
            restFacility: .none,
            signOn: signOn,
            signOff: signOn.addingTimeInterval(8 * 3600),
            flightTime: 7.0,
            nightTime: 0,
            sectors: 2,
            isInternational: false,
            hasActualINTime: true,
            toAirport: "YMML"
        )
        let result = service.checkCompliance(proposedDuty: proposedDuty, previousDuty: prevDuty, cumulativeTotals: zeroCumulatives())
        if case .violation = result { } else {
            Issue.record("Expected violation but got \(result)")
        }
    }
}

// MARK: - checkCompliance: Cumulative Limits

struct CheckComplianceCumulativeLimitsTests {

    // MARK: A320/B737

    @Test func SH_7dayDutyLimit_violation() {
        let service = makeSHService()
        // 60h is the limit; already at 58h → adding 3h = 61h → violation
        var totals = zeroCumulatives(fleet: .a320B737)
        totals = FRMSCumulativeTotals(
            flightTime7Days: 0, flightTime28Or30Days: 0, flightTime365Days: 0,
            dutyTime7Days: 58, dutyTime14Days: 58,
            daysOff28Days: 8, consecutiveDuties: 0, consecutiveEarlyStarts: 0,
            consecutiveLateNights: 0, dutyDaysIn11Days: 0, fleet: .a320B737
        )
        let proposed = makeDuty(signOnHour: 8, durationHours: 3.0, flightTime: 2.5)
        let result = service.checkCompliance(proposedDuty: proposed, previousDuty: nil, cumulativeTotals: totals)
        if case .violation = result { } else {
            Issue.record("Expected violation for 7-day duty limit")
        }
    }

    @Test func SH_7dayDutyLimit_compliant() {
        let service = makeSHService()
        let totals = FRMSCumulativeTotals(
            flightTime7Days: 0, flightTime28Or30Days: 0, flightTime365Days: 0,
            dutyTime7Days: 55, dutyTime14Days: 55,
            daysOff28Days: 8, consecutiveDuties: 0, consecutiveEarlyStarts: 0,
            consecutiveLateNights: 0, dutyDaysIn11Days: 0, fleet: .a320B737
        )
        let proposed = makeDuty(signOnHour: 8, durationHours: 4.0, flightTime: 3.5)
        let result = service.checkCompliance(proposedDuty: proposed, previousDuty: nil, cumulativeTotals: totals)
        #expect({ if case .compliant = result { return true }; return false }())
    }

    @Test func SH_28dayFlightLimit_violation() {
        let service = makeSHService()
        let totals = FRMSCumulativeTotals(
            flightTime7Days: 0, flightTime28Or30Days: 98, flightTime365Days: 0,
            dutyTime7Days: 0, dutyTime14Days: 0,
            daysOff28Days: 8, consecutiveDuties: 0, consecutiveEarlyStarts: 0,
            consecutiveLateNights: 0, dutyDaysIn11Days: 0, fleet: .a320B737
        )
        // 3h flight + 98h existing = 101h > 100h limit
        let proposed = makeDuty(signOnHour: 8, durationHours: 4.0, flightTime: 3.0)
        let result = service.checkCompliance(proposedDuty: proposed, previousDuty: nil, cumulativeTotals: totals)
        if case .violation = result { } else {
            Issue.record("Expected violation for 28-day flight time limit")
        }
    }

    // MARK: A380/A330/B787

    @Test func LH_7dayFlightLimit_violation() {
        let service = makeLHService()
        // 30h limit; already at 28h → adding 3h = 31h → violation
        let totals = FRMSCumulativeTotals(
            flightTime7Days: 28, flightTime28Or30Days: 0, flightTime365Days: 0,
            dutyTime7Days: 0, dutyTime14Days: 0,
            daysOff28Days: 8, consecutiveDuties: 0, consecutiveEarlyStarts: 0,
            consecutiveLateNights: 0, dutyDaysIn11Days: 0, fleet: .a380A330B787
        )
        let proposed = makeDuty(signOnHour: 8, durationHours: 16.0, flightTime: 3.0)
        let result = service.checkCompliance(proposedDuty: proposed, previousDuty: nil, cumulativeTotals: totals)
        if case .violation = result { } else {
            Issue.record("Expected violation for LH 7-day flight time limit")
        }
    }

    @Test func LH_7dayFlightLimit_compliant() {
        let service = makeLHService()
        let totals = FRMSCumulativeTotals(
            flightTime7Days: 20, flightTime28Or30Days: 0, flightTime365Days: 0,
            dutyTime7Days: 0, dutyTime14Days: 0,
            daysOff28Days: 8, consecutiveDuties: 0, consecutiveEarlyStarts: 0,
            consecutiveLateNights: 0, dutyDaysIn11Days: 0, fleet: .a380A330B787
        )
        let proposed = makeDuty(signOnHour: 8, durationHours: 16.0, flightTime: 9.0)
        let result = service.checkCompliance(proposedDuty: proposed, previousDuty: nil, cumulativeTotals: totals)
        #expect({ if case .compliant = result { return true }; return false }())
    }
}

// MARK: - Fleet Limit Constants

struct FleetLimitConstantsTests {

    @Test func SH_noSevenDayFlightLimit() {
        #expect(FRMSFleet.a320B737.maxFlightTime7Days == nil)
    }

    @Test func LH_sevenDayFlightLimit_is30() {
        #expect(FRMSFleet.a380A330B787.maxFlightTime7Days == 30.0)
    }

    @Test func SH_28dayFlightLimit_is100() {
        #expect(FRMSFleet.a320B737.maxFlightTime28Days == 100.0)
        #expect(FRMSFleet.a320B737.flightTimePeriodDays == 28)
    }

    @Test func LH_30dayFlightLimit_is100() {
        #expect(FRMSFleet.a380A330B787.maxFlightTime28Days == 100.0)
        #expect(FRMSFleet.a380A330B787.flightTimePeriodDays == 30)
    }

    @Test func both_7dayDutyLimit_is60() {
        #expect(FRMSFleet.a320B737.maxDutyTime7Days == 60.0)
        #expect(FRMSFleet.a380A330B787.maxDutyTime7Days == 60.0)
    }

    @Test func both_14dayDutyLimit_is100() {
        #expect(FRMSFleet.a320B737.maxDutyTime14Days == 100.0)
        #expect(FRMSFleet.a380A330B787.maxDutyTime14Days == 100.0)
    }

    @Test func SH_14dayInitialLimit_is90() {
        #expect(FRMSFleet.a320B737.maxDutyTime14DaysInitial == 90.0)
    }

    @Test func LH_noInitial14dayLimit() {
        #expect(FRMSFleet.a380A330B787.maxDutyTime14DaysInitial == nil)
    }

    @Test func SH_365dayFlightLimit_is1000() {
        #expect(FRMSFleet.a320B737.maxFlightTime365Days == 1000.0)
    }

    @Test func LH_365dayFlightLimit_is900() {
        #expect(FRMSFleet.a380A330B787.maxFlightTime365Days == 900.0)
    }
}
