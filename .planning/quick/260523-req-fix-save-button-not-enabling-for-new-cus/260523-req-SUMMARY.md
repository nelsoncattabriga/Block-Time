---
phase: quick-260523-req
plan: 01
subsystem: BulkEdit
tags: [bulk-edit, custom-fields, save-button, bug-fix]
dependency_graph:
  requires: []
  provides: [save-button-enables-for-new-custom-fields]
  affects: [BulkEditSheet]
tech_stack:
  added: []
  patterns: []
key_files:
  modified:
    - Block-Time/ViewModels/BulkEditViewModel.swift
decisions:
  - Treat absent initialStates key as baseline .notEdited; only non-empty .value enables Save for new fields
  - Leave hasFieldBeenModified unchanged to preserve existing caller semantics
metrics:
  duration: ~5 minutes
  completed: 2026-05-23
  tasks_completed: 1
  files_modified: 1
---

# Phase quick-260523-req Plan 01: Fix Save Button Not Enabling for New Custom Fields Summary

**One-liner:** Patched `checkForModifications()` to treat absent `initialStates` key as baseline, enabling Save for custom fields added after BulkEditSheet init.

## What Was Built

Single targeted change inside the `customCounterStates.contains(where:)` closure in `BulkEditViewModel.checkForModifications()`.

**Before:**
```swift
customCounterStates.contains(where: { (col, state) in
    hasFieldBeenModified(state, key: "customCounter_\(col)")
})
```

`hasFieldBeenModified` returns `false` when the key is missing from `initialStates`, so any custom field definition added after sheet init was always treated as "unchanged" — Save never enabled.

**After:**
```swift
customCounterStates.contains(where: { (col, state) in
    let key = "customCounter_\(col)"
    if initialStates[key] != nil {
        return hasFieldBeenModified(state, key: key)
    }
    // New definition added after sheet init — any non-empty value is a modification
    if case .value(let v) = state { return !v.isEmpty }
    return false
})
```

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Patch checkForModifications for missing initialStates key | 9330e6d | Block-Time/ViewModels/BulkEditViewModel.swift |

## Verification Required (Checkpoint)

Manual build-and-test required:
1. Open BulkEditSheet for one or more flights.
2. Add a new custom field definition while sheet is open (or open sheet on flights with a field added after ViewModel snapshot).
3. Enter a non-empty value into the new field row → Save button should enable.
4. Clear the value → Save should disable.
5. Edit an existing custom field → Save still enables (regression check).
6. Edit other fields (INS toggle, remarks, etc.) → Save still enables (regression check).

## Deviations from Plan

**Merge required before execution:** Worktree branch was branched off before recent quick-task commits (260523-qbo, 260523-qsz, 260523-r6m) which added `customCounterStates` to `BulkEditViewModel`. Fast-forward merge of `main` into the worktree branch was performed before making the targeted edit.

No other deviations — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- File modified: Block-Time/ViewModels/BulkEditViewModel.swift — contains `initialStates[key] != nil` check at line 507.
- Commit 9330e6d exists in worktree branch.
- `hasFieldBeenModified` body unchanged (line 516+).
