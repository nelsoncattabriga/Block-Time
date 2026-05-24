---
id: 260523-urt
type: quick
date: 2026-05-23
duration: ~2 minutes
tasks_completed: 1
tasks_total: 1
files_modified: 1
commits:
  - 2e82238
tags: [import, custom-fields, display]
---

# Quick Task 260523-urt: Show Custom Counter Fields by User-Defined Label

## One-liner
ImportMappingView now shows user-defined field labels (e.g. "Approaches") instead of raw keys ("Counter1") at both display sites.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Use logbookFieldDescription for display in mapping row header and PreviewRowView | 2e82238 | ImportMappingView.swift |

## Changes Made

Two targeted display-only substitutions in `ImportMappingView.swift`:

1. **Line ~888 — Mapping row header:** `Text(mapping.logbookField)` → `Text(mapping.logbookFieldDescription.isEmpty ? mapping.logbookField : mapping.logbookFieldDescription)`
2. **Line ~2012 — PreviewRowView label column:** `Text(mapping.logbookField + ":")` → `Text((mapping.logbookFieldDescription.isEmpty ? mapping.logbookField : mapping.logbookFieldDescription) + ":")`

All other uses of `mapping.logbookField` (logic, matching, profile storage) remain unchanged.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] Both grep matches confirmed (output: 2)
- [x] Commit 2e82238 exists
- [x] No other logbookField display sites modified

## Self-Check: PASSED
