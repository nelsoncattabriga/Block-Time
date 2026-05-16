---
phase: 01-foundation
plan: 05
subsystem: app-entry
tags: [swiftui, swiftdata, environment, migration, wiring, foundation]
dependency_graph:
  requires: [01-03, 01-04]
  provides: [AppRepositoryEnvironment, OptionalModelContainerModifier, SplashScreen-migration-hook]
  affects: [Block-Time/Block_TimeApp.swift, Block-Time/Views/Screens/SplashScreenView.swift, Block-Time/Infrastructure/AppRepositoryEnvironment.swift, Block-TimeTests/AppEntry/PreviewInMemoryEnvironmentTests.swift]
tech_stack:
  added: []
  patterns: [EnvironmentKey, ViewModifier, static-lazy-init, OptionalModelContainer]
key_files:
  created:
    - Block-Time/Infrastructure/AppRepositoryEnvironment.swift
    - Block-TimeTests/AppEntry/PreviewInMemoryEnvironmentTests.swift
  modified:
    - Block-Time/Views/Screens/SplashScreenView.swift
    - Block-Time/Block_TimeApp.swift
decisions:
  - "OptionalModelContainerModifier wraps .modelContainer() so pre-migration launches (container=nil) leave the view tree unchanged"
  - "productionContainer static lazy reads v2MigrationComplete AND checks hasNoLegacyData — covers both post-migration and fresh-install paths without an explicit flag"
  - "SplashScreenView migration .task runs alongside existing .onAppear (additive) — zero v1 code removed"
  - "Task 4 checkpoint pending — Simulator verification awaiting user response"
metrics:
  duration: "12 minutes"
  completed_date: "2026-05-16"
  tasks_completed: 3
  tasks_total: 4
  files_created: 2
  files_modified: 2
---

# Phase 1 Plan 5: App Entry Point Wiring Summary

One-line: Plans 03 and 04 wired into app entry point — SplashScreenView triggers migration, Block_TimeApp injects CloudKit ModelContainer post-migration, InMemoryFlightRepository injectable for SwiftUI previews (FOUND-12).

## What Was Built

### Task 1 — AppRepositoryEnvironment (FOUND-12)

`Block-Time/Infrastructure/AppRepositoryEnvironment.swift` — SwiftUI `EnvironmentKey` for `FlightRepository` injection.

```swift
private struct FlightRepositoryKey: EnvironmentKey {
    static let defaultValue: any FlightRepository = InMemoryFlightRepository()
}

extension EnvironmentValues {
    var flightRepository: any FlightRepository { ... }
}

extension View {
    func flightRepository(_ repo: any FlightRepository) -> some View {
        environment(\.flightRepository, repo)
    }
}
```

Default value is `InMemoryFlightRepository()` — SwiftUI previews work without a CloudKit account (FOUND-12 satisfied).

`Block-TimeTests/AppEntry/PreviewInMemoryEnvironmentTests.swift` — 2 tests:
- `test_environmentDefault_isInMemoryFlightRepository` — verifies `EnvironmentValues()` returns `InMemoryFlightRepository`
- `test_environmentSetter_acceptsSeededRepo` — verifies setter replaces default and count() returns correct value

### Task 2 — SplashScreenView migration hook

`Block-Time/Views/Screens/SplashScreenView.swift` — additive `.task(priority: .userInitiated)` modifier added to root `ZStack`:

```swift
.task(priority: .userInitiated) {
    let service = CoreDataMigrationService()
    do {
        try await service.runIfNeeded()
    } catch {
        Logger(subsystem: "com.thezoolab.blocktime", category: "Migration.SplashScreen")
            .error("v2 migration failed: \(error.localizedDescription, privacy: .public)")
        // Per D-08: do NOT set isActive = true here.
        // Phase 3 will surface this to the user via a UI alert.
    }
}
```

All existing `.onAppear` blocks (simulatorFlightMigrationV2, aircraftTypeA321ToA21N, simFlightP1Times) preserved verbatim. Zero lines deleted.

### Task 3 — Block_TimeApp ModelContainer injection (D-10)

`Block-Time/Block_TimeApp.swift` additions:

**imports added:** `import SwiftData`, `import os`

**productionContainer static property:**
```swift
private static let productionContainer: ModelContainer? = {
    let migrationComplete = UserDefaults.standard.bool(forKey: "v2MigrationComplete")
    let hasNoLegacyData = !FileManager.default.fileExists(
        atPath: FlightDatabaseService.shared.persistentContainer.persistentStoreCoordinator
            .persistentStores.first?.url?.path ?? ""
    )
    guard migrationComplete || hasNoLegacyData else { return nil }
    do {
        return try ModelContainerFactory.makeProductionContainer()
    } catch {
        Logger(subsystem: "com.thezoolab.blocktime", category: "App.Container")
            .error("Failed to create production ModelContainer: \(error.localizedDescription, privacy: .public)")
        return nil
    }
}()
```

