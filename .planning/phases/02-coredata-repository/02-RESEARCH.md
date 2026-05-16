# Phase 2: CoreData Repository - Research

**Researched:** 2026-05-16
**Domain:** Core Data model versioning, NSEntityMigrationPolicy, NSFetchRequest repository pattern
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Migration Policy Implementation**
- D-01: Migration policy inlines its own string→minutes conversion logic. Does NOT reuse `TimeStringConverter`. Self-contained, avoids coupling.
- D-02: `CoreDataMigrationService`, `CoreDataMigrationActor`, `LegacyFlightSnapshot`, and the `SplashScreenView` migration task deleted entirely. Lightweight Core Data migration is automatic — no trigger code needed.
- D-03: On first Phase 2 launch, delete the orphaned SwiftData `blocktime.sqlite` file from the App Group container if found.
- D-04: UserDefaults flags `v2MigrationStarted` and `v2MigrationComplete` cleared on first Phase 2 launch.
- D-05: Gate time strings are UTC. Migration combines "HH:MM" string with the flight's `date` (UTC midnight) to produce a full UTC `Date?`.
- D-06: Missing or malformed gate strings → `nil`. Nil string time fields → `0` on the new `Int16` column.
- D-07: `NSMigratePersistentStoresAutomaticallyOption = true` and `NSInferMappingModelAutomaticallyOption = false` in `FlightDatabaseService.persistentContainer`. Custom `NSMappingModel` provided.

**Core Data Model Versioning**
- D-08: Current model renamed to `FlightDataModelV1`. New `FlightDataModelV2` added as current active version.
- D-09: In V2: time string columns renamed `blockTimeLegacy`, `simTimeLegacy`, etc. (optional String, kept in store). New `Int16` scalar columns take canonical names: `blockTime`, `simTime`, `nightTime`, `p1Time`, `p1usTime`, `p2Time`, `instrumentTime`, `spInsTime`. New `Int16` column `dualTime` defaults to 0.
- D-10: Gate time columns in V2: old `outTime`, `inTime`, `scheduledDeparture`, `scheduledArrival` (String?) renamed to `*Legacy`. New `Date?` columns take canonical names.
- D-11: Custom `.xcmappingmodel` added. `NSEntityMigrationPolicy` subclass performs conversions. Legacy strings left in store.

**Flight Domain Struct**
- D-12: `Flight.swift` updated: 8 time fields from `TimeInterval` → `Int` (minutes). Gate fields from `TimeInterval?` → `Date?`, renamed `outTime`/`inTime`. Add `scheduledDeparture: Date?` and `scheduledArrival: Date?`.
- D-13: Add ALL missing fields: `dualTime: Int`, `so1Name: String`, `so2Name: String`, `customCount: Int`. One complete update.
- D-14: `InMemoryFlightRepository` and all `BlockTimeKit` test fixtures updated atomically with `Flight` struct change.

**CoreDataFlightRepository Implementation**
- D-15: Lives in app target. Conforms to `FlightRepository`. Uses `NSPersistentCloudKitContainer` directly. Does NOT delegate to `FlightDatabaseService`.
- D-16: All methods `@MainActor`, use `viewContext`.
- D-17: `toDomain` and `apply` as private static methods on `CoreDataFlightRepository`.
- D-18: `search(query:)` uses `NSCompoundPredicate(orPredicateWithSubpredicates:)` with `contains[cd]` on: `fromAirport`, `toAirport`, `flightNumber`, `aircraftReg`, `aircraftType`, `captainName`, `foName`, `remarks`.
- D-19: Sort by `date` descending, then `createdAt` descending.
- D-20: `update(_:)` — if UUID not found, insert as new (upsert).
- D-21: `deleteAll()` — fetch all, `context.delete()` per entity, then save. NOT `NSBatchDeleteRequest`.

**App Entry Point Wiring**
- D-22: `Block_TimeApp` injects `CoreDataFlightRepository` at top level via `.flightRepository(CoreDataFlightRepository(container: FlightDatabaseService.shared.persistentContainer))`. `.managedObjectContext` injection kept.
- D-23: `productionContainer` static property, `OptionalModelContainerModifier`, and all `.modelContainer()` calls deleted.
- D-24: Project-wide sweep: all `import SwiftData` removed from all files. Deleted files: `ModelContainerFactory`, `SchemaV1`, `FlightModel`, `AircraftModel`, `CoreDataMigrationService`, `CoreDataMigrationActor`, `LegacyFlightSnapshot`, `SwiftDataFlightRepository`.
- D-25: `AppRepositoryEnvironment.swift` default stays `InMemoryFlightRepository` (for previews). Only entry point injection changes.

### Claude's Discretion
- Exact UserDefaults key name for the Phase 2 "orphan cleanup done" flag (if needed)
- Whether to use `NSSortDescriptor` array or `SortDescriptor` for the NSFetchRequest sort
- Error types thrown by `CoreDataFlightRepository` (can use `CoreDataError` wrapper or rethrow raw)
- Exact naming for the `NSEntityMigrationPolicy` subclass

