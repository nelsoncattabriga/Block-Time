---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: "## Phases"
current_phase: 01
status: in_progress
last_updated: "2026-05-15T23:28:00.991Z"
last_activity: 2026-05-16 - Plan 01-04 Tasks 1-3 complete; checkpoint at Task 4 (real .sqlite fixture verification — awaiting user response)
progress:
  total_phases: 7
  completed_phases: 0
  total_plans: 5
  completed_plans: 3
---

# Block-Time v2.0 — Project State

## Status

Phase: In Progress
Current phase: 01
Last updated: 2026-05-15

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-07)

**Core value:** A pilot's logbook must be accurate and never lose data
**Current focus:** Phase 01 — foundation

## Phase Progress

- ☐ Phase 1 — Foundation
- ☐ Phase 2 — Calculators & Tests
- ☐ Phase 3 — Core UI
- ☐ Phase 4 — Import Pipeline
- ☐ Phase 5 — Widgets & Extensions
- ☐ Phase 6 — Export & Settings
- ☐ Phase 7 — Mac + Pre-release

## Performance Metrics

Plans completed: 1
Plans total: 5
Phases completed: 0 / 7

## Accumulated Context

### Key Decisions (logged at phase transitions)

- Phase 01-01: swift-tools-version 6.0 required (CLI needs 6.0 for iOS 18/macOS 15 platform constants; 5.10 fails)
- Phase 01-01: Flight struct has 31 stored properties (plan said 26; interface spec requires 31)
- [01-foundation P02] TimeStringConverter lives in app target (D-03) — migration code is one-shot app concern, not BlockTimeKit
- [01-foundation P02] clockStringToSecondsFromMidnight returns nil for malformed clock strings, not 0 — caller handles absence vs. midnight
- [01-foundation P03] migrationPlan omitted from production CloudKit container — Apple bug causes fatal error (Pitfall 3)
- [01-foundation P03] @MainActor on all SwiftDataFlightRepository methods — simpler than ModelActor for Phase 1; revisit in Phase 3
- [01-foundation P03] FlightModel has 41 properties; toDomain/apply map all 31 Flight fields
- [01-foundation P04] CoreDataMigrationService uses Dependencies struct for injection — simpler than a protocol
- [01-foundation P04] Crash recovery resets v2MigrationStarted=false before retry — re-enters .notStarted cleanly (D-06 + D-07 compatible)
- [01-foundation P04] Real .sqlite fixture test (Test 9) deferred — must be completed before TestFlight (HARD requirement)

### Critical Reminders

- FOUND-01 (VersionedSchema) and FOUND-02 (App Group URL) must be done before any TestFlight build — no exceptions
- Migration (FOUND-09/10/11) must be proven against a real production .sqlite file, not just in-memory tests
- CloudKit schema must be deployed to Production (CloudKit Console) before App Store submission — Phase 7 checklist item
- @Query iOS 18 refresh bug (IMP-07) requires ModelContext.didSave workaround — must be in architecture from Phase 3 onward
- @Model classes may need to stay in app targets, not Swift Package — spike this on day one of Phase 1 (research risk 8)
- CloudKit record type name must match v1 CD_FlightEntity — verify in CloudKit Console before any Production schema change

### Open Questions

- (none yet)

### Blockers

- (none)

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260508-lvr | Add AddFlightWidget to the BlockTimeWidget extension | 2026-05-08 | f1aef95 | [260508-lvr-add-addflightwidget-to-the-blocktimewidg](./quick/260508-lvr-add-addflightwidget-to-the-blocktimewidg/) |
| Phase 01-foundation P03 | 5 | 4 tasks | 8 files |
| Phase 01-foundation P04 | 8 | 3 tasks | 8 files |

## Session Continuity

Last activity: 2026-05-16 - Plan 01-04 Tasks 1-3 complete; stopped at Task 4 (checkpoint:human-verify — real .sqlite fixture)
Next action: Respond to Task 4 checkpoint: either "fixture-confirmed" (place FlightDataModel.sqlite in Block-TimeTests/Fixtures/ and confirm Test 9 passes) OR "fixture-deferred-to-pre-testflight" (explicit deferral acknowledgement)
