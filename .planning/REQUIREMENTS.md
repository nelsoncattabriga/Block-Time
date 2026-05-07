# Block-Time v2.0 Requirements

## v1 Requirements

### Foundation (FOUND)

- [ ] **FOUND-01**: SwiftData schema wrapped in `VersionedSchema` / `SchemaV1` from the very first build — no unversioned schema ever shipped
- [ ] **FOUND-02**: `ModelConfiguration` URL and App Group container identifier pinned before any TestFlight distribution
- [ ] **FOUND-03**: `BlockTimeKit` local Swift Package created with four modules: `BlockTimeDomain`, `BlockTimeCalculators`, `BlockTimeData`, shared between iOS and Mac targets
- [ ] **FOUND-04**: `Flight` domain struct (value type, zero persistence coupling) is the authoritative model used by all calculators and ViewModels
- [ ] **FOUND-05**: `FlightRepository` protocol with two implementations: `SwiftDataFlightRepository` (production) and `InMemoryFlightRepository` (tests and SwiftUI previews)
- [ ] **FOUND-06**: All time values stored as `TimeInterval` (seconds) in `@Model` — no `String` time fields anywhere in v2.0
- [ ] **FOUND-07**: All dates stored as UTC `Date` — local-time conversion happens only at the display/binding layer
- [ ] **FOUND-08**: CloudKit sync configured via `ModelConfiguration(cloudKitDatabase: .automatic)` with the existing iCloud container — user data continuity preserved
- [ ] **FOUND-09**: One-time Core Data → SwiftData migration service runs on first launch, guarded by a `UserDefaults` completion flag, handles app crash mid-migration safely
- [ ] **FOUND-10**: Migration service converts all 8 String time fields (blockTime, simTime, nightTime, p1Time, p1usTime, p2Time, instrumentTime, spInsTime) to `TimeInterval`, handling nil, empty, "HH:MM", decimal-hours, malformed, and legacy placeholder strings without crashing
- [ ] **FOUND-11**: Migration service runs via `@ModelActor` on a background thread; main thread is never blocked during migration
- [ ] **FOUND-12**: SwiftUI previews work without a real CloudKit connection (in-memory repository injected via environment)

### Calculators & Testing (CALC)

- [ ] **CALC-01**: `FRMSCalculator.compute(duties: [Duty], config: FRMSConfig) -> FRMSResult` is a pure function with no SwiftData dependency
- [ ] **CALC-02**: LH Planning FRMS rules covered by unit tests — all limit thresholds and rest requirements
- [ ] **CALC-03**: LH Operational FRMS rules covered by unit tests
- [ ] **CALC-04**: SH Planning FRMS rules covered by unit tests
- [ ] **CALC-05**: SH Operational FRMS rules covered by unit tests
- [ ] **CALC-06**: Night time calculator is a pure function, tested for midnight crossing, DST transitions, and polar twilight edge cases
- [ ] **CALC-07**: UTC ↔ local time converter is a pure function, tested for DST transitions and midnight-crossing with airport timezone resolution
- [ ] **CALC-08**: CSV import parser is tested against fixture files covering all known field formats
- [ ] **CALC-09**: ACARS photo parser is tested against fixture images for B737, A330, A321, and A380 formats
- [ ] **CALC-10**: Roster parser (LH and SH formats) is tested against fixture roster documents
- [ ] **CALC-11**: `InMemoryFlightRepository` unit tests cover all `FlightRepository` protocol operations (fetch, insert, update, delete, filter)
- [ ] **CALC-12**: All calculator and parser tests run without a simulator (pure Swift, no SwiftUI or SwiftData dependency)

### Core UI (UI)

- [ ] **UI-01**: Flights list screen — all existing functionality preserved (search, filter, sort, scroll-to-current on launch)
- [ ] **UI-02**: Add/Edit flight screen — all fields, keyboard toolbar, local-time entry, draft persistence
- [ ] **UI-03**: Flight sector row — all display columns and tap behaviour preserved
- [ ] **UI-04**: FRMS view — all four rule sets, ring gauges, next duty calculator
- [ ] **UI-05**: Insights / Dashboard — all cards, chart data, @AppStorage picker state
- [ ] **UI-06**: Flight map view — MapKit, route polylines, airport annotations
- [ ] **UI-07**: Spreadsheet view (frozen column) and logbook spreadsheet view preserved
- [ ] **UI-08**: Bulk edit — multi-select, field overwrite, delete, BulkEditViewModel
- [ ] **UI-09**: Settings screen — all existing sections and options preserved
- [ ] **UI-10**: All ViewModels use `@Observable` (no `ObservableObject` remaining in v2.0)
- [ ] **UI-11**: `ThemeService` injected via `@Environment`, all theme tokens preserved
- [ ] **UI-12**: iPad: `NavigationSplitView` layout preserved
- [ ] **UI-13**: SwiftUI previews for all major screens using `InMemoryFlightRepository`

