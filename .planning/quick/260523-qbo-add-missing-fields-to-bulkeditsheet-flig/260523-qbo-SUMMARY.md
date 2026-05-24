---
phase: quick-260523-qbo
plan: 01
subsystem: BulkEdit
tags: [bulk-edit, custom-fields, flight-date, sp-ins, ios26-datepicker]
requires: []
provides: [bulk-edit-flight-date, bulk-edit-ins, bulk-edit-custom-fields]
affects: [BulkEditViewModel, BulkEditSheet, BulkEditFields, BulkEditPickers]
tech-stack:
  added: []
  patterns: [FieldState<String>, MainActor.assumeIsolated, BulkEditFlightTypeToggle segmented control extension]
key-files:
  created: []
  modified:
    - Block-Time/ViewModels/BulkEditViewModel.swift
    - Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift
    - Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift
    - Block-Time/Views/Screens/BulkEdit/BulkEditPickers.swift
decisions:
  - "CustomCounterService accessed via computed property (.shared) not @Environment — presentation sites (FlightsView/FlightsSplitView) do not inject it"
  - "INS added as 4th button in BulkEditFlightTypeToggle segmented control (FLT/PAX/SIM/INS) rather than a separate row"
  - "isSpIns and isSimulator are mutually exclusive in the toggle — selecting INS clears isSimulator and vice versa"
metrics:
  duration: "6 minutes"
  completed: "2026-05-23"
  tasks_completed: 3
  tasks_total: 4
  files_modified: 4
---

# Quick Task 260523-qbo: Add Missing Fields to BulkEditSheet — Summary

**One-liner:** BulkEditSheet now supports bulk flight date, INS (Sp/Ins) toggle with spInsTime, and dynamic custom fields card driven by CustomCounterService definitions.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Extend BulkEditViewModel with flightDate, isSpIns, spInsTime, customCounterStates | cb9899e | BulkEditViewModel.swift |
| 2 | Add BulkEditDateField and extend BulkEditFlightTypeToggle with INS | f360d15 | BulkEditFields.swift, BulkEditPickers.swift |
| 3 | Add Flight Date card, INS row, SP/INS Time field, Custom Fields card to BulkEditSheet | 58efd94 | BulkEditSheet.swift |
| 4 | Visual verification checkpoint | — | (skipped — Nelson builds locally) |

## What Was Built

### BulkEditViewModel (BulkEditViewModel.swift)
- `flightDate: FieldState<String>` — analyzes `FlightSector.date` across selected flights
- `isSpIns: FieldState<Bool>` — analyzes `spInsTime > 0`, mirrors the `isSimulator` pattern
- `spInsTime: FieldState<String>` — direct time override
- `customCounterStates: [Int: FieldState<String>]` — keyed by `columnIndex`, populated from `CustomCounterService.shared.definitions` via `MainActor.assumeIsolated`
- All four groups wired into `analyzeFields`, `storeInitialStates`, `setupModificationTracking`, `checkForModifications`
- `applyChanges` writes: `flight.date`, mirrors isSimulator block-time swap for isSpIns, writes spInsTime override, writes/removes `counterEntries[columnIndex]`

### BulkEditFields.swift
- New `BulkEditDateField` struct using iOS 26 pattern: Button showing formatted date → `.sheet` with `.graphical` DatePicker + `.presentationDetents([.height(420)])` + auto-dismiss via `onChange`
- Static `DateFormatter` instances (storage: "dd/MM/yyyy" en_AU UTC, display: "d MMM yyyy")

### BulkEditPickers.swift
- `BulkEditFlightTypeToggle` extended with `@Binding var isSpIns: FieldState<Bool>` parameter
- Added `ins` case to `FlightType` enum
- 4th "INS" button (indigo) added to segmented control; selecting any type clears the other three
- Frame widths reduced from 55pt to 48pt to fit four buttons comfortably

### BulkEditSheet.swift
- Flight Date `SectionCard` as the first card in the scroll view
- SP/INS Time `BulkEditTextField` in Flight Times card after SIM Time
- `BulkEditFlightTypeToggle` call updated with `isSpIns:` binding
- Custom Fields `SectionCard` (color: `.mint`) at the bottom, guarded by `!customCounterService.definitions.isEmpty`
- `keyboardType(for:)` helper: `.time` → numberPad, `.decimal` → decimalPad (numbersAndPunctuation on iPad), `.integer` → numberPad, `.text` → default
- `CustomCounterService` accessed as `private var customCounterService: CustomCounterService { CustomCounterService.shared }` — it's `@Observable` so the card auto-refreshes on definition changes

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written with one clarifying implementation choice.

### Implementation Notes

**INS toggle placement:** The plan said to add INS as "a separate row in Operations" or extend the toggle. I chose to extend `BulkEditFlightTypeToggle` as a 4th button (making the segmented control FLT/PAX/SIM/INS). This matches the plan's "extending its signature" option and gives a cleaner single-row UI. The mutual-exclusivity is intentional — INS and SIM are distinct flight types. If a flight needs to be both INS and something else, `spInsTime` can be set independently via the SP/INS Time field in Flight Times.

**CustomCounterService injection:** Used computed property fallback (`.shared`) because `FlightsView` and `FlightsSplitView` do not inject `CustomCounterService` into environment at the sheet presentation site. The service is `@Observable` so the computed property access still triggers view updates correctly.

## Known Stubs

None.

## Self-Check: PASSED

- `BulkEditViewModel.swift` — modified, contains all four new state groups
- `BulkEditFields.swift` — modified, contains `BulkEditDateField`
- `BulkEditPickers.swift` — modified, `BulkEditFlightTypeToggle` has `isSpIns` binding and INS button
- `BulkEditSheet.swift` — modified, Flight Date card first, SP/INS Time after SIM, INS in toggle, Custom Fields card at bottom
- Commits: cb9899e, f360d15, 58efd94 — all present