### Deferred Ideas (OUT OF SCOPE)
- Background context for `CoreDataFlightRepository` — deferred to Phase 4
- Nil-ing out legacy string columns after migration — rejected
- Widget rewiring to `CoreDataFlightRepository` — deferred to Phase 5
- View-level wiring of `@Environment(\.flightRepository)` — deferred to Phase 5
- `FlightEntity` to `NSPersistentContainer` (non-CloudKit) typing — revisit if needed for unit tests
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REPO-01 | `CoreDataFlightRepository` conforms to `FlightRepository`, backed by `NSPersistentCloudKitContainer` | Confirmed: repository pattern from `SwiftDataFlightRepository` is the direct template; NSFetchRequest replaces FetchDescriptor |
| REPO-02 | Lightweight migration adds `Int16` minute columns for 8 time fields; existing decimal-hour strings converted via migration policy | Confirmed: NSEntityMigrationPolicy custom subclass; v1 model verified (all 8 as String?) |
| REPO-03 | Lightweight migration adds `dualTime: Int16` column, defaults 0 | Confirmed: simple attribute addition with default; standard lightweight migration territory |
| REPO-04 | Lightweight migration replaces 4 gate String fields with `Date?` columns; "HH:MM" + flight date → UTC timestamp | Confirmed: requires NSEntityMigrationPolicy for the date reconstruction; D-05 defines UTC semantics |
| REPO-05 | `Flight` domain struct uses `Int` (minutes) for all time fields — `TimeInterval` removed | Confirmed: 8 `TimeInterval` properties in current `Flight.swift` must change to `Int`; gate fields become `Date?` |
| REPO-06 | `blockTime` stored independently in Core Data — not derived from gate times | Confirmed: v1 already stores `blockTime` as its own String field; migration keeps it independent as `Int16` |
| REPO-07 | SwiftData infrastructure deleted | Confirmed: 8 files to delete; all `import SwiftData` in 8 app-target files identified |
| REPO-08 | App entry point injects `CoreDataFlightRepository` via `.environment`; SwiftData container removed | Confirmed: `Block_TimeApp.swift` wiring identified; `OptionalModelContainerModifier` and `productionContainer` to remove |
| REPO-09 | All existing `BlockTimeKit` tests still pass | Confirmed: 2 test files (`FlightTests.swift`, `FlightRepositoryTests.swift`); all fixtures use current `Flight` init signature — must be updated atomically |
| REPO-10 | CloudKit sync continues — `NSPersistentCloudKitContainer` unchanged; lightweight migration survives iCloud | Confirmed: migration options added to `description`, not the container itself; CloudKit remains active throughout |
</phase_requirements>

---

## Summary

Phase 2 replaces the Phase 1 SwiftData dead-end with `CoreDataFlightRepository` — a production repository backed by the already-working `NSPersistentCloudKitContainer` in `FlightDatabaseService`. The work has three independent streams that must be coordinated: (1) add a Core Data V2 model version with a custom mapping model and `NSEntityMigrationPolicy`; (2) update the `Flight` domain struct and all consumers atomically; (3) build `CoreDataFlightRepository` and wire it at the app entry point while deleting all SwiftData infrastructure.

The most risk-concentrated task is the Core Data model migration. The current `FlightDataModel.xcdatamodel` is the only version — no versioning exists yet. The migration must add 8 `Int16` scalar columns (one per time field), 1 `dualTime: Int16` column, and swap 4 String gate-time columns for `Date?` columns, all in a single V1→V2 hop. The `NSEntityMigrationPolicy` subclass must inline its own "decimal-hour string or HH:MM string → Int16 minutes" logic (D-01) and the "HH:MM string + UTC midnight Date → UTC Date?" logic (D-05). Malformed inputs produce 0/nil, never throw.

The `Flight` struct change (TimeInterval → Int, `outTimeSeconds`/`inTimeSeconds` → `Date?`) cascades to `InMemoryFlightRepository`, both test files, and `SwiftDataFlightRepository` (which is then deleted). Because the compiler enforces completeness across these types, the plan must treat the struct change and all its consumers as a single atomic unit.

**Primary recommendation:** Plan three waves: (1) Core Data model versioning + migration policy, (2) Flight struct update + test fixture update + InMemoryFlightRepository update, (3) CoreDataFlightRepository implementation + SwiftData deletion + app wiring.

---

## Standard Stack

### Core
| Component | Version/Type | Purpose | Why Standard |
|-----------|-------------|---------|--------------|
| `NSEntityMigrationPolicy` | CoreData.framework | Custom attribute transformation during migration | Only mechanism for programmatic value conversion in Core Data migrations |
| `NSMappingModel` (.xcmappingmodel) | Xcode artifact | Declares custom migration policy class for Core Data | Required when `NSInferMappingModelAutomatically = false` |
| `NSFetchRequest<FlightEntity>` | CoreData.framework | Repository fetch operations | Typed, predicate-capable; replaces SwiftData's `FetchDescriptor` |
| `NSCompoundPredicate` | CoreData.framework | `search(query:)` multi-field OR filter | Standard predicate composition |
| `NSSortDescriptor` | Foundation | Sort by `date` desc, `createdAt` desc | Works with NSFetchRequest directly |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `NSPersistentStoreDescription` options | Enable automatic migration, disable inferred mapping | Added to `FlightDatabaseService.persistentContainer` before `loadPersistentStores` |
| `FileManager` (orphan cleanup) | Delete stale SwiftData `blocktime.sqlite` on first Phase 2 launch | `Block_TimeApp.init()` — one-shot, no service dependency |
| `UserDefaults` (cleanup flag) | Guard orphan deletion to one run | Standard, same pattern as other migration flags in the project |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom `NSEntityMigrationPolicy` | Inferred lightweight migration | Inferred migration cannot convert String→Int16; custom policy is mandatory |
| `NSBatchDeleteRequest` in `deleteAll()` | Per-entity `context.delete()` | Batch delete bypasses CloudKit persistent history tracking — forbidden (D-21) |
| `NSPersistentContainer` parameter on `CoreDataFlightRepository` | `NSPersistentCloudKitContainer` | NSPersistentContainer is the superclass and would allow in-memory test injection; locked as deferred (D-15) |

