# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## batch-import-wal-deadlock — Large batch import hangs due to WAL checkpoint deadlock with CloudKit readers
- **Date:** 2026-06-01
- **Error patterns:** WAL deadlock, NSSQLCore, batch save hang, NSBatchDeleteRequest, wal_checkpoint, NSCloudKitMirroringDelegate, Request Rate Limited, batch import, restore, StartingBatchSave, 7252 flights, CoreData fault, Illegal attempt to return an error
- **Root cause:** Two causes: (1) clearAllFlights() loaded all objects into viewContext (fetch-then-delete) leaving an open SQLite read transaction — fixed by NSBatchDeleteRequest + viewContext.reset(). (2) NSCloudKitMirroringDelegate in-flight export operations continue firing every ~0.1s even after disableCloudKitSync(); each holds a SQLite read transaction; per-object chunk-saves grow the WAL past ~8MB threshold; wal_checkpoint(TRUNCATE) cannot proceed while CloudKit readers are active; background context performAndWait deadlocks.
- **Fix:** NSBatchInsertRequest fast path in saveFlightsBatch when the store is empty (replace/restore mode). Operates at SQL layer, far fewer WAL pages, eliminates the checkpoint threshold trigger. Per-object loop with duplicate detection retained for non-empty-store (normal import) mode.
- **Files changed:** Block-Time/Services/FlightDatabaseService.swift
---
