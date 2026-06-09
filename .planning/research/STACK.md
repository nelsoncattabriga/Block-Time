# Stack Research

**Project:** Block-Time v2.0 — SwiftData architectural rewrite
**Researched:** 2026-05-07
**Minimum deployment targets:** iOS 18.6+, macOS 15+

---

## SwiftData + CloudKit Setup

### Version Requirements

SwiftData requires iOS 17+ / macOS 14+. The project already targets iOS 18.6+ and macOS 15+, so there are no floor constraints to worry about. CloudKit sync is part of SwiftData's built-in ModelConfiguration, not a separate framework.

### ModelContainer Configuration

```swift
// Basic CloudKit-enabled container
let schema = Schema([Flight.self, Aircraft.self /* … */])

let config = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .automatic   // uses the container from iCloud entitlement
)

let container = try ModelContainer(for: schema, configurations: [config])
```

`.automatic` reads the CloudKit container identifier from the app's entitlement (the same `iCloud.com.yourcompany.blocktime` container used by the v1 NSPersistentCloudKitContainer). You can also pass `.private("iCloud.com.yourcompany.blocktime")` explicitly.

### Required Xcode Capabilities

- **iCloud** capability with CloudKit checked and your container registered.
- **Background Modes** capability with **Remote notifications** checked (so the app wakes on CloudKit push and syncs).
- These are identical to what v1 already has — no new entitlements needed.

### App entry point

```swift
@main
struct BlockTimeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Flight.self, Aircraft.self /* … */],
                        inMemory: false,
                        isAutosaveEnabled: true,
                        isUndoEnabled: false,
                        onSetup: { result in /* handle error */ })
    }
}
```

The `.modelContainer(for:)` scene modifier is the recommended entry point. It propagates the container via the SwiftUI environment automatically.

### CloudKit Data Model Constraints (NON-NEGOTIABLE)

These are hard requirements — violating any silently disables sync without an obvious error:

1. **All stored properties must be Optional or have a default value.** No exceptions. This means `var blockTime: TimeInterval = 0` is fine; `var blockTime: TimeInterval` is not.
2. **All relationships must be Optional.** `var aircraft: Aircraft?` not `var aircraft: Aircraft`.
3. **`@Attribute(.unique)` cannot be used on any synced property.** CloudKit does not support unique constraints.
4. **No non-optional `@Relationship` with `.cascade` delete if the inverse is missing.** Always declare the inverse.
5. **Enum raw values** must be `String` or `Int` types (Codable enums are fine if stored as `Data`).

The workaround for non-optional logic: use an optional stored property and expose a computed non-optional accessor:

```swift
@Model final class Flight {
    var _blockTime: TimeInterval? = 0   // stored, syncs to CloudKit
    var blockTime: TimeInterval {       // non-optional for business logic
        get { _blockTime ?? 0 }
        set { _blockTime = newValue }
    }
}
```

This is verbose but correct. Whether to use this pattern or just accept optionals throughout is a design call — for a logbook app where 0 is a valid default, plain `var blockTime: TimeInterval = 0` is simpler and avoids the wrapper.

### CloudKit Schema Initialisation

SwiftData does not expose `initializeCloudKitSchema()` directly the way NSPersistentCloudKitContainer does. If you hit incomplete sync on first install, you may need to drop to the Core Data layer to call it. This is a known gap — the fatbobman article documents the workaround:

```swift
// Workaround if CloudKit schema is incomplete after first install
if let coordinator = container.mainContext.coordinator {
    try coordinator.initializeCloudKitSchema(options: [])
}
```

Confidence on needing this: LOW — most apps don't need it; it's triggered by certain schema layouts.

---

## Swift Package for Shared Business Logic

### Recommended Structure

Create a local Swift Package inside the Xcode project directory. Add it via **File → Add Package Dependencies → Add Local**. Both the iOS app target and the Mac target depend on it.