---

## Architecture Patterns

### Recommended Project Structure (new files only)

```
Block-Time/
├── FlightDataModel.xcdatamodeld/
│   ├── FlightDataModel.xcdatamodel/     ← rename to FlightDataModelV1 (internal to bundle)
│   └── FlightDataModelV2.xcdatamodel/  ← new active version
├── FlightDataModelV1toV2.xcmappingmodel/ ← new custom mapping model
├── Repositories/
│   ├── SwiftDataFlightRepository.swift  ← DELETE
│   └── CoreDataFlightRepository.swift   ← NEW
├── Migration/
│   ├── CoreDataMigrationService.swift   ← DELETE
│   ├── CoreDataMigrationActor.swift     ← DELETE
│   ├── LegacyFlightSnapshot.swift       ← DELETE
│   ├── MigrationError.swift             ← keep (may be used elsewhere — verify)
│   └── TimeStringConverter.swift        ← keep (Phase 3 will use for calculator)
└── Models/
    ├── SchemaV1.swift                   ← DELETE
    ├── FlightModel.swift                ← DELETE
    └── AircraftModel.swift              ← DELETE
```

### Pattern 1: Core Data Model Versioning

**What:** Add `FlightDataModelV2` as a new model version inside the existing `.xcdatamodeld` bundle. Mark V2 as the current version. V1 remains in the bundle as migration source.

**Key mechanics:**
- In Xcode: Editor > Add Model Version → name it `FlightDataModelV2`
- Set V2 as the "current" version in the model inspector (green checkmark moves)
- The `.xcdatamodeld` file externally keeps its name `FlightDataModel.xcdatamodeld`
- `NSPersistentCloudKitContainer(name: "FlightDataModel")` continues to work — the container finds the current model version automatically

**V2 attribute changes for `FlightEntity`:**

| Old Attribute | Old Type | New Name | New Type | Migration |
|--------------|----------|----------|----------|-----------|
| `blockTime` | `String?` | `blockTimeLegacy` | `String?` | rename in mapping |
| (new) | — | `blockTime` | `Integer 16` scalar | policy converts |
| `simTime` | `String?` | `simTimeLegacy` | `String?` | rename in mapping |
| (new) | — | `simTime` | `Integer 16` scalar | policy converts |
| `nightTime` | `String?` | `nightTimeLegacy` | `String?` | rename in mapping |
| (new) | — | `nightTime` | `Integer 16` scalar | policy converts |
| `p1Time` | `String?` | `p1TimeLegacy` | `String?` | rename in mapping |
| (new) | — | `p1Time` | `Integer 16` scalar | policy converts |
| `p1usTime` | `String?` | `p1usTimeLegacy` | `String?` | rename in mapping |
| (new) | — | `p1usTime` | `Integer 16` scalar | policy converts |
| `p2Time` | `String?` | `p2TimeLegacy` | `String?` | rename in mapping |
| (new) | — | `p2Time` | `Integer 16` scalar | policy converts |
| `instrumentTime` | `String?` | `instrumentTimeLegacy` | `String?` | rename in mapping |
| (new) | — | `instrumentTime` | `Integer 16` scalar | policy converts |
| `spInsTime` | `String?` | `spInsTimeLegacy` | `String?` | rename in mapping |
| (new) | — | `spInsTime` | `Integer 16` scalar | policy converts |
| `outTime` | `String?` | `outTimeLegacy` | `String?` | rename in mapping |
| (new) | — | `outTime` | `Date?` | policy converts |
| `inTime` | `String?` | `inTimeLegacy` | `String?` | rename in mapping |
| (new) | — | `inTime` | `Date?` | policy converts |
| `scheduledDeparture` | `String?` | `scheduledDepartureLegacy` | `String?` | rename in mapping |
| (new) | — | `scheduledDeparture` | `Date?` | policy converts |
| `scheduledArrival` | `String?` | `scheduledArrivalLegacy` | `String?` | rename in mapping |
| (new) | — | `scheduledArrival` | `Date?` | policy converts |
| (new) | — | `dualTime` | `Integer 16` scalar, default 0 | no conversion needed |

