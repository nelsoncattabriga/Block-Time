# Phase 1: Foundation - Research

**Researched:** 2026-05-15
**Domain:** SwiftData schema, BlockTimeKit Swift Package, FlightRepository protocol, Core Data → SwiftData migration
**Confidence:** HIGH (canonical files read, v1 schema fully audited, migration patterns verified)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** `BlockTimeKit` has **3 modules**: `BlockTimeDomain`, `BlockTimeCalculators`, `BlockTimeData`. No fourth Parsers module — parsers live inside `BlockTimeCalculators`. (NOTE: FOUND-03 in REQUIREMENTS.md says four modules — D-01 overrides this.)
- **D-02:** `FlightRepository` protocol lives in **`BlockTimeData`**. ViewModels import `BlockTimeData` to get the protocol + `InMemoryFlightRepository`.
- **D-03:** Migration service lives in **app target only** — not in `BlockTimeKit`.
- **D-04:** `ThemeService`, `AirportService`, `AppState`, and all other existing singletons stay in the app target in Phase 1.
- **D-05:** `@Model` in Swift Package is a non-starter. `@Model` classes and `SwiftDataFlightRepository` live in the **app target**. `BlockTimeKit` only gets the `FlightRepository` protocol and `InMemoryFlightRepository`.
- **D-06:** Crash safety = clear-and-retry. If `migrationStarted=true` and `migrationComplete=false` on launch, delete the partially-written SwiftData store and re-run.
- **D-07:** Two UserDefaults flags: `migrationStarted` (set at begin) and `migrationComplete` (set after row-count verification). Never invert write order.
- **D-08:** Row-count verification before setting `migrationComplete=true`. Exact count match required. Mismatch = log diagnostic, surface error, do NOT set flag.
- **D-09:** Migration runs with `cloudKitDatabase: .none`. After `migrationComplete=true`, force relaunch via `exit(0)`. New launch creates the real CloudKit-backed `ModelContainer`.

### Claude's Discretion
- Internal structure of `BlockTimeDomain` (which value types to define in Phase 1 vs later)
- `Flight` domain struct field layout (mirroring v1 `FlightEntity` fields)
- Exact UserDefaults keys for migration flags
- Whether to show a migration progress UI or keep it silent/splash-screen-level
- `InMemoryFlightRepository` API surface detail

### Deferred Ideas (OUT OF SCOPE)
- Moving `AirportService` into `BlockTimeCalculators` — deferred to Phase 2/3
- Migration progress UI — deferred to Phase 3 (Core UI)
- Batch-by-batch checkpoint migration — evaluated and rejected in favour of clear-and-retry
- In-process container swap after migration — evaluated and rejected as high risk
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | SwiftData schema wrapped in `VersionedSchema` / `SchemaV1` from first build — no unversioned schema ever shipped | VersionedSchema boilerplate documented; must wrap before any install |
| FOUND-02 | `ModelConfiguration` URL and App Group container pinned before any TestFlight | App Group = `group.com.thezoolab.blocktime`; exact `groupContainer` API documented below |
| FOUND-03 | `BlockTimeKit` local Swift Package created — 3 modules per D-01 (not 4) | Package.swift structure documented; `@Model` stays in app target per D-05 |
| FOUND-04 | `Flight` domain struct (value type, zero persistence coupling) is authoritative model | Field inventory from v1 schema complete; all fields catalogued below |
| FOUND-05 | `FlightRepository` protocol with `SwiftDataFlightRepository` (production) and `InMemoryFlightRepository` | Lives in `BlockTimeData` per D-02; protocol methods derived from v1 usage patterns |
| FOUND-06 | All time values stored as `TimeInterval` (seconds) in `@Model` — no String time fields | 8 String fields catalogued; conversion function requirements documented |
| FOUND-07 | All dates stored as UTC `Date` — local-time conversion at display layer only | v1 stores `date` as `Date` (UTC); `inTime`/`outTime`/`scheduledDeparture`/`scheduledArrival` stored as HH:MM strings — must be decoded to `Date` offsets or stored as `TimeInterval` offsets |
| FOUND-08 | CloudKit sync via `ModelConfiguration(cloudKitDatabase: .automatic)` with existing iCloud container | Container ID = `iCloud.com.thezoolab.blocktime`; all-optional properties required |
| FOUND-09 | One-time Core Data → SwiftData migration service; guarded by UserDefaults flag; crash-safe | Architecture fully designed per D-06/07/08/09; `@ModelActor` approach documented |
| FOUND-10 | Migration converts 8 String time fields to `TimeInterval`; handles nil, empty, HH:MM, decimal, malformed | All format variants found in v1 code; complete parser spec documented below |
| FOUND-11 | Migration runs via `@ModelActor` on background thread; main thread never blocked | `@ModelActor` pattern + detached task requirement documented; init-on-main-thread gotcha noted |
| FOUND-12 | SwiftUI previews work without CloudKit (`InMemoryFlightRepository` via environment) | Injection pattern via `@Environment` documented; `cloudKitDatabase: .none` required |
</phase_requirements>

---

## Summary

Phase 1 delivers the infrastructure that every subsequent phase depends on: the SwiftData `@Model` classes in the app target, the `BlockTimeKit` local Swift Package (three modules), the `FlightRepository` protocol + both implementations, and the one-time Core Data → SwiftData migration service.

The v1 Core Data schema has been fully audited. `FlightEntity` has 8 time fields stored as `String?` (blockTime, simTime, nightTime, p1Time, p1usTime, p2Time, instrumentTime, spInsTime), 4 integer landing/takeoff fields, 7 boolean approach fields, and miscellaneous string fields. All of these must be mapped to the new `FlightModel` SwiftData class with `TimeInterval` for times and `Date` for dates.

The highest risk in this phase is the time string converter (FOUND-10). V1 stores time in decimal-hours strings ("4.53") and HH:MM strings ("4:32") interchangeably depending on how the entry was created. The `TimeCalculationManager.timeStringToHours(_:)` in v1 handles both formats — this logic must be extracted into the migration service's converter. Any converter failure must be logged individually and must not silently produce zero for a non-zero source value.

