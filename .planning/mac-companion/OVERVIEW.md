# Mac Companion — Overview & Phase Map

_Branch: `mac-companion-rebuild` (forked from `main`; `main` shipping app stays untouched)_

## The decision

Build the Mac app as a **native macOS SwiftUI target** that shares one **`BlockTimeKit` Swift Package** with the iOS app. The package holds the Core Data + CloudKit data layer and all pure-logic services/models; each app target holds only its own UI.

This replaces the current `Mac_Companion_Build` branch's approach, which duplicated ~4,800 lines of business logic into `Mac*` service copies and stood up a second, independent Core Data stack. That duplication — not the UI — is what made the branch feel like it needed a rewrite. We keep the branch's genuinely good Mac UI work (the AppKit `NSTableView` spreadsheet, edit panel, filters, settings) and throw away the duplicated logic.

Ships on the **existing Core Data + CloudKit stack** — no SwiftData rewrite, no new bundle ID.

Full rationale and file-level findings: `../research/MAC-COMPANION-ASSESSMENT.md`.

## Phases

- **Phase 0 — Extract `BlockTimeKit` shared core.** Move data layer + logic out of the iOS app into the package; iOS app builds against it. Plan: `PHASE-0-SHARED-CORE.md`. ← start here
- **Phase 1 — Rebase Mac UI onto the core.** Cherry-pick the Mac UI from `Mac_Companion_Build`; delete every `Mac*` duplicate service and the duplicate Core Data stack; point the Mac target at `BlockTimeKit`. Removes ~4,800 lines, fixes sync risk.
- **Phase 2 — Spreadsheet editing.** Make the `NSTableView` columns editable (cell-by-cell entry) validating through the shared service; wire bulk edit reusing the iOS `BulkEditSheet` logic. Keep the detail-panel entry path too.
- **Phase 3 — Import.** Mac import window reusing `FileImportService` / `UnifiedRosterParser` / `LogbookImportService` from the core.
- **Phase 4 — Sync verification + ship.** Prove Mac↔iOS round-trip on one shared stack; notarize / App Store.

## The test that matters most

Once iOS and Mac share one `BlockTimeKit` Core Data + CloudKit stack: **edit on Mac → confirm it appears on iOS, and the reverse.** That's the proof the architecture is sound and the thing the old two-stack branch could never reliably pass.

## Workflow notes

- One phase at a time; build between increments; commit each green step.
- Per `CLAUDE.md`: don't remove features without approval; Nelson runs device builds.
- Phase plans 1–4 will be written when each is reached, following the Phase 0 format.
