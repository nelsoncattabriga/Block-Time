---
phase: quick
plan: 260520-sqy
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Services/FileImportService.swift
  - Block-Time/Views/Screens/Settings/ExportLogbookView.swift
autonomous: true
requirements: [SQY-01]
must_haves:
  truths:
    - "exportToCSV with useLabelsAsHeaders: true uses def.label for column headers"
    - "exportToCSV with useLabelsAsHeaders: false (default) still uses Counter<N> headers"
    - "ExportLogbookView passes useLabelsAsHeaders: true"
    - "AutomaticBackupService call is unchanged (uses default false)"
  artifacts:
    - path: "Block-Time/Services/FileImportService.swift"
      provides: "Updated exportToCSV signature with useLabelsAsHeaders parameter"
    - path: "Block-Time/Views/Screens/Settings/ExportLogbookView.swift"
      provides: "Call site updated to pass useLabelsAsHeaders: true"
  key_links:
    - from: "ExportLogbookView.swift"
      to: "FileImportService.exportToCSV"
      via: "useLabelsAsHeaders: true argument"
---

<objective>
Add `useLabelsAsHeaders: Bool = false` parameter to `exportToCSV(flights:definitions:)`. When true, use `def.label` as the column header instead of `Counter\(def.columnIndex)`. Update ExportLogbookView to pass true; leave AutomaticBackupService unchanged.

Purpose: Exported CSV files shown to users use human-readable labels; backup files keep the stable machine-readable Counter<N> keys.
Output: Two file changes — signature update + call site update.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

<interfaces>
<!-- From Block-Time/Services/FileImportService.swift (lines 1261–1276) -->
Current signature:
```swift
func exportToCSV(flights: [FlightSector], definitions: [CustomCounterDefinition]) -> String
```

Header-building loop (lines 1274–1276):
```swift
for def in definitions {
    headerRow += ",Counter\(def.columnIndex)"
}
```

<!-- From Block-Time/Views/Screens/Settings/ExportLogbookView.swift (line 139) -->
Current call site (no-definitions overload — fetches definitions internally):
```swift
let csvString = FileImportService.shared.exportToCSV(flights: sortedFlights)
```

<!-- From Block-Time/Services/AutomaticBackupService.swift (line 290) -->
Backup call site (passes definitions explicitly — must NOT change):
```swift
let csvString = FileImportService.shared.exportToCSV(flights: sortedFlights, definitions: counterDefinitions)
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add useLabelsAsHeaders parameter to exportToCSV</name>
  <files>Block-Time/Services/FileImportService.swift</files>
  <action>
In `exportToCSV(flights:definitions:)` (line 1261), add `useLabelsAsHeaders: Bool = false` as a third parameter.

Update the header-building loop (lines 1274–1276) to branch on the flag:

```swift
for def in definitions {
    let header = useLabelsAsHeaders ? def.label : "Counter\(def.columnIndex)"
    headerRow += ",\(header)"
}
```

Default is `false` so both existing call sites (AutomaticBackupService and the no-definitions overload at line 1257) continue to produce `Counter<N>` headers without any change.

Do NOT touch the no-definitions overload at line 1257 — it does not forward this parameter and the default covers it.
  </action>
  <verify>
    <automated>grep -n "useLabelsAsHeaders" /Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Services/FileImportService.swift</automated>
  </verify>
  <done>Signature includes `useLabelsAsHeaders: Bool = false`; loop branches on flag; both existing callers unchanged.</done>
</task>

<task type="auto">
  <name>Task 2: Update ExportLogbookView call site</name>
  <files>Block-Time/Views/Screens/Settings/ExportLogbookView.swift</files>
  <action>
In `performExport()` (line 139), the current call uses the no-definitions overload:

```swift
let csvString = FileImportService.shared.exportToCSV(flights: sortedFlights)
```

Replace it with the definitions overload passing `useLabelsAsHeaders: true`:

```swift
let definitions = CustomCounterService.shared.definitions
let csvString = FileImportService.shared.exportToCSV(
    flights: sortedFlights,
    definitions: definitions,
    useLabelsAsHeaders: true
)
```

This ensures the user-facing export CSV uses label-based column headers (e.g., "Approach Count") rather than machine keys (e.g., "Counter1").
  </action>
  <verify>
    <automated>grep -n "useLabelsAsHeaders" /Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Views/Screens/Settings/ExportLogbookView.swift</automated>
  </verify>
  <done>`useLabelsAsHeaders: true` present in ExportLogbookView call; AutomaticBackupService call unchanged (verify with grep on that file).</done>
</task>

</tasks>

<verification>
```bash
# Confirm parameter added
grep -n "useLabelsAsHeaders" \
  /Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Services/FileImportService.swift \
  /Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Views/Screens/Settings/ExportLogbookView.swift

# Confirm AutomaticBackupService was NOT changed
grep -n "useLabelsAsHeaders" \
  /Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Services/AutomaticBackupService.swift
# Expected: no output (no useLabelsAsHeaders — still uses default false)
```
</verification>

<success_criteria>
- `exportToCSV(flights:definitions:useLabelsAsHeaders:)` compiles with default `false`
- ExportLogbookView passes `useLabelsAsHeaders: true` and pre-fetches definitions
- AutomaticBackupService.swift has zero changes
- No other call sites broken (default covers them)
</success_criteria>

<output>
After completion, create `.planning/quick/260520-sqy-add-uselabelsasheaders-param-to-exportto/260520-sqy-SUMMARY.md`
</output>
