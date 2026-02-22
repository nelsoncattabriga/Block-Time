//
//  DashboardConfiguration.swift
//  Block-Time
//
//  Observable class holding which cards appear in the sidebar and detail pane
//  of the Insights dashboard. Persists to UserDefaults automatically.
//

import SwiftUI

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

    /// Cards not yet assigned to sidebar or detail (iPad).
    var availableCards: [DashboardCardID] {
        let used = Set(sidebarCards + detailCards)
        return DashboardCardID.allCases.filter { !used.contains($0) }
    }

    /// Cards not in the detail list — used on iPhone where there is no sidebar.
    /// Sidebar-only cards appear here so iPhone users can still add them.
    var availableForPhone: [DashboardCardID] {
        let used = Set(detailCards)
        return DashboardCardID.allCases.filter { !used.contains($0) }
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
            sidebarCards = [.totalTime, .frmsFlightTime, .frmsDutyTime]
        }

        if let data = UserDefaults.standard.data(forKey: detailKey),
           let cards = try? JSONDecoder().decode([DashboardCardID].self, from: data) {
            detailCards = cards
        } else {
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            let sidebarDefaults: Set<DashboardCardID> = [.totalTime, .frmsFlightTime, .frmsDutyTime]
            let remaining = DashboardCardID.allCases.filter { !sidebarDefaults.contains($0) }
            detailCards = isIPad
                ? remaining
                : [.totalTime, .frmsFlightTime, .frmsDutyTime] + remaining
        }
    }
}
