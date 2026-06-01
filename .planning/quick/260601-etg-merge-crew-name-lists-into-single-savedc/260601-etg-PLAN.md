---
phase: quick
plan: 260601-etg
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Services/UserDefaultsService.swift
  - Block-Time/Services/CloudKitSettingsSyncService.swift
  - Block-Time/Services/MigrationImportService.swift
  - Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
  - Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
  - Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift
autonomous: true
requirements: [ETG-01]

must_haves:
  truths:
    - "All four crew fields (CAPTAIN, F/O, S/O 1, S/O 2) share one autocomplete list"
    - "Legacy names from savedCaptainNames/savedCoPilotNames/savedSONames are preserved on first run"
    - "Adding a name via any crew field updates the unified list"
    - "CloudKit syncs the new savedCrewNames key; legacy keys still sync for older app versions"
  artifacts:
    - path: "Block-Time/Services/UserDefaultsService.swift"
      provides: "savedCrewNames key, addCrewName, removeCrewName, migrateCrewNamesIfNeeded"
    - path: "Block-Time/ViewModels/FlightTimeExtractorViewModel.swift"
      provides: "Single @Published var savedCrewNames replacing three separate arrays"
    - path: "Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift"
      provides: "All ModernCrewField calls pass savedNames: viewModel.savedCrewNames"
  key_links:
    - from: "UserDefaultsService.migrateCrewNamesIfNeeded"
      to: "UserDefaults key crewNamesMigrated"
      via: "bool guard — runs once, never again"
    - from: "FlightTimeExtractorViewModel.savedCrewNames"
      to: "CrewOpsCard ModernCrewField savedNames"
      via: "viewModel.savedCrewNames binding"
---

<objective>
Merge three separate UserDefaults crew name lists (savedCaptainNames, savedCoPilotNames, savedSONames) into a single unified savedCrewNames list.

Purpose: Eliminates role-scoped crew lists so any crew name typed for any role appears in autocomplete for all roles — matching real-world pilot rosters where the same person flies different seats.
Output: One UserDefaults key, one @Published property, all crew fields sharing one list.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md

Invoke the `swiftui-pro` skill before writing any Swift/SwiftUI code.

Key types for reference:

AppSettings (UserDefaultsService.swift):
- Currently has: `savedCaptainNames: [String]`, `savedCoPilotNames: [String]`, `savedSONames: [String]`
- Add: `savedCrewNames: [String]`
- Keep the old three fields — they are read by CloudKitSettingsSyncService and MigrationImportService

UserDefaultsService (UserDefaultsService.swift):
- Keys enum: add `savedCrewNames = "savedCrewNames"`, `crewNamesMigrated = "crewNamesMigrated"`
- Add `migrateCrewNamesIfNeeded()` — unions all three legacy lists → savedCrewNames, clears old keys, sets flag
- Add `addCrewName(_ name: String) -> [String]`
- Add `removeCrewName(_ name: String) -> [String]`
- Make `addCaptainName`, `addCoPilotName`, `addSOName` delegate to `addCrewName` and return the unified list
- Make `removeCaptainName`, `removeCoPilotName`, `removeSOName` delegate to `removeCrewName` and return the unified list
- `loadSettings()` must call `migrateCrewNamesIfNeeded()` before reading, then populate `savedCrewNames`
- `saveSettings()` must write `savedCrewNames`

FlightTimeExtractorViewModel (FlightTimeExtractorViewModel.swift):
- Replace lines 201–203: `@Published var savedCrewNames: [String] = []` (remove savedCaptainNames/savedCoPilotNames)
- `savedSONames` at line 203 can also be removed (SO names are now in savedCrewNames)
- In `loadSettings()` path (line ~456): assign `savedCrewNames = settings.savedCrewNames`
  - Remove the three separate assignments for savedCaptainNames/savedCoPilotNames/savedSONames
- In `updateChangedSettings` switch (line ~507): add case `"savedCrewNames"` → `savedCrewNames = settings.savedCrewNames`
  - Remove cases for savedCaptainNames/savedCoPilotNames/savedSONames
- `addCaptainName`, `addCoPilotName`, `addSOName` methods (line ~1480): each should set `savedCrewNames = ...`
- `removeCaptainName`, `removeCoPilotName`, `removeSOName` methods: each should set `savedCrewNames = ...`
- `reloadSavedCrewNames()` (line ~1505): update to build union into `savedCrewNames` instead of three arrays

