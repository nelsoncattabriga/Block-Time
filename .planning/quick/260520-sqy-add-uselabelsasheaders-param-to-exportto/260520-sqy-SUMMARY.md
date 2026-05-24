---
phase: quick
plan: 260520-sqy
subsystem: csv-export
tags: [csv, custom-fields, export]
key-files:
  modified:
    - Block-Time/Services/FileImportService.swift
    - Block-Time/Views/Screens/Settings/ExportLogbookView.swift
decisions:
  - Default false on useLabelsAsHeaders preserves AutomaticBackupService backward compat without any call-site change
metrics:
  duration: "< 5 minutes"
  completed: 2026-05-20
  tasks: 2
  files: 2
---

# Quick 260520-sqy: Add useLabelsAsHeaders param to exportToCSV — Summary

**One-liner:** User-facing CSV export now writes `def.label` column headers; backup export keeps stable `Counter<N>` keys.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add useLabelsAsHeaders parameter | 3f56845 | FileImportService.swift |
| 2 | Update ExportLogbookView call site | 7bf55b6 | ExportLogbookView.swift |

## What Changed

**FileImportService.swift** — `exportToCSV(flights:definitions:)` signature now includes `useLabelsAsHeaders: Bool = false`. The header loop branches: `def.label` when true, `"Counter\(def.columnIndex)"` when false.

**ExportLogbookView.swift** — `performExport()` now fetches definitions from `CustomCounterService.shared.definitions` and calls the explicit-definitions overload with `useLabelsAsHeaders: true`.

**AutomaticBackupService.swift** — unchanged. Its call passes `definitions` explicitly but no `useLabelsAsHeaders`, so it gets the default `false` and continues producing `Counter<N>` headers.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `FileImportService.swift` modified: confirmed
- `ExportLogbookView.swift` modified: confirmed
- `AutomaticBackupService.swift` untouched: confirmed (grep returns no match)
- Both commits exist: 3f56845, 7bf55b6
