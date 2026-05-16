# Phase 2: CoreData Repository - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-16
**Phase:** 02-coredata-repository
**Areas discussed:** Migration policy implementation, Flight struct + Field scope, App wiring scope, CoreData model versioning

---

## Migration Policy Implementation

### Conversion logic source

| Option | Description | Selected |
|--------|-------------|----------|
| Inline the conversion | Migration policy contains its own string→minutes logic. Self-contained, no coupling to TimeStringConverter. | ✓ |
| Reuse TimeStringConverter | Policy calls TimeStringConverter directly. DRY but couples migration to an app-target type that may change. | |
| Move converter to BlockTimeKit first | Extract first, then use from package. Adds scope to Phase 2. | |

**User's choice:** Inline the conversion
**Notes:** Migration policies are one-shot — inline code is appropriate.

---

### Splash / CoreDataMigrationService fate

| Option | Description | Selected |
|--------|-------------|----------|
| Delete CoreDataMigrationService entirely | Lightweight migration is automatic. Delete service, actor, snapshot, and splash trigger. | ✓ |
| Repurpose as validation pass | Keep a lightweight row-count check service. | |
| Keep but disable | Comment out. Not recommended — dead code. | |

**User's choice:** Delete entirely

---

### Orphaned SwiftData store file

| Option | Description | Selected |
|--------|-------------|----------|
| Delete on launch if found | Check App Group container for blocktime.sqlite; delete if present. Dev builds only — no real user data. | ✓ |
| Leave it | Orphaned but harmless. | |

**User's choice:** Delete on launch if found

---

### UserDefaults migration flags cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Clear them on first launch | Remove v2MigrationStarted and v2MigrationComplete from UserDefaults. Avoids confusing future diagnostic reads. | ✓ |
| Leave them alone | Stale flags do no harm. | |

**User's choice:** Clear on first launch

---

### Core Data model versioning setup

| Option | Description | Selected |
|--------|-------------|----------|
| Rename current to v1, add v2 as active version | Standard Xcode flow. FlightDataModelV2 as current version. Core Data lightweight migration auto-detects delta. | ✓ |
| Create a fresh model file | More work, no benefit. | |

**User's choice:** Rename to v1, add v2 via Xcode

---

### Gate time timezone

| Option | Description | Selected |
|--------|-------------|----------|
| Local time strings | HH:MM is local airport time — needs ICAO lookup for conversion. | |
| UTC strings | HH:MM is already UTC. Combine with flight date directly. | ✓ |
| Mixed / unsure | Needs codebase verification. | |

**User's choice:** UTC strings
**Notes:** v1 app stores gate times as UTC "HH:MM".

---

### Gate time handling for nil/malformed

| Option | Description | Selected |
|--------|-------------|----------|
| Nil on missing or malformed | New Date? column is nil for any unreadable gate string. | ✓ |
| Use flightDate midnight as fallback | Produces misleading timestamp when time is unknown. | |

**User's choice:** Nil on missing or malformed

---

### Column naming convention

| Option | Description | Selected |
|--------|-------------|----------|
| New columns use canonical name | Old strings renamed to blockTimeLegacy etc.; new Int16 columns take blockTime etc. | ✓ |
| New columns get suffix | Old strings keep names; new Int16 get "Minutes" suffix. Permanently awkward. | |

**User's choice:** New columns take canonical names; old renamed to legacy

---

### Nil string → Int16 behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Nil string → 0 | No time logged = 0 minutes. Safe for FRMS calculation. | ✓ |
| Nil string → keep as nil | Not viable — Int16 is a scalar, cannot be nil in Core Data. | |

**User's choice:** Nil string → 0

---

### Legacy columns after migration

| Option | Description | Selected |
|--------|-------------|----------|
| Keep legacy columns in v2, mark as transient | Migration policy reads old values; columns kept as historical snapshots. | ✓ |
| Remove legacy columns in v2 | Cannot do this with lightweight migration — policy needs to read old values during migration. | |

**User's choice:** Keep legacy columns, marked transient

---

