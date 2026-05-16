# Phase 2: CoreData Repository - Context

**Gathered:** 2026-05-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Delete all SwiftData infrastructure, build `CoreDataFlightRepository` conforming to `FlightRepository` (backed by the existing `NSPersistentCloudKitContainer`), add a Core Data v2 model version with a custom `NSEntityMigrationPolicy` that converts decimal-hour strings to `Int16` minutes and "HH:MM" gate strings to `Date?`, update the `Flight` domain struct to use `Int` minutes and `Date?` gate times, and wire `CoreDataFlightRepository` at the app entry point. No view-level rewiring — that is Phase 5 scope.

</domain>

<decisions>
## Implementation Decisions

### Migration Policy Implementation
- **D-01:** Migration policy inlines its own string→minutes conversion logic. Does NOT reuse `TimeStringConverter`. Migration policies are one-shot — inline code is self-contained and avoids coupling to a type that may change in Phase 3.
- **D-02:** `CoreDataMigrationService`, `CoreDataMigrationActor`, `LegacyFlightSnapshot`, and the `SplashScreenView` migration task are deleted entirely. Lightweight Core Data migration is automatic — no trigger code needed.
- **D-03:** On first Phase 2 launch, delete the orphaned SwiftData `blocktime.sqlite` file from the App Group container if found. (Only dev builds ran Phase 1 branch — no real user data.)
- **D-04:** UserDefaults flags `v2MigrationStarted` and `v2MigrationComplete` (from the deleted `CoreDataMigrationService`) are cleared on first Phase 2 launch.
- **D-05:** Gate time strings are UTC (the v1 app stored them as UTC "HH:MM"). Migration combines the "HH:MM" string with the flight's `date` (UTC midnight) to produce a full UTC `Date?`.
- **D-06:** Missing or malformed gate strings → `nil` on the new `Date?` column. Nil string time fields → `0` on the new `Int16` column.
- **D-07:** `NSMigratePersistentStoresAutomaticallyOption = true` and `NSInferMappingModelAutomaticallyOption = false` configured in `FlightDatabaseService.persistentContainer` setup. Custom `NSMappingModel` provided. Core Data auto-migrates on first load.

### Core Data Model Versioning
- **D-08:** Current single-version model renamed to `FlightDataModelV1`. New `FlightDataModelV2` added as the current active version via Xcode (Editor > Add Model Version).
- **D-09:** In `FlightDataModelV2`: time string columns renamed to `blockTimeLegacy`, `simTimeLegacy`, etc. (kept as optional String, marked as transient in the mapping but retained in the store for historical reference). New `Int16` scalar columns take the canonical names: `blockTime`, `simTime`, `nightTime`, `p1Time`, `p1usTime`, `p2Time`, `instrumentTime`, `spInsTime`. New `Int16` column `dualTime` defaults to 0.
- **D-10:** Gate time columns in v2: old `outTime`, `inTime`, `scheduledDeparture`, `scheduledArrival` (String?) renamed to `outTimeLegacy`, `inTimeLegacy`, `scheduledDepartureLegacy`, `scheduledArrivalLegacy`. New `Date?` columns take canonical names: `outTime`, `inTime`, `scheduledDeparture`, `scheduledArrival`.
- **D-11:** Custom `.xcmappingmodel` file added in Xcode. `NSEntityMigrationPolicy` subclass performs the string→Int16 and String→Date? conversions. Legacy string values left as-is in the store after migration (no cleanup pass needed).

### Flight Domain Struct
- **D-12:** `Flight.swift` updated: all 8 time fields changed from `TimeInterval` to `Int` (minutes). Gate time fields (`outTimeSeconds`, `inTimeSeconds`) changed from `TimeInterval?` to `Date?` and renamed to `outTime`, `inTime`. Add `scheduledDeparture: Date?` and `scheduledArrival: Date?`.
- **D-13:** Add ALL fields missing from current struct: `dualTime: Int`, `so1Name: String`, `so2Name: String`, `customCount: Int`. One complete update — no partial state going into Phase 3.
- **D-14:** `InMemoryFlightRepository` and all `BlockTimeKit` test fixtures updated in the same plan as the `Flight` struct change (atomic — compiler enforces completeness).