### Import Pipeline (IMP)

- [ ] **IMP-01**: CSV / file import end-to-end: file picker → parse → merge review sheet → commit
- [ ] **IMP-02**: ACARS photo import end-to-end: photo picker → OCR → field population → save
- [ ] **IMP-03**: Roster import (LH and SH): file picker → parse → planned flights → save
- [ ] **IMP-04**: AeroDataBox / FlightAware flight data lookup preserved
- [ ] **IMP-05**: Merge review sheet (duplicate detection) preserved with full field-level diff display
- [ ] **IMP-06**: WebCIS mapping view preserved
- [ ] **IMP-07**: `@Query` view refresh after background `@ModelActor` import uses `ModelContext.didSave` notification workaround (iOS 18 bug)

### Widgets & Extensions (WIDG)

- [ ] **WIDG-01**: Next-flight WidgetKit widget rebuilt against SwiftData App Group container
- [ ] **WIDG-02**: App Intents configuration intent preserved
- [ ] **WIDG-03**: Widget data writer uses `FlightRepository` protocol (not Core Data directly)
- [ ] **WIDG-04**: Midnight rollover and same-day sort logic preserved
- [ ] **WIDG-05**: Widget works correctly when no flights exist (empty state)

### Export (EXP)

- [ ] **EXP-01**: PDF logbook export — all pages, column layout, totals rows preserved
- [ ] **EXP-02**: CSV export — all fields, correct encoding preserved
- [ ] **EXP-03**: Calendar `.ics` export preserved
- [ ] **EXP-04**: Automatic backup service preserved
- [ ] **EXP-05**: PDF renderer reads from `FlightRepository` protocol (not Core Data)

### Settings & Sync (SET)

- [ ] **SET-01**: Single `AppSettings` `@Model` or `@Observable` class — one source of truth for all user preferences
- [ ] **SET-02**: All scattered `@AppStorage` calls in services eliminated — settings read through `AppSettings` only
- [ ] **SET-03**: CloudKit settings sync preserved (settings replicate across devices)
- [ ] **SET-04**: `FRMSConfiguration` consolidated into `AppSettings`
- [ ] **SET-05**: `LogbookSettings` consolidated into `AppSettings`
- [ ] **SET-06**: Onboarding flow and paywall preserved

### Mac Target (MAC)

- [ ] **MAC-01**: Mac target builds from the same `BlockTimeKit` Swift Package as iOS
- [ ] **MAC-02**: Mac Add/Edit/Delete panel preserved
- [ ] **MAC-03**: Mac Settings screen preserved
- [ ] **MAC-04**: Mac uses same `SwiftDataFlightRepository` as iOS
- [ ] **MAC-05**: Mac CloudKit sync works from the same iCloud container

---

## v2 Requirements (Deferred)

- Roster event calendar export — deferred to V3.0 milestone
- Real-time OOOI integration — anti-feature; explicitly excluded
- Weather briefing / EFB functions — anti-feature; explicitly excluded
- Weight and balance — anti-feature; explicitly excluded
- Instructor endorsement signatures — out of scope; airline-facing not addressed
- Career matching / job board integration — anti-feature

---

## Out of Scope

