//
//  SplashScreenView.swift
//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//
import SwiftUI

struct SplashScreenView: View {
    @Environment(ThemeService.self) private var themeService
    @Environment(PurchaseService.self) private var purchaseService
    @State private var isActive = false
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0.3

    // Constants
    private enum Constants {
        static let iconSize: CGFloat = 280
        static let iconCornerRadius: CGFloat = 140
        static let initialDelay: TimeInterval = 1.0
        static let animationDuration: Double = 1.0
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        //let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "v\(version)" //.\(build)"
    }

    var body: some View {
        ZStack {
            if isActive {
                MainTabView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 10) {
                    if let uiImage = UIImage(named: "SplashIcon") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: Constants.iconCornerRadius))
                    } else {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 120))
                            .foregroundColor(.blue)
                    }

                    Text("Block-Time")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    if !purchaseService.isPro {
                        Text("TRIAL")
                            .font(.headline)
                            .fontWeight(.heavy)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.75), in: Capsule())
                    }

                    Text(appVersion)
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                }
                .scaleEffect(scale)
                .opacity(opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(themeService.getGradient())
        .task {
            // Animate the splash content
            withAnimation(.easeIn(duration: Constants.animationDuration)) {
                scale = 1.0
                opacity = 1.0
            }

            // Wait, then transition to main view
            try? await Task.sleep(nanoseconds: UInt64(Constants.initialDelay * 1_000_000_000))
            withAnimation {
                isActive = true
            }
        }
        .onAppear {
            // One-time migration: legacy customCount integer → counter1 + CustomCounterService definition.
            // Runs synchronously on a background thread before the main view appears.
            // Guard: only runs when logCustomCount was enabled and no new definitions exist yet.
            let legacyCounterMigrationKey = "legacyCounterMigratedToColumn1"
           
//            #if DEBUG
//            UserDefaults.standard.removeObject(forKey: legacyCounterMigrationKey)
//            #endif
            
            if !UserDefaults.standard.bool(forKey: legacyCounterMigrationKey) {
                let logCustomCount = UserDefaults.standard.bool(forKey: "logCustomCount")
                let label = UserDefaults.standard.string(forKey: "customCountLabel") ?? "Passengers"
                if logCustomCount {
                    // 1. Register the definition if not already done (main thread — CustomCounterService is @MainActor)
                    CustomCounterService.shared.migrateLegacyDefinitionIfNeeded(legacyLabel: label)
                    // 2. Swap dashboard card immediately on main thread, before DashboardConfiguration loads.
                    //    Safe to call even if already swapped — swapIfNeeded is a no-op when "customCount" absent.
                    migrateLegacyDashboardCard()
                    // 3. Copy customCount → counter1 on all flight records (background, idempotent)
                    DispatchQueue.global(qos: .utility).async {
                        let count = FlightDatabaseService.shared.migrateLegacyCustomCounterToColumn1()
                        DispatchQueue.main.async {
                            UserDefaults.standard.set(true, forKey: legacyCounterMigrationKey)
                            if count > 0 {
                                NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                            }
                        }
                    }
                } else {
                    // Feature was never enabled — mark done so we skip forever
                    UserDefaults.standard.set(true, forKey: legacyCounterMigrationKey)
                }
            }

            // Run one-time simulator flight migration off the main thread.
            // Moved here from Block_TimeApp.init() to avoid accessing viewContext
            // before the persistent container is ready (caused blank screen on first launch).
            let migrationKey = "simulatorFlightMigrationV2Completed"
            if !UserDefaults.standard.bool(forKey: migrationKey) {
                DispatchQueue.global(qos: .utility).async {
                    let result = FlightDatabaseService.shared.migrateSimulatorFlights()
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: migrationKey)
                        UserDefaults.standard.set(result.migratedCount, forKey: "simulatorFlightMigrationCount")
                        UserDefaults.standard.set(result.summary, forKey: "simulatorFlightMigrationSummary")
                        if result.migratedCount > 0 {
                            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                        }
                    }
                }
            }

            // One-time migration: A321 → A21N for Qantas XLR fleet (OGA–OGG).
            let a21nMigrationKey = "aircraftTypeA321ToA21NMigrationCompleted"
            if !UserDefaults.standard.bool(forKey: a21nMigrationKey) {
                DispatchQueue.global(qos: .utility).async {
                    let result = FlightDatabaseService.shared.migrateAircraftTypeA321ToA21N()
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: a21nMigrationKey)
                        if result.migratedCount > 0 {
                            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                        }
                        LogManager.shared.info("A321→A21N migration: \(result.summary)")
                    }
                }
            }

            // One-time migration: zero out p1/p1us/p2 on SIM flights where they were incorrectly populated.
            let simP1MigrationKey = "simFlightP1TimesMigrationCompleted"
            if !UserDefaults.standard.bool(forKey: simP1MigrationKey) {
                DispatchQueue.global(qos: .utility).async {
                    let count = FlightDatabaseService.shared.migrateSimP1Times()
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: simP1MigrationKey)
                        if count > 0 {
                            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                        }
                    }
                }
            }
        }
    }
}

/// Replaces the legacy "customCount" card ID with "customCounter.1" in the persisted
/// sidebar and detail layout arrays. Operates directly on UserDefaults JSON so it runs
/// before DashboardConfiguration is instantiated — no instance reference needed.
private func migrateLegacyDashboardCard() {
    let sidebarKey = "insightsSidebarCards2"
    let detailKey  = "insightsDetailCards2"
    let legacyRaw  = "customCount"
    let newRaw     = "customCounter.1"

    func swapIfNeeded(key: String) {
        guard let data = UserDefaults.standard.data(forKey: key),
              var ids = try? JSONDecoder().decode([String].self, from: data),
              let idx = ids.firstIndex(of: legacyRaw) else { return }
        ids[idx] = newRaw
        if let updated = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(updated, forKey: key)
        }
    }

    swapIfNeeded(key: sidebarKey)
    swapIfNeeded(key: detailKey)
}

#Preview {
    SplashScreenView()
}
