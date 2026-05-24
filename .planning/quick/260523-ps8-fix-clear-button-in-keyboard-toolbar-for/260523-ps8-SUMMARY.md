---
phase: quick-260523-ps8
plan: 01
subsystem: AddFlightView / KeyboardToolbar
tags: [bug-fix, keyboard-toolbar, custom-fields]
key-files:
  modified:
    - Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift
decisions:
  - ModernRemarksField now registers a real clear closure instead of a no-op
metrics:
  duration: <5 minutes
  completed: 2026-05-23
  tasks: 1
  files: 1
---

# Quick 260523-ps8: Fix Clear Button in Keyboard Toolbar for ModernRemarksField

**One-liner:** Wired `ModernRemarksField` clear closure to `{ value = "" }` so the keyboard toolbar Clear button empties the Remarks and custom Text-type fields.

## What Was Done

**Task 1: Wire ModernRemarksField Clear action to empty the bound value**
- Commit: `34d3255`
- In `ModernRemarksField.onChange(of: editorFocused)`, replaced `keyboardToolbar?.fieldDidFocus(clear: {})` with `keyboardToolbar?.fieldDidFocus(clear: { value = "" })`.
- Removed stale comment "Remarks has no Clear button — pass a no-op clear action".
- No other code changed.

## Verification

```
grep -n 'fieldDidFocus(clear: { value = "" })' Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift
# Line 440: keyboardToolbar?.fieldDidFocus(clear: { value = "" })
```

No remaining no-op `fieldDidFocus(clear: {})` calls in ModernRemarksField.

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- File modified: `Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift` — FOUND
- Commit `34d3255` — FOUND
