# Block-Time v2.0 Roadmap

## Milestone: v2.0 Hybrid Architecture Rewrite

## Phases

- [x] **Phase 1: Foundation** — BlockTimeKit package, Flight domain struct, FlightRepository protocol, InMemoryFlightRepository (completed 2026-05-16)
- [x] **Phase 2: CoreData Repository** — CoreDataFlightRepository, lightweight Core Data migration, SwiftData infrastructure deleted (completed 2026-05-17)
- [ ] **Phase 3: Calculators & Tests** — Pure function FRMS, night time, UTC conversion, time formatter with exhaustive unit tests
- [ ] **Phase 4: God Object Breakup** — FlightDatabaseService split into focused @Observable services, ACARS parsing extracted to BlockTimeKit
- [ ] **Phase 5: Core UI + Widgets** — All screens at feature parity wired to new services, WidgetKit updated to Core Data App Group
- [ ] **Phase 6: Import Pipeline** — CSV, ACARS, roster end-to-end with merge review sheet and fixture tests
- [ ] **Phase 7: Export & Settings** — PDF with dualTime column, CSV/ICS export, AppSettings consolidation
- [ ] **Phase 8: Mac + Pre-release** — Mac target, migration rehearsal on real device, CloudKit Production verification

---

## Phase Details

### Phase 1: Foundation
**Goal**: BlockTimeKit package and FlightRepository protocol boundary are proven before any persistence or UI work depends on them.
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04
**Success Criteria** (what must be TRUE):
  1. BlockTimeKit builds with three modules (BlockTimeDomain, BlockTimeCalculators, BlockTimeData) and links into both iOS and Mac targets
  2. Flight domain struct compiles as Sendable value type with zero persistence imports
  3. FlightRepository protocol and InMemoryFlightRepository are functional — all CRUD operations work in unit tests
  4. SwiftUI previews open without a CloudKit connection using the in-memory repository
**Plans**: 5/5 plans complete

Plans:
- [x] 01-01-PLAN.md — BlockTimeKit Swift Package scaffold (3 modules), Flight struct, FlightRepository protocol, InMemoryFlightRepository
- [x] 01-02-PLAN.md — TimeStringConverter (TDD) — all 13 v1 time-string format variants
- [x] 01-03-PLAN.md — SchemaV1 (FlightModel + AircraftModel), ModelContainerFactory (3 modes), SwiftDataFlightRepository
- [x] 01-04-PLAN.md — CoreDataMigrationService + @ModelActor + crash-safety + row-count verification
- [x] 01-05-PLAN.md — App entry wiring: SplashScreen trigger, production ModelContainer injection, preview environment

### Phase 2: CoreData Repository
**Goal**: The app runs entirely against CoreDataFlightRepository — existing user data is readable, SwiftData is gone, and the lightweight Core Data migration converts time strings and gate-time fields to clean types.
**Depends on**: Phase 1
**Requirements**: REPO-01, REPO-02, REPO-03, REPO-04, REPO-05, REPO-06, REPO-07, REPO-08, REPO-09, REPO-10
**Success Criteria** (what must be TRUE):
  1. The app builds and launches against CoreDataFlightRepository with no SwiftData imports remaining in the project
  2. Existing user Core Data records are readable — all flight fields map correctly to the Flight domain struct
  3. A lightweight Core Data migration runs on first launch: time strings convert to Int16 minutes, "HH:MM" gate times convert to Date?, dualTime column defaults to 0
  4. All existing BlockTimeKit tests (InMemoryFlightRepository, Flight struct) still pass after the persistence swap
  5. CloudKit sync continues — NSPersistentCloudKitContainer is unchanged and iCloud-synced data survives the migration
**Plans**: 4 plans

Plans:
- [x] 02-01-PLAN.md — Flight struct update (Int minutes, Date? gates, new fields) + InMemoryFlightRepository + test fixtures (atomic)
- [x] 02-02-PLAN.md — Core Data V2 model version + FlightDataModelV1toV2.xcmappingmodel + FlightEntityMigrationPolicy
- [x] 02-03-PLAN.md — CoreDataFlightRepository implementation + FlightDatabaseService migration options
- [x] 02-04-PLAN.md — SwiftData deletion sweep + Block_TimeApp wiring + orphan cleanup + simulator verification

