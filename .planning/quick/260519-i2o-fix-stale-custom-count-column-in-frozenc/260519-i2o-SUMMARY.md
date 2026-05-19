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

| Task | Commit | Description |
|------|--------|-------------|
| 1    | 9cb2af0 | fix(quick-260519-i2o): remove legacy customCount column from spreadsheet view |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Verification Checklist

- [x] `useLegacyColumn` — not present in file
- [x] `"Custom Count"` string literal — not present in file
- [x] `customCount` — not present in file (column display only; field still exists in FlightSector/Core Data)
- [x] `useCustomCount` — present (both in container and RightCell)
- [x] `max(counterCount, 1)` — not present in file

## Self-Check: PASSED

- File exists: CONFIRMED
- Commit 9cb2af0 exists: CONFIRMED
- All grep checks: PASSED (5/5)

## Awaiting

Task 2 is a `checkpoint:human-verify` — build locally and test the four scenarios listed in the plan.
