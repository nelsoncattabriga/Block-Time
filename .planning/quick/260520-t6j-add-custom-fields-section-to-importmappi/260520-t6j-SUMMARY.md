---
id: 260520-t6j
type: quick
completed: 2026-05-20
duration: ~10 min
tasks_completed: 2 / 2
commits:
  - 3b89da8
  - 0370e6d
files_modified:
  - Block-Time/Services/CustomCounterService.swift
  - Block-Time/Views/Screens/Settings/ImportMappingView.swift
key_decisions:
  - CustomFieldSlotRow is a proper struct (not @ViewBuilder) so it can own @State showingColumnPicker and present sheets
  - PendingSlotConfig has only label + type (sourceColumn removed — column tracked in fieldMappings already)
  - Counter1..Counter10 FieldMapping entries appended after existing logbookFields in createInitialMappings, not replacing them
---

# Quick Task 260520-t6j: Add Custom Fields Section to ImportMappingView

**One-liner:** Custom Fields section in ImportMappingView with 10 slot rows, inline define-on-import for undefined slots, and pre-import definition commit via addToSlot.

## Tasks Completed

| # | Task | Commit |
|---|------|--------|
| 1 | Add addToSlot(_:label:type:showTotal:) to CustomCounterService | 3b89da8 |
| 2 | Add PendingSlotConfig + Custom Fields section to ImportMappingView | 0370e6d |

## What Was Built

### CustomCounterService.addToSlot
New method that inserts a `CustomCounterDefinition` at a specific slot index (1–10). No-ops silently if the slot is already occupied. Appends and persists (UserDefaults + CloudKit sync) if the slot is free.

### ImportMappingView changes
- **PendingSlotConfig** struct (file-private): `label: String` + `type: CounterType` for undefined slots being configured during import.
- **pendingSlotConfigs: [Int: PendingSlotConfig]** `@State` on `ImportMappingView`.
- **createInitialMappings**: after building the standard `logbookFields` mappings, appends 10 `FieldMapping` entries (`Counter1`…`Counter10`). For defined slots, fuzzy-matches `def.label` against CSV headers (exact, prefix, or suffix match). Leaves the existing "Custom Count" entry untouched.
- **Custom Fields Form section**: rendered between "Field Mapping" and "Aircraft Type Mapping". Uses `CustomFieldSlotRow` for each slot.
- **CustomFieldSlotRow** (private struct): owns `@State private var showingColumnPicker` and presents `ColumnPickerView` sheet. Defined slots show label + type badge. Undefined slots show dimmed "Custom Field N" label, then reveal `TextField("Label")` + `Picker("Type")` inline once a column is assigned.
- **isValidMapping**: now also checks that undefined slots with an assigned column have a non-empty trimmed label.
- **Import action**: before calling `onImport(...)`, iterates slots 1–10, commits any pending new definitions via `addToSlot`, and sets `UserDefaults.standard.set(true, forKey: "logCustomCount")`.

## Deviations from Plan

None — plan executed exactly as written (using the "Revised approach" for `CustomFieldSlotRow` that the plan itself specified).

## Known Stubs

None — all 10 slot rows are functional; FieldMapping entries for Counter1..Counter10 flow through to `onImport` and thence to FileImportService unchanged.

## Self-Check: PASSED

- CustomCounterService.addToSlot present at line 51
- PendingSlotConfig struct at line 127
- pendingSlotConfigs @State at line 202
- CustomFieldSlotRow struct at line 1053
- Custom Fields Section at line 309 (between Field Mapping at 289 and Aircraft Type Mapping at 331)
- counterMappings appended in createInitialMappings at lines 613–634
- counterSlotsValid check in isValidMapping at lines 490–497
- addToSlot call in Import action at line 470
- Commits 3b89da8, 0370e6d both exist in git log