### Phase 3: Calculators & Tests
**Goal**: Every business rule is a pure function with unit tests that run without a simulator — regressions in FRMS rules are caught by the test suite before they reach users.
**Depends on**: Phase 2
**Requirements**: CALC-01, CALC-02, CALC-03, CALC-04, CALC-05, CALC-06, CALC-07, CALC-08, CALC-09
**Success Criteria** (what must be TRUE):
  1. `xcodebuild test` runs the full FRMS, night time, UTC conversion, and time formatter suite without a simulator — all tests pass
  2. All four FRMS rule sets (LH planning, LH operational, SH planning, SH operational) have at least one test that catches a known edge case before the fix is applied
  3. Night time calculator tests cover midnight crossing, DST transition, and polar twilight edge cases
  4. Time formatter pure function correctly handles all v1 string formats and produces correct "HH:MM" and "H.hh" decimal output
**Plans**: 5 plans

Plans:
- [x] 03-01-PLAN.md — Move FRMS domain types into BlockTimeDomain, add FRMSResult, add BlockTimeCalculatorsTests target
- [x] 03-02-PLAN.md — TimeFormatter + UTCConverter pure functions + XCTest suites
- [x] 03-03-PLAN.md — NightTimeCalculator extraction with same-airport guard + XCTest edge cases
- [ ] 03-04-PLAN.md — Move 4 FRMS rule-set files + extract FRMSCalculator + LH Planning/Operational XCTest suites
- [ ] 03-05-PLAN.md — SH Planning + SH Operational XCTest suites

### Phase 4: God Object Breakup
**Goal**: FlightDatabaseService and FlightTimeExtractorViewModel are split into focused, independently-testable services — no single file owns query, write, statistics, CloudKit notification, and parsing logic at the same time.
**Depends on**: Phase 3
**Requirements**: GODOBJ-01, GODOBJ-02, GODOBJ-03, GODOBJ-04, GODOBJ-05
**Success Criteria** (what must be TRUE):
  1. FlightDatabaseService no longer contains query, statistics, or CloudKit notification logic — those responsibilities live in FlightQueryService, FlightStatisticsService, and CloudKitService
  2. FlightTimeExtractorViewModel no longer contains ACARS parsing logic — parsing is extracted to pure functions in BlockTimeKit
  3. All new services are @Observable @MainActor with no ObservableObject or @Published remaining
  4. ACARS fixture tests for B737, A330, A321, and A380 formats all pass in BlockTimeKit
**Plans**: TBD

### Phase 5: Core UI + Widgets
**Goal**: A user can complete the full flight logging workflow end to end on a real device — and the next-flight widget shows correct data from the Core Data App Group container.
**Depends on**: Phase 4
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07, UI-08, UI-09, UI-10, UI-11, UI-12, WIDG-01, WIDG-02, WIDG-03, WIDG-04
**Success Criteria** (what must be TRUE):
  1. A user can open the app, see their full flights list, scroll to the current flight on launch, add a flight with dualTime, edit it, and delete it — end to end on device
  2. The FRMS view shows correct limits for the user's rule set, wired to the pure FRMSCalculator — outputs match v1 for the same input data
  3. No ViewModel uses ObservableObject or @Published — all use @Observable
  4. The next-flight widget shows the correct upcoming flight from the Core Data App Group container, including correct midnight rollover behaviour and empty-state handling
**UI hint**: yes
**Plans**: TBD

