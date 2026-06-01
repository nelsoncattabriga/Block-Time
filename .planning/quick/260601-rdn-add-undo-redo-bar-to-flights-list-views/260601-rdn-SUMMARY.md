---
phase: quick
plan: 260601-rdn
subsystem: flights-list
tags: [undo, core-data, flights-view, flights-split-view]
key-files:
  modified:
    - Block-Time/Services/FlightDatabaseService.swift
    - Block-Time/Views/Screens/FlightsView.swift
    - Block-Time/Views/Screens/FlightsSplitView.swift
decisions:
  - Undo grouping added to 5 per-flight methods only (saveFlight, updateFlight, updateScheduledFlightWithActualData, deleteFlight, deleteFlights); background/bulk/migration methods left untouched
  - undoableChangeCount tracked manually since NSUndoManager exposes no public count
  - NSManagedObjectContextDidSave used in addition to flightDataChanged to catch undo/redo saves that do not post .flightDataChanged themselves
metrics:
  completed: "2026-06-01"
  tasks: 2
  files: 3
---

# Quick Task 260601-rdn: Add Undo/Redo Bar to Flights List Views

**One-liner:** In-memory NSUndoManager on viewContext surfaces an orange undo/redo bar in both flights list views after any per-flight save, update, or delete.

## What Was Built

### FlightDatabaseService.swift
- `UndoManager()` assigned to `container.viewContext.undoManager` in the `persistentContainer` lazy closure.
- `canUndo`, `canRedo` computed vars exposing the context's undo manager state.
- `private(set) var undoableChangeCount: Int` tracks stack depth (NSUndoManager has no public count).
- `undoLastChange()` and `redoLastChange()` — each calls undo/redo on the undo manager, saves the context, decrements/increments the count, and posts `.flightDataChanged`.
- Five per-flight save methods (`saveFlight`, `updateFlight`, `updateScheduledFlightWithActualData`, `deleteFlight`, `deleteFlights`) now wrap their `try viewContext.save()` in `beginUndoGrouping` / `endUndoGrouping` and increment `undoableChangeCount` on success.
- All background-context methods (`updateFlightsBulk`, `saveFlightsBatch`, async fetches), bulk/destructive operations (`clearAllFlights`, `deleteImportSession`, `duplicateFlights`, `regenerateAllFlightUUIDs`), and migration methods are unchanged.

### FlightsView.swift and FlightsSplitView.swift (identical changes)
- `@State private var undoCount: Int = 0` and `@State private var canRedo: Bool = false` added.
- `refreshUndoState()` reads `FlightDatabaseService.shared.undoableChangeCount` and `.canRedo`.
- `undoBar` `@ViewBuilder` computed property: only visible when `undoCount > 0`; styled to match `filterStatusBanner` (orange accent, `.ultraThinMaterial`, `RoundedRectangle(cornerRadius: 12)`); secondary label uses `.footnote`; Redo button (grey) shown only when `canRedo`; Undo button (orange) always shown when bar is visible.
- `undoBar` placed directly below `filterStatusBanner` in each view's body VStack.
- `.animation(.spring(response: 0.3, dampingFraction: 0.7), value: undoCount)` added alongside existing animation modifiers.
- `refreshUndoState()` called in `.onAppear`, in `.onReceive(.flightDataChanged)`, and in a new `.onReceive(NSManagedObjectContextDidSave)`.
- Bulk delete confirmation alert message updated from "This action cannot be undone." to "This will delete the selected entries." in both files.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED
- Block-Time/Services/FlightDatabaseService.swift — modified (undoManager wiring + 5 groupings)
- Block-Time/Views/Screens/FlightsView.swift — modified (undoBar + refreshUndoState)
- Block-Time/Views/Screens/FlightsSplitView.swift — modified (undoBar + refreshUndoState)
- Commits: 884dfff (FlightDatabaseService), cccb7ad (views)
