# Block-Time v2.0 — Project State

## Status
Phase: Not started
Current phase: —
Last updated: 2026-05-07

## Project Reference
See: .planning/PROJECT.md (updated 2026-05-07)

**Core value:** A pilot's logbook must be accurate and never lose data
**Current focus:** Phase 1 — Foundation

## Phase Progress

- ☐ Phase 1 — Foundation
- ☐ Phase 2 — Calculators & Tests
- ☐ Phase 3 — Core UI
- ☐ Phase 4 — Import Pipeline
- ☐ Phase 5 — Widgets & Extensions
- ☐ Phase 6 — Export & Settings
- ☐ Phase 7 — Mac + Pre-release

## Performance Metrics

Plans completed: 0
Plans total: TBD (populated after phase planning)
Phases completed: 0 / 7

## Accumulated Context

### Key Decisions (logged at phase transitions)
- (none yet)

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
- (none yet)

## Session Continuity

Last session: 2026-05-07 — Roadmap created, files written, traceability populated
Next action: `/gsd:plan-phase 1` — plan Foundation phase
