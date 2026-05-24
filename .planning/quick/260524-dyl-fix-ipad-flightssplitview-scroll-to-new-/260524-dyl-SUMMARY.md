---
phase: quick-260524-dyl
plan: 01
subsystem: FlightsSplitView / iPad list scroll
tags: [scroll, ipad, split-view, ux]
dependency_graph:
  requires: []
  provides: [scroll-to-new-flight-on-ipad]
  affects: [FlightsSplitView]
tech_stack:
  added: []
  patterns: [NotificationCenter flag pattern for deferred scroll]
key_files:
  modified:
    - Block-Time/Views/Screens/FlightsSplitView.swift
decisions:
  - Use a boolean flag (pendingScrollToLatest) set by .flightAdded notification, consumed in the next onChange cycle, to avoid racing against data reload
metrics:
  duration: 3 minutes
  completed: 2026-05-24
  tasks_completed: 1
  files_modified: 1
---

# Quick Task 260524-dyl: Fix iPad FlightsSplitView Scroll to New Flight — Summary

**One-liner:** Added `pendingScrollToLatest` flag so iPad list scrolls to `sectors.first` after `.flightAdded` notification fires.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add pendingScrollToLatest flag and wire into flightAdded + onChange | 9d04bc8 | FlightsSplitView.swift |

## Changes Made

Three surgical edits inside `FlightsListContent` in `FlightsSplitView.swift`:

1. Added `@State private var pendingScrollToLatest = false` after `hasScrolledOnLaunch`.
2. Updated `.onReceive(.flightAdded)` to also set `pendingScrollToLatest = true`.
3. Updated `.onChange(of: filteredFlightSectors)` to check `pendingScrollToLatest` first: if set, scrolls to `sectors.first?.id` and returns early; otherwise falls through to existing launch-scroll logic unchanged.

No other structs, functions, or files were touched.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `Block-Time/Views/Screens/FlightsSplitView.swift` — modified and committed
- Commit `9d04bc8` — present in git log