### CoreDataFlightRepository Implementation
- **D-15:** `CoreDataFlightRepository` lives in the app target (not `BlockTimeKit`). Conforms to `FlightRepository`. Uses `NSPersistentCloudKitContainer` directly — holds a reference to the container and creates `NSFetchRequest<FlightEntity>` directly. Does NOT delegate to `FlightDatabaseService`.
- **D-16:** All methods are `@MainActor` and use `viewContext`. Matches `FlightDatabaseService` pattern. Background context deferred to Phase 4 if needed.
- **D-17:** `Flight↔FlightEntity` mapping as private static methods on `CoreDataFlightRepository` (mirroring `SwiftDataFlightRepository` pattern: `toDomain` and `apply`).
- **D-18:** `search(query:)` uses `NSCompoundPredicate(orPredicateWithSubpredicates:)` with `contains[cd]` predicates on: `fromAirport`, `toAirport`, `flightNumber`, `aircraftReg`, `aircraftType`, `captainName`, `foName`, `remarks`. String fields only — no date searching.
- **D-19:** `fetchAll()`, `fetchRecent(days:)`, `fetch(from:to:)` sort by `date` descending, then `createdAt` descending (consistent ordering for same-date flights).
- **D-20:** `update(_:)` — if UUID not found, insert as new (same upsert behavior as `SwiftDataFlightRepository`).
- **D-21:** `deleteAll()` — fetch all then `context.delete()` per entity, then save. NOT `NSBatchDeleteRequest` — batch delete bypasses CloudKit history tracking.

### App Entry Point Wiring
- **D-22:** `Block_TimeApp` injects `CoreDataFlightRepository` at top level via `.flightRepository(CoreDataFlightRepository(container: FlightDatabaseService.shared.persistentContainer))`. `.managedObjectContext` injection kept — views still use `FlightDatabaseService` directly until Phase 5.
- **D-23:** `productionContainer` static property, `OptionalModelContainerModifier`, and all `.modelContainer()` calls deleted from `Block_TimeApp`.
- **D-24:** Project-wide sweep: all `import SwiftData` removed. All files — including deleted files (`ModelContainerFactory`, `SchemaV1`, `FlightModel`, `AircraftModel`) and modified files (`Block_TimeApp`, `SplashScreenView`, `AppRepositoryEnvironment`, etc.).
- **D-25:** `AppRepositoryEnvironment.swift` default stays `InMemoryFlightRepository` (for previews). Only the entry point injection changes.

### Claude's Discretion
- Exact UserDefaults key name for the Phase 2 "orphan cleanup done" flag (if needed)
- Whether to use a `NSSortDescriptor` array or `SortDescriptor` for the NSFetchRequest sort
- Error types thrown by `CoreDataFlightRepository` (can use `CoreDataError` wrapper or rethrow raw)
- Exact naming for the `NSEntityMigrationPolicy` subclass

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Core Data Model (migration source and destination)
- `Block-Time/FlightDataModel.xcdatamodeld/FlightDataModel.xcdatamodel/contents` — v1 model: all entity names, attribute types (String?, Int16, Date, UUID, Bool). Migration source.
- `Block-Time/Models/FlightEntity+Extensions.swift` — Field accessors on `FlightEntity`. All computed properties and helpers that map field names.

### SwiftData Infrastructure (to be deleted)
- `Block-Time/Models/SchemaV1.swift` — `SchemaV1: VersionedSchema` and `FlightMigrationPlan`. Delete entirely.
- `Block-Time/Models/FlightModel.swift` — `@Model FlightModel`. Delete entirely.
- `Block-Time/Models/AircraftModel.swift` — `@Model AircraftModel`. Delete entirely.
- `Block-Time/Infrastructure/ModelContainerFactory.swift` — `ModelContainerFactory` enum. Delete entirely.
- `Block-Time/Repositories/SwiftDataFlightRepository.swift` — Reference for `toDomain`/`apply` mapping pattern before deleting.
- `Block-Time/Migration/CoreDataMigrationService.swift` — Delete entirely.
- `Block-Time/Migration/CoreDataMigrationActor.swift` — Delete entirely.
- `Block-Time/Migration/LegacyFlightSnapshot.swift` — Delete entirely.

### Flight Domain & Repository Protocol
- `BlockTimeKit/Sources/BlockTimeDomain/Flight.swift` — Current `Flight` struct (uses `TimeInterval` — must be updated to `Int` and `Date?`).
- `BlockTimeKit/Sources/BlockTimeData/FlightRepository.swift` — Protocol all implementations must satisfy.
- `BlockTimeKit/Sources/BlockTimeData/InMemoryFlightRepository.swift` — In-memory impl; must be updated atomically with `Flight` struct.

