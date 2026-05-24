//
//  BulkEditViewModel.swift
//  Block-Time
//
//  Created by Nelson on 16/01/2026.
//

import Foundation
import Combine
import SwiftUI

class BulkEditViewModel: ObservableObject {

    // MARK: - Field State Enum

    enum FieldState<T: Equatable>: Equatable {
        case notEdited
        case mixed
        case value(T)

        var displayValue: T? {
            if case .value(let val) = self {
                return val
            }
            return nil
        }

        var isMixed: Bool {
            if case .mixed = self {
                return true
            }
            return false
        }
    }

    // MARK: - Prefix Operation Enum

    enum PrefixOperation: String, Equatable, CaseIterable {
        case noChange = "No Change"
        case add = "Add"
        case remove = "Remove"
    }

    // MARK: - Published Properties

    // Flight Date
    @Published var flightDate: FieldState<String> = .notEdited

    // Aircraft Info
    @Published var aircraftReg: FieldState<String> = .notEdited
    @Published var aircraftType: FieldState<String> = .notEdited
    @Published var prefixOperation: FieldState<PrefixOperation> = .notEdited
    @Published var prefixValue: FieldState<String> = .notEdited
    @Published var regoPrefixOperation: FieldState<PrefixOperation> = .notEdited
    @Published var regoPrefixValue: FieldState<String> = .notEdited

    // Crew
    @Published var captainName: FieldState<String> = .notEdited
    @Published var foName: FieldState<String> = .notEdited
    @Published var so1Name: FieldState<String?> = .notEdited
    @Published var so2Name: FieldState<String?> = .notEdited

    // Times
    @Published var blockTime: FieldState<String> = .notEdited
    @Published var nightTime: FieldState<String> = .notEdited
    @Published var p1Time: FieldState<String> = .notEdited
    @Published var p1usTime: FieldState<String> = .notEdited
    @Published var p2Time: FieldState<String> = .notEdited
    @Published var instrumentTime: FieldState<String> = .notEdited
    @Published var simTime: FieldState<String> = .notEdited
    @Published var spInsTime: FieldState<String> = .notEdited

    // Schedule
    @Published var outTime: FieldState<String> = .notEdited
    @Published var inTime: FieldState<String> = .notEdited
    @Published var scheduledDeparture: FieldState<String> = .notEdited
    @Published var scheduledArrival: FieldState<String> = .notEdited

    // Booleans
    @Published var isPilotFlying: FieldState<Bool> = .notEdited
    @Published var isPositioning: FieldState<Bool> = .notEdited
    @Published var isSimulator: FieldState<Bool> = .notEdited
    @Published var isSpIns: FieldState<Bool> = .notEdited

    // Time Credit Type
    @Published var selectedTimeCredit: FieldState<TimeCreditType> = .notEdited

    // Copy each flight's own block time into the chosen role field
    @Published var blockTimeRole: FieldState<TimeCreditType> = .notEdited

    // Approach types (stored as individual bools but presented as single selection)
    @Published var isAIII: FieldState<Bool> = .notEdited
    @Published var isRNP: FieldState<Bool> = .notEdited
    @Published var isILS: FieldState<Bool> = .notEdited
    @Published var isGLS: FieldState<Bool> = .notEdited
    @Published var isNPA: FieldState<Bool> = .notEdited

    // Computed approach type for UI
    @Published var selectedApproachType: FieldState<String?> = .notEdited

    // Takeoffs & Landings
    @Published var dayTakeoffs: FieldState<Int> = .notEdited
    @Published var dayLandings: FieldState<Int> = .notEdited
    @Published var nightTakeoffs: FieldState<Int> = .notEdited
    @Published var nightLandings: FieldState<Int> = .notEdited

    // Route
    @Published var fromAirport: FieldState<String> = .notEdited
    @Published var toAirport: FieldState<String> = .notEdited

    // Remarks
    @Published var remarks: FieldState<String> = .notEdited

    // Custom Counters (keyed by columnIndex 1-10)
    @Published var customCounterStates: [Int: FieldState<String>] = [:]

    // Modification tracking
    @Published var hasModifications: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let selectedFlights: [FlightSector]

    // Store initial states to detect actual modifications
    private var initialStates: [String: Any] = [:]

    // MARK: - Initialization

    init(selectedFlights: [FlightSector]) {
        self.selectedFlights = selectedFlights

        // Analyze initial field states
        analyzeFields()

        // Store initial states before tracking begins
        storeInitialStates()

        // Setup modification tracking
        setupModificationTracking()
    }