CloudKitSettingsSyncService (CloudKitSettingsSyncService.swift):
- Add `static let savedCrewNames = "cloud_savedCrewNames"` to CloudKeys enum
- In `syncToCloud()`: add `ubiquitousStore.set(settings.savedCrewNames, forKey: CloudKeys.savedCrewNames)`
  - KEEP the existing savedCaptainNames/savedCoPilotNames/savedSONames sync lines (backward compat)
- In `syncFromCloud()`: add a block reading `CloudKeys.savedCrewNames` → `settings.savedCrewNames`, changedKeys.insert("savedCrewNames")
  - KEEP existing blocks for savedCaptainNames/savedCoPilotNames/savedSONames

MigrationImportService (MigrationImportService.swift):
- Add `savedCrewNames: [String]?` to `MigrationSettings` struct
- In the restore block (~line 568): add `if let savedCrewNames = settings.savedCrewNames { ubiquitousStore.set(...) }`
  - Keep existing savedCaptainNames/savedCoPilotNames/savedSONames restore lines

CrewOpsCard.swift ModernManualEntryDataCard:
- CAPTAIN ModernCrewField: change `savedNames: viewModel.savedCaptainNames` → `savedNames: viewModel.savedCrewNames`
- F/O ModernCrewField: change `savedNames: viewModel.savedCoPilotNames` → `savedNames: viewModel.savedCrewNames`
- S/O 1 ModernCrewField: already uses `savedNames: viewModel.savedSONames` → change to `viewModel.savedCrewNames`
- S/O 2 ModernCrewField: same change

BulkEditSheet.swift:
- Line ~134: `savedNames: viewModel.savedCaptainNames` → `savedNames: viewModel.savedCrewNames`
- Line ~144: `savedNames: viewModel.savedCoPilotNames` → `savedNames: viewModel.savedCrewNames`
- Line ~154 and ~164: `savedNames: viewModel.savedSONames` → `savedNames: viewModel.savedCrewNames`
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add savedCrewNames to UserDefaultsService with one-time migration</name>
  <files>Block-Time/Services/UserDefaultsService.swift</files>
  <action>
    Invoke swiftui-pro skill first.

    1. In `AppSettings` struct: add `var savedCrewNames: [String]` field after `savedSONames`. Add `savedCrewNames: []` to the `default` static instance.

    2. In `Keys` enum: add `static let savedCrewNames = "savedCrewNames"` and `static let crewNamesMigrated = "crewNamesMigrated"`.

    3. Add `func migrateCrewNamesIfNeeded()` as a private method:
       ```swift
       private func migrateCrewNamesIfNeeded() {
           guard !userDefaults.bool(forKey: Keys.crewNamesMigrated) else { return }
           let captains = userDefaults.stringArray(forKey: Keys.savedCaptainNames) ?? []
           let coPilots = userDefaults.stringArray(forKey: Keys.savedCoPilotNames) ?? []
           let sos = userDefaults.stringArray(forKey: Keys.savedSONames) ?? []
           let unified = sortCrewNamesByFirstName(Array(Set(captains + coPilots + sos)))
           userDefaults.set(unified, forKey: Keys.savedCrewNames)
           userDefaults.set(true, forKey: Keys.crewNamesMigrated)
       }
       ```
       DO NOT clear the old keys — they must remain for CloudKit backward compat sync.

    4. In `loadSettings()`: call `migrateCrewNamesIfNeeded()` at the top of the method (before building AppSettings). Then in the returned AppSettings, add `savedCrewNames: loadAndSortCrewNames(forKey: Keys.savedCrewNames)`.

    5. In `saveSettings()`: add `userDefaults.set(settings.savedCrewNames, forKey: Keys.savedCrewNames)` alongside the existing saves.

    6. Add `func addCrewName(_ name: String) -> [String]`:
       - Trim name, guard not empty
       - Load current `savedCrewNames` from userDefaults
       - If not already present, append, sort, save
       - Return sorted list

    7. Add `func removeCrewName(_ name: String) -> [String]`:
       - Load current list, remove matching name, save, return updated list

    8. Update `addCaptainName`, `addCoPilotName`, `addSOName` to call `addCrewName` and return its result (keep writing to their own legacy keys too, for KVS backward compat):
       - After writing to the legacy key (existing logic), also call `addCrewName(name)` — but do NOT return the legacy list. Return `addCrewName(trimmedName)` instead.
       - Actually simpler: replace body entirely — write to legacy key for compat, then delegate:
         ```swift
         func addCaptainName(_ name: String) -> [String] {
             let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
             guard !trimmedName.isEmpty else { return loadAndSortCrewNames(forKey: Keys.savedCrewNames) }
             // Keep legacy key updated for CloudKit backward compat
             var legacy = userDefaults.stringArray(forKey: Keys.savedCaptainNames) ?? []
             if !legacy.contains(trimmedName) {
                 legacy.append(trimmedName)
                 userDefaults.set(sortCrewNamesByFirstName(legacy), forKey: Keys.savedCaptainNames)
             }
             return addCrewName(trimmedName)
         }
         ```
       - Do the same for `addCoPilotName` (legacy key: savedCoPilotNames) and `addSOName` (legacy key: savedSONames).

    9. Update `removeCaptainName`, `removeCoPilotName`, `removeSOName` to also call `removeCrewName` and return its result:
       - Keep removing from their legacy key (existing code), then call `removeCrewName(name)` and return its result.
  </action>
  <verify>File compiles without errors. `loadSettings()` returns an AppSettings with a non-nil `savedCrewNames`. `migrateCrewNamesIfNeeded()` is guarded by `crewNamesMigrated` bool.</verify>
  <done>AppSettings has savedCrewNames. Migration runs once. add/remove methods delegate to unified list while keeping legacy keys updated.</done>
