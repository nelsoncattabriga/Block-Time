---
phase: quick-260519-gta
plan: 01
subsystem: ui
tags: [swiftui, ipad, split-view, state, binding]

requires: []
provides:
  - UUID-based refresh trigger on FlightsSplitView wired to FlightsListContent.loadFlights()
affects: [FlightsSplitView, FlightsListContent]

tech-stack:
  added: []
  patterns:
    - "UUID refresh trigger pattern: mutate UUID @State to force child view reload via @Binding + .onChange"

key-files:
  created: []
  modified:
    - Block-Time/Views/Screens/FlightsSplitView.swift

key-decisions:
  - "Keep existing onReceive(.flightDataChanged) in place; UUID trigger is additive, not a replacement"
  - "Place listRefreshTrigger = UUID() as last statement inside the successful save branch only (not the else/failed branch)"

requirements-completed: [GTA-01]

duration: 8min
completed: 2026-05-19
---

# Quick Task 260519-gta: Fix iPad Split View Flight List Stale Row Summary

**UUID-based refresh trigger wired from save alert to FlightsListContent.loadFlights() via @Binding + .onChange, bypassing flaky notification path**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-19T02:46:00Z
- **Completed:** 2026-05-19T02:54:18Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added `@State private var listRefreshTrigger: UUID` to `FlightsSplitView`
- Passed `refreshTrigger: $listRefreshTrigger` to `FlightsListContent` call site
- Added `@Binding var refreshTrigger: UUID` property to `FlightsListContent` (after `isSelectMode`, before `onFlightSelected`)
- Added `.onChange(of: refreshTrigger) { _, _ in Task { await loadFlights() } }` after existing `onReceive(.flightDataChanged)` handler
- Set `listRefreshTrigger = UUID()` as final statement inside the `if viewModel.updateExistingFlight()` success block

## Task Commits

1. **Task 1: Add UUID refresh trigger and wire save alert to force list reload** - `9b3501f` (fix)

**Plan metadata:** (included in this commit)

## Files Created/Modified
- `Block-Time/Views/Screens/FlightsSplitView.swift` - Five targeted edits: new state, new binding, new onChange, new call-site arg, trigger mutation in save alert

## Decisions Made
- Kept `onReceive(.flightDataChanged)` untouched — it serves other callers (delete, duplicate, etc.) that do not go through the save alert path
- Used two-argument closure form `.onChange(of:) { _, _ in }` as required by Swift 6

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Fix is ready for local build and iPad verification
- Manual test: edit a flight on iPad, tap another row, tap "Save" in the alert — edited row in left list must update immediately without navigating away

## Self-Check: PASSED
- `Block-Time/Views/Screens/FlightsSplitView.swift` - FOUND and modified
- Commit `9b3501f` - FOUND in git log

---
*Phase: quick-260519-gta*
*Completed: 2026-05-19*
