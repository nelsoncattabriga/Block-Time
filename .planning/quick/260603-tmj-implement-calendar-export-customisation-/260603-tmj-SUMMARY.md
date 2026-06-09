---
phase: quick-260603-tmj
plan: 01
subsystem: calendar-export
tags: [calendar, export, settings, ics, customisation]
dependency_graph:
  requires: []
  provides: [CalendarExportSettings, CalendarFormatSheet, settings-driven ICS generation]
  affects: [CalendarExportService, CalendarExportView]
tech_stack:
  added: []
  patterns: ["@Observable UserDefaults JSON persistence", "OrderedComponent Codable struct", "@Bindable settings binding", "onMove drag reorder in List"]
key_files:
  created:
    - Block-Time/Services/CalendarExportSettings.swift
    - Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift
  modified:
    - Block-Time/Services/CalendarExportService.swift
    - Block-Time/Views/Screens/Settings/CalendarExportView.swift
decisions:
  - "CalendarExportSettings uses plain stored properties with didSet JSON persistence rather than @AppStorage (arrays not supported)"
  - "CalendarExportService marked @MainActor to satisfy Swift 6 concurrency since it accesses @MainActor settings"
  - "Format sheet onDismiss refreshes dutyDayCount so subtitle stays accurate after mode change"
metrics:
  duration: "~20 min"
  completed: "2026-06-03"
  tasks_completed: 4
  files_modified: 4
---

# Quick Task 260603-tmj: Calendar Export Customisation Summary

## One-liner
Settings-driven ICS export with mode picker (all-day / sectors / both), reorderable component lists, and live previews persisted to UserDefaults.

## Tasks Completed

| Task | Name | Commit |
|------|------|--------|
| 1 | Create CalendarExportSettings model | 5faf5a8 |
| 2 | Rewrite CalendarExportService with settings-driven title builders | cf274be |
| 3 | Create CalendarFormatSheet with mode picker and reorderable lists | 4079a98 |
| 4 | Wire CalendarExportView to the format sheet and settings | a23136e |

## What Was Built

**CalendarExportSettings** (`Block-Time/Services/CalendarExportSettings.swift`)
- `CalendarExportMode` enum (allDayOnly / sectorsOnly / both) with displayName
- `AllDayComponent` enum (firstSTD, route, lastSTA, flightNumbers)
- `SectorComponent` enum (std, flightNumber, from, to, sta, paxIndicator)
- `OrderedComponent` Codable struct (rawValue + enabled flag)
- `@Observable @MainActor CalendarExportSettings.shared` singleton
- JSON persistence to UserDefaults with default-merging on new enum cases
- `enabledAllDay()` / `enabledSector()` helpers return ordered enabled components

**CalendarExportService** (`Block-Time/Services/CalendarExportService.swift`)
- New signature: `generateICS(from:settings:)` — groups flights by duty day, emits events per mode
- `buildSectorTitle(for:settings:)` — iterates `enabledSector()` in order; std/sta as "HH:MM"; PAX merges before flight number token; from/to collapses to "FROM -> TO"
- `buildDailyTitle(for:settings:)` — iterates `enabledAllDay()` in order; firstSTD/lastSTA as "HHmm"; route chain with optional inline flight number annotation; PAX prefix on positioning sectors
- `buildDailyEvent` / `buildSectorEvent` — all-day VEVENT and per-sector VEVENT builders
- `hhmmToColon` / `hhmmStripColon` helpers; `firstNonEmpty` updated to accept HHMM 4-digit format
- All existing date/time helpers (`resolveTimes`, `parseFlightDate`, `allDayString`, `utcDateTimeString`, `iCalTimestamp`, `icsEscape`) preserved

**CalendarFormatSheet** (`Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift`)
- Segmented Picker for export mode (Section 1)
- All-day event section: live preview pill + reorderable/toggleable component list (Section 2)
- Sector event section: same pattern; hidden when mode is `.allDayOnly` (Section 3)
- Preview pills use `RoundedRectangle(cornerRadius: 5)`, purple tint, `.lineLimit(1).minimumScaleFactor(0.7)`
- Placeholder duty (PAX QF101 BNE->SYD + QF203 SYD->MEL) and sector (QF123 BNE->SYD) for reactive live previews
- `#Preview` injects `ThemeService.shared`

**CalendarExportView** (`Block-Time/Views/Screens/Settings/CalendarExportView.swift`)
- `showFormatSheet` state + `slider.horizontal.3` toolbar button (second `.topBarLeading` item after Cancel)
- Sheet presents `CalendarFormatSheet` with `themeService` environment; `refreshCount()` on dismiss
- `generateICS` call updated to pass `CalendarExportSettings.shared`
- `dutyDayCount` added to viewModel (distinct flight dates), updated in `refreshCount()`
- `CalendarExportFlightCountCard` subtitle reflects mode: duty days / sector events / both
- All existing features (Cancel, Export, filter card, date rows, share sheet, error alert, unflown selection) preserved

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `Block-Time/Services/CalendarExportSettings.swift` exists
- `Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift` exists
- Commits 5faf5a8, cf274be, 4079a98, a23136e all present in git log
