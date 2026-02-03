//
//  FlightsView.swift
//  Block-Time
//
//  Created by Nelson on 30/9/2025.
//

import SwiftUI

// MARK: - Wrapper for iPad to inject filter view model
struct FlightsViewWithFilter: View {
    @ObservedObject var filterViewModel: FlightsFilterViewModel

    var body: some View {
        FlightsView(filterViewModel: filterViewModel)
    }
}

struct FlightsView: View {
    private let databaseService = FlightDatabaseService.shared
    @ObservedObject private var themeService = ThemeService.shared
    @State private var allFlightSectors: [FlightSector] = []
    @State private var filteredFlightSectors: [FlightSector] = []
    @State private var hasLoadedFlights = false
    @State private var flightStatistics = FlightStatistics.empty
    @State private var showingFilterSheet = false
    @State private var selectedFlight: FlightSector?
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject var filterViewModel: FlightsFilterViewModel

    init(filterViewModel: FlightsFilterViewModel? = nil) {
        _filterViewModel = ObservedObject(wrappedValue: filterViewModel ?? FlightsFilterViewModel())
    }

    // Cached date formatter for performance
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    @State private var isFilterActive: Bool = false
    @State private var flightToDelete: FlightSector?
    @State private var showingDeleteAlert = false
    @State private var isSelectMode: Bool = false
    @State private var selectedFlights: Set<UUID> = []
    @State private var showingBulkDeleteAlert = false
    @State private var showingBulkEditSheet = false
    @State private var summaryToEdit: FlightSector?
    @State private var reloadTask: Task<Void, Never>?
    @State private var cachedTotalHours: Double = 0.0
    @State private var hasPerformedInitialScroll: Bool = false
    @State private var shouldScrollToLastFlight: Bool = false
    @State private var shouldScrollToTop: Bool = false
    @State private var showSearchBar: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    // Made internal so it can be used by FlightsSplitView
    enum DateRangeOption: Int {
        case allFlights = 0, twelveMonths = 1, sixMonths = 2, twentyEightDays = 3, custom = 4
    }

