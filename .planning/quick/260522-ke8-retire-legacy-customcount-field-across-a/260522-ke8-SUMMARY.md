---
phase: quick
plan: 260522-ke8
subsystem: custom-fields
tags: [cleanup, refactor, legacy-removal, custom-counters]
key-files:
  modified:
    - Block-Time/Views/Screens/Settings/SettingsView.swift
    - Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
    - Block-Time/Views/Screens/Settings/ImportMappingView.swift
    - Block-Time/Services/FileImportService.swift
    - Block-Time/Views/Screens/FrozenColumnSpreadsheetView.swift
    - Block-Time/Views/Screens/LogbookSpreadsheetView.swift
    - Block-Time/Views/Components/Dashboard/DashboardCardView.swift
    - Block-Time/Views/Components/Dashboard/DashboardEditSheet.swift
    - Block-Time/Views/Components/Dashboard/CustomCountCard.swift
    - Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
    - Block-Time/Models/FlightLogbook.swift
    - Block-Time/Services/FlightDatabaseService.swift
    - Block-Time/Services/MigrationImportService.swift
    - Block-Time/Views/Screens/FlightSectorEditScreen.swift
decisions:
  - "MigrationFlight.customCount DTO field retained so v1 backup JSON decodes without error"
  - "logCustomCount UserDefaults key and all persistence paths left untouched for migration safety"
  - "DashboardCardID.customCount enum case left in place — persisted configs may still reference it"
  - "FlightEntity.customCount Core Data attribute untouched — migration reads it directly via NSFetchRequest"
metrics:
  completed: 2026-05-22
---

# Quick 260522-ke8: Retire Legacy customCount Field Across App Summary

**One-liner:** Removed legacy single-counter customCount from FlightSector struct, UI, import/export, and all read/write paths while preserving Core Data attribute and migration code.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Strip legacy customCount UI from Settings and Add/Edit Flight | 3717c3d | SettingsView.swift, CrewOpsCard.swift |
| 2 | Update ImportMappingView and FileImportService import/export paths | ae0df22 | ImportMappingView.swift, FileImportService.swift |
| 3 | Switch spreadsheet and dashboard gates from logCustomCount to definitions.isEmpty | 319c088 | FrozenColumnSpreadsheetView.swift, LogbookSpreadsheetView.swift, DashboardCardView.swift, DashboardEditSheet.swift, CustomCountCard.swift |
| 4 | Remove customCount @Published and read/write paths from FlightTimeExtractorViewModel | dfd38d2 | FlightTimeExtractorViewModel.swift |
| 5 | Remove customCount writes from FlightDatabaseService and FlightSectorEditScreen | e8e1733 | FlightDatabaseService.swift, FlightSectorEditScreen.swift |
| 6 | Remove customCount from FlightSector struct and fold v1 migration into Counter1 | 6c557d2 | FlightLogbook.swift, MigrationImportService.swift |

## Files Touched Per Task

### Task 1
- **SettingsView.swift:** Removed ModernToggleRow "Use Custom Fields" and `if viewModel.logCustomCount` gate. InlineCustomFieldsView now always shown.
- **CrewOpsCard.swift:** Replaced `viewModel.logCustomCount` gate with `!CustomCounterService.shared.definitions.isEmpty`. Removed legacy FieldIntegerField and `legacyCounterMigratedToColumn1` UserDefaults check.

### Task 2
- **ImportMappingView.swift:** Removed `("Custom Count", ...)` from logbookFields array.
- **FileImportService.swift:**
  - Header auto-detect: `custom count` header now maps to `Counter1` instead of `Custom Count`.
  - Removed `customCountRaw` / `customCount` local variable parsing.
  - Removed `customCount:` argument from FlightSector init call in import path.
  - Removed `,Custom Count` from CSV export header string.
  - Removed `flight.customCount > 0 ? String(flight.customCount) : ""` from CSV row builder.

