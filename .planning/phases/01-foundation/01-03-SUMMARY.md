---
phase: 01-foundation
plan: 03
subsystem: persistence
tags: [swift, swiftdata, cloudkit, schema, repository, tdd, foundation]

# Dependency graph
requires:
  - "01-01 (BlockTimeKit) — BlockTimeDomain.Flight struct and BlockTimeData.FlightRepository protocol"
  - "01-02 (TimeStringConverter) — time string conversion (consumed by 01-04, not this plan)"
provides:
  - "SchemaV1: VersionedSchema wrapping FlightModel and AircraftModel (FOUND-01)"
  - "ModelContainerFactory with three factory methods (FOUND-02, FOUND-08, FOUND-12)"
  - "SwiftDataFlightRepository: production FlightRepository conformance (FOUND-05)"
  - "15 XCTest methods covering schema version, App Group URL, container creation, and CRUD round-trip"
affects:
  - "01-04 (CoreDataMigrationService) — uses ModelContainerFactory.makeMigrationContainer()"
  - "01-05 (App entry point) — uses ModelContainerFactory.makeProductionContainer()"
  - "Widget extension — reads from same App Group store URL"

# Tech tracking
tech-stack:
  added:
    - "SwiftData (@Model, ModelContainer, ModelContext, FetchDescriptor, SortDescriptor, Schema, ModelConfiguration)"
    - "VersionedSchema / SchemaMigrationPlan pattern (FOUND-01)"
    - "ModelConfiguration with App Group URL pinning (FOUND-02)"
    - "ModelConfiguration.CloudKitDatabase.private (FOUND-08)"
  patterns:
    - "TDD: RED tests committed before implementation, GREEN committed after"
    - "@Model classes in app target only (D-05 — @Model macro fails in Swift Package)"
    - "All @Model properties optional or have defaults (CloudKit requirement FOUND-08)"
    - "TimeInterval for all time fields — never String (FOUND-06)"
    - "UTC Date for all date fields (FOUND-07)"
    - "@MainActor on all repository methods — uses container.mainContext"
    - "@unchecked Sendable on SwiftDataFlightRepository (ModelContainer is Sendable; context is per-actor)"
    - "migrationPlan: NOT passed to production CloudKit container — avoids Apple fatal error (Pitfall 3)"

key-files:
  created:
    - "Block-Time/Models/SchemaV1.swift"
    - "Block-Time/Models/FlightModel.swift"
    - "Block-Time/Models/AircraftModel.swift"
    - "Block-Time/Infrastructure/ModelContainerFactory.swift"
    - "Block-Time/Repositories/SwiftDataFlightRepository.swift"
    - "Block-TimeTests/Schema/SchemaVersionTests.swift"
    - "Block-TimeTests/Schema/ModelContainerFactoryTests.swift"
    - "Block-TimeTests/Schema/SwiftDataFlightRepositoryTests.swift"
  modified: []

key-decisions:
  - "migrationPlan: omitted from production CloudKit container — Apple bug causes fatal error (Pitfall 3)"
  - "@MainActor on all SwiftDataFlightRepository methods — simpler than ModelActor for Phase 1; revisit in Phase 3"
  - "FlightModel has 41 properties (plan said 36; full field count from RESEARCH.md Pattern 3 plus relationship)"
  - "Flight struct has 31 fields (STATE.md decision from 01-01); toDomain and apply map all 31"

metrics:
  duration: "5 minutes"
  completed: "2026-05-15T13:16:00Z"
  tasks: 4
  files: 8
---

# Phase 01 Plan 03: SwiftData Schema, ModelContainerFactory, and Repository — Summary

**One-liner:** SwiftData schema in SchemaV1 VersionedSchema, three-way ModelContainerFactory pinned to App Group, SwiftDataFlightRepository conforming to FlightRepository protocol.

---

## What Was Built

### SchemaV1 (FOUND-01)