**Primary recommendation:** Build and test the `TimeStringToIntervalConverter` as a pure function in isolation before wiring it into the migration service. Test it against a copy of the production `.sqlite` file with known record counts and spot-check specific flights with known block times.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 18+ (built-in) | Persistence, CloudKit sync | Required by project constraints |
| CoreData | iOS 18+ (built-in) | Read-only source during migration | Required to access v1 store |
| Swift Package Manager | Xcode 16+ | `BlockTimeKit` local package | Xcode-native; no external deps |
| XCTest | Xcode 16+ | Unit tests for migration converter and `InMemoryFlightRepository` | Xcode-native |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | Built-in | `TimeInterval`, `Date`, `UUID`, `UserDefaults` | Always |
| CloudKit | Built-in | CloudKit container access (migration disables, production enables) | In `FlightDatabaseService` setup |

### No External Dependencies

This phase introduces zero third-party Swift packages. All tooling is Apple-native.

---

## Architecture Patterns

### Recommended Project Structure

```
Block-Time/                          (Xcode project root)
├── BlockTimeKit/                    (local Swift Package — added via File → Add Local)
│   ├── Package.swift
│   └── Sources/
│       ├── BlockTimeDomain/         (Flight struct, AircraftInfo struct, zero external deps)
│       ├── BlockTimeCalculators/    (pure functions; imports BlockTimeDomain only)
│       └── BlockTimeData/           (FlightRepository protocol + InMemoryFlightRepository)
│           └── Tests/
│               └── BlockTimeDataTests/
├── Block-Time/                      (iOS app target)
│   ├── Models/
│   │   ├── FlightModel.swift        (@Model class — SwiftData, app target only)
│   │   ├── AircraftModel.swift      (@Model class — SwiftData, app target only)
│   │   └── SchemaV1.swift           (VersionedSchema wrapping FlightModel + AircraftModel)
│   ├── Repositories/
│   │   └── SwiftDataFlightRepository.swift   (production FlightRepository impl)
│   ├── Infrastructure/
│   │   └── ModelContainerFactory.swift       (creates ModelContainer with pinned URL)
│   └── Services/
│       └── CoreDataMigrationService.swift    (one-time migration, app target only)
```

### Pattern 1: VersionedSchema (FOUND-01)

Every `@Model` class must be wrapped in `VersionedSchema.SchemaV1` before the first TestFlight build. Shipping unversioned then adding VersionedSchema later crashes existing users on update.

```swift
// Source: WWDC23, Hacking with Swift VersionedSchema docs
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [FlightModel.self, AircraftModel.self]
    }

    @Model
    final class FlightModel {
        // ... all fields
    }

    @Model
    final class AircraftModel {
        // ... all fields
    }
}

// Migration plan — required to exist even if empty at v1
enum FlightMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
```

**Warning:** `SchemaMigrationPlan` with CloudKit (`cloudKitDatabase: .automatic`) throws a fatal error at container init — an Apple bug. Do not use `SchemaMigrationPlan` in the production CloudKit container. Use it only for in-memory test containers.

### Pattern 2: ModelContainerFactory with App Group URL (FOUND-02, FOUND-08)

```swift
// Source: Apple ModelConfiguration init docs; fatbobman App Group pattern
enum ModelContainerFactory {
    static let appGroupID = "group.com.thezoolab.blocktime"    // from WidgetFlightEntry.appGroupID
    static let iCloudContainerID = "iCloud.com.thezoolab.blocktime" // from entitlements

    /// Production container — CloudKit enabled, pinned to App Group URL
    static func makeProductionContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let storeURL = appGroupStoreURL()

        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(iCloudContainerID)
        )
        return try ModelContainer(for: schema, migrationPlan: FlightMigrationPlan.self,
                                  configurations: [config])
    }

    /// Migration-time container — CloudKit DISABLED (D-09)
    static func makeMigrationContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let storeURL = appGroupStoreURL()

        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// In-memory container — for tests and previews (FOUND-12)
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none   // CRITICAL: .none required for in-memory
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func appGroupStoreURL() -> URL {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )!
        return container.appendingPathComponent("blocktime.sqlite")
    }
}
```

**Why explicit URL is critical (FOUND-02):** Without pinning the URL to the App Group container, SwiftData picks a default location inside the app's sandbox. The widget extension has no access to that sandbox path. Adding/removing the widget extension would cause SwiftData to open a different file on next launch, making the user's data appear to vanish.

### Pattern 3: @Model Class Layout (FOUND-06, FOUND-07, FOUND-08)

All stored properties must be optional or have defaults — CloudKit requirement (FOUND-08). Time values use `TimeInterval` (seconds from epoch when representing elapsed time) with `= 0` default.

```swift
// Source: CloudKit constraints from STACK.md; v1 schema audit
@Model
final class FlightModel {

    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var importedAt: Date?
    var importSessionID: UUID?

    // MARK: - Route
    var date: Date = Date()         // UTC midnight of the flight date
    var fromAirport: String = ""
    var toAirport: String = ""
    var flightNumber: String = ""

    // MARK: - Aircraft
    var aircraftType: String = ""
    var aircraftReg: String = ""

    // MARK: - Times (stored as seconds; converted from v1 String fields)
    var blockTime: TimeInterval = 0      // v1: blockTime String?
    var simTime: TimeInterval = 0        // v1: simTime String?
    var nightTime: TimeInterval = 0      // v1: nightTime String?
    var p1Time: TimeInterval = 0         // v1: p1Time String?
    var p1usTime: TimeInterval = 0       // v1: p1usTime String?
    var p2Time: TimeInterval = 0         // v1: p2Time String?
    var instrumentTime: TimeInterval = 0 // v1: instrumentTime String?
    var spInsTime: TimeInterval = 0      // v1: spInsTime String?

    // MARK: - Gate/slot times (stored as offset seconds from midnight UTC of date)
    // v1 stores these as HH:MM strings; v2 stores as seconds-from-midnight on date
    var outTimeSeconds: TimeInterval?    // v1: outTime String? e.g. "09:15" → 33300
    var inTimeSeconds: TimeInterval?     // v1: inTime String?
    var scheduledDepartureSeconds: TimeInterval?  // v1: scheduledDeparture String?
    var scheduledArrivalSeconds: TimeInterval?    // v1: scheduledArrival String?

    // MARK: - Movements
    var dayTakeoffs: Int = 0
    var nightTakeoffs: Int = 0
    var dayLandings: Int = 0
    var nightLandings: Int = 0
    var customCount: Int = 0

    // MARK: - Approach booleans
    var isILS: Bool = false
    var isGLS: Bool = false
    var isRNP: Bool = false
    var isNPA: Bool = false
    var isAIII: Bool = false

    // MARK: - Role / Type
    var isPilotFlying: Bool = false
    var isPositioning: Bool = false

    // MARK: - Crew
    var captainName: String = ""
    var foName: String = ""
    var so1Name: String = ""
    var so2Name: String = ""

    // MARK: - Notes
    var remarks: String = ""

    // MARK: - Relationship (optional per CloudKit constraint)
    @Relationship(deleteRule: .nullify, inverse: \AircraftModel.flights)
    var aircraft: AircraftModel?
}
```

