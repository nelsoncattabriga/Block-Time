# Research Summary — Block-Time v2.0

---

## Stack Recommendations

| Decision | Recommendation | Confidence |
|----------|---------------|------------|
| Persistence | SwiftData + CloudKit (`.automatic`) | HIGH |
| Package name | `BlockTimeKit` — local Swift Package, 5 modules | MEDIUM |
| `@Model` location | App targets only, NOT in Swift Package | MEDIUM |
| Migration strategy | Application-layer one-time migration (not SchemaMigrationPlan) | HIGH |
| Schema versioning | `VersionedSchema` (`SchemaV1`) on day one, before first TestFlight | CRITICAL |
| CloudKit database type | Private only — matches v1; public/shared not supported by SwiftData | HIGH |
| App Group for widget | Pin `ModelConfiguration` URL explicitly; do not rely on automatic path | HIGH |
| `@Model` properties | All optional or with default values — `var blockTime: TimeInterval = 0` pattern | HIGH |
| Actor model | `@ModelActor` for background import; init from detached task, not `@MainActor` | MEDIUM |
| Testing | `InMemoryFlightRepository` (protocol impl) for logic tests; real on-disk `.sqlite` fixture for migration tests | HIGH |

---

## Table Stakes Features

Must ship in v2.0 before App Store submission (absence causes immediate rejection):

- Flight entry: date, dep/arr airport, aircraft type/reg, block time, role (PIC/P1U/P2), day/night, T/Os and landings
- Simulator entry: separate from flight time, FSTD type/name/location
- Multi-role time fields: PIC, PICUS, SIC/P2, dual, instructor (EASA FCL.050 mandates role separation)
- Night time as a stored field (not derived) — CASA CASR 61.345
- Instrument approaches by type — CASA + EASA + FAA all require this
- Running totals: last 28 days, last 90 days, last 365 days, total PIC, total hours
- PDF export — print-ready, CASA-compliant with role columns and ICAO types
- CSV export — non-negotiable for user trust; pilots fear vendor lock-in
- iCloud sync — all devices, seamless; already in v1
- Bulk CSV import — mandatory for new user acquisition; cannot ship without it
- ACARS + roster import — Block-Time's primary differentiator; must be preserved
- Search and filter by date range, aircraft, route, role
- Dashboard/totals view at-a-glance
- FRMS fatigue limit tracking — Block-Time's core differentiator; no AU competitor does LH + SH correctly
- Dark mode, widget (next flight + hours summary), calendar export, flight map — all preserved from v1

Features explicitly deferred (anti-features):
- Weather briefing, weight and balance, checklist management, social features, built-in flight planning, real-time ATC/OOOI, instructor endorsement signatures, career matching, maintenance logging

---

## Architecture: Layer Structure

5-module Swift Package (`BlockTimeKit`) + 2 app targets:

```
BlockTimeDomain          — Flight, Duty, Airport, FRMSResult structs; FlightRepository protocol
                           Zero external deps beyond Foundation; fully Sendable
BlockTimeCalculators     — FRMSCalculator, NightTimeCalculator, TimeConverter (pure functions)
                           Imports BlockTimeDomain only; unit-testable without simulator
BlockTimeData            — FlightModel (@Model), SwiftDataFlightRepository, InMemoryFlightRepository
                           ModelContainerFactory (pins App Group URL explicitly)
                           Imports SwiftData — only module that does
BlockTimeParsers         — CSVParser, ACARSParser, RosterParser
                           Imports BlockTimeDomain only; tested against fixture files
BlockTimeUI              — @Observable ViewModels, TimeDisplayFormatter
                           Imports Domain + Calculators; does NOT import SwiftData directly

iOS app target           — SwiftUI views, @main, entitlements, asset catalogs
Mac app target           — SwiftUI views (different layouts), same package dependencies
Widget extension         — Imports BlockTimeData; must include all @Model files in target membership
```

Key rules:
- `@Model` classes stay in app targets (MEDIUM risk if put in SPM; spike before committing)
- `FlightRepository` protocol is the seam: views never touch `ModelContext` directly
- UTC `Date` at storage; local time conversion at view layer only, via `TimeDisplayFormatter`
- `@Query` avoided in ViewModels — use `FetchDescriptor` via repository for testability
- Set relationships from the "many" side (iOS 18 bug: setting from "one" side silently fails)

---

## Critical Constraints

These cannot be changed after first TestFlight build without a user-visible migration or data risk:

1. **`VersionedSchema` (`SchemaV1`) must wrap initial schema before any user installs v2.0.** Shipping unversioned then adding VersionedSchema later crashes existing users on update.

2. **App Group store URL must be pinned explicitly in `ModelConfiguration`.** Adding an App Group entitlement without pinning the URL causes SwiftData to silently open a new empty store — users see data as gone.

3. **CloudKit schema must be deployed to Production (CloudKit Console → "Deploy Schema Changes") before App Store submission.** Development and Production CloudKit environments are fully separate; new attributes on TestFlight-only builds will not sync for App Store users.

4. **Core Data → SwiftData migration is application-layer, not `SchemaMigrationPlan`.** Custom `SchemaMigrationPlan` stages with CloudKit enabled throw a fatal error at container init — an Apple bug with no fix as of iOS 18. Migration must: open Core Data read-only, convert String→TimeInterval, insert into SwiftData, set UserDefaults flag, disable CloudKit during the migration window.

5. **All `@Model` properties need defaults or optionals.** Non-optional `TimeInterval` without a default silently breaks CloudKit sync — no crash, no user-visible error.

