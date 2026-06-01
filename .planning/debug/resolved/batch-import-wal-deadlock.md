---
status: resolved
trigger: "Large batch import (7252 flights) hangs indefinitely at Starting batch save with CoreData WAL deadlock errors"
created: 2026-06-01T00:00:00Z
updated: 2026-06-01T00:00:02Z
---

## Current Focus

hypothesis: CONFIRMED (revised) — NSBatchDeleteRequest fix resolved the viewContext reader lock, but CloudKit NSCloudKitMirroringDelegate in-flight operations (firing every ~0.1s with "Request Rate Limited" retries) hold their own SQLite read transactions throughout the batch save. disableCloudKitSync() only sets cloudKitContainerOptions=nil on the store description — it does NOT stop already-running operations. Per-object saveFlightsBatch grows WAL to checkpoint threshold; checkpoint blocks on those CloudKit readers. Deadlock.
test: completed
expecting: NSBatchInsertRequest in saveFlightsBatch (fast path when store is empty) writes directly at SQL layer — produces far fewer WAL pages than per-object inserts, eliminating the WAL threshold trigger entirely.
next_action: verify fix with user

## Symptoms

expected: A restore-from-backup of 7252 flights completes within ~60 seconds and shows a success dialog
actual: App freezes indefinitely after "Database: Starting batch save of 7252 flights" log line. Never reaches success dialog. CoreData WAL errors appear after ~90 seconds. Works fine for ~5000 flights.
errors:
  - CoreData: fault: Illegal attempt to return an error without one in NSSQLCore.m:2706 (repeating)
  - Publishing changes from background threads is not allowed
reproduction: Restore from backup with 7250+ flights using replace mode via BackupsView → quickRestoreFromBackup → FileImportService.importFlights → saveFlightsBatch
started: Pre-dates undo feature (confirmed on commit 790fb7e too). Real user also reports needing to split imports into smaller chunks.

## Eliminated

- hypothesis: chunked saves (every 500 rows) would prevent WAL overflow
  evidence: chunk saves were already in place (line 1574) but hang persists — the WAL is not the cause; the viewContext reader lock is the cause
  timestamp: 2026-06-01

- hypothesis: automaticallyMergesChangesFromParent=false + reset() prevents viewContext from holding locks
  evidence: reset() is called at line 279 (suspendUndoForBatchImport) BEFORE clearAllFlights re-populates the context at line 1287-1296. The reset() that should matter happens TOO EARLY.
  timestamp: 2026-06-01

- hypothesis: NSBatchDeleteRequest + viewContext.reset() in clearAllFlights is sufficient to fix the hang
  evidence: Console log confirms delete + WAL checkpoint both succeed. Hang still occurs at batch save. CloudKit mirroring delegate operations are the remaining readers — they are not affected by the viewContext fix.
  timestamp: 2026-06-01

- hypothesis: sleep/drain after disableCloudKitSync() stops in-flight CloudKit operations
  evidence: 2s sleep already tried — not enough. CloudKit retry timers are ~44s. This approach is impractical.
  timestamp: 2026-06-01

## Evidence

- timestamp: 2026-06-01
  checked: FileImportService.swift importFlights() lines 261-279
  found: Call order in replace mode: (1) suspendUndoForBatchImport() [calls viewContext.reset()], (2) disableCloudKitSync(), (3) clearAllFlights(), (4) sleep 0.5s, (5) sleep 2.0s, (6) saveFlightsBatch()
  implication: The reset() in step 1 is undone by clearAllFlights() in step 3 which loads all flights back into viewContext via a standard fetch-and-delete pattern

- timestamp: 2026-06-01
  checked: FlightDatabaseService.swift clearAllFlights() lines 1287-1308
  found: Uses viewContext.fetch(FlightEntity.fetchRequest()) then forEach { viewContext.delete($0) } then viewContext.save(). No NSBatchDeleteRequest. No viewContext.reset() after save.
  implication: For 7252 flights this loads 7252 managed objects into viewContext row cache. After the save, those objects (now in deleted state) remain in the context's object graph. NSManagedObjectContext holds an open SQLite read connection for fetched objects until reset() is called.