**Unchanged V1 attributes carried to V2 (straight mapping):** `id`, `date`, `createdAt`, `modifiedAt`, `importedAt`, `importSessionID`, `fromAirport`, `toAirport`, `flightNumber`, `aircraftType`, `aircraftReg`, `captainName`, `foName`, `so1Name`, `so2Name`, `remarks`, `dayTakeoffs`, `nightTakeoffs`, `dayLandings`, `nightLandings`, `customCount`, `isILS`, `isGLS`, `isRNP`, `isNPA`, `isAIII`, `isPilotFlying`, `isPositioning`.

### Pattern 2: Custom NSEntityMigrationPolicy

**What:** Subclass of `NSEntityMigrationPolicy` that runs per-record during migration. Overrides `createDestinationInstances(forSource:in:manager:)`.

**Structure:**

```swift
// FlightEntityMigrationPolicy.swift — app target only
import CoreData
import Foundation

final class FlightEntityMigrationPolicy: NSEntityMigrationPolicy {

    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 1. Create destination instance via super
        try super.createDestinationInstances(forSource: source, in: mapping, manager: manager)

        // 2. Retrieve the destination object
        guard let destination = manager.destinationInstances(
            forEntityMappingName: mapping.name, sourceInstances: [source]
        ).first else { return }

        // 3. Convert time string columns → Int16 minutes
        let timeFields: [(src: String, dst: String)] = [
            ("blockTime", "blockTime"), ("simTime", "simTime"),
            ("nightTime", "nightTime"), ("p1Time", "p1Time"),
            ("p1usTime", "p1usTime"), ("p2Time", "p2Time"),
            ("instrumentTime", "instrumentTime"), ("spInsTime", "spInsTime")
        ]
        for (srcKey, dstKey) in timeFields {
            let raw = source.value(forKey: srcKey) as? String
            destination.setValue(Self.stringToMinutes(raw), forKey: dstKey)
        }

        // 4. Convert gate time strings → Date? using flight date
        let flightDate = source.value(forKey: "date") as? Date ?? Date(timeIntervalSince1970: 0)
        let gateFields: [(src: String, dst: String)] = [
            ("outTime", "outTime"), ("inTime", "inTime"),
            ("scheduledDeparture", "scheduledDeparture"),
            ("scheduledArrival", "scheduledArrival")
        ]
        for (srcKey, dstKey) in gateFields {
            let raw = source.value(forKey: srcKey) as? String
            destination.setValue(Self.stringToDate(raw, on: flightDate), forKey: dstKey)
        }

        // 5. dualTime defaults to 0 (set by model default; nothing to do)
    }

    // MARK: - Inline conversion (D-01: does NOT reuse TimeStringConverter)

    /// Decimal-hour string or HH:MM string → Int16 minutes. Nil/malformed → 0.
    private static func stringToMinutes(_ raw: String?) -> Int16 {
        guard let raw else { return 0 }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s != "0", s != "0.0" else { return 0 }
        if s.contains(":") {
            let parts = s.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let h = Int(parts[0]), let m = Int(parts[1]),
                  h >= 0, m >= 0, m < 60 else { return 0 }
            return Int16(min(h * 60 + m, Int(Int16.max)))
        } else {
            guard let hours = Double(s), hours.isFinite, hours >= 0 else { return 0 }
            return Int16(min(Int(hours * 60), Int(Int16.max)))
        }
    }

    /// "HH:MM" UTC string + UTC-midnight Date → UTC Date?. Nil/malformed → nil. (D-05)
    private static func stringToDate(_ raw: String?, on utcMidnight: Date) -> Date? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = s.replacingOccurrences(of: ":", with: "")
        guard clean.count == 4,
              let hours = Int(clean.prefix(2)),
              let minutes = Int(clean.suffix(2)),
              hours >= 0, hours < 24,
              minutes >= 0, minutes < 60 else { return nil }
        return utcMidnight.addingTimeInterval(TimeInterval(hours * 3600 + minutes * 60))
    }
}
```

**Registering the policy in `.xcmappingmodel`:** In Xcode, open the mapping model, select the `FlightEntity` → `FlightEntity` entity mapping, set "Custom Policy" to `FlightEntityMigrationPolicy`. The class name must match exactly — no module prefix needed for app-target classes.

### Pattern 3: FlightDatabaseService Migration Options

**What:** Two description options must be set before `loadPersistentStores` fires. They go on the `NSPersistentStoreDescription`, not the container.

```swift
// In FlightDatabaseService.persistentContainer (lazy var), BEFORE loadPersistentStores:
description.shouldMigrateStoreAutomatically = true      // equivalent to NSMigratePersistentStoresAutomaticallyOption
description.shouldInferMappingModelAutomatically = false // equivalent to NSInferMappingModelAutomaticallyOption = false
```

`NSPersistentStoreDescription` exposes these as properties directly — no need to use the dictionary option key strings. Core Data finds the custom `.xcmappingmodel` automatically if it is in the app bundle and matches the source/destination model versions.

### Pattern 4: CoreDataFlightRepository

**What:** Repository class in app target conforming to `FlightRepository`. All methods `@MainActor`. Uses `NSPersistentCloudKitContainer` reference.

