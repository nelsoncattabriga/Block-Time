# Phase 2 — Inline Cell Editing + Bulk Edit

_Branch: `mac-companion-rebuild` • Prereq: Phase 1 complete (Mac UI on the shared core) • Target executor: Claude Code CLI_

## Goal

Add spreadsheet-style **cell-by-cell editing** to the Mac `NSTableView`, and a **bulk edit** path for multi-row changes — both writing through the shared `FlightDatabaseService` so Mac and iOS stay consistent. The existing detail/edit panel (`MacFlightEditView`) stays as the "standard entry" path; cell editing is **additive**, not a replacement.

**Definition of done:** double-click (or keyboard) edits a cell in place; valid edits persist via the shared layer and sync; invalid input is rejected without a write; selecting multiple rows and applying a bulk change updates all of them through one shared call. No existing feature removed.

> This is the highest-judgment phase — fiddly AppKit editing in a two-table frozen-column layout. Consider running it on the stronger model, one increment at a time.

## Why this is well-positioned

The plumbing is already right:
- The Mac viewmodel maps `FlightSector` ↔ `MacFlightRow` (`MacFlightRow(sector:)`) and `MacEditableFlight` ↔ `FlightSector`, and writes through `FlightDatabaseService.shared`.
- `FlightSector` is a public value type in `BlockTimeKit` (`Models/FlightLogbook.swift`).
- The shared service already exposes the exact write methods we need: `updateFlight(_ sector: FlightSector)` (single) and `updateFlightsBulk(_ updates: [UUID: FlightSector]) async` (bulk) — both with undo + sync handled internally.

So a cell edit is just: row → its `FlightSector` → mutate one field (validated) → `updateFlight`. A bulk edit is: selected rows → `[UUID: FlightSector]` → `updateFlightsBulk`.

---

## Current table model (what you're extending)

In `MacLogbookTableView.swift`:
- `struct LogbookColumn: Identifiable` has `let value: (MacFlightRow) -> String` — **read-only** today.
- Cells are non-editable `CentredLabel` (NSTextField labels), built in `tableView(_:viewFor:row:)`.
- Frozen left table + scrolling right table share one `Coordinator` (`NSTableViewDelegate`/`DataSource`).
- Rows are `[MacFlightRow]`; each has `.id` (UUID) and display formatting (`parseTime`/`formatTime`/`decimalDisplay`).

---

## Workstream A — Inline cell editing

### 1. Make columns describe how to edit, not just how to display

Extend `LogbookColumn` with edit metadata:

```swift
enum CellEditor {
    case none                       // read-only (e.g. computed totals)
    case text                       // free text (remarks, names)
    case time                       // HH:MM, parsed by the shared time parser
    case integer(min: Int, max: Int)// landings / takeoffs
    case decimal                    // decimal-hours fields if any
    case toggle                     // Bool flags (ILS/GLS/NPA/RNP/AIII/positioning/PF)
    case date                       // flight date
    case picker(options: () -> [String])  // airports, aircraft type/reg, crew names
}

struct LogbookColumn: Identifiable {
    // …existing…
    let value: (MacFlightRow) -> String
    let editor: CellEditor
    // Validate + apply one field onto a sector. Return false to reject (revert + NSBeep).
    let apply: (_ raw: String, _ sector: inout FlightSector) -> Bool
}
```

> `apply` must use the **same parsing/formatting the panel uses** so a cell edit and a panel edit produce identical stored values — reuse the shared time parser (BlockTimeKit `TimeCalculationManager` / the existing `MacFlightRow.parseTime`) and airport/aircraft normalisation (`AirportService`, `AircraftFleetService`). Don't write a second parser.

Read-only / computed columns get `.editor = .none` and are never editable.

### 2. Make the cell editable

- For editable columns, use an editable `NSTextField` (not a label): begin non-editable; on activation set `isEditable = true`, show focus ring, `selectText`.
- Coordinator conforms to `NSTextFieldDelegate`.
- **Edit triggers:** double-click the cell, or press Return / start typing while the row+cell is selected.
- **Commit:** in `controlTextDidEndEditing`, resolve the row's `FlightSector` (via the viewmodel / `MacEditableFlight(from: row)`), run `column.apply(rawString, &sector)`; if it returns true call `FlightDatabaseService.shared.updateFlight(sector)`, then reload that one row preserving selection. If false: revert the cell text, `NSBeep()`, no write.
- `toggle` columns: render a checkbox / click-to-toggle rather than text entry; commit immediately.
- `picker` columns: combo box sourced from the shared service; free text still allowed where the panel allows it.

