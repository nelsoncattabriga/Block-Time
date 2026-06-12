# Phase 0 — Extract `BlockTimeKit` Shared Core

_Branch: `mac-companion-rebuild` • Target executor: Claude Code CLI_

## Goal

Move the data layer and all pure-logic services/models out of the `Block-Time` app target and into the `BlockTimeKit` Swift Package, so the iOS app and the future Mac app both depend on **one** copy. No behaviour changes. The iOS app must build, run, and pass its tests against the package before Phase 1 begins.

**Definition of done:** iOS app compiles and runs with the moved code living in `BlockTimeKit`; Core Data + CloudKit still load; no feature removed. (Per `CLAUDE.md`: do not build unless Nelson asks — leave the final device build to him.)

## Hard rules (from `CLAUDE.md`)

- Do **not** remove any existing feature, button, logic, or behaviour without explicit approval.
- Swift 6 strict concurrency; prefer `@Observable` over `ObservableObject`; `async/await`; `guard` early exits.
- Work in small, compiling increments. Commit after each green step.
- Nelson builds locally — do not run device builds; you may run `swift build` on the package and ask him to build the app in Xcode.

---

## Key facts established (don't re-derive)

- Data layer is **Core Data + CloudKit**: `NSPersistentCloudKitContainer(name: "FlightDataModel")`, app group `group.com.thezoolab.blocktime`, CloudKit container `iCloud.com.thezoolab.blocktime`.
- Core Data model `FlightDataModel.xcdatamodeld` uses **`codeGenerationType="class"`** (Xcode auto-generates `FlightEntity` etc.). This must change — see the Core Data section, it's the riskiest step.
- `FlightDatabaseService` (~3,600 lines) is the crown jewel. It imports `SwiftUI` but only uses `ObservableObject` + `@Published` — both are **Combine**, not SwiftUI. The SwiftUI import is incidental and removable.
- Several other "UI-flagged" logic services (`FlightAwareService`, `CustomCounterService`, `AircraftFleetService`, `+InsightsQueries`) likewise import SwiftUI but use only Combine/Observation → imports removable.
- 20 services use the `static let shared` singleton pattern. **Keep it** in Phase 0; do not refactor to dependency injection yet (minimise churn).
- `BlockTimeKit/` currently has no `Package.swift` and no sources — you are creating the package from scratch.
- iOS deployment target: 18.6. Set the package to `iOS 18.6, macOS 14` (adjust macOS to match the Mac target later).

---

## File classification

### MOVE to `BlockTimeKit` (pure logic — Foundation / CoreData / Combine / Observation only)

**Models** → `Sources/BlockTimeKit/Models/`
`Airline`, `CustomCounterDefinition`, `FRMSData`, `FlightEntity+Extensions`, `FlightLogbook`, `FlightTimePosition`, `LH_Operational_FltDuty`, `LH_Planning_FltDuty`, `SH_Operational_FltDuty`, `SH_Planning_FltDuty`, `SH_NZ_Operational_FltDuty`, `SH_NZ_Planning_FltDuty`, `Notifications`, `TimeCreditType`, `TimeInterval+Extensions`, `WidgetFlightEntry`

**Services** → `Sources/BlockTimeKit/Services/`
`APIKeys`, `AeroDataBoxService`, `AircraftFleetService`, `AppUpdateService`, `AirportService`, `CalendarExportService`, `CalendarExportSettings`, `CloudKitSettingsSyncService`, `CrewContactService`, `FRMSCalculationService`, `FileImportService`, `LHRosterParserService`, `LogbookImportService`, `LogbookPDFTotals`, `NightCalcService`, `PlannedFlightService`, `PurchaseService`, `RosterParserService`, `TimeCalculationManager`, `UnifiedRosterParser`, `UserDefaultsService`, `WidgetDataWriter`, `CustomCounterService`, `FlightAwareService`

**Data layer (move LAST, together with the Core Data model)** → `Sources/BlockTimeKit/Data/`
`FlightDatabaseService`, `FlightDatabaseService+InsightsQueries`, `FlightDataModel.xcdatamodeld`

