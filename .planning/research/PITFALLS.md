# Pitfalls Research

**Project:** Block-Time v2.0 — Core Data → SwiftData migration
**Researched:** 2026-05-07
**Overall confidence:** HIGH (multiple independent sources, Apple Developer Forums threads confirm each pitfall)

---

## SwiftData + CloudKit Known Issues

### 1. Custom migrations are incompatible with CloudKit sync (CRITICAL)

SwiftData's `SchemaMigrationPlan` with custom `MigrationStage.custom` stages does not work when CloudKit sync is enabled. The container throws "Cannot use staged migration with an unknown model version." CloudKit initializes before the migration runs, causing a catch-22. This is a persistent, unresolved Apple bug across iOS 17 and iOS 18. Only lightweight (inferred) migrations work with CloudKit enabled.

**Consequence for this project:** The String→TimeInterval type change cannot be done as a SwiftData custom migration with CloudKit active. Options:
- Run migration outside SwiftData: read old Core Data store, transform, write new SwiftData store, then enable CloudKit.
- Perform the one-time transformation at the application layer on first launch (read legacy strings, convert, save new typed values) rather than via SchemaMigrationPlan.

**Workaround used in production:** Disable CloudKit (`.cloudKitDatabase(.none)`) for the first container open after migration, allow the schema migration to complete, then on next launch re-enable CloudKit. Requires detecting "first launch after migration" reliably.

