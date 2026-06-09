# Architecture Research

**Project:** Block-Time v2.0 — SwiftData rewrite
**Researched:** 2026-05-07
**Overall confidence:** HIGH (SwiftData constraints are well-documented; patterns verified across multiple sources)

---

## Recommended Layer Structure

```
┌────────────────────────────────────────────────────────┐
│  View Layer  (iOS target / Mac target)                 │
│  SwiftUI views, @State, @Environment, @Query           │
│  Formatters: UTC Date → local string at this layer     │
└───────────────────┬────────────────────────────────────┘
                    │  reads domain structs, calls repository
┌───────────────────▼────────────────────────────────────┐
│  ViewModel Layer  (BlockTimeKit package)               │
│  @Observable, @MainActor                               │
│  Holds [Flight] domain structs, exposes computed props │
│  Calls repository, maps @Model ↔ domain struct         │
└───────────────────┬────────────────────────────────────┘
                    │  FlightRepository protocol
┌───────────────────▼────────────────────────────────────┐
│  Repository Layer  (BlockTimeKit package)              │
│  protocol FlightRepository                             │
│  SwiftDataFlightRepository (real)                      │
│  InMemoryFlightRepository (tests/previews)             │
└───────────────────┬────────────────────────────────────┘
                    │  maps domain struct ↔ @Model
┌───────────────────▼────────────────────────────────────┐
│  Persistence Layer  (BlockTimeKit package)             │
│  @Model classes: FlightModel, AircraftModel, etc.      │
│  ModelContainer factory (real store / in-memory)       │
│  SwiftData + CloudKit (private database only)          │
└────────────────────────────────────────────────────────┘

Calculators (pure functions, no layer — BlockTimeKit package)
  FRMSCalculator.compute(duties:config:) → FRMSResult
  NightTimeCalculator.compute(…) → TimeInterval
  TimeConverter.utcToLocal(date:iata:) → DateComponents
```

**Data flow (read):** View asks ViewModel → ViewModel calls repository.fetch() → repository queries SwiftData, maps FlightModel → Flight struct → ViewModel publishes [Flight] → View renders.

**Data flow (write):** View calls ViewModel method → ViewModel validates, calls repository.save(flight:) → repository maps Flight → FlightModel, inserts into ModelContext → SwiftData persists.

---

## @Model vs Domain Struct

**Recommendation: separate @Model persistence class from Flight domain struct. Map at the repository boundary.**

### Why you cannot use @Model as the domain type

`@Model` requires a `class` — it cannot be applied to a `struct`. The macro generates `PersistentModel` conformance plus `Observable` conformance via synthesised property observation. The class is inherently reference-typed and bound to a `ModelContext`. Passing `@Model` objects across concurrency boundaries (e.g. into a pure calculator or a unit test) requires the ModelContext to be alive and on the correct actor, which makes testing and isolation painful.

Specifically for this project:
- `FRMSCalculator` must be a pure function taking value types — passing `@Model` objects into it couples the calculator to SwiftData.
- Unit tests for calculators would need a live ModelContainer even to instantiate input values.
- `FlightModel` exposes SwiftData internals (persistent identifiers, relationships as `@Relationship` wrappers) that are irrelevant to display and calculation logic.

### The mapping pattern

```swift
// Persistence layer — in BlockTimeKit, persistence sublayer
@Model
final class FlightModel {
    var id: UUID
    var departureDateUTC: Date        // always UTC Date
    var blockTimeSeconds: Int         // never String
    var fromIATA: String
    var toIATA: String
    // ... all fields as proper types
}

// Domain layer — in BlockTimeKit, domain sublayer
struct Flight: Identifiable, Hashable, Sendable {
    let id: UUID
    let departureDateUTC: Date
    let blockTimeSeconds: Int
    let from: Airport
    let to: Airport
    // ... computed helpers (blockTime as TimeInterval, etc.)
}

// Repository layer maps between them
extension Flight {
    init(_ model: FlightModel) {
        self.id = model.id
        self.departureDateUTC = model.departureDateUTC
        self.blockTimeSeconds = model.blockTimeSeconds
        // ...
    }
}

extension FlightModel {
    convenience init(_ flight: Flight) { ... }
    func update(from flight: Flight) { ... }
}
```

### Trade-off acknowledged