    // MARK: - Field Analysis

    private func analyzeFields() {
        flightDate = Self.analyzeStringField(selectedFlights) { $0.date }

        aircraftReg = Self.analyzeStringField(selectedFlights) { $0.aircraftReg }
        aircraftType = Self.analyzeStringField(selectedFlights) { $0.aircraftType }

        captainName = Self.analyzeStringField(selectedFlights) { $0.captainName }
        foName = Self.analyzeStringField(selectedFlights) { $0.foName }
        so1Name = Self.analyzeOptionalStringField(selectedFlights) { $0.so1Name }
        so2Name = Self.analyzeOptionalStringField(selectedFlights) { $0.so2Name }

        blockTime = Self.analyzeStringField(selectedFlights) { $0.blockTime }
        nightTime = Self.analyzeStringField(selectedFlights) { $0.nightTime }
        p1Time = Self.analyzeStringField(selectedFlights) { $0.p1Time }
        p1usTime = Self.analyzeStringField(selectedFlights) { $0.p1usTime }
        p2Time = Self.analyzeStringField(selectedFlights) { $0.p2Time }
        instrumentTime = Self.analyzeStringField(selectedFlights) { $0.instrumentTime }
        simTime = Self.analyzeStringField(selectedFlights) { $0.simTime }
        spInsTime = Self.analyzeStringField(selectedFlights) { $0.spInsTime }

        outTime = Self.analyzeStringField(selectedFlights) { $0.outTime }
        inTime = Self.analyzeStringField(selectedFlights) { $0.inTime }
        scheduledDeparture = Self.analyzeStringField(selectedFlights) { $0.scheduledDeparture }
        scheduledArrival = Self.analyzeStringField(selectedFlights) { $0.scheduledArrival }

        isPilotFlying = Self.analyzeBoolField(selectedFlights) { $0.isPilotFlying }
        isPositioning = Self.analyzeBoolField(selectedFlights) { $0.isPositioning }
        isSimulator = Self.analyzeBoolField(selectedFlights) { flight in
            let simValue = Double(flight.simTime) ?? 0.0
            return simValue > 0.0
        }
        isSpIns = Self.analyzeBoolField(selectedFlights) { flight in
            let spValue = Double(flight.spInsTime) ?? 0.0
            return spValue > 0.0
        }

        // Analyze time credit type
        selectedTimeCredit = Self.analyzeTimeCreditType(selectedFlights)

        // Analyze individual approach booleans
        isAIII = Self.analyzeBoolField(selectedFlights) { $0.isAIII }
        isRNP = Self.analyzeBoolField(selectedFlights) { $0.isRNP }
        isILS = Self.analyzeBoolField(selectedFlights) { $0.isILS }
        isGLS = Self.analyzeBoolField(selectedFlights) { $0.isGLS }
        isNPA = Self.analyzeBoolField(selectedFlights) { $0.isNPA }

        // Derive approach type from individual booleans
        selectedApproachType = Self.analyzeApproachType(selectedFlights)

        dayTakeoffs = Self.analyzeIntField(selectedFlights) { $0.dayTakeoffs }
        dayLandings = Self.analyzeIntField(selectedFlights) { $0.dayLandings }
        nightTakeoffs = Self.analyzeIntField(selectedFlights) { $0.nightTakeoffs }
        nightLandings = Self.analyzeIntField(selectedFlights) { $0.nightLandings }

        fromAirport = Self.analyzeStringField(selectedFlights) { $0.fromAirport }
        toAirport = Self.analyzeStringField(selectedFlights) { $0.toAirport }

        remarks = Self.analyzeStringField(selectedFlights) { $0.remarks }

        // Analyze custom counter states — BulkEditSheet is constructed on main thread,
        // so MainActor.assumeIsolated is safe here during init.
        let defs = MainActor.assumeIsolated { CustomCounterService.shared.definitions }
        for def in defs {
            customCounterStates[def.columnIndex] = Self.analyzeStringField(selectedFlights) {
                $0.counterEntries[def.columnIndex] ?? ""
            }
        }
    }

    private static func analyzeStringField(_ flights: [FlightSector], keyPath: (FlightSector) -> String) -> FieldState<String> {
        let values = Set(flights.map(keyPath))
        if values.count == 1, let value = values.first {
            return .value(value)
        }
        return .mixed
    }

    private static func analyzeOptionalStringField(_ flights: [FlightSector], keyPath: (FlightSector) -> String?) -> FieldState<String?> {
        let values = Set(flights.map(keyPath))
        if values.count == 1, let value = values.first {
            return .value(value)
        }
        return .mixed
    }