**Note on `Int` fields:** CloudKit requires all properties to be optional or defaulted. `Int` with `= 0` is safe. `Int16` (as used in v1 Core Data) maps to `Int` in SwiftData — no special handling needed.

**Note on `outTime`/`inTime`/`scheduledDeparture`/`scheduledArrival`:** These are HH:MM strings in v1. Converting to seconds-from-midnight (a `TimeInterval?`) is cleaner than storing as full `Date` objects (which would require knowing the actual UTC date, adding complexity in migration when local vs UTC is ambiguous). Stored as `TimeInterval?` (nil if empty in v1).

### Pattern 4: @ModelActor Migration Service (FOUND-11)

```swift
// Source: STACK.md ModelActor section; fatbobman concurrent programming in SwiftData
@ModelActor
actor CoreDataMigrationActor {
    func importLegacyFlights(_ entities: [LegacyFlightSnapshot]) throws -> Int {
        var count = 0
        for snapshot in entities {
            let flight = FlightModel()
            // Map all fields via TimeStringConverter
            flight.blockTime = TimeStringConverter.toSeconds(snapshot.blockTime)
            // ... all fields
            modelContext.insert(flight)
            count += 1
        }
        try modelContext.save()
        return count
    }
}

// Caller — must be launched from a detached Task, NOT from @MainActor code directly
// Source: STACK.md ModelActor init-on-main-thread gotcha
Task.detached(priority: .userInitiated) {
    let actor = CoreDataMigrationActor(modelContainer: migrationContainer)
    let count = try await actor.importLegacyFlights(snapshots)
}
```

**Critical:** If the actor is initialized inside a `@MainActor` context (e.g., inside a SwiftUI `.task` modifier), its executor binds to the main thread and no background benefit is gained. Always initialize from `Task.detached`.

### Pattern 5: Migration Service State Machine (FOUND-09, D-06, D-07, D-08, D-09)

```swift
// Migration flow — runs from SplashScreenView.onAppear (matching v1 pattern)
// Source: v1 SplashScreenView.swift; user decisions D-06/07/08/09

enum MigrationState {
    case notStarted
    case crashed           // started=true, complete=false
    case inProgress
    case complete
}

class CoreDataMigrationService {
    private let startedKey = "v2MigrationStarted"     // D-07
    private let completeKey = "v2MigrationComplete"   // D-07

    var state: MigrationState {
        let started = UserDefaults.standard.bool(forKey: startedKey)
        let complete = UserDefaults.standard.bool(forKey: completeKey)
        switch (started, complete) {
        case (false, _):    return .notStarted
        case (true, true):  return .complete
        case (true, false): return .crashed
        }
    }

    func runIfNeeded() async throws {
        switch state {
        case .complete:
            return  // Nothing to do
        case .crashed:
            // D-06: Delete partial SwiftData store, retry from scratch
            deleteSwiftDataStore()
            fallthrough
        case .notStarted:
            UserDefaults.standard.set(true, forKey: startedKey)  // D-07: set FIRST
            try await performMigration()
            // D-08: Verify row counts BEFORE setting complete
            guard rowCountsMatch() else {
                throw MigrationError.rowCountMismatch
            }
            UserDefaults.standard.set(true, forKey: completeKey) // D-07: set LAST
            exit(0)  // D-09: force relaunch for CloudKit-enabled container
        case .inProgress:
            break
        }
    }
}
```

### Pattern 6: FlightRepository Protocol (FOUND-05)

Lives in `BlockTimeData` module (D-02). Methods derived from v1 usage patterns across `FlightDatabaseService`, `FlightTimeExtractorViewModel`, `BulkEditViewModel`, `FlightMapViewModel`.

```swift
// Source: D-02; v1 FlightDatabaseService and ViewModel usage audit
public protocol FlightRepository: Sendable {
    func fetchAll() async throws -> [Flight]
    func fetchRecent(days: Int) async throws -> [Flight]
    func fetch(from: Date, to: Date) async throws -> [Flight]
    func insert(_ flight: Flight) async throws
    func update(_ flight: Flight) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
    func count() async throws -> Int
    func search(query: String) async throws -> [Flight]
}
```

### Pattern 7: InMemoryFlightRepository (FOUND-12)

Lives in `BlockTimeData` module. No SwiftData dependency — pure Swift array.

```swift
// Source: STACK.md testing pattern; D-02
@Observable
public final class InMemoryFlightRepository: FlightRepository {
    private var storage: [UUID: Flight] = [:]

    public func fetchAll() async -> [Flight] {
        Array(storage.values).sorted { $0.date > $1.date }
    }
    public func insert(_ flight: Flight) async throws {
        storage[flight.id] = flight
    }
    public func update(_ flight: Flight) async throws {
        storage[flight.id] = flight
    }
    public func delete(id: UUID) async throws {
        storage.removeValue(forKey: id)
    }
    public func count() async throws -> Int { storage.count }
    // ... etc.
}
```