This adds a mapping layer that `@Query` in views avoids. The trade-off is worth it here because:
1. FRMS calculator must take pure value types — this is non-negotiable for the test requirement.
2. The existing codebase already has 3,654 lines in one service; the repository boundary is how you prevent that recurring.
3. In-memory test implementation of `FlightRepository` is trivial with domain structs; mocking `ModelContext` is not (ModelContext and ModelContainer cannot be subclassed).

**Confidence: HIGH** — constraint that @Model must be a class is documented by Apple; inability to subclass ModelContext for mocking is confirmed in Apple Developer Forums.

---

## Swift Package Structure

**Package name:** `BlockTimeKit` (local package, embedded in Xcode project)

```
BlockTimeKit/
├── Package.swift
└── Sources/
    ├── BlockTimeDomain/          # zero external deps beyond Foundation
    │   ├── Models/
    │   │   ├── Flight.swift      # domain struct
    │   │   ├── Duty.swift
    │   │   ├── Airport.swift
    │   │   └── FRMSResult.swift
    │   └── Protocols/
    │       └── FlightRepository.swift  # protocol only
    │
    ├── BlockTimeData/            # depends on BlockTimeDomain + SwiftData
    │   ├── Models/
    │   │   └── FlightModel.swift      # @Model class
    │   ├── Repositories/
    │   │   ├── SwiftDataFlightRepository.swift
    │   │   └── InMemoryFlightRepository.swift
    │   └── Container/
    │       └── ModelContainerFactory.swift
    │
    ├── BlockTimeCalculators/     # depends on BlockTimeDomain only
    │   ├── FRMSCalculator.swift
    │   ├── NightTimeCalculator.swift
    │   ├── TimeConverter.swift
    │   └── FRMSConfig.swift
    │
    ├── BlockTimeParsers/         # depends on BlockTimeDomain only
    │   ├── CSVParser.swift
    │   ├── ACARSParser.swift
    │   └── RosterParser.swift
    │
    └── BlockTimeUI/              # depends on Domain + Calculators; NO SwiftData
        ├── ViewModels/
        │   ├── FlightListViewModel.swift
        │   └── FRMSViewModel.swift
        └── Formatters/
            └── TimeDisplayFormatter.swift
```

**What stays in the app targets (not in the package):**
- SwiftUI views (iOS and Mac have different layouts)
- `@main` App struct and `WindowGroup`/`MenuBarExtra`
- Target-specific entitlements (App Groups, iCloud containers)
- Widget extension entry points
- Asset catalogs, localisation strings

**Why this split:** `BlockTimeDomain` and `BlockTimeCalculators` have zero SwiftData dependency — calculators can be imported and tested by a plain Swift test target with no simulator needed. `BlockTimeData` is the only module that imports SwiftData. The Mac target and iOS target both depend on the same package products; they get different SwiftUI view files in their respective targets.

**Confidence: MEDIUM** — SPM multi-target structure is well-established; the specific naming is a design choice, not a framework constraint. Confirmed that @Model classes in a package module work (SwiftData import travels with the target).

---

## FRMS Calculator Placement

**Place in `BlockTimeCalculators` module inside `BlockTimeKit`.**

Rationale:
- Pure functions, no SwiftData dependency — no reason to couple it to `BlockTimeData`.
- Both iOS and Mac targets need it — package is the right sharing mechanism.
- Widget extension may need fatigue status for display — it can import `BlockTimeCalculators` without pulling in the full persistence stack.
- Unit tests import `BlockTimeCalculators` directly, no ModelContainer needed.

Signature (confirmed appropriate):
```swift
// BlockTimeCalculators/FRMSCalculator.swift
public enum FRMSCalculator {
    public static func compute(
        duties: [Duty],
        config: FRMSConfig
    ) -> FRMSResult { ... }
}
```

`Duty` and `FRMSConfig` are domain structs in `BlockTimeDomain`. `FRMSResult` is also a domain struct. No classes, no actors, fully `Sendable`.

**Confidence: HIGH** — pure function calculator placement is a straightforward dependency graph decision.

---

## Widget + App Group with SwiftData

**Recommended pattern (confirmed from Apple docs + June 2025 community articles):**

### Setup

