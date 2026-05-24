---
phase: quick-260523-qsz
plan: 01
subsystem: BulkEdit
tags: [bug-fix, combine, modification-tracking]
dependency_graph:
  requires: []
  provides: [isSpIns-modification-tracking]
  affects: [BulkEditSheet]
tech_stack:
  added: []
  patterns: [dedicated-publisher-sink]
key_files:
  modified:
    - Block-Time/ViewModels/BulkEditViewModel.swift
decisions:
  - Added standalone $isSpIns sink (additive) rather than altering CombineLatest3 to avoid side effects
metrics:
  duration: "< 5 minutes"
  completed: 2026-05-23
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase quick-260523-qsz Plan 01: Fix Save Button Not Illuminating for INS Toggle Summary

**One-liner:** Added dedicated `$isSpIns` Combine sink so INS toggle immediately illuminates Save button in BulkEditSheet.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add dedicated $isSpIns sink in setupModificationTracking() | 269942e | BulkEditViewModel.swift |

## What Was Done

Added a 5-line `$isSpIns` sink in `BulkEditViewModel.setupModificationTracking()` between the existing `$remarks` sink and the `CombineLatest3($flightDate, $isSpIns, $spInsTime)` block.

**Root cause:** The INS button action mutates `isPositioning`, `isSimulator`, then `isSpIns` sequentially. The `CombineLatest4($scheduledArrival, $isPilotFlying, $isPositioning, $isSimulator)` fires `checkForModifications()` before `isSpIns` updates, producing a stale read. The `CombineLatest3` containing `$isSpIns` fires after, but its combined signal wasn't guaranteed to re-evaluate the Save state correctly in all cases.

**Fix:** A dedicated `$isSpIns` sink guarantees `checkForModifications()` fires whenever `isSpIns` changes, regardless of mutation ordering — same pattern already used for `$blockTimeRole` and `$remarks`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- File modified: Block-Time/ViewModels/BulkEditViewModel.swift — FOUND
- Commit 269942e — FOUND
- `$isSpIns` dedicated sink calling `checkForModifications()` — FOUND (line 440)
- `CombineLatest3($flightDate, $isSpIns, $spInsTime)` unchanged — FOUND (line 447)
