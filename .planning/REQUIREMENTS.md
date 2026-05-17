# Block-Time v2.0 Requirements

**Defined:** 2026-05-16
**Core Value:** A pilot's logbook must be accurate and never lose data — every architectural decision serves that constraint first.

## v1 Requirements

### Foundation (FOUND)

- [x] **FOUND-01**: `BlockTimeKit` local Swift Package exists with three modules: `BlockTimeDomain`, `BlockTimeCalculators`, `BlockTimeData`, shared between iOS and Mac targets
- [x] **FOUND-02**: `Flight` domain struct (value type, zero persistence coupling, `Sendable`) is the authoritative model used by all calculators and ViewModels
- [x] **FOUND-03**: `FlightRepository` protocol defined in `BlockTimeData` with `InMemoryFlightRepository` for tests and previews
- [x] **FOUND-04**: SwiftUI previews work without a CloudKit connection (in-memory repository injected via environment)

### Core Data Repository (REPO)

- [x] **REPO-01**: `CoreDataFlightRepository` conforms to `FlightRepository`, backed by the existing `NSPersistentCloudKitContainer` — no store format change for users
- [x] **REPO-02**: Core Data lightweight migration adds `Int16` minute columns for all 8 time fields (blockTime, simTime, nightTime, p1Time, p1usTime, p2Time, instrumentTime, spInsTime) — existing decimal-hour strings converted via migration policy
- [ ] **REPO-03**: Core Data lightweight migration adds `dualTime: Int16` column (subset of P2, defaults 0 for all existing flights)
- [x] **REPO-04**: Core Data lightweight migration replaces `outTime`, `inTime`, `STD`, `STA` string fields with `Date?` columns — existing "HH:MM" strings combined with flight date and converted to UTC timestamps
- [x] **REPO-05**: `Flight` domain struct uses `Int` (minutes) for all time fields — `TimeInterval` (seconds) removed throughout `BlockTimeKit`
- [ ] **REPO-06**: `blockTime` stored independently in Core Data — not derived from `outTime`/`inTime`; handles simulator and positioning flights with no gate times
- [ ] **REPO-07**: SwiftData infrastructure deleted — `SchemaV1`, `FlightModel`, `AircraftModel`, `ModelContainerFactory`, `CoreDataMigrationService`, `CoreDataMigrationActor`, `SwiftDataFlightRepository` all removed
- [ ] **REPO-08**: App entry point injects `CoreDataFlightRepository` via `.environment` — SwiftData container setup removed
- [x] **REPO-09**: All existing `BlockTimeKit` tests still pass — `InMemoryFlightRepository` and `Flight` struct tests unaffected by persistence swap
- [x] **REPO-10**: CloudKit sync continues working — `NSPersistentCloudKitContainer` unchanged; lightweight migration does not break existing iCloud-synced data

### Calculators & Testing (CALC)

- [x] **CALC-01**: `FRMSCalculator.compute(duties: [Duty], config: FRMSConfig) -> FRMSResult` is a pure function in `BlockTimeCalculators` with no Core Data dependency
- [ ] **CALC-02**: LH Planning FRMS rules covered by unit tests — all limit thresholds and rest requirements
- [ ] **CALC-03**: LH Operational FRMS rules covered by unit tests
- [ ] **CALC-04**: SH Planning FRMS rules covered by unit tests
- [ ] **CALC-05**: SH Operational FRMS rules covered by unit tests
- [ ] **CALC-06**: Night time calculator is a pure function, tested for midnight crossing, DST transitions, and polar twilight edge cases
- [ ] **CALC-07**: `localDateToUTC(localDate:localTime:airportICAO:) -> Date` is a pure function in `BlockTimeCalculators`, tested for DST transitions, midnight crossing, and missing airport fallback
- [ ] **CALC-08**: Time display formatter (minutes → "HH:MM" and "H.hh" decimal) is a pure function, replaces all scattered `safeDoubleFromString` / `DateFormatter` string parsing
- [x] **CALC-09**: All calculator tests run without a simulator (pure Swift, no UIKit or Core Data dependency)

### God Object Breakup (GODOBJ)

- [ ] **GODOBJ-01**: `FlightDatabaseService` (3,693 lines) split into focused services: `FlightQueryService`, `FlightWriteService`, `FlightStatisticsService`, `CloudKitService`
- [ ] **GODOBJ-02**: `FlightTimeExtractorViewModel` (3,375 lines) split into `FlightFormViewModel` (form state only) and pure parser/service functions
- [ ] **GODOBJ-03**: All new services are `@Observable @MainActor` — no `ObservableObject` or `@Published` remaining in new code
- [ ] **GODOBJ-04**: `FlightDatabaseService.shared` singleton retained as thin coordinator during transition — services extracted incrementally, not all at once
- [ ] **GODOBJ-05**: ACARS parsing logic extracted to pure functions in `BlockTimeKit` with fixture tests for B737, A330, A321, A380 formats

