//
//  MacDetailPanelView.swift
//  Block-Time-Mac
//
//  Right-hand detail panel — adapts per section and selection state.
//

import SwiftUI

struct MacDetailPanelView: View {
    let section: MacSection
    let tableSelection: Set<UUID>
    var showingFilter: Bool = false
    var filter: MacFilterState? = nil
    var allRows: [MacFlightRow] = []
    var onCloseFilter: () -> Void = {}

    var body: some View {
        Group {
            if showingFilter, let filter {
                MacFilterPanelView(filter: filter, rows: allRows, onClose: onCloseFilter)
            } else {
                switch section {
                case .logbook:
                    MacLogbookDetailPlaceholder()
                case .dashboard:
                    MacDetailPlaceholder(icon: "chart.bar.fill", label: "Select a card")
                case .map:
                    MacDetailPlaceholder(icon: "airplane.arrival", label: "Select an airport")
                case .frms:
                    MacDetailPlaceholder(icon: "shield.fill", label: "FRMS Detail")
                case .settings:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

// MARK: - Logbook Detail Placeholder

private struct MacLogbookDetailPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle")
                .font(.system(size: 40))
                .foregroundStyle(.blue.opacity(0.5))
            Text("Add New Flight")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Select a row to edit, or press ⌘N")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Generic Detail Placeholder

private struct MacDetailPlaceholder: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}