```swift
import CoreData
import Foundation
import BlockTimeDomain
import BlockTimeData

@MainActor
final class CoreDataFlightRepository: FlightRepository, @unchecked Sendable {

    private let container: NSPersistentCloudKitContainer

    init(container: NSPersistentCloudKitContainer) {
        self.container = container
    }

    private var context: NSManagedObjectContext { container.viewContext }

    // MARK: - FlightRepository

    func fetchAll() async throws -> [Flight] {
        let request = fetchRequest(sortedByDateDesc: true)
        return try context.fetch(request).map(Self.toDomain)
    }

    func fetchRecent(days: Int) async throws -> [Flight] {
        let cutoff = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let request = fetchRequest(sortedByDateDesc: true)
        request.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
        return try context.fetch(request).map(Self.toDomain)
    }

    func fetch(from: Date, to: Date) async throws -> [Flight] {
        let request = fetchRequest(sortedByDateDesc: true)
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@",
                                        from as NSDate, to as NSDate)
        return try context.fetch(request).map(Self.toDomain)
    }

    func insert(_ flight: Flight) async throws {
        let entity = FlightEntity(context: context)
        Self.apply(flight, to: entity)
        try context.save()
    }

    func update(_ flight: Flight) async throws {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", flight.id as CVarArg)
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first {
            Self.apply(flight, to: existing)
            existing.modifiedAt = Date()
        } else {
            let entity = FlightEntity(context: context)
            Self.apply(flight, to: entity)
        }
        try context.save()
    }

    func delete(id: UUID) async throws {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        for entity in try context.fetch(request) {
            context.delete(entity)
        }
        try context.save()
    }

    func deleteAll() async throws {
        let request = fetchRequest()
        for entity in try context.fetch(request) {
            context.delete(entity)
        }
        try context.save()
    }

    func count() async throws -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: "FlightEntity")
        request.resultType = .countResultType
        return try context.count(for: fetchRequest())
    }

    func search(query: String) async throws -> [Flight] {
        let fields = ["fromAirport", "toAirport", "flightNumber",
                      "aircraftReg", "aircraftType", "captainName", "foName", "remarks"]
        let predicates = fields.map {
            NSPredicate(format: "%K CONTAINS[cd] %@", $0, query)
        }
        let request = fetchRequest(sortedByDateDesc: true)
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return try context.fetch(request).map(Self.toDomain)
    }

    // MARK: - Private

    private func fetchRequest(sortedByDateDesc: Bool = false) -> NSFetchRequest<FlightEntity> {
        let request = NSFetchRequest<FlightEntity>(entityName: "FlightEntity")
        if sortedByDateDesc {
            request.sortDescriptors = [
                NSSortDescriptor(key: "date", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
        }
        return request
    }

    // MARK: - Mapping

    private static func toDomain(_ e: FlightEntity) -> Flight {
        Flight(
            id: e.id ?? UUID(),
            date: e.date ?? Date(),
            fromAirport: e.fromAirport ?? "",
            toAirport: e.toAirport ?? "",
            flightNumber: e.flightNumber ?? "",
            aircraftType: e.aircraftType ?? "",
            aircraftReg: e.aircraftReg ?? "",
            blockTime: Int(e.blockTime),          // Int16 scalar → Int
            simTime: Int(e.simTime),
            nightTime: Int(e.nightTime),
            p1Time: Int(e.p1Time),
            p1usTime: Int(e.p1usTime),
            p2Time: Int(e.p2Time),
            instrumentTime: Int(e.instrumentTime),
            spInsTime: Int(e.spInsTime),
            dualTime: Int(e.dualTime),
            outTime: e.outTime,                   // Date? direct
            inTime: e.inTime,
            scheduledDeparture: e.scheduledDeparture,
            scheduledArrival: e.scheduledArrival,
            dayTakeoffs: Int(e.dayTakeoffs),
            nightTakeoffs: Int(e.nightTakeoffs),
            dayLandings: Int(e.dayLandings),
            nightLandings: Int(e.nightLandings),
            customCount: Int(e.customCount),
            isPilotFlying: e.isPilotFlying,
            isPositioning: e.isPositioning,
            isILS: e.isILS,
            isGLS: e.isGLS,
            isRNP: e.isRNP,
            isNPA: e.isNPA,
            isAIII: e.isAIII,
            captainName: e.captainName ?? "",
            foName: e.foName ?? "",
            so1Name: e.so1Name ?? "",
            so2Name: e.so2Name ?? "",
            remarks: e.remarks ?? ""
        )
    }

    private static func apply(_ f: Flight, to e: FlightEntity) {
        e.id = f.id
        e.date = f.date
        e.fromAirport = f.fromAirport
        e.toAirport = f.toAirport
        e.flightNumber = f.flightNumber
        e.aircraftType = f.aircraftType
        e.aircraftReg = f.aircraftReg
        e.blockTime = Int16(min(f.blockTime, Int(Int16.max)))
        e.simTime = Int16(min(f.simTime, Int(Int16.max)))
        e.nightTime = Int16(min(f.nightTime, Int(Int16.max)))
        e.p1Time = Int16(min(f.p1Time, Int(Int16.max)))
        e.p1usTime = Int16(min(f.p1usTime, Int(Int16.max)))
        e.p2Time = Int16(min(f.p2Time, Int(Int16.max)))
        e.instrumentTime = Int16(min(f.instrumentTime, Int(Int16.max)))
        e.spInsTime = Int16(min(f.spInsTime, Int(Int16.max)))
        e.dualTime = Int16(min(f.dualTime, Int(Int16.max)))
        e.outTime = f.outTime
        e.inTime = f.inTime
        e.scheduledDeparture = f.scheduledDeparture
        e.scheduledArrival = f.scheduledArrival
        e.dayTakeoffs = Int16(f.dayTakeoffs)
        e.nightTakeoffs = Int16(f.nightTakeoffs)
        e.dayLandings = Int16(f.dayLandings)
        e.nightLandings = Int16(f.nightLandings)
        e.customCount = Int16(f.customCount)
        e.isPilotFlying = f.isPilotFlying
        e.isPositioning = f.isPositioning
        e.isILS = f.isILS
        e.isGLS = f.isGLS
        e.isRNP = f.isRNP
        e.isNPA = f.isNPA
        e.isAIII = f.isAIII
        e.captainName = f.captainName
        e.foName = f.foName
        e.so1Name = f.so1Name
        e.so2Name = f.so2Name
        e.remarks = f.remarks
        if e.createdAt == nil { e.createdAt = Date() }
    }
}
```

