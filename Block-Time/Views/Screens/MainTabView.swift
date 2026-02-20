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

struct MainTabView: View {
    @StateObject private var viewModel = FlightTimeExtractorViewModel()
    @StateObject private var flightsFilterViewModel = FlightsFilterViewModel()
    @StateObject private var frmsViewModel = FRMSViewModel()
    @StateObject private var userDefaultsService = UserDefaultsService()
    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    @State private var showingOnboardingFlow = false
    @State private var showingMigrationImport = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
            FlightsSplitView(filterViewModel: flightsFilterViewModel)
                .environmentObject(viewModel)
                .tabItem {
                    Image(systemName: "airplane.departure")
                    Text("Logbook")
                }
                .tag(0)

            NavigationStack {
                DashboardView()
                    .environmentObject(viewModel)
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Dashboard")
            }
            .tag(1)

            // FRMS tab
            FRMSSplitView(flightTimeVM: viewModel, frmsViewModel: frmsViewModel)
                .tabItem {
                    Image(systemName: "clock.badge.checkmark")
                    Text("FRMS")
                }
                .tag(2)

            SettingsSplitView(viewModel: viewModel, frmsViewModel: frmsViewModel)
                .environmentObject(viewModel)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)

        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingWelcomeView(
                onImportFromLogger: {
                    showingOnboarding = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingMigrationImport = true
                    }
                },
                onSetupManually: {
                    showingOnboarding = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingOnboarding = true
                }
            }
        }
    }
}


#Preview {
    MainTabView()
}
