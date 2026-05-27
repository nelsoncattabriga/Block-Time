//
//  ContentView.swift
//  Block-Time-Mac
//
//  Root layout: section picker in title bar, content + optional trailing detail panel.
//

import SwiftUI

// MARK: - Mac Section

enum MacSection: String, Hashable, CaseIterable {
    case logbook   = "Logbook"
    case dashboard = "Dashboard"
    case map       = "Map"
    case frms      = "FRMS"

    var icon: String {
        switch self {
        case .logbook:   return "airplane.departure"
        case .dashboard: return "chart.xyaxis.line"
        case .map:       return "map.fill"
        case .frms:      return "clock.badge.checkmark"
        }
    }

    var color: Color {
        switch self {
        case .logbook:   return .blue
        case .dashboard: return .orange
        case .map:       return .green
        case .frms:      return .purple
        }
    }
}

// MARK: - Detail panel state

enum MacDetailMode: Equatable {
    case none
    case filter
    case add
    case edit(UUID)

    static func == (lhs: MacDetailMode, rhs: MacDetailMode) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none), (.filter, .filter), (.add, .add): return true
        case (.edit(let a), .edit(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Mac Root View

struct MacRootView: View {
    @State private var selectedSection: MacSection = .logbook
    @State private var tableSelection = Set<UUID>()
    @State private var showingFilter = false
    @State private var filterState = MacFilterState()
    @State private var allLogbookRows: [MacFlightRow] = []
    @State private var isSyncing = false
    @State private var detailMode: MacDetailMode = .none

    @StateObject private var logbookVM = MacLogbookViewModel()

    private var panelIsVisible: Bool { detailMode != .none }

    var body: some View {
        HStack(spacing: 0) {
            MacContentAreaView(
                section: selectedSection,
                tableSelection: $tableSelection,
                showingFilter: $showingFilter,
                filterState: filterState,
                logbookVM: logbookVM,
                onRowsLoaded: { allLogbookRows = $0 },
                onSyncingChanged: { isSyncing = $0 },
                isSyncing: isSyncing
            )

            if panelIsVisible {
                Divider()
                detailPanel
                    .frame(width: 340)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: panelIsVisible)
        .toolbar {
            ToolbarItem(placement: .principal) {
                sectionPicker
            }
        }
        .onChange(of: tableSelection) { _, newSel in
            guard selectedSection == .logbook else { return }
            if showingFilter { return }
            if let selectedID = newSel.first {
                detailMode = .edit(selectedID)
            } else {
                detailMode = .none
            }
        }
        .onChange(of: showingFilter) { _, showing in
            detailMode = showing ? .filter : resolvedEditMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .macNewFlight)) { _ in
            tableSelection.removeAll()
            showingFilter = false
            detailMode = .add
        }
        .onChange(of: selectedSection) { _, _ in
            detailMode = .none
            showingFilter = false
            tableSelection.removeAll()
        }
    }

    // MARK: - Section picker (title bar)

    private var sectionPicker: some View {
        HStack(spacing: 2) {
            ForEach(MacSection.allCases, id: \.self) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: section.icon)
                        Text(section.rawValue)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        selectedSection == section
                            ? section.color.opacity(0.15)
                            : Color.clear
                    )
                    .foregroundStyle(selectedSection == section ? section.color : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }


    // MARK: - Helpers

    private func resolvedEditMode() -> MacDetailMode {
        if let id = tableSelection.first { return .edit(id) }
        return .none
    }

    @ViewBuilder
    private var detailPanel: some View {
        switch detailMode {
        case .none:
            EmptyView()

        case .filter:
            MacDetailPanelView(
                section: selectedSection,
                tableSelection: tableSelection,
                showingFilter: true,
                filter: filterState,
                allRows: allLogbookRows,
                onCloseFilter: {
                    showingFilter = false
                    detailMode = resolvedEditMode()
                }
            )

        case .add:
            MacFlightEditView(mode: .add, viewModel: logbookVM) {
                detailMode = .none
            }

        case .edit(let id):
            if let row = allLogbookRows.first(where: { $0.id == id }) {
                MacFlightEditView(mode: .edit(row), viewModel: logbookVM) {
                    detailMode = .none
                    tableSelection.removeAll()
                }
                .id(id)
            } else {
                Text("Flight not found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