Injected into SwiftUI previews via environment:

```swift
// Preview usage
#Preview {
    FlightListView()
        .environment(InMemoryFlightRepository.seeded())
}
```

### Anti-Patterns to Avoid

- **@Model in Swift Package:** Macro expansion fails or produces incomplete output. All `@Model` classes go in app target (D-05).
- **Unversioned schema on first ship:** Cannot be corrected without a forced update + another migration. Wrap in `SchemaV1` on day one.
- **`cloudKitDatabase: .automatic` on in-memory container:** Throws at container creation. Always use `.none` for in-memory.
- **Setting `migrationComplete` before row-count verification:** Silent data loss becomes permanent. Always verify (D-08).
- **`@ModelActor` init inside `@MainActor` code:** Actor runs on main thread, blocking UI. Use `Task.detached`.
- **Passing `@Model` instances across actor boundaries:** Swift 6 concurrency error. Pass `PersistentIdentifier`, refetch.
- **Setting relationship before `context.insert(_:)`:** Crashes at runtime. Insert first, set relationship after.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CloudKit sync | Custom sync engine | `ModelConfiguration(cloudKitDatabase: .automatic)` | SwiftData handles conflict resolution, retry, incremental sync |
| Background persistence | DispatchQueue + shared context | `@ModelActor` | Thread-safe by design; eliminates race conditions |
| In-memory test store | Custom mock store | `ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)` | Identical API to production; no behaviour differences |
| Schema versioning | Manual migration scripts | `VersionedSchema` + `SchemaMigrationPlan` | SwiftData runs on-open; handles multi-version chains |
| App Group URL | Re-derive from bundle ID | `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` | Canonical; matches WidgetFlightEntry.appGroupID |

**Key insight:** The time string converter is the one thing that MUST be hand-rolled because it's domain-specific to v1's storage format. Everything else has a SwiftData/Apple API.

---

## Time String to TimeInterval Conversion (FOUND-10)

### Complete Format Inventory (from v1 codebase audit)

V1 stores time fields as `String?`. The following formats appear in production data based on `TimeCalculationManager.timeStringToHours(_:)` and `FlightTimeExtractorViewModel`:

| Format | Example | How Entered | Conversion |
|--------|---------|-------------|------------|
| `nil` | — | Field never set | → `0` |
| `""` (empty string) | `""` | Field cleared | → `0` |
| Decimal hours (2dp) | `"4.53"` | Most common: calculated from OUT/IN | → `Double("4.53")! * 3600` |
| Decimal hours (1dp) | `"4.5"` | Less precise entry | → `Double("4.5")! * 3600` |
| Decimal hours (integer) | `"4"` | Sim time often whole hours | → `Double("4")! * 3600` |
| `"HH:MM"` | `"4:32"` | Manual HH:MM entry | → `(4 * 3600) + (32 * 60)` |
| `"H:MM"` | `"9:05"` | Single-digit hour | → `(9 * 3600) + (5 * 60)` |
| `"HH:M"` | `"4:5"` | Single-digit minute (rare) | → `(4 * 3600) + (5 * 60)` |
| `"0"` | `"0"` | No time recorded | → `0` |
| `"0.0"` | `"0.0"` | Explicit zero | → `0` |
| Malformed/legacy | `"-"`, `"N/A"`, `"--:--"`, whitespace | Import artifacts | → `0` + **log warning** |

### Required Converter Behaviour

```swift
// Must live in migration service (app target). NOT in BlockTimeKit.
// Source: TimeCalculationManager.timeStringToHours + full format audit above
enum TimeStringConverter {
    /// Converts a v1 time String? to TimeInterval (seconds).
    /// Returns 0 for nil, empty, zero, or unrecognised formats.
    /// Logs a warning (non-fatal) for malformed non-empty strings.
    static func toSeconds(_ raw: String?) -> TimeInterval {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, trimmed != "0", trimmed != "0.0" else {
            return 0
        }

        if trimmed.contains(":") {
            // HH:MM or H:MM or HH:M format
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  let hours = Int(parts[0]),
                  let minutes = Int(parts[1]),
                  hours >= 0, minutes >= 0, minutes < 60 else {
                LogManager.shared.warning("TimeStringConverter: malformed HH:MM '\(trimmed)'")
                return 0
            }
            return TimeInterval(hours * 3600 + minutes * 60)
        } else {
            // Decimal hours
            guard let hours = Double(trimmed), hours.isFinite, hours >= 0 else {
                LogManager.shared.warning("TimeStringConverter: malformed decimal '\(trimmed)'")
                return 0
            }
            return hours * 3600.0
        }
    }
}
```

**Critical rule:** Any non-empty, non-zero string that fails to parse must log a warning WITH the raw value and record identifier. Silent zero for a non-zero source is data loss.

### HH:MM Time-of-Day Strings (outTime, inTime, scheduledDeparture, scheduledArrival)

These are departure/arrival clock times, not durations. They are stored as `"HH:mm"` strings in v1 and must become `TimeInterval?` (seconds from midnight UTC on `date`) in v2.

```swift
static func clockStringToSecondsFromMidnight(_ raw: String?) -> TimeInterval? {
    guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
          trimmed.count >= 4 else { return nil }
    let clean = trimmed.replacingOccurrences(of: ":", with: "")
    guard clean.count == 4,
          let hours = Int(clean.prefix(2)),
          let minutes = Int(clean.suffix(2)),
          hours < 24, minutes < 60 else { return nil }
    return TimeInterval(hours * 3600 + minutes * 60)
}
```

---

## Common Pitfalls

### Pitfall 1: App Group Store URL Not Pinned
**What goes wrong:** SwiftData opens a store in the app's private sandbox instead of the shared App Group container. Widget extension reads an empty store. Users see no data in the widget.
**Why it happens:** `ModelConfiguration` without an explicit `url` defaults to a path inside `~/Library/Application Support/` which the widget extension cannot access.
**How to avoid:** Always pass `url: ModelContainerFactory.appGroupStoreURL()` in every non-in-memory `ModelConfiguration`.
**Warning signs:** Widget shows "No upcoming flights" even when flights exist in app.

