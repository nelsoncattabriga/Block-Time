---
phase: quick
plan: 260601-etg
subsystem: crew-names
tags: [userdefaults, cloudkit, viewmodel, crew, settings, migration]
key-files:
  modified:
    - Block-Time/Services/UserDefaultsService.swift
    - Block-Time/Services/CloudKitSettingsSyncService.swift
    - Block-Time/Services/MigrationImportService.swift
    - Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
    - Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
    - Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift
decisions:
  - "Legacy savedCaptainNames/savedCoPilotNames/savedSONames keys kept in UserDefaults and CloudKit for backward compat — not cleared"
  - "Migration guarded by crewNamesMigrated UserDefaults bool so it runs exactly once per device"
  - "Old add/remove methods (addCaptainName etc.) kept as delegates — callers unchanged"
metrics:
  duration: "8 minutes"
  completed: "2026-06-01T00:45:59Z"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 6
---

# Quick Task 260601-etg: Merge Crew Name Lists into Single savedCrewNames Summary

**One-liner:** Unified three role-scoped crew name lists (captain/FO/SO) into one savedCrewNames list shared across all crew autocomplete fields.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add savedCrewNames to UserDefaultsService with one-time migration | 51370b7 | UserDefaultsService.swift |
| 2 | Update CloudKitSettingsSyncService and MigrationImportService | 6a81319 | CloudKitSettingsSyncService.swift, MigrationImportService.swift |
| 3 | Update ViewModel and Views to use savedCrewNames | aa6015f | FlightTimeExtractorViewModel.swift, CrewOpsCard.swift, BulkEditSheet.swift |

## What Was Built

- `AppSettings.savedCrewNames: [String]` — new unified field in AppSettings
- `UserDefaultsService.migrateCrewNamesIfNeeded()` — one-time migration that unions all three legacy lists into `savedCrewNames`, guarded by `crewNamesMigrated` bool in UserDefaults
- `UserDefaultsService.addCrewName()` / `removeCrewName()` — new unified methods
- Legacy `addCaptainName/addCoPilotName/addSOName` and `removeCaptainName/removeCoPilotName/removeSOName` kept as delegates — they still update their legacy keys (for CloudKit backward compat) then delegate to the unified methods
- `FlightTimeExtractorViewModel.savedCrewNames: [String]` replaces the three separate `@Published` arrays
- All 8 crew autocomplete fields (4 in CrewOpsCard, 4 in BulkEditSheet) pass `savedNames: viewModel.savedCrewNames`
- CloudKit KVS syncs `cloud_savedCrewNames` in both directions; legacy keys still synced
- `MigrationSettings.savedCrewNames` added to backup restore struct

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- UserDefaultsService.swift modified: FOUND
- CloudKitSettingsSyncService.swift modified: FOUND
- MigrationImportService.swift modified: FOUND
- FlightTimeExtractorViewModel.swift modified: FOUND
- CrewOpsCard.swift modified: FOUND
- BulkEditSheet.swift modified: FOUND
- Commits 51370b7, 6a81319, aa6015f: FOUND
- Zero remaining references to savedCaptainNames/savedCoPilotNames/savedSONames in view/viewmodel files: CONFIRMED
