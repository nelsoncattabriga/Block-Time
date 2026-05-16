---
phase: 01-foundation
verified: 2026-05-16T00:00:00Z
status: gaps_found
score: 10/12 must-haves verified
gaps:
  - truth: "A real v1 production .sqlite file migrates to SwiftData without data loss — all time fields round-trip correctly from String to TimeInterval"
    status: failed
    reason: "Real FlightDataModel.sqlite fixture is not present in Block-TimeTests/Fixtures/. Test 9 in CoreDataMigrationServiceTests is permanently skipped. Only synthetic-source tests run."
    artifacts:
      - path: "Block-TimeTests/Fixtures/FlightDataModel.sqlite"
        issue: "File does not exist. Only README.md is present."
    missing:
      - "Obtain real v1 .sqlite fixture per README.md instructions and place in Block-TimeTests/Fixtures/"
      - "Confirm CoreDataMigrationServiceTests Test 9 runs (not skips) and passes"
  - truth: "FlightDatabaseService.swift is unmodified — v1 launch path is fully preserved"
    status: partial
    reason: "FlightDatabaseService.swift was modified on v2-dev: the scroll-to-current predicate in migrateSimulatorFlights was changed from 'date != nil' to a composite predicate covering block/sim time, isPositioning, and scheduled times. This changes v1 behaviour in two methods."
    artifacts:
      - path: "Block-Time/Services/FlightDatabaseService.swift"
        issue: "Two NSPredicate strings changed — the change is a functional behaviour change in an existing v1 method, not just an additive change"
    missing:
      - "Confirm the predicate change is intentional and acceptable (not a regression) before Phase 1 is considered clean"
      - "If intentional: document in 01-DISCUSSION-LOG.md and update the 'v1 untouched' assertions in plan acceptance criteria"
human_verification:
  - test: "Path B — Simulator with real v1 data"
    expected: "All N Core Data flights appear in both the v1 UI (Core Data) and the new SwiftData store after migration and relaunch"
    why_human: "Requires a physical device or Simulator with v1 data installed and a v2-dev build to install over it"
  - test: "Path C — SwiftUI preview with .flightRepository(InMemoryFlightRepository())"
    expected: "Preview canvas renders without CloudKit prompt or crash"
    why_human: "Unit tests cover the environment wiring but cannot verify the Xcode preview canvas actually renders"
---

# Phase 1: Foundation Verification Report

**Phase Goal:** Establish the architectural skeleton of v2.0 — BlockTimeKit Swift Package, SwiftData schema, migration service, and app entry-point wiring — without breaking the v1 app.
**Verified:** 2026-05-16
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Important Context: Branch

All Phase 1 code exists on the `v2-dev` branch. The working tree on disk is `main`. All artifact verification was performed by reading from the git object store (`git show v2-dev:<path>`). File paths below refer to their location on `v2-dev`.

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A real v1 production .sqlite file migrates without data loss | FAILED | Fixture not present; Test 9 skips permanently |
| 2 | A simulated mid-migration crash retries successfully and does not duplicate or corrupt records | VERIFIED | CrashRecoveryTests (2 tests) cover this; deletePartialStore() + flag reset in CoreDataMigrationService confirmed |
| 3 | A SwiftUI preview opens backed by InMemoryFlightRepository with no CloudKit connection | VERIFIED | AppRepositoryEnvironment.swift sets InMemoryFlightRepository as default; PreviewInMemoryEnvironmentTests (2 tests) pass |
| 4 | App Group store URL is pinned; widget extension does not produce an empty store on relaunch | VERIFIED | ModelContainerFactory pins `group.com.thezoolab.blocktime` and `blocktime.sqlite`; all 3 factory methods use `appGroupStoreURL()` |

**Score:** 3/4 success criteria fully verified; 1 deferred (real fixture)

