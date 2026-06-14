//
//  FlightsSplitView.swift
//  Block-Time
//
//  Created for iPad split-view experience
//  Displays FlightsView on the left, flight details on the right
//

import SwiftUI
import CoreData
import BlockTimeKit

struct FlightsSplitView: View {
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject var filterViewModel: FlightsFilterViewModel
    @State private var selectedFlight: FlightSector?
    @State private var isAddingNewFlight: Bool = false
    @State private var showingPaywall = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var isSelectMode: Bool = false
    @State private var showingDiscardAlert: Bool = false
    @State private var pendingFlightSelection: FlightSector?
    @State private var showingSaveFailedAlert: Bool = false
    @State private var listRefreshTrigger: UUID = UUID()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PurchaseService.self) private var purchaseService

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
                    refreshTrigger: $listRefreshTrigger,
                    onFlightSelected: { flight in
                        if viewModel.hasUnsavedChanges {
                            pendingFlightSelection = flight
                            showingDiscardAlert = true
                        } else {
                            isAddingNewFlight = false
                            viewModel.loadFlightForEditing(flight)
                        }
                    }
                )
                .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 600)
            } detail: {
                // Right pane: Flight detail, add new flight, or empty state
                NavigationStack {
                    if isAddingNewFlight {
                        // Show full AddFlightView with ACARS capture
                        AddFlightView(onNextSector: {
                            // VM already pre-populated by nextSector() — force view refresh
                            isAddingNewFlight = false
                            Task { @MainActor in isAddingNewFlight = true }
                        })
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
                        AddFlightView(onNextSectorFromEdit: {
                            // VM pre-populated by nextSectorFromEdit() — switch to add screen
                            selectedFlight = nil
                            Task { @MainActor in isAddingNewFlight = true }
                        })
                            .environmentObject(viewModel)
                            .id(flight.id) // Force view refresh when flight changes
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button {
                                        if viewModel.hasUnsavedChanges {
                                            showingDiscardAlert = true
                                        } else {
                                            selectedFlight = nil
                                            viewModel.exitEditingMode()
                                        }
                                    } label: {
                                        Text("Done")
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .alert("Save Changes?", isPresented: $showingDiscardAlert) {
                                Button("Save") {
                                    if viewModel.updateExistingFlight() {
                                        if let pending = pendingFlightSelection {
                                            selectedFlight = pending
                                            isAddingNewFlight = false
                                            viewModel.loadFlightForEditing(pending)
                                            pendingFlightSelection = nil
                                        } else {
                                            selectedFlight = nil
                                            viewModel.exitEditingMode()
                                        }
                                        listRefreshTrigger = UUID()
                                    } else {
                                        pendingFlightSelection = nil
                                        showingSaveFailedAlert = true
                                    }
                                }
                                Button("Discard", role: .destructive) {
                                    if let pending = pendingFlightSelection {
                                        selectedFlight = pending
                                        isAddingNewFlight = false
                                        viewModel.loadFlightForEditing(pending)
                                        pendingFlightSelection = nil
                                    } else {
                                        selectedFlight = nil
                                        viewModel.exitEditingMode()
                                    }
                                }
                                Button("Cancel", role: .cancel) {
                                    pendingFlightSelection = nil
                                }
                            } message: {
                                Text(viewModel.changesSummary)
                            }
                            .alert("Save Failed", isPresented: $showingSaveFailedAlert) {
                                Button("OK", role: .cancel) { }
                            } message: {
                                Text("Check BLOCK time not empty.")
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
                                if purchaseService.canAddFlight {
                                    isAddingNewFlight = true
                                } else {
                                    showingPaywall = true
                                }
                            }
                        )
                        .onAppear {
//                                    LogManager.shared.debug("Empty detail view showing - selectedFlight is nil")
                        }
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
            .sheet(isPresented: $showingPaywall) {
                PaywallView(isDismissible: true)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Force sidebar to show when app becomes active
                if newPhase == .active && shouldUseSplitView {
                    columnVisibility = .doubleColumn
                }
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
    @Binding var refreshTrigger: UUID
    let onFlightSelected: (FlightSector) -> Void

    private let databaseService = FlightDatabaseService.shared
    @Environment(PurchaseService.self) private var purchaseService
    @State private var showingPaywall = false
    @State private var showingMap = false
    @State private var showingSpreadsheet = false
    @State private var allFlightSectors: [FlightSector] = []
    @State private var filteredFlightSectors: [FlightSector] = []
    @State private var showingFilterSheet = false
    @State private var isFilterActive: Bool = false
    @State private var flightToDelete: FlightSector?
    @State private var showingDeleteAlert = false
    @State private var selectedFlightsForDeletion: Set<UUID> = []
    @State private var showingBulkDeleteAlert = false
    @State private var showingBulkDuplicateAlert = false
    @State private var showingBulkEditSheet = false
    @State private var summaryToEdit: FlightSector?
    @State private var showingNewSummarySheet = false
    @State private var sessionFilterIDs: Set<UUID> = []
    @State private var showingDeleteSessionAlert = false
    @State private var cachedTotalHours: Double = 0.0
    @State private var hasScrolledOnLaunch = false
    @State private var pendingScrollToLatest = false
    @State private var undoCount: Int = 0
    @State private var undoDescription: String? = nil
    @State private var showClearUndoAlert = false

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

    private var bulkDuplicateAlertTitle: String {
        let n = selectedFlightsForDeletion.count
        return "Duplicate \(n) \(n == 1 ? "Entry" : "Entries")?"
    }

    // Device-dependent vertical padding for action buttons
    private var actionButtonVerticalPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 10 : 14
    }

    private var safeAreaTopInset: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top) ?? 0
    }

    private var allFilteredIds: Set<UUID> { Set(filteredFlightSectors.map { $0.id }) }

    private func toggleSelectAll() {
        HapticManager.shared.impact(.light)
        let allIds = allFilteredIds
        if selectedFlightsForDeletion == allIds {
            selectedFlightsForDeletion.removeAll()
        } else {
            selectedFlightsForDeletion = allIds
        }
    }

    private var flightCountHeader: some View {
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
    }

    @ViewBuilder
    private var flightListContent: some View {
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
                guard !hasScrolledOnLaunch, !filteredFlightSectors.isEmpty else { return }
                hasScrolledOnLaunch = true
                scrollToLastCompleted(in: filteredFlightSectors, proxy: proxy)
            }
            .onChange(of: filteredFlightSectors) { _, sectors in
                guard !sectors.isEmpty else { return }
                if pendingScrollToLatest {
                    pendingScrollToLatest = false
                    scrollToLastCompleted(in: sectors, proxy: proxy)
                    return
                }
                if isFilterActive {
                    proxy.scrollTo(sectors.first?.id, anchor: .top)
                    return
                }
                guard !hasScrolledOnLaunch else { return }
                hasScrolledOnLaunch = true
                scrollToLastCompleted(in: sectors, proxy: proxy)
            }
            .onReceive(NotificationCenter.default.publisher(for: .flightAdded)) { _ in
                hasScrolledOnLaunch = false
                pendingScrollToLatest = true
            }
        }
    }

    @ViewBuilder
    private var selectModeOverlay: some View {
        if isSelectMode {
            let isEmpty = selectedFlightsForDeletion.isEmpty
            HStack(spacing: 0) {
                // Edit
                Button {
                    HapticManager.shared.impact(.medium)
                    showingBulkEditSheet = true
                } label: {
                    Text("Edit")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(isEmpty ? Color.primary.opacity(0.3) : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(isEmpty)

                Divider()
                    .frame(height: 20)

                // Duplicate
                Button {
                    HapticManager.shared.impact(.medium)
                    showingBulkDuplicateAlert = true
                } label: {
                    Text("Duplicate")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(isEmpty ? Color.primary.opacity(0.3) : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(isEmpty)

                Divider()
                    .frame(height: 20)

                // Delete
                Button {
                    HapticManager.shared.notification(.warning)
                    showingBulkDeleteAlert = true
                } label: {
                    Text("Delete")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(isEmpty ? Color.red.opacity(0.35) : .red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(isEmpty)
            }
            .background(.thickMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.25), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 6)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var filterStatusBanner: some View {
        let isImportReview = filterViewModel.filterImportSessionID != nil
        if isImportReview || isFilterActive {
            let accentColor: Color = isImportReview ? .orange : .blue
            let icon = isImportReview ? "tray.and.arrow.down.fill" : "line.3.horizontal.decrease.circle.fill"
            let label = isImportReview ? "Showing imported flights" : "Showing filtered list"
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(accentColor)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    HapticManager.shared.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        clearFilters()
                    }
                }) {
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var importDeleteBanner: some View {
        if filterViewModel.filterImportSessionID != nil {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Text("Remove this import")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: {
                    HapticManager.shared.impact(.light)
                    showingDeleteSessionAlert = true
                }) {
                    Text("Delete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var customToolbar: some View {
        HStack(spacing: 12) {
            if isSelectMode {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    isSelectMode = false
                    selectedFlightsForDeletion.removeAll()
                }) {
                    Text("Cancel")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.blue, lineWidth: 1.5)
                        )
                }

                Spacer()

                Text(selectedFlightsForDeletion.isEmpty ? "Select Entries" : "\(selectedFlightsForDeletion.count) Selected")
                    .font(.headline)

                Spacer()

                if !filteredFlightSectors.isEmpty {
                    Button(action: toggleSelectAll) {
                        let allSelected = selectedFlightsForDeletion == allFilteredIds
                        Text(allSelected ? "Deselect All" : "Select All")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.blue, lineWidth: 1.5)
                            )
                    }
                }
            } else {
                // Add + Select buttons on the left
                Menu {
                    Button {
                        HapticManager.shared.impact(.light)
                        if purchaseService.canAddFlight {
                            selectedFlight = nil
                            isAddingNewFlight = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Label("New Flight", systemImage: "airplane")
                    }
                    Button {
                        HapticManager.shared.impact(.light)
                        showingNewSummarySheet = true
                    } label: {
                        Label("Add Aircraft Summary", systemImage: "list.bullet.rectangle")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title)
                }

                if !filteredFlightSectors.isEmpty {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        isSelectMode = true
                        if let selectedId = selectedFlight?.id {
                            selectedFlightsForDeletion.insert(selectedId)
                        }
                        selectedFlight = nil
                    }) {
                        Text("Select")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.blue, lineWidth: 1.5)
                            )
                    }
                }

                Spacer()

                // Map, Data, Filter buttons on the right
                HStack(spacing: 20) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showingMap = true
                    }) {
                        Image(systemName: "globe.asia.australia")
                            .font(.title)
                    }

                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showingSpreadsheet = true
                    }) {
                        Image(systemName: "tablecells")
                            .font(.title)
                    }

                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showingFilterSheet = true
                    }) {
                        ZStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title)
                            if isFilterActive {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                } // end HStack

            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .padding(.top, safeAreaTopInset)
    }

    private func refreshUndoState() {
        undoCount = FlightDatabaseService.shared.undoableChangeCount
        undoDescription = FlightDatabaseService.shared.lastUndoDescription
    }

    @ViewBuilder
    private var undoBar: some View {
        if undoCount > 0 {
            HStack(spacing: 10) {
                Button {
                    HapticManager.shared.impact(.light)
                    showClearUndoAlert = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Clear undo history")
                VStack(alignment: .leading, spacing: 1) {
                    Text(undoDescription ?? "\(undoCount) \(undoCount == 1 ? "change" : "changes") to undo")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("History clears when app closes")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    HapticManager.shared.impact(.light)
                    FlightDatabaseService.shared.undoLastChange()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        refreshUndoState()
                    }
                } label: {
                    Text("Undo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .alert("Clear Undo History?", isPresented: $showClearUndoAlert) {
                Button("Clear History", role: .destructive) {
                    FlightDatabaseService.shared.clearUndoHistory()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        refreshUndoState()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the ability to undo recent changes.")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            customToolbar

            if filteredFlightSectors.isEmpty && !allFlightSectors.isEmpty && !isOnlyKeywordSearchActive() {
                NoResultsView(onClearFilters: clearFilters)
            } else if filteredFlightSectors.isEmpty && allFlightSectors.isEmpty {
                EmptyFlightsView()
            } else {
                flightCountHeader
                    .background(Color.clear)
                filterStatusBanner
                importDeleteBanner
                undoBar
                flightListContent
            }
        }
        .overlay(alignment: .bottomTrailing) {
            selectModeOverlay
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelectMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedFlightsForDeletion.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: undoCount)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.container, edges: .top)
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView(isDismissible: true)
        }
        .fullScreenCover(isPresented: $showingMap) {
            FlightMapView()
        }
        .fullScreenCover(isPresented: $showingSpreadsheet) {
            LogbookSpreadsheetView(flights: isFilterActive ? filteredFlightSectors : nil)
                .environmentObject(viewModel)
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
                filterSpIns: $filterViewModel.filterSpIns,
                filterNoBlockTime: $filterViewModel.filterNoBlockTime,
                filterNoCrewNames: $filterViewModel.filterNoCrewNames,
                filterNoFlightNumber: $filterViewModel.filterNoFlightNumber,
                filterNoAircraftType: $filterViewModel.filterNoAircraftType,
                filterNoAircraftReg: $filterViewModel.filterNoAircraftReg,
                filterNoRoleAssigned: $filterViewModel.filterNoRoleAssigned,
                filterMultipleRolesAssigned: $filterViewModel.filterMultipleRolesAssigned,
                filterTypeSummary: $filterViewModel.filterTypeSummary,
                filterKeywordSearch: $filterViewModel.filterKeywordSearch,
                selectedDateRange: $filterViewModel.selectedDateRange,
                filterImportSessionID: $filterViewModel.filterImportSessionID,
                sortOrderReversed: $filterViewModel.sortOrderReversed,
                onApply: {
                    applyFilters()
                    showingFilterSheet = false
                },
                onClear: {
                    clearFilters()
                    showingFilterSheet = false
                }
            )
        }
        .onAppear {
            if viewModel.isEditingMode {
                viewModel.exitEditingMode()
            }
            Task { await loadFlights() }
            refreshUndoState()
            if AppState.shared.pendingAddFlight {
                AppState.shared.pendingAddFlight = false
                isAddingNewFlight = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSManagedObjectContextDidSave)) { _ in
            refreshUndoState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddFlight)) { _ in
            isAddingNewFlight = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddFlightCapture)) { _ in
            AppState.shared.triggerCamera = true
            isAddingNewFlight = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .reviewImportSession)) { notification in
            if let sessionID = notification.userInfo?["sessionID"] as? UUID {
                filterViewModel.filterImportSessionID = sessionID
                loadSessionFilterIDs(sessionID)
            }
        }
        .onChange(of: filterViewModel.filterImportSessionID) { _, newSessionID in
            if let sessionID = newSessionID {
                loadSessionFilterIDs(sessionID)
            } else {
                sessionFilterIDs = []
                applyFilters()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            let selectedFlightId = selectedFlight?.id
            Task {
                await loadFlights()
                if let selectedId = selectedFlightId {
                    if let updatedFlight = filteredFlightSectors.first(where: { $0.id == selectedId }) {
                        selectedFlight = updatedFlight
                        // Skip reload if user has unsaved changes (e.g. lookup data just populated)
                        if !viewModel.hasUnsavedChanges {
                            viewModel.loadFlightForEditing(updatedFlight)
                        }
                    } else {
                        selectedFlight = nil
                    }
                }
            }
            refreshUndoState()
        }
        .onChange(of: refreshTrigger) { _, _ in
            Task { await loadFlights() }
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
            Text("This will delete the selected entries.")
        }
        .alert(bulkDuplicateAlertTitle, isPresented: $showingBulkDuplicateAlert) {
            Button("Duplicate") {
                HapticManager.shared.notification(.success)
                performBulkDuplicate()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Copies will be added to your logbook with the same details.")
        }
        .alert("Delete Import Batch?", isPresented: $showingDeleteSessionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                if let sessionID = filterViewModel.filterImportSessionID {
                    FlightDatabaseService.shared.deleteImportSession(sessionID)
                    filterViewModel.filterImportSessionID = nil
                    sessionFilterIDs = []
                }
            }
        } message: {
            Text("This will permanently delete all flights from this import.")
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
        .sheet(isPresented: $showingNewSummarySheet) {
            AircraftSummarySheet(
                editingSector: nil,
                onSave: { newSummary in
                    saveSummary(newSummary)
                }
            )
        }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func sectorRowContent(for sector: FlightSector) -> some View {
        if sector.flightNumber == "SUMMARY" {
            SummaryRow(sector: sector, showTimesInHoursMinutes: viewModel.showTimesInHoursMinutes).equatable()
        } else {
            FlightSectorRow(
                sector: sector,
                useLocalTime: viewModel.displayFlightsInLocalTime,
                useIATACodes: viewModel.useIATACodes,
                showTimesInHoursMinutes: viewModel.showTimesInHoursMinutes,
                roundingMode: viewModel.decimalRoundingMode
            ).equatable()
        }
    }

    @ViewBuilder
    private func selectModeRow(for sector: FlightSector) -> some View {
        let isSelected = selectedFlightsForDeletion.contains(sector.id)
        sectorRowContent(for: sector)
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
        let isActive = selectedFlight?.id == sector.id
        sectorRowContent(for: sector)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.blue.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.shared.impact(.light)
                if isSummary {
                    summaryToEdit = sector
                } else {
//                    LogManager.shared.debug("Flight tapped: \(sector.flightNumberFormatted)")
                    selectedFlight = sector
                    onFlightSelected(sector)
                }
            }
            .onLongPressGesture {
                HapticManager.shared.impact(.medium)
                isSelectMode = true
                selectedFlightsForDeletion.insert(sector.id)
            }
            .id(sector.id)
    }

    private func scrollToLastCompleted(in sectors: [FlightSector], proxy: ScrollViewProxy) {
        let today = Calendar.current.startOfDay(for: Date())
        guard let completedIndex = sectors.firstIndex(where: {
            guard let date = $0.parsedDate else { return false }
            return date <= today && ($0.blockTimeValue > 0 || $0.simTimeValue > 0 || $0.spInsTimeValue > 0 || $0.isPositioning)
        }) else {
            if let id = sectors.last?.id { proxy.scrollTo(id, anchor: .top) }
            return
        }
        // Scroll to the next future flight if one exists, so the user sees upcoming context.
        let scrollIndex = completedIndex > 0 ? completedIndex - 1 : completedIndex
        proxy.scrollTo(sectors[scrollIndex].id, anchor: .top)
    }

    @MainActor
    private func loadFlights() async {
        let sectors = await databaseService.fetchAllFlightsAsync()
        self.allFlightSectors = sectors
        LogManager.shared.debug("FlightsSplitView: Loaded \(self.allFlightSectors.count) flights from database")
        self.applyFilters()
    }

    private func refreshFlights() async {
        HapticManager.shared.impact(.light)
        await loadFlights()
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
               let sectorDate = sector.parsedDate {
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

            // Simulator filter (exclude Sp/Ins-only flights — they have simTime==spInsTime but are not SIM)
            if filterViewModel.filterSimulator && (sector.simTimeValue == 0 || sector.isSpInsOnly) {
                return false
            }

            // Positioning filter
            if filterViewModel.filterPositioning && !sector.isPositioning {
                return false
            }

            // Sp/Ins filter (sim instruction OR aircraft instruction)
            if filterViewModel.filterSpIns && !sector.isSpInsOnly && !sector.isAircraftInstruction {
                return false
            }

            // No Block Time filter (exclude PAX and SIM flights — they legitimately have no block time)
            if filterViewModel.filterNoBlockTime {
                if sector.isPositioning || sector.simTimeValue > 0 {
                    return false
                }
                if sector.blockTimeValue != 0.0 {
                    return false
                }
            }

            // No Crew Names filter
            if filterViewModel.filterNoCrewNames {
                let captainEmpty = sector.captainName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let foEmpty = sector.foName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if !captainEmpty && !foEmpty {
                    return false
                }
            }

            // No Role Assigned filter (block time > 0, no P1/ICUS/P2, not a SUMMARY)
            if filterViewModel.filterNoRoleAssigned {
                let isSummary = sector.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "SUMMARY"
                if isSummary || sector.blockTimeValue == 0 ||
                   sector.p1TimeValue > 0 || sector.p1usTimeValue > 0 || sector.p2TimeValue > 0 {
                    return false
                }
            }

            // Multiple Roles Assigned filter (block time > 0, more than one role column > 0, not a SUMMARY)
            if filterViewModel.filterMultipleRolesAssigned {
                let isSummary = sector.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "SUMMARY"
                let roleCount = (sector.p1TimeValue > 0 ? 1 : 0) + (sector.p1usTimeValue > 0 ? 1 : 0) + (sector.p2TimeValue > 0 ? 1 : 0)
                if isSummary || sector.blockTimeValue == 0 || roleCount < 2 {
                    return false
                }
            }

            // No Flight Number filter
            if filterViewModel.filterNoFlightNumber &&
               !sector.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }

            // No Aircraft Type filter — exclude PAX flights unless the PAX toggle is also on
            if filterViewModel.filterNoAircraftType {
                if sector.isPositioning && !filterViewModel.filterPositioning { return false }
                if !sector.aircraftType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            }

            // No Aircraft Registration filter
            if filterViewModel.filterNoAircraftReg &&
               !sector.aircraftReg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }

            // Import Session filter
            if filterViewModel.filterImportSessionID != nil,
               !sessionFilterIDs.contains(sector.id) {
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
                if time1.isEmpty && time2.isEmpty {
                    let result = (flight1.createdAt ?? .distantPast) > (flight2.createdAt ?? .distantPast)
                    return filterViewModel.sortOrderReversed ? !result : result
                }
                if time1.isEmpty { return filterViewModel.sortOrderReversed ? false : true }
                if time2.isEmpty { return filterViewModel.sortOrderReversed ? true : false }
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
        } else if filterViewModel.filterSpIns {
            sorted.reduce(0.0) { $0 + $1.spInsTimeValue }
        } else {
            sorted.reduce(0.0) { $0 + $1.blockTimeValue + ($1.isSpInsOnly || !viewModel.countSimInTotal ? 0 : $1.simTimeValue) }
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
                        filterViewModel.filterSpIns ||
                        filterViewModel.filterNoBlockTime ||
                        filterViewModel.filterNoCrewNames ||
                        filterViewModel.filterNoFlightNumber ||
                        filterViewModel.filterNoAircraftType ||
                        filterViewModel.filterNoAircraftReg ||
                        filterViewModel.filterNoRoleAssigned ||
                        filterViewModel.filterMultipleRolesAssigned ||
                        filterViewModel.filterTypeSummary ||
                        filterViewModel.filterImportSessionID != nil ||
                        !filterViewModel.filterKeywordSearch.isEmpty

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
        sessionFilterIDs = []
        applyFilters()
    }

    private func loadSessionFilterIDs(_ sessionID: UUID) {
        let context = FlightDatabaseService.shared.viewContext
        context.perform {
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.predicate = NSPredicate(format: "importSessionID == %@", sessionID as CVarArg)
            request.propertiesToFetch = ["id"]
            let flights = (try? context.fetch(request)) ?? []
            let ids = Set(flights.compactMap { $0.id })
            DispatchQueue.main.async {
                sessionFilterIDs = ids
                applyFilters()
            }
        }
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

    private func performBulkDuplicate() {
        let flightsToDuplicate = filteredFlightSectors.filter { selectedFlightsForDeletion.contains($0.id) }
        guard !flightsToDuplicate.isEmpty else { return }
        databaseService.duplicateFlights(flightsToDuplicate)
        selectedFlightsForDeletion.removeAll()
        isSelectMode = false
        Task { await loadFlights() }
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

        // Disable CloudKit sync before dispatching background work
        let cloudKitWasEnabled = databaseService.disableCloudKitSync()

        Task {
            let success = await databaseService.updateFlightsBulk(updates)
            // Task inherits @MainActor from the calling SwiftUI context,
            // so all UI updates below run on the main thread.
            if success {
                if cloudKitWasEnabled { databaseService.enableCloudKitSync() }
                // Update selectedFlight if it was one of the edited flights (O(1) dict lookup)
                if let currentId = selectedFlight?.id, let updated = updates[currentId] {
                    selectedFlight = updated
                }
                selectedFlightsForDeletion.removeAll()
                isSelectMode = false
                HapticManager.shared.notification(.success)
                await loadFlights()
            } else {
                if cloudKitWasEnabled { databaseService.enableCloudKitSync() }
                HapticManager.shared.notification(.error)
            }
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
                Task { await loadFlights() }
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
               !filterViewModel.filterSpIns &&
               !filterViewModel.filterNoBlockTime &&
               !filterViewModel.filterNoCrewNames &&
               !filterViewModel.filterNoFlightNumber &&
               !filterViewModel.filterNoAircraftType &&
               !filterViewModel.filterNoAircraftReg &&
               !filterViewModel.filterNoRoleAssigned &&
               !filterViewModel.filterMultipleRolesAssigned &&
               !filterViewModel.filterTypeSummary &&
               filterViewModel.filterImportSessionID == nil
    }

}

// MARK: - Empty Detail View
private struct EmptyDetailView: View {
    @Environment(ThemeService.self) private var themeService
    let isSelectMode: Bool
    let onAddFlight: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            Text("Select a Flight")
                .font(.title)
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
                            .font(.title)
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
                .font(.title)
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
                .font(.title)
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
