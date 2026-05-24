---
phase: quick-260524-hnc
plan: 01
subsystem: PDF Export
tags: [pdf, training-record, custom-fields, layout]
key-files:
  modified:
    - Block-Time/Services/LogbookPDFLayout.swift
    - Block-Time/Services/LogbookPDFPageDrawer.swift
    - Block-Time/Services/LogbookPDFTotals.swift
    - Block-Time/Services/LogbookPDFRenderer.swift
    - Block-Time/Views/Screens/Settings/LogbookPDFExportView.swift
decisions:
  - Custom column ids use 100+n scheme (n = array index into customFields) — avoids collision with Standard ids 0–16
  - Remarks width formula: 560 - customCount*44 (560 = 806 - 246 fixed non-remarks cols)
  - Footer box left edge derived from first time-group column offset dynamically, not hardcoded id 9
  - Standard callers pass columns/columnOffsets/[] to drawer — no special-casing needed; identical output
metrics:
  duration: ~35 minutes
  completed: 2026-05-24
  tasks: 4
  files: 5
---

# Training Record PDF Dynamic Layout

Dynamic Training Record PDF variant: drops crew columns, adds up to 7 user-selected custom field columns with shrinking Remarks. Standard mode completely unchanged.

## Tasks Completed

| # | Task | Commit |
|---|------|--------|
| 1 | Add Training Record column factory + dynamic geometry helpers to LogbookPDFLayout | e75a0b7 |
| 2 | Inject columns/offsets/customFields into LogbookPDFPageDrawer | 85a3f66 |
| 3 | Add custom-field accumulation + formatting to PageTotals | f6fdea5 |
| 4 | Thread customFields through renderer + add custom-field picker UI | 316569a |

## What Was Built

**LogbookPDFLayout.swift:**
- `trainingRecordColumns(customFields:)` — builds dynamic 7-fixed-col layout without CAPT/F/O; custom field cols (id 100+n) inserted between REMARKS and TRNG; Remarks width = 560 - N*44
- `columnOffsets(for:)` — computes offsets for any column array (non-cached companion to the static `columnOffsets` property)
- `groupGeometry(for:in:offsets:)` — overload accepting injected arrays; existing static overload untouched

**LogbookPDFPageDrawer.swift:**
- Three new stored properties: `columns`, `columnOffsets`, `customFields`
- All `L.columns`/`L.columnOffsets` references replaced with `self.columns`/`self.columnOffsets`
- `groupGeometry` calls updated to injected-array overload
- Zero-width groups (empty `.crew` in Training Record) skipped in header drawing and grid lines
- Custom cells (id >= 100) render `flight.counterEntries[def.columnIndex]` raw values
- Footer and grid derive first-time-column offset dynamically via `columns.first(where: { $0.group == .time })`
- Custom footer values call `formattedCustomValue`; standard ids use `formattedValue`

**LogbookPDFTotals.swift:**
- `PageTotals.customTotals: [Int: Double]` keyed by `CustomCounterDefinition.columnIndex`; defaults `[:]`
- `+` operator merges `customTotals` via key union + sum
- `accumulate(_:customFields:)` parses `.time` (HH:MM via `hhmmToDecimal`), `.decimal`, `.integer`; skips `.text`
- `formattedCustomValue(columnIndex:type:useHHMM:)` formats by CounterType; text returns ""
- `computeTotals(pages:seed:customFields:)` threads customFields; Standard callers use default `[]`

**LogbookPDFRenderer.swift:**
- `render()` gains `customFields: [CustomCounterDefinition] = []` — backward compatible
- Computes active `columns` and `offsets` once; Standard path uses cached statics
- Passes `columns`/`offsets`/`customFields` into every `LogbookPDFPageDrawer` init

**LogbookPDFExportView.swift:**
- `@AppStorage("logbookPDFTrainingCustomFields")` persists comma-separated columnIndex ints
- `selectedCustomFields` resolves raw string → definitions in saved order, intersected with current defs, capped at 7
- `customFieldsPickerSection` shown only when `contentMode == .instructorHoursOnly`; shows hint row when no defs exist; 7-field cap disables un-selected rows at cap
- `generatePDF` captures `pdfCustomFields` on main actor before `Task.detached`

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all data paths fully wired.

## Self-Check: PASSED

- `LogbookPDFLayout.trainingRecordColumns` exists at line 145
- `LogbookPDFLayout.columnOffsets(for:)` exists at line 176
- `LogbookPDFLayout.groupGeometry(for:in:offsets:)` exists at line 188
- `PageTotals.customTotals` exists; `formattedCustomValue` exists; `accumulate(_:customFields:)` exists
- No `L.columns` or `L.columnOffsets` remaining in `LogbookPDFPageDrawer`
- `logbookPDFTrainingCustomFields` AppStorage, `selectedCustomFields`, `customFieldsPickerSection`, `pdfCustomFields` all present in view
- Commits e75a0b7, 85a3f66, f6fdea5, 316569a all exist in git log
