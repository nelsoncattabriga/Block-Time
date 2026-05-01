//
//  ContentView.swift
//  Block-Time-Mac
//
//  Root layout: sidebar + content column with a trailing detail panel
//  that slides in for filter, edit, and add modes.
//

import SwiftUI

// MARK: - Mac Section

enum MacSection: String, Hashable, CaseIterable {
    case logbook    = "Logbook"
    case dashboard  = "Dashboard"
    case map        = "Map"
    case frms       = "FRMS"
    case settings   = "Settings"

    var icon: String {
        switch self {
        case .logbook:   return "book.closed.fill"
        case .dashboard: return "chart.bar.fill"
        case .map:       return "map.fill"
        case .frms:      return "shield.fill"
        case .settings:  return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .logbook:   return .blue
        case .dashboard: return .orange
        case .map:       return .green
        case .frms:      return .purple
        case .settings:  return .gray
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

    @AppStorage("macAppearance") private var appearanceRaw: String = "system"

    // Single logbook viewmodel lives here so edits trigger table reloads
    @StateObject private var logbookVM = MacLogbookViewModel()

    private var preferredColorScheme: ColorScheme? {
        switch appearanceRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private var panelIsVisible: Bool {
        detailMode != .none
    }

    var body: some View {
        NavigationSplitView {
            MacSidebarView(selectedSection: $selectedSection, isSyncing: isSyncing)
                .navigationSplitViewColumnWidth(200)
        } detail: {
            HStack(spacing: 0) {
                MacContentAreaView(
                    section: selectedSection,
                    tableSelection: $tableSelection,
                    showingFilter: $showingFilter,
                    filterState: filterState,
                    logbookVM: logbookVM,
                    onRowsLoaded: { allLogbookRows = $0 },
                    onSyncingChanged: { isSyncing = $0 }
                )

                if panelIsVisible {
                    Divider()
                    detailPanel
                        .frame(width: 340)
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: panelIsVisible)
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(preferredColorScheme)
        .onChange(of: tableSelection) { _, newSel in
            guard selectedSection == .logbook else { return }
            if showingFilter {
                // Keep filter panel open; don't switch to edit
                return
            }
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
                // Row deleted or not yet loaded
                Text("Flight not found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
