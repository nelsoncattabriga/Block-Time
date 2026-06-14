# Block-Time Mac Companion — Assessment & Roadmap

_Date: 2026-06-12_

## Verdict

**Salvage the branch, don't restart — but fix one core architectural flaw before going further.**

The `Mac_Companion_Build` branch contains real, hard-won, *correct* work that's worth keeping. It also contains the seed of the problem that's making you want to throw it away: it duplicates the iOS business logic instead of sharing it. The fix is not a rewrite — it's extracting a shared core so both apps stop drifting apart.

---

## What the branch actually is

- A **separate native macOS SwiftUI target** (`Block-Time-Mac`, ~8,360 lines), not Mac Catalyst.
- 43 commits ahead of `main`, 26 behind. Real features landed: data table, add/edit/delete flight panel, filter panel, full Settings, per-definition custom fields, online flight lookup, undo for delete.
- The table (`MacLogbookTableView`, 640 lines) is **AppKit `NSTableView`** wrapped in `NSViewRepresentable`, split into a frozen left table (date + flight number) and a scrolling right table. This is exactly the right foundation for a desktop spreadsheet.

## What's good — keep it

1. **Native target over Catalyst was the right call.** You want cell-by-cell editing, bulk edit, frozen columns, and keyboard-driven entry. Catalyst gives a cheap port but a second-rate grid and keyboard experience. Native is correct.
2. **The NSTableView grid.** Research confirms SwiftUI's `Table` still has no convenient inline cell editing; `NSTableView` gives editable cells, column resize, and reorder almost for free. The branch already built on it. This is ~640 lines you do **not** want to redo.
3. **The Mac UI layer generally** — `MacFlightEditView` (1,105 lines), `MacFilterPanelView`, `MacSettingsView`, column manager, undo. Genuinely Mac-specific work worth preserving.

## What's wrong — the root cause

1. **Massive logic duplication (~4,800 lines).** The branch forked the business logic into Mac copies: `MacNightCalcService`, `MacTimeCalculationManager`, `MacAircraftFleetService`, `MacCrewNameService`, `MacCustomFieldService`, plus verbatim copies of `AeroDataBoxService`, `FlightAwareService`, `AirportService`, `APIKeys`. Each is a parallel implementation that *will* drift from iOS. Every bug fix and feature has to be done twice. This is the reason the branch feels like it needs an overhaul.
2. **A second, independent Core Data stack.** `MacLogbookViewModel` spins up its own `NSPersistentCloudKitContainer(name: "FlightDataModel")` instead of reusing the iOS data layer (`FlightDatabaseService`, ~3,600 lines). A commit on the branch literally reads *"core data not being synced FROM mac to ios yet."* Two independently-written stacks must agree perfectly on schema and CloudKit semantics — sync correctness is unproven and fragile.
3. **The intended shared package was never populated.** `BlockTimeKit` exists as a Swift Package but contains a single file. The right structure was scaffolded and then bypassed.

---

## Recommended architecture

**Shared Swift Package core (`BlockTimeKit`) + thin per-platform UI.**

This is the "shared Swift core" option, and it's the right one *for this app specifically* because the business logic is large and identical across platforms.

Move into `BlockTimeKit`:
- The Core Data model (`FlightDataModel.xcdatamodeld`) + the persistence/stack layer (`FlightDatabaseService` and friends)
- All pure-logic services: time calc, night calc, FRMS calculation, roster/logbook parsers, aircraft fleet, crew, custom fields, import services
- The model types (`FlightEntity` extensions, FRMS models, etc.)

Then:
- **iOS app** imports `BlockTimeKit` for data + logic, keeps its iOS views.
- **Mac app** imports `BlockTimeKit` for data + logic, keeps *only* Mac-specific UI.

Result: one source of truth, one Core Data + CloudKit stack (so sync is correct by construction), features built once.

The companion ships on today's Core Data + CloudKit stack — the same one the iOS app already runs and syncs on. No data-layer rewrite is involved; this is purely an extraction so both apps share the existing, proven stack.

---

## Timely roadmap

Estimates assume focused solo work; adjust to your pace.

**Phase 0 — Extract the shared core (½–1 day).** Off a fresh branch from `main`: move the Core Data model + `FlightDatabaseService` + pure services + models into `BlockTimeKit`. Make the iOS app build against the package. This is the biggest structural move; everything else depends on it.

**Phase 1 — Rebase the Mac UI onto the core (1–2 days).** Cherry-pick / re-apply the Mac UI (table, edit panel, filter, settings) on top of the shared core. **Delete every `Mac*` duplicate service and the duplicate Core Data stack**; point the Mac app at `BlockTimeKit`'s `FlightDatabaseService`. This alone removes ~4,800 lines and fixes the sync risk.

**Phase 2 — Spreadsheet editing (2–3 days).** Make the `NSTableView` columns editable for cell-by-cell entry, validating writes through the shared service. Wire bulk edit by reusing the iOS `BulkEditSheet` logic (now shared). Keep the existing detail-panel entry as the alternative "standard" entry path you asked for.

**Phase 3 — Import (1–2 days).** Reuse `FileImportService` / `UnifiedRosterParser` / `LogbookImportService` from the shared core; build a Mac import window (CSV + roster/logbook).

**Phase 4 — Sync verification + ship.** The single most important test: edit on Mac → confirm it appears on iOS and vice-versa, now that both share one stack. Then notarization / App Store.

---

## The one test that matters most

Once iOS and Mac share a single `BlockTimeKit` Core Data + CloudKit stack: **make an edit on Mac, confirm it round-trips to iOS, and the reverse.** That's the proof the architecture is sound — and it's the thing the current branch could never reliably pass because it had two stacks.

## Sources

- [SwiftUI Table inline editing limitations — TextEditor cells in SwiftUI Table (Apple Developer Forums)](https://developer.apple.com/forums/thread/693236)
- [NSTableView single-cell editing (Apple Developer Forums)](https://developer.apple.com/forums/thread/689887)
- [macOS Programming: Working with Table Views (AppCoda)](https://www.appcoda.com/macos-programming-tableview/)