### Pitfall 2: Unversioned Schema Shipped
**What goes wrong:** Adding `VersionedSchema` to an already-shipped app crashes on update — SwiftData cannot reconcile the unversioned on-disk schema with the versioned in-code schema.
**Why it happens:** Delaying `VersionedSchema` wrapping to "do it later."
**How to avoid:** `SchemaV1` wrapper must be in place before any device install, including TestFlight. Verify the wrapper is in place before any test build.
**Warning signs:** Fatal crash at container creation on app update; no recovery without delete and reinstall.

### Pitfall 3: SchemaMigrationPlan + CloudKit Fatal Error
**What goes wrong:** App crashes at container creation with a fatal error from `NSPersistentCloudKitContainer`.
**Why it happens:** Apple bug — `SchemaMigrationPlan` with CloudKit enabled is unsupported as of iOS 18.
**How to avoid:** Production container does NOT pass `migrationPlan:`. The `FlightMigrationPlan` is only used in test containers (`cloudKitDatabase: .none`). Future schema changes migrate via the application layer, not via `SchemaMigrationPlan`.
**Warning signs:** Crash at app launch after adding a migration stage.

### Pitfall 4: @ModelActor Init on Main Thread
**What goes wrong:** Migration blocks the main thread; UI is unresponsive during migration of large logbooks.
**Why it happens:** `CoreDataMigrationActor(modelContainer:)` called inside `@MainActor` code (e.g., a `.task` modifier). The actor's executor binds to the main thread.
**How to avoid:** Always create the actor inside `Task.detached(priority: .userInitiated)`.
**Warning signs:** App freezes during splash screen; Instruments shows 100% main-thread CPU during migration.

### Pitfall 5: migrationComplete Set Before Row-Count Verification
**What goes wrong:** Migration completes with missing records (e.g., network interruption killed a save mid-batch) but the app never retries.
**Why it happens:** Setting the flag immediately after `modelContext.save()` without verifying counts.
**How to avoid:** D-08 is non-negotiable. Count Core Data records, count SwiftData records, require exact match before setting `migrationComplete=true`.
**Warning signs:** User reports missing flights after update; `migrationComplete=true` is already set so migration never retries.

### Pitfall 6: Relationship Set Before insert
**What goes wrong:** Runtime crash when assigning `flight.aircraft = aircraft` on a `FlightModel` that hasn't been inserted into a `ModelContext`.
**Why it happens:** SwiftData relationships require both objects to be in a context before linking.
**How to avoid:** Call `modelContext.insert(flight)` before setting any relationship properties.
**Warning signs:** EXC_BAD_ACCESS during migration when wiring aircraft relationships.

### Pitfall 7: Time String with Single-Digit Minute
**What goes wrong:** `"4:5"` parses as 4 hours 5 minutes in some implementations, and fails in others.
**Why it happens:** `Int("5")` succeeds but `split(separator: ":")` may leave `"5"` as a single-character component which passes validation — ensure the converter handles single-digit minutes explicitly.
**How to avoid:** The converter spec above handles `parts[1]` as `Int` without requiring a leading zero. Test `"1:5"`, `"10:05"`, `"10:5"` in unit tests.

### Pitfall 8: CloudKit Record Type Name Divergence (Phase 7 risk, set up correctly in Phase 1)
**What goes wrong:** v1 used `CD_FlightEntity` as the CloudKit record type. If SwiftData generates a different record type name, v1 iCloud data never syncs to v2.
**Why it happens:** SwiftData uses the class name as the CloudKit record type by default.
**How to avoid:** Verify the actual CloudKit record type name in CloudKit Console before Production deploy (Phase 7). In Phase 1, use the same class name as v1 entity: name the SwiftData class `FlightEntity` (not `FlightModel`) if the CloudKit record type must match, OR accept that v2 creates new CloudKit records and v1 records are abandoned. This is a Phase 7 decision but the Phase 1 class naming affects it.

**Recommendation:** Name the SwiftData class `FlightModel` (clearly distinct from `FlightEntity`). Accept that v2 writes new CloudKit records. The migration service reads v1 Core Data store locally — CloudKit history from v1 is not needed, only the local SQLite data. This is the safest approach and avoids naming collisions.

---

## v1 Core Data Schema — Full Field Inventory

From `FlightDataModel.xcdatamodel/contents` (canonical source):

### FlightEntity

