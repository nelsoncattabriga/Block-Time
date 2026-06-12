# Phase 1 — Rebase the Mac UI onto the Shared Core

_Branch: `mac-companion-rebuild` • Prereq: Phase 0 complete (BlockTimeKit holds the data layer + logic) • Target executor: Claude Code CLI_

## Goal

Bring the Mac app's UI from the old `Mac_Companion_Build` branch onto this branch, **delete every duplicated `Mac*` service and the Mac's home-grown Core Data stack**, and make the Mac target consume `BlockTimeKit` instead. One data layer, one copy of the business logic, shared by both apps.

**Definition of done:** the `Block-Time-Mac` target builds against `BlockTimeKit`; the duplicate services are gone; the Mac app reads and writes flights through the shared `FlightDatabaseService`; no Mac UI feature lost. (Nelson runs the actual build.)

## Why this phase exists

The old branch worked but maintained a parallel universe: `MacLogbookViewModel` (~984 lines) stands up its **own** `NSPersistentCloudKitContainer(name: "FlightDataModel")` and does raw `NSManagedObject` / `NSFetchRequest` access, while `Mac*`-prefixed services re-implement logic the iOS app already has. That's ~4,800 lines of drift-prone duplication and the reason a commit on that branch reads *"core data not being synced FROM mac to ios yet."* Phase 1 removes it.

---

## What to KEEP from `Mac_Companion_Build` (the genuinely Mac-specific UI)

Bring these over (cherry-pick or copy from the old branch) — they are real Mac UI work, not duplication:

| File | Notes |
|---|---|
| `Block_Time_MacApp.swift` | App entry, `Settings` scene, ⌘N command. Keep. |
| `ContentView.swift` / `MacContentAreaView.swift` / `MacSidebarView.swift` | Window shell / layout. Keep. |
| `MacLogbookTableView.swift` | The AppKit `NSTableView` spreadsheet (frozen left + scrolling right). **The crown jewel — keep intact.** |
| `MacLogbookView.swift` | Hosts the table. Keep; rewire its data source (see below). |
| `MacFlightEditView.swift` / `MacDetailPanelView.swift` | Add/edit/delete panel. Keep; rewire saves to `FlightDatabaseService`. |
| `MacFilterPanelView.swift` / `MacFilterState.swift` | Filtering UI. Keep. |
| `MacSettingsView.swift` / `MacPickerViews.swift` | Settings. Keep; point at shared services. |
| `MacFlightSegmentPickerPopover.swift` / `MacFlightSearchHelpers.swift` | Keep. |
| `ColumnManagerPopover.swift` / `ColumnPreferences.swift` | Column show/hide/reorder. Keep (Mac-only UI state). |

## What to DELETE (duplicates — replace with `BlockTimeKit`)

| Delete from `Block-Time-Mac/` | Replace with (from `BlockTimeKit`) |
|---|---|
| `MacAircraftFleetService.swift` | `AircraftFleetService` |
| `MacNightCalcService.swift` | `NightCalcService` |
| `MacTimeCalculationManager.swift` | `TimeCalculationManager` |
| `MacCustomFieldService.swift` + `MacCustomCounterDefinition.swift` | `CustomCounterService` + `CustomCounterDefinition` |
| `MacCrewNameService.swift` | iOS crew-name store — **confirm the iOS equivalent first** (likely `UserDefaultsService` or a crew helper; it reads the same UserDefaults + KVS keys). If iOS has no shared service for this, move that logic into `BlockTimeKit` rather than keeping a Mac copy. |
| `AeroDataBoxService.swift` (copy) | `AeroDataBoxService` |
| `AirportService.swift` (copy) | `AirportService` |
| `FlightAwareService.swift` (copy) | `FlightAwareService` |
| `APIKeys.swift` (copy) | `APIKeys` |

> Rule: if a `Mac*` file only re-implements logic, delete it and import the package type. If it contains any Mac-only behaviour, lift just that behaviour into the kept UI layer — don't keep a whole duplicate service for it.

---

## The central task: replace the Mac Core Data stack with `FlightDatabaseService`

`MacLogbookViewModel` currently:
- builds its own `NSPersistentCloudKitContainer`,
- fetches via `NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")` with string keys,
- inserts/saves with `NSEntityDescription.insertNewObject` + `ctx.save()`.

