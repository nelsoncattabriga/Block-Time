//
//  BulkEditViewModel.swift
//  Block-Time
//
//  Created by Nelson on 16/01/2026.
//

import Foundation
import Combine

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

    // MARK: - Published Properties

    // Aircraft Info
    @Published var aircraftReg: FieldState<String> = .notEdited
    @Published var aircraftType: FieldState<String> = .notEdited

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

    // Schedule
    @Published var outTime: FieldState<String> = .notEdited
    @Published var inTime: FieldState<String> = .notEdited
    @Published var scheduledDeparture: FieldState<String> = .notEdited
    @Published var scheduledArrival: FieldState<String> = .notEdited

    // Booleans
    @Published var isPilotFlying: FieldState<Bool> = .notEdited
    @Published var isICUS: FieldState<Bool> = .notEdited
    @Published var isPositioning: FieldState<Bool> = .notEdited
    @Published var isSimulator: FieldState<Bool> = .notEdited

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

    // Remarks
    @Published var remarks: FieldState<String> = .notEdited

    // Modification tracking
    @Published var hasModifications: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let selectedFlights: [FlightSector]

    // MARK: - Initialization

    init(selectedFlights: [FlightSector]) {
        self.selectedFlights = selectedFlights

        // Analyze initial field states
        analyzeFields()

        // Setup modification tracking
        setupModificationTracking()
    }

    // MARK: - Field Analysis

    private func analyzeFields() {
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

        outTime = Self.analyzeStringField(selectedFlights) { $0.outTime }
        inTime = Self.analyzeStringField(selectedFlights) { $0.inTime }
        scheduledDeparture = Self.analyzeStringField(selectedFlights) { $0.scheduledDeparture }
        scheduledArrival = Self.analyzeStringField(selectedFlights) { $0.scheduledArrival }

        isPilotFlying = Self.analyzeBoolField(selectedFlights) { $0.isPilotFlying }
        isICUS = Self.analyzeBoolField(selectedFlights) { flight in
            let p1usValue = Double(flight.p1usTime) ?? 0.0
            return p1usValue > 0.0
        }
        isPositioning = Self.analyzeBoolField(selectedFlights) { $0.isPositioning }
        isSimulator = Self.analyzeBoolField(selectedFlights) { flight in
            let simValue = Double(flight.simTime) ?? 0.0
            return simValue > 0.0
        }

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

        remarks = Self.analyzeStringField(selectedFlights) { $0.remarks }
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

    // MARK: - Modification Tracking

    private func setupModificationTracking() {
        // Monitor all published properties for changes
        Publishers.CombineLatest4(
            $aircraftReg, $aircraftType, $captainName, $foName
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
            $scheduledArrival, $isPilotFlying, $isICUS, $isPositioning
        )
        .sink { [weak self] _ in
            self?.checkForModifications()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $isSimulator, $isAIII, $isRNP, $isILS
        )
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

        $remarks
            .sink { [weak self] _ in
                self?.checkForModifications()
            }
            .store(in: &cancellables)
    }

    private func checkForModifications() {
        // Check if any field has been changed from its initial state
        hasModifications = hasFieldBeenModified(aircraftReg) ||
                          hasFieldBeenModified(aircraftType) ||
                          hasFieldBeenModified(captainName) ||
                          hasFieldBeenModified(foName) ||
                          hasFieldBeenModified(so1Name) ||
                          hasFieldBeenModified(so2Name) ||
                          hasFieldBeenModified(blockTime) ||
                          hasFieldBeenModified(nightTime) ||
                          hasFieldBeenModified(p1Time) ||
                          hasFieldBeenModified(p1usTime) ||
                          hasFieldBeenModified(p2Time) ||
                          hasFieldBeenModified(instrumentTime) ||
                          hasFieldBeenModified(simTime) ||
                          hasFieldBeenModified(outTime) ||
                          hasFieldBeenModified(inTime) ||
                          hasFieldBeenModified(scheduledDeparture) ||
                          hasFieldBeenModified(scheduledArrival) ||
                          hasFieldBeenModified(isPilotFlying) ||
                          hasFieldBeenModified(isICUS) ||
                          hasFieldBeenModified(isPositioning) ||
                          hasFieldBeenModified(isSimulator) ||
                          hasFieldBeenModified(selectedApproachType) ||
                          hasFieldBeenModified(isAIII) ||
                          hasFieldBeenModified(isRNP) ||
                          hasFieldBeenModified(isILS) ||
                          hasFieldBeenModified(isGLS) ||
                          hasFieldBeenModified(isNPA) ||
                          hasFieldBeenModified(dayTakeoffs) ||
                          hasFieldBeenModified(dayLandings) ||
                          hasFieldBeenModified(nightTakeoffs) ||
                          hasFieldBeenModified(nightLandings) ||
                          hasFieldBeenModified(remarks)
    }

    private func hasFieldBeenModified<T: Equatable>(_ field: FieldState<T>) -> Bool {
        // Field is modified if it's now .value and wasn't originally .value,
        // or if it's .value but different from all original values
        if case .value = field {
            return true
        }
        return false
    }

    // MARK: - Apply Changes

    func applyChanges(to flights: [FlightSector]) -> [UUID: FlightSector] {
        var updatedFlights: [UUID: FlightSector] = [:]

        for flight in flights {
            var updated = flight

            // Only update fields that have .value state (user explicitly set them)
            if case .value(let reg) = aircraftReg {
                updated.aircraftReg = reg
            }
            if case .value(let type) = aircraftType {
                updated.aircraftType = type
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

            // Apply individual time fields (these override simulator conversion if specified)
            if case .value(let block) = blockTime {
                updated.blockTime = block
            }
            if case .value(let night) = nightTime {
                updated.nightTime = night
            }
            if case .value(let p1) = p1Time {
                updated.p1Time = p1
            }
            if case .value(let p1us) = p1usTime {
                updated.p1usTime = p1us
            }
            if case .value(let p2) = p2Time {
                updated.p2Time = p2
            }
            if case .value(let inst) = instrumentTime {
                updated.instrumentTime = inst
            }
            if case .value(let sim) = simTime {
                updated.simTime = sim
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

            if case .value(let rem) = remarks {
                updated.remarks = rem
            }

            updatedFlights[flight.id] = updated
        }

        return updatedFlights
    }
}
