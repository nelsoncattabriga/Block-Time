---
phase: quick-260601-sx6
plan: 01
subsystem: flights-undo
tags: [undo, ux, core-data, flights]
dependency_graph:
  requires: [260601-rdn]
  provides: [human-readable-undo-descriptions]
  affects: [FlightsView, FlightsSplitView, FlightTimeExtractorViewModel]
tech_stack:
  added: []
  patterns: [description-stack-in-lockstep-with-undo-count]
key_files:
  created: []
  modified:
    - Block-Time/Services/FlightDatabaseService.swift
    - Block-Time/Views/Screens/FlightsView.swift
    - Block-Time/Views/Screens/FlightsSplitView.swift
    - Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
decisions:
  - "Description stack uses simple [String] array in lockstep with undoableChangeCount — no separate type needed"
  - "shortDayFormatter is static to avoid allocating on each call inside performAndWait"
  - "lineLimit(1).minimumScaleFactor(0.7) applied per project text-overflow rule"
metrics:
  duration: "~15 minutes"
  completed: "2026-06-01"
  tasks_completed: 2
  files_modified: 4
---

# Phase quick-260601-sx6 Plan 01: Add Human-Readable Undo Descriptions Summary

**One-liner:** Undo bar now shows "Deleted SYD-MEL · 14 May" instead of "1 change to undo" using a description stack kept in lockstep with undoableChangeCount.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add undoDescriptions stack + optional params to FlightDatabaseService | 5317684 | FlightDatabaseService.swift |
| 2 | Show description in both undo bars; pass actionDescription at ViewModel call sites | f1c599a | FlightsView.swift, FlightsSplitView.swift, FlightTimeExtractorViewModel.swift |

## What Was Built

### FlightDatabaseService.swift
- `private var undoDescriptions: [String] = []` — parallel stack to `undoableChangeCount`
- `var lastUndoDescription: String? { undoDescriptions.last }` — read by views via `refreshUndoState()`
- `private static let shortDayFormatter` — "d MMM" formatter (static, allocated once)
- `shortDay(from:)` — parses "dd/MM/yyyy" via existing `dateFormatter`, formats as "14 May"
- `undoDescription(verb:for:includeDate:)` — builds "Deleted SYD-MEL · 14 May" or "Edited SYD-MEL"
- All 6 CRUD methods gain `actionDescription: String? = nil` — callers without the param use auto-fallback
- `undoableChangeCount += 1` and `undoDescriptions.append(...)` always occur together
- `undoLastChange()` pops the description after a successful undo

### FlightsView.swift + FlightsSplitView.swift (identical changes)
- `@State private var undoDescription: String? = nil`
- `refreshUndoState()` now also reads `FlightDatabaseService.shared.lastUndoDescription`
- Undo bar primary label: `Text(undoDescription ?? "\(undoCount) \(undoCount == 1 ? "change" : "changes") to undo")`
- `.lineLimit(1).minimumScaleFactor(0.7)` added per project text-overflow rule

### FlightTimeExtractorViewModel.swift
- 5 call sites updated to pass `actionDescription:` with route string (e.g. "Added SYD-MEL")
- `duplicateFlights` internal `saveFlight(copy)` left unchanged — default nil produces auto-fallback

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED
