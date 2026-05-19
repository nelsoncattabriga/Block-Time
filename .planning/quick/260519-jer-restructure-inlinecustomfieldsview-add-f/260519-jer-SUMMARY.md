---
phase: quick-260519-jer
plan: 01
subsystem: Settings UI
tags: [swiftui, settings, custom-fields]
key-files:
  modified:
    - Block-Time/Views/Screens/Settings/SettingsView.swift
decisions:
  - Removed fixed-height frame math from List; natural row sizing avoids stale height on definition count change
metrics:
  duration: ~5 min
  completed: 2026-05-19
  tasks: 1
  files: 1
---

# Quick 260519-jer: Restructure InlineCustomFieldsView — Add Field at Top, Natural List Height

One-liner: Moved "Add Field" button to top of InlineCustomFieldsView and stripped nested rounded-background from List so it blends into the parent card.

## What Was Done

Single task, single file. Edited only `InlineCustomFieldsView.body` in `SettingsView.swift` (~lines 2447–2495):

1. Moved the "Add Field" button from the bottom to the first position in the VStack (before the if/else block).
2. Removed `.padding(.top, 8)` from the button (no longer last item; VStack spacing handles gaps).
3. Deleted the `Divider()` between the list and the button.
4. Removed three List modifiers: `.frame(height: CGFloat(service.definitions.count) * 44)`, `.clipShape(RoundedRectangle(cornerRadius: 8))`, `.background(Color(.secondarySystemBackground).clipShape(RoundedRectangle(cornerRadius: 8)))`.

All other modifiers, row content, sheet handlers, helper functions (`iconFor`, `colorFor`), and `CustomFieldsSettingsView` are completely unchanged.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 279a16a | feat(quick-260519-jer): move Add Field button to top, remove nested List background |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `struct InlineCustomFieldsView` exists at line 2441 — FOUND
- `struct CustomFieldsSettingsView` exists at line 2523 — FOUND
- "Add Field" appears at line 2449 (first VStack child) — FOUND
- No `frame(height: CGFloat(service.definitions` inside InlineCustomFieldsView — CONFIRMED
- No `secondarySystemBackground).clipShape` on List inside InlineCustomFieldsView — CONFIRMED
- `listRowBackground(Color(.secondarySystemBackground))` on row still present at line 2477 — FOUND
- Commit 279a16a — FOUND
