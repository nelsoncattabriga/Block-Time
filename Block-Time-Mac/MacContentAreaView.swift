//
//  MacContentAreaView.swift
//  Block-Time-Mac
//
//  Central content column — switches per sidebar selection.
//

import SwiftUI

struct MacContentAreaView: View {
    let section: MacSection
    @Binding var tableSelection: Set<UUID>
    @Binding var showingFilter: Bool
    var filterState: MacFilterState
    var logbookVM: MacLogbookViewModel
    var onRowsLoaded: ([MacFlightRow]) -> Void
    var onSyncingChanged: (Bool) -> Void = { _ in }
    var isSyncing: Bool = false

    var body: some View {
        switch section {
        case .logbook:
            MacLogbookView(
                viewModel: logbookVM,
                selection: $tableSelection,
                showingFilter: $showingFilter,
                filterState: filterState,
                onRowsLoaded: onRowsLoaded,
                onSyncingChanged: onSyncingChanged,
                isSyncing: isSyncing
            )
        case .dashboard:
            MacSectionPlaceholder(section: section)
        case .map:
            MacSectionPlaceholder(section: section)
        case .frms:
            MacSectionPlaceholder(section: section)
        }
    }
}

// MARK: - Generic Placeholder

struct MacSectionPlaceholder: View {
    let section: MacSection

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: section.icon)
                .font(.system(size: 48))
                .foregroundStyle(section.color.opacity(0.4))
            Text(section.rawValue)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .navigationTitle(section.rawValue)
    }
}
