---
phase: quick-260608-ptl
plan: 01
subsystem: roster-import
tags: [roster, import, stale-flights, core-data, swift6]
key-files:
  modified:
    - Block-Time/Services/UnifiedRosterParser.swift
    - Block-Time/Services/PlannedFlightService.swift
    - Block-Time/Views/Screens/Settings/UnifiedRosterImportView.swift
    - Block-Time/Views/Screens/Settings/UnifiedRosterPreviewView.swift
decisions:
  - stale detection uses normalised flight number + ICAO route + UTC calendar day as match key
  - staleFlights array on ImportResult always empty (stale detection is caller-driven, not inside importFlights)
  - deleteStaleFlights fetches by objectID inside context.perform to avoid Sendable violations
metrics:
  duration: "~25 minutes"
  completed: "2026-06-08"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 4
---

# Quick Task 260608-ptl: Implement Stale Roster Flight Removal

**One-liner:** Stale roster detection with interstitial review sheet — unflown out-of-roster flights shown for selective removal between Preview and Result screens.

## What Was Built

### Task 1 — UnifiedParseResult bid-period date range
Added `periodStartDate: Date?` and `periodEndDate: Date?` to `UnifiedParseResult`. Both `SHRosterParser.convertToUnified` and `LHRosterParser.convertToUnified` populate them via `flights.map(\.date).min()/.max()`. The `UnifiedRosterPreviewView` preview initialiser was also updated to include the new fields (deviation: fix required to keep the preview compiling — Rule 1).

### Task 2 — PlannedFlightService stale detection and deletion
- `ImportResult` gains `staleFlights: [FlightEntity]`. `importFlights` always passes `staleFlights: []`; detection is caller-driven.
- `findStaleFlights(periodStart:periodEnd:rosterFlights:)`: fetches all unflown `FlightEntity` rows in the UTC day window, builds a roster key set (`normalisedFlightNum|depICAO|arrICAO|utcDay`), returns flights absent from that set. Flown flights (`isFlown`) are always excluded.
- `deleteStaleFlights(_ flights:)`: deletes given entities via `context.perform` + `withCheckedContinuation`, saves context, returns count.

### Task 3 — Stale-review interstitial sheet
- `SheetType.staleReview(staleFlights:importResult:)` added to `UnifiedRosterImportView`.
- `importSelectedFlights` now accepts `parseResult: UnifiedParseResult` and calls `findStaleFlights` after import. If stale is empty -> go straight to `.result`. If stale is non-empty -> show `.staleReview`.
- `StaleFlightReviewView` (file-private): NavigationStack, explanation header with `ImportStatCard`, scrollable list of stale flights each with checkmark toggle (all selected/red by default), bottom Continue/Skip bar.
- Continue deletes only selected entities then shows Result. Skip shows Result immediately, deleting nothing.
- `import CoreData` added to `UnifiedRosterImportView.swift`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated UnifiedRosterPreviewView preview to include new UnifiedParseResult fields**
- **Found during:** Task 1
- **Issue:** `UnifiedRosterPreviewView`'s `#Preview` block constructed `UnifiedParseResult` without the two new fields, which would cause a compile error.
- **Fix:** Added `periodStartDate` and `periodEndDate` to the preview initialiser.
- **Files modified:** `Block-Time/Views/Screens/Settings/UnifiedRosterPreviewView.swift`
- **Commit:** 1f9be74

**2. [Rule 2 - Missing import] Added `import CoreData` to UnifiedRosterImportView.swift**
- **Found during:** Task 3
- **Issue:** `FlightEntity` (Core Data class) referenced in `SheetType` and `StaleFlightReviewView` but `CoreData` not imported.
- **Fix:** Added `import CoreData` at top of file, consistent with other views that use `FlightEntity`.
- **Files modified:** `Block-Time/Views/Screens/Settings/UnifiedRosterImportView.swift`
- **Commit:** 97ae817

## Commits

| Hash | Message |
|------|---------|
| 1f9be74 | feat(260608-ptl): add periodStartDate/periodEndDate to UnifiedParseResult |
| 12e662b | feat(260608-ptl): add findStaleFlights, deleteStaleFlights, and staleFlights to ImportResult |
| 97ae817 | feat(260608-ptl): insert stale-review interstitial sheet in UnifiedRosterImportView |

## Known Stubs

None — all data is wired to live Core Data. The stale detection operates on real `FlightEntity` fetches.

## Self-Check: PASSED

- `UnifiedRosterParser.swift` — `periodStartDate` at lines 52, 178, 232: confirmed present
- `PlannedFlightService.swift` — `findStaleFlights` at line 622, `deleteStaleFlights` at line 713: confirmed present
- `UnifiedRosterImportView.swift` — `case staleReview` at line 35, `StaleFlightReviewView` at line 733: confirmed present
- All 3 feature commits exist in git log