### Gate time column approach

| Option | Description | Selected |
|--------|-------------|----------|
| New Date columns replace old String columns (rename old to legacy) | outTimeLegacy (String, old), outTime (Date?, new). Same pattern as time fields. | ✓ |
| Different names for Date columns | e.g. outTimeDate alongside outTime. Permanently awkward. | |

**User's choice:** Rename old to legacy, new Date? columns take canonical names

---

### Mapping model approach

| Option | Description | Selected |
|--------|-------------|----------|
| Custom .xcmappingmodel file in Xcode | Explicit, visible, required for NSEntityMigrationPolicy. | ✓ |
| Inferred mapping model | Does NOT support custom NSEntityMigrationPolicy — not viable. | |

**User's choice:** Custom .xcmappingmodel file

---

### Legacy column cleanup after migration

| Option | Description | Selected |
|--------|-------------|----------|
| Leave them as-is | Small size, no complexity, no failure point. | ✓ |
| Nil out after migration | Post-migration batch update. Adds complexity and failure point. | |

**User's choice:** Leave legacy columns as-is

---

### Migration trigger location

| Option | Description | Selected |
|--------|-------------|----------|
| Configure in FlightDatabaseService persistentContainer | NSMigratePersistentStoresAutomaticallyOption + custom mapping model. Auto-migrates on first load. | ✓ |
| One-time coordinator before container loads | More explicit control but duplicates Core Data native behavior. | |

**User's choice:** Configure in FlightDatabaseService persistentContainer

---

## Flight Struct + Field Scope

### Field update scope

| Option | Description | Selected |
|--------|-------------|----------|
| Add ALL missing fields now | Int minutes, Date? gate times, dualTime, so1Name, so2Name, scheduledArrival/Departure, customCount. One complete update. | ✓ |
| Only REPO-required fields | Smaller diff but leaves Flight incomplete going into Phase 3. | |

**User's choice:** Add ALL missing fields

---

### customCount inclusion

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add it | customCount: Int in both Core Data and FlightModel. Must be in Flight for round-trip. | ✓ |
| Defer it | Not in REPO requirements — leave to Phase 5. | |

**User's choice:** Yes, add customCount

---

### search(query:) field scope

| Option | Description | Selected |
|--------|-------------|----------|
| String fields only | fromAirport, toAirport, flightNumber, aircraftReg, aircraftType, captainName, foName, remarks. Matches v1 behavior. | ✓ |
| Include date matching | Also match date strings. Not in v1. | |

**User's choice:** String fields only

---

### Flight↔FlightEntity mapping code location

| Option | Description | Selected |
|--------|-------------|----------|
| Private static methods on CoreDataFlightRepository | Same pattern as SwiftDataFlightRepository. Self-contained. | ✓ |
| FlightEntity extension | Cleaner for unit testing mapping but adds a file and couples FlightEntity to domain struct. | |

**User's choice:** Private static methods on CoreDataFlightRepository

---

### Core Data context access pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Direct NSFetchRequest on FlightEntity | CoreDataFlightRepository holds container reference, creates own NSFetchRequests. No dependency on FlightDatabaseService. | ✓ |
| Delegate to FlightDatabaseService | Tightly couples new repo to god object. | |

**User's choice:** Direct NSFetchRequest

---

### Context threading model

| Option | Description | Selected |
|--------|-------------|----------|
| viewContext on MainActor | All methods @MainActor. Matches FlightDatabaseService. Phase 4 can revisit if background queries needed. | ✓ |
| Background context | More complex, adds merge conflicts now. | |

**User's choice:** viewContext on MainActor

---

### Protocol conformance for @MainActor

| Option | Description | Selected |
|--------|-------------|----------|
| @MainActor on all mutating methods | Satisfies async protocol requirements. Swift allows this. | ✓ |
| Task { @MainActor in } at callsites | Not applicable — ViewModels will also be @MainActor. | |

**User's choice:** @MainActor on all methods

---

### search() predicate implementation

