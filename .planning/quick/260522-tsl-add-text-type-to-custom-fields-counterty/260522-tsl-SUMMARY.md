---
phase: quick-260522-tsl
plan: 01
subsystem: custom-fields
tags: [custom-fields, counter-type, text-field, settings, dashboard]
dependency_graph:
  requires: []
  provides: [CounterType.text, ModernRemarksField.placeholder]
  affects: [SettingsView, CrewOpsCard, CustomCounterDashboardCard, DashboardCardID, FrozenColumnSpreadsheetView]
tech_stack:
  added: []
  patterns: [exhaustive-switch, optional-placeholder-parameter]
key_files:
  created: []
  modified:
    - Block-Time/Models/CustomCounterDefinition.swift
    - Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift
    - Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
    - Block-Time/Views/Screens/Settings/SettingsView.swift
    - Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift
    - Block-Time/Models/DashboardCardID.swift
    - Block-Time/Views/Screens/FrozenColumnSpreadsheetView.swift
decisions:
  - Text fields default showTotal = false and the toggle is hidden in FieldEditSheet
  - Text dashboard card returns "—" without aggregation — no numeric display
  - ModernRemarksField gains placeholder parameter with default "Add remarks..." preserving all existing call sites
metrics:
  duration: ~15 minutes
  completed: 2026-05-22
  tasks_completed: 3
  files_modified: 7
---

# Quick 260522-tsl: Add Text Type to Custom Fields — Summary

**One-liner:** Added `CounterType.text` case wired through model, form, settings, and dashboard with no totalling support.

## What Was Built

### New `.text` case on CounterType

`CounterType` gains a `.text` case alongside `.time`, `.decimal`, and `.integer`. Text fields:
- Store values verbatim in the existing `counter1`–`counter10` `String?` Core Data columns — no migration needed.
- Display as a multi-line remarks-style input (`ModernRemarksField`) with placeholder "Add text..." on Add/Edit Flight.
- Show no Total toggle in Settings and never produce dashboard aggregation values.

### Files Changed

**Block-Time/Models/CustomCounterDefinition.swift** (lines 10–31)
- Added `case text` to `CounterType` enum.
- Added `"Text"` to `displayName` switch.
- Added `"Notes, codes, or any text value"` to `subtitle` switch.

**Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift** (lines 394–399)
- Added `var placeholder: String = "Add remarks..."` property to `ModernRemarksField`.
- Replaced hardcoded `"Add remarks..."` literal with the new `placeholder` property.
- Default preserves all existing Remarks call sites without modification.

**Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift** (lines 370–388)
- Added `case .text:` branch to `fieldRow` dispatcher.
- Renders `ModernRemarksField` with `icon: "text.alignleft"` and `placeholder: "Add text..."`.

**Block-Time/Views/Screens/Settings/SettingsView.swift**
- Three `iconFor` switches (InlineCustomFieldsView ~2531, CustomFieldsSettingsView ~2636, FieldEditSheet ~2789): added `case .text: return "text.alignleft"`.
- Three `colorFor` switches (same locations): added `case .text: return .purple`.
- Wrapped `showTotal` Toggle in `if type != .text { ... }` to hide it for text fields.
- Added `.onChange(of: type) { _, newValue in if newValue == .text { showTotal = false } }` on the NavigationStack.

**Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift** (lines 129–196)
- Added `case .text: displayValue = "—"; return` as first case in `loadStats()` switch.
- Added `case .text: return "text.alignleft"` to `iconForType`.
- Added `case .text: return .purple` to `colorForType`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing coverage] CounterType switches in DashboardCardID.swift**
- **Found during:** Task 3 review sweep
- **Issue:** `DashboardCardID.icon` and `DashboardCardID.accentColor` both had exhaustive switches over `CounterType` without `.text` — would cause compiler warnings/errors.
- **Fix:** Added `case .text: return "text.alignleft"` to icon switch and `case .text: return .purple` to accentColor switch.
- **Files modified:** Block-Time/Models/DashboardCardID.swift
- **Commit:** 8fbf502

**2. [Rule 2 - Missing coverage] CounterType switch in FrozenColumnSpreadsheetView.swift**
- **Found during:** Task 3 review sweep
- **Issue:** `addTotalCounterLabel` had exhaustive switch without `.text`. In practice text fields will never reach this (guarded by `showTotal` being false), but compiler requires exhaustiveness.
- **Fix:** Added `case .text: text = ""` no-op with explanatory comment.
- **Files modified:** Block-Time/Views/Screens/FrozenColumnSpreadsheetView.swift
- **Commit:** 8fbf502

## Confirmation: No Model/Migration Changes

- `counter1`–`counter10` on `FlightEntity` are already `String?` in Core Data — text values store verbatim.
- No new Core Data attributes, entities, or migration stages required.
- `CustomCounterDefinition` encoding/decoding handles `.text` via `rawValue` = `"text"` automatically.

## Known Stubs

None.

## Self-Check: PASSED

Files exist:
- Block-Time/Models/CustomCounterDefinition.swift: FOUND
- Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift: FOUND
- Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift: FOUND
- Block-Time/Views/Screens/Settings/SettingsView.swift: FOUND
- Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift: FOUND
- Block-Time/Models/DashboardCardID.swift: FOUND
- Block-Time/Views/Screens/FrozenColumnSpreadsheetView.swift: FOUND

Commits exist:
- a801707: feat(quick-260522-tsl): add .text case to CounterType with placeholder support
- e06f3d9: feat(quick-260522-tsl): wire .text into SettingsView icons, colours, and toggle guard
- ee718ae: feat(quick-260522-tsl): wire .text into CustomCounterDashboardCard — no aggregation
- 8fbf502: fix(quick-260522-tsl): add .text branch to CounterType switches in DashboardCardID and FrozenColumnSpreadsheetView
