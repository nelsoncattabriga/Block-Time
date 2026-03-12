//
//  FlightsFilterViewModel.swift
//  Block-Time
//
//  Created by Nelson on 3/10/2025.
//

import SwiftUI

@Observable
@MainActor
final class FlightsFilterViewModel {
    var filterStartDate: Date = Date.distantPast
    var filterEndDate: Date = Date.distantFuture
    var filterAircraftType: String = ""
    var filterAircraftReg: String = ""
    var filterCaptainName: String = ""
    var filterFOName: String = ""
    var filterSOName: String = ""
    var filterFromAirport: String = ""
    var filterToAirport: String = ""
    var filterFlightNumber: String = ""
    var filterPilotFlyingOnly: Bool = false
    var filterApproachType: String? = nil  // nil = no filter, "AIII", "RNP", "ILS", "GLS", "NPA"
    var filterContainsRemarks: Bool = false
    var filterSimulator: Bool = false
    var filterPositioning: Bool = false
    var filterNoBlockTime: Bool = false
    var filterNoCrewNames: Bool = false
    var filterNoFlightNumber: Bool = false
    var filterTypeSummary: Bool = false
    var filterKeywordSearch: String = ""
    var selectedDateRange: FlightsView.DateRangeOption = .allFlights
    var sortOrderReversed: Bool = false

    func clearFilters() {
        filterStartDate = Date.distantPast
        filterEndDate = Date.distantFuture
        filterAircraftType = ""
        filterAircraftReg = ""
        filterCaptainName = ""
        filterFOName = ""
        filterSOName = ""
        filterFromAirport = ""
        filterToAirport = ""
        filterFlightNumber = ""
        filterPilotFlyingOnly = false
        filterApproachType = nil
        filterContainsRemarks = false
        filterSimulator = false
        filterPositioning = false
        filterNoBlockTime = false
        filterNoCrewNames = false
        filterNoFlightNumber = false
        filterTypeSummary = false
        filterKeywordSearch = ""
        selectedDateRange = .allFlights
    }
}
