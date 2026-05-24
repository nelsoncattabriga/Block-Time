//
//  NewDashboardView.swift
//  Block-Time
//
//  New Insights dashboard.
//  iPad: NavigationSplitView with configurable sidebar + analytics detail pane.
//  iPhone: Single ScrollView with compact FRMS strip at top.
//

import SwiftUI

struct NewDashboardView: View {
    var frmsViewModel: FRMSViewModel

    @State private var viewModel = NewDashboardViewModel()
    @State private var config = DashboardConfiguration()
    @State private var showingEditSheet = false
    @Environment(ThemeService.self) private var themeService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    /// Loads dashboard data and FRMS cumulative totals concurrently.
    private func loadAll() async {
        // FRMS loads first so its duties are available for the rolling chart
        await triggerFRMSLoadIfNeeded()
        await viewModel.load(duties: frmsViewModel.dutiesLast365Days)
    }

    @MainActor
    private func triggerFRMSLoadIfNeeded() async {
        guard frmsViewModel.cumulativeTotals == nil, !frmsViewModel.isLoading else { return }
        let raw      = UserDefaults.standard.string(forKey: "flightTimePosition") ?? ""
        let position = FlightTimePosition(rawValue: raw) ?? .captain
        await frmsViewModel.refreshFlightData(crewPosition: position, ignoresCooldown: true)
    }

    var body: some View {
        if isIPad {
            ipadLayout
        } else {
            iphoneLayout
        }
    }

    // MARK: - iPad (NavigationSplitView)

    private var ipadLayout: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {

            DashboardSidebarView(
                config: config,
                viewModel: viewModel,
                frmsViewModel: frmsViewModel
            )
            .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 450)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingEditSheet = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }

        } detail: {

            ZStack {
                themeService.getGradient().ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading insights…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        detailCards
                            .padding(.horizontal, 16)
                    }
                    .refreshable { await loadAll() }
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingEditSheet) {
            DashboardEditSheet(config: config)
        }
        .task { await loadAll() }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            Task { await loadAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            config.pruneRemovedCards()
            Task { await viewModel.load(duties: frmsViewModel.dutiesLast365Days) }
        }
    }

    // MARK: - iPhone (single scroll column)

    private var iphoneLayout: some View {
        NavigationStack {
            ZStack {
                themeService.getGradient().ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading insights…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            detailCards
                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .refreshable { await loadAll() }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingEditSheet = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                DashboardEditSheet(config: config)
            }
        }
        .task { await loadAll() }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            Task { await loadAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            config.pruneRemovedCards()
            Task { await viewModel.load(duties: frmsViewModel.dutiesLast365Days) }
        }
    }

    // MARK: - Detail / main card list

    @ViewBuilder
    private var detailCards: some View {
        VStack(spacing: 16) {
            ForEach(config.detailCards, id: \.self) { card in
                DashboardCardView(
                    cardID: card,
                    frmsViewModel: frmsViewModel,
                    viewModel: viewModel
                )
            }
        }
    }
}
