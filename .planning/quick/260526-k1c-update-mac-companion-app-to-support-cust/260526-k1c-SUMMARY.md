---
phase: quick-260526-k1c
plan: 01
subsystem: mac-companion
tags: [mac, custom-fields, icloud-kvs, core-data, logbook-table, edit-panel]
dependency_graph:
  requires: [260519-ka3, 260522-ke8]
  provides: [MAC-CUSTOM-01]
  affects: [Block-Time-Mac/MacLogbookViewModel.swift, Block-Time-Mac/MacLogbookTableView.swift, Block-Time-Mac/MacFlightEditView.swift]
tech_stack:
  added: [NSUbiquitousKeyValueStore, MacCustomFieldService, MacCustomCounterDefinition]
  patterns: [ObservableObject KVS observer, counter1-10 String Core Data, typed column injection via scrollingColumns]
key_files:
  created:
    - Block-Time-Mac/MacCustomCounterDefinition.swift
    - Block-Time-Mac/MacCustomFieldService.swift
  modified:
    - Block-Time-Mac/MacLogbookViewModel.swift
    - Block-Time-Mac/MacLogbookTableView.swift
    - Block-Time-Mac/MacFlightEditView.swift
decisions:
  - "Use MainActor.assumeIsolated in static scrollingColumns to access MacCustomFieldService.shared without restructuring callers"
  - "Capture columnIndex into local idx constant in scrollingColumns closure to avoid capture-by-reference issues"
  - "KVS decode happens in init() (not just on change notification) so fresh Mac install populates without waiting for remote change"
metrics:
  duration: 305s
  completed: "2026-05-26"
  tasks_completed: 4
  files_created: 2
  files_modified: 3
---

# Phase quick-260526-k1c Plan 01: Mac Custom Fields Parity Summary

**One-liner:** Mac companion app gains full custom-fields parity — KVS-synced definitions drive typed table columns and edit panel controls, replacing the retired integer-only customCount column.

## What Was Built

iOS replaced the single `customCount: Int16` Core Data field with ten per-definition `counter1`–`counter10: String?` slots driven by `CustomCounterDefinition` objects synced via iCloud KVS. The Mac app had no knowledge of this system, so custom data entered on iPhone was invisible on Mac. This plan brings the Mac to parity.

### Task 1 — MacCustomCounterDefinition + MacCustomFieldService (commit 6a62448)

Created two new Mac-only files:

- `MacCustomCounterDefinition.swift`: `CounterType` enum and `CustomCounterDefinition` struct with Codable keys identical to iOS. Includes the `decodeIfPresent(Bool.self, forKey: .showTotal) ?? true` custom init for forward compatibility.
- `MacCustomFieldService.swift`: `@MainActor ObservableObject` singleton. Reads local UserDefaults on init, then seeds from iCloud KVS string-encoded JSON directly (so a fresh Mac install gets definitions without waiting for a change notification). Observes `NSUbiquitousKeyValueStore.didChangeExternallyNotification` to update live when iOS adds/changes/removes a definition. Persists KVS-decoded definitions to local UserDefaults so subsequent launches are fast.

### Task 2 — Data layer: counter1–10 replaces customCount (commit f755617)

- `MacFlightRow`: removed `var customCount: Int`, added `var counter1`–`counter10: String` plus `counterValue(_ idx: Int) -> String`.
- `MacFlightRow.init?(entity:)`: reads `counter1`–`counter10` via the existing `str()` helper; no longer reads `customCount`.
- `MacEditableFlight`: removed `var customCount: Int = 0`, added `counter1`–`counter10: String = ""` plus `counterValue` and `mutating setCounter`.
- `MacEditableFlight.init(from:)`: copies counter1–10 from `MacFlightRow`.
- `applyFields`: writes `counter1`–`counter10` (empty string → `nil`), no longer writes `customCount`. The `customCount` Core Data attribute is left untouched (schema unchanged per constraint).
- Sync indicator: `isSyncing = true` in `init()`; `isSyncing = false` after first `reload()` in `load()`.

### Task 3 — Per-definition columns in logbook table (commit e67351f)

`LogbookColumn.scrollingColumns` refactored from an array literal to a var-based builder. After the fixed columns, it reads `MacCustomFieldService.shared.definitions` (via `MainActor.assumeIsolated`), sorts by `columnIndex`, and appends one typed `LogbookColumn` per definition with id `"counter{N}"`. Value closures format by type: `.time` → `parseTime`/`formatTime`, `.decimal` → `decimalDisplay`, `.integer`/`.text` → raw string. The `remarks` column is appended last. Legacy `custom`/`customCount` column removed. `ColumnPreferences` and `ColumnManagerPopover` unchanged — they get the new columns automatically.

### Task 4 — Typed controls in edit panel (commit 0ba3950)

- Removed `@AppStorage("logCustomCount")` and `@AppStorage("customCountLabel")` from `MacFlightEditView`.
- Replaced the `if logCustomCount { Section(customCountLabel) { intRow(...) } }` block with a definitions-driven `Section("Custom Fields")` containing one `customFieldRow` per definition, sorted by `columnIndex`.
- Added `customFieldRow(_:)` `@ViewBuilder` dispatching by `CounterType` to `intRow` (integer), monospaced `TextField` (decimal, time), or plain `TextField` (text).
- Added `counterBinding(for:)` and `intBinding(for:)` wiring to `draft.counterValue`/`draft.setCounter`.
- Removed `logCustomCount` toggle and `customCountLabel` text field from `EditEntryOptionsPopover`. Custom field definitions are managed on iOS only.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all custom field data is live-wired through `MacCustomFieldService.shared.definitions` → Core Data `counter1`–`counter10`.

## Self-Check: PASSED

Files created/exist:
- Block-Time-Mac/MacCustomCounterDefinition.swift: FOUND
- Block-Time-Mac/MacCustomFieldService.swift: FOUND

Commits exist:
- 6a62448: FOUND
- f755617: FOUND
- e67351f: FOUND
- 0ba3950: FOUND
