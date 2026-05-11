# Block-Time v2.0 Roadmap

## Milestone: v2.0

## Phases

- [ ] **Phase 1: Foundation** — SwiftData schema, BlockTimeKit package, FlightRepository protocol, migration service
- [ ] **Phase 2: Calculators & Tests** — Pure function FRMS, night time, time converter, all parsers with unit tests
- [ ] **Phase 3: Core UI** — All screens at feature parity, wired to SwiftData via repository
- [ ] **Phase 4: Import Pipeline** — CSV, ACARS, roster end-to-end with merge review sheet
- [ ] **Phase 5: Widgets & Extensions** — WidgetKit and App Intents rebuilt against SwiftData App Group container
- [ ] **Phase 6: Export & Settings** — PDF, CSV, .ics export; AppSettings consolidation
- [ ] **Phase 7: Mac + Pre-release** — Mac target, CloudKit Production deploy, migration rehearsal

---

## Phase Details

### Phase 1: Foundation
**Goal:** The SwiftData schema, BlockTimeKit package, and migration service are proven safe before any UI or TestFlight build touches them.
**UI hint:** no
**Depends on:** Nothing (first phase)
**Requirements:** FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-07, FOUND-08, FOUND-09, FOUND-10, FOUND-11, FOUND-12
**Success criteria:**
1. A real v1 production `.sqlite` file migrates to SwiftData without data loss — all time fields round-trip correctly from String to TimeInterval.
2. A simulated mid-migration crash on relaunch retries successfully and does not duplicate or corrupt records.
3. A SwiftUI preview opens on a screen backed by `InMemoryFlightRepository` with no CloudKit connection required.
4. The App Group store URL is pinned; adding/removing the widget extension does not produce an empty store on relaunch.
**Plans:** TBD

### Phase 2: Calculators & Tests
**Goal:** Every business rule and parser is a pure function with 100% test coverage before any UI wires against it.
**UI hint:** no
**Depends on:** Phase 1
**Requirements:** CALC-01, CALC-02, CALC-03, CALC-04, CALC-05, CALC-06, CALC-07, CALC-08, CALC-09, CALC-10, CALC-11, CALC-12
**Success criteria:**
1. `xcodebuild test` runs the full FRMS, night time, and time converter suite without a simulator — all tests pass.
2. All four FRMS rule sets (LH planning, LH operational, SH planning, SH operational) have at least one failing test that catches a known edge case before the fix is applied.
3. CSV, ACARS (B737/A330/A321/A380), and roster fixture tests all pass with no false-positive passes (fixtures include known bad inputs).
4. `InMemoryFlightRepository` tests cover fetch, insert, update, delete, and filter — all pass without SwiftData.
**Plans:** TBD

### Phase 3: Core UI
**Goal:** Every screen from v1 exists in v2.0 at full feature parity, backed by the repository protocol and using @Observable ViewModels.
**UI hint:** yes
**Depends on:** Phase 1, Phase 2
**Requirements:** UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07, UI-08, UI-09, UI-10, UI-11, UI-12, UI-13
**Success criteria:**
1. A user can open the app, see their full flights list, scroll to the current flight on launch, add a new flight, edit it, and delete it — end to end on a real device against the migrated SwiftData store.
2. The FRMS view shows the correct limits for the logged-in user's rule set — outputs match v1 for the same input data.
3. No screen contains an `ObservableObject` ViewModel; all ViewModels use `@Observable`.
4. All major screens have a working SwiftUI preview that renders without a CloudKit connection.
**Plans:** TBD

### Phase 4: Import Pipeline
**Goal:** CSV, ACARS photo, and roster imports complete end-to-end and the merge review sheet correctly surfaces duplicates.
**UI hint:** yes
**Depends on:** Phase 3
**Requirements:** IMP-01, IMP-02, IMP-03, IMP-04, IMP-05, IMP-06, IMP-07
**Success criteria:**
1. A user imports a CSV file — the merge review sheet appears, shows field-level diffs for duplicates, and committing the import persists all new records to SwiftData.
2. An ACARS photo is selected from the photo library, parsed, and the populated Add Flight form appears with correct field values for all four aircraft types.
3. A roster file (LH and SH formats) imports and creates planned flight entries visible in the flights list immediately after import — no app restart required.
4. After a background `@ModelActor` import completes, the flights list view refreshes without requiring manual pull-to-refresh (ModelContext.didSave workaround active).
**Plans:** TBD

