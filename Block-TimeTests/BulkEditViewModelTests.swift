//
//  BulkEditViewModelTests.swift
//  Block-TimeTests
//
//  Tests for BulkEditViewModel.applyChanges(to:) — the core bulk-edit logic.
//  Covers prefix operations, sim↔block time swaps, time credit redistribution,
//  approach type mapping, and field state semantics.
//

import Testing
@testable import Block_Time

struct BulkEditViewModelTests {

    // MARK: - Helpers

    private func makeFlight(
        flightNumber: String = "QF001",
        aircraftReg: String = "VH-OQA",
        aircraftType: String = "B789",
        blockTime: String = "8.5",
        simTime: String = "0.0",
        p1Time: String = "8.5",
        p1usTime: String = "0.0",
        p2Time: String = "0.0",
        captainName: String = "Smith",
        foName: String = "Jones",
        isILS: Bool = false,
        isRNP: Bool = false,
        isAIII: Bool = false,
        isGLS: Bool = false,
        isNPA: Bool = false
    ) -> FlightSector {
        FlightSector(
            date: "01/01/2026",
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: "YSSY",
            toAirport: "YMML",
            captainName: captainName,
            foName: foName,
            blockTime: blockTime,
            nightTime: "0.0",
            p1Time: p1Time,
            p1usTime: p1usTime,
            p2Time: p2Time,
            instrumentTime: "0.0",
            simTime: simTime,
            isPilotFlying: true,
            isAIII: isAIII,
            isRNP: isRNP,
            isILS: isILS,
            isGLS: isGLS,
            isNPA: isNPA
        )
    }

    private func viewModel(flights: [FlightSector]) -> BulkEditViewModel {
        BulkEditViewModel(selectedFlights: flights)
    }

    // MARK: - Field State: notEdited fields are not applied

    @Test func notEditedFields_areNotApplied() {
        let flight = makeFlight(aircraftType: "B789")
        let vm = viewModel(flights: [flight])
        // aircraftType starts as .value("B789") from analyzeFields — don't change it
        // leave vm.aircraftType as analysed; only mutate something else
        vm.captainName = .value("NewCaptain")

        let result = vm.applyChanges(to: [flight])
        // aircraftType should be unchanged
        #expect(result[flight.id]?.aircraftType == "B789")
        #expect(result[flight.id]?.captainName == "NewCaptain")
    }

    // MARK: - Prefix: Add

    @Test func prefixAdd_addsPrefix() {
        let flight = makeFlight(flightNumber: "001")
        let vm = viewModel(flights: [flight])
        vm.prefixOperation = .value(.add)
        vm.prefixValue = .value("QF")

        let result = vm.applyChanges(to: [flight])
        #expect(result[flight.id]?.flightNumber == "QF001")
    }

    @Test func prefixAdd_doesNotDuplicate_ifAlreadyPresent() {
        let flight = makeFlight(flightNumber: "QF001")
        let vm = viewModel(flights: [flight])
        vm.prefixOperation = .value(.add)
        vm.prefixValue = .value("QF")

        let result = vm.applyChanges(to: [flight])
        #expect(result[flight.id]?.flightNumber == "QF001")
    }

    @Test func prefixAdd_isCaseInsensitive() {
        let flight = makeFlight(flightNumber: "qf001")
        let vm = viewModel(flights: [flight])
        vm.prefixOperation = .value(.add)
        vm.prefixValue = .value("QF")

        let result = vm.applyChanges(to: [flight])
        // Already starts with "qf" (case-insensitive match) — should not duplicate
        #expect(result[flight.id]?.flightNumber == "qf001")
    }

    // MARK: - Prefix: Remove

    @Test func prefixRemove_removesPrefix() {
        let flight = makeFlight(flightNumber: "QF001")
        let vm = viewModel(flights: [flight])
        vm.prefixOperation = .value(.remove)
        vm.prefixValue = .value("QF")

        let result = vm.applyChanges(to: [flight])
        #expect(result[flight.id]?.flightNumber == "001")
    }

    @Test func prefixRemove_noOp_ifPrefixAbsent() {
        let flight = makeFlight(flightNumber: "EK001")
        let vm = viewModel(flights: [flight])
        vm.prefixOperation = .value(.remove)
        vm.prefixValue = .value("QF")

        let result = vm.applyChanges(to: [flight])
        #expect(result[flight.id]?.flightNumber == "EK001")
    }

    // MARK: - Rego Prefix: Add / Remove

    @Test func regoPrefixAdd_addsPrefix() {
        let flight = makeFlight(aircraftReg: "OQA")
        let vm = viewModel(flights: [flight])
        vm.regoPrefixOperation = .value(.add)
        vm.regoPrefixValue = .value("VH-")

        let result = vm.applyChanges(to: [flight])
        #expect(result[flight.id]?.aircraftReg == "VH-OQA")
    }

    @Test func regoPrefixRemove_removesPrefix() {
        let flight = makeFlight(aircraftReg: "VH-OQA")
        let vm = viewModel(flights: [flight])
        vm.regoPrefixOperation = .value(.remove)
        vm.regoPrefixValue = .value("VH-")

        let result = vm.applyChanges(to: [flight])
        #expect(result[flight.id]?.aircraftReg == "OQA")
    }

    // MARK: - Simulator conversion: block → sim

    @Test func isSimulator_true_movesBlockTimeToSimTime() {
        let flight = makeFlight(blockTime: "4.0", simTime: "0.0")
        let vm = viewModel(flights: [flight])
        vm.isSimulator = .value(true)
        // Prevent analyzeFields-derived individual time fields from overwriting the sim swap
        vm.blockTime = .notEdited
        vm.simTime = .notEdited

        let result = vm.applyChanges(to: [flight])
        let updated = result[flight.id]!
        #expect(updated.simTimeValue == 4.0)
        #expect(updated.blockTimeValue == 0.0)
    }

