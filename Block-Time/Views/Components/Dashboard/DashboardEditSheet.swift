//
//  DashboardEditSheet.swift
//  Block-Time
//
//  Full-screen sheet for customising the Insights dashboard layout.
//  Users can reorder, remove, and add cards to the sidebar (iPad) and
//  detail pane sections using drag handles.
//

import SwiftUI

struct DashboardEditSheet: View {
    @Bindable var config: DashboardConfiguration
    @Environment(\.dismiss) private var dismiss

    @State private var sidebarCards: [DashboardCardID] = []
    @State private var detailCards: [DashboardCardID] = []
    @State private var cardToAdd: DashboardCardID? = nil
    @State private var editMode: EditMode = .active
    @AppStorage("showSpInsSelector") private var showSpInsSelector: Bool = false

    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var availablePool: [DashboardCardID] {
        let used = Set(sidebarCards + detailCards)
        let all = isIPad ? config.availableCards : config.availableForPhone
        return all.filter {
            !used.contains($0) &&
            ($0 != .customCount || !CustomCounterService.shared.definitions.isEmpty) &&
            ($0 != .insTime || showSpInsSelector)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Sidebar section (iPad only) ────────────────────────────
                if isIPad {
                    Section {
                        ForEach(sidebarCards, id: \.self) { card in
                            cardRow(card, location: "Sidebar")
                        }
                        .onMove { offsets, dest in
                            sidebarCards.move(fromOffsets: offsets, toOffset: dest)
                            config.moveSidebarCard(from: offsets, to: dest)
                        }
                        .onDelete { offsets in
                            sidebarCards.remove(atOffsets: offsets)
                            config.removeSidebarCard(at: offsets)
                        }
                    } header: {
                        Label("Sidebar", systemImage: "sidebar.left")
                    }
                }

                // ── Detail / main cards ────────────────────────────────────
                Section {
                    ForEach(detailCards, id: \.self) { card in
                        cardRow(card, location: isIPad ? "Detail Pane" : nil)
                    }
                    .onMove { offsets, dest in
                        detailCards.move(fromOffsets: offsets, toOffset: dest)
                        config.moveDetailCard(from: offsets, to: dest)
                    }
                    .onDelete { offsets in
                        detailCards.remove(atOffsets: offsets)
                        config.removeDetailCard(at: offsets)
                    }
                } header: {
                    Label(
                        isIPad ? "Detail Pane" : "Selected For Display",
                        systemImage: isIPad ? "rectangle.righthalf.inset.filled" : "square.grid.2x2"
                    )
                }

                // ── Available pool (grouped by category, custom order within) ──
                Section {
                    EmptyView()
                } header: {
                    Text("Available Cards")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 16)
                        .padding(.bottom, -8)
                }

                ForEach(DashboardCardID.Category.allCases, id: \.self) { category in
                    let cards = sortedCards(availablePool.filter { $0.category == category }, in: category)
                    if !cards.isEmpty {
                        Section(category.rawValue) {
                            ForEach(cards, id: \.self) { card in
                                availableRow(card)
                            }
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .onAppear {
                sidebarCards = config.sidebarCards
                detailCards  = config.detailCards
            }
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
                        sidebarCards = config.sidebarCards
                        cardToAdd = nil
                        reactivateEditMode()
                    }
                    Button("Detail Pane") {
                        config.addToDetail(card)
                        detailCards = config.detailCards
                        cardToAdd = nil
                        reactivateEditMode()
                    }
                    Button("Cancel", role: .cancel) { cardToAdd = nil }
                }
            }
        }
    }

    // MARK: - Row Builders

    private func cardRow(_ card: DashboardCardID, location: String?) -> some View {
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

    private func reactivateEditMode() {
        editMode = .inactive
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            editMode = .active
        }
    }

    private func sortedCards(_ cards: [DashboardCardID], in category: DashboardCardID.Category) -> [DashboardCardID] {
        switch category {
        case .timeStats:
            let order: [DashboardCardID] = [.totalTime, .picTime, .icusTime, .insTime, .instrumentTime, .nightTime, .simTime]
            return cards.sorted { (order.firstIndex(of: $0) ?? 999) < (order.firstIndex(of: $1) ?? 999) }
        case .recency:
            let order: [DashboardCardID] = [.aiiiRecency, .recentActivity28, .recentActivity30, .recentActivity365, .recentActivity7, .pfRecency, .takeoffRecency, .landingRecency]
            return cards.sorted { (order.firstIndex(of: $0) ?? 999) < (order.firstIndex(of: $1) ?? 999) }
        default:
            return cards.sorted { $0.displayName < $1.displayName }
        }
    }

    private func availableRow(_ card: DashboardCardID) -> some View {
        Button {
            if isIPad {
                cardToAdd = card
            } else {
                config.addToDetailFromPhone(card)
                detailCards = config.detailCards
                reactivateEditMode()
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
