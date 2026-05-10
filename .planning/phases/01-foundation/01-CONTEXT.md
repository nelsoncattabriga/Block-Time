# Phase 1: Foundation - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the SwiftData schema, `BlockTimeKit` local Swift Package, `FlightRepository` protocol + both implementations (SwiftData production + in-memory), and the Core Data → SwiftData one-time migration service. No UI changes. No service migrations. Pure infrastructure that must be proven safe before any TestFlight build.

</domain>

<decisions>
## Implementation Decisions

### Package Module Structure
- **D-01:** `BlockTimeKit` has **3 modules**: `BlockTimeDomain`, `BlockTimeCalculators`, `BlockTimeData`. No fourth Parsers module — parsers (CSV, ACARS, roster) live inside `BlockTimeCalculators` alongside FRMS and night-time calculators.
- **D-02:** `FlightRepository` protocol lives in **`BlockTimeData`** (not `BlockTimeDomain`). ViewModels import `BlockTimeData` to get the protocol + `InMemoryFlightRepository`.
- **D-03:** The migration service lives in the **app target only** — not in `BlockTimeKit`. It references both `NSPersistentCloudKitContainer` (Core Data) and `ModelContainer` (SwiftData) and is a one-shot launch concern. Dragging Core Data into the package is unnecessary.
- **D-04:** `ThemeService`, `AirportService`, `AppState`, and all other existing app-target singletons stay in the app target in Phase 1. Service migration is Phase 3 scope.

### @Model Placement
- **D-05:** Treat `@Model` in a Swift Package as a known non-starter. **Do not spike it.** `@Model` classes and `SwiftDataFlightRepository` live in the app target from day one. `BlockTimeKit` only gets the `FlightRepository` protocol and `InMemoryFlightRepository`.

### Migration Crash Safety
- **D-06:** **Clear-and-retry** on crash. If `migrationStarted=true` and `migrationComplete=false` on launch, delete the partially-written SwiftData store and re-run migration from scratch using the (read-only) Core Data source. Simple and safe.
- **D-07:** **Two flags in UserDefaults**: `migrationStarted` (set at migration begin) and `migrationComplete` (set only after row-count verification passes). Never invert their write order.
- **D-08:** **Row-count verification** before setting `migrationComplete=true`. Count flights in Core Data, count in SwiftData, require exact match. If mismatch: do not set complete flag, log a diagnostic, surface an error to the user. No silent failures.

### CloudKit During Migration
- **D-09:** Migration runs with **`cloudKitDatabase: .none`** — CloudKit is disabled for the duration. Prevents partial records from syncing to devices still running v1.
- **D-10:** After `migrationComplete=true` is set, **force relaunch via `exit(0)`**. New launch path creates the real CloudKit-backed `ModelContainer`. No in-process container swap.

### Claude's Discretion
- Internal structure of `BlockTimeDomain` (which value types to define in Phase 1 vs later phases)
- `Flight` domain struct field layout (mirroring v1 `FlightEntity` fields)
- Exact UserDefaults keys for migration flags
- Whether to show a migration progress UI or keep it silent/splash-screen-level
- `InMemoryFlightRepository` API surface detail (Claude can follow `FlightRepository` protocol)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1 Core Data Schema (migration source)
- `Block-Time/FlightDataModel.xcdatamodeld/FlightDataModel.xcdatamodel/contents` — The v1 Core Data model. All entity names, field types, and relationships that the migration service must read from.
- `Block-Time/Models/FlightEntity+Extensions.swift` — Field accessors and computed properties on `FlightEntity`.

### v1 App Entry Point & Container Setup
- `Block-Time/Block_TimeApp.swift` — Current app entry point; shows how Core Data context is injected. Migration logic must not break this launch path for v1 users.
- `Block-Time/Services/FlightDatabaseService.swift` — `NSPersistentCloudKitContainer` setup (lazy, App Group URL, CloudKit options). Migration reads from this stack.

### App Group & CloudKit Identifiers (pinned)
- `Block-Time/Block-Time.entitlements` — iCloud container: `iCloud.com.thezoolab.blocktime`; App Group: `group.com.thezoolab.blocktime`. These must match exactly in the new SwiftData `ModelConfiguration`.

### Widget App Group Reference
- `Block-Time/Models/WidgetFlightEntry.swift` — `appGroupID = "group.com.thezoolab.blocktime"`. SwiftData store URL must be pinned to this same group so the widget extension can read it.

### Project Requirements
- `.planning/REQUIREMENTS.md` — FOUND-01 through FOUND-12 are all in scope for Phase 1. Every requirement must be addressed.

### Research
- `.planning/research/STACK.md` — SwiftData + CloudKit setup guide, `@Model` constraints, `ModelActor` patterns, migration option analysis.
- `.planning/research/SUMMARY.md` — Synthesized research findings.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FlightDatabaseService.swift`: The Core Data singleton — migration service reads `persistentContainer.viewContext` (or a background context) to fetch all `FlightEntity` records.
- `WidgetFlightEntry.swift`: Defines `appGroupID = "group.com.thezoolab.blocktime"` — copy this constant, don't re-derive it.
- `FlightEntity+Extensions.swift`: Field helpers to reference when building the `Flight` domain struct mapping.

### Established Patterns
- Core Data context is injected via `.environment(\.managedObjectContext, ...)` — the SwiftData equivalent will be via `ModelContainer` / `@Environment(\.modelContext)`.
- Services are singletons (`ServiceName.shared`) — `BlockTimeKit` modules should prefer protocol-based injection over singletons.
- App uses `lazy var persistentContainer` — SwiftData `ModelContainer` should similarly be created once and passed down.

### Integration Points
- `Block_TimeApp.swift` is where the new `ModelContainer` will be created and injected (replacing the `.managedObjectContext` environment key).
- Migration service will be triggered from `SplashScreenView.onAppear` (current pattern for one-time launch tasks in v1).
- Widget extension needs the same App Group store URL — `ModelConfiguration` URL must be pinned before any widget build.

</code_context>

<specifics>
## Specific Ideas

- The iCloud container `iCloud.com.thezoolab.blocktime` and App Group `group.com.thezoolab.blocktime` are the live production identifiers. They must be pinned in `ModelConfiguration` before any TestFlight distribution (FOUND-02 is non-negotiable).
- `exit(0)` is the chosen relaunch mechanism after migration — simple, proven, avoids container swap complexity.
- The `v2-dev` branch is the long-running branch for all v2 work. v1 stays shippable on `main`.

</specifics>

<deferred>
## Deferred Ideas

- Moving `AirportService` into `BlockTimeCalculators` — deferred to Phase 2/3 (night-time calculator needs it, but service migration is Phase 3 scope).
- Migration progress UI — deferred to Phase 3 (Core UI). Phase 1 can use splash screen / silent migration.
- Batch-by-batch checkpoint migration — evaluated and rejected in favour of clear-and-retry for simplicity.
- In-process container swap after migration — evaluated and rejected as high risk.

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-05-10*
