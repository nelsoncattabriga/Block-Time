# Block-Time v2.0

## What This Is

Block-Time is an iOS (and Mac) pilot logbook app for professional airline pilots. It records flight sectors, calculates FRMS fatigue limits, tracks time totals, and exports logbook PDFs. v2.0 is a full architectural rewrite of the existing app, replacing Core Data with SwiftData, moving to a clean domain model, and making FRMS and time calculations fully unit-testable — while preserving every feature the current app has and migrating existing user data.

## Core Value

A pilot's logbook must be accurate and never lose data — every architectural decision serves that constraint first.

## Requirements

### Validated

**Data Layer**
- ✓ Clean `Flight` domain struct (no persistence concerns) acts as the authoritative model — Phase 1
- ✓ `FlightRepository` protocol with SwiftData and in-memory implementations — Phase 1
- ✓ All time values stored as `TimeInterval` (seconds) — no string representation in the model — Phase 1
- ✓ All dates/times stored as UTC `Date` — Phase 1
- ✓ Migration path from existing Core Data store to SwiftData on first launch — Phase 1 (real-device fixture test deferred to pre-TestFlight)
- ✓ SwiftData replaces Core Data as the persistence backend (schema + repository layer) — Phase 1

### Active

**Data Layer**
- [ ] SwiftData replaces Core Data as the persistence backend
- [ ] All time values stored as `TimeInterval` (seconds) or `Int` — no string representation in the model
- [ ] All dates/times stored as UTC `Date` — display layer converts to local
- [ ] Clean `Flight` domain struct (no persistence concerns) acts as the authoritative model
- [ ] `FlightRepository` protocol with SwiftData and in-memory implementations
- [ ] Migration path from existing Core Data store to SwiftData on first launch
- [ ] CloudKit sync works with SwiftData (iCloud logbook sync preserved)

**FRMS & Calculations**
- [ ] `FRMSCalculator` is a pure function: `compute(duties: [Duty], config: FRMSConfig) -> FRMSResult`
- [ ] All FRMS rules covered by unit tests (LH planning/operational, SH planning/operational)
- [ ] Night time calculation as pure function with edge cases covered by tests
- [ ] UTC↔local conversion as pure function, tested independently
- [ ] Time credit logic (block, sim, INS) as pure functions

**Import & Parsing**
- [ ] CSV file import (existing format support)
- [ ] ACARS photo parsing (B737, A330, A321, A380)
- [ ] Roster import (LH and SH formats, unified parser)
- [ ] WebCIS/AeroDataBox flight data lookup
- [ ] All parsers unit-tested against fixture inputs
- [ ] Merge review sheet preserved (duplicate detection on import)

**UI & Features**
- [ ] All existing screens and features preserved (flights list, add/edit, FRMS view, dashboard, map, settings, bulk edit, spreadsheet view)
- [ ] Shared iPad/Mac layout (NavigationSplitView)
- [ ] iOS and Mac targets built from the same Swift package
- [ ] ThemeService preserved via `@Environment`
- [ ] All `@AppStorage` picker state preserved

**Widgets & Extensions**
- [ ] WidgetKit next-flight widget works with SwiftData app group container
- [ ] App Intents configuration preserved
- [ ] Widget data writer uses new repository protocol

**Export**
- [ ] PDF logbook export preserved
- [ ] CSV export preserved
- [ ] Calendar (.ics) export preserved

**Settings & Sync**
- [ ] Single `AppSettings` model — one source of truth
- [ ] All UserDefaults settings consolidated (no scattered `@AppStorage` in services)
- [ ] CloudKit settings sync preserved

**Testing**
- [ ] FRMS rule unit tests — 100% rule coverage
- [ ] Repository layer tests with in-memory SwiftData store
- [ ] Parser tests for CSV, ACARS, roster formats
- [ ] Time/night calculation tests including DST and midnight-crossing edge cases

### Out of Scope

- UI redesign — v2.0 is an architecture rewrite; visual design stays the same
- New features not in v1 — roster event calendar, V2 feature ideas deferred
- Breaking existing data — user data must survive migration

## Context

- **v1 codebase:** 66,000 lines Swift, iOS 18.6+, currently shipping on App Store
- **Core Data God object:** `FlightDatabaseService.swift` is 3,654 lines — primary motivation for the rewrite
- **Time strings:** All time fields currently stored as `String?` in Core Data; the entire string-parsing layer must be eliminated
- **FRMS complexity:** LH and SH rules span 1,842 lines; no unit tests; regressions are invisible
- **Existing architecture strengths to preserve:** Service folder separation, ThemeService via @Environment, card-based dashboard with @AppStorage state, NavigationSplitView on iPad
- **ObservableObject classes left unmigrated by design in v1:** `FlightDatabaseService`, `FlightTimeExtractorViewModel`, `BulkEditViewModel`, `FlightTimeExtractorViewModel` — v2.0 migrates all of these
- **4 classes deliberately not migrated to @Observable in v1:** Now migrate in v2.0
- **iOS and Mac targets:** Mac companion app exists in v1; v2.0 shares a Swift Package between both targets

## Constraints

- **Tech stack:** SwiftData (not Core Data), Swift 6 strict concurrency, `@Observable`, iOS 18.6+, macOS 15+
- **Data safety:** Migration from v1 Core Data store is mandatory — no data loss acceptable
- **Feature parity:** Every feature in v1 must exist in v2.0 before shipping
- **App Store continuity:** v2.0 ships as an update to the existing app, not a new listing
- **No UI regressions:** Existing users must not notice a visual difference

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftData over Core Data | Eliminates boilerplate, native CloudKit sync, `@Query` in views, proper typed storage | Schema shipped as `SchemaV1: VersionedSchema` from day one (Phase 1) |
| Protocol-based repositories | Makes data layer swappable for tests; `FlightRepository` protocol with real + in-memory impl | `SwiftDataFlightRepository` + `InMemoryFlightRepository` both shipped (Phase 1) |
| Pure function FRMS calculator | Eliminates ObservableObject state from rule engine, enables exhaustive unit testing | — Phase 2 |
| `TimeInterval` for all time values | Eliminates string parsing layer throughout the app | All `@Model` fields use `TimeInterval`; `TimeStringConverter` handles v1 string→seconds conversion (Phase 1) |
| Shared Swift Package for iOS + Mac | Single source of truth for business logic, UI split at target boundary | `BlockTimeKit` with 3 modules shipped and linked (Phase 1) |
| `Flight` domain struct (not NSManagedObject) | Views and calculators work against a clean type, not persistence objects | `Flight: Sendable, Identifiable, Hashable` in `BlockTimeDomain` (Phase 1) |
| iOS/Mac same update — not new app | Preserve existing user base and reviews | — Pending |
| swift-tools-version 6.0 (not 5.10) | CLI toolchain requires 6.0 for iOS 18/macOS 15 platform constants | No negative impact on Xcode integration (Phase 1) |
| Migration guard in App Group container | Core Data store is in App Group, not app sandbox — real-device fixture test requires export step | Deferred to pre-TestFlight; Simulator fresh-install path verified (Phase 1) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-16 after Phase 1 (Foundation)*