### Task 3
- **FrozenColumnSpreadsheetView.swift:** `counterDefinitions` and `configure()` now use `CustomCounterService.shared.definitions` directly; no UserDefaults logCustomCount gate.
- **LogbookSpreadsheetView.swift:** `activeCounterCount` initializer and `onReceive` use `CustomCounterService.shared.definitions.count` directly.
- **DashboardEditSheet.swift:** Removed `@AppStorage("logCustomCount")`. Pool filter uses `!CustomCounterService.shared.definitions.isEmpty`.
- **DashboardCardView.swift:** Removed `@AppStorage("logCustomCount")`. `.customCount` case gates on `!CustomCounterService.shared.definitions.isEmpty`.
- **CustomCountCard.swift:** Data source changed from `flight.customCount` to `Int(flight.counterEntries[1] ?? "") ?? 0`.

### Task 4
- **FlightTimeExtractorViewModel.swift:** Removed `var customCount: Int = 0` from DraftFlightData struct; removed `@Published var customCount = 0`; removed all 4 FlightSector init `customCount:` arguments; removed `customCount = sector.customCount` loader; removed hasUnsavedChanges clause; removed changes summary block; removed reset assignment; removed draft snapshot and draft→VM loader assignments.

### Task 5
- **FlightDatabaseService.swift:** Removed `flight.customCount = Int16(sector.customCount)` from saveFlight, updateFlight, bulkUpdateFlights, and importFlightsBatch. Removed `customCount: Int(entity.customCount)` from entity→sector converter. Removed `customCount: sector.customCount` from copy/duplicate path. Migration function (lines 1732–1754) left bit-for-bit unchanged.
- **FlightSectorEditScreen.swift:** Removed `customCount: sector.customCount,` from save path FlightSector init.

### Task 6
- **FlightLogbook.swift:** Removed `var customCount: Int` stored property; removed from CodingKeys; removed `customCount: Int = 0` init parameter and `self.customCount = max(0, customCount)` body assignment; removed `customCount = try c.decode(Int.self, forKey: .customCount)` from Codable init; removed `customCount: Int(entity.customCount)` from `init(from entity:)`.
- **MigrationImportService.swift:** Replaced `customCount: migrationFlight.customCount ?? 0` with `counterEntries:` closure that folds non-zero v1 customCount values into `[1: String(cc)]`. `MigrationFlight.customCount: Int?` DTO field (line 63) left unchanged.

## Compiler Issues

None encountered. All changes were surgical removals with no logic introduced.

## Migration Code Paths Confirmation

- `FlightDatabaseService.migrateLegacyCustomCounterToColumn1` (lines 1732–1754): unchanged. Reads `entity.customCount` directly via NSFetchRequest on `FlightEntity` — independent of `FlightSector` struct.
- `SplashScreenView` legacy migration block (lines 89–180): unchanged. Reads `UserDefaults.standard.bool(forKey: "logCustomCount")` directly.
- `MigrationFlight.customCount: Int?` DTO field: unchanged. v1 backup JSON still decodes successfully. Non-zero values now fold into `counterEntries[1]` during import.

## UserDefaults Keys Confirmation

No UserDefaults persistence keys were removed:
- `logCustomCount` — still defined in `UserDefaultsService.Keys.logCustomCount`, `LogbookSettings` DTO, and `UserDefaultsService` read/write methods.
- `customCountLabel` — still defined and read/written by `UserDefaultsService`.
- `cloud_logCustomCount`, `cloud_customCountLabel` — still defined in `CloudKitSettingsSyncService`.

## Deviations from Plan

None. Plan executed exactly as written.

## Known Stubs

None. All data sources are fully wired. CustomCountCard now reads Counter1 values from `counterEntries[1]`, which is where migrated and new data lives.

## Self-Check: PASSED

- All 6 task commits exist: 3717c3d, ae0df22, 319c088, dfd38d2, e8e1733, 6c557d2
- Final grep audits confirm zero unexpected `customCount` references outside allowed scopes
- Zero `logCustomCount` references outside UserDefaultsService, CloudKitSettingsSyncService, MigrationImportService, SplashScreenView, FlightTimeExtractorViewModel, ImportMappingView
- FlightSector struct compiles without `customCount` stored property
- Migration code paths verified untouched