    private static func analyzeBoolField(_ flights: [FlightSector], keyPath: (FlightSector) -> Bool) -> FieldState<Bool> {
        let values = Set(flights.map(keyPath))
        if values.count == 1, let value = values.first {
            return .value(value)
        }
        return .mixed
    }

    private static func analyzeIntField(_ flights: [FlightSector], keyPath: (FlightSector) -> Int) -> FieldState<Int> {
        let values = Set(flights.map(keyPath))
        if values.count == 1, let value = values.first {
            return .value(value)
        }
        return .mixed
    }

    private static func analyzeApproachType(_ flights: [FlightSector]) -> FieldState<String?> {
        let approachTypes = flights.map { flight -> String? in
            if flight.isAIII { return "AIII" }
            if flight.isRNP { return "RNP" }
            if flight.isILS { return "ILS" }
            if flight.isGLS { return "GLS" }
            if flight.isNPA { return "NPA" }
            return nil
        }

        let uniqueTypes = Set(approachTypes)
        if uniqueTypes.count == 1, let type = uniqueTypes.first {
            return .value(type)
        }
        return .mixed
    }

    private static func analyzeTimeCreditType(_ flights: [FlightSector]) -> FieldState<TimeCreditType> {
        let creditTypes = flights.map { flight -> TimeCreditType in
            let p1usValue = Double(flight.p1usTime) ?? 0.0
            let p2Value = Double(flight.p2Time) ?? 0.0

            // Determine which time credit type has the value
            if p1usValue > 0.0 {
                return .p1us
            } else if p2Value > 0.0 {
                return .p2
            } else {
                return .p1  // Default to P1
            }
        }

        let uniqueTypes = Set(creditTypes)
        if uniqueTypes.count == 1, let type = uniqueTypes.first {
            return .value(type)
        }
        return .mixed
    }

    // MARK: - Initial State Storage

    private func storeInitialStates() {
        initialStates = [
            "flightDate": flightDate,
            "aircraftReg": aircraftReg,
            "aircraftType": aircraftType,
            "prefixOperation": prefixOperation,
            "prefixValue": prefixValue,
            "regoPrefixOperation": regoPrefixOperation,
            "regoPrefixValue": regoPrefixValue,
            "captainName": captainName,
            "foName": foName,
            "so1Name": so1Name,
            "so2Name": so2Name,
            "blockTime": blockTime,
            "nightTime": nightTime,
            "p1Time": p1Time,
            "p1usTime": p1usTime,
            "p2Time": p2Time,
            "instrumentTime": instrumentTime,
            "simTime": simTime,
            "spInsTime": spInsTime,
            "outTime": outTime,
            "inTime": inTime,
            "scheduledDeparture": scheduledDeparture,
            "scheduledArrival": scheduledArrival,
            "isPilotFlying": isPilotFlying,
            "isPositioning": isPositioning,
            "isSimulator": isSimulator,
            "isSpIns": isSpIns,
            "selectedTimeCredit": selectedTimeCredit,
            "selectedApproachType": selectedApproachType,
            "isAIII": isAIII,
            "isRNP": isRNP,
            "isILS": isILS,
            "isGLS": isGLS,
            "isNPA": isNPA,
            "dayTakeoffs": dayTakeoffs,
            "dayLandings": dayLandings,
            "nightTakeoffs": nightTakeoffs,
            "nightLandings": nightLandings,
            "fromAirport": fromAirport,
            "toAirport": toAirport,
            "remarks": remarks
        ]
        // Store initial states for each custom counter independently
        for (columnIndex, state) in customCounterStates {
            initialStates["customCounter_\(columnIndex)"] = state
        }
    }

    // MARK: - Modification Tracking