```
Block-Time/
├── Block-Time.xcodeproj
├── BlockTimeCore/            ← local Swift Package
│   ├── Package.swift
│   └── Sources/
│       └── BlockTimeCore/
│           ├── Models/       ← Flight, Aircraft, etc. (pure domain structs)
│           ├── Repositories/ ← FlightRepository protocol + implementations
│           ├── FRMS/         ← FRMSCalculator pure functions
│           ├── Parsers/      ← CSV, ACARS, Roster parsers
│           └── Calculations/ ← Night time, UTC conversion, time credit
├── Block-Time/               ← iOS app target (SwiftUI, SwiftData models)
└── Block-Time-Mac/           ← Mac app target (SwiftUI, same SwiftData models)
```

### Package.swift minimum

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BlockTimeCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "BlockTimeCore", targets: ["BlockTimeCore"])
    ],
    targets: [
        .target(
            name: "BlockTimeCore",
            path: "Sources/BlockTimeCore"
        ),
        .testTarget(
            name: "BlockTimeCoreTests",
            dependencies: ["BlockTimeCore"],
            path: "Tests/BlockTimeCoreTests"
        )
    ]
)
```

### What Goes in the Package vs the App Target

| BlockTimeCore (package) | App Target |
|-------------------------|-----------|
| Domain structs (`Flight`, `Aircraft`) | `@Model` classes (SwiftData) |
| `FlightRepository` protocol | `SwiftDataFlightRepository` implementation |
| FRMS calculator (pure functions) | SwiftUI views |
| Parsers (CSV, ACARS, roster) | `@Environment` wiring |
| Time/night/UTC calculations | Widget extension |
| In-memory repository (for tests) | App Intents |

**Key principle:** the package has zero dependency on SwiftData, SwiftUI, or UIKit. The app target translates between `@Model` persistence objects and the pure domain structs. This is what makes the FRMS calculator and parsers unit-testable.

### Gotcha: @Model cannot live in a Swift Package

SwiftData's `@Model` macro requires the Swift compiler plugin that ships with Xcode. As of iOS 18 / Xcode 16, placing `@Model` classes inside a Swift Package does not work reliably — the macro expander fails or produces incomplete output in some configurations. Keep all `@Model` classes in the app target. The package works with plain Swift structs and protocols.

Confidence: MEDIUM (consistent reports in developer forums; worth verifying at project start with a small spike).

---

## SwiftData Testing (In-Memory)

### Pattern

```swift
import XCTest
import SwiftData

@MainActor
final class FlightRepositoryTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([FlightModel.self, AircraftModel.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none    // CRITICAL: must be .none for in-memory
        )
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    func testInsertFlight() throws {
        let flight = FlightModel(date: .now, blockTime: 3600)
        context.insert(flight)
        try context.save()

        let descriptor = FetchDescriptor<FlightModel>()
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].blockTime, 3600)
    }
}
```

`cloudKitDatabase: .none` is mandatory — combining an in-memory store with `.automatic` or `.private` will throw at container creation time.

### Testing the Repository Protocol

Because `FlightRepository` is a protocol and `InMemoryFlightRepository` is a pure-Swift implementation in the package (no SwiftData), FRMS tests and parser tests do not need SwiftData at all. This is the higher-value test target.

```swift
// In BlockTimeCore package — no SwiftData import needed
final class InMemoryFlightRepository: FlightRepository {
    private var flights: [Flight] = []
    func insert(_ flight: Flight) { flights.append(flight) }
    func fetchAll() -> [Flight] { flights }
}
```

### Migration Testing

Test `VersionedSchema` migrations with an in-memory store that you seed with V1 data:

```swift
let v1Container = try ModelContainer(
    for: SchemaV1.Flight.self,
    migrationPlan: FlightMigrationPlan.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
)
// Seed V1 data, then open with V2 schema and assert conversion
```

---

## @Observable + @Model Constraints

### What @Model Gives You

`@Model` implicitly conforms to `Observable` — you get SwiftUI view invalidation for free. Do not add `@Observable` to a `@Model` class; the macro already includes it. Attempting to add both produces a compiler error.

### Sendability Rules (Swift 6 Strict Concurrency)

| Type | Sendable | Crosses actor boundary? |
|------|----------|------------------------|
| `ModelContainer` | YES | Can be passed freely |
| `PersistentIdentifier` | YES | Can be passed freely |
| `ModelContext` | NO | Create one per actor |
| `@Model` instances | NO | Pass `PersistentIdentifier`, refetch on other actor |

This means: never pass a `Flight` (the `@Model` class) across an actor boundary. Pass its `persistentModelID` and fetch it fresh on the receiving actor.

### ModelActor for Background Work

```swift
@ModelActor
actor FlightImportActor {
    func importFlights(_ rawData: [ParsedFlight]) throws {
        for raw in rawData {
            let flight = FlightModel(from: raw)
            modelContext.insert(flight)
        }
        try modelContext.save()
    }
}