</task>

<task type="auto">
  <name>Task 2: Update CloudKitSettingsSyncService and MigrationImportService</name>
  <files>
    Block-Time/Services/CloudKitSettingsSyncService.swift
    Block-Time/Services/MigrationImportService.swift
  </files>
  <action>
    Invoke swiftui-pro skill first.

    CloudKitSettingsSyncService.swift:

    1. In `CloudKeys` enum, add:
       `static let savedCrewNames = "cloud_savedCrewNames"`

    2. In `syncToCloud()`, after the existing `savedCoPilotNames` line (~line 303), add:
       `ubiquitousStore.set(settings.savedCrewNames, forKey: CloudKeys.savedCrewNames)`
       Keep all existing savedCaptainNames/savedCoPilotNames/savedSONames lines — they remain for backward compat.

    3. In `syncFromCloud()`, after the existing `savedCoPilotNames` block (~line 474–477), add:
       ```swift
       if let savedCrewNames = ubiquitousStore.array(forKey: CloudKeys.savedCrewNames) as? [String],
          savedCrewNames != localSettings.savedCrewNames {
           settings.savedCrewNames = savedCrewNames
           changedKeys.insert("savedCrewNames")
       }
       ```
       Keep all existing savedCaptainNames/savedCoPilotNames/savedSONames sync blocks.

    MigrationImportService.swift:

    1. In `MigrationSettings` struct, add:
       `let savedCrewNames: [String]?`

    2. In the restore block (~line 568), after the `savedCoPilotNames` block, add:
       ```swift
       if let savedCrewNames = settings.savedCrewNames {
           ubiquitousStore.set(savedCrewNames, forKey: "cloud_savedCrewNames")
       }
       ```
       Keep existing savedCaptainNames/savedCoPilotNames/savedSONames restore lines.
  </action>
  <verify>Files compile without errors. CloudKeys has `savedCrewNames`. Both sync directions handle the new key.</verify>
  <done>CloudKit syncs savedCrewNames in both directions. Legacy keys still sync. MigrationImportService preserves savedCrewNames in backup restore.</done>
</task>