    @Test func isSimulator_false_movesSimTimeToBlockTime() {
        let flight = makeFlight(blockTime: "0.0", simTime: "3.5")
        let vm = viewModel(flights: [flight])
        vm.isSimulator = .value(false)
        vm.blockTime = .notEdited
        vm.simTime = .notEdited

        let result = vm.applyChanges(to: [flight])
        let updated = result[flight.id]!
        #expect(updated.blockTimeValue == 3.5)
        #expect(updated.simTimeValue == 0.0)
    }

    // MARK: - Time credit redistribution

    @Test func timeCreditChange_toP2_setsP2ToBlockTime_clearsOthers() {
        let flight = makeFlight(blockTime: "8.5", p1Time: "8.5", p1usTime: "0.0", p2Time: "0.0")
        let vm = viewModel(flights: [flight])
        vm.selectedTimeCredit = .value(.p2)
        // Prevent individual time fields from overwriting the credit redistribution
        vm.p1Time = .notEdited
        vm.p1usTime = .notEdited
        vm.p2Time = .notEdited

        let result = vm.applyChanges(to: [flight])
        let updated = result[flight.id]!
        #expect(updated.p2TimeValue == 8.5)
        #expect(updated.p1TimeValue == 0.0)
        #expect(updated.p1usTimeValue == 0.0)
    }

    @Test func timeCreditChange_toP1US_setsP1USToBlockTime_clearsOthers() {
        let flight = makeFlight(blockTime: "6.0", p1Time: "6.0", p1usTime: "0.0", p2Time: "0.0")
        let vm = viewModel(flights: [flight])
        vm.selectedTimeCredit = .value(.p1us)
        vm.p1Time = .notEdited
        vm.p1usTime = .notEdited
        vm.p2Time = .notEdited

        let result = vm.applyChanges(to: [flight])
        let updated = result[flight.id]!
        #expect(updated.p1usTimeValue == 6.0)
        #expect(updated.p1TimeValue == 0.0)
        #expect(updated.p2TimeValue == 0.0)
    }

    @Test func timeCreditChange_toP1_setsP1ToBlockTime_clearsOthers() {
        let flight = makeFlight(blockTime: "5.0", p1Time: "0.0", p1usTime: "0.0", p2Time: "5.0")
        let vm = viewModel(flights: [flight])
        vm.selectedTimeCredit = .value(.p1)
        vm.p1Time = .notEdited
        vm.p1usTime = .notEdited
        vm.p2Time = .notEdited

        let result = vm.applyChanges(to: [flight])
        let updated = result[flight.id]!
        #expect(updated.p1TimeValue == 5.0)
        #expect(updated.p1usTimeValue == 0.0)
        #expect(updated.p2TimeValue == 0.0)
    }

    // MARK: - Approach type mapping

    @Test func approachType_ILS_setsIsILS_clearsOthers() {
        let flight = makeFlight(isRNP: true)
        let vm = viewModel(flights: [flight])
        vm.selectedApproachType = .value("ILS")

        let result = vm.applyChanges(to: [flight])
        let updated = result[flight.id]!
        #expect(updated.isILS == true)
        #expect(updated.isRNP == false)
        #expect(updated.isAIII == false)
        #expect(updated.isGLS == false)
        #expect(updated.isNPA == false)
    }

    @Test func approachType_none_clearsAll() {
        let flight = makeFlight(isILS: true)
        let vm = viewModel(flights: [flight])
        vm.selectedApproachType = .value(nil)

        let result = vm.applyChanges(to: [flight])
        let updated = result[flight.id]!
        #expect(updated.isILS == false)
        #expect(updated.isRNP == false)
        #expect(updated.isAIII == false)
        #expect(updated.isGLS == false)
        #expect(updated.isNPA == false)
    }

    @Test func approachType_RNP() {
        let flight = makeFlight()
        let vm = viewModel(flights: [flight])
        vm.selectedApproachType = .value("RNP")

        let result = vm.applyChanges(to: [flight])
        #expect(result[flight.id]?.isRNP == true)
    }

    @Test func approachType_AIII() {
        let flight = makeFlight()
        let vm = viewModel(flights: [flight])
        vm.selectedApproachType = .value("AIII")

        let result = vm.applyChanges(to: [flight])
        #expect(result[flight.id]?.isAIII == true)
    }

    // MARK: - Multiple flights

    @Test func appliesChangesToAllFlights() {
        let f1 = makeFlight(flightNumber: "QF001", aircraftType: "B789")
        let f2 = makeFlight(flightNumber: "QF002", aircraftType: "A380")
        let vm = viewModel(flights: [f1, f2])
        vm.captainName = .value("Williams")

        let result = vm.applyChanges(to: [f1, f2])
        #expect(result[f1.id]?.captainName == "Williams")
        #expect(result[f2.id]?.captainName == "Williams")
    }

    // MARK: - FieldState analysis

    @Test func analyzeFields_allSame_producesValue() {
        let f1 = makeFlight(aircraftType: "B789")
        let f2 = makeFlight(aircraftType: "B789")
        let vm = viewModel(flights: [f1, f2])
        #expect(vm.aircraftType == .value("B789"))
    }

    @Test func analyzeFields_different_producesMixed() {
        let f1 = makeFlight(aircraftType: "B789")
        let f2 = makeFlight(aircraftType: "A380")
        let vm = viewModel(flights: [f1, f2])
        #expect(vm.aircraftType == .mixed)
    }
}