    var body: some View {
        VStack(spacing: 0) {
                if filteredFlightSectors.isEmpty && !allFlightSectors.isEmpty && !isOnlyKeywordSearchActive() {
                    NoResultsView(onClearFilters: clearFilters)
                } else if filteredFlightSectors.isEmpty && allFlightSectors.isEmpty {
                    EmptyFlightsView()
                } else {
                    // Flight count header
                    HStack {
                        //VStack(alignment: .leading, spacing: 2) {
                            Text("\(filteredFlightSectors.count) \(filteredFlightSectors.count == 1 ? "Entry" : "Entries")")
                            .font(.headline.bold())
                                .foregroundColor(.secondary)
                        Spacer()
                        Spacer()

                        Text("\(cachedTotalHours, specifier: "%.1f") hrs")
                            .font(.headline.bold())
                                .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.clear)

                    // Search bar (collapsible)
                    if showSearchBar {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .padding(.leading, 12)

                            TextField("Search logbook...", text: $filterViewModel.filterKeywordSearch)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isSearchFieldFocused)
                                .onChange(of: filterViewModel.filterKeywordSearch) { _, _ in
                                    applyFilters()
                                }

                            if !filterViewModel.filterKeywordSearch.isEmpty {
                                Button(action: {
                                    filterViewModel.filterKeywordSearch = ""
                                    applyFilters()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.trailing, 12)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredFlightSectors, id: \.id) { sector in
                                if isSelectMode {
                                    selectModeRow(for: sector)
                                } else {
                                    normalModeRow(for: sector)
                                }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                        }
                        .scrollIndicators(.visible)
                        .refreshable {
                            await refreshFlights()
                        }
                        .onAppear {
                            scrollToFirstNonDimmedFlight(proxy: proxy)
                        }
                        .onChange(of: shouldScrollToLastFlight) { _, newValue in
                            if newValue {
                                scrollToFirstNonDimmedFlight(proxy: proxy)
                                shouldScrollToLastFlight = false
                            }
                        }
                        .onChange(of: shouldScrollToTop) { _, newValue in
                            if newValue, let firstFlight = filteredFlightSectors.first {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(firstFlight.id, anchor: .top)
                                    }
                                    shouldScrollToTop = false
                                }
                            }
                        }
                    }
                }
            }
            .background(
                themeService.getGradient()
                    .ignoresSafeArea()
            )
            .overlay(alignment: .bottomTrailing) {
                if isSelectMode {
                    HStack(spacing: 12) {
                        // Edit button
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            showingBulkEditSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil")
                                    .font(.body)
                                Text("Edit \(selectedFlights.count)")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(selectedFlights.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(selectedFlights.isEmpty)

                        // Delete button
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            showingBulkDeleteAlert = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.fill")
                                    .font(.body)
                                Text("Delete \(selectedFlights.count)")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(selectedFlights.isEmpty ? Color.red.opacity(0.5) : Color.red)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(selectedFlights.isEmpty)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelectMode)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedFlights.count)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedFlight) { sector in
                AddFlightView()
                    .environmentObject(viewModel)
                    .onDisappear {
                        // Reload flights when returning from edit
                        if !viewModel.isEditingMode {
                            loadFlights()
                        }
                        selectedFlight = nil
                    }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !filteredFlightSectors.isEmpty {
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            isSelectMode.toggle()
                            if !isSelectMode {
                                selectedFlights.removeAll()
                            }
                        }) {
                            Text(isSelectMode ? "Cancel" : "Select")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectMode {
                        // Show Select All / Deselect All button in select mode
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            let allFilteredIds = Set(filteredFlightSectors.map { $0.id })
                            if selectedFlights == allFilteredIds {
                                // All selected, so deselect all
                                selectedFlights.removeAll()
                            } else {
                                // Select all filtered flights
                                selectedFlights = allFilteredIds
                            }
                        }) {
                            let allSelected = selectedFlights == Set(filteredFlightSectors.map { $0.id })
                            Text(allSelected ? "Deselect All" : "Select All")
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Show search, sort and filter buttons in normal mode
                        HStack(spacing: 16) {
                            Button(action: {
                                HapticManager.shared.impact(.light)

                                if showSearchBar {
                                    // Hiding the search bar
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showSearchBar = false
                                    }
                                    isSearchFieldFocused = false

                                    // Clear search and scroll back to last completed flight
                                    if !filterViewModel.filterKeywordSearch.isEmpty {
                                        filterViewModel.filterKeywordSearch = ""
                                        applyFilters()
                                        // Reset scroll flag and trigger scroll to last flight
                                        hasPerformedInitialScroll = false
                                        shouldScrollToLastFlight = true
                                    }
                                } else {
                                    // Showing the search bar
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showSearchBar = true
                                    }
                                    // Delay focus slightly to ensure the text field is rendered
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isSearchFieldFocused = true
                                    }
                                }
                            }) {
                                ZStack {
                                    Image(systemName: "magnifyingglass.circle")
                                        .font(.title3)
                                    // Show indicator when search is active
                                    if !filterViewModel.filterKeywordSearch.isEmpty {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 10, y: -10)
                                    }
                                }
                            }

                            Button(action: {
                                HapticManager.shared.impact(.light)
                                filterViewModel.sortOrderReversed.toggle()
                                applyFilters()
                                shouldScrollToTop = true
                            }) {
                                Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.title3)
                            }

                            Button(action: {
                                HapticManager.shared.impact(.light)
                                showingFilterSheet = true
                            }) {
                                ZStack {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.title3)
                                    if isFilterActive {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 10, y: -10)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    filterStartDate: $filterViewModel.filterStartDate,
                    filterEndDate: $filterViewModel.filterEndDate,
                    filterAircraftType: $filterViewModel.filterAircraftType,
                    filterAircraftReg: $filterViewModel.filterAircraftReg,
                    filterCaptainName: $filterViewModel.filterCaptainName,
                    filterFOName: $filterViewModel.filterFOName,
                    filterSOName: $filterViewModel.filterSOName,
                    filterFromAirport: $filterViewModel.filterFromAirport,
                    filterToAirport: $filterViewModel.filterToAirport,
                    filterFlightNumber: $filterViewModel.filterFlightNumber,
                    filterPilotFlyingOnly: $filterViewModel.filterPilotFlyingOnly,
                    filterApproachType: $filterViewModel.filterApproachType,
                    filterContainsRemarks: $filterViewModel.filterContainsRemarks,
                    filterSimulator: $filterViewModel.filterSimulator,
                    filterPositioning: $filterViewModel.filterPositioning,
                    filterNoBlockTime: $filterViewModel.filterNoBlockTime,
                    filterNoCrewNames: $filterViewModel.filterNoCrewNames,
                    filterNoFlightNumber: $filterViewModel.filterNoFlightNumber,
                    filterTypeSummary: $filterViewModel.filterTypeSummary,
                    filterKeywordSearch: $filterViewModel.filterKeywordSearch,
                    selectedDateRange: $filterViewModel.selectedDateRange,
                    onApply: applyFilters,
                    onClear: clearFilters
                )
            }
            .onAppear {
                // Exit editing mode when returning to flights list
                if viewModel.isEditingMode {
                    viewModel.exitEditingMode()
                }
                loadFlights()
            }
            .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
                debouncedLoadFlights()
            }
            .alert(flightToDelete.map { "Delete flight \($0.flightNumberFormatted)?" } ?? "Delete Flight?",
                   isPresented: $showingDeleteAlert,
                   presenting: flightToDelete) { flight in
                Button("Delete", role: .destructive) {
                    HapticManager.shared.notification(.warning)
                    performDelete(flight)
                }
                Button("Cancel", role: .cancel) {
                    flightToDelete = nil
                }
            }
            .alert("Delete \(selectedFlights.count) \(selectedFlights.count == 1 ? "Entry" : "Entries")?",
                   isPresented: $showingBulkDeleteAlert) {
                Button("Delete", role: .destructive) {
                    HapticManager.shared.notification(.warning)
                    performBulkDelete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $showingBulkEditSheet) {
                let flights = filteredFlightSectors.filter { selectedFlights.contains($0.id) }
                BulkEditSheet(
                    selectedFlights: flights,
                    onSave: { updatedFlights in
                        performBulkUpdate(updatedFlights)
                    }
                )
                .environmentObject(viewModel)
            }
            .sheet(item: $summaryToEdit) { summary in
                AircraftSummarySheet(
                    editingSector: summary,
                    onSave: { updatedSummary in
                        saveSummary(updatedSummary)
                    },
                    onDelete: { summaryToDelete in
                        deleteSummary(summaryToDelete)
                    }
                )
            }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func selectModeRow(for sector: FlightSector) -> some View {
        let isSelected = selectedFlights.contains(sector.id)
        let isSummary = sector.flightNumber == "SUMMARY"

        Group {
            if isSummary {
                SummaryRow(
                    sector: sector,
                    showTimesInHoursMinutes: viewModel.showTimesInHoursMinutes
                )
                .equatable()
            } else {
                FlightSectorRow(
                    sector: sector,
                    useLocalTime: viewModel.displayFlightsInLocalTime,
                    useIATACodes: viewModel.useIATACodes,
                    showTimesInHoursMinutes: viewModel.showTimesInHoursMinutes
                )
                .equatable()
            }
        }
//        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(.light)
            if isSelected {
                selectedFlights.remove(sector.id)
            } else {
                selectedFlights.insert(sector.id)
            }
        }
        .id(sector.id)
    }

    @ViewBuilder
    private func normalModeRow(for sector: FlightSector) -> some View {
        let isSummary = sector.flightNumber == "SUMMARY"

        Group {
            if isSummary {
                SummaryRow(
                    sector: sector,
                    showTimesInHoursMinutes: viewModel.showTimesInHoursMinutes
                )
                .equatable()
            } else {
                FlightSectorRow(
                    sector: sector,
                    useLocalTime: viewModel.displayFlightsInLocalTime,
                    useIATACodes: viewModel.useIATACodes,
                    showTimesInHoursMinutes: viewModel.showTimesInHoursMinutes
                )
                .equatable()
            }
        }
//        .padding(4)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(.light)
            if isSummary {
                // Show summary edit sheet
                summaryToEdit = sector
            } else {
                // Normal flight - show edit view
                selectedFlight = sector
                viewModel.loadFlightForEditing(sector)
            }
        }
        .onLongPressGesture {
            // Enter select mode and select this flight
            HapticManager.shared.impact(.medium)
            isSelectMode = true
            selectedFlights.insert(sector.id)
        }
        .id(sector.id)
    }

    private func loadFlights() {
        self.allFlightSectors = self.databaseService.fetchAllFlights()
        self.flightStatistics = self.databaseService.getFlightStatistics()
        self.applyFilters()
    }

    /// Debounced flight reload to prevent cascading reloads on rapid changes
    private func debouncedLoadFlights() {
        // Cancel any pending reload task
        reloadTask?.cancel()

        // Schedule new reload with 300ms delay
        reloadTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            await MainActor.run {
                loadFlights()
            }
        }
    }

    /// Async function for pull-to-refresh
    private func refreshFlights() async {
        HapticManager.shared.impact(.light)

        // Reload flights from database
        await MainActor.run {
            loadFlights()
        }

        // Small delay to ensure refresh animation completes smoothly
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
    }

    private func applyFilters() {
        // Pre-compute date range once
        let startDateString = dateFormatter.string(from: filterViewModel.filterStartDate)
        let endDateString = dateFormatter.string(from: filterViewModel.filterEndDate)
        let startDate = dateFormatter.date(from: startDateString)
        let endDate = dateFormatter.date(from: endDateString)

//        // Debug: Print date range in both local and UTC
//        let localFormatter = DateFormatter()
//        localFormatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
//        localFormatter.timeZone = TimeZone.current
//
//        let utcFormatter = DateFormatter()
//        utcFormatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
//        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
//
//        LogManager.shared.debug("FlightsView Filter Applied:")
//        LogManager.shared.debug("   LOCAL TZ: \(localFormatter.string(from: filterViewModel.filterStartDate)) to \(localFormatter.string(from: filterViewModel.filterEndDate))")
//        LogManager.shared.debug("   UTC:      \(utcFormatter.string(from: filterViewModel.filterStartDate)) to \(utcFormatter.string(from: filterViewModel.filterEndDate))")
//        LogManager.shared.debug("   Strings:  \(startDateString) to \(endDateString)")

        // Single pass filtering - check all conditions at once
        let filtered = allFlightSectors.filter { sector in
            // Date range filter
            if let start = startDate, let end = endDate,
               let sectorDate = dateFormatter.date(from: sector.date) {
                if sectorDate < start || sectorDate > end {
                    return false
                }

                // Exclude future flights from "Prev..." date ranges (not Custom range)
                // Future flights have no block time and no sim time, but exclude PAX flights
                if filterViewModel.selectedDateRange != .allFlights && filterViewModel.selectedDateRange != .custom {
                    if sector.blockTimeValue == 0 && sector.simTimeValue == 0 && !sector.isPositioning {
                        return false
                    }
                }
            }

            // Aircraft type filter
            if !filterViewModel.filterAircraftType.isEmpty &&
               !sector.aircraftType.localizedCaseInsensitiveContains(filterViewModel.filterAircraftType) {
                return false
            }

            // Aircraft registration filter
            if !filterViewModel.filterAircraftReg.isEmpty &&
               !sector.aircraftReg.localizedCaseInsensitiveContains(filterViewModel.filterAircraftReg) {
                return false
            }

            // Captain name filter
            if !filterViewModel.filterCaptainName.isEmpty &&
               !sector.captainName.localizedCaseInsensitiveContains(filterViewModel.filterCaptainName) {
                return false
            }

            // F/O name filter
            if !filterViewModel.filterFOName.isEmpty &&
               !sector.foName.localizedCaseInsensitiveContains(filterViewModel.filterFOName) {
                return false
            }

            // Second Officer name filter
            if !filterViewModel.filterSOName.isEmpty {
                let matchesSO1 = (sector.so1Name ?? "").localizedCaseInsensitiveContains(filterViewModel.filterSOName)
                let matchesSO2 = (sector.so2Name ?? "").localizedCaseInsensitiveContains(filterViewModel.filterSOName)
                if !matchesSO1 && !matchesSO2 {
                    return false
                }
            }

            // From airport filter
            if !filterViewModel.filterFromAirport.isEmpty &&
               !sector.fromAirport.localizedCaseInsensitiveContains(filterViewModel.filterFromAirport) {
                return false
            }

            // To airport filter
            if !filterViewModel.filterToAirport.isEmpty &&
               !sector.toAirport.localizedCaseInsensitiveContains(filterViewModel.filterToAirport) {
                return false
            }

            // Flight number filter
            if !filterViewModel.filterFlightNumber.isEmpty &&
               !sector.flightNumber.localizedCaseInsensitiveContains(filterViewModel.filterFlightNumber) {
                return false
            }

            // Pilot Flying filter
            if filterViewModel.filterPilotFlyingOnly && !sector.isPilotFlying {
                return false
            }

            // Approach type filter
            if let approachType = filterViewModel.filterApproachType {
                let matchesApproach: Bool
                switch approachType {
                case "AIII": matchesApproach = sector.isAIII
                case "RNP": matchesApproach = sector.isRNP
                case "ILS": matchesApproach = sector.isILS
                case "GLS": matchesApproach = sector.isGLS
                case "NPA": matchesApproach = sector.isNPA
                default: matchesApproach = false
                }
                if !matchesApproach {
                    return false
                }
            }

            // Contains Remarks filter
            if filterViewModel.filterContainsRemarks &&
               sector.remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }

            // Simulator filter
            if filterViewModel.filterSimulator && sector.simTimeValue <= 0 {
                return false
            }

            // Positioning filter
            if filterViewModel.filterPositioning && !sector.isPositioning {
                return false
            }

            // No Block Time filter
            if filterViewModel.filterNoBlockTime && sector.blockTimeValue != 0.0 {
                return false
            }

            // No Crew Names filter
            if filterViewModel.filterNoCrewNames {
                let captainEmpty = sector.captainName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let foEmpty = sector.foName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if !captainEmpty && !foEmpty {
                    return false
                }
            }

            // No Flight Number filter
            if filterViewModel.filterNoFlightNumber &&
               !sector.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }

            // Type Summary filter - show only SUMMARY entries
            if filterViewModel.filterTypeSummary && sector.flightNumber != "SUMMARY" {
                return false
            }

            // Keyword search filter - searches across all text fields
            if !filterViewModel.filterKeywordSearch.isEmpty {
                let keyword = filterViewModel.filterKeywordSearch
                let matchesKeyword =
                    sector.flightNumber.localizedCaseInsensitiveContains(keyword) ||
                    sector.aircraftType.localizedCaseInsensitiveContains(keyword) ||
                    sector.aircraftReg.localizedCaseInsensitiveContains(keyword) ||
                    sector.fromAirport.localizedCaseInsensitiveContains(keyword) ||
                    sector.toAirport.localizedCaseInsensitiveContains(keyword) ||
                    sector.captainName.localizedCaseInsensitiveContains(keyword) ||
                    sector.foName.localizedCaseInsensitiveContains(keyword) ||
                    (sector.so1Name ?? "").localizedCaseInsensitiveContains(keyword) ||
                    (sector.so2Name ?? "").localizedCaseInsensitiveContains(keyword) ||
                    sector.remarks.localizedCaseInsensitiveContains(keyword) ||
                    sector.date.localizedCaseInsensitiveContains(keyword)
                if !matchesKeyword {
                    return false
                }
            }

            return true
        }

        // Sort by date (newest first), then by OUT time (latest first) for same-day flights
        // Pre-compute dates once for performance using a dictionary
        let calendar = Calendar.current
        var flightDatesCache: [UUID: Date] = [:]
        for flight in filtered {
            if let date = dateFormatter.date(from: flight.date) {
                flightDatesCache[flight.id] = calendar.startOfDay(for: date)
            }
        }

        var sortedFiltered = filtered
        sortedFiltered.sort { flight1, flight2 in
            guard let day1 = flightDatesCache[flight1.id],
                  let day2 = flightDatesCache[flight2.id] else {
                return false
            }

            if day1 == day2 {
                // Same date - sort by OUT time (or STD for rostered flights) (latest first)
                // Use scheduledDeparture if outTime is empty (rostered flights)
                let time1 = flight1.outTime.isEmpty ? flight1.scheduledDeparture : flight1.outTime
                let time2 = flight2.outTime.isEmpty ? flight2.scheduledDeparture : flight2.outTime
                let result = compareOutTimes(time1, time2)
                return filterViewModel.sortOrderReversed ? !result : result
            } else {
                // Different dates - newest first (or oldest if reversed)
                return filterViewModel.sortOrderReversed ? day1 < day2 : day1 > day2
            }
        }

        filteredFlightSectors = sortedFiltered

        // Cache total hours calculation - expensive reduce operation
        cachedTotalHours = if filterViewModel.filterSimulator {
            sortedFiltered.reduce(0.0) { $0 + $1.simTimeValue }
        } else {
            // Match Dashboard logic: sum block + sim (handles Summary Rows with both fields)
            sortedFiltered.reduce(0.0) { $0 + $1.blockTimeValue + $1.simTimeValue }
        }

        // Update filter active state - includes custom date range and other filters
        let isCustomDateRange = !(filterViewModel.filterStartDate == Date.distantPast && filterViewModel.filterEndDate == Date.distantFuture)

        isFilterActive = isCustomDateRange ||
                        !filterViewModel.filterAircraftType.isEmpty ||
                        !filterViewModel.filterAircraftReg.isEmpty ||
                        !filterViewModel.filterCaptainName.isEmpty ||
                        !filterViewModel.filterFOName.isEmpty ||
                        !filterViewModel.filterSOName.isEmpty ||
                        !filterViewModel.filterFromAirport.isEmpty ||
                        !filterViewModel.filterToAirport.isEmpty ||
                        !filterViewModel.filterFlightNumber.isEmpty ||
                        filterViewModel.filterPilotFlyingOnly ||
                        filterViewModel.filterApproachType != nil ||
                        filterViewModel.filterContainsRemarks ||
                        filterViewModel.filterSimulator ||
                        filterViewModel.filterPositioning ||
                        filterViewModel.filterNoBlockTime ||
                        filterViewModel.filterNoCrewNames ||
                        filterViewModel.filterNoFlightNumber ||
                        filterViewModel.filterTypeSummary

        showingFilterSheet = false

        // Scroll to top when filters are active
        if isFilterActive {
            shouldScrollToTop = true
        }
    }

    private func compareOutTimes(_ time1: String, _ time2: String) -> Bool {
        // Parse time format - handles both "HHMM" and "HH:MM"
        func parseTime(_ time: String) -> Int? {
            // Return nil for empty strings
            guard !time.isEmpty else { return nil }

            let cleaned = time.replacingOccurrences(of: ":", with: "")

            // Handle HHMM format (4 digits) or HMM format (3 digits)
            if cleaned.count == 4, let timeInt = Int(cleaned) {
                let hours = timeInt / 100
                let minutes = timeInt % 100
                return hours * 60 + minutes
            } else if cleaned.count == 3, let timeInt = Int(cleaned) {
                // Handle 3-digit format like "326" (3:26)
                let hours = timeInt / 100
                let minutes = timeInt % 100
                return hours * 60 + minutes
            }
            return nil
        }

        guard let minutes1 = parseTime(time1),
              let minutes2 = parseTime(time2) else {
            return false
        }

        return minutes1 > minutes2
    }

    private func clearFilters() {
        filterViewModel.clearFilters()
        applyFilters()
        // Reset scroll flag and trigger scroll to last flight after clearing filters
        hasPerformedInitialScroll = false
        shouldScrollToLastFlight = true
    }

    private func deleteFlight(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        HapticManager.shared.impact(.medium)
        flightToDelete = filteredFlightSectors[index]
        showingDeleteAlert = true
    }

    private func performDelete(_ flight: FlightSector) {
        if databaseService.deleteFlight(flight) {
            // Remove from both lists
            filteredFlightSectors.removeAll { $0.id == flight.id }
            allFlightSectors.removeAll { $0.id == flight.id }

            // Database service observers will automatically post .flightDataChanged notification
        } else {
            HapticManager.shared.notification(.error)
        }
        flightToDelete = nil
    }

    private func deleteFlightSector(_ sector: FlightSector) {
        if databaseService.deleteFlight(sector) {
            // Remove deleted sector immediately from the local list
            allFlightSectors.removeAll { $0.id == sector.id }
            loadFlights()
            hasLoadedFlights = true
        }
    }

    private func updateFlightSector(_ updated: FlightSector) {
        if let index = allFlightSectors.firstIndex(where: { $0.id == updated.id }) {
            allFlightSectors[index] = updated
        } else {
            // Fallback: reload if the sector isn't in the current list
            loadFlights()
        }
    }

    private func performBulkDelete() {
        // Get the flight sectors to delete
        let flightsToDelete = filteredFlightSectors.filter { selectedFlights.contains($0.id) }

        guard !flightsToDelete.isEmpty else { return }

        // Temporarily disable CloudKit sync for cleaner bulk operation
        // This reduces console noise and improves performance
        let cloudKitWasEnabled = databaseService.disableCloudKitSync()

        // Delete from database
        if databaseService.deleteFlights(flightsToDelete) {
            // Re-enable CloudKit sync if it was enabled
            if cloudKitWasEnabled {
                databaseService.enableCloudKitSync()
            }

            // Remove from both lists
            filteredFlightSectors.removeAll { selectedFlights.contains($0.id) }
            allFlightSectors.removeAll { selectedFlights.contains($0.id) }

            // Clear selection and exit select mode
            selectedFlights.removeAll()
            isSelectMode = false

            // Database service observers will automatically post .flightDataChanged notification
        } else {
            // Re-enable CloudKit sync even on error
            if cloudKitWasEnabled {
                databaseService.enableCloudKitSync()
            }
            HapticManager.shared.notification(.error)
        }
    }

    private func performBulkUpdate(_ updates: [UUID: FlightSector]) {
        guard !updates.isEmpty else { return }

        // Temporarily disable CloudKit sync for cleaner bulk operation
        let cloudKitWasEnabled = databaseService.disableCloudKitSync()

        if databaseService.updateFlightsBulk(updates) {
            // Re-enable CloudKit sync if it was enabled
            if cloudKitWasEnabled {
                databaseService.enableCloudKitSync()
            }

            // Update local state
            for (id, updatedFlight) in updates {
                if let index = filteredFlightSectors.firstIndex(where: { $0.id == id }) {
                    filteredFlightSectors[index] = updatedFlight
                }
                if let index = allFlightSectors.firstIndex(where: { $0.id == id }) {
                    allFlightSectors[index] = updatedFlight
                }
            }

            // Clear selection and exit select mode
            selectedFlights.removeAll()
            isSelectMode = false

            // Success haptic
            HapticManager.shared.notification(.success)

            // Reload to ensure consistency
            loadFlights()

        } else {
            // Re-enable CloudKit sync even on error
            if cloudKitWasEnabled {
                databaseService.enableCloudKitSync()
            }
            HapticManager.shared.notification(.error)
        }
    }

    private func saveSummary(_ summary: FlightSector) {
        // Check if this is an update or new entry
        let isUpdate = allFlightSectors.contains { $0.id == summary.id }

        if isUpdate {
            // Update existing summary
            if databaseService.updateFlight(summary) {
                // Update local state
                if let index = filteredFlightSectors.firstIndex(where: { $0.id == summary.id }) {
                    filteredFlightSectors[index] = summary
                }
                if let index = allFlightSectors.firstIndex(where: { $0.id == summary.id }) {
                    allFlightSectors[index] = summary
                }
                // Notify other views
                NotificationCenter.default.post(name: .flightDataChanged, object: nil)
            } else {
                HapticManager.shared.notification(.error)
            }
        } else {
            // Save new summary
            if databaseService.saveFlight(summary) {
                loadFlights()
                NotificationCenter.default.post(name: .flightDataChanged, object: nil)
            } else {
                HapticManager.shared.notification(.error)
            }
        }

        // Clear the editing state
        summaryToEdit = nil
    }

    private func deleteSummary(_ summary: FlightSector) {
        if databaseService.deleteFlight(summary) {
            // Remove from local state
            filteredFlightSectors.removeAll { $0.id == summary.id }
            allFlightSectors.removeAll { $0.id == summary.id }
            // Notify other views
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        } else {
            HapticManager.shared.notification(.error)
        }

        // Clear the editing state
        summaryToEdit = nil
    }

    /// Check if only keyword search is active (no other filters)
    private func isOnlyKeywordSearchActive() -> Bool {
        let isCustomDateRange = !(filterViewModel.filterStartDate == Date.distantPast && filterViewModel.filterEndDate == Date.distantFuture)

        return !filterViewModel.filterKeywordSearch.isEmpty &&
               !isCustomDateRange &&
               filterViewModel.filterAircraftType.isEmpty &&
               filterViewModel.filterAircraftReg.isEmpty &&
               filterViewModel.filterCaptainName.isEmpty &&
               filterViewModel.filterFOName.isEmpty &&
               filterViewModel.filterSOName.isEmpty &&
               filterViewModel.filterFromAirport.isEmpty &&
               filterViewModel.filterToAirport.isEmpty &&
               filterViewModel.filterFlightNumber.isEmpty &&
               !filterViewModel.filterPilotFlyingOnly &&
               filterViewModel.filterApproachType == nil &&
               !filterViewModel.filterContainsRemarks &&
               !filterViewModel.filterSimulator &&
               !filterViewModel.filterPositioning &&
               !filterViewModel.filterNoBlockTime &&
               !filterViewModel.filterNoCrewNames &&
               !filterViewModel.filterNoFlightNumber &&
               !filterViewModel.filterTypeSummary
    }

    private func scrollToFirstNonDimmedFlight(proxy: ScrollViewProxy) {
        // Only scroll once per view lifecycle to avoid disrupting user scrolling
        guard !hasPerformedInitialScroll else { return }

        // Don't scroll if we're in select mode
        guard !isSelectMode else { return }

        // Find the FIRST completed flight (first one WITH block/sim time)
        // This is the transition point between future and completed flights
        // Note: PAX flights without logged time are still future flights
        var firstCompletedIndex: Int?
        for (index, sector) in filteredFlightSectors.enumerated() {
            // A flight is considered completed if it has actual logged time
            if sector.blockTimeValue > 0 || sector.simTimeValue > 0 {
                firstCompletedIndex = index
                break
            }
        }

        // If we found a completed flight, scroll to it
        if let completedIndex = firstCompletedIndex {
            let targetFlight = filteredFlightSectors[completedIndex]

            // Scroll to the target flight
            // Use delay to ensure LazyVStack has rendered items
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(targetFlight.id, anchor: .center)
                }
                self.hasPerformedInitialScroll = true
            }
        } else {
            hasPerformedInitialScroll = true
        }
    }
}