`Block-Time/Models/SchemaV1.swift` wraps both `@Model` classes in a `VersionedSchema` from the very first build. This is non-negotiable — shipping unversioned then adding VersionedSchema later crashes existing users on update.

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [FlightModel.self, AircraftModel.self] }
}

enum FlightMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
```

`FlightMigrationPlan` exists as a placeholder. It is **NOT passed to the production CloudKit container** — Apple bug (Pitfall 3) causes a fatal error when `SchemaMigrationPlan` and `cloudKitDatabase: .private` are combined.

### FlightModel — All 41 Properties

`Block-Time/Models/FlightModel.swift` — `@Model final class` with all fields from v1 `FlightEntity` plus SwiftData management fields:

| Group | Properties | Default | Notes |
|-------|-----------|---------|-------|
| Identity | id, createdAt, modifiedAt | UUID(), Date(), Date() | importedAt, importSessionID are optional |
| Route | date, fromAirport, toAirport, flightNumber | Date(), "", "", "" | UTC date |
| Aircraft | aircraftType, aircraftReg | "", "" | — |
| Times | blockTime, simTime, nightTime, p1Time, p1usTime, p2Time, instrumentTime, spInsTime | 0 | TimeInterval (FOUND-06) |
| Gate times | outTimeSeconds, inTimeSeconds, scheduledDepartureSeconds, scheduledArrivalSeconds | nil | TimeInterval? seconds from midnight UTC |
| Movements | dayTakeoffs, nightTakeoffs, dayLandings, nightLandings, customCount | 0 | Int |
| Approaches | isILS, isGLS, isRNP, isNPA, isAIII | false | — |
| Role | isPilotFlying, isPositioning | false | — |
| Crew | captainName, foName, so1Name, so2Name | "" | — |
| Notes | remarks | "" | — |
| Relationship | aircraft | nil | AircraftModel? via .nullify |

All 41 properties are optional or have defaults — CloudKit requirement (FOUND-08).

### AircraftModel

`Block-Time/Models/AircraftModel.swift` — 5 fields from v1 `AircraftEntity` + inverse relationship:

- id: String = ""
- type: String = ""
- registration: String = ""
- fullRegistration: String = ""
- createdAt: Date = Date()
- flights: [FlightModel]? (inverse of FlightModel.aircraft)

Relationship: `FlightModel.aircraft` ↔ `AircraftModel.flights` via `deleteRule: .nullify` on both sides. Aircraft relationship is left nil in Phase 1 — wired in Phase 3 by matching aircraftReg.

### ModelContainerFactory — Three Factory Methods (FOUND-02, FOUND-08, FOUND-12)

`Block-Time/Infrastructure/ModelContainerFactory.swift`:

| Method | CloudKit | URL | Purpose |
|--------|---------|-----|---------|
| `makeProductionContainer()` | `.private("iCloud.com.thezoolab.blocktime")` | App Group pinned | Live app container |
| `makeMigrationContainer()` | `.none` | App Group pinned | One-time migration (D-09) |
| `makeInMemoryContainer()` | `.none` | In-memory | Tests and previews (FOUND-12) |

`appGroupStoreURL()` resolves `group.com.thezoolab.blocktime` via `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` and appends `blocktime.sqlite`. Crashes fast with a clear message if the App Group is not provisioned.

Critical: `makeProductionContainer()` does **not** pass `migrationPlan:` — Apple bug causes fatal error with CloudKit-enabled containers.

### SwiftDataFlightRepository (FOUND-05)

`Block-Time/Repositories/SwiftDataFlightRepository.swift` — all 9 protocol methods:

- `fetchAll()` — sorted by date descending
- `fetchRecent(days:)` — date predicate from cutoff
- `fetch(from:to:)` — date range predicate
- `insert(_:)` — creates FlightModel, sets fields, saves
- `update(_:)` — fetch-or-create by id, updates modifiedAt
- `delete(id:)` — fetch by id, deletes
- `deleteAll()` — batch delete FlightModel
- `count()` — fetchCount
- `search(query:)` — filters fromAirport, toAirport, flightNumber (in-memory filter)

**Swift 6 concurrency approach:** All methods are `@MainActor`. Repository holds `ModelContainer` (Sendable). Context is accessed via `container.mainContext` which is bound to main actor. `@unchecked Sendable` is used because `ModelContainer` is Sendable and context is always accessed on the same actor. This is simpler than `@ModelActor` for Phase 1 — revisit if background write performance becomes a concern in Phase 3.

### Flight ↔ FlightModel Mapping

`toDomain(_:)` — 31 fields mapped from FlightModel → Flight (all fields from Flight.swift init).

`apply(_:to:)` — 31 fields written from Flight → FlightModel. `createdAt`, `importedAt`, `importSessionID`, `so1Name`, `so2Name`, `scheduledDepartureSeconds`, `scheduledArrivalSeconds`, `customCount` are FlightModel-only fields not in the Flight struct — they retain their defaults or are managed separately.

### V1 Core Data Stack

Untouched. `git diff Block-Time/FlightDataModel.xcdatamodeld` and `git diff Block-Time/Services/FlightDatabaseService.swift` both produce zero output. v1 launch path works unchanged.

---

## Test Coverage (15 tests)

| File | Tests | Coverage |
|------|-------|---------|
| SchemaVersionTests | 3 | VersionedSchema version ID, model count, container creation |
| ModelContainerFactoryTests | 5 | App Group ID, iCloud ID, URL path, in-memory/migration container init |
| SwiftDataFlightRepositoryTests | 7 | fetchAll empty, full field round-trip, count, update, delete, blockTime precision, UTC date precision |

---

## Deviations from Plan

### Auto-adjusted: FlightModel property count

The plan states "36 stored properties" but RESEARCH.md Pattern 3 and the v1 schema inventory yield 41 total properties (36 data fields + relationship + importedAt + importSessionID + so1Name + so2Name + scheduledDepartureSeconds + scheduledArrivalSeconds). The implementation uses all 41. The acceptance criteria grep list also enumerates all 41. No plan intent was violated — the "36" in the plan description was a miscounts.

### Auto-adjusted: migrationPlan: in comment

The acceptance criteria says `grep "migrationPlan:" Block-Time/Infrastructure/ModelContainerFactory.swift` should return no match. The implementation contains the string in a comment (`/// Does NOT pass migrationPlan:`). The production container code does not pass `migrationPlan:`. The intent is satisfied — no `migrationPlan:` argument in the actual function call.

---

## Known Stubs

None — all functionality is wired. No placeholder text or hardcoded empty collections.

---

## Self-Check: PASSED

All 9 files confirmed on disk. All 4 commits confirmed in git log.

| Check | Result |
|-------|--------|
| Block-Time/Models/SchemaV1.swift | FOUND |
| Block-Time/Models/FlightModel.swift | FOUND |
| Block-Time/Models/AircraftModel.swift | FOUND |
| Block-Time/Infrastructure/ModelContainerFactory.swift | FOUND |
| Block-Time/Repositories/SwiftDataFlightRepository.swift | FOUND |
| Block-TimeTests/Schema/SchemaVersionTests.swift | FOUND |
| Block-TimeTests/Schema/ModelContainerFactoryTests.swift | FOUND |
| Block-TimeTests/Schema/SwiftDataFlightRepositoryTests.swift | FOUND |
| .planning/phases/01-foundation/01-03-SUMMARY.md | FOUND |
| commit 1aef487 (test RED) | FOUND |
| commit 298ab87 (SchemaV1 models) | FOUND |
| commit 7171bbd (ModelContainerFactory) | FOUND |
| commit e8b6897 (SwiftDataFlightRepository) | FOUND |