### Pattern 5: Flight Struct Update (D-12, D-13)

The current `Flight.swift` has 30 properties in its init. The V2 init signature:

```swift
public init(
    id: UUID,
    date: Date,
    fromAirport: String,
    toAirport: String,
    flightNumber: String,
    aircraftType: String,
    aircraftReg: String,
    blockTime: Int,          // was TimeInterval
    simTime: Int,            // was TimeInterval
    nightTime: Int,          // was TimeInterval
    p1Time: Int,             // was TimeInterval
    p1usTime: Int,           // was TimeInterval
    p2Time: Int,             // was TimeInterval
    instrumentTime: Int,     // was TimeInterval
    spInsTime: Int,          // was TimeInterval
    dualTime: Int,           // NEW (D-13)
    outTime: Date?,          // was outTimeSeconds: TimeInterval? (D-12)
    inTime: Date?,           // was inTimeSeconds: TimeInterval? (D-12)
    scheduledDeparture: Date?,  // NEW (D-12)
    scheduledArrival: Date?,    // NEW (D-12)
    dayTakeoffs: Int,
    nightTakeoffs: Int,
    dayLandings: Int,
    nightLandings: Int,
    customCount: Int,        // NEW (D-13)
    isPilotFlying: Bool,
    isPositioning: Bool,
    isILS: Bool,
    isGLS: Bool,
    isRNP: Bool,
    isNPA: Bool,
    isAIII: Bool,
    captainName: String,
    foName: String,
    so1Name: String,         // NEW (D-13)
    so2Name: String,         // NEW (D-13)
    remarks: String
)
```

### Anti-Patterns to Avoid

- **Setting migration options after `loadPersistentStores`:** The description options must be set before the closure runs. They have no effect after the store is loaded.
- **Using `NSBatchDeleteRequest` in `deleteAll()`:** Bypasses CloudKit persistent history tracking. Use per-entity delete (D-21).
- **Calling `super.createDestinationInstances` after setting values:** Call super first — it creates the destination object. Set values after.
- **Using `@NSManaged` String properties for the renamed scalar columns in `CoreDataFlightRepository`:** The V2 entity has `blockTime` as `Int16` scalar. If any extension still types it as `String?`, reading it after migration will return nil. Verify `FlightEntity` codegen regenerates for V2.
- **Referencing `FlightModel`, `AircraftModel`, `SchemaV1` in any lingering code:** The compiler will catch these after deletion only if no `.swift` files conditionally import them. Do a grep sweep before declaring complete.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| String→Int16 in migration | Custom migration orchestrator | `NSEntityMigrationPolicy.createDestinationInstances` | Core Data calls it per record, handles transaction, rollback |
| Auto-migration trigger | Manual migration code in app launch | `shouldMigrateStoreAutomatically = true` on `NSPersistentStoreDescription` | Core Data detects version mismatch and runs migration at store load time |
| Multi-field search | Manual `filter` after `fetchAll` | `NSCompoundPredicate(orPredicateWithSubpredicates:)` on the fetch request | Pushes filtering to the Core Data layer, not in-memory |
| Count query | Fetch all and count array | `context.count(for:)` with `countResultType` | Does not load objects into memory |

**Key insight:** Core Data's migration engine handles rollback and crash recovery automatically when `shouldMigrateStoreAutomatically = true`. The migration policy subclass only needs to transform values — it does not need to manage transactions or idempotency.

---

## Common Pitfalls

### Pitfall 1: FlightEntity codegen not regenerating for V2

**What goes wrong:** Xcode auto-generates `FlightEntity+CoreDataProperties.swift` from the current model. If the generated file is stale (cached from V1), properties like `blockTime` are still typed `String?` and the new `Int16` scalar does not appear. `CoreDataFlightRepository.toDomain` reads `Int16` scalars but the generated file exposes `String?` — silent wrong value or crash.

**Why it happens:** Codegen is "Class Definition" mode — Xcode regenerates on build, but sometimes caches. If the file was manually edited or the derived data is stale, the old types persist.