| Option | Description | Selected |
|--------|-------------|----------|
| NSCompoundPredicate with field predicates | Individual contains[cd] per field, combined with orPredicateWithSubpredicates. Type-safe. | ✓ |
| NSPredicate format string | CONTAINS[cd] format string across all fields. Slightly less type-safe. | |

**User's choice:** NSCompoundPredicate

---

### Test fixture updates

| Option | Description | Selected |
|--------|-------------|----------|
| Same plan as Flight struct update | Atomic change — compiler enforces completeness. | ✓ |
| Separate plan for test updates | Risk: non-compiling codebase between plans. | |

**User's choice:** Same plan — atomic

---

### deleteAll() implementation

| Option | Description | Selected |
|--------|-------------|----------|
| Fetch-then-delete via context | CloudKit history tracking preserved. Correct for NSPersistentCloudKitContainer. | ✓ |
| NSBatchDeleteRequest | Bypasses CloudKit history — deletes won't sync to other devices. | |

**User's choice:** Fetch-then-delete

---

### Sort order

| Option | Description | Selected |
|--------|-------------|----------|
| date descending, then createdAt descending | Consistent ordering for same-date flights. Matches FlightDatabaseService. | ✓ |
| date descending only | Same-date ordering undefined. | |

**User's choice:** Two-level sort: date desc, createdAt desc

---

### update() behavior when UUID not found

| Option | Description | Selected |
|--------|-------------|----------|
| Insert as new | Matches SwiftDataFlightRepository upsert behavior. Handles mid-edit delete race. | ✓ |
| Throw an error | More explicit but complex for call sites. | |

**User's choice:** Insert as new (upsert)

---

## App Wiring Scope

### Wiring depth

| Option | Description | Selected |
|--------|-------------|----------|
| Entry point only — .environment in Block_TimeApp | Views still use FlightDatabaseService directly. Phase 5 rewires views. | ✓ |
| Full view wiring now | 50+ files reference FlightDatabaseService. Too much scope. | |

**User's choice:** Entry point only

---

### productionContainer and OptionalModelContainerModifier

| Option | Description | Selected |
|--------|-------------|----------|
| Delete both entirely | SwiftData gone — no container needed. Simplifies Block_TimeApp. | ✓ |
| Keep as commented code | Dead code. Not recommended. | |

**User's choice:** Delete both

---

### SwiftData import removal scope

| Option | Description | Selected |
|--------|-------------|----------|
| Project-wide sweep | All import SwiftData removed. REPO-07 requirement. | ✓ |
| Only files directly touched | Risk: stray imports violate REPO-07. | |

**User's choice:** Project-wide sweep

---

### Block_TimeApp import cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, clean all unnecessary imports | Remove SwiftData, audit remaining imports. | ✓ |
| Leave imports alone | Defer cleanup. | |

**User's choice:** Clean all unnecessary imports

---

### EnvironmentKey default

| Option | Description | Selected |
|--------|-------------|----------|
| Default stays InMemoryFlightRepository | Good for previews. Entry point injects CoreDataFlightRepository. | ✓ |
| Change default to CoreDataFlightRepository | Breaks previews — never do this. | |

**User's choice:** Default stays InMemoryFlightRepository

---

### .managedObjectContext injection

| Option | Description | Selected |
|--------|-------------|----------|
| Keep .managedObjectContext injection | All existing views still need it. Remove in Phase 5. | ✓ |
| Remove it now | Would break all screens. Not viable. | |

**User's choice:** Keep until Phase 5

---

## Claude's Discretion

- Exact UserDefaults key for Phase 2 "orphan cleanup done" flag
- Error types thrown by CoreDataFlightRepository
- Exact naming for the NSEntityMigrationPolicy subclass
- Whether CoreDataFlightRepository parameter types as NSPersistentContainer (non-CloudKit, for test injection)

## Deferred Ideas

- Background context for CoreDataFlightRepository — Phase 4
- Widget rewiring to CoreDataFlightRepository — Phase 5
- View-level @Environment(\.flightRepository) wiring — Phase 5
- Nil-ing legacy string columns after migration — evaluated and rejected