// MARK: - Empty State View
private struct EmptyFlightsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Flights Recorded")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Capture your first ACARS photo to start building your logbook or Import from Settings")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - No Results View
private struct NoResultsView: View {
    let onClearFilters: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Flights Match Filters")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Try adjusting your filter criteria")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                HapticManager.shared.impact(.medium)
                onClearFilters()
            }) {
                Text("Clear All Filters")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Sheet
// Made internal so it can be used by FlightsSplitView
struct FilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @Binding var filterStartDate: Date
    @Binding var filterEndDate: Date
    @Binding var filterAircraftType: String
    @Binding var filterAircraftReg: String
    @Binding var filterCaptainName: String
    @Binding var filterFOName: String
    @Binding var filterSOName: String
    @Binding var filterFromAirport: String
    @Binding var filterToAirport: String
    @Binding var filterFlightNumber: String
    @Binding var filterPilotFlyingOnly: Bool
    @Binding var filterApproachType: String?
    @Binding var filterContainsRemarks: Bool
    @Binding var filterSimulator: Bool
    @Binding var filterPositioning: Bool
    @Binding var filterNoBlockTime: Bool
    @Binding var filterNoCrewNames: Bool
    @Binding var filterNoFlightNumber: Bool
    @Binding var filterTypeSummary: Bool
    @Binding var filterKeywordSearch: String
    @Binding var selectedDateRange: FlightsView.DateRangeOption
    let onApply: () -> Void
    let onClear: () -> Void

    @State private var availableAircraftTypes: [String] = []
    @State private var availableAircraftRegs: [String] = []
    @State private var availableCaptainNames: [String] = []
    @State private var availableFONames: [String] = []
    @State private var availableSONames: [String] = []
    @State private var availableFlightNumbers: [String] = []
    @State private var availableFromAirports: [String] = []
    @State private var availableToAirports: [String] = []
    @State private var showCustomDatePicker = false
    @State private var showingCaptainPicker = false
    @State private var showingFOPicker = false
    @State private var showingSOPicker = false
    @State private var showingFlightNumberPicker = false
    @State private var showingFromAirportPicker = false
    @State private var showingToAirportPicker = false
    private let databaseService = FlightDatabaseService.shared

    // Cache filter data to avoid repeated database scans
    @State private var filterDataCache: FilterDataCache?
    @State private var filterCacheTimestamp: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            DateRangeButton(
                                title: "All Flights",
                                isSelected: selectedDateRange == .allFlights && !showCustomDatePicker
                            ) {
                                filterStartDate = Date.distantPast
                                filterEndDate = Date.distantFuture
                                showCustomDatePicker = false
                                selectedDateRange = .allFlights
                            }

                            DateRangeButton(
                                title: "Prev 12 Mths",
                                isSelected: selectedDateRange == .twelveMonths && !showCustomDatePicker
                            ) {
                                let calendar = Calendar.current
                                let now = Date()
                                // Include all of today back to 12 months ago
                                filterStartDate = calendar.date(byAdding: .month, value: -12, to: calendar.startOfDay(for: now)) ?? Date()
                                filterEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? Date()
                                showCustomDatePicker = false
                                selectedDateRange = .twelveMonths
                            }
                        }

                        HStack(spacing: 8) {
                            DateRangeButton(
                                title: "Prev 6 Mths",
                                isSelected: selectedDateRange == .sixMonths && !showCustomDatePicker
                            ) {
                                let calendar = Calendar.current
                                let now = Date()
                                // Include all of today back to 6 months ago
                                filterStartDate = calendar.date(byAdding: .month, value: -6, to: calendar.startOfDay(for: now)) ?? Date()
                                filterEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? Date()
                                showCustomDatePicker = false
                                selectedDateRange = .sixMonths
                            }

                            DateRangeButton(
                                title: "Prev 28 Days",
                                isSelected: selectedDateRange == .twentyEightDays && !showCustomDatePicker
                            ) {
                                let calendar = Calendar.current
                                let now = Date()
                                // Include all of today back to 27 days ago (28 days total including today)
                                filterStartDate = calendar.date(byAdding: .day, value: -27, to: calendar.startOfDay(for: now)) ?? Date()
                                filterEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? Date()
                                showCustomDatePicker = false
                                selectedDateRange = .twentyEightDays
                            }
                        }

                        DateRangeButton(
                            title: "Custom Date Range",
                            isSelected: showCustomDatePicker,
                            icon: showCustomDatePicker ? "chevron.up" : "chevron.down"
                        ) {
                            // Set to current date when opening custom date picker
                            if !showCustomDatePicker {
                                filterStartDate = Date()
                                filterEndDate = Date()
                            }
                            showCustomDatePicker.toggle()
                            selectedDateRange = .custom
                        }

                        if showCustomDatePicker {
                            VStack(spacing: 12) {
                                Divider()
                                DatePicker("Start Date", selection: $filterStartDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                DatePicker("End Date", selection: $filterEndDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Date Range")
                }

                Section(header: Text("Aircraft")) {
                    Picker("Type", selection: $filterAircraftType) {
                        Text("All Types").tag("")
                        ForEach(availableAircraftTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    Picker("Registration", selection: $filterAircraftReg) {
                        Text("All Registrations").tag("")
                        ForEach(availableAircraftRegs, id: \.self) { reg in
                            Text(reg).tag(reg)
                        }
                    }
                }

                Section(header: Text("Crew")) {
                    Button(action: {
                        showingCaptainPicker = true
                    }) {
                        HStack {
                            Text("Captain")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(filterCaptainName.isEmpty ? "Any" : filterCaptainName)
                                .foregroundColor(filterCaptainName.isEmpty ? .secondary : .blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: {
                        showingFOPicker = true
                    }) {
                        HStack {
                            Text("F/O")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(filterFOName.isEmpty ? "Any" : filterFOName)
                                .foregroundColor(filterFOName.isEmpty ? .secondary : .blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: {
                        showingSOPicker = true
                    }) {
                        HStack {
                            Text("S/O")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(filterSOName.isEmpty ? "Any" : filterSOName)
                                .foregroundColor(filterSOName.isEmpty ? .secondary : .blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Flight Details")) {
                    Button(action: {
                        showingFlightNumberPicker = true
                    }) {
                        HStack {
                            Text("Flight Number")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(filterFlightNumber.isEmpty ? "Any" : filterFlightNumber)
                                .foregroundColor(filterFlightNumber.isEmpty ? .secondary : .blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: {
                        showingFromAirportPicker = true
                    }) {
                        HStack {
                            Text("From")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(filterFromAirport.isEmpty ? "Any" : filterFromAirport)
                                .foregroundColor(filterFromAirport.isEmpty ? .secondary : .blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: {
                        showingToAirportPicker = true
                    }) {
                        HStack {
                            Text("To")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(filterToAirport.isEmpty ? "Any" : filterToAirport)
                                .foregroundColor(filterToAirport.isEmpty ? .secondary : .blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                

                Section(header: Text("Operations")) {
                    Toggle("Pilot Flying", isOn: $filterPilotFlyingOnly)

                    HStack {
                        Text("Approach")
                        Spacer()
                        Picker("", selection: $filterApproachType) {
                            Text("Any").tag(nil as String?)
                            Text("GLS").tag("GLS" as String?)
                            Text("ILS").tag("ILS" as String?)
                            Text("RNP").tag("RNP" as String?)
                            Text("AIII").tag("AIII" as String?)
                            Text("NPA").tag("NPA" as String?)
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle("Contains Remarks", isOn: $filterContainsRemarks)

                    Toggle("Simulator", isOn: $filterSimulator)

                    Toggle("PAX", isOn: $filterPositioning)

                    Toggle("Type Summary", isOn: $filterTypeSummary)
                }
                
                Section(header: Text("Missing Data")) {
                    Toggle("No Block Time", isOn: $filterNoBlockTime)
                    Toggle("No Crew Names", isOn: $filterNoCrewNames)
                    Toggle("No Flight Number", isOn: $filterNoFlightNumber)
                }
                
                
            }
            .navigationTitle("Filter Flights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        HapticManager.shared.impact(.medium)
                        onClear()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        HapticManager.shared.impact(.light)
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadAllFilterData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
                // Invalidate cache when flight data changes (e.g., new summary added)
                filterCacheTimestamp = nil
                loadAllFilterData()
            }
            .sheet(isPresented: $showingCaptainPicker) {
                FilterCrewPickerSheet(
                    title: "Captain",
                    selectedName: $filterCaptainName,
                    availableNames: availableCaptainNames,
                    onDismiss: { showingCaptainPicker = false }
                )
            }
            .sheet(isPresented: $showingFOPicker) {
                FilterCrewPickerSheet(
                    title: "First Officer",
                    selectedName: $filterFOName,
                    availableNames: availableFONames,
                    onDismiss: { showingFOPicker = false }
                )
            }
            .sheet(isPresented: $showingSOPicker) {
                FilterCrewPickerSheet(
                    title: "Second Officer",
                    selectedName: $filterSOName,
                    availableNames: availableSONames,
                    onDismiss: { showingSOPicker = false }
                )
            }
            .sheet(isPresented: $showingFlightNumberPicker) {
                FilterTextPickerSheet(
                    title: "Flight Numbers",
                    selectedValue: $filterFlightNumber,
                    availableValues: availableFlightNumbers,
                    placeholder: "Search flight number...",
                    onDismiss: { showingFlightNumberPicker = false }
                )
            }
            .sheet(isPresented: $showingFromAirportPicker) {
                FilterAirportPickerSheet(
                    title: "From Airport",
                    selectedAirport: $filterFromAirport,
                    availableAirports: availableFromAirports,
                    useIATACodes: viewModel.useIATACodes,
                    onDismiss: { showingFromAirportPicker = false }
                )
            }
            .sheet(isPresented: $showingToAirportPicker) {
                FilterAirportPickerSheet(
                    title: "To Airport",
                    selectedAirport: $filterToAirport,
                    availableAirports: availableToAirports,
                    useIATACodes: viewModel.useIATACodes,
                    onDismiss: { showingToAirportPicker = false }
                )
            }
        }
    }

    /// Load all filter data with caching (5 minute cache)
    private func loadAllFilterData() {
        // Check if cache is still valid (less than 5 minutes old)
        if let cache = filterDataCache,
           let timestamp = filterCacheTimestamp,
           Date().timeIntervalSince(timestamp) < 300 { // 5 minutes
            // Use cached data
            availableAircraftTypes = cache.aircraftTypes
            availableAircraftRegs = cache.aircraftRegs
            availableCaptainNames = cache.captainNames
            availableFONames = cache.foNames
            availableSONames = cache.soNames
            availableFlightNumbers = cache.flightNumbers
            availableFromAirports = cache.fromAirports
            availableToAirports = cache.toAirports
            return
        }

        // Cache expired or doesn't exist - load fresh data
        let cache = FilterDataCache(
            aircraftTypes: databaseService.getAllAircraftTypes(),
            aircraftRegs: databaseService.getAllAircraftRegistrations(),
            captainNames: databaseService.getAllCaptainNames(),
            foNames: databaseService.getAllFONames(),
            soNames: databaseService.getAllSONames(),
            flightNumbers: databaseService.getAllFlightNumbers(),
            fromAirports: databaseService.getAllFromAirports(),
            toAirports: databaseService.getAllToAirports()
        )

        // Update state with fresh data
        availableAircraftTypes = cache.aircraftTypes
        availableAircraftRegs = cache.aircraftRegs
        availableCaptainNames = cache.captainNames
        availableFONames = cache.foNames
        availableSONames = cache.soNames
        availableFlightNumbers = cache.flightNumbers
        availableFromAirports = cache.fromAirports
        availableToAirports = cache.toAirports

        // Store cache
        filterDataCache = cache
        filterCacheTimestamp = Date()
    }
}

// MARK: - Filter Data Cache
private struct FilterDataCache {
    let aircraftTypes: [String]
    let aircraftRegs: [String]
    let captainNames: [String]
    let foNames: [String]
    let soNames: [String]
    let flightNumbers: [String]
    let fromAirports: [String]
    let toAirports: [String]
}

// MARK: - Date Range Button Component
// Made internal so it can be used by FilterSheet
struct DateRangeButton: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if let icon = icon {
                    Spacer()
                    Image(systemName: icon)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isSelected ? Color.green.opacity(0.15) : Color(.systemGray6))
            .foregroundColor(isSelected ? .green : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
