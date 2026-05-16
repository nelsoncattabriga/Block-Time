---
phase: 02-coredata-repository
plan: "02"
subsystem: database
tags: [core-data, migration, nsentitymigrationpolicy, swift]

# Dependency graph
requires:
  - phase: 02-coredata-repository
    provides: Research and context for Core Data V2 migration approach
provides:
  - FlightEntityMigrationPolicy.swift with inline string→Int16 and string→Date? conversion
  - V2 Core Data model (pending Xcode UI checkpoint — Task 2 not yet done)
  - FlightDataModelV1toV2.xcmappingmodel (pending Xcode UI checkpoint)
affects:
  - 02-coredata-repository (Task 2 Xcode UI work)
  - CoreDataFlightRepository implementation (reads Int16 scalars and Date? gates)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSEntityMigrationPolicy inline conversion: no external dependencies, self-contained"
    - "D-01: migration policy does NOT reuse TimeStringConverter"

key-files:
  created:
    - Block-Time/Migration/FlightEntityMigrationPolicy.swift
  modified: []

key-decisions:
  - "Inline stringToMinutes/stringToDate in migration policy — no reuse of TimeStringConverter (D-01)"
  - "Malformed time strings → 0 (Int16 fields) or nil (Date? fields) per D-06"

patterns-established:
  - "NSEntityMigrationPolicy pattern: super.createDestinationInstances first, then setValue loops for batch field conversion"

requirements-completed: [REPO-02, REPO-03, REPO-04, REPO-06]

# Metrics
duration: ~5min (Task 1 only; Task 2 pending human checkpoint)
completed: 2026-05-16
---

# Phase 02 Plan 02: Core Data V2 Model and Migration Policy Summary

**NSEntityMigrationPolicy subclass with inline decimal-hour and HH:MM string conversion to Int16 minutes and UTC Date? — Task 1 complete; Task 2 awaiting Xcode UI operations at checkpoint**

## Performance

- **Duration:** ~5 min (Task 1)
- **Started:** 2026-05-16T11:45:59Z
- **Completed:** 2026-05-16T11:47:XX Z (partial — checkpoint hit at Task 2)
- **Tasks:** 1/2 complete
- **Files modified:** 1

## Accomplishments
- `FlightEntityMigrationPolicy.swift` created with inline `stringToMinutes` and `stringToDate` helpers
- All 8 time fields (blockTime, simTime, nightTime, p1Time, p1usTime, p2Time, instrumentTime, spInsTime) handled
- All 4 gate fields (outTime, inTime, scheduledDeparture, scheduledArrival) handled
- No `import SwiftData`, no `TimeStringConverter` reference (D-01 satisfied)
- dualTime left to model default (0) — no action needed in policy

## Task Commits

1. **Task 1: Write FlightEntityMigrationPolicy class with inline string conversion** - `9f1b49a` (feat)
2. **Task 2: Add FlightDataModelV2 in Xcode (UI-only)** - PENDING CHECKPOINT

## Files Created/Modified
- `Block-Time/Migration/FlightEntityMigrationPolicy.swift` — NSEntityMigrationPolicy subclass for V1→V2 migration; inline stringToMinutes (decimal-hour and HH:MM → Int16 minutes) and stringToDate (HH:MM UTC + flight date → Date?); no external dependencies

## Decisions Made
- Inline conversion logic (no TimeStringConverter reuse) per D-01 — migration policy is one-shot, self-contained
- Malformed/nil inputs: time fields → 0, gate fields → nil per D-06
- dualTime: no action in policy, V2 model default of 0 handles it

## Deviations from Plan

None — Task 1 executed exactly as specified. Comment text adjusted to remove `TimeStringConverter` mention (acceptance criterion: grep count = 0).

## Issues Encountered

None.

## CHECKPOINT STATUS

**Task 2 is a `checkpoint:human-action` gate.** The following Xcode UI operations are required and cannot be scripted:

- Add Model Version V2 inside `FlightDataModel.xcdatamodeld` (Editor > Add Model Version)
- Rename V1 model to `FlightDataModelV1.xcdatamodel`
- Set V2 as current version (green checkmark)
- Modify V2 FlightEntity: rename 12 String? fields to *Legacy variants, add 8 new Int16 scalar columns + dualTime + 4 Date? gate columns
- Create `FlightDataModelV1toV2.xcmappingmodel` (File > New > Mapping Model)
- Attach `FlightEntityMigrationPolicy` as Custom Policy in the entity mapping
- Verify build succeeds and generated `FlightEntity+CoreDataProperties.swift` has `blockTime: Int16`

See `.planning/phases/02-coredata-repository/02-02-PLAN.md` Task 2 `<how-to-verify>` for full step-by-step instructions.

## Next Phase Readiness

- `FlightEntityMigrationPolicy.swift` is ready for Xcode to pick up automatically (folder-based inclusion)
- After Xcode UI checkpoint completes, the V2 model and mapping model will be in place
- CoreDataFlightRepository (Plan 03) requires V2 entity codegen (`Int16` scalar properties) — depends on Task 2 being done

---
*Phase: 02-coredata-repository*
*Completed: 2026-05-16 (partial — Task 2 checkpoint pending)*
