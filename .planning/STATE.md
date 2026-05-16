---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: "Hybrid Architecture Rewrite"
current_phase: 2
status: Ready to plan
last_updated: "2026-05-16"
last_activity: 2026-05-16
progress:
  total_phases: 8
  completed_phases: 1
  total_plans: 5
  completed_plans: 5
---

# Block-Time v2.0 — Project State

## Status

Phase: 2 of 8 (CoreData Repository — ready to plan)
Plan: —
Last activity: 2026-05-16 — Roadmap rewritten for hybrid Core Data approach; Phase 1 complete

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-16)

**Core value:** A pilot's logbook must be accurate and never lose data
**Current focus:** Phase 2 — CoreData Repository

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

Plans completed: 5
Plans total: 5 (Phase 1 only; Phases 2-8 TBD)
Phases completed: 1 / 8

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

### Critical Reminders

- Real .sqlite fixture test (deferred from 01-04) MUST be done before any TestFlight build
- CloudKit schema must be verified in Production console before App Store submission (Phase 8)
- CloudKit record type name must match v1 CD_FlightEntity — verify before any schema change
- Lightweight migration must be idempotent — UserDefaults flag prevents double-run

### Blockers

- (none)

## Session Continuity

Last session: 2026-05-16
Stopped at: Roadmap rewritten for hybrid approach — Phase 2 ready to plan
Next action: `/gsd:plan-phase 2`