### 3. Keyboard navigation (do this after basic editing works)

Intercept in `control(_:textView:doCommandBy:)`:
- `insertTab:` / `insertBacktab:` → commit, move to next/previous **editable** cell (skip `.none`), begin editing.
- `insertNewline:` → commit, move down one row, same column.
- `cancelOperation:` (Esc) → revert, end editing.
- Handle crossing the frozen-left ↔ scrolling-right boundary (the two tables share the Coordinator, so translate the column index across panes).

### 4. Increment order for Workstream A

A1. Add `editor`/`apply` to `LogbookColumn`; mark every column's editability (most start `.none`). Build. ✅
A2. Editable `.text` columns end-to-end (edit → validate → `updateFlight` → row reload). Build + manual test. ✅
A3. `.time` and `.integer` editors with shared validation. ✅
A4. `.toggle` (checkbox) and `.picker` (combo) editors. ✅
A5. Keyboard nav (Tab/Return/Esc, frozen-boundary aware). ✅

---

## Workstream B — Bulk edit

### 1. Share the apply logic (stop the next duplication before it starts)

`BulkEditViewModel.applyChanges(to: [FlightSector]) -> [UUID: FlightSector]` currently lives app-side in `Block-Time/ViewModels/BulkEditViewModel.swift` (an `ObservableObject`). Extract the **pure** part into `BlockTimeKit`:
- A plain value type (e.g. `BulkEditChangeSet`) holding the per-field "change/clear/leave" intent, plus `func applyChanges(to: [FlightSector]) -> [UUID: FlightSector]`.
- iOS `BulkEditViewModel` keeps its `@Published` form bindings but **delegates** the apply to the shared `BulkEditChangeSet` (no behaviour change for iOS).
- The Mac panel builds the same `BulkEditChangeSet` from its own SwiftUI form.

> Verify iOS bulk edit still behaves identically after this extraction — it's a refactor of shared logic, so re-test the iOS path too.

### 2. Mac bulk-edit UI

- Multi-select already works (`tableViewSelectionDidChange` → `parent.selection: Set<UUID>`).
- Add a Mac bulk-edit panel (sheet or inspector) enabled when >1 row is selected. Reuse the iOS field list/enums where they're not SwiftUI-bound; the form itself is a new Mac SwiftUI view.
- Apply: selected rows → their `FlightSector`s → `changeSet.applyChanges(to:)` → `await FlightDatabaseService.shared.updateFlightsBulk(updates)` → refresh the table.

### 3. Increment order for Workstream B

B1. Extract `BulkEditChangeSet` + `applyChanges` into `BlockTimeKit`; rewire iOS `BulkEditViewModel` to use it; **re-test iOS bulk edit**. ✅
B2. Mac bulk-edit panel wired to `updateFlightsBulk`. ✅

---

## Verification (gate before Phase 3)

1. Cell edit of a text field persists, survives relaunch, and the value matches what the panel would store.
2. A time-field cell edit accepts the same formats the panel accepts and rejects bad input (revert + beep, no write).
3. Tab/Return/Esc navigation works, including across the frozen/scrolling boundary; read-only columns are skipped.
4. Bulk edit on multiple selected rows updates all of them via `updateFlightsBulk` and refreshes.
5. iOS bulk edit still behaves exactly as before (the shared-logic extraction didn't regress it).
6. **Sync test:** a cell edit on Mac appears on iOS, and vice-versa.
7. The detail/edit panel path still works — nothing removed.

## Out of scope for Phase 2

- Import UI (Phase 3).
- Copy/paste of ranges, multi-cell fill, undo *grouping* of cell edits beyond what `FlightDatabaseService` already provides (note any desired enhancement as a follow-up).
- PDF export on Mac.

## Suggested Claude Code kickoff prompt

> Read `.planning/mac-companion/PHASE-2-SPREADSHEET-EDITING.md`. We're on `mac-companion-rebuild`, Phases 0–1 done. Start with Workstream A, increment A1 only: add an `editor: CellEditor` and `apply` closure to `LogbookColumn` and set every existing column's editability (default `.none`), with no behaviour change yet. Build and stop. Report the column→editability mapping you chose before doing A2.

Drive one increment at a time, building/testing between each. Do Workstream B's B1 (shared-logic extraction) carefully and re-test the iOS bulk-edit path before touching Mac bulk UI.
