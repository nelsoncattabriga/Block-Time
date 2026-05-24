---
phase: quick-260523-sv8
plan: 01
subsystem: BulkEdit / CustomFields
tags: [bulk-edit, custom-fields, time-field, swiftui]
key-files:
  modified:
    - Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift
    - Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift
decisions:
  - Wrote on-blur (not on-change) to fieldState to avoid partial-string storage mid-typing
  - Left keyboardType(for:) helper in place per plan directive despite having no callers
metrics:
  duration: ~10 min
  completed: 2026-05-23
  tasks: 2
  files: 2
---

# Quick 260523-sv8: Add BulkEditTimeField replicating FieldTimeField for BulkEdit custom Time fields

**One-liner:** Dual-mode decimal/HH:MM time field for BulkEditSheet custom fields that stores decimal strings to Core Data.

## What Was Done

**Task 1 — BulkEditTimeField (9dd9f59):**
Added `BulkEditTimeField` struct to `BulkEditFields.swift`. Mirrors `FieldTimeField` from `CrewOpsCard.swift` but operates on `BulkEditViewModel.FieldState<String>`. Key behaviours:
- Keyboard type: iPad uses `.numbersAndPunctuation`; iPhone uses `.numberPad` (HH:MM mode) or `.decimalPad` (decimal mode)
- Placeholder: `(Mixed)` when `fieldState.isMixed`; `0:00` or `0.0` otherwise
- On focus: converts stored decimal to HH:MM for display (or decimal to decimal), clears if zero/empty/mixed
- On blur: converts HH:MM input to decimal string (`"%.1f"` format) before writing to `fieldState`
- On appear: same conversion logic as on-focus for initial display
- Registers `keyboardToolbar.fieldDidFocus` clear callback
- Visual style matches `BulkEditTextField`: label above, `secondarySystemBackground` rounded box, blue focus stroke
- Uses `foregroundStyle`, `clipShape(.rect(cornerRadius:))` per coding standards

**Task 2 — BulkEditSheet dispatch (9a2ae39):**
Replaced the flat `ForEach` in the Custom Fields card with a `switch def.type`:
- `.time` → `BulkEditTimeField`
- `.decimal` → `BulkEditTextField` with decimalPad/numbersAndPunctuation
- `.integer` → `BulkEditTextField` with numberPad/numbersAndPunctuation
- `.text` → `BulkEditTextField` with default keyboard, no toolbar

Removed `isTimeField(for:)` and `customFieldKeyboardType(for:)` helper functions (no remaining call sites). The four `isTimeField: true` callers for OUT/IN/STD/STA Schedule Times fields are unchanged.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `struct BulkEditTimeField` present in BulkEditFields.swift (line 374)
- `FlightSector.decimalToHHMM` and `FlightSector.hhmmToDecimal` both referenced
- `switch def.type` present in BulkEditSheet.swift (line 332)
- `BulkEditTimeField(` call present in BulkEditSheet.swift (line 334)
- 4 `isTimeField: true` callers remain (Schedule Times only) — correct
- Commits 9dd9f59 and 9a2ae39 confirmed in git log