6. **Migration must be idempotent.** App crash mid-migration means next launch retries; UserDefaults flag must be set only after successful `modelContext.save()`.

---

## Top Risks

Ordered by probability x impact:

1. **Data loss during migration** (CRITICAL). String→TimeInterval converter must handle nil, empty string, "HH:MM", decimal hours, single-digit minutes ("1:5"), corrupt strings ("-", "N/A", "--:--"), and values >24 hours. Any conversion failure producing 0 for a non-zero value must be logged, not silently discarded. Test against a real production `.sqlite` file — in-memory tests do not exercise this path.

2. **Unversioned schema shipped to App Store** (CRITICAL). One-time mistake; no recovery without another forced update. Must be verified before any TestFlight build.

3. **App Group URL not pinned → empty store on launch** (CRITICAL). Pilot sees no data; App Store reviews crater. Fix is one line of code but must be caught before TestFlight.

4. **CloudKit schema not deployed to Production** (HIGH). Silent sync failure for all App Store users. Must be a documented pre-release checklist step.

5. **`@Query` not refreshing after background `@ModelActor` updates** (HIGH — iOS 18 regression). Inserts/deletes reflect; property-value updates do not. Import pipeline (ACARS, CSV) must post `ModelContext.didSave` notification and re-drive UI from main context.

6. **FRMS regressions invisible without tests** (HIGH). 1,842 lines of LH/SH rules with zero unit tests in v1. Must reach 100% rule coverage in `BlockTimeCalculators` before any UI work on the FRMS view.

7. **CloudKit record type name divergence** (HIGH). v1 Core Data used `CD_FlightEntity` as the CloudKit record type. SwiftData must use the same name or v1 iCloud data never syncs to v2. Verify in CloudKit Console before submission.

8. **`@Model` in Swift Package macro expansion failure** (MEDIUM). Consistent forum reports; if confirmed, all `@Model` classes stay in app targets, adding boilerplate. Spike this on day one of Phase 1.

9. **ModelActor init on main thread** (MEDIUM). `@ModelActor` init inside `@MainActor` code provides no background benefit. Import operations must init from a `Task.detached` context.

10. **Mac target CloudKit.framework not linked** (MEDIUM). Sync works in debug, silently dead in App Store builds. Check Build Phases before Mac TestFlight.

---

## Phase Implications

Research converges on this build order — each phase depends on the one above it being stable before proceeding:

**Phase 1 — Foundation (data layer + migration)**
Must come first. Every other phase depends on a working `Flight` struct and `FlightRepository`. Contains the highest-risk work (migration, schema versioning, App Group URL, CloudKit constraints). Must be proven against a real production `.sqlite` fixture before Phase 2 starts.
- Deliverables: `BlockTimeDomain`, `BlockTimeData`, `ModelContainerFactory`, `CoreDataMigrationService`, `SchemaV1` VersionedSchema, `InMemoryFlightRepository`, migration unit tests with real fixture
- Pitfalls to eliminate: risks 1–3 above (migration, unversioned schema, App Group URL)

**Phase 2 — Calculators + parsers (testable business logic)**
Parallel-eligible with Phase 1's later steps once domain structs are stable. Pure functions with no persistence dependency — fastest to write, most value from tests.
- Deliverables: `FRMSCalculator` with 100% rule coverage, `NightTimeCalculator`, `TimeConverter`, `CSVParser`, `ACARSParser`, `RosterParser` — all with fixture-based tests
- Research flag: FRMS LH/SH rule completeness — existing 1,842 lines need audit before test coverage target is set

**Phase 3 — ViewModels + core UI (flights list, add/edit, FRMS view)**
Needs Phase 1 (`InMemoryFlightRepository` for previews) and Phase 2 (calculators for FRMS display) complete. Build `@Observable` ViewModels first; wire SwiftUI views against them using in-memory repository.
- Deliverables: `FlightListViewModel`, `AddFlightViewModel`, `FRMSViewModel`, all existing screens at feature parity
- Watch: `@Query` background-update regression — implement `ModelContext.didSave` observer here

**Phase 4 — Import pipeline (ACARS, CSV, roster)**
Needs Phase 3 merge-review sheet UI to exist before importers can be trusted end-to-end.
- Deliverables: file import, ACARS photo parsing, roster import, duplicate detection merge sheet, all format variants (B737/A330/A321/A380)
- Watch: chunked batch inserts in `@ModelActor` (serial actor blocks on large imports)

**Phase 5 — Widget + extensions**
Needs Phase 1 `ModelContainerFactory` with App Group URL pinned. Must verify all `@Model` files in widget target membership.
- Deliverables: WidgetKit extension rebuilt against SwiftData, App Intents configuration preserved

**Phase 6 — Export + settings consolidation**
PDF, CSV, calendar export. Consolidate scattered `@AppStorage` into single `AppSettings` model.
- Deliverables: PDF export, CSV export, .ics export, `AppSettings` SwiftData model

**Phase 7 — Mac target + pre-release**
Mac companion rebuilt against same package. CloudKit.framework explicitly linked. CloudKit Production schema deployed. Real-device migration tested (existing data, clean iCloud-only device).
- Must-do before submission: CloudKit Console deploy, macOS Build Phases check, full migration rehearsal on a device with real v1 data
- Research flag: CloudKit record type name verification — inspect CloudKit Console against v1 `CD_FlightEntity` before any Production schema change

**Phases needing deeper research before planning:** Phase 2 (FRMS rule audit), Phase 7 (CloudKit record name verification).
**Phases with well-documented patterns (skip research):** Phase 1 (all patterns confirmed), Phase 5 (App Group widget pattern fully documented).
