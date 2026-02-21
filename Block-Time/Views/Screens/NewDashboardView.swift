//
//  NewDashboardView.swift
//  Block-Time
//
//  New Insights dashboard.
//  iPad: NavigationSplitView with FRMS limits sidebar + analytics detail pane.
//  iPhone: Single ScrollView with compact FRMS strip at top.
//

import SwiftUI

struct NewDashboardView: View {
    @ObservedObject var frmsViewModel: FRMSViewModel

    @State private var viewModel = NewDashboardViewModel()
    @Environment(ThemeService.self) private var themeService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
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

            InsightsSidebarView(
                flightStrip: viewModel.frmsStrip,
                frmsViewModel: frmsViewModel
            )
            .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 450)
            .navigationTitle("FRMS Limits")
            .navigationBarTitleDisplayMode(.inline)

        } detail: {

            ZStack {
                themeService.getGradient().ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading insights…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        analyticsCards
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            Task { await viewModel.load() }
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
                            FRMSStatusStripCard(data: viewModel.frmsStrip)
                            analyticsCards
                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            Task { await viewModel.load() }
        }
    }

    // MARK: - Shared analytics cards (no Night heatmap, no Career milestones)

    @ViewBuilder
    private var analyticsCards: some View {
        VStack(spacing: 16) {
            ActivityChartCard(data: viewModel.monthlyActivity)
            FleetDonutCard(data: viewModel.fleetHours)
            RoleDistributionCard(data: viewModel.monthlyRoles)
            PFRatioCard(data: viewModel.pfRatioByMonth)
            TakeoffLandingCard(stats: viewModel.tlStats)
            ApproachTypesCard(data: viewModel.approachTypes)
            TopRoutesCard(routes: viewModel.topRoutes)
            TopRegistrationsCard(registrations: viewModel.topRegistrations)
        }
    }
}