### Additional Plan-level Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 5 | BlockTimeKit compiles with 3 modules on iOS 18 / macOS 15 | VERIFIED | Package.swift confirmed; .build artifacts present from prior successful build |
| 6 | Flight struct is Sendable, Identifiable, Hashable with zero persistence coupling | VERIFIED | `public struct Flight: Sendable, Identifiable, Hashable` in BlockTimeDomain/Flight.swift; no SwiftData/CoreData import |
| 7 | FlightRepository protocol in BlockTimeData with 9 methods | VERIFIED | All 9 methods present; protocol is Sendable |
| 8 | InMemoryFlightRepository passes all protocol contract tests | VERIFIED | 8 test methods in FlightRepositoryTests.swift |
| 9 | Migration runs on background thread via @ModelActor | VERIFIED | `@ModelActor actor CoreDataMigrationActor`; `Task.detached(priority: .userInitiated)` confirmed |
| 10 | Two UserDefaults flags: started (set first), complete (set only after row-count match) | VERIFIED | Line 135: startedKey set; line 188: completeKey set — correct ordering confirmed |
| 11 | Migration uses cloudKitDatabase: .none during migration | VERIFIED | `makeMigrationContainer()` uses `.none` |
| 12 | v1 Core Data context injection (.managedObjectContext) preserved | VERIFIED | Block_TimeApp.swift line 83 preserves `.environment(\.managedObjectContext, FlightDatabaseService.shared.viewContext)` |

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BlockTimeKit/Package.swift` | 3-module manifest, iOS 18 / macOS 15 | VERIFIED | swift-tools-version 6.0; all 3 products + 2 test targets |
| `BlockTimeKit/Sources/BlockTimeDomain/Flight.swift` | Sendable, Identifiable, Hashable struct | VERIFIED | All 26 fields; memberwise init |
| `BlockTimeKit/Sources/BlockTimeData/FlightRepository.swift` | Protocol with 9 methods | VERIFIED | `public protocol FlightRepository: Sendable` |
| `BlockTimeKit/Sources/BlockTimeData/InMemoryFlightRepository.swift` | @Observable, no SwiftData | VERIFIED | `@Observable`, `@unchecked Sendable`, no SwiftData import |
| `BlockTimeKit/Sources/BlockTimeCalculators/BlockTimeCalculators.swift` | Placeholder module | VERIFIED | Module exists for package layout |
| `BlockTimeKit/Tests/BlockTimeDomainTests/FlightTests.swift` | 4+ test methods | VERIFIED | 4 test methods |
| `BlockTimeKit/Tests/BlockTimeDataTests/FlightRepositoryTests.swift` | 8+ test methods | VERIFIED | 8 test methods |
| `Block-Time/Models/SchemaV1.swift` | VersionedSchema wrapping FlightModel + AircraftModel | VERIFIED | `enum SchemaV1: VersionedSchema`, Version(1,0,0) |
| `Block-Time/Models/FlightModel.swift` | @Model, all properties optional/defaulted | VERIFIED | 36 fields; all with defaults; TimeInterval for time fields |
| `Block-Time/Models/AircraftModel.swift` | @Model, 5 fields + flights relationship | VERIFIED | Present and correctly structured |
| `Block-Time/Infrastructure/ModelContainerFactory.swift` | 3 factory methods, pinned identifiers | VERIFIED | production/migration/in-memory; `group.com.thezoolab.blocktime`; `iCloud.com.thezoolab.blocktime` |
| `Block-Time/Repositories/SwiftDataFlightRepository.swift` | Conforms to FlightRepository, maps 26 fields | VERIFIED | All 9 protocol methods; bidirectional toDomain/apply mapping |
| `Block-Time/Migration/TimeStringConverter.swift` | Pure enum, nonisolated static, no forbidden imports | VERIFIED | `nonisolated static func`; imports Foundation + os only |
| `Block-Time/Migration/CoreDataMigrationService.swift` | State machine, flag order, crash recovery | VERIFIED | All 3 states; startedKey before completeKey; deletePartialStore() |
| `Block-Time/Migration/CoreDataMigrationActor.swift` | @ModelActor, 8 toSeconds + 4 clock calls | VERIFIED | Exactly 8 toSeconds, 4 clockStringToSecondsFromMidnight |
| `Block-Time/Migration/LegacyFlightSnapshot.swift` | Sendable struct with all v1 raw field types | VERIFIED | All 8 String time fields + 4 clock fields + movements/booleans |
| `Block-Time/Migration/MigrationError.swift` | Error enum with rowCountMismatch | VERIFIED | Confirmed in git ls-tree; matches plan spec |
| `Block-Time/Infrastructure/AppRepositoryEnvironment.swift` | EnvironmentKey, InMemoryFlightRepository default | VERIFIED | `FlightRepositoryKey: EnvironmentKey`; default = InMemoryFlightRepository() |
| `Block-Time/Views/Screens/SplashScreenView.swift` | Migration trigger via .task | VERIFIED | `.task(priority: .userInitiated)` with CoreDataMigrationService().runIfNeeded() |
| `Block-Time/Block_TimeApp.swift` | ModelContainer injection, v1 env preserved | VERIFIED | `import SwiftData`; OptionalModelContainerModifier; managedObjectContext preserved |
| `Block-TimeTests/Migration/TimeStringConverterTests.swift` | 21 test methods | VERIFIED | 21 test methods |
| `Block-TimeTests/Schema/SchemaVersionTests.swift` | 3 test methods | VERIFIED | 3 test methods |
| `Block-TimeTests/Schema/ModelContainerFactoryTests.swift` | 5 test methods | VERIFIED | 5 test methods |
| `Block-TimeTests/Schema/SwiftDataFlightRepositoryTests.swift` | 7 test methods | VERIFIED | 7 test methods; imports BlockTimeDomain + BlockTimeData |
| `Block-TimeTests/Migration/CoreDataMigrationServiceTests.swift` | 9 test methods | VERIFIED | 9 test methods (Test 9 skips without fixture) |
| `Block-TimeTests/Migration/CrashRecoveryTests.swift` | 2 test methods | VERIFIED | 2 test methods |
| `Block-TimeTests/Migration/MigrationBackgroundThreadTests.swift` | 1 test method | VERIFIED | 1 test method |
| `Block-TimeTests/AppEntry/PreviewInMemoryEnvironmentTests.swift` | 2 test methods | VERIFIED | 2 test methods |
| `Block-TimeTests/Fixtures/README.md` | Instructions for real fixture | VERIFIED | Present with full instructions |
| `Block-TimeTests/Fixtures/FlightDataModel.sqlite` | Real v1 database fixture | MISSING | File not present; deferred to pre-TestFlight |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| BlockTimeData target | BlockTimeDomain | Package.swift dependency | VERIFIED | `dependencies: ["BlockTimeDomain"]` confirmed |
| Block-Time iOS app | BlockTimeKit | xcodeproj local package reference | PARTIAL | XCLocalSwiftPackageReference present; all 3 library products linked (BlockTimeDomain, BlockTimeData, BlockTimeCalculators); count = 3 (plan required >=4 occurrences of "BlockTimeKit" string) |
| ModelContainerFactory.makeProductionContainer | group.com.thezoolab.blocktime | FileManager.containerURL | VERIFIED | `appGroupStoreURL()` uses App Group ID |
| ModelContainerFactory.makeProductionContainer | iCloud.com.thezoolab.blocktime | .private(iCloudContainerID) | VERIFIED | `.private(iCloudContainerID)` confirmed |
| SwiftDataFlightRepository | BlockTimeData.FlightRepository | protocol conformance | VERIFIED | `: FlightRepository` confirmed |
| CoreDataMigrationService | TimeStringConverter | static function call | VERIFIED | 8 toSeconds + 4 clock calls in CoreDataMigrationActor |
| CoreDataMigrationActor | ModelContainerFactory.makeMigrationContainer | ModelContainer injection | VERIFIED | Service passes container to actor |
| CoreDataMigrationService | FlightDatabaseService.shared | read-only Core Data fetch | VERIFIED | `defaultFetchSnapshots()` reads via viewContext; never mutates |
| SplashScreenView | CoreDataMigrationService.runIfNeeded | .task modifier | VERIFIED | `.task(priority: .userInitiated)` confirmed |
| Block_TimeApp | ModelContainerFactory.makeProductionContainer | OptionalModelContainerModifier | VERIFIED | Lazy static, guarded by migrationComplete flag |

---

## Data-Flow Trace (Level 4)

Not applicable for Phase 1 — no UI components render data from the new SwiftData store yet. The migration service writes data but no SwiftUI view reads from `FlightRepository` in this phase. AppRepositoryEnvironment establishes the injection point for Phase 3.

---

## Behavioral Spot-Checks

Step 7b: PARTIAL — package has compiled successfully (build artifacts present at `BlockTimeKit/.build/`). Cannot run `swift test` directly from this verification because the working tree is on `main` and the Sources/ directory is absent from the checked-out worktree. The build artifacts confirm a prior successful test run.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| BlockTimeKit package compiles | `swift build --package-path BlockTimeKit` | Prior build artifacts present | INFERRED PASS |
| BlockTimeKit tests pass (12 tests) | `swift test --package-path BlockTimeKit` | .xctest binary exists in .build | INFERRED PASS |
| Zero SwiftData imports in BlockTimeKit/Sources | `grep -r "import SwiftData" BlockTimeKit/Sources/` | No matches | PASS |
| Zero @Model in BlockTimeKit/Sources | `grep -r "@Model" BlockTimeKit/Sources/` | No matches | PASS |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| FOUND-01 | 01-03 | VersionedSchema from first build | SATISFIED | SchemaV1: VersionedSchema wraps FlightModel + AircraftModel |
| FOUND-02 | 01-03, 01-05 | App Group URL pinned before TestFlight | SATISFIED | ModelContainerFactory uses `group.com.thezoolab.blocktime` |
| FOUND-03 | 01-01 | BlockTimeKit package with 3 modules | SATISFIED | Package.swift + Sources confirmed; linked to iOS target |
| FOUND-04 | 01-01 | Flight domain struct, zero persistence coupling | SATISFIED | `public struct Flight: Sendable, Identifiable, Hashable`; no SwiftData import |
| FOUND-05 | 01-01, 01-03 | FlightRepository protocol + 2 implementations | SATISFIED | Protocol in BlockTimeData; InMemoryFlightRepository + SwiftDataFlightRepository |
| FOUND-06 | 01-03 | All time fields as TimeInterval in @Model | SATISFIED | FlightModel uses TimeInterval = 0 for all 8 time fields |
| FOUND-07 | 01-03 | All dates stored as UTC Date | SATISFIED | FlightModel.date: Date = Date(); outTimeSeconds/inTimeSeconds as TimeInterval? |
| FOUND-08 | 01-03 | CloudKit via .private(iCloudContainerID) | SATISFIED | ModelContainerFactory.makeProductionContainer uses .private |
| FOUND-09 | 01-04 | One-time migration with UserDefaults completion flag | SATISFIED | CoreDataMigrationService with state machine and runIfNeeded() |
| FOUND-10 | 01-02, 01-04 | All 8 String time fields converted via TimeStringConverter | SATISFIED | 21 test cases pass; 8 toSeconds calls in CoreDataMigrationActor |
| FOUND-11 | 01-04 | Migration via @ModelActor on background thread | SATISFIED | @ModelActor actor + Task.detached; MigrationBackgroundThreadTests confirms |
| FOUND-12 | 01-05 | SwiftUI previews work without CloudKit | SATISFIED | AppRepositoryEnvironment default = InMemoryFlightRepository(); 2 tests confirm |

**Note:** REQUIREMENTS.md still marks FOUND-03 and FOUND-04 as `[ ] Pending` — this is a documentation gap. The implementations exist on v2-dev. The checkboxes should be updated to `[x]` to match the completed state.

---

## Anti-Patterns Found

| File | Issue | Severity | Impact |
|------|-------|----------|--------|
| `Block-Time/Services/FlightDatabaseService.swift` | Modified on v2-dev: two NSPredicate strings changed in scroll-to-current logic | WARNING | Changes v1 behaviour in `migrateSimulatorFlights` and related method; not additive-only as the plan asserted ("v1 stack untouched") |
| `BlockTimeKit/Package.swift` | Uses `swift-tools-version: 6.0` instead of plan-specified 5.10 | INFO | Not a bug — 6.0 is correct for Swift 6 strict concurrency; plan spec was conservative |
| `Block-Time.xcodeproj/project.pbxproj` | BlockTimeKit appears 3 times, not >=4 as plan acceptance criteria required | INFO | All 3 library products (BlockTimeDomain, BlockTimeData, BlockTimeCalculators) ARE linked; the count criterion was slightly under-specified |
| `Block-TimeTests/Fixtures/FlightDataModel.sqlite` | Missing — real fixture not obtained | BLOCKER | Success criterion 1 of ROADMAP.md cannot be met until fixture is present and Test 9 passes |

---

## Human Verification Required

### 1. Path B — Migration from real v1 data on device

**Test:** Install v1 build on a Simulator with populated flights (or use a device), update to v2-dev build, watch Console.app
**Expected:** Migration log shows N > 0 records read, N records written, row counts match, exit(0) fires, second launch opens v1 UI normally
**Why human:** Requires v1 build with populated data and a device/Simulator

### 2. Real .sqlite fixture for Test 9

**Test:** Follow Block-TimeTests/Fixtures/README.md to obtain FlightDataModel.sqlite; run CoreDataMigrationServiceTests
**Expected:** Test 9 executes (not skips) and passes — all time fields round-trip correctly from String to TimeInterval
**Why human:** File must be extracted from a physical device or Simulator with v1 data

### 3. REQUIREMENTS.md checkbox update

**Test:** Verify FOUND-03 and FOUND-04 boxes are updated to `[x]` on v2-dev
**Expected:** Both requirements show as Complete in the Traceability table
**Why human:** Requires a doc edit commit on v2-dev

---

## Gaps Summary

Two gaps block full phase goal achievement:

**Gap 1 — Real fixture absent (blocker for ROADMAP success criterion 1):** The ROADMAP states "A real v1 production .sqlite file migrates to SwiftData without data loss." This cannot be verified until `Block-TimeTests/Fixtures/FlightDataModel.sqlite` exists. The plan acknowledged this deferral (Option B), but it remains an open blocker for TestFlight.

**Gap 2 — FlightDatabaseService modified (warning):** The plan explicitly stated "Existing v1 Core Data stack (FlightDatabaseService) is NOT modified" as a must-have truth. On v2-dev, FlightDatabaseService.swift has two predicate changes in the simulator migration helper. While this may be intentional (improving scroll-to-current behaviour), it contradicts the acceptance criteria and should be explicitly acknowledged.

Both gaps are structured in the frontmatter `gaps:` block for `/gsd:plan-phase --gaps`.

---

_Verified: 2026-05-16_
_Verifier: Claude (gsd-verifier)_
