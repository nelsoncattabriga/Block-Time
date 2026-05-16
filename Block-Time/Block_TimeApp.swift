//
//  Block_TimeApp.swift
//  Block-Time
//
//  Created by Nelson on 26/8/2025.
//

import SwiftUI
import SwiftData
import CoreData
import WidgetKit
import os

@main
struct Block_TimeApp: App {
    @State private var incomingRosterURL: URL?
    @State private var incomingMigrationURL: URL?
    @State private var themeService = ThemeService.shared
    @State private var cloudKitService = CloudKitSettingsSyncService.shared
    @State private var purchaseService = PurchaseService.shared
    @ObservedObject private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Reset debug mode to off every app launch
        UserDefaults.standard.set(false, forKey: "debugModeEnabled")
        // Warm AirportService on a background thread so its airports.dat parse
        // doesn't block the main thread when FlightTimeExtractorViewModel first accesses it.
        DispatchQueue.global(qos: .userInitiated).async { _ = AirportService.shared }

    #if DEBUG
          PurchaseService.shared.grantProForTesting()
//          PurchaseService.shared.resetToFreshInstall()             // fresh trial
//          PurchaseService.shared.resetTrialForTesting()            // expired — shows paywall
//          PurchaseService.shared.resetTrialForTesting(daysRemaining: 3)  // red badge, warning icon
//          PurchaseService.shared.resetTrialForTesting(daysRemaining: 7)  // orange badge
//          PurchaseService.shared.resetTrialForTesting(daysRemaining: 15) // blue badge, normal state

    #endif
    }

    /// Production SwiftData container. Created lazily so a v1-only launch (before migration has completed)
    /// does NOT try to open a SwiftData store that has not yet been written. After migrationComplete=true,
    /// exit(0) forces a relaunch and this property is then initialised cleanly.
    /// On a fresh install (no v1 data), this initialises on first access too — there's nothing to migrate.
    private static let productionContainer: ModelContainer? = {
        let migrationComplete = UserDefaults.standard.bool(forKey: "v2MigrationComplete")
        let hasNoLegacyData = !FileManager.default.fileExists(
            atPath: FlightDatabaseService.shared.persistentContainer.persistentStoreCoordinator
                .persistentStores.first?.url?.path ?? ""
        )
        // Create the production (CloudKit) container if migration is complete, OR if there is no v1 data
        // to migrate (fresh install). If neither, we are pre-migration on a v1-data device and the
        // SplashScreenView will run migration + exit(0) before this is ever consumed.
        guard migrationComplete || hasNoLegacyData else { return nil }
        do {
            return try ModelContainerFactory.makeProductionContainer()
        } catch {
            Logger(subsystem: "com.thezoolab.blocktime", category: "App.Container")
                .error("Failed to create production ModelContainer: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }()

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .task {
                    await purchaseService.listenForTransactions()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { @MainActor in
                            WidgetDataWriter.shared.updateWidgetSnapshot()
                        }
                    }
                }
                .preferredColorScheme(colorSchemeForAppearanceMode(themeService.appearanceMode))
                .environment(themeService)
                .environment(cloudKitService)
                .environment(purchaseService)
                .environment(\.managedObjectContext, FlightDatabaseService.shared.viewContext)
                .modifier(OptionalModelContainerModifier(container: Self.productionContainer))
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
        // Handle blocktime:// deep link scheme (widget deep links)
        if url.scheme == "blocktime" {
            if url.host == "add-flight" {
                let capture = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.contains(where: { $0.name == "capture" && $0.value == "true" }) ?? false
                if capture {
                    AppState.shared.triggerCamera = true
                }
                AppState.shared.pendingAddFlight = true
                NotificationCenter.default.post(name: capture ? .openAddFlightCapture : .openAddFlight, object: nil)
            }
            return
        }

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

/// Conditionally applies `.modelContainer()` only when a container is available.
/// When `container` is `nil` (pre-migration, v1-data device), the view is returned unchanged —
/// the UI continues to use Core Data via the existing `.managedObjectContext` environment key.
private struct OptionalModelContainerModifier: ViewModifier {
    let container: ModelContainer?
    func body(content: Content) -> some View {
        if let container {
            content.modelContainer(container)
        } else {
            content
        }
    }
}

// Helper wrapper to make URL identifiable for sheet presentation.
// Using the URL's absolute string as the id ensures that re-evaluating
// the sheet Binding's get closure doesn't produce a new id, which would
// cause SwiftUI to dismiss and re-present the sheet mid-animation.
private struct URLWrapper: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