1. Add App Group entitlement to both app target and widget extension: `group.com.yourcompany.blocktime`
2. In `ModelContainerFactory`, use `ModelConfiguration(groupContainer: .identifier("group.com.yourcompany.blocktime"))` — SwiftData automatically uses `containerURL(forSecurityApplicationGroupIdentifier:)` as the store parent directory.
3. Widget's `TimelineProvider` creates its own `ModelContainer` instance (separate process, separate instance, same on-disk store).

```swift
// ModelContainerFactory.swift — BlockTimeData module
public struct ModelContainerFactory {
    public static func makeShared(appGroupID: String) throws -> ModelContainer {
        let config = ModelConfiguration(
            groupContainer: .identifier(appGroupID)
        )
        return try ModelContainer(
            for: FlightModel.self, AircraftModel.self,
            configurations: config
        )
    }

    public static func makeInMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: FlightModel.self, AircraftModel.self,
            configurations: config
        )
    }
}
```

4. App target injects container at root: `.modelContainer(try ModelContainerFactory.makeShared(appGroupID: "group.com.yourcompany.blocktime"))`
5. Widget creates it directly in `TimelineProvider.getTimeline`.

### Migration from Core Data App Group store

The existing v1 app stores Core Data in an App Group container. SwiftData's migration path for this case (app group → app group) is handled by coexistence: run both stacks pointing at the same `group.*` container directory, copy data, then cut over. The Core Data store file and the SwiftData `.store` file live in the same App Group directory but are different files — no collision.

**CloudKit with App Groups:** SwiftData + CloudKit private database works with App Group containers. The `ModelConfiguration` that includes the group container identifier still syncs via CloudKit when the iCloud entitlement is present. PUBLIC/SHARED CloudKit databases are NOT supported by SwiftData — the existing app only uses the private database, so this is not a constraint.

**Confidence: HIGH** — `ModelConfiguration.GroupContainer` API is documented by Apple; App Group widget pattern confirmed in multiple 2024–2025 sources.

---

## UTC Storage + Local Display Pattern

**Rule: one conversion point per value — never at the model or repository layer.**

### Storage
All `Date` values in `FlightModel` are UTC `Date` objects. SwiftData stores `Date` as a Double (seconds since reference date) — timezone is irrelevant at storage. Do not store timezone offset in the `Date`; store it separately as an IATA airport code if needed (you already have `fromIATA`/`toIATA`).

### Display (view layer only)
```swift
// BlockTimeUI/Formatters/TimeDisplayFormatter.swift
public struct TimeDisplayFormatter {
    /// Returns HH:MM string in the local timezone of the given IATA airport
    public static func localTime(
        _ utcDate: Date,
        iata: String,
        airports: AirportService
    ) -> String {
        let tz = airports.timezone(for: iata) ?? .current
        let formatter = DateFormatter()   // or use FormatStyle in iOS 15+
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = tz
        return formatter.string(from: utcDate)
    }
}
```

For SwiftUI `Text` with `Date`:
```swift
// Use .formatted() with explicit timezone — iOS 15+
Text(flight.departureDateUTC.formatted(
    .dateTime.hour().minute().timeZone()
))
// For explicit airport-local time, pass through TimeDisplayFormatter
Text(TimeDisplayFormatter.localTime(flight.departureDateUTC, iata: flight.fromIATA, airports: airportService))
```

### Binding pattern for edit views (the existing pattern that works — confirmed from v1 Applied Learning)
```swift
// ViewModel holds UTC Date
var departureDateUTC: Date

// Binding presented to DatePicker converts at binding edges only
var localDepartureBinding: Binding<Date> {
    Binding(
        get: { TimeConverter.utcToLocal(departureDateUTC, iata: fromIATA) },
        set: { localDate in departureDateUTC = TimeConverter.localToUTC(localDate, iata: fromIATA) }
    )
}
```

Only convert complete, valid dates — partial string inputs (from the old String storage) no longer exist in v2.0 because the model stores `Date` directly.

**DateFormatter is not Sendable** — create per-call or cache per-actor. In `@MainActor` view models, a `@MainActor`-isolated `static let` formatter is safe.

**Confidence: HIGH** — `Date` in Swift is always UTC-epoch; timezone is a display concern only. This is well-established Swift behaviour.

---

## Build Order Implications

Build phases must respect the dependency graph. Nothing in a lower layer may import a higher layer.

