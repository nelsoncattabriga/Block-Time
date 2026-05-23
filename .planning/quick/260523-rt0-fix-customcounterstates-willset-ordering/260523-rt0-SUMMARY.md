---
phase: quick-260523-rt0
plan: 01
subsystem: BulkEdit
tags: [bug-fix, modification-tracking, combine, willset]
key-files:
  modified:
    - Block-Time/ViewModels/BulkEditViewModel.swift
decisions:
  - Use closure parameter (newStates) instead of self.customCounterStates to avoid @Published willSet timing issue
metrics:
  duration: "< 5 min"
  completed: 2026-05-23
  tasks: 1
  files: 1
---

# Quick 260523-rt0: Fix customCounterStates willSet ordering in BulkEditViewModel

**One-liner:** Fixed Save button not enabling on custom counter keystrokes by passing `newStates` closure parameter instead of reading stale `self.customCounterStates` in the Combine sink.

## What Was Done

Single task — two edits to `BulkEditViewModel.swift`:

1. `$customCounterStates` sink: added `.receive(on: RunLoop.main)` and changed the closure from `_ in self?.checkForModifications()` to `newStates in self?.checkForModifications(customStates: newStates)`.

2. `checkForModifications()`: added optional parameter `customStates: [Int: FieldState<String>]? = nil`, computed `let counters = customStates ?? customCounterStates` at the top, and replaced `customCounterStates.contains(where:` with `counters.contains(where:` in the boolean chain. All other call sites use the default `nil` and are unaffected.

## Root Cause

`@Published` fires its publisher via `willSet` — before the property is updated. Reading `self.customCounterStates` inside the sink therefore returned the previous value, making modification detection always compare old-to-old and never enabling Save.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- File exists: Block-Time/ViewModels/BulkEditViewModel.swift — FOUND
- Commit 3f1741d — FOUND
