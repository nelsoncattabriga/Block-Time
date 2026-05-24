---
phase: quick
plan: 260522-lvy
subsystem: import
tags: [import, custom-fields, ui-fix]
dependency_graph:
  requires: [260520-t6j]
  provides: []
  affects: [ImportMappingView]
tech_stack:
  added: []
  patterns: [ForEach-with-conditional-guard]
key_files:
  modified:
    - Block-Time/Views/Screens/Settings/ImportMappingView.swift
decisions:
  - "Used if-inside-ForEach pattern over .filter on Binding to preserve write-back correctness"
metrics:
  duration: "5m"
  completed: 2026-05-22
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Quick 260522-lvy: Fix Duplicate Counter1-10 Rows in Import Summary

**One-liner:** Added `isCustomCounterField` guard to exclude Counter1–10 from the generic Field Mapping ForEach so they render only in the Custom Fields section.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Filter Counter\d+ entries from generic Field Mapping ForEach | ddb7982 |

## What Was Done

`ImportMappingView.swift` had a ForEach over all `fieldMappings` in the generic "Field Mapping" section, which rendered Counter1–Counter10 entries there AND again in the dedicated "Custom Fields" section — causing duplicate rows.

**Fix:** Added a private helper `isCustomCounterField(_:)` that returns `true` for logbookField values matching `Counter` + one-or-more digits. Wrapped the `FieldMappingRow` inside the generic ForEach in `if !isCustomCounterField(mapping.logbookField)`.

The `if`-inside-ForEach pattern was chosen intentionally (not `.filter` on the Binding) because filtering a `Binding<[FieldMapping]>` with `.filter` breaks write-back. The ForEach still iterates the full collection; only the rendering is suppressed for counter fields.

`createInitialMappings` and the "Custom Fields" Section are byte-for-byte unchanged. The `fieldMappings` array still holds all Counter1–10 entries so the "Custom Fields" section can look them up by `logbookField`.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `isCustomCounterField` helper present at line 520: FOUND
- Commit ddb7982: FOUND
- `createInitialMappings` unchanged: VERIFIED (grep shows no modification)
- "Custom Fields" section unchanged: VERIFIED (grep shows no modification)
