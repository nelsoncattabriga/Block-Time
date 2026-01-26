//
//  FlightsFilterViewModel.swift
//  Block-Time
//
//  Created by Nelson on 3/10/2025.
//

import SwiftUI
import Combine

class FlightsFilterViewModel: ObservableObject {
    @Published var filterStartDate: Date = Date.distantPast
    @Published var filterEndDate: Date = Date.distantFuture
    @Published var filterAircraftType: String = ""
    @Published var filterAircraftReg: String = ""
    @Published var filterCaptainName: String = ""
    @Published var filterFOName: String = ""
    @Published var filterSOName: String = ""
    @Published var filterFromAirport: String = ""
    @Published var filterToAirport: String = ""
    @Published var filterFlightNumber: String = ""
    @Published var filterPilotFlyingOnly: Bool = false
    @Published var filterApproachType: String? = nil  // nil = no filter, "AIII", "RNP", "ILS", "GLS", "NPA"
    @Published var filterContainsRemarks: Bool = false
    @Published var filterSimulator: Bool = false
    @Published var filterPositioning: Bool = false
    @Published var filterNoBlockTime: Bool = false
    @Published var filterNoCrewNames: Bool = false
    @Published var filterNoFlightNumber: Bool = false
    @Published var filterTypeSummary: Bool = false
    @Published var filterKeywordSearch: String = ""
    @Published var selectedDateRange: FlightsView.DateRangeOption = .allFlights
    @Published var sortOrderReversed: Bool = false

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
