# Mac Companion — Overview & Phase Map

_Branch: `mac-companion-rebuild` (forked from `main`; `main` shipping app stays untouched)_

## The decision

Build the Mac app as a **native macOS SwiftUI target** that shares one **`BlockTimeKit` Swift Package** with the iOS app. The package holds the Core Data + CloudKit data layer and all pure-logic services/models; each app target holds only its own UI.

This replaces the current `Mac_Companion_Build` branch's approach, which duplicated ~4,800 lines of business logic into `Mac*` service copies and stood up a second, independent Core Data stack. That duplication — not the UI — is what made the branch feel like it needed a rewrite. We keep the branch's genuinely good Mac UI work (the AppKit `NSTableView` spreadsheet, edit panel, filters, settings) and throw away the duplicated logic.

Ships on the **existing Core Data + CloudKit stack** — no SwiftData rewrite, no new bundle ID.

Full rationale and file-level findings: `../research/MAC-COMPANION-ASSESSMENT.md`.

## Phases

- **Phase 0 — Extract `BlockTimeKit` shared core.** ✅ Done. Data layer + logic live in the package (48 files); iOS app builds against it. Plan: `PHASE-0-SHARED-CORE.md`.
- **Phase 1 — Rebase Mac UI onto the core.** ✅ Done. Mac UI on the shared core; `Mac*` duplicate services and the duplicate Core Data stack gone; build + tests pass. Plan: `PHASE-1-REBASE-MAC-UI.md`.
- **Phase 2 — Spreadsheet editing.** ← active. Make the `NSTableView` columns editable (cell-by-cell entry) validating through the shared service; wire bulk edit by extracting `applyChanges` into the core and calling `updateFlightsBulk`. Keep the detail-panel entry path too. Plan: `PHASE-2-SPREADSHEET-EDITING.md`.
- **Phase 3 — Import.** Mac import window reusing `FileImportService` / `UnifiedRosterParser` / `LogbookImportService` from the core.
- **Phase 4 — Sync verification + ship.** Prove Mac↔iOS round-trip on one shared stack; notarize / App Store.

## The test that matters most

Once iOS and Mac share one `BlockTimeKit` Core Data + CloudKit stack: **edit on Mac → confirm it appears on iOS, and the reverse.** That's the proof the architecture is sound and the thing the old two-stack branch could never reliably pass.

## Workflow notes

- One phase at a time; build between increments; commit each green step.
- Per `CLAUDE.md`: don't remove features without approval; Nelson runs device builds.
- Phase plans 1–4 will be written when each is reached, following the Phase 0 format.
