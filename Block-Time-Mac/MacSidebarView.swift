//
//  MacSidebarView.swift
//  Block-Time-Mac
//

import SwiftUI

struct MacSidebarView: View {
    @Binding var selectedSection: MacSection
    var isSyncing: Bool = false

    var body: some View {
        List(MacSection.allCases, id: \.self, selection: $selectedSection) { section in
            Label(section.rawValue, systemImage: section.icon)
                .foregroundStyle(selectedSection == section ? .white : section.color)
                .tag(section)
        }
        .listStyle(.sidebar)
        .navigationTitle("Block-Time")
        .safeAreaInset(edge: .bottom) {
            SidebarFooterView(isSyncing: isSyncing)
        }
    }
}

// MARK: - Sidebar Footer

private struct SidebarFooterView: View {
    var isSyncing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            HStack(spacing: 6) {
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 7, height: 7)
                    Text("Syncing...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text("Synced")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