**How to avoid:** After adding V2 and setting it as current, force a clean build (Product > Clean Build Folder) before writing `CoreDataFlightRepository`. Verify the generated `FlightEntity+CoreDataProperties.swift` shows `@NSManaged public var blockTime: Int16` (scalar) not `String?`.

**Warning signs:** Compiler accepts `e.blockTime` as `String?` when you try to assign an `Int16`.

### Pitfall 2: Custom migration policy class not found at runtime

**What goes wrong:** Core Data cannot find `FlightEntityMigrationPolicy` and logs "entity migration policy class not found" — migration silently skips custom logic and new scalar columns get 0/nil even for records that had valid string data.

**Why it happens:** The class name in the `.xcmappingmodel` must match the runtime class name exactly. For app-target classes this is `FlightEntityMigrationPolicy` (no module prefix). For Swift Package classes the module prefix is required, but the policy must be in the app target (D-15).

**How to avoid:** Set "Custom Policy" to `FlightEntityMigrationPolicy` (no prefix) in the mapping model. Verify on a test device with real v1 data by checking that `blockTime` values on fetched `Flight` domain objects are non-zero after migration.

**Warning signs:** After migration, `Flight.blockTime == 0` for records that had `blockTime = "1.5"` in v1.

### Pitfall 3: Migration options set too late in persistentContainer setup

**What goes wrong:** `shouldMigrateStoreAutomatically` and `shouldInferMappingModelAutomatically` are set on `description` after `loadPersistentStores` runs. Core Data uses the default options (auto-migrate with inferred mapping), finds the V1→V2 migration requires a custom policy it cannot infer, and either crashes or silently uses an inferred mapping that skips custom transformation.

**Why it happens:** The lazy var pattern in `FlightDatabaseService` has all setup before the `loadPersistentStores` call — but it is easy to accidentally insert the option-setting code after the guard that retrieves `description`.

**How to avoid:** Both option properties must be set in the block between `let description = container.persistentStoreDescriptions.first` and `container.loadPersistentStores { ... }`.

**Warning signs:** App launches without migrating V1 to V2 (old String values still present), or Core Data error "Can't find mapping model for migration."

### Pitfall 4: Flight.outTimeSeconds / inTimeSeconds rename breaks test fixtures

**What goes wrong:** Both `FlightTests.swift` and `FlightRepositoryTests.swift` use the current `Flight` init with `outTimeSeconds: 32400` and `inTimeSeconds: 39600`. After the struct rename to `outTime: Date?`, these calls become compile errors. If the planner treats the struct update and test update as separate tasks, the build breaks in between.

**Why it happens:** The `Flight` init parameter label changes are breaking changes — any code using the old labels fails to compile.

**How to avoid:** Treat `Flight.swift` update, `InMemoryFlightRepository.swift` update, `FlightTests.swift` update, and `FlightRepositoryTests.swift` update as a single atomic plan. The plan instruction must update all four files in one wave.

**Warning signs:** Compile error on `outTimeSeconds:` or `inTimeSeconds:` at any callsite.

### Pitfall 5: CloudKit schema sync after migration adding new attributes

**What goes wrong:** The V2 model adds 13 new attributes to `FlightEntity`. On first post-migration launch in Development, `initializeCloudKitSchema` runs (existing DEBUG code in `FlightDatabaseService`) and uploads the new schema. But on the first sync from a second device, CloudKit may reject records that have the new `Int16` fields if the Production schema has not been deployed.

**Why it happens:** Phase 8 is responsible for CloudKit Production schema deployment, but Phase 2 changes the model. The Development environment auto-initializes schema (existing code). Production does not.

**How to avoid:** Phase 2 is dev-only — no TestFlight during Phase 2. The Critical Reminder in STATE.md already captures "CloudKit schema must be verified in Production console before App Store submission (Phase 8)." No additional action needed in Phase 2, but the plan should note this constraint explicitly.

**Warning signs:** CloudKit sync errors on a second device after Phase 2 migration (acceptable in development; blocking before Phase 8 completes).

### Pitfall 6: Orphan SwiftData file deletion path

**What goes wrong:** `ModelContainerFactory.appGroupStoreURL()` is deleted in Phase 2. The orphan cleanup code (D-03) that deletes `blocktime.sqlite` cannot call it. If the cleanup code is written after the factory is deleted, the URL must be reconstructed inline.

**Why it happens:** D-03 says to check for the file and delete it. The only code that knew the path was `ModelContainerFactory`, which is deleted.