- **UI redesign** — v2.0 is an architecture rewrite; no visual changes
- **New features not in v1** — feature parity only; new features added post-v2.0
- **Breaking existing data** — user logbook data must survive migration without loss
- **EFB / operational tools** — pilots use company tools for these; not a logbook concern
- **FAA/EASA roster formats** — v1 supports LH and SH only; other airlines deferred

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 — Foundation | Pending |
| FOUND-02 | Phase 1 — Foundation | Pending |
| FOUND-03 | Phase 1 — Foundation | Pending |
| FOUND-04 | Phase 1 — Foundation | Pending |
| FOUND-05 | Phase 1 — Foundation | Pending |
| FOUND-06 | Phase 1 — Foundation | Pending |
| FOUND-07 | Phase 1 — Foundation | Pending |
| FOUND-08 | Phase 1 — Foundation | Pending |
| FOUND-09 | Phase 1 — Foundation | Pending |
| FOUND-10 | Phase 1 — Foundation | Pending |
| FOUND-11 | Phase 1 — Foundation | Pending |
| FOUND-12 | Phase 1 — Foundation | Pending |
| CALC-01 | Phase 2 — Calculators & Tests | Pending |
| CALC-02 | Phase 2 — Calculators & Tests | Pending |
| CALC-03 | Phase 2 — Calculators & Tests | Pending |
| CALC-04 | Phase 2 — Calculators & Tests | Pending |
| CALC-05 | Phase 2 — Calculators & Tests | Pending |
| CALC-06 | Phase 2 — Calculators & Tests | Pending |
| CALC-07 | Phase 2 — Calculators & Tests | Pending |
| CALC-08 | Phase 2 — Calculators & Tests | Pending |
| CALC-09 | Phase 2 — Calculators & Tests | Pending |
| CALC-10 | Phase 2 — Calculators & Tests | Pending |
| CALC-11 | Phase 2 — Calculators & Tests | Pending |
| CALC-12 | Phase 2 — Calculators & Tests | Pending |
| UI-01 | Phase 3 — Core UI | Pending |
| UI-02 | Phase 3 — Core UI | Pending |
| UI-03 | Phase 3 — Core UI | Pending |
| UI-04 | Phase 3 — Core UI | Pending |
| UI-05 | Phase 3 — Core UI | Pending |
| UI-06 | Phase 3 — Core UI | Pending |
| UI-07 | Phase 3 — Core UI | Pending |
| UI-08 | Phase 3 — Core UI | Pending |
| UI-09 | Phase 3 — Core UI | Pending |
| UI-10 | Phase 3 — Core UI | Pending |
| UI-11 | Phase 3 — Core UI | Pending |
| UI-12 | Phase 3 — Core UI | Pending |
| UI-13 | Phase 3 — Core UI | Pending |
| IMP-01 | Phase 4 — Import Pipeline | Pending |
| IMP-02 | Phase 4 — Import Pipeline | Pending |
| IMP-03 | Phase 4 — Import Pipeline | Pending |
| IMP-04 | Phase 4 — Import Pipeline | Pending |
| IMP-05 | Phase 4 — Import Pipeline | Pending |
| IMP-06 | Phase 4 — Import Pipeline | Pending |
| IMP-07 | Phase 4 — Import Pipeline | Pending |
| WIDG-01 | Phase 5 — Widgets & Extensions | Pending |
| WIDG-02 | Phase 5 — Widgets & Extensions | Pending |
| WIDG-03 | Phase 5 — Widgets & Extensions | Pending |
| WIDG-04 | Phase 5 — Widgets & Extensions | Pending |
| WIDG-05 | Phase 5 — Widgets & Extensions | Pending |
| EXP-01 | Phase 6 — Export & Settings | Pending |
| EXP-02 | Phase 6 — Export & Settings | Pending |
| EXP-03 | Phase 6 — Export & Settings | Pending |
| EXP-04 | Phase 6 — Export & Settings | Pending |
| EXP-05 | Phase 6 — Export & Settings | Pending |
| SET-01 | Phase 6 — Export & Settings | Pending |
| SET-02 | Phase 6 — Export & Settings | Pending |
| SET-03 | Phase 6 — Export & Settings | Pending |
| SET-04 | Phase 6 — Export & Settings | Pending |
| SET-05 | Phase 6 — Export & Settings | Pending |
| SET-06 | Phase 6 — Export & Settings | Pending |
| MAC-01 | Phase 7 — Mac + Pre-release | Pending |
| MAC-02 | Phase 7 — Mac + Pre-release | Pending |
| MAC-03 | Phase 7 — Mac + Pre-release | Pending |
| MAC-04 | Phase 7 — Mac + Pre-release | Pending |
| MAC-05 | Phase 7 — Mac + Pre-release | Pending |