Sources: [Apple Forums thread/742899](https://developer.apple.com/forums/thread/742899), [Apple Forums thread/744491](https://developer.apple.com/forums/thread/744491), [Apple Forums thread/775060](https://developer.apple.com/forums/thread/775060)

---

### 2. CloudKit schema must be manually deployed to production (HIGH)

Development and production CloudKit environments are completely separate. Local debug/TestFlight builds use Development. App Store builds use Production. If you add a new `@Model` attribute and don't deploy the schema to Production via the CloudKit dashboard, Production users will silently stop syncing — no crash, no error shown to the user.

**Required step:** After any schema change, log into CloudKit Console → select the container → "Deploy Schema Changes…" before submitting to App Store review.

**Secondary issue:** `initializeCloudKitSchema()` must be called at least once (in a debug build) whenever a new model or attribute is added. It is a Core Data API (not SwiftData), so you must drop down to the `NSPersistentStoreCoordinator` layer to call it.

Sources: [fatbobman.com — Fix CloudKit sync in production](https://fatbobman.medium.com/fix-core-data-swiftdata-cloud-sync-issues-in-production-b35ae50f8501), [leojkwan.com — Deploy CloudKit schema](https://www.leojkwan.com/swiftdata-cloudkit-deploy-schema-changes/)

---

### 3. All @Model properties must be optional or have default values for CloudKit (HIGH)

CloudKit requires every attribute to be optional or carry a default. A non-optional `TimeInterval` without a default (e.g. `var blockTime: TimeInterval`) will compile fine but cause a runtime error when CloudKit tries to initialize the schema. The error message is "CloudKit integration requires that all attributes be optional, or have a default value set." SwiftData logs this but does not crash loudly on first launch in all cases — it can silently fail sync.

**Fix:** Always give time values a default: `var blockTime: TimeInterval = 0`.

Sources: [Apple Forums thread/730950](https://developer.apple.com/forums/thread/730950), WebSearch corroboration from multiple forum threads

---

### 4. @Query does not refresh views after background ModelActor updates (HIGH — iOS 18 regression)

Background updates performed via `@ModelActor` contexts are not reflected in `@Query`-driven views in iOS 18. Deletes and inserts trigger refresh; property-value updates do not. This is a confirmed Apple regression from iOS 17 behavior.

**Workarounds:**
- Observe `ModelContext.didSave` notification, extract `PersistentIdentifier`s, refetch on the main context.
- For import-heavy operations (ACARS parse, CSV import), post a notification after the background context saves and re-drive the UI from the main context.
- For simpler cases, perform writes on `@MainActor` to avoid the issue entirely — acceptable for user-initiated saves.

Sources: [Apple Forums thread/758882](https://developer.apple.com/forums/thread/758882), [Apple Forums thread/734177](https://developer.apple.com/forums/thread/734177), [Apple Forums thread/770416](https://developer.apple.com/forums/thread/770416)

---

### 5. macOS: CloudKit.framework not automatically linked (MEDIUM)

On macOS targets, CloudKit sync silently fails if `CloudKit.framework` is not explicitly linked in Build Phases. This manifests as the app working perfectly in debug but sync being dead in App Store/TestFlight builds. The Mac companion target must explicitly link `CloudKit.framework`.

Sources: [fatbobman.com — Fix macOS sync](https://fatbobman.com/en/snippet/fix-synchronization-issues-for-macos-apps-using-core-dataswiftdata/)

---

### 6. iOS 26 sync regression (LOW — monitor)

Reports surfaced in early 2026 of SwiftData CloudKit sync producing `BAD_REQUEST` errors on iOS 26 after an OS update. Likely a beta artifact; worth tracking before v2.0 ships but not an immediate blocker (app targets iOS 18.6+).

Sources: [Apple Forums thread/811675](https://developer.apple.com/forums/thread/811675)

---

## Core Data → SwiftData Migration Risks

### 1. Unversioned schema shipped first = crash on first versioned update (CRITICAL)

If v2.0 ships with an unversioned SwiftData schema (no `VersionedSchema` wrapper) and v2.1 then introduces a versioned schema with a migration plan, users who installed v2.0 will crash on launch. SwiftData cannot infer what version v2.0's schema corresponds to.

**Required pattern:** v2.0 must ship with `SchemaV1` defined from day one, even if no migration is needed yet. Wrap the initial model in a `VersionedSchema` before any user ever installs the app.

Sources: [Apple Forums thread/761735](https://developer.apple.com/forums/thread/761735), [atomicrobot.com — Unauthorized guide to SwiftData migrations](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)

---

### 2. The Core Data → SwiftData migration is not automatic via SwiftData APIs (CRITICAL)

SwiftData has no built-in bridge to read an existing `NSPersistentCloudKitContainer` store and migrate it. You must either:

**Option A (recommended):** Keep `FlightDatabaseService` alive in v2.0 behind a migration gate. On first launch, read all `FlightEntity` objects via Core Data, transform, insert into SwiftData, mark migration done in UserDefaults, then shut down Core Data permanently.

**Option B:** Use the `NSPersistentStoreCoordinator` / `migratePersistentStore` API to copy the SQLite store to a new location, then open it with SwiftData.

Option B is fragile when CloudKit is involved (see pitfall §1.1). Option A gives you explicit control over data transformation including String→TimeInterval conversion.

**The .sqlite file location matters:** SwiftData defaults to `Application Support/<bundle-id>.store`. Core Data typically uses `Application Support/<ModelName>.sqlite`. If SwiftData picks a different path it creates a new empty store and leaves the Core Data store untouched — silent data loss from the user's perspective.

Sources: [Apple Forums thread/756615](https://developer.apple.com/forums/thread/756615), multiple forum threads confirming no automatic migration exists

---

### 3. Relationship inverse requirements are stricter in SwiftData (HIGH)

SwiftData enforces inverse relationships at compile time / schema-init time in ways Core Data's NSManagedObject does not. Any relationship without a configured inverse will prevent the container from opening. Audit all relationships before migration.

Sources: WebSearch corroboration from multiple medium.com posts

---

### 4. Default values in Swift initializer do not backfill existing rows (HIGH)

If a new `@Model` property is added with a Swift default value (e.g., `var isPositioning: Bool = false`), SwiftData lightweight migration does not guarantee existing SQLite rows get that value written. The property may read correctly from the initializer for new objects but existing rows may read as `nil` or cause decoding errors depending on the attribute type. Test migration from a real on-disk store, not just in-memory.

Sources: [atomicrobot.com — SwiftData migrations guide](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)

---

## String → TimeInterval Conversion Edge Cases

This is specific to Block-Time's current schema: all time fields are `String?` in Core Data (`blockTime`, `simTime`, `nightTime`, `p1Time`, `p1usTime`, `p2Time`, `instrumentTime`, `spInsTime`).

### 1. nil and empty string are different failure modes

- `nil` → field was never set. Should produce `0` (zero duration), not a conversion error.
- `""` (empty string) → field was explicitly cleared. Should also produce `0`. Do not propagate as `nil` to the `TimeInterval` field; CloudKit will reject a non-optional `TimeInterval` with no value.
- `"  "` (whitespace) → trim before parsing. Seen in paste-from-clipboard imports.

### 2. Two distinct formats exist in the stored data

- `"HH:MM"` — e.g., `"01:30"` = 1.5 hours = 5400 seconds. This is the primary format.
- Decimal hours as a string — e.g., `"1.5"`. Present in some older imported entries from CSV files or ACARS parsing. The converter must detect which format by presence of `:`.
- Mixed case: `"1:5"` (single-digit minutes without zero-padding). Present in some hand-typed entries. Treat `"1:5"` as 1 hour 5 minutes, not 1 hour 50 minutes.

**Recommended converter:**
```swift
func parseTimeString(_ raw: String?) -> TimeInterval {
    guard let s = raw?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return 0 }
    if s.contains(":") {
        let parts = s.split(separator: ":", maxSplits: 1)
        guard parts.count == 2,
              let h = Double(parts[0]),
              let m = Double(parts[1]) else { return 0 }
        return (h * 3600) + (m * 60)
    }
    // Decimal hours fallback
    return (Double(s) ?? 0) * 3600
}
```

### 3. Values over 24 hours are valid

A pilot can have a sim session or accumulated P1 time > 24 hours in a single entry (unlikely but valid). Do not cap at 86400 seconds or assume the hours component is 0–23.

### 4. Negative values and obviously corrupt strings

Legacy imports from certain roster systems produced `"-"`, `"N/A"`, `"--:--"`. These must produce `0`, not a crash or NaN. The converter must have a safe fallback for any unrecognized format.

### 5. Silent loss if conversion produces 0 for a non-zero value

The migration must log every field where the source string was non-empty but the parsed result is 0. These are conversion failures that need post-migration review, not silent corruption. Write a migration report to a log file or UserDefaults diagnostic key.

### 6. Takeoff/landing counts are Int16, not String

`dayTakeoffs`, `nightTakeoffs`, `dayLandings`, `nightLandings` are already `Int16` scalars in Core Data. These do not need conversion — just copy as `Int`.

---

## Swift 6 Concurrency + SwiftData Gotchas

### 1. @Model objects are not Sendable (CRITICAL)

`ModelContext` and `@Model` instances are explicitly not `Sendable`. You cannot pass a fetched `FlightEntity` across actor boundaries. The correct pattern:

1. Fetch in the source actor's context.
2. Extract the `PersistentIdentifier` (which is `Sendable`).
3. Send the identifier across the actor boundary.
4. Re-fetch in the destination actor using `modelContext.model(for: identifier)`.

Violating this produces `Sendable` conformance errors under Swift 6 strict concurrency. These are not false positives.

Sources: [hackingwithswift.com — SwiftData concurrency](https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency), [brightdigit.com — ModelActor tutorial](https://brightdigit.com/tutorials/swiftdata-modelactor/)

---

### 2. ModelActor's context thread is determined at creation time (HIGH)

`@ModelActor` creates a context tied to the actor's execution context at the time `ModelActor` is initialized. If you initialize a `@ModelActor` on the main thread (e.g., inside `@MainActor` code), its context runs on the main thread and provides no background-processing benefit. Initialize `@ModelActor` instances from a detached task or non-main-actor context.

Sources: [massicotte.org — ModelActor is Just Weird](https://www.massicotte.org/model-actor/), [mjtsai.com](https://mjtsai.com/blog/2025/08/26/swiftdatas-modelactor-is-just-weird/)

---

### 3. One-to-many relationships from the "one" side are broken in iOS 18 (HIGH)

Setting `flight.aircraft = aircraft` does not automatically populate `aircraft.flights` in iOS 18. You must set the relationship from the "many" side or manually append to the collection. Setting from the "one" side silently leaves the relationship nil and the object fails to save correctly.

Sources: [Apple Developer Forums — iOS 18 relationship issue](https://developer.apple.com/forums/thread/761554)

---

### 4. Animations break when data updates come from non-MainActor contexts (MEDIUM)

SwiftUI animations triggered by `@Observable` or `@Query` updates from a background actor run outside the main render loop. The updates arrive but without animation. Use `await MainActor.run { withAnimation { ... } }` when the UI must animate in response to a background data change.

Sources: [medium.com — ModelActor pitfalls](https://killlilwinters.medium.com/taking-swiftdata-further-modelactor-swift-concurrency-and-avoiding-mainactor-pitfalls-3692f61f2fa1)

---

### 5. A single @ModelActor serializes all operations (MEDIUM)

`@ModelActor` is a serial actor. Long-running imports (CSV with thousands of flights, ACARS batch) block the actor and prevent any other query or save from running against that context. Design the import pipeline with chunked batch inserts and periodic `try modelContext.save()` calls so the actor yields between chunks.

---

## App Store Update + iCloud Continuity

### 1. iCloud data is not touched by a schema migration — but the local SQLite is (HIGH)

When a user installs v2.0, the Core Data → SwiftData migration runs on the local device. The existing iCloud CloudKit records remain unchanged in the cloud (they use the old Core Data schema). v2.0 must be capable of reconciling the CloudKit sync-down of these old records against the new SwiftData schema. If the CloudKit schema is not updated to match (see §1.2), the sync-down will either silently drop records or fail with type-mismatch errors.

**Required:** Before releasing v2.0, test a device that has existing data only in iCloud (local store deleted) — confirm it syncs down and is correctly read by the new schema.

---

### 2. CloudKit record types persist even after schema changes (HIGH)

CloudKit record types are permanent in production once any device has written them. If v1's Core Data used `CD_FlightEntity` as the CloudKit record type and v2.0's SwiftData uses a different record name, two separate record types exist in the cloud and iCloud data from v1 will never sync to v2.0 models. SwiftData and Core Data use the same `CD_<EntityName>` naming convention, so this is probably safe — but it must be verified by inspecting the CloudKit console before v2.0 submission.

---

### 3. Shipping unversioned then versioned = launch crash for existing users (CRITICAL)

Documented above in Core Data migration section. Repeat emphasis: version the schema from day one in v2.0.

---

### 4. The migration must be idempotent (HIGH)

If the app crashes during migration, the next launch will attempt migration again. The migration code must check "has migration already completed?" before running. Use a UserDefaults boolean flag set only after a successful `modelContext.save()`. If the migration runs again on already-migrated data, duplicate records must not be created.

---

## Widget + App Group Pitfalls

### 1. Adding an App Group changes where SwiftData creates its store (CRITICAL)

When an App Group entitlement is present and no explicit `url:` is passed to `ModelConfiguration`, SwiftData silently relocates the store to the App Group container directory. If the v2.0 main app previously stored data at `Application Support/<name>.store` (no App Group), adding the App Group for the widget causes SwiftData to open a new empty store at the App Group path — the user's data appears gone.

**Fix:** Explicitly specify `url:` in `ModelConfiguration` to pin the store location, or copy the existing store to the App Group path as part of the migration.

Sources: [Apple Forums thread/789173](https://developer.apple.com/forums/thread/789173)

---

### 2. Widget extension must include all @Model types in its target membership (HIGH)

Swift files defining `@Model` classes must be compiled into both the main app target and the widget extension target. Forgetting a model file in the widget's target membership causes `Could not materialize Objective-C class named...` errors at widget runtime. Confirm all `@Model` files are in both targets.

Sources: [hackingwithswift.com — Widgets + SwiftData](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-access-a-swiftdata-container-from-widgets)

---

### 3. Widget writes to the store must go through the App Group path (HIGH)

If the widget needs to write anything (timeline reload triggers, last-seen state), it must use the same `ModelConfiguration` URL as the main app. Reading from a different path than writing produces a forked database state — the widget's writes are invisible to the main app and vice versa.

---

### 4. ModelContainer setup must be a shared factory function (MEDIUM)

Both the main app and the widget extension must construct an identical `ModelContainer` (same schema, same URL, same configuration). Duplication invites divergence. Define a `shared` factory in a Swift Package or a file included in both targets:

```swift
extension ModelContainer {
    static func appContainer() throws -> ModelContainer {
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.yourapp")!
            .appendingPathComponent("flights.store")
        let config = ModelConfiguration(schema: Schema([Flight.self, ...]), url: url)
        return try ModelContainer(for: Schema([Flight.self, ...]), configurations: [config])
    }
}
```

---

## Testing @Model Types

### 1. @MainActor required for in-memory container setup (HIGH)

`ModelContainer.mainContext` is `@MainActor`-isolated. Test setup functions that access `mainContext` must be marked `@MainActor` (or be `async` and `await` the context on the main actor). Tests that don't do this will produce Swift 6 compiler errors.

```swift
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Flight.self, configurations: [config])
}
```

Sources: [hackingwithswift.com — SwiftData unit tests](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code)

---

### 2. @Query is untestable in unit tests (HIGH)

`@Query` is a SwiftUI property wrapper that only works inside a `View`. It cannot be instantiated in a unit test. Repository tests must use `FetchDescriptor` directly against the `ModelContext`. This is a design forcing function: if your ViewModels use `@Query` directly, they become untestable. ViewModels should take a `FlightRepository` protocol and the repository's tests use `FetchDescriptor`.

---

### 3. Relationship setup order matters in tests (MEDIUM)

Insert the parent `@Model` object into the context before setting child relationships. Setting a relationship before the parent is inserted causes a crash in the context's getter. Test setup must follow: `context.insert(parent)` → `parent.children.append(child)` → `try context.save()`.

Sources: [Apple Forums thread/736804](https://developer.apple.com/forums/thread/736804)

---

### 4. SwiftData in Swift Package (no bundle) has extra setup requirements (MEDIUM)

When SwiftData `@Model` types live in a Swift Package (not a bundle target), the schema must be constructed explicitly from types rather than relying on automatic bundle discovery. `Schema([Flight.self, Aircraft.self, ...])` must be passed explicitly to `ModelContainer`. Omitting it causes a "no model found" error at runtime in SPM-hosted models.

Sources: [Swift Forums — Testing SwiftData in SwiftPM](https://forums.swift.org/t/testing-swiftdata-in-swiftpm/68293)

---

### 5. Migration testing requires a real on-disk store (HIGH)

In-memory containers skip the migration codepath entirely. To test that the migration from v1 (Core Data, String times) to v2.0 (SwiftData, TimeInterval) actually works, you must:

1. Create a real `.sqlite` file representing a production v1 Core Data store.
2. Run the migration code against it.
3. Open the result with SwiftData and verify field values.

Fixture: export a copy of a real device's `.sqlite` store (obfuscated if needed) and commit it as a test resource. In-memory tests will not catch this class of regression.

Sources: [medium.com — Testing SwiftData migrations](https://medium.com/@abegehr/testing-swiftdata-migrations-7a612da2c91c)

---

## Phase Mapping

| Pitfall | Phase to Address | Priority |
|---------|-----------------|----------|
| Unversioned schema → future crash | Phase 1 — Data layer setup | CRITICAL: ship VersionedSchema on day 1 |
| Custom migration + CloudKit incompatible | Phase 1 — Migration design | CRITICAL: use application-layer migration, not SchemaMigrationPlan |
| Core Data → SwiftData no automatic bridge | Phase 1 — Migration | CRITICAL: keep FlightDatabaseService alive behind migration gate |
| App Group store location change | Phase 1 — Container configuration | CRITICAL: pin ModelConfiguration URL before any TestFlight |
| String → TimeInterval edge cases | Phase 1 — Migration | HIGH: build and test converter with real fixtures |
| All @Model properties need defaults for CloudKit | Phase 1 — Model definition | HIGH: enforce in initial schema |
| CloudKit schema deployment to production | Phase 1 / Pre-release | HIGH: document as release checklist step |
| Migration idempotency | Phase 1 — Migration | HIGH: UserDefaults gate |
| One-to-many relationship from "one" side broken | Phase 1 — Model layer | HIGH: always set from the "many" side |
| @Query + @MainActor untestable | Phase 2 — Repository layer | HIGH: FlightRepository protocol forces testability |
| @Model not Sendable | Phase 2 — Repository + background ops | HIGH: PersistentIdentifier pattern |
| @Query not refreshing after background updates | Phase 3 — Import pipeline | HIGH: ModelContext.didSave observer |
| ModelActor created on main thread | Phase 3 — Import pipeline | MEDIUM: detached task pattern |
| Widget target membership | Phase 4 — Widget rebuild | HIGH: verify all @Model files in widget target |
| @MainActor required in test setup | Phase 2 — Testing | HIGH: all test containers must be @MainActor |
| Migration test requires real on-disk fixture | Phase 1 — Migration testing | HIGH: commit .sqlite fixture |
| SwiftData in SPM explicit schema | Phase 1 — Package setup | MEDIUM: pass Schema([...]) explicitly |
| macOS CloudKit.framework not linked | Phase 5 — Mac target | MEDIUM: check Build Phases before Mac release |
| iOS 26 sync regression | Pre-release | LOW: monitor; not blocking for iOS 18.6+ target |