| Field | CD Type | Default | v2 Type | Conversion |
|-------|---------|---------|---------|------------|
| `id` | UUID | nil | `UUID = UUID()` | Direct copy |
| `date` | Date | nil | `Date = Date()` | Direct copy (already UTC in v1) |
| `createdAt` | Date | nil | `Date = Date()` | Direct copy |
| `modifiedAt` | Date | nil | `Date = Date()` | Direct copy |
| `importedAt` | Date | nil | `Date?` | Direct copy |
| `importSessionID` | UUID | nil | `UUID?` | Direct copy |
| `fromAirport` | String | nil | `String = ""` | `?? ""` |
| `toAirport` | String | nil | `String = ""` | `?? ""` |
| `flightNumber` | String | nil | `String = ""` | `?? ""` |
| `aircraftType` | String | nil | `String = ""` | `?? ""` |
| `aircraftReg` | String | nil | `String = ""` | `?? ""` |
| `captainName` | String | nil | `String = ""` | `?? ""` |
| `foName` | String | nil | `String = ""` | `?? ""` |
| `so1Name` | String | nil | `String = ""` | `?? ""` |
| `so2Name` | String | nil | `String = ""` | `?? ""` |
| `remarks` | String | nil | `String = ""` | `?? ""` (use `safeRemarks` accessor) |
| `blockTime` | String | nil | `TimeInterval = 0` | `TimeStringConverter.toSeconds(_:)` |
| `simTime` | String | nil | `TimeInterval = 0` | `TimeStringConverter.toSeconds(_:)` |
| `nightTime` | String | nil | `TimeInterval = 0` | `TimeStringConverter.toSeconds(_:)` |
| `p1Time` | String | nil | `TimeInterval = 0` | `TimeStringConverter.toSeconds(_:)` |
| `p1usTime` | String | nil | `TimeInterval = 0` | `TimeStringConverter.toSeconds(_:)` |
| `p2Time` | String | nil | `TimeInterval = 0` | `TimeStringConverter.toSeconds(_:)` |
| `instrumentTime` | String | nil | `TimeInterval = 0` | `TimeStringConverter.toSeconds(_:)` |
| `spInsTime` | String | nil | `TimeInterval = 0` | `TimeStringConverter.toSeconds(_:)` |
| `outTime` | String | nil | `TimeInterval?` | `clockStringToSecondsFromMidnight(_:)` |
| `inTime` | String | nil | `TimeInterval?` | `clockStringToSecondsFromMidnight(_:)` |
| `scheduledDeparture` | String | nil | `TimeInterval?` | `clockStringToSecondsFromMidnight(_:)` |
| `scheduledArrival` | String | nil | `TimeInterval?` | `clockStringToSecondsFromMidnight(_:)` |
| `dayTakeoffs` | Integer 16 | 0 | `Int = 0` | Direct (scalar to Int) |
| `nightTakeoffs` | Integer 16 | 0 | `Int = 0` | Direct |
| `dayLandings` | Integer 16 | 0 | `Int = 0` | Direct |
| `nightLandings` | Integer 16 | 0 | `Int = 0` | Direct |
| `customCount` | Integer 16 | 0 | `Int = 0` | Direct |
| `isPilotFlying` | Boolean | nil | `Bool = false` | `?? false` |
| `isPositioning` | Boolean | false | `Bool = false` | `?? false` |
| `isILS` | Boolean | nil | `Bool = false` | `?? false` |
| `isGLS` | Boolean | nil | `Bool = false` | `?? false` |
| `isRNP` | Boolean | nil | `Bool = false` | `?? false` |
| `isNPA` | Boolean | nil | `Bool = false` | `?? false` |
| `isAIII` | Boolean | nil | `Bool = false` | `?? false` |

### AircraftEntity

| Field | CD Type | v2 Type | Conversion |
|-------|---------|---------|------------|
| `id` | String | `String = ""` | `?? ""` |
| `type` | String | `String = ""` | `?? ""` |
| `registration` | String | `String = ""` | `?? ""` |
| `fullRegistration` | String | `String = ""` | `?? ""` |
| `createdAt` | Date | `Date = Date()` | `?? Date()` |

**Aircraft relationship:** v1 has no Core Data relationship between `FlightEntity` and `AircraftEntity` — the schema shows `aircraftReg` and `aircraftType` as plain String fields on `FlightEntity`. The `AircraftEntity` is a separate roster of aircraft. In v2, the relationship in `FlightModel` is optional and may be wired by matching `aircraftReg` during migration, or left nil and wired later in Phase 3. Phase 1 should migrate both entities independently and leave the relationship nil.

---

## Package.swift Structure (FOUND-03, D-01)

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BlockTimeKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "BlockTimeDomain", targets: ["BlockTimeDomain"]),
        .library(name: "BlockTimeCalculators", targets: ["BlockTimeCalculators"]),
        .library(name: "BlockTimeData", targets: ["BlockTimeData"]),
    ],
    targets: [
        // Zero external deps. Foundation only.
        .target(name: "BlockTimeDomain", dependencies: []),

        // Pure functions. Imports BlockTimeDomain.
        .target(name: "BlockTimeCalculators", dependencies: ["BlockTimeDomain"]),

        // FlightRepository protocol + InMemoryFlightRepository.
        // Imports BlockTimeDomain. Does NOT import SwiftData.
        .target(name: "BlockTimeData", dependencies: ["BlockTimeDomain"]),

        .testTarget(
            name: "BlockTimeDataTests",
            dependencies: ["BlockTimeData"],
            path: "Tests/BlockTimeDataTests"
        ),
        .testTarget(
            name: "BlockTimeDomainTests",
            dependencies: ["BlockTimeDomain"],
            path: "Tests/BlockTimeDomainTests"
        ),
    ]
)
```

**What goes in each module:**

| Module | Contents | Imports |
|--------|----------|---------|
| `BlockTimeDomain` | `Flight` struct, `AircraftInfo` struct, `Duty` struct, `FRMSResult` struct | Foundation only |
| `BlockTimeCalculators` | `FRMSCalculator`, `NightTimeCalculator`, `TimeConverter`, CSV/ACARS/roster parsers (Phase 2) | BlockTimeDomain |
| `BlockTimeData` | `FlightRepository` protocol, `InMemoryFlightRepository` | BlockTimeDomain |

**What stays in the app target:**

| Item | Reason |
|------|--------|
| `FlightModel` (@Model class) | `@Model` macro fails in Swift Packages (D-05) |
| `AircraftModel` (@Model class) | Same reason |
| `SwiftDataFlightRepository` | Imports SwiftData; must be in app target |
| `ModelContainerFactory` | Imports SwiftData; must be in app target |
| `CoreDataMigrationService` | Imports CoreData + SwiftData; one-shot app concern (D-03) |
| `SchemaV1` | Wraps @Model classes; must be in app target |

---

## Flight Domain Struct (FOUND-04)

The `Flight` struct lives in `BlockTimeDomain`. It is the value-type representation of a flight record, used by all calculators and ViewModels. It mirrors the `FlightModel` fields but has no persistence annotations.

```swift
// BlockTimeDomain/Sources/BlockTimeDomain/Flight.swift
public struct Flight: Sendable, Identifiable, Hashable {
    public var id: UUID
    public var date: Date           // UTC
    public var fromAirport: String
    public var toAirport: String
    public var flightNumber: String
    public var aircraftType: String
    public var aircraftReg: String

    // Times in seconds
    public var blockTime: TimeInterval
    public var simTime: TimeInterval
    public var nightTime: TimeInterval
    public var p1Time: TimeInterval
    public var p1usTime: TimeInterval
    public var p2Time: TimeInterval
    public var instrumentTime: TimeInterval
    public var spInsTime: TimeInterval

