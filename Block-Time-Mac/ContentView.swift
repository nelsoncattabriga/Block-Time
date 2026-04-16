//
//  ContentView.swift
//  Block-Time-Mac
//
//  Root 3-column NavigationSplitView shell.
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

    /// Whether this section uses the detail panel column.
    var usesDetailPanel: Bool {
        switch self {
        case .logbook, .dashboard, .map, .frms: return true
        case .settings: return false
        }
    }
}

// MARK: - Mac Root View

struct MacRootView: View {
    @State private var selectedSection: MacSection = .logbook
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var tableSelection = Set<UUID>()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MacSidebarView(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(200)
        } content: {
            MacContentAreaView(section: selectedSection, tableSelection: $tableSelection)
                .navigationSplitViewColumnWidth(min: 500, ideal: 800)
        } detail: {
            MacDetailPanelView(section: selectedSection, tableSelection: tableSelection)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
