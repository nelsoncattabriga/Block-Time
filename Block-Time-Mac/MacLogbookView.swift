//
//  MacLogbookView.swift
//  Block-Time-Mac
//
//  Spreadsheet-style logbook table using SwiftUI Table.
//

import SwiftUI

struct MacLogbookView: View {
    @ObservedObject var viewModel: MacLogbookViewModel
    @Binding var selection: Set<UUID>
    @Binding var showingFilter: Bool
    var filterState: MacFilterState
    var onRowsLoaded: ([MacFlightRow]) -> Void
    var onSyncingChanged: (Bool) -> Void = { _ in }

    @State private var columnPrefs = ColumnPreferences()
    @State private var showingColumnManager = false

    var body: some View {
        VStack(spacing: 0) {
            tableContent
            if filterState.isActive && !showingFilter {
                filterBanner
            }
            footerBar
        }
        .task {
            if viewModel.allFlights.isEmpty {
                await viewModel.load()
            }
            onRowsLoaded(viewModel.allFlights)
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search flights…")
        .toolbar { tableToolbar }
        .onChange(of: filterState.version) { applyFilters() }
        .onChange(of: viewModel.allFlights.count) { onRowsLoaded(viewModel.allFlights) }
        .onChange(of: viewModel.isSyncing) { onSyncingChanged(viewModel.isSyncing) }
    }

    private func applyFilters() {
        viewModel.applyFilters(filterState)
    }

    // MARK: - Table

    private var tableContent: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading logbook…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.displayedFlights.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty && !filterState.isActive ? "No Flights" : "No Results",
                    systemImage: "book.closed",
                    description: Text(viewModel.searchText.isEmpty && !filterState.isActive
                        ? "Flights sync automatically from your iPhone."
                        : "Try adjusting your search or filters.")
                )
            } else {
                MacLogbookTableView(
                    rows: viewModel.displayedFlights,
                    selection: $selection,
                    columns: columnPrefs.visibleColumns,
                    prefs: columnPrefs
                )
            }
        }
    }

    // MARK: - Filter Banner

    private var filterBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 12))
            Text("Showing filtered flights")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear") { filterState.clearFilters() }
                .font(.system(size: 12))
                .foregroundStyle(.red)
            Button("Edit Filters") { showingFilter = true }
                .font(.system(size: 12))
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.blue.opacity(0.07))
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Footer

    private var footerBar: some View {
        ZStack {
            // Centred block total
            let totalBlock = MacFlightRow.hhmmDisplay(viewModel.totalBlockHours)
            Text("\(totalBlock) hours")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Left-aligned counts
            HStack(spacing: 16) {
                Text("\(viewModel.displayedFlights.count) entries")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !selection.isEmpty {
                    Text("| \(selection.count) selected")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var tableToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                NotificationCenter.default.post(name: .macNewFlight, object: nil)
            } label: {
                Label("New Flight", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task { await viewModel.reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showingColumnManager.toggle()
            } label: {
                Label("Columns", systemImage: "table.badge.more")
            }
            .popover(isPresented: $showingColumnManager, arrowEdge: .bottom) {
                ColumnManagerPopover(prefs: columnPrefs)
            }
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showingFilter.toggle()
            } label: {
                filterButtonLabel
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }
    }

    private var filterButtonLabel: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: showingFilter
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
            .foregroundStyle(showingFilter ? .blue : .primary)

            if filterState.isActive {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 7, height: 7)
                    .offset(x: 3, y: -3)
            }
        }
    }
}