### Core UI (UI)

- [ ] **UI-01**: Flights list — all existing functionality preserved (search, filter, sort, scroll-to-current on launch)
- [ ] **UI-02**: Add/Edit flight form — all fields, keyboard toolbar, local-time entry, `dualTime` field added
- [ ] **UI-03**: FRMS view — all four rule sets, ring gauges, next duty calculator, wired to pure `FRMSCalculator`
- [ ] **UI-04**: Insights / Dashboard — all cards, chart data, `@AppStorage` picker state preserved
- [ ] **UI-05**: Flight map view — MapKit, route polylines, airport annotations preserved
- [ ] **UI-06**: Spreadsheet and logbook spreadsheet views preserved
- [ ] **UI-07**: Bulk edit — multi-select, field overwrite, delete preserved
- [ ] **UI-08**: Settings screen — all existing sections and options preserved
- [ ] **UI-09**: All ViewModels use `@Observable` — no `ObservableObject` remaining
- [ ] **UI-10**: `ThemeService` injected via `@Environment`, all theme tokens preserved
- [ ] **UI-11**: iPad `NavigationSplitView` layout preserved
- [ ] **UI-12**: SwiftUI previews for all major screens using `InMemoryFlightRepository`

### Import Pipeline (IMP)

- [ ] **IMP-01**: CSV / file import end-to-end: file picker → parse → merge review sheet → commit to Core Data via `FlightWriteService`
- [ ] **IMP-02**: ACARS photo import end-to-end: photo picker → OCR → field population → save
- [ ] **IMP-03**: Roster import (LH and SH): file picker → parse → planned flights → save
- [ ] **IMP-04**: AeroDataBox / FlightAware flight data lookup preserved
- [ ] **IMP-05**: Merge review sheet (duplicate detection) preserved with full field-level diff display
- [ ] **IMP-06**: CSV and roster parsers tested against fixture files covering all known field formats

### Widgets & Extensions (WIDG)

- [ ] **WIDG-01**: Next-flight WidgetKit widget reads from Core Data App Group container via `CoreDataFlightRepository`
- [ ] **WIDG-02**: App Intents configuration intent preserved
- [ ] **WIDG-03**: Midnight rollover and same-day sort logic preserved
- [ ] **WIDG-04**: Widget works correctly when no flights exist (empty state)

### Export & Settings (EXP)

- [ ] **EXP-01**: PDF logbook export — all pages, column layout, totals rows, `dualTime` column added
- [ ] **EXP-02**: CSV export — all fields including `dualTime`, correct encoding preserved
- [ ] **EXP-03**: Calendar `.ics` export preserved
- [ ] **EXP-04**: Automatic backup service preserved
- [ ] **EXP-05**: Single `AppSettings` `@Observable` class — one source of truth for all user preferences; scattered `@AppStorage` in services eliminated
- [ ] **EXP-06**: CloudKit settings sync preserved

### Mac Target (MAC)

- [ ] **MAC-01**: Mac target builds from the same `BlockTimeKit` package as iOS
- [ ] **MAC-02**: Mac Add/Edit/Delete panel preserved and uses `CoreDataFlightRepository`
- [ ] **MAC-03**: Mac Settings screen preserved
- [ ] **MAC-04**: Full migration rehearsal on a real device carrying v1 data — zero records lost
- [ ] **MAC-05**: CloudKit schema verified in Production console before App Store submission

---

## v2 Requirements (Deferred)

