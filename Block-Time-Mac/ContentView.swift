//
//  ContentView.swift
//  Block-Time-Mac
//
//  Root layout: 2-column NavigationSplitView (sidebar + content).
//  The detail panel is an inline trailing pane that slides in/out within the content column.
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

// MARK: - Mac Root View

struct MacRootView: View {
    @State private var selectedSection: MacSection = .logbook
    @State private var tableSelection = Set<UUID>()
    @State private var showingFilter = false
    @State private var filterState = MacFilterState()
    @State private var allLogbookRows: [MacFlightRow] = []
    @AppStorage("macAppearance") private var appearanceRaw: String = "system"

    private var panelHasContent: Bool {
        showingFilter && selectedSection == .logbook
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        NavigationSplitView {
            MacSidebarView(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(200)
        } detail: {
            HStack(spacing: 0) {
                MacContentAreaView(
                    section: selectedSection,
                    tableSelection: $tableSelection,
                    showingFilter: $showingFilter,
                    filterState: filterState,
                    onRowsLoaded: { allLogbookRows = $0 }
                )

                if panelHasContent {
                    Divider()
                    MacDetailPanelView(
                        section: selectedSection,
                        tableSelection: tableSelection,
                        showingFilter: true,
                        filter: filterState,
                        allRows: allLogbookRows,
                        onCloseFilter: { showingFilter = false }
                    )
                    .frame(width: 350)
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: panelHasContent)
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(preferredColorScheme)
    }
}
