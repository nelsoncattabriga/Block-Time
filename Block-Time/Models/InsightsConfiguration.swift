//
//  InsightsConfiguration.swift
//  Block-Time
//
//  Observable class holding which cards appear in the sidebar and detail pane
//  of the Insights dashboard. Persists to UserDefaults automatically.
//

import SwiftUI

@Observable
final class InsightsConfiguration {

    var sidebarCards: [InsightsCardID]
    var detailCards: [InsightsCardID]

    private let sidebarKey = "insightsSidebarCards"
    private let detailKey  = "insightsDetailCards"

    init() {
        sidebarCards = []
        detailCards  = []
        load()
    }

    // MARK: - Computed

    /// Cards not yet assigned to sidebar or detail.
    var availableCards: [InsightsCardID] {
        let used = Set(sidebarCards + detailCards)
        return InsightsCardID.allCases.filter { !used.contains($0) }
    }

    // MARK: - Add

    func addToSidebar(_ card: InsightsCardID) {
        guard !sidebarCards.contains(card), !detailCards.contains(card) else { return }
        sidebarCards.append(card)
        save()
    }

    func addToDetail(_ card: InsightsCardID) {
        guard !sidebarCards.contains(card), !detailCards.contains(card) else { return }
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
           let cards = try? JSONDecoder().decode([InsightsCardID].self, from: data) {
            sidebarCards = cards
        } else {
            sidebarCards = [.frmsLimits, .totalTime]
        }

        if let data = UserDefaults.standard.data(forKey: detailKey),
           let cards = try? JSONDecoder().decode([InsightsCardID].self, from: data) {
            detailCards = cards
        } else {
            detailCards = [
                .activityChart, .fleetDonut, .roleDistribution, .pfRatioChart,
                .takeoffLanding, .approachTypes, .topRoutes, .topRegistrations
            ]
        }
    }
}
