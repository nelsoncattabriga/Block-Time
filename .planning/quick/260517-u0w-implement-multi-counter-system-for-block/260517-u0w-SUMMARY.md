---
phase: quick-260517-u0w
plan: 01
subsystem: custom-counters
tags: [core-data, dashboard, settings, add-flight, ios]
tech-stack:
  added: []
  patterns: [Core Data lightweight migration, @Observable service singleton, DashboardCardID struct refactor]
key-files:
  created:
    - Block-Time/FlightDataModel.xcdatamodeld/FlightDataModel 2.xcdatamodel/contents
    - Block-Time/FlightDataModel.xcdatamodeld/.xccurrentversion
    - Block-Time/Models/CustomCounterDefinition.swift
    - Block-Time/Services/CustomCounterService.swift
    - Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift
    - Block-Time/Views/Components/AddFlightView/CustomCountersCard.swift
  modified:
    - Block-Time/Models/FlightLogbook.swift
    - Block-Time/Models/DashboardCardID.swift
    - Block-Time/Models/DashboardConfiguration.swift
    - Block-Time/Services/FlightDatabaseService.swift
    - Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
    - Block-Time/Views/Components/Dashboard/DashboardCardView.swift
    - Block-Time/Views/Screens/AddFlightView.swift
    - Block-Time/Views/Screens/Settings/SettingsView.swift
decisions:
  - DashboardCardID converted from enum to struct so UUID-keyed custom counter IDs can coexist; rawValues preserved 1:1 for UserDefaults compatibility
  - counterEntries stored as [String: String] dict on FlightSector (uuidString → raw value); Core Data CustomCounterEntry entity holds individual rows with cascade delete
  - Time counter values stored as decimal hours in Core Data (consistent with all other time fields); displayed as HH:MM in the form and summed as minutes for the dashboard card
  - SettingsCategory.customCounters added as a top-level Settings category rather than embedding inside an existing category, for discoverability
metrics:
  duration: ~2h
  completed: 2026-05-18
  tasks: 5
  files: 13
---

# Quick Task 260517-u0w: Multi-counter system (definition + Core Data + dashboard + form + Settings)

**One-liner:** Per-flight custom counters (time/decimal/integer) with UserDefaults definition storage, Core Data CustomCounterEntry rows, DashboardCardID struct refactor, dashboard card with period totals, and Settings management UI.

## Tasks Completed

| # | Task | Commit |
|---|------|--------|
| 1 | Core Data model v2 + CustomCounterDefinition + CustomCounterService + FlightSector.counterEntries | 0311420 |
| 2 | DashboardCardID enum→struct refactor + DashboardConfiguration + FlightDatabaseService save/load + VM helpers | 54053a0 |
| 3 | CustomCounterDashboardCard + DashboardCardView dispatch | d951719 |
| 4 | CustomCountersCard + AddFlightView integration | d451f55 |
| 5 | Settings UI — CustomCountersSettingsView + AddCounterSheet | 2150c02 |

## Decisions Made

1. **DashboardCardID struct rawValue preservation** — every existing enum case rawValue is identical in the new struct, so all existing UserDefaults serialised selections decode cleanly without any migration.

2. **counterEntries as [String: String]** — using uuidString keys and string values avoids any UUID serialisation complexity in Core Data and keeps the FlightSector Codable-compatible.

3. **Time storage format** — time counter values are stored as decimal hours (same as blockTime, simTime, etc.) regardless of HH:MM display in the UI, for consistency with existing time-handling patterns throughout the codebase.

4. **CustomCountersSettingsView as standalone category** — added as a new `SettingsCategory` top-level entry rather than buried inside Crew & Ops, so pilots can easily discover the feature.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] FlightSector.from(entity:) was not passing customCount to the FlightSector init**
- **Found during:** Task 2, when auditing the load path
- **Issue:** The original `from(entity:)` factory omitted `customCount` from the FlightSector init call, so it always defaulted to 0 on load. This pre-existed but was exposed by the load-path audit.
- **Fix:** Added `customCount: Int(entity.customCount)` explicitly in the init call alongside `counterEntries`.
- **Files modified:** Block-Time/Models/FlightLogbook.swift
- **Commit:** 54053a0

## Known Stubs

None — all data paths are wired end-to-end: definitions persist to UserDefaults, counterEntries round-trip through Core Data CustomCounterEntry rows, and the dashboard card aggregates live data from the fetch service.

## Awaiting

Task 6 (checkpoint:human-verify) — user must build locally and verify:
1. Lightweight Core Data migration runs on existing data without crash
2. Settings > Custom Counters: add/reorder/delete counters, persist across launches
3. Add/Edit form shows Custom Counters section when counters are defined; values round-trip
4. Dashboard card picker shows custom counter cards; card renders period totals with correct type aggregation
5. Existing customCount card and all other cards/sections unchanged

## Self-Check: PASSED

- CustomCounterDefinition.swift: FOUND
- CustomCounterService.swift: FOUND
- FlightDataModel 2.xcdatamodel/contents: FOUND
- .xccurrentversion pointing to version 2: FOUND (verified via grep)
- CustomCounterDashboardCard.swift: FOUND
- CustomCountersCard.swift: FOUND
- All 5 task commits present: 0311420, 54053a0, d951719, d451f55, 2150c02
- FlightSector.counterEntries property: FOUND (line 105)
- Existing customCount field: UNCHANGED (verified)