- **SE/ME time** — derivable from aircraft type classification once an aircraft type database exists; no schema change needed
- **Aircraft type database** — SE/ME classification, performance data; deferred post-v2.0
- **Roster event calendar export** — deferred to v3.0
- **Real-time OOOI integration** — anti-feature; explicitly excluded
- **Weather briefing / EFB functions** — anti-feature; explicitly excluded
- **Weight and balance** — anti-feature; explicitly excluded

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| UI redesign | Architecture rewrite only — no visual changes |
| SwiftData migration | High user risk — one-way store swap, CloudKit schema instability. Core Data retained. |
| New features not in v1 | Feature parity only; new features post-v2.0 |
| Breaking existing data | User logbook must survive migration without loss |
| FAA/EASA/other roster formats | v1 supports LH and SH only |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 — Foundation | Complete |
| FOUND-02 | Phase 1 — Foundation | Complete |
| FOUND-03 | Phase 1 — Foundation | Complete |
| FOUND-04 | Phase 1 — Foundation | Complete |
| REPO-01 | Phase 2 — CoreData Repository | Complete |
| REPO-02 | Phase 2 — CoreData Repository | Complete |
| REPO-03 | Phase 2 — CoreData Repository | Pending |
| REPO-04 | Phase 2 — CoreData Repository | Complete |
| REPO-05 | Phase 2 — CoreData Repository | Complete |
| REPO-06 | Phase 2 — CoreData Repository | Pending |
| REPO-07 | Phase 2 — CoreData Repository | Pending |
| REPO-08 | Phase 2 — CoreData Repository | Pending |
| REPO-09 | Phase 2 — CoreData Repository | Complete |
| REPO-10 | Phase 2 — CoreData Repository | Complete |
| CALC-01 | Phase 3 — Calculators & Tests | Complete |
| CALC-02 | Phase 3 — Calculators & Tests | Pending |
| CALC-03 | Phase 3 — Calculators & Tests | Pending |
| CALC-04 | Phase 3 — Calculators & Tests | Pending |
| CALC-05 | Phase 3 — Calculators & Tests | Pending |
| CALC-06 | Phase 3 — Calculators & Tests | Pending |
| CALC-07 | Phase 3 — Calculators & Tests | Pending |
| CALC-08 | Phase 3 — Calculators & Tests | Pending |
| CALC-09 | Phase 3 — Calculators & Tests | Complete |
| GODOBJ-01 | Phase 4 — God Object Breakup | Pending |
| GODOBJ-02 | Phase 4 — God Object Breakup | Pending |
| GODOBJ-03 | Phase 4 — God Object Breakup | Pending |
| GODOBJ-04 | Phase 4 — God Object Breakup | Pending |
| GODOBJ-05 | Phase 4 — God Object Breakup | Pending |
| UI-01 | Phase 5 — Core UI + Widgets | Pending |
| UI-02 | Phase 5 — Core UI + Widgets | Pending |
| UI-03 | Phase 5 — Core UI + Widgets | Pending |
| UI-04 | Phase 5 — Core UI + Widgets | Pending |
| UI-05 | Phase 5 — Core UI + Widgets | Pending |
| UI-06 | Phase 5 — Core UI + Widgets | Pending |
| UI-07 | Phase 5 — Core UI + Widgets | Pending |
| UI-08 | Phase 5 — Core UI + Widgets | Pending |
| UI-09 | Phase 5 — Core UI + Widgets | Pending |
| UI-10 | Phase 5 — Core UI + Widgets | Pending |
| UI-11 | Phase 5 — Core UI + Widgets | Pending |
| UI-12 | Phase 5 — Core UI + Widgets | Pending |
| WIDG-01 | Phase 5 — Core UI + Widgets | Pending |
| WIDG-02 | Phase 5 — Core UI + Widgets | Pending |
| WIDG-03 | Phase 5 — Core UI + Widgets | Pending |
| WIDG-04 | Phase 5 — Core UI + Widgets | Pending |
| IMP-01 | Phase 6 — Import Pipeline | Pending |
| IMP-02 | Phase 6 — Import Pipeline | Pending |
| IMP-03 | Phase 6 — Import Pipeline | Pending |
| IMP-04 | Phase 6 — Import Pipeline | Pending |
| IMP-05 | Phase 6 — Import Pipeline | Pending |
| IMP-06 | Phase 6 — Import Pipeline | Pending |
| EXP-01 | Phase 7 — Export & Settings | Pending |
| EXP-02 | Phase 7 — Export & Settings | Pending |
| EXP-03 | Phase 7 — Export & Settings | Pending |
| EXP-04 | Phase 7 — Export & Settings | Pending |
| EXP-05 | Phase 7 — Export & Settings | Pending |
| EXP-06 | Phase 7 — Export & Settings | Pending |
| MAC-01 | Phase 8 — Mac + Pre-release | Pending |
| MAC-02 | Phase 8 — Mac + Pre-release | Pending |
| MAC-03 | Phase 8 — Mac + Pre-release | Pending |
| MAC-04 | Phase 8 — Mac + Pre-release | Pending |
| MAC-05 | Phase 8 — Mac + Pre-release | Pending |

**Coverage:**
- v1 requirements: 57 total
- Mapped to phases: 57
- Unmapped: 0

---
*Requirements defined: 2026-05-16*
*Last updated: 2026-05-16 — rewritten for hybrid Core Data approach; traceability aligned to 8-phase roadmap*
