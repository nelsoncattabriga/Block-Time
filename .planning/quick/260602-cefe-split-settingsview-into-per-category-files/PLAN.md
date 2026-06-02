# Split SettingsView.swift into Per-Category Files

**Type:** Refactor (no functional changes)
**Goal:** Reduce SettingsView.swift from ~2900 lines to a thin coordinator + imports by extracting each logical unit into its own file under `Views/Screens/Settings/`.

---

## Context

`SettingsView.swift` contains every settings card, helper row, and sheet in a single file. The structs have clear natural seams matching the existing `SettingsCategory` enum. Xcode's type-checker can time out on large SwiftUI files; splitting also makes navigation and future editing much faster.

**Zero functional changes.** No logic moves, no renames, no API changes — only file boundaries change.

---

## Target File Layout

```
Views/Screens/Settings/
  SettingsView.swift                  ← keep: SettingsCategory enum + SettingsView + AppearanceSettingsView
  PersonalCrewSettingsView.swift      ← NEW: PersonalCrewSettingsView + all crew/ops cards
  FlightInformationSettingsView.swift ← NEW: FlightInformationSettingsView + ModernFormatOptionsCard + ModernFleetSelectorRow + AirlinePickerSheet + ModernAirlinePrefixRow
  FRMSSettingsDetailView.swift        ← NEW: FRMSSettingsDetailView + ModernFRMSCard
  BackupsView.swift                   ← already exists — no change
  ImportExportView.swift              ← already exists — no change
  SettingsComponents.swift            ← NEW: ModernToggleRow + ModernTextFieldRow + ShareSheetWrapper
  CustomFieldsView.swift              ← NEW: InlineCustomFieldsView + CustomFieldsSettingsView + FieldEditSheet + FieldEditMode
  CloudKitSyncCard.swift              ← NEW: ModernCloudKitSyncCard + SyncDetailRowView + ICloudSyncHelpSheet
  ModernPhotoBackupCard.swift         ← NEW: ModernPhotoBackupCard (currently public, stays public)
```

---

## Tasks

### Task 1 — Create `SettingsComponents.swift`

Extract the three shared primitives that are used by multiple cards:
- `ModernToggleRow` (private → internal)
- `ModernTextFieldRow` (private → internal)
- `ShareSheetWrapper` (already public — no change)

These must move first because other cards depend on them.

**Steps:**
1. Create `Views/Screens/Settings/SettingsComponents.swift`
2. Copy `ModernToggleRow`, `ModernTextFieldRow`, `ShareSheetWrapper` into the new file
3. Remove `private` access modifier from `ModernToggleRow` and `ModernTextFieldRow` (file-private scope no longer applies)
4. Delete the originals from `SettingsView.swift`

---

### Task 2 — Create `CustomFieldsView.swift`

Extract the custom fields subsystem (self-contained, no dependencies on other cards):
- `FieldEditMode` (private enum → internal)
- `InlineCustomFieldsView` (public — no change)
- `CustomFieldsSettingsView` (public — no change)
- `FieldEditSheet` (private → internal)

**Steps:**
1. Create `Views/Screens/Settings/CustomFieldsView.swift`
2. Copy the four types above
3. Remove `private` from `FieldEditMode` and `FieldEditSheet`
4. Delete the originals from `SettingsView.swift` (lines ~2490–2924)

---

### Task 3 — Create `CloudKitSyncCard.swift`

Extract the iCloud sync subsystem (self-contained):
- `ModernCloudKitSyncCard` (public — no change)
- `SyncDetailRowView` (private → internal)
- `ICloudSyncHelpSheet` (private → internal)

**Steps:**
1. Create `Views/Screens/Settings/CloudKitSyncCard.swift`
2. Copy the three types above
3. Remove `private` from `SyncDetailRowView` and `ICloudSyncHelpSheet`
4. Delete the originals from `SettingsView.swift` (lines ~1916–2488)

---

### Task 4 — Create `FRMSSettingsDetailView.swift`

Extract FRMS settings:
- `FRMSSettingsDetailView` (already at file scope — no change)
- `ModernFRMSCard` (private → internal)

**Steps:**
1. Create `Views/Screens/Settings/FRMSSettingsDetailView.swift`
2. Copy the two types above
3. Remove `private` from `ModernFRMSCard`
4. Delete the originals from `SettingsView.swift` (lines ~325–352 and ~1789–1914)