- timestamp: 2026-06-01
  checked: FlightDatabaseService.swift lines 279, 289 — all reset() call sites
  found: reset() only called in suspendUndoForBatchImport() and resumeUndoAfterBatchImport(). Never after clearAllFlights().
  implication: No reset() is ever called between clearAllFlights() and saveFlightsBatch(), so viewContext holds open read transaction throughout the entire batch save.

- timestamp: 2026-06-01
  checked: Entire codebase grep for NSBatchDeleteRequest
  found: Not used anywhere in Services/
  implication: clearAllFlights() is the only delete-all path and it has never used the batch SQL path that bypasses the object graph.

- timestamp: 2026-06-01
  checked: WAL deadlock mechanics (NSSQLCore.m:2706)
  found: Core Data's PostSaveMaintenance calls wal_checkpoint(TRUNCATE) when WAL grows. SQLite's WAL checkpoint cannot proceed while any reader holds a read transaction. viewContext's open read transaction from clearAllFlights() is that reader. Background context performAndWait blocks waiting for the checkpoint to complete. Deadlock.
  implication: The threshold (~5000 flights works, 7252 doesn't) is because 7252 flights × ~row size crosses the ~8MB WAL threshold that triggers checkpoint, while 5000 doesn't.

- timestamp: 2026-06-01
  checked: Console log from second test run (user provided)
  found: Line 83: NSBatchDeleteRequest removed 1500 flights (delete IS working). Line 97: WAL checkpoint succeeds after delete (Log size: 1097, checkpointed: 1097 — WAL clean before save). Lines 103–216: NSCloudKitMirroringDelegate export operations firing continuously every ~0.1s with "Request Rate Limited" retries during the batch save. Line 225: "Starting batch save of 7252 flights" — then hang.
  implication: The viewContext reader lock fix worked. The CloudKit mirroring delegate's already-running in-flight operations are the new blocker — they hold their own SQLite read transactions that prevent WAL checkpoint during the per-object chunk saves.

- timestamp: 2026-06-01
  checked: disableCloudKitSync() implementation (lines 306-330)
  found: Sets cloudKitContainerOptions = nil on the store description. This only affects future operations — it does NOT stop NSCloudKitMirroringDelegate operations that are already in-flight. No public API exists to stop these operations synchronously.
  implication: Any sleep/drain approach after disableCloudKitSync() would need to exceed the CloudKit retry timer (~44s as observed) — impractical. Fix must eliminate the WAL threshold trigger instead.

## Resolution

root_cause: Two independent but cooperating causes:
  (1) clearAllFlights() was loading 7252 objects into viewContext (fetch-then-delete), leaving an open SQLite read transaction — FIXED by NSBatchDeleteRequest + viewContext.reset().
  (2) REAL CAUSE of continued hang: NSCloudKitMirroringDelegate in-flight export operations continue firing every ~0.1s (with "Request Rate Limited" retries and ~44s retry timers) even after disableCloudKitSync() sets cloudKitContainerOptions=nil. Each in-flight operation holds a SQLite read transaction on the store coordinator. Per-object saveFlightsBatch chunk-saves grow the WAL past the ~8MB checkpoint threshold. wal_checkpoint(TRUNCATE) cannot proceed while CloudKit readers hold transactions. Background context performAndWait blocks. Deadlock.

fix: NSBatchInsertRequest fast path in saveFlightsBatch. When all duplicate indexes are empty (i.e., the store is empty after clearAllFlights — always the case in replace/restore mode), skip the per-object insert loop entirely and use NSBatchInsertRequest(entityName:objects:) with a dictionary array. NSBatchInsertRequest operates at the SQL layer, does not create NSManagedObjects, does not trigger KVO, and produces far fewer WAL pages than per-object inserts — eliminating the WAL threshold trigger that caused the CloudKit reader deadlock. Normal import mode (non-empty store) still uses the existing per-object loop with duplicate detection.

verification: User confirmed — 7252 flights imported in 3 seconds, no hang, no WAL errors, success dialog shown, all flights loaded in UI.
files_changed: [Block-Time/Services/FlightDatabaseService.swift]
