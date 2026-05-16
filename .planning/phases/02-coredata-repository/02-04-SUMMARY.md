---
phase: 02-coredata-repository
plan: 04
subsystem: database
tags: [coredata, swiftdata-deletion, repository, app-entry, cleanup]

requires:
  - phase: 02-03
    provides: [CoreDataFlightRepository]

provides:
  - All SwiftData infrastructure deleted from app target
  - Block_TimeApp injects CoreDataFlightRepository via .flightRepository()
  - One-shot orphan cleanup of Phase 1 blocktime.sqlite on first launch
  - SplashScreenView migration trigger removed

affects: [03-calculators]

tech-stack:
  added: []
  patterns:
    - "Orphan cleanup via guarded UserDefaults flag in App.init()"
    - "CoreDataFlightRepository injected at WindowGroup root via .flightRepository()"

key-files:
  created: []
  modified:
    - Block-Time/Block_TimeApp.swift
    - Block-Time/Views/Screens/SplashScreenView.swift
    - Block-Time/Infrastructure/AppRepositoryEnvironment.swift
    - Block-Time/Services/WidgetDataWriter.swift
    - Block-Time/ViewModels/FlightMapViewModel.swift
    - Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
  deleted:
    - Block-Time/Models/SchemaV1.swift (18 lines)
    - Block-Time/Models/FlightModel.swift (90 lines)
    - Block-Time/Models/AircraftModel.swift (31 lines)
    - Block-Time/Infrastructure/ModelContainerFactory.swift (62 lines)
    - Block-Time/Migration/CoreDataMigrationService.swift (282 lines)
    - Block-Time/Migration/CoreDataMigrationActor.swift (129 lines)
    - Block-Time/Migration/LegacyFlightSnapshot.swift (95 lines)
    - Block-Time/Repositories/SwiftDataFlightRepository.swift (181 lines)

key-decisions:
  - "App Group ID confirmed as group.com.thezoolab.blocktime — matches Block-Time.entitlements"
  - "UserDefaults flag phase2OrphanCleanupDone guards the one-shot orphan cleanup"
  - "AppRepositoryEnvironment stale SwiftDataFlightRepository comments updated to CoreDataFlightRepository"
  - "FlightDatabaseService.swift has 98 pre-existing V2 schema errors — deferred to Phase 4 (god object breakup)"

metrics:
  duration: ~45min
  completed: 2026-05-16T12:43:00Z
  tasks_completed: 4
  tasks_total: 5
  files_modified: 6
  files_deleted: 8
---

# Phase 2 Plan 04: SwiftData Deletion and App Wiring — Summary (PARTIAL — Task 5 checkpoint pending)

**8 SwiftData infrastructure files deleted, Block_TimeApp rewired to inject CoreDataFlightRepository, SplashScreenView migration trigger removed, one-shot orphan cleanup added.**

## Status

Tasks 1-4 complete and committed. Task 5 is a checkpoint:human-verify — awaiting Nelson's simulator verification.

## Performance

- **Started:** ~2026-05-16T12:29:00Z
- **Completed (partial):** 2026-05-16T12:43:00Z
- **Duration:** ~45 min
- **Tasks completed:** 4 of 5
- **Files deleted:** 8 (888 total lines)
- **Files modified:** 6

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Delete 8 SwiftData infrastructure files | a1880cc | 8 files deleted (888 lines) |
| 2 | Rewire Block_TimeApp | 4b039f3 | Block_TimeApp.swift |
| 3 | Remove migration trigger from SplashScreenView | 017a5c8 | SplashScreenView.swift |
| 4 | Verify AppRepositoryEnvironment (stale comments fixed) | 6d69645 | AppRepositoryEnvironment.swift |
| 4-dev | Fix V2 schema type errors in 3 consumer files | 8b9aa89 | WidgetDataWriter, FlightMapViewModel, FlightTimeExtractorViewModel |
| 5 | Human-verify first-launch migration on simulator | PENDING | — |

## Deleted Files (with line counts at deletion time)

| File | Lines |
|------|-------|
| Block-Time/Models/SchemaV1.swift | 18 |
| Block-Time/Models/FlightModel.swift | 90 |
| Block-Time/Models/AircraftModel.swift | 31 |
| Block-Time/Infrastructure/ModelContainerFactory.swift | 62 |
| Block-Time/Migration/CoreDataMigrationService.swift | 282 |
| Block-Time/Migration/CoreDataMigrationActor.swift | 129 |
| Block-Time/Migration/LegacyFlightSnapshot.swift | 95 |
| Block-Time/Repositories/SwiftDataFlightRepository.swift | 181 |
| **Total** | **888** |

Preserved (NOT deleted):
- `Block-Time/Migration/MigrationError.swift` — may be used elsewhere
- `Block-Time/Migration/TimeStringConverter.swift` — Phase 3 calculator use

