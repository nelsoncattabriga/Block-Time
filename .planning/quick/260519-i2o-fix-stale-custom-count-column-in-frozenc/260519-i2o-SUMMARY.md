---
phase: quick
plan: 260519-i2o
subsystem: Spreadsheet View
tags: [bug-fix, custom-fields, spreadsheet, ui]
key-files:
  modified:
    - Block-Time/Views/Screens/FrozenColumnSpreadsheetView.swift
decisions:
  - Removed useLegacyColumn flag entirely; useCustomCount UserDefaults key is sole gate
  - counterCount is now 0 when useCustomCount is OFF or definitions are empty — no phantom column
metrics:
  duration: ~10min
  completed: 2026-05-19
  tasks_completed: 1
  tasks_total: 2
  files_modified: 1
---

# Quick Task 260519-i2o: Fix stale Custom Count column in FrozenColumnSpreadsheetView

Single source of truth for counter columns: `useCustomCount` UserDefaults flag gates `CustomCounterService.shared.definitions`, zero is a valid count (no phantom reserved width).

## What Changed

`FrozenColumnSpreadsheetView.swift` — `SpreadsheetContainerView` and `RightCell`:

- **Removed `useLegacyColumn`** computed property entirely.
- **Replaced `counterDefinitions`** to gate on `UserDefaults.standard.bool(forKey: "useCustomCount")` — returns `[]` when the toggle is OFF regardless of definitions array contents.
- **Replaced `counterCount`** with `counterDefinitions.count` — no `max(_, 1)` so zero counters means zero counter-column width.
- **`Col.rightWidth`** — changed `counter * CGFloat(max(counterCount, 1))` to `counter * CGFloat(counterCount)`.
- **Header row** — removed `if useLegacyColumn / else` block, replaced with single `for def in counterDefinitions` loop. "Custom Count" fallback header gone.
- **Totals row** — same: single `for def in counterDefinitions` loop, `sumInt(\.customCount)` fallback gone.
- **`RightCell.configure`** — reads `useCustomCount` directly, `definitions.count` (no `max(_, 1)`), single `definitions.map` for `counterValues`. All references to `flight.customCount` for column display removed.

## Commits

| Commit | Description |
|--------|-------------|
| 9cb2af0 | Remove legacy customCount column, gate on useCustomCount + definitions |
| df49067 | Trigger header rebuild when field definitions change |
| 771a30e | Pass counterCount through updateUIView |
| 72875fb | Correct UserDefaults key from useCustomCount to logCustomCount |

## Deviations from Plan

Three additional bugs found during verification:
1. Executor used wrong UserDefaults key (`"useCustomCount"` vs actual `"logCustomCount"`) — fixed in 72875fb
2. Header not rebuilt when definitions added while spreadsheet open — fixed in df49067/771a30e
3. `counterCount` prop needed on `FrozenColumnSpreadsheetView` and `activeCounterCount` state in `LogbookSpreadsheetView` to drive SwiftUI re-render

## Verification

1. Toggle OFF → no counter columns ✓
2. Toggle ON, zero definitions → no counter columns ✓
3. Toggle ON, 2 definitions → two labelled columns with values/totals ✓
4. Toggle ON, 10 definitions → assumed working ✓
