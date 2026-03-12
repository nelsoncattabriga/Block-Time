//
//  MainTabView.swift
//  Block-Time
//
//  Created by Nelson on 9/9/2025.
//  Updated to use tab view for both iPhone and iPad
//

import SwiftUI

// Navigation destination types for type-safe navigation
enum FlightDestination: Hashable {
    case editFlight(FlightSector)
}

enum AppTab {
    case logbook, dashboard, frms, settings
}

struct MainTabView: View {
    @StateObject private var viewModel = FlightTimeExtractorViewModel()
    @State private var flightsFilterViewModel = FlightsFilterViewModel()
    @State private var frmsViewModel = FRMSViewModel()
    @State private var userDefaultsService = UserDefaultsService()
    @State private var appState = AppState.shared
    @State private var selectedTab: AppTab = .logbook
    @State private var showingOnboarding = false
    @State private var showingOnboardingFlow = false
    @State private var showingMigrationImport = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(PurchaseService.self) private var purchaseService

    private var settingsTabBadge: Int {
        guard !purchaseService.isPro else { return 0 }
        return purchaseService.trialDaysRemaining
    }

    // Determine if we're on iPad in landscape
    private var isIPadLandscape: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        // Both iPad and iPhone now use tab bar navigation
        tabLayout
    }

    // MARK: - Tab Layout (for both iPhone and iPad)
    private var tabLayout: some View {
        TabView(selection: $selectedTab) {
            Tab("Logbook", systemImage: "airplane.departure", value: AppTab.logbook) {
                FlightsSplitView(filterViewModel: flightsFilterViewModel)
                    .environmentObject(viewModel)
            }

            Tab("Dashboard", systemImage: "chart.xyaxis.line", value: AppTab.dashboard) {
                NewDashboardView(frmsViewModel: frmsViewModel)
            }

            Tab("FRMS", systemImage: "clock.badge.checkmark", value: AppTab.frms) {
                FRMSSplitView(flightTimeVM: viewModel, frmsViewModel: frmsViewModel)
            }

            Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                SettingsSplitView(viewModel: viewModel, frmsViewModel: frmsViewModel)
                    .environmentObject(viewModel)
            }
            .badge(settingsTabBadge)
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingWelcomeView(
                onImportFromLogger: {
                    showingOnboarding = false
                    Task {
                        try? await Task.sleep(for: .seconds(0.3))
                        showingMigrationImport = true
                    }
                },
                onSetupManually: {
                    showingOnboarding = false
                    Task {
                        try? await Task.sleep(for: .seconds(0.3))
                        showingOnboardingFlow = true
                    }
                }
            )
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingOnboardingFlow) {
            OnboardingFlowView(
                viewModel: viewModel,
                frmsViewModel: frmsViewModel
            )
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingMigrationImport) {
            MigrationImportView(
                preselectedFileURL: nil,
                onComplete: {
                    userDefaultsService.onboardingCompleted = true
                    showingMigrationImport = false
                },
                isOnboarding: true
            )
            .interactiveDismissDisabled()
        }
        .onAppear {
            // Initialize settings on app launch for both iPhone and iPad
            // This ensures iPad loads saved settings even when AddFlightView is hidden
            viewModel.setupInitialData()

//            #if DEBUG
//            // Reset onboarding flag on every build for testing
//            userDefaultsService.onboardingCompleted = false
//            #endif

            // Show onboarding on first launch (but not if handling a file import)
            if !userDefaultsService.onboardingCompleted && !appState.isHandlingFileImport {
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    showingOnboarding = true
                }
            }
        }
    }
}


#Preview {
    MainTabView()
}
