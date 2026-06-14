//
//  DashboardConfiguration.swift
//  Block-Time
//
//  Observable class holding which cards appear in the sidebar and detail pane
//  of the Dashboard. Persists to UserDefaults automatically.
//

import SwiftUI
import BlockTimeKit

@Observable
final class DashboardConfiguration {

    var sidebarCards: [DashboardCardID]
    var detailCards: [DashboardCardID]

    private let sidebarKey = "insightsSidebarCards2"
    private let detailKey  = "insightsDetailCards2"

    init() {
        sidebarCards = []
        detailCards  = []
        load()
    }

    // MARK: - Computed

    /// All known cards: standard cards + one entry per user-defined counter definition.
    /// Excludes the legacy .customCount card once the counter migration has run, since
    /// the data is now owned by customCounter.1 and the old card would be a duplicate.
    private var allKnownCards: [DashboardCardID] {
        let legacyMigrated = UserDefaults.standard.bool(forKey: "legacyCounterMigratedToColumn1")
        let standardCards = legacyMigrated
            ? DashboardCardID.allStandardCases.filter { $0 != .customCount }
            : DashboardCardID.allStandardCases
        let counterCards = CustomCounterService.shared.definitions
            .filter { $0.showTotal }
            .map { DashboardCardID.customCounter($0.columnIndex) }
        return standardCards + counterCards
    }

    /// Cards not yet assigned to sidebar or detail (iPad).
    var availableCards: [DashboardCardID] {
        let used = Set(sidebarCards + detailCards)
        return allKnownCards.filter { !used.contains($0) }
    }

    /// Cards not in the detail list — used on iPhone where there is no sidebar.
    /// Sidebar-only cards appear here so iPhone users can still add them.
    var availableForPhone: [DashboardCardID] {
        let used = Set(detailCards)
        return allKnownCards.filter { !used.contains($0) }
    }

    // MARK: - Add

    func addToSidebar(_ card: DashboardCardID) {
        guard !sidebarCards.contains(card), !detailCards.contains(card) else { return }
        sidebarCards.append(card)
        save()
    }

    func addToDetail(_ card: DashboardCardID) {
        guard !sidebarCards.contains(card), !detailCards.contains(card) else { return }
        detailCards.append(card)
        save()
    }

    /// Adds a card to the detail list regardless of sidebar membership.
    /// Used on iPhone where there is no sidebar and all cards should be accessible.
    func addToDetailFromPhone(_ card: DashboardCardID) {
        guard !detailCards.contains(card) else { return }
        detailCards.append(card)
        save()
    }

    // MARK: - Reorder

    func moveSidebarCard(from offsets: IndexSet, to destination: Int) {
        sidebarCards.move(fromOffsets: offsets, toOffset: destination)
        save()
    }

    func moveDetailCard(from offsets: IndexSet, to destination: Int) {
        detailCards.move(fromOffsets: offsets, toOffset: destination)
        save()
    }

    // MARK: - Prune

    /// Removes any sidebar/detail cards that are no longer in allKnownCards.
    /// Called when counter definitions change (e.g. showTotal toggled off, counter deleted).
    func pruneRemovedCards() {
        let known = Set(allKnownCards)
        let prunedSidebar = sidebarCards.filter { known.contains($0) }
        let prunedDetail  = detailCards.filter  { known.contains($0) }
        if prunedSidebar.count != sidebarCards.count || prunedDetail.count != detailCards.count {
            sidebarCards = prunedSidebar
            detailCards  = prunedDetail
            save()
        }
    }

    // MARK: - Remove (returns card to the Available pool)

    func removeSidebarCard(at offsets: IndexSet) {
        sidebarCards.remove(atOffsets: offsets)
        save()
    }

    func removeDetailCard(at offsets: IndexSet) {
        detailCards.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(sidebarCards) {
            UserDefaults.standard.set(data, forKey: sidebarKey)
        }
        if let data = try? JSONEncoder().encode(detailCards) {
            UserDefaults.standard.set(data, forKey: detailKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: sidebarKey),
           let cards = try? JSONDecoder().decode([DashboardCardID].self, from: data) {
            sidebarCards = cards
        } else {
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            sidebarCards = isIPad ? [.careerMilestones] : []
        }

        if let data = UserDefaults.standard.data(forKey: detailKey),
           let cards = try? JSONDecoder().decode([DashboardCardID].self, from: data) {
            detailCards = cards
        } else {
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            detailCards = isIPad ? [.activityChart] : [.careerMilestones, .activityChart]
        }
    }
}