<task type="auto">
  <name>Task 3: Update ViewModel and Views to use savedCrewNames</name>
  <files>
    Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
    Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
    Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift
  </files>
  <action>
    Invoke swiftui-pro skill first.

    FlightTimeExtractorViewModel.swift:

    1. Replace lines 201–203 (three @Published arrays):
       Remove `@Published var savedCaptainNames: [String] = []`
       Remove `@Published var savedCoPilotNames: [String] = []`
       Remove `@Published var savedSONames: [String] = []`
       Add: `@Published var savedCrewNames: [String] = []`

    2. In `loadSettings()` path (~line 445–457): replace the three separate assignments
       (`savedSONames = settings.savedSONames`, `savedCaptainNames = settings.savedCaptainNames`, `savedCoPilotNames = settings.savedCoPilotNames`)
       with: `savedCrewNames = settings.savedCrewNames`

    3. In `updateChangedSettings` switch: remove cases `"savedCaptainNames"`, `"savedCoPilotNames"`, `"savedSONames"`.
       Add: `case "savedCrewNames": savedCrewNames = settings.savedCrewNames`

    4. `addCaptainName` method (~line 1481): change `savedCaptainNames = ...` to `savedCrewNames = ...`
       `addCoPilotName` method (~line 1485): change `savedCoPilotNames = ...` to `savedCrewNames = ...`
       `addSOName` method (~line 659): change `savedSONames = ...` to `savedCrewNames = ...`

    5. `removeCaptainName` (~line 1489): change `savedCaptainNames = ...` to `savedCrewNames = ...`
       `removeCoPilotName` (~line 1493): change `savedCoPilotNames = ...` to `savedCrewNames = ...`
       `removeSOName` (~line 1497): change `savedSONames = ...` to `savedCrewNames = ...`

    6. `reloadSavedCrewNames()` (~line 1505): replace the three union+sort assignments with:
       ```swift
       let userCrewNames = Set(settings.savedCrewNames)
       let allDBNames = Set(dbCaptainNames + dbFONames + dbSONames)
       savedCrewNames = Array(userCrewNames.union(allDBNames)).sorted()
       ```
       (Keep the DB name collection lines above that build dbCaptainNames/dbFONames/dbSONames — just change what they merge into.)

    CrewOpsCard.swift (ModernManualEntryDataCard):

    7. CAPTAIN ModernCrewField: `savedNames: viewModel.savedCaptainNames` → `savedNames: viewModel.savedCrewNames`
    8. F/O ModernCrewField: `savedNames: viewModel.savedCoPilotNames` → `savedNames: viewModel.savedCrewNames`
    9. S/O 1 ModernCrewField: `savedNames: viewModel.savedSONames` → `savedNames: viewModel.savedCrewNames`
    10. S/O 2 ModernCrewField: `savedNames: viewModel.savedSONames` → `savedNames: viewModel.savedCrewNames`

    BulkEditSheet.swift:

    11. Line ~134: `savedNames: viewModel.savedCaptainNames` → `savedNames: viewModel.savedCrewNames`
    12. Line ~144: `savedNames: viewModel.savedCoPilotNames` → `savedNames: viewModel.savedCrewNames`
    13. Line ~154: `savedNames: viewModel.savedSONames` → `savedNames: viewModel.savedCrewNames`
    14. Line ~164: `savedNames: viewModel.savedSONames` → `savedNames: viewModel.savedCrewNames`
  </action>
  <verify>Project compiles cleanly. No remaining references to `savedCaptainNames`, `savedCoPilotNames`, or `savedSONames` on viewModel (grep viewModel for these strings — result should be empty).</verify>
  <done>All four crew autocomplete fields use viewModel.savedCrewNames. ViewModel has one @Published property. No compile errors.</done>
</task>

</tasks>

<verification>
grep -n "savedCaptainNames\|savedCoPilotNames\|savedSONames" \
  "Block-Time/ViewModels/FlightTimeExtractorViewModel.swift" \
  "Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift" \
  "Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift"

Expected: zero results (these files no longer reference the old property names).

grep -n "savedCrewNames" \
  "Block-Time/Services/UserDefaultsService.swift" \
  "Block-Time/Services/CloudKitSettingsSyncService.swift" \
  "Block-Time/ViewModels/FlightTimeExtractorViewModel.swift"

Expected: multiple hits confirming the new unified field is wired end-to-end.
</verification>

<success_criteria>
- AppSettings struct has `savedCrewNames: [String]`
- `migrateCrewNamesIfNeeded()` unions all three legacy lists once, guarded by `crewNamesMigrated` bool
- `addCaptainName/addCoPilotName/addSOName` still exist and delegate to addCrewName
- `removeCaptainName/removeCoPilotName/removeSOName` still exist and delegate to removeCrewName
- FlightTimeExtractorViewModel has one `@Published var savedCrewNames: [String]`
- All six ModernCrewField calls (4 in CrewOpsCard, 2 SO fields) pass `savedNames: viewModel.savedCrewNames`
- All four ModernCrewField calls in BulkEditSheet pass `savedNames: viewModel.savedCrewNames`
- CloudKitSettingsSyncService syncs `cloud_savedCrewNames` in both directions
- Project builds without errors or warnings related to these changes
</success_criteria>

<output>
After completion, create `.planning/quick/260601-etg-merge-crew-name-lists-into-single-savedc/260601-etg-SUMMARY.md`
</output>