// Usage from MainActor
let actor = FlightImportActor(modelContainer: container)
try await actor.importFlights(parsed)
```

`@ModelActor` creates an actor with a dedicated `ModelContext`. Its executor is tied to the context's queue. If you initialise the actor on the main thread the first call may still run on main — always `await` it from a detached task when you want genuine background execution.

### Relationship Gotcha

You cannot access a `@Relationship` property on a `@Model` object before it has been inserted into a `ModelContext`. Doing so crashes at runtime. Pattern: insert first, set relationships after.

```swift
// WRONG
let flight = FlightModel()
flight.aircraft = aircraft   // crash if flight not yet in context

// RIGHT
context.insert(flight)
flight.aircraft = aircraft
```

### @Query in Views

`@Query` only works inside a SwiftUI view (it relies on the view's environment `ModelContext`). It cannot be used in an `@Observable` view model class. If you need to fetch from a view model, inject the `ModelContext` via the environment and call `context.fetch(descriptor)` manually.

### No Predicate on Optional Relationships (CloudKit-forced optionals)

When CloudKit forces all relationships to be optional, writing `#Predicate` filters against them requires `?.` chains that the `#Predicate` macro does not always handle. This is an active limitation as of iOS 18. Workaround: filter in Swift after fetching, or fetch by `PersistentIdentifier`.

---

## Core Data → SwiftData Migration

### The Options

There are three approaches. Only one is viable for this project.

#### Option A: Native Coexistence (Core Data + SwiftData same store) — NOT RECOMMENDED

Both stacks open the same SQLite file simultaneously. This is possible but requires:
- Identical entity names between Core Data and SwiftData classes (or careful namespacing).
- Persistent history tracking enabled on the Core Data stack.
- Schema must stay perfectly synchronised between both stacks.
- No CloudKit schema divergence.

This is appropriate for incremental migration (phase it over releases). For a full rewrite where you are also changing property types (String → TimeInterval), it is unworkable — the schemas cannot match, because the field types differ.

**Verdict: ruled out** for this project because the type system is changing too fundamentally.

#### Option B: One-Time Migration at First Launch — RECOMMENDED

Run a migration job on first launch that:
1. Opens the v1 Core Data store with `NSPersistentCloudKitContainer` (read-only).
2. Reads all `FlightEntity` records.
3. Converts each one (parse time strings → `TimeInterval`, parse dates → UTC `Date`).
4. Inserts converted `FlightModel` objects into the SwiftData `ModelContext`.
5. Saves the SwiftData store.
6. Sets a `UserDefaults` flag so migration never runs again.
7. (Optionally) deletes or archives the old Core Data store after verifying row counts match.

This is the cleanest approach and the only one that works when property types change.

```swift
// Pseudocode — runs once, inside a detached Task on first launch
func migrateIfNeeded(into container: ModelContainer) async throws {
    guard !UserDefaults.standard.bool(forKey: "v2MigrationComplete") else { return }

    let oldStore = try LegacyFlightDatabaseService()   // read-only NSPersistentCloudKitContainer
    let flights = oldStore.allFlights()                 // returns [FlightEntity]

    let actor = FlightImportActor(modelContainer: container)
    try await actor.importLegacy(flights)               // converts + inserts

    UserDefaults.standard.set(true, forKey: "v2MigrationComplete")
}
```

CloudKit data: once the SwiftData store is populated and synced to CloudKit, the new container will sync going forward. The old CloudKit records (from the Core Data container) remain in the private iCloud database but are ignored by SwiftData. There is no automatic bridging between them — the migration is write-new-records, not rename-existing-records. Users on multiple devices will need to re-download from CloudKit after first migration on one device, which is normal CloudKit behaviour.