    private func setupModificationTracking() {
        // Monitor all published properties for changes
        Publishers.CombineLatest4(
            $aircraftReg, $aircraftType, $prefixOperation, $prefixValue
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest(
            $captainName, $foName
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $so1Name, $so2Name, $blockTime, $nightTime
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $p1Time, $p1usTime, $p2Time, $instrumentTime
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $simTime, $outTime, $inTime, $scheduledDeparture
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $scheduledArrival, $isPilotFlying, $isPositioning, $isSimulator
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $isAIII, $isRNP, $isILS, $selectedTimeCredit
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        $blockTimeRole
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkForModifications()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            $isGLS, $isNPA, $selectedApproachType
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $dayTakeoffs, $dayLandings, $nightTakeoffs, $nightLandings
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest(
            $regoPrefixOperation, $regoPrefixValue
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest(
            $fromAirport, $toAirport
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        $remarks
            .sink { [weak self] _ in
                self?.checkForModifications()
            }
            .store(in: &cancellables)

        $isSpIns
            .sink { [weak self] _ in
                self?.checkForModifications()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            $flightDate, $isSpIns, $spInsTime
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        $customCounterStates
            .receive(on: RunLoop.main)
            .sink { [weak self] newStates in
                self?.checkForModifications(customStates: newStates)
            }
            .store(in: &cancellables)
    }

    private func checkForModifications(customStates: [Int: FieldState<String>]? = nil) {
        let counters = customStates ?? customCounterStates
        // Check if any field has been changed from its initial state
        hasModifications = hasFieldBeenModified(aircraftReg, key: "aircraftReg") ||
                          hasFieldBeenModified(aircraftType, key: "aircraftType") ||
                          hasFieldBeenModified(prefixOperation, key: "prefixOperation") ||
                          hasFieldBeenModified(prefixValue, key: "prefixValue") ||
                          hasFieldBeenModified(regoPrefixOperation, key: "regoPrefixOperation") ||
                          hasFieldBeenModified(regoPrefixValue, key: "regoPrefixValue") ||
                          hasFieldBeenModified(captainName, key: "captainName") ||
                          hasFieldBeenModified(foName, key: "foName") ||
                          hasFieldBeenModified(so1Name, key: "so1Name") ||
                          hasFieldBeenModified(so2Name, key: "so2Name") ||
                          hasFieldBeenModified(blockTime, key: "blockTime") ||
                          hasFieldBeenModified(nightTime, key: "nightTime") ||
                          hasFieldBeenModified(p1Time, key: "p1Time") ||
                          hasFieldBeenModified(p1usTime, key: "p1usTime") ||
                          hasFieldBeenModified(p2Time, key: "p2Time") ||
                          hasFieldBeenModified(instrumentTime, key: "instrumentTime") ||
                          hasFieldBeenModified(simTime, key: "simTime") ||
                          hasFieldBeenModified(outTime, key: "outTime") ||
                          hasFieldBeenModified(inTime, key: "inTime") ||
                          hasFieldBeenModified(scheduledDeparture, key: "scheduledDeparture") ||
                          hasFieldBeenModified(scheduledArrival, key: "scheduledArrival") ||
                          hasFieldBeenModified(isPilotFlying, key: "isPilotFlying") ||
                          hasFieldBeenModified(isPositioning, key: "isPositioning") ||
                          hasFieldBeenModified(isSimulator, key: "isSimulator") ||
                          hasFieldBeenModified(selectedTimeCredit, key: "selectedTimeCredit") ||
                          (blockTimeRole != .notEdited) ||
                          hasFieldBeenModified(selectedApproachType, key: "selectedApproachType") ||
                          hasFieldBeenModified(isAIII, key: "isAIII") ||
                          hasFieldBeenModified(isRNP, key: "isRNP") ||
                          hasFieldBeenModified(isILS, key: "isILS") ||
                          hasFieldBeenModified(isGLS, key: "isGLS") ||
                          hasFieldBeenModified(isNPA, key: "isNPA") ||
                          hasFieldBeenModified(dayTakeoffs, key: "dayTakeoffs") ||
                          hasFieldBeenModified(dayLandings, key: "dayLandings") ||
                          hasFieldBeenModified(nightTakeoffs, key: "nightTakeoffs") ||
                          hasFieldBeenModified(nightLandings, key: "nightLandings") ||
                          hasFieldBeenModified(fromAirport, key: "fromAirport") ||
                          hasFieldBeenModified(toAirport, key: "toAirport") ||
                          hasFieldBeenModified(remarks, key: "remarks") ||
                          hasFieldBeenModified(flightDate, key: "flightDate") ||
                          hasFieldBeenModified(isSpIns, key: "isSpIns") ||
                          hasFieldBeenModified(spInsTime, key: "spInsTime") ||
                          counters.contains(where: { (col, state) in
                              let key = "customCounter_\(col)"
                              if initialStates[key] != nil {
                                  return hasFieldBeenModified(state, key: key)
                              }
                              // New definition added after sheet init — any non-empty value is a modification
                              if case .value(let v) = state { return !v.isEmpty }
                              return false
                          })
    }

    private func hasFieldBeenModified<T: Equatable>(_ field: FieldState<T>, key: String) -> Bool {
        // Get the initial state for this field
        guard let initialState = initialStates[key] as? FieldState<T> else {
            return false
        }

        // Field is modified only if the current state differs from the initial state
        return field != initialState
    }

    // MARK: - Apply Changes

    func applyChanges(to flights: [FlightSector]) -> [UUID: FlightSector] {
        var updatedFlights: [UUID: FlightSector] = [:]

        for flight in flights {
            var updated = flight

            // Only update fields that have .value state (user explicitly set them)
            if case .value(let d) = flightDate {
                updated.date = d
            }

            if case .value(let reg) = aircraftReg {
                updated.aircraftReg = reg
            }
            if case .value(let type) = aircraftType {
                updated.aircraftType = type
            }

            // Handle prefix operation
            if case .value(let operation) = prefixOperation, operation != .noChange,
               case .value(let prefix) = prefixValue, !prefix.isEmpty {
                let currentFlightNumber = updated.flightNumber

                switch operation {
                case .add:
                    // Add prefix if it doesn't already start with it
                    let uppercasePrefix = prefix.uppercased()
                    if !currentFlightNumber.uppercased().hasPrefix(uppercasePrefix) {
                        updated.flightNumber = uppercasePrefix + currentFlightNumber
                    }

                case .remove:
                    // Remove prefix if it starts with it
                    let uppercasePrefix = prefix.uppercased()
                    if currentFlightNumber.uppercased().hasPrefix(uppercasePrefix) {
                        updated.flightNumber = String(currentFlightNumber.dropFirst(uppercasePrefix.count))
                    }

                case .noChange:
                    break
                }
            }

            // Handle rego prefix operation
            if case .value(let operation) = regoPrefixOperation, operation != .noChange,
               case .value(let prefix) = regoPrefixValue, !prefix.isEmpty {
                let currentReg = updated.aircraftReg

                switch operation {
                case .add:
                    let uppercasePrefix = prefix.uppercased()
                    if !currentReg.isEmpty && !currentReg.uppercased().hasPrefix(uppercasePrefix) {
                        updated.aircraftReg = uppercasePrefix + currentReg
                    }

                case .remove:
                    let uppercasePrefix = prefix.uppercased()
                    if currentReg.uppercased().hasPrefix(uppercasePrefix) {
                        updated.aircraftReg = String(currentReg.dropFirst(uppercasePrefix.count))
                    }

                case .noChange:
                    break
                }
            }

            if case .value(let captain) = captainName {
                updated.captainName = captain
            }
            if case .value(let fo) = foName {
                updated.foName = fo
            }
            if case .value(let so1) = so1Name {
                updated.so1Name = so1
            }
            if case .value(let so2) = so2Name {
                updated.so2Name = so2
            }

            // Handle simulator conversion first, before applying individual time fields
            if case .value(let isSim) = isSimulator {
                if isSim {
                    // Converting to simulator: move blockTime to simTime, set blockTime to 0
                    let currentBlockTime = updated.blockTime
                    if let blockValue = Double(currentBlockTime), blockValue > 0 {
                        updated.simTime = currentBlockTime
                        updated.blockTime = "0.0"
                    }
                } else {
                    // Converting from simulator: move simTime to blockTime, set simTime to 0
                    let currentSimTime = updated.simTime
                    if let simValue = Double(currentSimTime), simValue > 0 {
                        updated.blockTime = currentSimTime
                        updated.simTime = "0.0"
                    }
                }
            }

            // Handle Sp/Ins conversion, mirroring the isSimulator pattern above
            if case .value(let isSp) = isSpIns {
                if isSp {
                    // Converting to Sp/Ins: move blockTime to spInsTime, set blockTime to 0
                    let currentBlock = updated.blockTime
                    if let v = Double(currentBlock), v > 0 {
                        updated.spInsTime = currentBlock
                        updated.blockTime = "0.0"
                    }
                } else {
                    // Converting from Sp/Ins: move spInsTime to blockTime, set spInsTime to 0
                    let currentSp = updated.spInsTime
                    if let v = Double(currentSp), v > 0 {
                        updated.blockTime = currentSp
                        updated.spInsTime = "0.0"
                    }
                }
            }

            // Handle time credit type change
            // This redistributes time from the current credit type to the new one
            if case .value(let creditType) = selectedTimeCredit {
                // Get the current block time
                let currentBlockTime = updated.blockTime

                // Clear all credit times first
                updated.p1Time = "0.0"
                updated.p1usTime = "0.0"
                updated.p2Time = "0.0"

                // Set the selected credit time to block time
                switch creditType {
                case .p1:
                    updated.p1Time = currentBlockTime
                case .p1us:
                    updated.p1usTime = currentBlockTime
                case .p2:
                    updated.p2Time = currentBlockTime
                }
            }

            // Copy each flight's own block time into the chosen role field
            if case .value(let role) = blockTimeRole {
                updated.p1Time = "0.0"
                updated.p1usTime = "0.0"
                updated.p2Time = "0.0"
                switch role {
                case .p1:   updated.p1Time = updated.blockTime
                case .p1us: updated.p1usTime = updated.blockTime
                case .p2:   updated.p2Time = updated.blockTime
                }
            }

            // Apply individual time fields (these override time credit selection if specified)
            if case .value(let block) = blockTime {
                updated.blockTime = block
            }
            if case .value(let night) = nightTime {
                updated.nightTime = night
            }
            if case .value(let p1) = p1Time, case .notEdited = blockTimeRole {
                updated.p1Time = p1
            }
            if case .value(let p1us) = p1usTime, case .notEdited = blockTimeRole {
                updated.p1usTime = p1us
            }
            if case .value(let p2) = p2Time, case .notEdited = blockTimeRole {
                updated.p2Time = p2
            }
            if case .value(let inst) = instrumentTime {
                updated.instrumentTime = inst
            }
            if case .value(let sim) = simTime {
                updated.simTime = sim
            }
            if case .value(let sp) = spInsTime {
                updated.spInsTime = sp
            }

            if case .value(let out) = outTime {
                updated.outTime = out
            }
            if case .value(let `in`) = inTime {
                updated.inTime = `in`
            }
            if case .value(let std) = scheduledDeparture {
                updated.scheduledDeparture = std
            }
            if case .value(let sta) = scheduledArrival {
                updated.scheduledArrival = sta
            }

            if case .value(let pf) = isPilotFlying {
                updated.isPilotFlying = pf
            }

            // Handle ICUS - note: In the model, ICUS is inferred from p1usTime > 0
            // For bulk edit, we won't modify p1usTime here as it's already handled above
            // The ICUS toggle is more for visibility/filtering in the UI

            if case .value(let pos) = isPositioning {
                updated.isPositioning = pos
            }

            // Handle approach type - convert single selection to individual booleans
            if case .value(let approachType) = selectedApproachType {
                // Clear all approach types first
                updated.isAIII = false
                updated.isRNP = false
                updated.isILS = false
                updated.isGLS = false
                updated.isNPA = false

                // Set the selected one
                switch approachType {
                case "AIII":
                    updated.isAIII = true
                case "RNP":
                    updated.isRNP = true
                case "ILS":
                    updated.isILS = true
                case "GLS":
                    updated.isGLS = true
                case "NPA":
                    updated.isNPA = true
                case .none:
                    break // All remain false
                default:
                    break
                }
            } else {
                // If approach type wasn't changed, check individual toggles (for backward compatibility)
                if case .value(let aiii) = isAIII {
                    updated.isAIII = aiii
                }
                if case .value(let rnp) = isRNP {
                    updated.isRNP = rnp
                }
                if case .value(let ils) = isILS {
                    updated.isILS = ils
                }
                if case .value(let gls) = isGLS {
                    updated.isGLS = gls
                }
                if case .value(let npa) = isNPA {
                    updated.isNPA = npa
                }
            }

            if case .value(let dayTO) = dayTakeoffs {
                updated.dayTakeoffs = dayTO
            }
            if case .value(let dayLdg) = dayLandings {
                updated.dayLandings = dayLdg
            }
            if case .value(let nightTO) = nightTakeoffs {
                updated.nightTakeoffs = nightTO
            }
            if case .value(let nightLdg) = nightLandings {
                updated.nightLandings = nightLdg
            }

            if case .value(let from) = fromAirport {
                updated.fromAirport = from
            }
            if case .value(let to) = toAirport {
                updated.toAirport = to
            }

            if case .value(let rem) = remarks {
                updated.remarks = rem
            }

            // Write back custom counter values
            for (columnIndex, state) in customCounterStates {
                if case .value(let v) = state {
                    if v.isEmpty {
                        updated.counterEntries.removeValue(forKey: columnIndex)
                    } else {
                        updated.counterEntries[columnIndex] = v
                    }
                }
            }

            updatedFlights[flight.id] = updated
        }

        return updatedFlights
    }
}