---

### Task 5 — Create `FlightInformationSettingsView.swift`

Extract flight info settings and its dependencies:
- `FlightInformationSettingsView` (file scope — no change)
- `ModernFormatOptionsCard` (private → internal)
- `ModernFleetSelectorRow` (private → internal)
- `ModernAirlinePrefixRow` (private → internal)
- `AirlinePickerSheet` (private → internal)

**Steps:**
1. Create `Views/Screens/Settings/FlightInformationSettingsView.swift`
2. Copy the five types above
3. Remove `private` from all four card/row types
4. Delete the originals from `SettingsView.swift`

---

### Task 6 — Create `PersonalCrewSettingsView.swift`

Extract crew & ops settings and its dependencies:
- `PersonalCrewSettingsView` (file scope — no change)
- `ModernDefaultCrewNamesCard` (private → internal)
- `ModernOpsDataCard` (private → internal)
- `ModernCrewNotesCard` (private → internal)
- `ModernCustomFieldsCard` (private → internal)

**Steps:**
1. Create `Views/Screens/Settings/PersonalCrewSettingsView.swift`
2. Copy the five types above
3. Remove `private` from all four card types
4. Delete the originals from `SettingsView.swift`

---

### Task 7 — Move `ModernPhotoBackupCard`

`ModernPhotoBackupCard` is public and used in `BackupsView`. Move it to its own file or to `SettingsComponents.swift`.

**Steps:**
1. Append `ModernPhotoBackupCard` to `SettingsComponents.swift`
2. Delete from `SettingsView.swift`

---

### Task 8 — Slim down `SettingsView.swift`

After tasks 1–7, `SettingsView.swift` should contain only:
- `import` statements
- `SettingsCategory` enum
- `SettingsView` struct
- `AppearanceSettingsView` struct

Verify no types remain that belong in other files. Remove any leftover commented-out code.

---

### Task 9 — Build verification

Confirm the project compiles clean:
- No "use of unresolved identifier" errors (access modifier changes are the main risk)
- No duplicate type definitions
- `ModernDataImportCard` — verify where it lives. It is currently in `SettingsView.swift` but is actually used by `ImportExportView.swift`. If so, move it there in this task.

**`ModernDataImportCard` finding:** This struct is defined in `SettingsView.swift` (line 1093) but has **zero call sites** — it is dead code, superseded by `ImportExportView`. Delete it during this task rather than moving it. Confirm with Nelson before deleting if there is any doubt.

**Steps:**
1. Comment out `ModernDataImportCard` in `SettingsView.swift` (lines 1093–1431) — it is unreferenced dead code but preserved for reference
2. Search for all usages of every other extracted type to confirm no references are broken
3. Report any access modifier issues found

> **Note:** Nelson builds locally. Do not run `xcodebuild` — list any remaining issues for Nelson to verify.

---

## Access Modifier Reference

Types changing from `private` → `internal` (implicit):

| Type | From | To |
|------|------|----|
| `ModernToggleRow` | private | internal |
| `ModernTextFieldRow` | private | internal |
| `ModernDefaultCrewNamesCard` | private | internal |
| `ModernOpsDataCard` | private | internal |
| `ModernCrewNotesCard` | private | internal |
| `ModernCustomFieldsCard` | private | internal |
| `ModernFormatOptionsCard` | private | internal |
| `ModernFleetSelectorRow` | private | internal |
| `ModernAirlinePrefixRow` | private | internal |
| `AirlinePickerSheet` | private | internal |
| `ModernFRMSCard` | private | internal |
| `SyncDetailRowView` | private | internal |
| `ICloudSyncHelpSheet` | private | internal |
| `FieldEditMode` | private | internal |
| `FieldEditSheet` | private | internal |

Types staying public (no change): `ShareSheetWrapper`, `ModernPhotoBackupCard`, `ModernCloudKitSyncCard`, `InlineCustomFieldsView`, `CustomFieldsSettingsView`

---

## Success Criteria

1. `SettingsView.swift` is under 300 lines
2. Each new file is under 500 lines
3. All extracted types are accessible from their callers (no unresolved identifier errors)
4. No functional behaviour changes — settings screens look and work identically
5. `ModernDataImportCard` location resolved (in `SettingsView.swift` or moved to `ImportExportView.swift`)
