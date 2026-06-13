//
//  MacFilterState.swift
//  Block-Time-Mac
//

import Foundation
import Observation

enum MacDateRangeOption: Int {
    case allFlights = 0, twelveMonths = 1, sixMonths = 2, twentyEightDays = 3, custom = 4
}

@Observable
final class MacFilterState {
    // Incremented on every property change — observe this single value instead of all properties
    private(set) var version: Int = 0
    private func touch() { version &+= 1 }

    var filterStartDate: Date = .distantPast          { didSet { touch() } }
    var filterEndDate: Date = .distantFuture           { didSet { touch() } }
    var selectedDateRange: MacDateRangeOption = .allFlights { didSet { touch() } }

    var filterAircraftType: String = ""  { didSet { touch() } }
    var filterAircraftReg: String = ""   { didSet { touch() } }

    var filterCaptainName: String = ""   { didSet { touch() } }
    var filterFOName: String = ""        { didSet { touch() } }
    var filterSOName: String = ""        { didSet { touch() } }

    var filterFromAirport: String = ""   { didSet { touch() } }
    var filterToAirport: String = ""     { didSet { touch() } }
    var filterFlightNumber: String = ""  { didSet { touch() } }
    var filterKeywordSearch: String = "" { didSet { touch() } }

    var filterPilotFlyingOnly: Bool = false  { didSet { touch() } }
    var filterApproachType: String? = nil    { didSet { touch() } }
    var filterContainsRemarks: Bool = false  { didSet { touch() } }
    var filterSimulator: Bool = false        { didSet { touch() } }
    var filterPositioning: Bool = false      { didSet { touch() } }
    var filterSpIns: Bool = false            { didSet { touch() } }
    var filterTypeSummary: Bool = false      { didSet { touch() } }

    var filterNoBlockTime: Bool = false    { didSet { touch() } }
    var filterNoCrewNames: Bool = false    { didSet { touch() } }
    var filterNoFlightNumber: Bool = false { didSet { touch() } }
    var filterNoAircraftType: Bool = false { didSet { touch() } }
    var filterNoAircraftReg: Bool = false  { didSet { touch() } }

    var sortOrderReversed: Bool = false { didSet { touch() } }

    var isActive: Bool {
        selectedDateRange != .allFlights ||
        !filterAircraftType.isEmpty ||
        !filterAircraftReg.isEmpty ||
        !filterCaptainName.isEmpty ||
        !filterFOName.isEmpty ||
        !filterSOName.isEmpty ||
        !filterFromAirport.isEmpty ||
        !filterToAirport.isEmpty ||
        !filterFlightNumber.isEmpty ||
        !filterKeywordSearch.isEmpty ||
        filterPilotFlyingOnly ||
        filterApproachType != nil ||
        filterContainsRemarks ||
        filterSimulator ||
        filterPositioning ||
        filterSpIns ||
        filterTypeSummary ||
        filterNoBlockTime ||
        filterNoCrewNames ||
        filterNoFlightNumber ||
        filterNoAircraftType ||
        filterNoAircraftReg ||
        sortOrderReversed
    }

    func clearFilters() {
        filterStartDate = .distantPast
        filterEndDate = .distantFuture
        selectedDateRange = .allFlights
        filterAircraftType = ""
        filterAircraftReg = ""
        filterCaptainName = ""
        filterFOName = ""
        filterSOName = ""
        filterFromAirport = ""
        filterToAirport = ""
        filterFlightNumber = ""
        filterKeywordSearch = ""
        filterPilotFlyingOnly = false
        filterApproachType = nil
        filterContainsRemarks = false
        filterSimulator = false
        filterPositioning = false
        filterSpIns = false
        filterTypeSummary = false
        filterNoBlockTime = false
        filterNoCrewNames = false
        filterNoFlightNumber = false
        filterNoAircraftType = false
        filterNoAircraftReg = false
        sortOrderReversed = false
    }
}