```
Phase 1: BlockTimeDomain
  - Flight, Duty, Airport, FRMSResult structs
  - FlightRepository protocol
  - No external dependencies beyond Foundation
  - Ship with full unit tests before moving on

Phase 2: BlockTimeCalculators (parallel with Phase 3)
  - FRMSCalculator, NightTimeCalculator, TimeConverter
  - Imports BlockTimeDomain only
  - Must have 100% rule coverage tests before Phase 4 starts
  (FRMS bugs are invisible without tests — this is the primary motivation for the rewrite)

Phase 3: BlockTimeData (parallel with Phase 2)
  - FlightModel @Model class
  - SwiftDataFlightRepository
  - InMemoryFlightRepository
  - ModelContainerFactory
  - Migration service (Core Data → SwiftData)
  - Tests use InMemoryFlightRepository — no simulator required for logic tests

Phase 4: BlockTimeParsers
  - CSV, ACARS, Roster parsers
  - Imports BlockTimeDomain only
  - Tests against fixture files (no persistence needed)

Phase 5: BlockTimeUI (ViewModels)
  - @Observable ViewModels
  - Imports Domain + Calculators + Data protocols
  - Does NOT import SwiftData directly — receives repository via @Environment

Phase 6: App Targets (iOS + Mac)
  - SwiftUI views
  - Wire ModelContainerFactory → environment
  - Wire FlightRepository → environment
  - Widget extension

Phase 7: Migration path
  - CoreDataMigrationService reads existing .sqlite, writes Flight structs via FlightRepository
  - Run on first launch after update
  - Guarded by a migration-complete flag in UserDefaults
```

**Critical constraint:** Do not start Phase 6 (views) until Phase 3 (repository) has a working `InMemoryFlightRepository` — views need a repository to preview against. The in-memory impl is the preview data source too.

**Critical constraint:** Phase 7 (migration) must be proven against a copy of a real v1 database before shipping. No synthetic test data is a substitute for a 66,000-line production logbook.

---

## Key Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| `@Model` classes cannot cross actor boundaries freely | HIGH | Map to domain structs at repository boundary; never pass `@Model` to calculators |
| SwiftData + CloudKit does not support public/shared DB | LOW | v1 uses private DB only — not affected |
| Core Data → SwiftData migration loses data | CRITICAL | Run migration against production backup; keep Core Data stack alive until migration verified |
| `ModelContext` cannot be subclassed for mocking | MEDIUM | Use `InMemoryFlightRepository` (protocol impl) for tests; do not mock ModelContext |
| `@Model` in SPM package — macro expansion works cross-module | MEDIUM | Confirmed working (SwiftData import is explicit in the package target); test early |
| DateFormatter not thread-safe | LOW | Always create per-actor or per-call; never share across threads |

---

## Sources

- Apple Developer Documentation — ModelConfiguration.GroupContainer: https://developer.apple.com/documentation/swiftdata/modelconfiguration/groupcontainer-swift.struct
- Apple Developer Documentation — SwiftData overview: https://developer.apple.com/documentation/swiftdata
- Hacking with Swift — Widget SwiftData access: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-access-a-swiftdata-container-from-widgets
- Hacking with Swift — Unit tests for SwiftData: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code
- Hacking with Swift — Why @Model is a class: https://www.hackingwithswift.com/quick-start/swiftdata/why-are-swiftdata-models-created-as-classes
- Geoff Pado — @Query Considered Harmful (2025): https://pado.name/blog/2025/02/swiftdata-query/
- AzamSharp — SwiftData Architecture Patterns (March 2025): https://azamsharp.com/2025/03/28/swiftdata-architecture-patterns-and-practices.html
- Swift Unwrap — Data vs Domain Models: https://swiftunwrap.com/article/data-vs-domain/
- SwiftDataDecoupled example (shapehq): https://github.com/shapehq/SwiftDataDecoupled
- Apple Developer Forums — ModelContext cannot be subclassed: https://developer.apple.com/forums/thread/736804
- Apple Developer Forums — Core Data + SwiftData coexistence in App Group: https://developer.apple.com/forums/thread/756615
- Medium (June 2025) — SwiftData Widget with App Intents: https://medium.com/app-makers/how-to-build-a-configurable-swiftui-widget-with-app-intents-and-swiftdata-e4db410cfd12
