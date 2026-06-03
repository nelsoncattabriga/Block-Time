# Block Time V2.0 — Loose Plan

## Motivation

V1 has accumulated technical debt that is better resolved in a clean rewrite than migrated in place:
- Time fields stored as `String` in Core Data — should be integer minutes
- `ObservableObject` singletons (`FlightDatabaseService.shared`) make testing and previews painful
- Core Data boilerplate is verbose and doesn't fit modern Swift patterns
- CloudKit sync is opaque and schema changes are painful

---

## Key Decisions

### Bundle ID
New bundle ID and new App Store listing. V1 stays installed until the user deletes it. Avoids in-place migration risk entirely.

### Data Layer: SwiftData
- Models defined as Swift classes with `@Model` — no `.xcdatamodeld` file
- Time stored as `Int` (minutes) throughout — no floating-point accumulation errors
- `ModelContext` injected via `@Environment` — no singletons
- Full `@Observable` / Swift 6 strict concurrency from day one

### Sync: iCloud Drive JSON
Prefer iCloud Drive JSON over CloudKit. Rationale:
- Logbook data volume is small (thousands of flights = ~2–3MB)
- Simultaneous multi-device writes are rare for a personal logbook
- Full control over format — migrations are plain JSON transformations
- File is inherently a portable backup
- No CloudKit schema lock-in or opaque sync debugging

If iCloud Drive JSON proves insufficient (e.g. real-time sync requirement emerges), revisit CloudKit via SwiftData's native integration.

### Mac Target
Decision needed before Phase 1. Options:
- **Mac Catalyst** — faster, reuses iOS code, lower quality ceiling
- **Native macOS target** — better UX, more work

Lean towards native if the Mac app is a priority; Catalyst if it's secondary.

### Monetisation
Decide paid upgrade vs subscription before App Store setup — affects pricing infrastructure from day one.

---

## Tech Stack

| Layer | Choice |
|---|---|
| Language | Swift 6 strict concurrency |
| UI | SwiftUI (iOS 18+) |
| Data | SwiftData |
| Sync | iCloud Drive JSON |
| State | `@Observable` throughout — no `ObservableObject` |
| Async | `async/await`, `TaskGroup` |
| Networking | Same providers (FlightAware, AeroDataBox) |

**Dropped from V1:**
- `ObservableObject` / `@Published` / `@StateObject`
- `NSPersistentCloudKitContainer`
- `FlightDatabaseService.shared` singleton
- String time fields

---

## Roadmap

### Phase 1 — Foundation
- New Xcode project, new bundle ID
- SwiftData schema (all entities, integer minutes, proper relationships)
- iCloud Drive JSON sync wired up
- V1 import — reads old Core Data store, converts strings → integer minutes, writes to SwiftData
- Basic flight list and add/edit flight (enough to validate the full stack on real data)

### Phase 2 — Core Logbook
- Full flight entry form (V1 parity)
- Aircraft management
- Crew management
- Logbook list with filtering and sorting
- Spreadsheet view

### Phase 3 — Import Pipelines
- WebCIS import
- File import (CSV/PDF)
- ACARS photo parsing
- Duplicate detection and merge review

### Phase 4 — FRMS & Dashboard
- FRMS calculation engine (rewritten against integer minutes — significantly cleaner)
- Dashboard cards
- Insights / analytics

### Phase 5 — Platform
- Widget (rebuilt against SwiftData)
- Mac target (Catalyst or native — decision from Phase 1)
- Calendar export
- PDF export

### Phase 6 — Polish & Ship
- Custom fields
- Settings parity
- V1 import UX as a first-class onboarding flow (not buried in settings)
- App Store submission

---

## Notes

- V1 import ships in Phase 1 so real data is available for dogfooding throughout development
- iOS 18+ minimum — enables full SwiftData maturity, `Tab` API, latest `@Observable`
- No hybrid approach — V2 is a clean slate, not a migration of V1 internals
