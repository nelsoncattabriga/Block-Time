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
    var viewModel: NewDashboardViewModel

    @State private var config = DashboardConfiguration()
    @State private var showingEditSheet = false
    @AppStorage("dashboardNudgeDismissed") private var nudgeDismissed = false
    @Environment(ThemeService.self) private var themeService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    /// Loads dashboard data and FRMS cumulative totals concurrently.
    private func loadAll() async {
        guard frmsViewModel.cumulativeTotals == nil, !frmsViewModel.isLoading else {
            await viewModel.load(duties: frmsViewModel.dutiesLast365Days)
            return
        }
        let raw      = UserDefaults.standard.string(forKey: "flightTimePosition") ?? ""
        let position = FlightTimePosition(rawValue: raw) ?? .captain
        async let frmsLoad: Void = frmsViewModel.refreshFlightData(crewPosition: position, ignoresCooldown: true)
        async let dashLoad: Void = viewModel.load(duties: [])
        _ = await (frmsLoad, dashLoad)
        // Reload dashboard now that FRMS duties are available for the rolling chart
        await viewModel.load(duties: frmsViewModel.dutiesLast365Days)
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
                    Button {
                        nudgeDismissed = true
                        showingEditSheet = true
                    } label: {
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
        .task {
            guard !viewModel.hasLoadedOnce else { return }
            await loadAll()
        }
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
                    Button {
                        nudgeDismissed = true
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                DashboardEditSheet(config: config)
            }
        }
        .task {
            guard !viewModel.hasLoadedOnce else { return }
            await loadAll()
        }
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
            if !nudgeDismissed {
                customiseNudge
            }
            ForEach(config.detailCards, id: \.self) { card in
                DashboardCardView(
                    cardID: card,
                    frmsViewModel: frmsViewModel,
                    viewModel: viewModel
                )
            }
        }
    }

    private var customiseNudge: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.secondary)
            Text("Tap the sliders icon to customise.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                nudgeDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("Customise Nudge") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                Text("Tap the sliders icon to customise.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button { } label: {
                    Image(systemName: "xmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 16)
    }
}
