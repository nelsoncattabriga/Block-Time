//
//  MacSidebarView.swift
//  Block-Time-Mac
//

import SwiftUI

struct MacSidebarView: View {
    @Binding var selectedSection: MacSection

    var body: some View {
        List(MacSection.allCases, id: \.self, selection: $selectedSection) { section in
            Label(section.rawValue, systemImage: section.icon)
                .foregroundStyle(selectedSection == section ? .white : section.color)
                .tag(section)
        }
        .listStyle(.sidebar)
        .navigationTitle("Block-Time")
        .safeAreaInset(edge: .bottom) {
            SidebarFooterView()
        }
    }
}

// MARK: - Sidebar Footer

private struct SidebarFooterView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                Text("Synced")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
