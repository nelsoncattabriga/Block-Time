---
phase: quick-260523-tux
plan: 01
subsystem: custom-fields
tags: [hhmm, keyboard, time-field, bulk-edit]
dependency_graph:
  requires: []
  provides: [FieldTimeField-hhmm-fix, BulkEditTimeField-hhmm-fix]
  affects: [CrewOpsCard, BulkEditSheet]
tech_stack:
  added: []
  patterns: [padHHMM-helper, AppStorage-showAsHHMM, 4-digit-colon-auto-insert]
key_files:
  modified:
    - Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
    - Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift
decisions:
  - "Add padHHMM() private helper inside each struct rather than sharing — avoids cross-struct coupling"
  - "Auto-colon insertion applied in both onChange and onBlur paths so keyboard Done tap and focus-loss are both covered"
metrics:
  duration: 600s
  completed: 2026-05-23T12:00:00Z
  tasks_completed: 3
  files_modified: 2
---

# Phase quick-260523-tux Plan 01: Fix HH:MM Mode Input in FieldTimeField and BulkEditTimeField Summary

**One-liner:** numberPad keyboard, "00:00" placeholder, padHHMM leading-zero display, and 4-digit auto-colon insertion for HH:MM custom Time fields in CrewOpsCard and BulkEditSheet.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Fix FieldTimeField HH:MM mode (CrewOpsCard.swift) | b80ce5b | CrewOpsCard.swift |
| 2 | Fix BulkEditTimeField HH:MM mode (BulkEditFields.swift) | b4cc346 | BulkEditFields.swift |
| 3 | Auto-insert colon for 4-digit HH:MM entry in both fields | e5b5d8c | CrewOpsCard.swift, BulkEditFields.swift |

## What Was Built

### Task 1 & 2 — Initial HH:MM Fixes
- Changed placeholder from `"0:00"` to `"00:00"` in HH:MM mode (both files)
- Changed keyboard to `(showAsHHMM ? .numberPad : .decimalPad)` on iPhone
- Added `padHHMM(_:)` private helper using `String(format: "%02d:%02d", h, m)`
- Wrapped all HH:MM `editingText` assignment sites with `padHHMM()` calls

### Task 3 — 4-Digit Colon Auto-Insert (Bug Fix)

**Bug:** Typing 4 digits (e.g. "0330") then tapping Done left the field showing "0330". On next
tap it misparsed as "330:00".

**Root cause:** `onChange(of: editingText)` only filtered characters — it never inserted the colon.
On blur the HH:MM branch only handled strings already containing ":" or pure decimals.

**Fix applied to both FieldTimeField (CrewOpsCard.swift) and BulkEditTimeField (BulkEditFields.swift):**

`onChange(of: editingText)` — when exactly 4 digits with no colon are detected, auto-insert:
```swift
if digitsAndColon.count == 4 && !digitsAndColon.contains(":") {
    filtered = "\(digitsAndColon.prefix(2)):\(digitsAndColon.suffix(2))"
} else {
    filtered = String(digitsAndColon.prefix(5))
}
```

`onChange(of: isFocused)` blur path — handle bare 4-digit string before parsing:
```swift
let blurInput: String
if trimmed.count == 4 && !trimmed.contains(":") && trimmed.allSatisfy(\.isNumber) {
    blurInput = "\(trimmed.prefix(2)):\(trimmed.suffix(2))"
} else {
    blurInput = trimmed
}
// then use blurInput instead of trimmed for hhmmToDecimal / Double conversion
```

## Deviations from Plan

None — all tasks executed exactly as specified.

## Self-Check: PASSED

- `b80ce5b` confirmed in git log (Task 1)
- `b4cc346` confirmed in git log (Task 2)
- `e5b5d8c` confirmed in git log (Task 3)
- Both files confirmed modified with colon auto-insert logic