### Phase 6: Import Pipeline
**Goal**: CSV, ACARS photo, and roster imports complete end to end — the merge review sheet correctly surfaces duplicates, and parsers are validated against real fixture files.
**Depends on**: Phase 5
**Requirements**: IMP-01, IMP-02, IMP-03, IMP-04, IMP-05, IMP-06
**Success Criteria** (what must be TRUE):
  1. A user imports a CSV file — the merge review sheet appears with field-level diffs for duplicates, and committing the import persists all new records to Core Data via FlightWriteService
  2. An ACARS photo parses correctly for all four aircraft types (B737, A330, A321, A380) and populates the Add Flight form with correct field values
  3. A roster file in both LH and SH formats imports and planned flights appear in the flights list immediately — no app restart required
  4. CSV and roster parser fixture tests cover all known field formats and known bad inputs, with no false-positive passes
**UI hint**: yes
**Plans**: TBD

### Phase 7: Export & Settings
**Goal**: PDF, CSV, and calendar exports work against the Core Data repository with the dualTime column, and AppSettings is the single source of truth for all user preferences.
**Depends on**: Phase 6
**Requirements**: EXP-01, EXP-02, EXP-03, EXP-04, EXP-05, EXP-06
**Success Criteria** (what must be TRUE):
  1. PDF export is visually identical to v1 — all pages, column layout, totals rows preserved — with the dualTime column added
  2. CSV export includes dualTime and re-imports cleanly without field misalignment
  3. No service or ViewModel reads @AppStorage directly — all preference reads go through AppSettings
  4. CloudKit settings sync is preserved — a setting changed on one device appears on a second device
**UI hint**: yes
**Plans**: TBD

### Phase 8: Mac + Pre-release
**Goal**: The Mac target builds from BlockTimeKit, a real device carrying v1 data updates without losing a single record, and the CloudKit schema is verified in the Production console before submission.
**Depends on**: Phase 7
**Requirements**: MAC-01, MAC-02, MAC-03, MAC-04, MAC-05
**Success Criteria** (what must be TRUE):
  1. The Mac target compiles and runs using the same BlockTimeKit package — Add/Edit/Delete panel and Settings screen are functional
  2. A real iOS device running v1 with a full logbook updates to v2.0 and all flights appear intact — zero records lost
  3. CloudKit schema is verified in the Production console and a second device syncs the same logbook after migration
**UI hint**: yes
**Plans**: TBD

---

## Coverage Validation

All 57 v1 requirements mapped to exactly one phase. No orphans.

| Phase | Requirements | Count |
|-------|-------------|-------|
| 1 — Foundation | FOUND-01, FOUND-02, FOUND-03, FOUND-04 | 4 |
| 2 — CoreData Repository | REPO-01, REPO-02, REPO-03, REPO-04, REPO-05, REPO-06, REPO-07, REPO-08, REPO-09, REPO-10 | 10 |
| 3 — Calculators & Tests | CALC-01, CALC-02, CALC-03, CALC-04, CALC-05, CALC-06, CALC-07, CALC-08, CALC-09 | 9 |
| 4 — God Object Breakup | GODOBJ-01, GODOBJ-02, GODOBJ-03, GODOBJ-04, GODOBJ-05 | 5 |
| 5 — Core UI + Widgets | UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07, UI-08, UI-09, UI-10, UI-11, UI-12, WIDG-01, WIDG-02, WIDG-03, WIDG-04 | 16 |
| 6 — Import Pipeline | IMP-01, IMP-02, IMP-03, IMP-04, IMP-05, IMP-06 | 6 |
| 7 — Export & Settings | EXP-01, EXP-02, EXP-03, EXP-04, EXP-05, EXP-06 | 6 |
| 8 — Mac + Pre-release | MAC-01, MAC-02, MAC-03, MAC-04, MAC-05 | 5 |
| **Total** | | **61** |

Note: 57 active requirements + 4 complete (FOUND-01–04) = 61 total mapped.

---

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 5/5 | Complete | 2026-05-16 |
| 2. CoreData Repository | 4/4 | Complete | 2026-05-17 |
| 3. Calculators & Tests | 0/5 | Planned | - |
| 4. God Object Breakup | 0/? | Not started | - |
| 5. Core UI + Widgets | 0/? | Not started | - |
| 6. Import Pipeline | 0/? | Not started | - |
| 7. Export & Settings | 0/? | Not started | - |
| 8. Mac + Pre-release | 0/? | Not started | - |
