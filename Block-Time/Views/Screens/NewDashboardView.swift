//
//  NewDashboardView.swift
//  Block-Time
//
//  New Insights dashboard — replaces the classic dashboard when ready.
//  Showcases charts and analytics beyond simple stat cards.
//

import SwiftUI

struct NewDashboardView: View {
    @State private var viewModel = NewDashboardViewModel()
    @Environment(ThemeService.self) private var themeService

    var body: some View {
        ZStack {
            themeService.getGradient().ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading insights…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {

                        // ── FRMS Flight Time Status ────────────────────────
                        FRMSStatusStripCard(data: viewModel.frmsStrip)

                        // ── Monthly Activity ───────────────────────────────
                        ActivityChartCard(data: viewModel.monthlyActivity)

                        // ── Fleet Breakdown + Role Distribution ────────────
                        FleetDonutCard(data: viewModel.fleetHours)
                        RoleDistributionCard(data: viewModel.monthlyRoles)

                        // ── PF Ratio Trend ─────────────────────────────────
                        PFRatioCard(data: viewModel.pfRatioByMonth)

                        // ── Night Flying Heatmap ───────────────────────────
                        NightHeatmapCard(data: viewModel.monthlyNight)

                        // ── T/O & Landings + Approach Types ───────────────
                        TakeoffLandingCard(stats: viewModel.tlStats)
                        ApproachTypesCard(data: viewModel.approachTypes)

                        // ── Top Routes & Registrations ─────────────────────
                        TopRoutesCard(routes: viewModel.topRoutes)
                        TopRegistrationsCard(registrations: viewModel.topRegistrations)

                        // ── Career Overview ────────────────────────────────
                        CareerMilestonesCard(stats: viewModel.careerStats)

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
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            Task { await viewModel.load() }
        }
    }
}
