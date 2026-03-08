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
    @State private var themeService = ThemeService.shared
    @State private var cloudKitService = CloudKitSettingsSyncService.shared
    @State private var purchaseService = PurchaseService.shared
    @ObservedObject private var appState = AppState.shared

    init() {
        // Reset debug mode to off every app launch
        UserDefaults.standard.set(false, forKey: "debugModeEnabled")

    #if DEBUG
//        PurchaseService.shared.resetToFreshInstall() // fresh trial

//          PurchaseService.shared.resetTrialForTesting()            // expired — shows paywall
//          PurchaseService.shared.resetTrialForTesting(daysRemaining: 3)  // red badge, warning icon
          PurchaseService.shared.resetTrialForTesting(daysRemaining: 7)  // orange badge
//          PurchaseService.shared.resetTrialForTesting(daysRemaining: 15) // blue badge, normal state

    #endif
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .task {
                    await purchaseService.listenForTransactions()
                }
                .preferredColorScheme(colorSchemeForAppearanceMode(themeService.appearanceMode))
                .environment(themeService)
                .environment(cloudKitService)
                .environment(purchaseService)
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
