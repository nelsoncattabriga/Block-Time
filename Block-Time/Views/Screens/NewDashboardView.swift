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
    @ObservedObject var frmsViewModel: FRMSViewModel

    @State private var viewModel = NewDashboardViewModel()
    @State private var config = InsightsConfiguration()
    @State private var showingEditSheet = false
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
                config: config,
                viewModel: viewModel,
                frmsViewModel: frmsViewModel
            )
            .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 450)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)

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
                            .padding(.top, 8)
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingEditSheet = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            InsightsEditSheet(config: config)
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
                            detailCards
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingEditSheet = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                InsightsEditSheet(config: config)
            }
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            Task { await viewModel.load() }
        }
    }

    // MARK: - Detail / main card list

    @ViewBuilder
    private var detailCards: some View {
        VStack(spacing: 16) {
            ForEach(config.detailCards, id: \.self) { card in
                InsightsCardView(
                    cardID: card,
                    frmsViewModel: frmsViewModel,
                    viewModel: viewModel
                )
            }
        }
    }
}
