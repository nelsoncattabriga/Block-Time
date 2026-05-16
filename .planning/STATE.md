---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Hybrid Architecture Rewrite
status: Executing Phase 02
stopped_at: Checkpoint 02-04-PLAN.md Task 5 (human-verify)
last_updated: "2026-05-16T12:43:00.000Z"
last_activity: 2026-05-16
progress:
  total_phases: 8
  completed_phases: 1
  total_plans: 9
  completed_plans: 8
---

# Block-Time v2.0 — Project State

## Status

Phase: 2 of 8 (CoreData Repository — ready to plan)
Plan: —
Last activity: 2026-05-16

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-16)

**Core value:** A pilot's logbook must be accurate and never lose data
**Current focus:** Phase 02 — coredata-repository

## Phase Progress

- ☑ Phase 1 — Foundation (complete)
- ☐ Phase 2 — CoreData Repository
- ☐ Phase 3 — Calculators & Tests
- ☐ Phase 4 — God Object Breakup
- ☐ Phase 5 — Core UI + Widgets
- ☐ Phase 6 — Import Pipeline
- ☐ Phase 7 — Export & Settings
- ☐ Phase 8 — Mac + Pre-release

## Performance Metrics

Plans completed: 6 (Phase 1: 5, Phase 2: 1 so far; 02-04 partial)
Plans total: 9
Phases completed: 1 / 8

| Phase | Plan | Duration (min) | Tasks | Files |
|-------|------|----------------|-------|-------|
| 02    | 01   | 8              | 3     | 4     |
| 02    | 03   | 12             | 2     | 2     |
| 02    | 04   | 45             | 4/5   | 14    |

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
- Phase 02-01: Flight struct uses Int minutes (not TimeInterval seconds) — self-documenting, no sub-minute precision needed
- Phase 02-01: InMemoryFlightRepository required no changes — stores Flight by UUID, no internal construction
- Phase 02-01: stringToMinutes/stringToDate test copies use Int return; production policy uses Int16 — clamp is identical
- Phase 02-03: CoreDataFlightRepository takes NSPersistentCloudKitContainer directly — does not delegate to FlightDatabaseService singleton (D-15)
- Phase 02-03: shouldInferMappingModelAutomatically = false is required — CoreData inference cannot handle String→Int16 conversion
- Phase 02-03: deleteAll uses per-entity delete (not NSBatchDeleteRequest) — NSBatchDeleteRequest bypasses CloudKit persistent history
- Phase 02-04: App Group ID confirmed group.com.thezoolab.blocktime — matches Block-Time.entitlements
- Phase 02-04: FlightDatabaseService.swift has 98 pre-existing V2 schema type errors — deferred to Phase 4 god object breakup
- Phase 02-04: Plan assumption "118 errors disappear after SwiftData deletion" was wrong — errors were always in FlightDatabaseService, hidden by early compile failure

### Critical Reminders

- Real .sqlite fixture test (deferred from 01-04) MUST be done before any TestFlight build
- CloudKit schema must be verified in Production console before App Store submission (Phase 8)
- CloudKit record type name must match v1 CD_FlightEntity — verify before any schema change
- Lightweight migration must be idempotent — UserDefaults flag prevents double-run

### Blockers

- FlightDatabaseService.swift (3686 lines): 60+ V2 schema type errors — blockTime (Int16) and scheduledDeparture/Arrival (Date?) used as String throughout. Requires Phase 4 god object breakup before build is green.
- FlightDatabaseService+InsightsQueries.swift: 38+ V2 schema errors of same type.

## Session Continuity

Last session: 2026-05-16T12:43:00.000Z
Stopped at: Checkpoint 02-04-PLAN.md Task 5 (human-verify simulator)
Next action: After Nelson verifies simulator launch, continue 02-04 checkpoint
