//
//  InsightsEditSheet.swift
//  Block-Time
//
//  Full-screen sheet for customising the Insights dashboard layout.
//  Users can reorder, remove, and add cards to the sidebar (iPad) and
//  detail pane sections using drag handles.
//

import SwiftUI

struct InsightsEditSheet: View {
    @Bindable var config: InsightsConfiguration
    @Environment(\.dismiss) private var dismiss

    @State private var cardToAdd: InsightsCardID? = nil
    @State private var editMode: EditMode = .active

    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var availablePool: [InsightsCardID] {
        isIPad ? config.availableCards : config.availableForPhone
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Sidebar section (iPad only) ────────────────────────────
                if isIPad {
                    Section {
                        ForEach(config.sidebarCards, id: \.self) { card in
                            cardRow(card, location: "Sidebar")
                        }
                        .onMove { config.moveSidebarCard(from: $0, to: $1) }
                        .onDelete { config.removeSidebarCard(at: $0) }
                    } header: {
                        Label("Sidebar", systemImage: "sidebar.left")
                    } footer: {
                        Text("Narrow cards shown in the left panel.")
                    }
                }

                // ── Detail / main cards ────────────────────────────────────
                Section {
                    ForEach(config.detailCards, id: \.self) { card in
                        cardRow(card, location: isIPad ? "Detail Pane" : nil)
                    }
                    .onMove { config.moveDetailCard(from: $0, to: $1) }
                    .onDelete { config.removeDetailCard(at: $0) }
                } header: {
                    Label(
                        isIPad ? "Detail Pane" : "Cards",
                        systemImage: isIPad ? "rectangle.righthalf.inset.filled" : "square.grid.2x2"
                    )
                }

                // ── Available pool ─────────────────────────────────────────
                if !availablePool.isEmpty {
                    Section("Available") {
                        ForEach(availablePool, id: \.self) { card in
                            availableRow(card)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Customise Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Add to…",
                isPresented: Binding(
                    get: { cardToAdd != nil },
                    set: { if !$0 { cardToAdd = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let card = cardToAdd {
                    Button("Sidebar") {
                        config.addToSidebar(card)
                        cardToAdd = nil
                        refreshEditMode()
                    }
                    Button("Detail Pane") {
                        config.addToDetail(card)
                        cardToAdd = nil
                        refreshEditMode()
                    }
                    Button("Cancel", role: .cancel) { cardToAdd = nil }
                }
            }
        }
    }

    // MARK: - Row Builders

    private func cardRow(_ card: InsightsCardID, location: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: card.icon)
                .foregroundStyle(card.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.displayName)
                    .foregroundStyle(.primary)
                if let location {
                    Text(location)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func refreshEditMode() {
        editMode = .inactive
        Task { @MainActor in editMode = .active }
    }

    private func availableRow(_ card: InsightsCardID) -> some View {
        Button {
            if isIPad {
                cardToAdd = card
            } else {
                config.addToDetailFromPhone(card)
                refreshEditMode()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: card.icon)
                    .foregroundStyle(card.accentColor)
                    .frame(width: 28)
                Text(card.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.large)
            }
        }
    }
}
