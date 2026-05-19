---
phase: quick
plan: 260519-g0g
subsystem: Settings, AddFlight, Dashboard
tags: [rename, ui-strings, swift-identifiers]
dependency_graph:
  requires: []
  provides: [Field terminology in Settings UI, CrewOpsCard field views, Dashboard fallback strings]
  affects: [SettingsView, CrewOpsCard, CustomCounterDashboardCard, DashboardCardID, FlightTimeExtractorViewModel]
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - Block-Time/Views/Screens/Settings/SettingsView.swift
    - Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
    - Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift
    - Block-Time/Models/DashboardCardID.swift
    - Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
decisions:
  - UserDefaults keys, CounterType enum, CustomCounterService, CustomCounterDefinition, and DashboardCardID.customCounter left unchanged
metrics:
  duration: ~5 minutes
  completed: 2026-05-19
  tasks_completed: 3
  tasks_total: 3
  files_modified: 5
---

# Quick Task 260519-g0g: Rename Counter/Counters to Field/Fields Summary

**One-liner:** Renamed all user-visible "Counter/Counters" strings and unsafe-to-store Swift identifiers to "Field/Fields" across 5 files.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Rename strings and identifiers in SettingsView.swift | 9857cef | SettingsView.swift |
| 2 | Rename view types and function in CrewOpsCard.swift | 60cbe14 | CrewOpsCard.swift |
| 3 | Rename fallback strings in DashboardCardID, CustomCounterDashboardCard, FlightTimeExtractorViewModel | 9bec18a | DashboardCardID.swift, CustomCounterDashboardCard.swift, FlightTimeExtractorViewModel.swift |

## Changes Made

### SettingsView.swift
- Toggle label: "Use Custom Fields"
- Navigation title: "Custom Fields"
- Section header: "Field Details"
- Button labels: "Add Field", "Edit Field", "Delete Field"
- Empty-state messages: "No fields added yet." / "No fields defined. Tap 'Add Field' to create one."
- Footer text: "Fields appear in the Add/Edit flight form..."
- Confirmation dialog: "Delete this field?" / "This will remove the field..."
- Swift types renamed: `FieldEditMode`, `FieldEditSheet`, `InlineCustomFieldsView`, `CustomFieldsSettingsView`
- MARK comments updated

### CrewOpsCard.swift
- Swift types renamed: `FieldTimeField`, `FieldDecimalField`, `FieldIntegerField`
- Function renamed: `fieldRow(for:viewModel:keyboardToolbar:)`
- All call sites updated (legacy single counter + ForEach + dispatcher body)
- MARK comments updated

### DashboardCardID.swift
- Fallback in `displayName`: `?? "Field"`

### CustomCounterDashboardCard.swift
- Card header title fallback: `?? "Field"`
- Unavailable text: `Text("Field unavailable")`

### FlightTimeExtractorViewModel.swift
- Change-log label fallback: `?? "Field"`

## What Was NOT Changed (by design)
- `CounterType` enum and all its cases
- `CustomCounterService` class
- `CustomCounterDefinition` struct
- `DashboardCardID.customCounter` case
- All UserDefaults keys and stored JSON keys
- `counterValues`, `counterEntries` ViewModel properties
- `legacyCounter` migration keys

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

Files verified present:
- Block-Time/Views/Screens/Settings/SettingsView.swift — FOUND
- Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift — FOUND
- Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift — FOUND
- Block-Time/Models/DashboardCardID.swift — FOUND
- Block-Time/ViewModels/FlightTimeExtractorViewModel.swift — FOUND

Commits verified:
- 9857cef — FOUND
- 60cbe14 — FOUND
- 9bec18a — FOUND

Overall verification: zero remaining user-visible "Counter/Counters" strings, zero old Swift identifiers.
