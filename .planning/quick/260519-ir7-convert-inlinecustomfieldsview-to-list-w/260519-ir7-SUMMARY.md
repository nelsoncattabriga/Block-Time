---
phase: quick-260519-ir7
plan: 01
subsystem: Settings UI
tags: [swiftui, list, reorder, delete, custom-fields]
dependency_graph:
  requires: []
  provides: [InlineCustomFieldsView-List-reorder-delete]
  affects: [SettingsView]
tech_stack:
  added: []
  patterns: [List with always-active editMode, scrollDisabled fixed-height List inside ScrollView]
key_files:
  modified:
    - Block-Time/Views/Screens/Settings/SettingsView.swift
decisions:
  - Mapped IndexSet offsets to columnIndex before calling service.remove to avoid index invalidation during batch deletes
metrics:
  duration: "~5 minutes"
  completed: "2026-05-19"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
---

# Phase quick-260519-ir7 Plan 01: Convert InlineCustomFieldsView to List Summary

**One-liner:** Replaced VStack/ForEach rows with a plain List using always-active editMode for drag-reorder and swipe-to-delete.

## What Changed in InlineCustomFieldsView

**Before:** The `else` branch rendered a `VStack(spacing: 0)` with a manual `ForEach(Array(service.definitions.enumerated()), id: \.element.id)` iterating over indexed tuples. Each row contained an explicit "Edit" `Button("Edit", systemImage: "pencil.circle")` inline in the row. Manual dividers between rows. Background applied with `.background` + `.clipShape` on the VStack.

**After:** The `else` branch renders a SwiftUI `List` with `ForEach(service.definitions)` (no enumeration, no index tuples). Each row is a plain `Button` whose action sets `editingDefinition = definition` — tap anywhere on the row to edit. `.onMove` calls `service.move(fromOffsets:toOffset:)` directly. `.onDelete` maps the `IndexSet` to an array of `columnIndex` values first (to avoid index invalidation on batch removes), then calls `service.remove(columnIndex:)` for each. The List is styled with:

- `.listStyle(.plain)` — plain rows, no grouped/inset chrome
- `.scrollContentBackground(.hidden)` — removes default white/grouped background so it blends with the card
- `.scrollDisabled(true)` — prevents nested scroll conflict with the Settings `ScrollView`
- `.environment(\.editMode, .constant(.active))` — drag handles always visible; no Edit toggle needed
- `.frame(height: CGFloat(service.definitions.count) * 44)` — sizes List to exact content height
- `.clipShape(RoundedRectangle(cornerRadius: 8))` + `.background(Color(.secondarySystemBackground)...)` — visual match with the original card style

The per-row explicit "Edit" button is removed. Tapping a row opens the edit sheet via `editingDefinition`.

## Unchanged

- `CustomFieldsSettingsView` — not touched (confirmed by diff scope, struct starts at line 2534)
- `CustomCounterService` — not modified; `move(fromOffsets:toOffset:)` and `remove(columnIndex:)` called as-is
- Both `.sheet` modifiers on the body (`showingAddSheet`, `editingDefinition`)
- `iconFor(_:)` and `colorFor(_:)` helpers
- Empty-state `Text("No fields added yet.")` branch
- `Divider()` and `Button("Add Field", …)` below the list

## Deviations from Plan

None. The implementation matches the plan's specified List configuration exactly.

## Self-Check: PASSED

- File modified: `Block-Time/Views/Screens/Settings/SettingsView.swift` — exists and contains `List`, `.onMove`, `.onDelete`, `.environment(\.editMode, .constant(.active))`, `.listStyle(.plain)`
- Commit `36c8453` exists in git log