    // Seconds from midnight UTC
    public var outTimeSeconds: TimeInterval?
    public var inTimeSeconds: TimeInterval?

    // Movements
    public var dayTakeoffs: Int
    public var nightTakeoffs: Int
    public var dayLandings: Int
    public var nightLandings: Int

    // Role
    public var isPilotFlying: Bool
    public var isPositioning: Bool

    // Approaches
    public var isILS: Bool
    public var isGLS: Bool
    public var isRNP: Bool
    public var isNPA: Bool
    public var isAIII: Bool

    // Crew
    public var captainName: String
    public var foName: String
    public var remarks: String
}
```

**Mapping between `Flight` and `FlightModel`:** `SwiftDataFlightRepository` (app target) converts between them. `FlightModel` → `Flight` is a mapping function; `Flight` → `FlightModel` creates or updates the persistent object.

---

## SplashScreen Integration Pattern

The migration service triggers from `SplashScreenView.onAppear`, consistent with v1's pattern for one-time launch tasks (3 existing migrations use this pattern: `simulatorFlightMigrationV2Completed`, `aircraftTypeA321ToA21NMigrationCompleted`, `simFlightP1TimesMigrationCompleted`).

The v2 migration must run BEFORE the main tab view is presented (before `isActive = true` in `SplashScreenView`). This means the `.task` modifier on the splash view is the right hook — it's async and can `await` the migration completion before transitioning.

The `exit(0)` relaunch (D-09) means the user will see the splash screen twice on migration day. This is acceptable for a one-time event.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (built-in, Xcode 16) |
| Config file | Xcode test scheme (no external config file) |
| Quick run command | `xcodebuild test -scheme BlockTimeKit -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -scheme "Block-Time" -destination 'platform=iOS Simulator,name=iPhone 16'` |

BlockTimeKit package tests run on macOS without a simulator — `BlockTimeDomain` and `BlockTimeData` have no UIKit/SwiftUI/SwiftData dependency, so package tests are fast and run anywhere.

Migration service tests require a simulator (they instantiate `ModelContainer`).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Test Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | `SchemaV1` wraps `FlightModel` at container creation | Integration | `xcodebuild test -scheme Block-Time -only-testing:Block-TimeTests/SchemaVersionTests` | No — Wave 0 |
| FOUND-02 | App Group URL resolves to correct path | Unit | `xcodebuild test -scheme BlockTimeKit -only-testing:BlockTimeKitTests/ModelContainerFactoryTests` | No — Wave 0 |
| FOUND-03 | Package compiles with 3 modules, no SwiftData import in BlockTimeData | Build | `swift build --package-path BlockTimeKit` | No — Wave 0 |
| FOUND-04 | `Flight` struct is `Sendable` and `Hashable` | Unit | Package test | No — Wave 0 |
| FOUND-05 | `InMemoryFlightRepository` satisfies all protocol methods | Unit | `xcodebuild test -scheme BlockTimeKit -only-testing:BlockTimeDataTests` | No — Wave 0 |
| FOUND-06 | `blockTime` round-trips: String → TimeInterval → String matches original precision | Unit | Migration converter test | No — Wave 0 |
| FOUND-10 | All 10 format variants parse correctly; malformed logs and returns 0 | Unit | `TimeStringConverterTests` | No — Wave 0 |
| FOUND-09 | Row counts match before `migrationComplete` is set | Integration | Migration fixture test with real `.sqlite` | No — Wave 0 |
| FOUND-09 | Crash recovery: partial store deleted, migration retries successfully | Integration | Migration crash simulation test | No — Wave 0 |
| FOUND-11 | Migration runs on background thread (not main actor) | Integration | `XCTAssertFalse(Thread.isMainThread)` inside actor | No — Wave 0 |
| FOUND-12 | SwiftUI preview with `InMemoryFlightRepository` compiles and runs | Manual / Build | Xcode preview | No — Wave 0 |

### Key Test: TimeStringConverter — Fixture Cases

The `TimeStringConverterTests` must cover every format variant. These test cases must be written before the converter implementation:

```swift
// All cases must pass
assert(TimeStringConverter.toSeconds(nil) == 0)
assert(TimeStringConverter.toSeconds("") == 0)
assert(TimeStringConverter.toSeconds("0") == 0)
assert(TimeStringConverter.toSeconds("0.0") == 0)
assert(TimeStringConverter.toSeconds("4.53") == 16308)      // 4h 31m 48s
assert(TimeStringConverter.toSeconds("4.5") == 16200)       // 4h 30m
assert(TimeStringConverter.toSeconds("4") == 14400)         // 4h
assert(TimeStringConverter.toSeconds("4:32") == 16320)      // 4h 32m
assert(TimeStringConverter.toSeconds("9:05") == 32700)      // 9h 5m
assert(TimeStringConverter.toSeconds("4:5") == 14700)       // 4h 5m (single-digit minute)
assert(TimeStringConverter.toSeconds("-") == 0)             // malformed — log warning, return 0
assert(TimeStringConverter.toSeconds("N/A") == 0)           // malformed
assert(TimeStringConverter.toSeconds("  4.53  ") == 16308)  // whitespace trimmed
```

### Key Test: Migration with Real .sqlite Fixture

This is the highest-confidence validation:

1. Copy a real production `FlightDataModel.sqlite` into `Block-Time/Tests/Fixtures/`.
2. In test: load it via `NSPersistentContainer` (read-only), count records, run migration into in-memory SwiftData store, count records, assert equal.
3. Spot-check 3-5 specific flights by their UUID: verify `blockTime`, `date`, `fromAirport`, `toAirport` round-trip correctly.
4. The fixture file must be committed to the repo (it's internal test data, not a user secret).

### Key Test: Crash Recovery Simulation

```swift
// Simulate crash mid-migration:
// 1. Set migrationStarted = true in UserDefaults
// 2. Leave migrationComplete = false
// 3. Leave a partially-written SwiftData store at the App Group URL
// 4. Call migrationService.runIfNeeded()
// 5. Assert: partial store was deleted
// 6. Assert: migration completed successfully
// 7. Assert: migrationComplete = true
// 8. Assert: SwiftData record count == Core Data record count
```

### Wave 0 Gaps

All test files must be created before implementation begins:

- [ ] `BlockTimeKit/Tests/BlockTimeDataTests/FlightRepositoryTests.swift` — InMemoryFlightRepository protocol conformance
- [ ] `Block-Time/Block-TimeTests/Migration/TimeStringConverterTests.swift` — all format variants
- [ ] `Block-Time/Block-TimeTests/Migration/CoreDataMigrationServiceTests.swift` — fixture-based integration test
- [ ] `Block-Time/Block-TimeTests/Migration/CrashRecoveryTests.swift` — crash simulation
- [ ] `Block-Time/Block-TimeTests/Schema/SchemaV1Tests.swift` — container creation with VersionedSchema
- [ ] `Block-Time/Block-TimeTests/Fixtures/` — directory for production `.sqlite` fixture file

---

## Environment Availability

This phase is code/configuration only. External dependencies:

| Dependency | Required By | Available | Version | Notes |
|------------|------------|-----------|---------|-------|
| Xcode 16+ | Swift Package creation, @Model macro | Assumed ✓ | 16.x | Project already builds on Xcode 16 |
| iOS 18.6+ Simulator | `ModelContainer` tests | Assumed ✓ | 18.6 | Project already targets iOS 18.6 |
| Real v1 `.sqlite` file | Migration fixture test | Manual step | — | Must be obtained from device and added to test fixtures |
| iCloud account (device) | CloudKit integration test | Device only | — | Not needed for unit tests; needed for Phase 7 |

**Missing with no fallback:** A real v1 production `.sqlite` file is required for the migration fixture test. This cannot be synthesised — it must come from a device running the current production app. This is a manual step that must happen before the migration tests can be fully validated.

---

## Open Questions

1. **AircraftEntity relationship wiring during migration**
   - What we know: v1 has no Core Data relationship between `FlightEntity` and `AircraftEntity`. Both are independent entities.
   - What's unclear: Should Phase 1 migration attempt to wire the `FlightModel.aircraft` relationship by matching `aircraftReg`, or leave it nil?
   - Recommendation: Leave relationship nil in Phase 1. Wire it in Phase 3 when the aircraft management UI is rebuilt. Avoids complex matching logic during migration.

2. **`schemaV1` naming convention for `@Model` classes**
   - What we know: Nesting `@Model` inside an enum (`SchemaV1.FlightModel`) is the documented VersionedSchema pattern.
   - What's unclear: Does the nested class name affect the CloudKit record type? (i.e., is it `CD_SchemaV1.FlightModel` or `CD_FlightModel`?)
   - Recommendation: Verify by inspecting the CloudKit Development console after first build. Phase 1 should include a checklist item to check this before Phase 7. This is purely a Phase 7 concern but must be observed in Phase 1.

3. **Migration trigger timing: before or after CloudKit container is initialized?**
   - What we know: D-09 says migration runs with `cloudKitDatabase: .none`. The production container (`.automatic`) is only created on the second launch (after `exit(0)`).
   - What's unclear: Does `FlightDatabaseService.shared` (the Core Data singleton) need to be accessed before or after creating the SwiftData migration container? If `FlightDatabaseService.shared` is accessed lazily and this is the first launch, there should be no race condition.
   - Recommendation: Create the migration `ModelContainer` first (with `.none`), then access `FlightDatabaseService.shared.persistentContainer` to read Core Data records. The lazy initializer in v1 handles this safely.

---

## Project Constraints (from CLAUDE.md)

- Swift 6 strict concurrency — all code must compile with `SWIFT_STRICT_CONCURRENCY = complete`
- `@Observable` over `ObservableObject` — `InMemoryFlightRepository` should be `@Observable`
- `async/await` for all async operations — no `DispatchQueue` callbacks in new code
- `guard` for early exits
- Prefer value types — `Flight`, `AircraftInfo` structs; `@Model` classes only where required by SwiftData
- Never remove existing features — migration service is additive; v1 launch path (`FlightDatabaseService.shared`) must not be broken for v1 users
- `NavigationStack` not `NavigationView` — N/A for Phase 1 (no UI)
- `@AppStorage` safety — migration flags use `UserDefaults.standard` directly (not `@AppStorage`) since they are read in a service, not a view

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `ModelConfiguration` init with `cloudKitDatabase:` and `url:` parameters
- Apple Developer Documentation — SwiftData `VersionedSchema` and `SchemaMigrationPlan`
- WWDC23: Migrate to SwiftData (session 10189)
- `Block-Time/FlightDataModel.xcdatamodeld/FlightDataModel.xcdatamodel/contents` — v1 schema (read directly)
- `Block-Time/Block-Time.entitlements` — App Group and CloudKit container identifiers (read directly)
- `Block-Time/Models/WidgetFlightEntry.swift` — `appGroupID` constant (read directly)
- `Block-Time/Services/TimeCalculationManager.swift` — `timeStringToHours(_:)` (read directly)
- `Block-Time/Models/TimeInterval+Extensions.swift` — `toDecimalHours` conversion pattern (read directly)
- `.planning/research/STACK.md` — synthesised SwiftData + CloudKit research
- `.planning/research/SUMMARY.md` — architecture layer decisions

### Secondary (MEDIUM confidence)
- fatbobman: Concurrent programming in SwiftData — `@ModelActor` init-on-main-thread behaviour
- Hacking with Swift: VersionedSchema complex migration — boilerplate patterns
- BrightDigit: Using ModelActor in SwiftData — background execution patterns

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple-native; verified against project entitlements and STACK.md
- Architecture: HIGH — patterns verified against v1 codebase; user decisions locked
- Time field inventory: HIGH — read directly from `.xcdatamodeld` contents file
- Migration service design: HIGH — design locked by D-06 through D-09
- Pitfalls: HIGH — all verified from STACK.md, Apple docs, or v1 codebase inspection
- Package structure: HIGH — user decisions D-01 through D-05 lock the layout

**Research date:** 2026-05-15
**Valid until:** 2026-08-15 (stable Apple APIs; no fast-moving dependencies)
