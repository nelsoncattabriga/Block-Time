//
//  InsightsSidebarView.swift
//  Block-Time
//
//  iPad-only sidebar: renders whichever cards the user has assigned to the
//  sidebar slot via InsightsConfiguration. Each card is injected with
//  isCompact: true so stat cards render at narrow (iPhone) widths.
//

import SwiftUI

struct InsightsSidebarView: View {
    let config: InsightsConfiguration
    let viewModel: NewDashboardViewModel
    @ObservedObject var frmsViewModel: FRMSViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(config.sidebarCards, id: \.self) { card in
                    InsightsCardView(
                        cardID: card,
                        frmsViewModel: frmsViewModel,
                        viewModel: viewModel,
                        isCompact: true
                    )
                }

                if config.sidebarCards.isEmpty {
                    ContentUnavailableView(
                        "No sidebar cards",
                        systemImage: "sidebar.left",
                        description: Text("Tap the edit button to add cards.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(16)
        }
        .task { await triggerFRMSLoadIfNeeded() }
    }

    // MARK: - FRMS auto-load

    @MainActor
    private func triggerFRMSLoadIfNeeded() async {
        guard frmsViewModel.cumulativeTotals == nil, !frmsViewModel.isLoading else { return }
        let raw      = UserDefaults.standard.string(forKey: "flightTimePosition") ?? ""
        let position = FlightTimePosition(rawValue: raw) ?? .captain
        frmsViewModel.loadFlightData(crewPosition: position)
    }
}