**How to avoid:** Inline the App Group URL construction in `Block_TimeApp.init()` orphan cleanup — `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.thezoolab.blocktime")?.appendingPathComponent("blocktime.sqlite")`. This is a one-liner and does not need a factory.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Swift Package, swift-tools-version 6.0) |
| Config file | `BlockTimeKit/Package.swift` |
| Quick run command | `cd BlockTimeKit && swift test --filter BlockTimeDomainTests` |
| Full suite command | `cd BlockTimeKit && swift test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REPO-05 | `Flight` init with `Int` time fields and `Date?` gate fields compiles | unit | `cd BlockTimeKit && swift test --filter FlightTests` | ✅ (needs update) |
| REPO-09 | `InMemoryFlightRepository` CRUD with updated `Flight` struct | unit | `cd BlockTimeKit && swift test --filter FlightRepositoryTests` | ✅ (needs update) |
| REPO-01 | `CoreDataFlightRepository` conforms to `FlightRepository` | compile-time | `xcodebuild build -scheme Block-Time` | ❌ Wave 0 |
| REPO-02 | Time string → Int16 minutes conversion | unit (inline in policy) | manual-only at migration time | — |
| REPO-04 | Gate string + date → UTC Date? conversion | unit (inline in policy) | manual-only at migration time | — |
| REPO-10 | CloudKit sync survives migration | integration (device) | manual-only | — |

### Sampling Rate

- Per task commit: `cd BlockTimeKit && swift test` (fast — no simulator needed)
- Per wave merge: `cd BlockTimeKit && swift test` + `xcodebuild build -scheme Block-Time -destination 'generic/platform=iOS'`
- Phase gate: Full suite green + app builds + launches on device before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `FlightTests.swift` — update `sample()` fixture to new `Flight` init signature (covers REPO-05)
- [ ] `FlightRepositoryTests.swift` — update `makeFlight()` fixture to new `Flight` init signature (covers REPO-09)

*(No new test files needed for Wave 0 — existing tests cover the domain struct and in-memory repository. Migration policy conversion logic is not separately unit-tested per D-01 design.)*

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Core Data model versioning, `.xcmappingmodel` creation | ✓ | 16.x (iOS 18.6+ target) | — |
| Swift Package Manager | `swift test` for BlockTimeKit tests | ✓ | 6.0 | — |
| Core Data framework | `NSEntityMigrationPolicy`, `NSFetchRequest` | ✓ | iOS 18.6+ | — |
| NSPersistentCloudKitContainer | Repository backing, CloudKit sync | ✓ | existing in FlightDatabaseService | — |

**Missing dependencies with no fallback:** None.

---

## Field Mapping: V1 FlightEntity → V2 FlightEntity → Flight Domain

### V1 → V2 (Core Data model)

The v1 model has been verified from `FlightDataModel.xcdatamodel/contents`. Notable:
- `customCount` is `Integer 16` scalar in v1 (not String) — no migration conversion needed
- `so1Name` and `so2Name` are already String? in v1 — straight mapping, no conversion
- `dayTakeoffs`, `nightTakeoffs`, `dayLandings`, `nightLandings` are `Integer 16` scalar — straight mapping
- All 8 time fields and 4 gate fields are `String?` — these require migration policy conversion
- `date`, `createdAt`, `modifiedAt`, `importedAt` are `Date` — straight mapping

### V2 FlightEntity → Flight domain (CoreDataFlightRepository.toDomain)

Scalar `Int16` → `Int` via `Int(e.fieldName)`. Date? → Date? direct. String? → `String` via `?? ""`.

**Fields currently in v1 model that are NOT currently in `Flight.swift` (to be added per D-13):**
- `so1Name: String?` → `so1Name: String` (missing from current struct)
- `so2Name: String?` → `so2Name: String` (missing from current struct)
- `customCount: Int16` → `customCount: Int` (missing from current struct)
- `dualTime` — new in V2, not in v1 entity (starts as 0)
- `scheduledDeparture`, `scheduledArrival` — promoted from gate strings to `Date?` in struct

**Fields in v1 NOT carried to Flight domain struct (infrastructure only):**
- `createdAt`, `modifiedAt`, `importedAt`, `importSessionID` — repository-internal, not in `Flight`

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection of `FlightDataModel.xcdatamodel/contents` — v1 attribute names and types verified
- Direct code inspection of `Flight.swift`, `FlightRepository.swift`, `InMemoryFlightRepository.swift` — exact current signatures
- Direct code inspection of `SwiftDataFlightRepository.swift` — template for `toDomain`/`apply` pattern
- Direct code inspection of `FlightDatabaseService.swift` (lines 105–177) — existing `persistentContainer` setup, CloudKit options
- Direct code inspection of `Block_TimeApp.swift` — exact SwiftData infrastructure to remove
- Direct code inspection of `FlightTests.swift`, `FlightRepositoryTests.swift` — test fixtures that must update atomically
- Apple CoreData documentation (from prior project STACK.md) — `NSEntityMigrationPolicy`, migration option keys
- `CONTEXT.md` D-01 through D-25 — all implementation decisions locked

### Secondary (MEDIUM confidence)
- `NSPersistentStoreDescription.shouldMigrateStoreAutomatically` / `shouldInferMappingModelAutomatically` as Swift property equivalents of the old dictionary option keys — consistent with Apple documentation pattern
- Custom policy class name without module prefix for app-target classes — consistent with Core Data behavior for non-package types

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components are existing Core Data APIs in use in the project
- Architecture: HIGH — all patterns derived from direct code inspection and locked CONTEXT.md decisions
- Pitfalls: HIGH — derived from actual v1 code structure and known Core Data migration behavior
- Migration policy conversion logic: HIGH — inline logic verified against `TimeStringConverter.swift` behavior (D-01 says inline, not reuse)

**Research date:** 2026-05-16
**Valid until:** 2026-06-16 (Core Data APIs stable; no external dependencies)