### Phase 5: Widgets & Extensions
**Goal:** The WidgetKit next-flight widget and App Intents read from the SwiftData App Group container and display correct data.
**UI hint:** no
**Depends on:** Phase 1
**Requirements:** WIDG-01, WIDG-02, WIDG-03, WIDG-04, WIDG-05
**Success criteria:**
1. The next-flight widget shows the correct upcoming flight on the Home Screen when flights exist in the App Group SwiftData store.
2. The widget shows the correct empty state when no flights are scheduled — no crash, no stale data.
3. A flight that starts before midnight and ends after midnight is attributed to the correct date in the widget (midnight rollover logic preserved).
**Plans:** TBD

### Phase 6: Export & Settings
**Goal:** PDF, CSV, and calendar exports work against the SwiftData repository, and all app settings have one consolidated source of truth.
**UI hint:** yes
**Depends on:** Phase 3
**Requirements:** EXP-01, EXP-02, EXP-03, EXP-04, EXP-05, SET-01, SET-02, SET-03, SET-04, SET-05, SET-06, CUST-01, CUST-02, CUST-03
**Success criteria:**
1. A user exports their logbook as PDF — the output is visually identical to v1 with correct role columns, totals rows, and ICAO types.
2. CSV export produces a file that re-imports cleanly into the same app without data loss or field misalignment.
3. Changing a setting on one device appears on a second device within 60 seconds via CloudKit settings sync.
4. No service or ViewModel reads `@AppStorage` directly — all preference reads go through `AppSettings`.
5. A user can add a custom airport (CUST-01), it appears immediately in the FROM/TO picker and overrides any bundled entry with the same ICAO (CUST-02), and custom airports sync to all devices via CloudKit alongside flights (CUST-03).
**Plans:** TBD

### Phase 7: Mac + Pre-release
**Goal:** The Mac target builds from BlockTimeKit, syncs via CloudKit, and the app passes a full migration rehearsal on a device carrying real v1 data.
**UI hint:** yes
**Depends on:** Phase 6
**Requirements:** MAC-01, MAC-02, MAC-03, MAC-04, MAC-05
**Success criteria:**
1. The Mac target compiles and runs using the same `BlockTimeKit` package — Add/Edit/Delete panel and Settings screen are functional.
2. A real device running v1 with a full logbook updates to v2.0 and all flights appear intact after migration — zero records lost.
3. CloudKit schema is deployed to Production and a second device (iOS or Mac) syncs the same logbook within 60 seconds of the first device completing migration.
**Plans:** TBD

---

## Coverage Validation

All 65 v1 requirements mapped to exactly one phase. No orphans.

| Phase | Requirements | Count |
|-------|-------------|-------|
| 1 — Foundation | FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-07, FOUND-08, FOUND-09, FOUND-10, FOUND-11, FOUND-12 | 12 |
| 2 — Calculators & Tests | CALC-01, CALC-02, CALC-03, CALC-04, CALC-05, CALC-06, CALC-07, CALC-08, CALC-09, CALC-10, CALC-11, CALC-12 | 12 |
| 3 — Core UI | UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07, UI-08, UI-09, UI-10, UI-11, UI-12, UI-13 | 13 |
| 4 — Import Pipeline | IMP-01, IMP-02, IMP-03, IMP-04, IMP-05, IMP-06, IMP-07 | 7 |
| 5 — Widgets & Extensions | WIDG-01, WIDG-02, WIDG-03, WIDG-04, WIDG-05 | 5 |
| 6 — Export & Settings | EXP-01, EXP-02, EXP-03, EXP-04, EXP-05, SET-01, SET-02, SET-03, SET-04, SET-05, SET-06, CUST-01, CUST-02, CUST-03 | 14 |
| 7 — Mac + Pre-release | MAC-01, MAC-02, MAC-03, MAC-04, MAC-05 | 5 |
| **Total** | | **68/68** |

---

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/? | Not started | - |
| 2. Calculators & Tests | 0/? | Not started | - |
| 3. Core UI | 0/? | Not started | - |
| 4. Import Pipeline | 0/? | Not started | - |
| 5. Widgets & Extensions | 0/? | Not started | - |
| 6. Export & Settings | 0/? | Not started | - |
| 7. Mac + Pre-release | 0/? | Not started | - |