> For each of these four "SwiftUI-flagged but Combine-only" files — `FlightDatabaseService`, `+InsightsQueries`, `FlightAwareService`, `CustomCounterService` — replace `import SwiftUI` with `import Combine` (or `import Observation`) and confirm it still compiles.

### STAY in the `Block-Time` app target (genuinely iOS-UI-bound)

`AppState` (SwiftUI), `AutomaticBackupService` (UIKit), `HapticManagerService` (UIKit), `LogManager` (UIKit), `MigrationImportService`, `PhotoSavingService` (Photos/UIKit), `TextRecognitionService` (UIKit/Vision), `ThemeService` (SwiftUI), `LogbookPDFLayout` / `LogbookPDFPageDrawer` / `LogbookPDFRenderer` (UIKit graphics), and the SwiftUI model files `DashboardCardID`, `DashboardConfiguration`, `LogbookSettings`, `StatCardType`.

> PDF rendering and these UI services are not needed for the Mac companion's first version. Leave them in the app. If the Mac app later needs PDF export, abstract the renderer behind a protocol in `BlockTimeKit` then.

---

## Core Data model relocation (the one risky step — read fully)

Moving `.xcdatamodeld` into a Swift Package breaks two things that Xcode normally does invisibly. Both must be handled:

1. **Codegen.** With `codeGenerationType="class"`, Xcode generates the `NSManagedObject` subclasses for the app target. A package can't rely on that.
   - In the model editor, set every entity's **Codegen → Manual/None**.
   - Generate the subclasses once (Editor ▸ Create NSManagedObject Subclass), then **move the generated `.swift` files into the package** (`Sources/BlockTimeKit/Data/Generated/`) and mark the classes/properties `public` where the app needs them.
   - Keep `representedClassName` matching the class names (e.g. `FlightEntity`).

2. **Model loading.** `NSPersistentCloudKitContainer(name: "FlightDataModel")` finds the model by searching the **main app bundle**. Once the `.momd` lives in the package, that lookup fails. Load the model explicitly from the package bundle and pass it in:

```swift
// In BlockTimeKit
public enum BlockTimeModel {
    public static let managedObjectModel: NSManagedObjectModel = {
        guard let url = Bundle.module.url(forResource: "FlightDataModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("FlightDataModel.momd not found in BlockTimeKit bundle")
        }
        return model
    }()
}

// Then change container init from:
//   NSPersistentCloudKitContainer(name: "FlightDataModel")
// to:
//   NSPersistentCloudKitContainer(name: "FlightDataModel", managedObjectModel: BlockTimeModel.managedObjectModel)
```

3. **Resource declaration.** In `Package.swift`, add the model as a processed resource: `resources: [.process("Data/FlightDataModel.xcdatamodeld")]`.

4. **Entitlements stay in the app targets.** The app group and CloudKit container identifiers are configured per-target in entitlements — leave them there. The package code references the identifiers by string; keep them as-is for now.

> ⚠️ Do not change the model name, entity names, attribute names, or CloudKit record types. The existing iCloud data and the schema in the CloudKit console must keep matching, or live user data won't sync.

---

## Package.swift starting point

`BlockTimeKit/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BlockTimeKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "BlockTimeKit", targets: ["BlockTimeKit"]),
    ],
    targets: [
        .target(
            name: "BlockTimeKit",
            resources: [
                .process("Data/FlightDataModel.xcdatamodeld")
            ]
        ),
        .testTarget(name: "BlockTimeKitTests", dependencies: ["BlockTimeKit"]),
    ]
)
```

