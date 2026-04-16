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

    var body: some View {
        switch section {
        case .logbook:
            MacLogbookView(selection: $tableSelection)
        case .dashboard:
            MacSectionPlaceholder(section: section)
        case .map:
            MacSectionPlaceholder(section: section)
        case .frms:
            MacSectionPlaceholder(section: section)
        case .settings:
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
