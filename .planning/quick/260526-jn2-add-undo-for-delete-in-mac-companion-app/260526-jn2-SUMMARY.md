---
phase: quick-260526-jn2
plan: "01"
subsystem: mac-companion
tags: [undo, delete, nsundomanager, core-data, mac]
dependency-graph:
  requires: []
  provides: [undo-delete-flight-mac]
  affects: [Block-Time-Mac/MacLogbookViewModel.swift, Block-Time-Mac/MacFlightEditView.swift]
tech-stack:
  added: []
  patterns: [NSUndoManager.registerUndo(withTarget:), value-type snapshot for undo safety]
key-files:
  modified:
    - Block-Time-Mac/MacLogbookViewModel.swift
    - Block-Time-Mac/MacFlightEditView.swift
decisions:
  - Capture undo manager before Task to avoid losing key-window reference on dismiss
  - Snapshot built from flights array first (already loaded), fallback to entity fetch
  - No redo registration — single-level undo only per plan scope
metrics:
  duration: ~5 minutes
  completed: 2026-05-26
  tasks-completed: 2
  tasks-total: 2
  files-modified: 2
---

# Quick Task 260526-jn2: Add Undo for Delete in Mac Companion App Summary

**One-liner:** NSUndoManager single-level undo for Mac delete-flight using value-type MacEditableFlight snapshot + reinsertFlight re-insert path.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add snapshot + undo registration to deleteFlight | 97e50d3 | MacLogbookViewModel.swift |
| 2 | Wire commitDelete to pass window undo manager; update alert | 97e50d3 | MacFlightEditView.swift |

## What Was Built

### MacLogbookViewModel.swift

`deleteFlight(id:undoManager:)` — extended signature with `undoManager: UndoManager? = nil` (default nil keeps existing callers working without change).

Before deletion, the method locates a `MacFlightRow` by id from the already-loaded `flights` array. If not found there (edge case), it falls back to `MacFlightRow(entity:)` on the fetched managed object. A `MacEditableFlight(from: row)` snapshot (a value type, Sendable-safe) is captured before the entity is deleted.

After a successful `ctx.save()`, the undo action is registered:
```swift
undoManager?.registerUndo(withTarget: self) { vm in
    Task { @MainActor in
        _ = await vm.reinsertFlight(snapshot)
    }
}
undoManager?.setActionName("Delete Flight")
```

`reinsertFlight(_ sector: MacEditableFlight)` mirrors `saveFlight`'s insert path: guards the id does not already exist, calls `NSEntityDescription.insertNewObject`, `applyFields(isNew: true)`, `ctx.save()`, and `reload()`. No redo is registered.

### MacFlightEditView.swift

`commitDelete()` now captures `NSApp.keyWindow?.undoManager` synchronously on the main actor before the `Task` block (and before `onDismiss()` dismisses the panel, which would cause the window to lose key status):

```swift
let undoManager = NSApp.keyWindow?.undoManager
Task {
    _ = await viewModel.deleteFlight(id: row.id, undoManager: undoManager)
    onDismiss()
}
```

Alert message updated from "This will permanently delete this flight. This cannot be undone." to "This will delete this flight. You can undo this from the Edit menu (⌘Z)." — alert and both buttons (Delete/Cancel) are untouched.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `Block-Time-Mac/MacLogbookViewModel.swift` — FOUND (modified)
- `Block-Time-Mac/MacFlightEditView.swift` — FOUND (modified)
- Commit 97e50d3 — FOUND