## Block_TimeApp.init() Orphan Cleanup Block (as committed)

```swift
// D-03/D-04: One-shot orphan cleanup — delete Phase 1 SwiftData store and stale migration flags.
if !UserDefaults.standard.bool(forKey: "phase2OrphanCleanupDone") {
    if let appGroupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.thezoolab.blocktime"
    ) {
        for suffix in ["", "-shm", "-wal"] {
            let url = appGroupURL.appendingPathComponent("blocktime.sqlite" + suffix)
            try? FileManager.default.removeItem(at: url)
        }
    }
    // D-04: clear stale Phase 1 migration flags
    UserDefaults.standard.removeObject(forKey: "v2MigrationStarted")
    UserDefaults.standard.removeObject(forKey: "v2MigrationComplete")
    UserDefaults.standard.set(true, forKey: "phase2OrphanCleanupDone")
}
```

**App Group identifier used:** `group.com.thezoolab.blocktime` — confirmed from `Block-Time/Block-Time.entitlements` `com.apple.security.application-groups` key.

## Task 4 — AppRepositoryEnvironment Outcome

Required a minimal correction: two comment lines referenced `SwiftDataFlightRepository` (now deleted). Updated to reference `CoreDataFlightRepository`. No functional code changed. `defaultValue` remains `InMemoryFlightRepository()` (D-25 satisfied).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] WidgetDataWriter.swift — scheduledDeparture/Arrival type change**
- **Found during:** Build verification after Task 4
- **Issue:** `buildDatetime(flightDate:, timeString:)` expected `String?` but V2 FlightEntity has `scheduledDeparture: Date?`
- **Fix:** Use `entity.scheduledDeparture` and `entity.scheduledArrival` directly as `Date?` — no string parsing needed since they're full UTC timestamps
- **Files modified:** Block-Time/Services/WidgetDataWriter.swift
- **Commit:** 8b9aa89

**2. [Rule 3 - Blocking] FlightMapViewModel.swift — blockTime type change**
- **Found during:** Build verification after Task 4
- **Issue:** Tuple typed `[(from: String, to: String, blockTime: String)]` with `entity.blockTime ?? ""` — V2 has `blockTime: Int16`
- **Fix:** Changed tuple type to use `Int16`, updated guard to `pair.blockTime > 0` (direct numeric comparison)
- **Files modified:** Block-Time/ViewModels/FlightMapViewModel.swift
- **Commit:** 8b9aa89

**3. [Rule 3 - Blocking] FlightTimeExtractorViewModel.swift — scheduledDeparture/Arrival pre-fill**
- **Found during:** Build verification after Task 4
- **Issue:** Pre-fill code used `scheduledFlight.scheduledDeparture` as `String?` with `.isEmpty` — now `Date?`
- **Fix:** Added `utcHHmm(from:)` static helper to format `Date` as "HH:mm" UTC string for the ViewModel's String field
- **Files modified:** Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
- **Commit:** 8b9aa89

### Build Status — NOT GREEN (pre-existing deferred errors)

The plan's assumption that "the 118 build errors disappear after Task 1" was incorrect. Those 118 errors were always in `FlightDatabaseService.swift` and `FlightDatabaseService+InsightsQueries.swift` — previously hidden because the compiler stopped at SwiftData import failures before reaching these files.

**98 remaining errors in FlightDatabaseService.swift + InsightsQueries.swift:**
- All are V2 schema type mismatches: `entity.blockTime` (now `Int16`) used where `String?` expected, and vice versa
- NSPredicates still use String comparisons for time fields
- `safeDoubleFromString(flight.blockTime)` calls — blockTime no longer String?
- `entity.scheduledDeparture` (now `Date?`) used as `String?`

These errors predate plan 02-04 — they were introduced in plan 02-02 (V2 schema changes) and require the Phase 4 god object breakup to address properly. Fixing them inline in this 3686-line file would exceed the scope of this plan.

## Known Stubs

None — no UI components created in this plan.

## Deferred Items

See `.planning/phases/02-coredata-repository/deferred-items.md`:
- `FlightDatabaseService.swift` — 60+ V2 schema errors (Int16/Date type mismatches) — Phase 4
- `FlightDatabaseService+InsightsQueries.swift` — 38+ V2 schema errors — Phase 4

## Self-Check: PARTIAL

- Task 1: All 8 files confirmed deleted — CONFIRMED
- Task 2: Block_TimeApp.swift acceptance criteria — all CONFIRMED
- Task 3: SplashScreenView.swift acceptance criteria — all CONFIRMED
- Task 4: AppRepositoryEnvironment.swift — CONFIRMED (stale comments fixed)
- Build: NOT GREEN — 98 pre-existing FlightDatabaseService errors remain
- Task 5: PENDING checkpoint verification

---
*Phase: 02-coredata-repository*
*Status: Tasks 1-4 committed; checkpoint:human-verify pending for Task 5*
