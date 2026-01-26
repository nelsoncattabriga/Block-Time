//
//  Block_TimeApp.swift
//  Block-Time
//
//  Created by Nelson on 26/8/2025.
//

import SwiftUI

@main
struct Block_TimeApp: App {
    @State private var incomingRosterURL: URL?
    @State private var incomingMigrationURL: URL?
    @ObservedObject private var themeService = ThemeService.shared
    @ObservedObject private var appState = AppState.shared

    init() {
        // Reset debug mode to off every app launch
        UserDefaults.standard.set(false, forKey: "debugModeEnabled")

        // Run one-time simulator flight migration
        performSimulatorFlightMigration()
    }

    private func performSimulatorFlightMigration() {
        let migrationKey = "simulatorFlightMigrationCompleted"

        // Check if migration already completed
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            LogManager.shared.debug("Simulator flight migration already completed")
            return
        }

        LogManager.shared.info("Running simulator flight migration...")
        let result = FlightDatabaseService.shared.migrateSimulatorFlights()

        // Store results
        UserDefaults.standard.set(true, forKey: migrationKey)
        UserDefaults.standard.set(result.migratedCount, forKey: "simulatorFlightMigrationCount")
        UserDefaults.standard.set(result.summary, forKey: "simulatorFlightMigrationSummary")

        LogManager.shared.info("Simulator flight migration complete: \(result.migratedCount) flights migrated")

        // Post notification to refresh views if any flights were migrated
        if result.migratedCount > 0 {
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .preferredColorScheme(colorSchemeForAppearanceMode(themeService.appearanceMode))
                .environment(\.managedObjectContext, FlightDatabaseService.shared.viewContext)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .sheet(item: Binding(
                    get: { incomingRosterURL.map { URLWrapper(url: $0) } },
                    set: { incomingRosterURL = $0?.url }
                )) { wrapper in
                    UnifiedRosterImportView(preselectedFileURL: wrapper.url)
                }
                .sheet(item: Binding(
                    get: { incomingMigrationURL.map { URLWrapper(url: $0) } },
                    set: { incomingMigrationURL = $0?.url }
                )) { wrapper in
                    MigrationImportView(
                        preselectedFileURL: wrapper.url,
                        onComplete: {
                            // Mark onboarding as complete and reset file handling flag
                            UserDefaultsService().onboardingCompleted = true
                            appState.isHandlingFileImport = false
                        },
                        onDismiss: {
                            // Reset file handling flag if user cancels
                            appState.isHandlingFileImport = false
                        },
                        isOnboarding: true
                    )
                }
        }
    }

    private func colorSchemeForAppearanceMode(_ mode: AppearanceMode) -> ColorScheme? {
        switch mode {
        case .system:
            return nil  // nil means follow system setting
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private func handleIncomingURL(_ url: URL) {
        let fileExtension = url.pathExtension.lowercased()

        // Check if it's a migration file
        if fileExtension == "blocktime" {
            LogManager.shared.info("📥 Received .blocktime migration file: \(url.lastPathComponent)")
            appState.isHandlingFileImport = true
            incomingMigrationURL = url
            return
        }

        // Check if the file is a text file (roster)
        if fileExtension == "txt" || url.pathExtension.isEmpty {
            incomingRosterURL = url
        }
    }
}

// Helper wrapper to make URL identifiable for sheet presentation
private struct URLWrapper: Identifiable {
    let id = UUID()
    let url: URL
}