#### Option C: SwiftData VersionedSchema / SchemaMigrationPlan — NOT APPLICABLE

This is for migrating between versions of a SwiftData schema (V1 → V2 → V3 within SwiftData). It does not bridge from Core Data. Use it after v2.0 ships for future schema changes.

### Data Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Migration runs twice | `UserDefaults` boolean flag, set only after verified row count |
| App killed mid-migration | Migration is idempotent if SwiftData store is cleared on restart; or use a transaction per batch |
| CloudKit sync during migration | Disable CloudKit during migration (`cloudKitDatabase: .none` temporarily), re-enable after |
| Data loss on old device running v1 | Migration is one-way; v2.0 ships as a hard cutover, not a dual-support release |

---

## Confidence Levels

| Area | Confidence | Rationale |
|------|-----------|-----------|
| SwiftData + CloudKit setup | HIGH | Apple documentation + multiple verified sources confirm ModelConfiguration API and CloudKit constraints |
| ModelConfiguration `.none` for in-memory | HIGH | Directly documented in Apple Developer Docs for the initialiser |
| All-optional CloudKit requirement | HIGH | Consistent across Apple docs, WWDC sessions, and community sources |
| `@Attribute(.unique)` CloudKit incompatibility | HIGH | Multiple sources; Apple docs confirm |
| `@Model` in Swift Package fails | MEDIUM | Consistent forum reports; verify with a spike at project start |
| ModelActor background execution behaviour | MEDIUM | Documented but has known quirk re: initialisation thread; test early |
| One-time Core Data→SwiftData migration approach | MEDIUM | Pattern is widely used; the CloudKit re-sync behaviour after migration is less documented and needs a real device test |
| `#Predicate` on optional relationships | MEDIUM | Known limitation as of iOS 18; may be fixed in later releases |
| SwiftData VersionedSchema for future changes | HIGH | WWDC23 + WWDC24 sessions and Hacking with Swift documentation |

---

## Sources

- [Apple: Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Apple: ModelConfiguration init (including cloudKitDatabase parameter)](https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(_:schema:isstoredinmemoryonly:allowssave:groupcontainer:cloudkitdatabase:))
- [Apple: ModelConfiguration.CloudKitDatabase](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct)
- [Apple: Organizing your code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
- [Hacking with Swift: Syncing SwiftData with CloudKit](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit)
- [Hacking with Swift: How to write unit tests for SwiftData](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code)
- [Hacking with Swift: How SwiftData works with Swift concurrency](https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency)
- [Hacking with Swift: Migrating from Core Data to SwiftData](https://www.hackingwithswift.com/quick-start/swiftdata/migrating-from-core-data-to-swiftdata)
- [Hacking with Swift: Core Data and SwiftData coexistence](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-make-core-data-and-swiftdata-coexist-in-the-same-app)
- [Hacking with Swift: VersionedSchema complex migration](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema)
- [fatbobman: Rules for adapting data models to CloudKit](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
- [fatbobman: initializeCloudKitSchema fix](https://fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-in-ios-development-using-initializecloudkitschema/)
- [fatbobman: Concurrent programming in SwiftData](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/)
- [fatbobman: Relationships in SwiftData](https://fatbobman.com/en/posts/relationships-in-swiftdata-changes-and-considerations/)
- [BrightDigit: Using ModelActor in SwiftData](https://brightdigit.com/tutorials/swiftdata-modelactor/)
- [Use Your Loaf: SwiftData background tasks](https://useyourloaf.com/blog/swiftdata-background-tasks/)
- [pol piella: Core Data and SwiftData side by side](https://www.polpiella.dev/core-data-and-swift-data/)
- [WWDC23: Migrate to SwiftData](https://developer.apple.com/videos/play/wwdc2023/10189/)
- [Apple Developer Forums: Migrate Core Data to SwiftData](https://developer.apple.com/forums/thread/756615)
- [Apple Developer Forums: SwiftData and CloudKit](https://developer.apple.com/forums/thread/761434)
- [Donny Wals: Deep dive into SwiftData migrations](https://www.donnywals.com/a-deep-dive-into-swiftdata-migrations/)