### App Entry Point
- `Block-Time/Block_TimeApp.swift` — Current DI wiring. `productionContainer`, `OptionalModelContainerModifier`, `.modelContainer()` calls all removed.
- `Block-Time/Infrastructure/AppRepositoryEnvironment.swift` — `FlightRepositoryKey` environment key wiring.
- `Block-Time/Views/Screens/SplashScreenView.swift` — Migration trigger task to be removed.

### Core Data Stack (stays — do not modify container setup except migration options)
- `Block-Time/Services/FlightDatabaseService.swift` — `NSPersistentCloudKitContainer` setup. Add `NSMigratePersistentStoresAutomaticallyOption` and custom mapping model reference. Do NOT change container structure.

### Project Requirements
- `.planning/REQUIREMENTS.md` — REPO-01 through REPO-10 are all in scope for Phase 2.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SwiftDataFlightRepository.swift`: Full `toDomain`/`apply` mapping pattern. Mirror this exactly for `CoreDataFlightRepository` but using `FlightEntity` instead of `FlightModel`. The method signatures and structure are the template.
- `FlightDatabaseService.persistentContainer`: Already-configured `NSPersistentCloudKitContainer`. `CoreDataFlightRepository` takes a reference to this container — no new container needed.
- `FlightEntity+Extensions.swift`: Field helpers useful when writing the `toDomain` mapping in `CoreDataFlightRepository`.

### Established Patterns
- Repository mapping: static `toDomain(_:) -> Flight` and `apply(_:to:)` methods on the repository class. Follow exactly.
- Context access: `@MainActor func context: NSManagedObjectContext { container.viewContext }` — mirror from `SwiftDataFlightRepository`'s `@MainActor private var context: ModelContext`.
- Saves: `try context.save()` after every insert/update/delete — same as `SwiftDataFlightRepository`.
- Sort: `NSSortDescriptor(key: "date", ascending: false)` + secondary `NSSortDescriptor(key: "createdAt", ascending: false)`.

### Integration Points
- `Block_TimeApp.swift`: Remove `productionContainer` + `OptionalModelContainerModifier`. Add `.flightRepository(CoreDataFlightRepository(...))` modifier. Keep `.environment(\.managedObjectContext, FlightDatabaseService.shared.viewContext)`.
- `SplashScreenView.swift`: Remove `.task { await CoreDataMigrationService... }` block.
- `FlightDatabaseService.persistentContainer`: Add `description.shouldMigrateStoreAutomatically = true` + `description.shouldInferMappingModelAutomatically = false` + provide custom mapping model.

</code_context>

<specifics>
## Specific Ideas

- `CoreDataFlightRepository` init: `init(container: NSPersistentCloudKitContainer)` — takes the container directly, not `FlightDatabaseService.shared`. Keeps the repository testable (can pass a test container).
- For test injection: `CoreDataFlightRepository` should work with any `NSPersistentCloudKitContainer` or ideally `NSPersistentContainer` — consider typing the parameter as `NSPersistentContainer` to allow in-memory test containers without CloudKit.
- Orphan cleanup: check for `FileManager.default.fileExists(atPath: ModelContainerFactory.appGroupStoreURL().path)` on launch. If found and SwiftData types no longer exist, delete it. This code can live in `Block_TimeApp.init()` — runs once, has no dependency on any service.
- The `FlightDataModelV1` name: the existing `.xcdatamodeld` file is named `FlightDataModel`. In Xcode, the rename to `FlightDataModelV1` happens inside the `.xcdatamodeld` bundle — the file stays named `FlightDataModel.xcdatamodeld` externally.

</specifics>

<deferred>
## Deferred Ideas

- Background context for `CoreDataFlightRepository` — deferred to Phase 4 (God Object Breakup) if needed for large-dataset performance.
- Nil-ing out legacy string columns after migration — evaluated and rejected (adds complexity, negligible space savings).
- Widget rewiring to `CoreDataFlightRepository` — deferred to Phase 5 (Core UI + Widgets). Widget continues to use `FlightDatabaseService` directly.
- View-level wiring of `@Environment(\.flightRepository)` — deferred to Phase 5. Phase 2 only wires the entry point.
- `FlightEntity` to `NSPersistentContainer` (non-CloudKit) typing — if needed for unit tests, revisit in Phase 2 plan execution.

</deferred>

---

*Phase: 02-coredata-repository*
*Context gathered: 2026-05-16*