Rewire it to use the shared layer:
1. Replace the private `persistentContainer` with `BlockTimeKit`'s `FlightDatabaseService` (its `.shared` singleton, which already owns the container, app-group store URL, CloudKit options, and the event-change observers).
2. Replace raw fetches with `FlightDatabaseService`'s existing public fetch API and the **typed** `FlightEntity` (now generated in the package), instead of untyped `NSManagedObject` + string keys.
3. Route add / edit / delete / bulk operations through `FlightDatabaseService`'s existing methods so writes, undo, and sync are handled in one place.
4. Delete the Mac viewmodel's CloudKit event handling — `FlightDatabaseService` already does it.

> Check `FlightDatabaseService`'s public surface first (fetch, insert, update, delete, bulk-update, undo). If the Mac viewmodel needs an operation the service doesn't expose publicly, **add it to the service in `BlockTimeKit`** (so iOS benefits too) rather than reaching into Core Data from the Mac layer.

### Entitlements / identifiers (already correct — verify, don't change)

The Mac target's entitlements already match iOS: iCloud container `iCloud.com.thezoolab.blocktime`, app group `group.com.thezoolab.blocktime`, KVS `$(TeamIdentifierPrefix)com.thezoolab.blocktime`. Keep them. Because the Mac app now uses the **same** `FlightDatabaseService` store-location and container logic as iOS, sync becomes correct by construction. Do not rename anything.

---

## Execution order (small, compiling increments — commit each ✅)

1. **Link the package to the Mac target.** Add `BlockTimeKit` as a dependency of `Block-Time-Mac`. Add an empty `import BlockTimeKit` somewhere and confirm it resolves. ✅
2. **Bring over the kept UI files** from `Mac_Companion_Build` (cherry-pick the relevant commits, or copy the files listed in "KEEP"). Don't bring the `Mac*` duplicate services. Expect it not to compile yet. ✅
3. **Swap leaf services first:** delete `MacNightCalcService`, `MacTimeCalculationManager`, `MacAircraftFleetService`, the copied `AeroDataBoxService` / `AirportService` / `FlightAwareService` / `APIKeys`; update call sites to the `BlockTimeKit` types. ✅
4. **Custom fields + crew names:** delete `MacCustomFieldService` / `MacCustomCounterDefinition` / `MacCrewNameService`; wire to `CustomCounterService` / `CustomCounterDefinition` and the confirmed iOS crew-name store. ✅
5. **Rewire the data layer** (the central task above): point `MacLogbookViewModel` at `FlightDatabaseService`; switch the table's rows to typed `FlightEntity`; route writes through the service; delete the Mac container + event handlers. ✅
6. **Reconnect the UI:** edit panel saves, filter, settings, column manager all driving the shared layer. ✅
7. **Build + smoke test** (Nelson): list shows flights, add/edit/delete works, settings persist. ✅

---

## Verification (the gate before Phase 2)

1. `Block-Time-Mac` compiles against `BlockTimeKit`; **zero `Mac*` duplicate service files remain** (`git ls-files Block-Time-Mac | grep -E 'Mac(NightCalc|TimeCalc|AircraftFleet|CustomField|CrewName)'` returns nothing).
2. No second `NSPersistentCloudKitContainer` anywhere in `Block-Time-Mac` (`git grep -n NSPersistentCloudKitContainer Block-Time-Mac` returns nothing — the only one lives in `BlockTimeKit`).
3. App launches, lists existing flights, add/edit/delete/bulk all work.
4. **The sync test that matters:** add a flight on Mac → it appears on an iOS device on the same iCloud account, and vice-versa. This is the proof the architecture is sound.
5. No Mac UI feature dropped vs the old branch (table, frozen columns, filter, edit panel, online lookup, undo, settings, column manager).

## Out of scope for Phase 1

- Inline cell editing in the table (that's Phase 2 — Phase 1 keeps the existing edit-panel entry path).
- New import UI (Phase 3).
- PDF export on Mac (the iOS PDF renderer stayed in the app target; abstract later if needed).

## Suggested Claude Code kickoff prompt

> Read `.planning/mac-companion/PHASE-1-REBASE-MAC-UI.md`. We're on `mac-companion-rebuild`, Phase 0 done. Execute step 1 only: add `BlockTimeKit` as a dependency of the `Block-Time-Mac` target and confirm the import resolves. Do not bring over any Mac files yet. Stop and report when step 1 is green.

Then proceed one numbered step at a time, building between each. Before step 4, first report what the iOS app uses to store crew names so we wire to the right shared store.