Two conditions allow container creation:
- `v2MigrationComplete = true` — migration ran successfully, relaunch via exit(0) (D-10)
- `hasNoLegacyData` — fresh install with no v1 .sqlite, nothing to migrate

**OptionalModelContainerModifier:**
```swift
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
```

Applied as `.modifier(OptionalModelContainerModifier(container: Self.productionContainer))` after the existing `.environment(\.managedObjectContext, FlightDatabaseService.shared.viewContext)`. The v1 Core Data injection is preserved verbatim. Zero lines deleted.

### Task 4 — Simulator verification (PENDING)

`checkpoint:human-verify` — execution stopped here per protocol. Human verification required before plan can be marked complete.

## Deviations from Plan

None — plan executed exactly as written. All three file modifications are purely additive.

## v1 Core Data Preservation Verification

```
git diff HEAD~2 Block-Time/Views/Screens/SplashScreenView.swift | grep "^-" | grep -vE "^---" | wc -l
→ 0

git diff HEAD~1 Block-Time/Block_TimeApp.swift | grep "^-" | grep -vE "^---" | wc -l
→ 0
```

Both diffs show zero deletions. The existing `.onAppear`, `.task`, `.environment(\.managedObjectContext, ...)`, `FlightDatabaseService.shared`, `ThemeService`, `CloudKitSettingsSyncService`, `PurchaseService`, `AppState`, all sheet presentations, `handleIncomingURL`, `colorSchemeForAppearanceMode` — all preserved.

## Simulator Verification (Task 4 — PENDING)

Awaiting user response. Expected verification paths:

**A — Fresh install (no v1 data):**
1. Erase Simulator → build + run
2. Console.app filter `com.thezoolab.blocktime`
3. Expected: migration logs, exit(0), relaunch, `blocktime.sqlite` at App Group URL
4. `UserDefaults.standard.bool(forKey: "v2MigrationComplete") == true` post-relaunch

**B — v1 data present:**
1. Install v1 → populate flights → update to v2-dev
2. Migration runs → N records → exit(0) → relaunch → v1 UI still works

**C — SwiftUI preview (FOUND-12):**
1. Preview with `.flightRepository(InMemoryFlightRepository())` renders without CloudKit

## Phase 1 Closing Note

This plan closes the Phase 1 loop. All 5 plans:
- 01-01: BlockTimeKit package (BlockTimeDomain, BlockTimeData, BlockTimeCalculators) + Flight struct
- 01-02: TimeStringConverter utility (app target, D-03)
- 01-03: FlightModel @Model, ModelContainerFactory, SwiftDataFlightRepository
- 01-04: CoreDataMigrationService, CoreDataMigrationActor, LegacyFlightSnapshot, MigrationError
- 01-05: App wiring — SplashScreen migration hook, Block_TimeApp ModelContainer injection, FlightRepository environment

FOUND-01 through FOUND-12 status (pending Task 4 Simulator verification):
- FOUND-01 (VersionedSchema): SchemaV1 enum defined in FlightModel.swift — DONE
- FOUND-02 (App Group URL): ModelContainerFactory.appGroupStoreURL() + productionContainer — DONE
- FOUND-03 (CloudKit all-optional): All FlightModel properties optional — DONE
- FOUND-04 (no @Attribute unique): Not used in FlightModel — DONE
- FOUND-05 (FlightRepository protocol): BlockTimeData.FlightRepository — DONE
- FOUND-06 (SwiftDataFlightRepository): App target — DONE
- FOUND-07 (InMemoryFlightRepository): BlockTimeData — DONE
- FOUND-08 (App Group pinned): ModelConfiguration(url: storeURL) — DONE
- FOUND-09 (one-time migration): CoreDataMigrationService — DONE
- FOUND-10 (LegacyFlightSnapshot): Sendable DTO — DONE
- FOUND-11 (background thread write): Task.detached + CoreDataMigrationActor — DONE
- FOUND-12 (preview injection): AppRepositoryEnvironment EnvironmentKey — DONE

## Known Stubs

None. All infrastructure is wired. The `productionContainer` will be `nil` on a v1-data device until migration runs — this is by design (not a stub), and the OptionalModelContainerModifier handles it gracefully.

## Self-Check

Files created:
- Block-Time/Infrastructure/AppRepositoryEnvironment.swift — FOUND
- Block-TimeTests/AppEntry/PreviewInMemoryEnvironmentTests.swift — FOUND

Files modified:
- Block-Time/Views/Screens/SplashScreenView.swift — CONFIRMED (contains CoreDataMigrationService + .task(priority: .userInitiated))
- Block-Time/Block_TimeApp.swift — CONFIRMED (contains import SwiftData, productionContainer, OptionalModelContainerModifier, .managedObjectContext preserved)

Commits:
- 8988890: feat(01-05): add FlightRepository SwiftUI environment for preview injection (FOUND-12)
- e61b350: feat(01-05): trigger v2 migration from SplashScreenView.task (additive, v1 untouched)
- 294417e: feat(01-05): inject production SwiftData ModelContainer alongside existing Core Data env (D-10)

## Self-Check: PASSED
