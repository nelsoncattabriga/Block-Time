---
phase: quick-260524-f6d
plan: 01
subsystem: pdf-export
tags: [pdf, ins, content-mode, filter]
dependency_graph:
  requires: []
  provides: [PDFContentMode, matchesContentMode, buildSlots-no-filter]
  affects: [LogbookPDFExportView, LogbookPDFPaginator]
tech_stack:
  added: []
  patterns: [AppStorage-rawValue-enum, content-predicate-helper]
key_files:
  modified:
    - Block-Time/Views/Screens/Settings/LogbookPDFExportView.swift
    - Block-Time/Services/LogbookPDFTotals.swift
decisions:
  - loadFlights() date-bound filter intentionally left as broad filter (allFlights predicate) so date picker range covers full span regardless of content mode
  - buildSlots() now trusts caller to pre-filter; redundant double-filter removed
metrics:
  duration: ~8min
  completed: 2026-05-24
  tasks_completed: 2
  files_modified: 2
---

# Phase quick-260524-f6d Plan 01: Add PDFContentMode (allFlights / includeINS / instructorHoursOnly) Summary

**One-liner:** 3-way PDF content picker with INS-aware filtering and paginator double-filter fix.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add PDFContentMode enum, @AppStorage, Content picker, matchesContentMode | fcdad63 | LogbookPDFExportView.swift |
| 2 | Remove redundant filter from buildSlots | 47f3684 | LogbookPDFTotals.swift |

## What Was Built

**LogbookPDFExportView.swift:**
- `PDFContentMode` enum with 3 cases: `allFlights`, `includeINSSessions`, `instructorHoursOnly`
- `@AppStorage("logbookPDFContentMode")` persists selection across launches
- `contentMode` computed accessor with `.allFlights` fallback
- `matchesContentMode(_:)` helper — single predicate definition used at both call-sites
- Content segmented picker rendered between Date Range and Date Format sections, styled with matching brown card
- `.onChange(of: contentModeRaw)` triggers `updateFlightCount()` for reactive count update
- `updateFlightCount()` base fetch uses `matchesContentMode`
- `generatePDF()` base fetch uses `matchesContentMode`
- `loadFlights()` date-bound filter left on broad `allFlights` predicate (intentional — needed to compute earliest/latest date for date pickers regardless of content mode)

**LogbookPDFTotals.swift:**
- Removed `.filter { !$0.isPositioning && ($0.blockTimeValue > 0 || $0.simTimeValue > 0) }` from `buildSlots(from:)`
- `buildSlots` now does `flights.map { .flight($0) }` — no filtering
- Doc comment updated: "caller applies content/date filters"
- INS-only sessions passed by the caller now survive into the rendered PDF

## Decisions Made

- `loadFlights()` date-bound filter: kept as broad `!isPositioning && (block>0 || sim>0)` because it drives the date picker's `earliestDate`/`latestDate` bounds and must cover the full flight history regardless of content mode. `updateFlightCount()` (called at the end) applies the content filter for the displayed count.
- `buildSlots()` double-filter: removed entirely. The caller already applies `matchesContentMode` before calling `buildSlots`, so a second filter was silently stripping INS-only sessions.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: Block-Time/Views/Screens/Settings/LogbookPDFExportView.swift
- FOUND: Block-Time/Services/LogbookPDFTotals.swift
- FOUND commit fcdad63 (Task 1)
- FOUND commit 47f3684 (Task 2)
