---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Hybrid Architecture Rewrite
status: Executing Phase 03
stopped_at: Completed 03-01-PLAN.md
last_updated: "2026-05-17T02:21:18.177Z"
last_activity: 2026-05-17
progress:
  total_phases: 8
  completed_phases: 2
  total_plans: 14
  completed_plans: 10
---

# Block-Time v2.0 — Project State

## Status

Phase: 2 of 8 COMPLETE — ready to plan Phase 3
Last activity: 2026-05-17

## Project Reference

See: .planning/PROJECT.md
See: .planning/ROADMAP.md

**Core value:** A pilot's logbook must be accurate and never lose data
**Current focus:** Phase 03 — calculators-tests

## Phase Progress

- ☑ Phase 1 — Foundation (complete 2026-05-16)
- ☑ Phase 2 — CoreData Repository (complete 2026-05-17)
- ☐ Phase 3 — Calculators & Tests
- ☐ Phase 4 — God Object Breakup
- ☐ Phase 5 — Core UI + Widgets
- ☐ Phase 6 — Import Pipeline
- ☐ Phase 7 — Export & Settings
- ☐ Phase 8 — Mac + Pre-release

## Performance Metrics

Plans completed: 10 / 14
Phases completed: 2 / 8

| Phase | Plan | Duration (min) | Tasks | Files |
|-------|------|----------------|-------|-------|
| 02    | 01   | 8              | 3     | 4     |
| 02    | 02   | ~60            | 3     | 3     |
| 02    | 03   | 12             | 2     | 2     |
| 02    | 04   | ~90            | 5     | 14+   |
| 03    | 01   | 6              | 3     | 30    |

## Accumulated Context

### Key Decisions (from Phase 1)

- Phase 01: swift-tools-version 6.0 required — 5.10 fails for iOS 18/macOS 15 platform constants
- Phase 01: Flight struct has 31 stored properties (not 26 as initially planned)
- Phase 01: TimeStringConverter lives in app target — one-shot migration code is not BlockTimeKit concern
- Phase 01: clockStringToSecondsFromMidnight returns nil for malformed strings, not 0
- Phase 01: migrationPlan omitted from production CloudKit container — Apple bug causes fatal error
- Phase 01: CoreDataMigrationService uses Dependencies struct for injection (simpler than protocol)
- Phase 01: Real .sqlite fixture test deferred — MUST be completed before TestFlight (hard requirement)
- Pivot (2026-05-16): Core Data retained as persistence backend — SwiftData deleted in Phase 2. CoreDataFlightRepository replaces SwiftDataFlightRepository under same FlightRepository protocol.

### Key Decisions (from Phase 2)

- Phase 02-01: Flight struct uses Int minutes (not TimeInterval seconds) — self-documenting, no sub-minute precision needed
- Phase 02-01: InMemoryFlightRepository required no changes — stores Flight by UUID, no internal construction
- Phase 02-01: stringToMinutes/stringToDate test copies use Int return; production policy uses Int16 — clamp is identical
- Phase 02-02: FlightDataModelV2 — Int16 scalar (non-optional, default 0) for 9 time fields; Date? for 4 gate fields; 12 *Legacy String? attrs preserved for CloudKit compatibility
- Phase 02-02: @objc(FlightEntityMigrationPolicy) required — Core Data looks up custom policy class by ObjC runtime name; Swift name mangling breaks lookup without it
- Phase 02-03: CoreDataFlightRepository takes NSPersistentCloudKitContainer directly — does not delegate to FlightDatabaseService singleton (D-15)
- Phase 02-03: shouldInferMappingModelAutomatically = false required — CoreData inference cannot handle String→Int16 conversion
- Phase 02-03: deleteAll uses per-entity delete (not NSBatchDeleteRequest) — NSBatchDeleteRequest bypasses CloudKit persistent history
- Phase 02-04: App Group ID confirmed group.com.thezoolab.blocktime — matches Block-Time.entitlements
- Phase 02-04: CloudKit schema init skipped on simulator (#targetEnvironment(simulator)) — preserves V1 STRING schema in shared Development container while V2 branch is being developed
- Phase 02-04: FlightDatabaseService.swift V2 type errors (safeDoubleFromString→minutesToHours, string NSPredicates→numeric) — all fixed inline during Phase 2, not deferred
- Phase 02-04: RawDatabaseView, WidgetDataWriter, FlightMapViewModel all updated for V2 Int16/Date? field types

### Key Decisions (from Phase 3)

- Phase 03-01: CrewRestFacility moved to BlockTimeDomain — SignOnTimeRange is in BlockTimeDomain, preventing a circular dep with BlockTimeCalculators
- Phase 03-01: OperationTimeClass.classify uses Calendar(identifier: .gregorian) not Calendar.current — deterministic unit tests
- Phase 03-01: Public memberwise init required on all moved structs — auto-synthesized init is internal, cross-module calls fail without explicit public init

### Critical Reminders

- Real .sqlite fixture test (deferred from 01-04) MUST be done before any TestFlight build
- CloudKit schema must be verified in Production console before App Store submission (Phase 8)
- CloudKit record type name must match v1 CD_FlightEntity — verify before any schema change
- Lightweight migration must be idempotent — UserDefaults flag prevents double-run
- CloudKit schema init disabled on simulator only — real device DEBUG builds still push schema updates

### Blockers

None — build is green, simulator verified with 2697 flights.

## Session Continuity

Last session: 2026-05-17T02:21:18.174Z
Stopped at: Completed 03-01-PLAN.md
Next action: /gsd:plan-phase 3 (Calculators & Tests)
