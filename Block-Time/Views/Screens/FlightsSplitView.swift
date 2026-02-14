//
//  FlightsSplitView.swift
//  Block-Time
//
//  Created for iPad split-view experience
//  Displays FlightsView on the left, flight details on the right
//

import SwiftUI

struct FlightsSplitView: View {
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject var filterViewModel: FlightsFilterViewModel
    @State private var selectedFlight: FlightSector?
    @State private var isAddingNewFlight: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var isSelectMode: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshTrigger = UUID()

    // Determine if we should use split view based on device and size class
    private var shouldUseSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        if shouldUseSplitView {
            // iPad landscape: Split view
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Left pane: Flights list
                FlightsListContent(
                    filterViewModel: filterViewModel,
                    selectedFlight: $selectedFlight,
                    isAddingNewFlight: $isAddingNewFlight,
                    isSelectMode: $isSelectMode,
                    refreshTrigger: refreshTrigger,
                    onFlightSelected: { flight in
//                                LogManager.shared.debug("onFlightSelected callback: \(flight.flightNumberFormatted)")
                        isAddingNewFlight = false
                        viewModel.loadFlightForEditing(flight)
                    }
                )
                .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 600)
            } detail: {
                // Right pane: Flight detail, add new flight, or empty state
                NavigationStack {
                    if isAddingNewFlight {
                        // Show full AddFlightView with ACARS capture
                        AddFlightView()
                            .environmentObject(viewModel)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Cancel") {
                                        isAddingNewFlight = false
                                        viewModel.resetAllFields()
                                    }
                                }
                            }
                            .onAppear {
                                        LogManager.shared.info("Add new flight mode")
                                viewModel.exitEditingMode() // Ensure we're not in edit mode
                            }
                    } else if let flight = selectedFlight {
                        // Show AddFlightView in edit mode (without ACARS capture)
                        AddFlightView()
                            .environmentObject(viewModel)
                            .id(flight.id) // Force view refresh when flight changes
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button {
                                        selectedFlight = nil
                                        viewModel.exitEditingMode()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .onAppear {
//                                        LogManager.shared.debug("Detail view appeared for flight: \(flight.flightNumberFormatted)")
//                                        LogManager.shared.debug("isEditingMode: \(viewModel.isEditingMode)")
                            }
                    } else {
                        // Show empty state with + button
                        EmptyDetailView(
                            isSelectMode: isSelectMode,
                            onAddFlight: {
                                isAddingNewFlight = true
                            }
                        )
                        .onAppear {
//                                    LogManager.shared.debug("Empty detail view showing - selectedFlight is nil")
                        }
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Force sidebar to show when app becomes active
                if newPhase == .active && shouldUseSplitView {
                    columnVisibility = .doubleColumn
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
                LogManager.shared.debug("FlightsSplitView: Received .flightDataChanged notification")
                refreshTrigger = UUID()
            }
        } else {
            // iPhone or iPad portrait: Standard navigation stack
            NavigationStack {
                FlightsView(filterViewModel: filterViewModel)
                    .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Flights List Content (Extracted for reuse)
private struct FlightsListContent: View {
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject var filterViewModel: FlightsFilterViewModel
    @Binding var selectedFlight: FlightSector?
    @Binding var isAddingNewFlight: Bool
    @Binding var isSelectMode: Bool
    let refreshTrigger: UUID
    let onFlightSelected: (FlightSector) -> Void

    private let databaseService = FlightDatabaseService.shared
    @State private var allFlightSectors: [FlightSector] = []
    @State private var filteredFlightSectors: [FlightSector] = []
    @State private var showingFilterSheet = false
    @State private var isFilterActive: Bool = false
    @State private var flightToDelete: FlightSector?
    @State private var showingDeleteAlert = false
    @State private var selectedFlightsForDeletion: Set<UUID> = []
    @State private var showingBulkDeleteAlert = false
    @State private var showingBulkEditSheet = false
    @State private var summaryToEdit: FlightSector?
    @State private var cachedTotalHours: Double = 0.0
    @State private var hasPerformedInitialScroll: Bool = false
    @State private var shouldScrollToLastFlight: Bool = false
    @State private var shouldScrollToTop: Bool = false
    @State private var showSearchBar: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    // Cached date formatter for performance
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    // Device-dependent corner radius for action buttons
    private var actionButtonCornerRadius: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 10 : 25
    }

    // Device-dependent vertical padding for action buttons
    private var actionButtonVerticalPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 10 : 14
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
                                // Reset scroll flag and trigger scroll to last flight
                                hasPerformedInitialScroll = false
                                shouldScrollToLastFlight = true
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
                        LazyVStack(spacing: 4) {
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
                            Text("Edit \(selectedFlightsForDeletion.count)")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, actionButtonVerticalPadding)
                        .background(selectedFlightsForDeletion.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                        .cornerRadius(actionButtonCornerRadius)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(selectedFlightsForDeletion.isEmpty)

                    // Delete button
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        showingBulkDeleteAlert = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.body)
                            Text("Delete \(selectedFlightsForDeletion.count)")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, actionButtonVerticalPadding)
                        .background(selectedFlightsForDeletion.isEmpty ? Color.red.opacity(0.5) : Color.red)
                        .cornerRadius(actionButtonCornerRadius)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(selectedFlightsForDeletion.isEmpty)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelectMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedFlightsForDeletion.count)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 16) {
                    // Add new flight button - hide in select mode
                    if !isSelectMode {
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            selectedFlight = nil
                            isAddingNewFlight = true
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                        }
                    }

                    if !filteredFlightSectors.isEmpty {
                        // Select/Cancel button
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            isSelectMode.toggle()
                            if !isSelectMode {
                                selectedFlightsForDeletion.removeAll()
                            } else {
                                // When entering select mode, include the currently selected flight
                                if let selectedId = selectedFlight?.id {
                                    selectedFlightsForDeletion.insert(selectedId)
                                }
                                // Clear the detail pane to show empty state
                                selectedFlight = nil
                            }
                        }) {
                            Text(isSelectMode ? "Cancel" : "Select")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.primary, lineWidth: 1.5)
                                )
                        }
                    }
                }
            }

            if isSelectMode {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Show Select All / Deselect All button in select mode
                    if !filteredFlightSectors.isEmpty {
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            let allFilteredIds = Set(filteredFlightSectors.map { $0.id })
                            if selectedFlightsForDeletion == allFilteredIds {
                                // All selected, so deselect all
                                selectedFlightsForDeletion.removeAll()
                            } else {
                                // Select all filtered flights
                                selectedFlightsForDeletion = allFilteredIds
                            }
                        }) {
                            let allSelected = selectedFlightsForDeletion == Set(filteredFlightSectors.map { $0.id })
                            Text(allSelected ? "Deselect All" : "Select All")
                                .foregroundColor(.blue)
                        }
                    }
                }
            } else {
                // Show search, sort and filter buttons in normal mode
                ToolbarItem(placement: .navigationBarTrailing) {
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
                        Label {
                            Text("Search")
                        } icon: {
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
                    }
                    .labelStyle(.iconOnly)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        filterViewModel.sortOrderReversed.toggle()
                        applyFilters()
                        shouldScrollToTop = true
                    }) {
                        Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                            .font(.title3)
                    }
                    .labelStyle(.iconOnly)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showingFilterSheet = true
                    }) {
                        Label {
                            Text("Filter")
                        } icon: {
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
                    .labelStyle(.iconOnly)
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
            if viewModel.isEditingMode {
                viewModel.exitEditingMode()
            }
            loadFlights()
        }
        .onChange(of: refreshTrigger) { _, _ in
            // Store the currently selected flight ID
            let selectedFlightId = selectedFlight?.id

            // Reload all flights from database
            loadFlights()

            // Update the selected flight with fresh data from the reloaded list
            if let selectedId = selectedFlightId {
                // Find the updated flight in the newly filtered list
                if let updatedFlight = filteredFlightSectors.first(where: { $0.id == selectedId }) {
                    selectedFlight = updatedFlight
                } else {
                    selectedFlight = nil
                }
            }
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
        .alert("Delete \(selectedFlightsForDeletion.count) \(selectedFlightsForDeletion.count == 1 ? "Entry" : "Entries")?",
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
            let flights = filteredFlightSectors.filter { selectedFlightsForDeletion.contains($0.id) }
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
        let isSelected = selectedFlightsForDeletion.contains(sector.id)
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
                    showTimesInHoursMinutes: viewModel.showTimesInHoursMinutes,
                    includeAirlinePrefixInFlightNumber: viewModel.includeAirlinePrefixInFlightNumber,
                    isCustomAirlinePrefix: viewModel.isCustomAirlinePrefix
                )
                .equatable()
            }
        }
        .padding(4)
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
                selectedFlightsForDeletion.remove(sector.id)
            } else {
                selectedFlightsForDeletion.insert(sector.id)
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
                    showTimesInHoursMinutes: viewModel.showTimesInHoursMinutes,
                    includeAirlinePrefixInFlightNumber: viewModel.includeAirlinePrefixInFlightNumber,
                    isCustomAirlinePrefix: viewModel.isCustomAirlinePrefix
                )
                .equatable()
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedFlight?.id == sector.id ? Color.blue.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedFlight?.id == sector.id ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(.light)
            if isSummary {
                // Show summary edit sheet instead of detail pane
                summaryToEdit = sector
            } else {
                // Normal flight - show in detail pane
//                LogManager.shared.debug("Flight tapped: \(sector.flightNumberFormatted)")
                selectedFlight = sector
                onFlightSelected(sector)
            }
        }
        .onLongPressGesture {
            // Enter select mode and select this flight
            HapticManager.shared.impact(.medium)
            isSelectMode = true
            selectedFlightsForDeletion.insert(sector.id)
        }
        .id(sector.id)
    }

    private func loadFlights() {
//        LogManager.shared.debug("FlightsSplitView: loadFlights() called")
        self.allFlightSectors = self.databaseService.fetchAllFlights()
        LogManager.shared.debug("FlightsSplitView: Loaded \(self.allFlightSectors.count) flights from database")
        self.applyFilters()
//        LogManager.shared.debug("FlightsSplitView: After filtering: \(self.filteredFlightSectors.count) flights")
    }

    private func refreshFlights() async {
        HapticManager.shared.impact(.light)

        await MainActor.run {
            loadFlights()
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    private func applyFilters() {
        // OPTIMIZED: Single-pass filtering instead of multiple separate filter operations
        // This reduces iterations from 50,000+ (2633 flights × 19+ filters) to just 2,633

        let startDateString = dateFormatter.string(from: filterViewModel.filterStartDate)
        let endDateString = dateFormatter.string(from: filterViewModel.filterEndDate)
        let startDate = dateFormatter.date(from: startDateString)
        let endDate = dateFormatter.date(from: endDateString)

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
                let matches = switch approachType {
                case "AIII": sector.isAIII
                case "RNP": sector.isRNP
                case "ILS": sector.isILS
                case "GLS": sector.isGLS
                case "NPA": sector.isNPA
                default: false
                }
                if !matches {
                    return false
                }
            }

            // Contains Remarks filter
            if filterViewModel.filterContainsRemarks &&
               sector.remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }

            // Simulator filter
            if filterViewModel.filterSimulator && sector.simTimeValue == 0 {
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

        // Sort by date
        let calendar = Calendar.current
        var flightDatesCache: [UUID: Date] = [:]
        var sorted = filtered
        for flight in sorted {
            if let date = dateFormatter.date(from: flight.date) {
                flightDatesCache[flight.id] = calendar.startOfDay(for: date)
            }
        }

        sorted.sort { flight1, flight2 in
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
                return filterViewModel.sortOrderReversed ? day1 < day2 : day1 > day2
            }
        }

        filteredFlightSectors = sorted

        // Cache total hours calculation
        cachedTotalHours = if filterViewModel.filterSimulator {
            sorted.reduce(0.0) { $0 + $1.simTimeValue }
        } else {
            // Match Dashboard logic: sum block + sim (handles Summary Rows with both fields)
            sorted.reduce(0.0) { $0 + $1.blockTimeValue + $1.simTimeValue }
        }

        // Update filter active state
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
            filteredFlightSectors.removeAll { $0.id == flight.id }
            allFlightSectors.removeAll { $0.id == flight.id }

            // Clear selection if deleted flight was selected
            if selectedFlight?.id == flight.id {
                selectedFlight = nil
            }

            // Database service observers will automatically post .flightDataChanged notification
        } else {
            HapticManager.shared.notification(.error)
        }
        flightToDelete = nil
    }

    private func performBulkDelete() {
        // Get the flight sectors to delete
        let flightsToDelete = filteredFlightSectors.filter { selectedFlightsForDeletion.contains($0.id) }

        guard !flightsToDelete.isEmpty else { return }

        // Temporarily disable CloudKit sync for cleaner bulk operation
        let cloudKitWasEnabled = databaseService.disableCloudKitSync()

        // Delete from database
        if databaseService.deleteFlights(flightsToDelete) {
            // Re-enable CloudKit sync if it was enabled
            if cloudKitWasEnabled {
                databaseService.enableCloudKitSync()
            }

            // Remove from both lists
            filteredFlightSectors.removeAll { selectedFlightsForDeletion.contains($0.id) }
            allFlightSectors.removeAll { selectedFlightsForDeletion.contains($0.id) }

            // Clear selection if any deleted flight was selected
            if let currentSelection = selectedFlight?.id, selectedFlightsForDeletion.contains(currentSelection) {
                selectedFlight = nil
            }

            // Clear selection and exit select mode
            selectedFlightsForDeletion.removeAll()
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

                // Update selectedFlight if it was edited
                if selectedFlight?.id == id {
                    selectedFlight = updatedFlight
                }
            }

            // Clear selection and exit select mode
            selectedFlightsForDeletion.removeAll()
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
                hasPerformedInitialScroll = true
            }
        } else {
            hasPerformedInitialScroll = true
        }
    }
}

// MARK: - Empty Detail View
private struct EmptyDetailView: View {
    @ObservedObject private var themeService = ThemeService.shared
    let isSelectMode: Bool
    let onAddFlight: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            Text("Select a Flight")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Tap a flight from the list to view or edit details")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Only show "or" and Add button when not in select mode
            if !isSelectMode {
                Text("or")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Add new flight button
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    onAddFlight()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Add New Flight")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            themeService.getGradient()
                .ignoresSafeArea()
        )
    }
}

// MARK: - Empty Flights View
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
