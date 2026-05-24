---
quick_id: 260524-fyn
date: 2026-05-24
status: complete
commit: a963f31
files_modified:
  - Block-Time/Views/Screens/Settings/LogbookPDFExportView.swift
---

# Quick Task 260524-fyn: Rename PDFContentMode labels to Standard / + SIM INS / INS Record

**One-liner:** Renamed three PDFContentMode rawValues and bumped AppStorage key to avoid stale persisted values.

## Changes

### PDFContentMode rawValue renames

| Case | Before | After |
|------|--------|-------|
| `allFlights` | "All Flights" | "Standard" |
| `includeINSSessions` | "Flights + INS" | "+ SIM INS" |
| `instructorHoursOnly` | "Instructor Hours Only" | "INS Record" |

### @AppStorage key bump

The Picker binds `contentModeRaw` directly to rawValue strings via `.tag(mode.rawValue)`. Any user who had a value persisted under `"logbookPDFContentMode"` would have seen an invalid stored string after the rename, causing `PDFContentMode(rawValue:)` to return `nil` and fall back to `.allFlights` silently.

Key changed from `"logbookPDFContentMode"` to `"logbookPDFContentMode2"` to force a clean default for all users.

## Self-Check: PASSED

- File modified: `Block-Time/Views/Screens/Settings/LogbookPDFExportView.swift` — confirmed
- Commit `a963f31` exists — confirmed
- No stubs introduced
