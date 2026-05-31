---
phase: 09-crew-contact-feature
plan: 03
subsystem: backup
tags: [backup, csv, crew-contacts, import, export]

# Dependency graph
requires:
  - CrewContactService.fetchAllAsBackup() (09-01)
  - CrewContactBackup Codable struct (09-01)
provides:
  - exportToCSV writes #CONTACTS: JSON line when crew contacts exist
  - quickRestoreFromBackup merges crew contacts using longer-notes-wins rule
  - AutomaticBackupService captures crew contacts on main thread before background dispatch
affects:
  - Block-Time/Services/FileImportService.swift
  - Block-Time/Services/AutomaticBackupService.swift

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "While-loop prefix stripping: all #-prefix metadata lines stripped before CSV parsing (extensible for future additions)"
    - "Main-thread capture pattern: @MainActor service data captured before DispatchQueue.global dispatch"
    - "Longer-notes-wins merge rule: existing contact notes preserved unless backup has more detail"

key-files:
  created: []
  modified:
    - Block-Time/Services/FileImportService.swift
    - Block-Time/Services/AutomaticBackupService.swift

key-decisions:
  - "While-loop over if-chain for prefix stripping — extensible for future #-prefix metadata lines without touching this code again"
  - "crewContacts default parameter [] — all existing exportToCSV call sites continue to compile and run unchanged"
  - "Merge on restore (not replace) — longer notes wins; existing contacts not clobbered by older backup data"

requirements-completed: []

# Metrics
duration: 5 min
completed: 2026-05-31
---

# Phase 9 Plan 03: CSV Backup/Restore Extended with Crew Contacts Summary

**exportToCSV writes #CONTACTS: JSON line after #DEFINITIONS:; quickRestoreFromBackup uses a while-loop to strip all #-prefix lines and merges crew contacts with longer-notes-wins rule**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-31
- **Completed:** 2026-05-31
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `crewContacts: [CrewContactBackup] = []` parameter to `exportToCSV` — defaults to `[]` so all existing call sites are unaffected
- Backup CSV now writes `#CONTACTS:{json}` line immediately after `#DEFINITIONS:` line (or as first metadata line if no definitions exist)
- Replaced single-if `#DEFINITIONS:` prefix strip in `quickRestoreFromBackup` with a while-loop that strips ALL `#`-prefix lines — handles current and future metadata lines in one pass
- Restore merges crew contacts: if name exists, only overwrites notes if backup notes are longer; new names are inserted directly
- `AutomaticBackupService.performBackup` captures `CrewContactService.shared.fetchAllAsBackup()` on the main thread before `DispatchQueue.global` dispatch — safe because `CrewContactService` is `@MainActor`

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend exportToCSV and update quickRestoreFromBackup** - `81ea41b` (feat)
2. **Task 2: Update AutomaticBackupService to capture crew contacts on main thread** - `baf2c59` (feat)

## Files Modified

- `Block-Time/Services/FileImportService.swift` — exportToCSV new parameter + #CONTACTS: write; quickRestoreFromBackup while-loop + contacts merge
- `Block-Time/Services/AutomaticBackupService.swift` — crewContactsSnapshot capture + passed to exportToCSV

## Decisions Made

- While-loop over if-chain for prefix stripping: extensible for future `#`-prefix lines without touching restore logic again
- Default `crewContacts: []` on exportToCSV: zero impact on existing call sites (manual export, WebCIS paths, etc.)
- Longer-notes-wins merge: preserves user-enriched notes on the device even after restoring an older backup

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CSV backup/restore fully extended with crew contacts
- Plan 04 (UI layer) can now rely on a complete data + backup foundation
- No blockers

## Self-Check

- [x] `Block-Time/Services/FileImportService.swift` modified — crewContacts parameter and #CONTACTS: lines present
- [x] `Block-Time/Services/AutomaticBackupService.swift` modified — crewContactsSnapshot before DispatchQueue.global
- [x] Commit `81ea41b` exists (Task 1)
- [x] Commit `baf2c59` exists (Task 2)

## Self-Check: PASSED

---
*Phase: 09-crew-contact-feature*
*Completed: 2026-05-31*