(`platforms: .iOS(.v18)` — bump deployment specifics in the app's build settings, which already pin 18.6.)

---

## Execution order (small, compiling increments — commit after each ✅)

Work leaf-first so each move compiles before the next.

1. **Scaffold the package.** Create `Package.swift` + empty `Sources/BlockTimeKit/BlockTimeKit.swift`. Run `swift build` in `BlockTimeKit/`. ✅
2. **Add as local package to the project.** In Xcode: add `BlockTimeKit` as a local Swift Package and link it to the `Block-Time` app target (and to `BlockTimeWidgetExtension` if it shares any moved file — `WidgetDataWriter`/`WidgetFlightEntry` are shared, so link the widget too). ✅
3. **Move leaf models first:** `TimeInterval+Extensions`, `TimeCreditType`, `FlightTimePosition`, `Airline`, `FRMSData`, the FltDuty model files, `Notifications`, `CustomCounterDefinition`, `FlightLogbook`, `WidgetFlightEntry`. Add `public` as the compiler demands. Build the app. ✅
4. **Move pure services with no Core Data:** `TimeCalculationManager`, `NightCalcService`, `FRMSCalculationService`, `AirportService`, `AeroDataBoxService`, `FlightAwareService` (drop SwiftUI import), `APIKeys`, `AppUpdateService`, `CalendarExportService`, `CalendarExportSettings`, `CloudKitSettingsSyncService`, `CrewContactService`, `UserDefaultsService`, `PurchaseService`, the roster/import parsers (`RosterParserService`, `LHRosterParserService`, `UnifiedRosterParser`, `LogbookImportService`, `FileImportService`), `LogbookPDFTotals`, `CustomCounterService` (drop SwiftUI import). Build. ✅
5. **Move the Core Data model** per the section above (codegen → manual, model into package, `Bundle.module` loader). Build the package alone first. ✅
6. **Move the data layer:** `FlightEntity+Extensions`, `AircraftFleetService`, `PlannedFlightService`, `WidgetDataWriter`, then `FlightDatabaseService` + `+InsightsQueries` (swap SwiftUI→Combine). Wire the container to `BlockTimeModel.managedObjectModel`. Build the app. ✅
7. **Add `import BlockTimeKit`** to every app file that referenced a moved type, and make the moved public API `public`. Let the compiler drive this — fix errors until green. ✅
8. **Run tests.** `Block-TimeTests` must still pass. Move any tests that now target package code into `BlockTimeKitTests`. ✅

---

## Access-control strategy

Moving into a package means every type/member the app touches needs `public`. Don't try to predict it — let the compiler tell you. Practical loop: build → for each "X is inaccessible" error, add `public` (and `public init` for structs the app constructs) → rebuild. Keep `static let shared` singletons `public`. Default to the smallest surface that compiles; avoid blanket-public.

## Concurrency note

The project targets Swift 6 strict concurrency. Moving `@MainActor`-annotated singletons across the module boundary can surface new isolation warnings. Keep existing `@MainActor` annotations as-is; if the compiler flags Sendable/isolation issues on a moved type, prefer matching the existing annotation over restructuring. Log anything that needs a real concurrency fix as a follow-up rather than redesigning in Phase 0.

---

## Verification (the gate before Phase 1)

1. `swift build` succeeds in `BlockTimeKit/`.
2. App target compiles in Xcode (Nelson runs this).
3. App launches; existing flights load from Core Data; CloudKit sync indicator behaves as before.
4. `Block-TimeTests` pass.
5. `git diff --stat` shows files **moved** (deletions in `Block-Time/`, additions in `BlockTimeKit/`) with no unrelated edits.
6. **No feature removed** — spot-check FRMS calc, add/edit flight, import, PDF export, widget.

## What Phase 0 explicitly does NOT do

- No SwiftData migration, no new bundle ID, no sync-mechanism change. (Companion ships on the existing, proven Core Data + CloudKit stack.)
- No DI refactor of singletons.
- No Mac code yet — that's Phase 1 (delete the duplicate `Mac*` services, point the Mac target at `BlockTimeKit`).

---

## Suggested Claude Code kickoff prompt

> Read `.planning/mac-companion/PHASE-0-SHARED-CORE.md`. We're on branch `mac-companion-rebuild`. Execute Phase 0 step 1 only: scaffold the `BlockTimeKit` Swift Package (`Package.swift` + empty source) and confirm `swift build` passes. Do not move any app files yet. Stop and report when step 1 is green.

Drive it one numbered step at a time, building between each.
