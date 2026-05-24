# Plan: 260519-ctr — Backup/Restore Custom Counter Fields

Task: Add `CustomCounterDefinition` round-trip to Block-Time backup/restore flow.

Files touched:
- `Block-Time/Services/FileImportService.swift`
- `Block-Time/Views/Screens/Settings/BackupsView.swift`

---

## Task 1 — `exportToCSV`: prepend `#DEFINITIONS:` line and append counter columns

**File:** `Block-Time/Services/FileImportService.swift`

**Where:** `func exportToCSV(flights: [FlightSector]) -> String` (line ~1154)

**What to do:**

1. At the top of the function, read definitions from `CustomCounterService`:

```swift
// Must be called on main thread — exportToCSV is invoked from main thread via the share sheet
let definitions = CustomCounterService.shared.definitions
    .sorted { $0.columnIndex < $1.columnIndex }
```

2. Build the `#DEFINITIONS:` prefix line. Insert it **before** the CSV header. If `definitions` is empty, skip this line entirely:

```swift
var result = ""
if !definitions.isEmpty,
   let data = try? JSONEncoder().encode(definitions),
   let json = String(data: data, encoding: .utf8) {
    result += "#DEFINITIONS:\(json)\n"
}
```

3. Build the header row. The existing header string already ends with `Custom Count`. Append counter column headers **after** it:

```swift
var headerFields = "Date,Flight Number,...,Custom Count"  // existing string, minus the trailing \n
for def in definitions {
    headerFields += ",Counter\(def.columnIndex)"
}
result += headerFields + "\n"
```

Concretely: change the existing `var csv = "...,Custom Count\n"` line to:
- Store the base header **without** `\n` as a `var` string.
- Append `,Counter{N}` for each definition.
- Append `\n`.
- Prepend the `#DEFINITIONS:` line before assigning to `result`.

4. In the per-flight row array, after the existing `flight.customCount > 0 ? String(flight.customCount) : ""` element, append counter values:

```swift
var row: [String] = [
    // ... all existing fields unchanged ...
    flight.customCount > 0 ? String(flight.customCount) : ""
]
for def in definitions {
    row.append(flight.counterEntries[def.columnIndex] ?? "")
}
```

5. Return `result` (not `csv`). The existing `csv += row.joined...` loop must write into `result` instead.

**Constraint:** Do NOT remove the `Custom Count` column. Keep all existing fields as-is.

**Verify:** Build succeeds. A manual export of a logbook with one counter definition produces a file whose first line starts with `#DEFINITIONS:[` and whose header row contains `Counter1` after `Custom Count`.

---

## Task 2 — `FileImportService`: add `DefinitionsBehavior`, `extractBackupDefinitions`, update `quickRestoreFromBackup`

**File:** `Block-Time/Services/FileImportService.swift`

**What to do:**

### 2a. Add `DefinitionsBehavior` enum

Add near the top of `FileImportService.swift` (after the class declaration opening, before `MARK: - Parse File`, outside the class):

```swift
enum DefinitionsBehavior {
    case skip
    case replaceAll
    case mergeIfEmpty
}
```

### 2b. Add `extractBackupDefinitions(url:skipSecurityScoping:) -> [CustomCounterDefinition]?`

Add as a new `func` inside `FileImportService` class:

```swift
/// Reads the first line of a backup CSV and extracts definitions if present.
/// Returns nil if the line is absent or unreadable.
func extractBackupDefinitions(url: URL, skipSecurityScoping: Bool) -> [CustomCounterDefinition]? {
    let needsSecurity = !skipSecurityScoping && !isInAppContainer(url)
    if needsSecurity { guard url.startAccessingSecurityScopedResource() else { return nil } }
    defer { if needsSecurity { url.stopAccessingSecurityScopedResource() } }

    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    let firstLine = content.components(separatedBy: .newlines).first ?? ""
    guard firstLine.hasPrefix("#DEFINITIONS:") else { return nil }
    let json = String(firstLine.dropFirst("#DEFINITIONS:".count))
    guard let data = json.data(using: .utf8),
          let defs = try? JSONDecoder().decode([CustomCounterDefinition].self, from: data)
    else { return nil }
    return defs
}
```

### 2c. Update `quickRestoreFromBackup` signature

Change:
```swift
func quickRestoreFromBackup(
    url: URL,
    mode: ImportMode = .merge,
    skipSecurityScoping: Bool = false,
    completion: @escaping (Result<ImportResult, Error>) -> Void
)
```
To:
```swift
func quickRestoreFromBackup(
    url: URL,
    mode: ImportMode = .merge,
    skipSecurityScoping: Bool = false,
    definitionsBehavior: DefinitionsBehavior = .mergeIfEmpty,
    completion: @escaping (Result<ImportResult, Error>) -> Void
)
```

### 2d. Update `quickRestoreFromBackup` body to strip the `#DEFINITIONS:` line before parsing

Replace the existing `do { let importData = try parseFile(url: url, ...)` block with:

```swift
do {
    // --- strip #DEFINITIONS: line if present ---
    let needsSecurity = !skipSecurityScoping && !isInAppContainer(url)
    if needsSecurity { guard url.startAccessingSecurityScopedResource() else {
        completion(.failure(ImportError.accessDenied)); return
    }}

    let rawContent: String
    do {
        rawContent = try String(contentsOf: url, encoding: .utf8)
    } catch {
        if needsSecurity { url.stopAccessingSecurityScopedResource() }
        completion(.failure(error)); return
    }
    if needsSecurity { url.stopAccessingSecurityScopedResource() }

    var extractedDefinitions: [CustomCounterDefinition]? = nil
    var contentForParsing = rawContent

    let lines = rawContent.components(separatedBy: .newlines)
    if let firstLine = lines.first, firstLine.hasPrefix("#DEFINITIONS:") {
        let json = String(firstLine.dropFirst("#DEFINITIONS:".count))
        if let data = json.data(using: .utf8),
           let defs = try? JSONDecoder().decode([CustomCounterDefinition].self, from: data) {
            extractedDefinitions = defs
        }
        // Strip first line — write remainder to a temp file
        let remainder = lines.dropFirst().joined(separator: "\n")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".csv")
        do {
            try remainder.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            completion(.failure(error)); return
        }
        // Parse the temp file (no security scoping needed — it's in our temp dir)
        let importData = try parseFile(url: tempURL, forceSecurityScoping: false)
        try? FileManager.default.removeItem(at: tempURL)

        guard isLoggerExportFormat(headers: importData.headers) else {
            completion(.failure(ImportError.notLoggerFormat)); return
        }
        let mappings = createLoggerFieldMapping(headers: importData.headers)

        // Apply definitions after import completes
        importFlights(from: importData, mapping: mappings, mode: mode) { result in
            if case .success = result, let defs = extractedDefinitions {
                DispatchQueue.main.async {
                    switch definitionsBehavior {
                    case .replaceAll:
                        CustomCounterService.shared.replaceAll(defs)
                    case .mergeIfEmpty:
                        if CustomCounterService.shared.definitions.isEmpty {
                            CustomCounterService.shared.replaceAll(defs)
                        }
                    case .skip:
                        break
                    }
                }
            }
            completion(result)
        }
        return
    }

    // No #DEFINITIONS: line — use original path
    let importData = try parseFile(url: url, forceSecurityScoping: !skipSecurityScoping)
    guard isLoggerExportFormat(headers: importData.headers) else {
        throw ImportError.notLoggerFormat
    }
    let mappings = createLoggerFieldMapping(headers: importData.headers)
    importFlights(from: importData, mapping: mappings, mode: mode, completion: completion)

} catch {
    completion(.failure(error))
}
```

**Note:** The entire existing `do { ... }` block inside `quickRestoreFromBackup` is replaced by the block above. The log statements at the top of the function (`LogManager.shared.info(...)`) before the `do` block are kept as-is.

**Verify:** Build succeeds. Old backups (no `#DEFINITIONS:` line) still import cleanly. A backup with `#DEFINITIONS:` line imports and restores definitions per the chosen behavior.

---

## Task 3 — `createLoggerFieldMapping`: recognise `Counter1`…`Counter10` headers

**File:** `Block-Time/Services/FileImportService.swift`

**Where:** `private func createLoggerFieldMapping(headers: [String])` (line ~1067)

**What to do:**

Add a private helper method inside the class:

```swift
private func parseCounterColumnIndex(_ header: String) -> Int? {
    guard header.hasPrefix("counter"),
          let idx = Int(header.dropFirst("counter".count)),
          (1...10).contains(idx) else { return nil }
    return idx
}
```

In `createLoggerFieldMapping`, inside the `for header in headers` loop, after the existing `} else if headerLower == "custom count" {` branch and before the closing `}` of the `if-else` chain, add:

```swift
} else if let idx = parseCounterColumnIndex(headerLower) {
    mappings.append(FieldMapping(
        logbookField: "Counter\(idx)",
        logbookFieldDescription: "Counter \(idx)",
        sourceColumn: header,
        isRequired: false
    ))
```

**Verify:** Build succeeds.

---

## Task 4 — `createFlightFromRow`: populate `counterEntries` from mapped counter columns

**File:** `Block-Time/Services/FileImportService.swift`

**Where:** `private func createFlightFromRow(...)` — specifically just after `let flight = FlightSector(...)` is constructed (line ~758) and before `return .success(flight)` (line ~760).

**What to do:**

`FlightSector.counterEntries` is a `var [Int: String]`, so mutate after init:

```swift
let flight = FlightSector(
    // ... all existing parameters unchanged ...
    customCount: isPositioning ? 0 : max(0, customCount)
)

// Populate custom counter entries
var counterEntries: [Int: String] = [:]
for i in 1...10 {
    let val = getValue("Counter\(i)").trimmingCharacters(in: .whitespacesAndNewlines)
    if !val.isEmpty {
        counterEntries[i] = val
    }
}
flight.counterEntries = counterEntries  // FlightSector.counterEntries is a var

return .success(flight)
```

Wait — `FlightSector` is a **struct** and `flight` is a `let` constant. Change `let flight` to `var flight`:

```swift
var flight = FlightSector(
    // ... all existing parameters unchanged ...
    customCount: isPositioning ? 0 : max(0, customCount)
)

var counterEntries: [Int: String] = [:]
for i in 1...10 {
    let val = getValue("Counter\(i)").trimmingCharacters(in: .whitespacesAndNewlines)
    if !val.isEmpty { counterEntries[i] = val }
}
flight.counterEntries = counterEntries

return .success(flight)
```

**Verify:** Build succeeds. Importing a backup CSV containing `Counter1` data with value `"42"` results in a flight whose `counterEntries[1] == "42"`.

---

## Task 5 — `BackupsView`: definition conflict handling in `BackupDetailSheet`

**File:** `Block-Time/Views/Screens/Settings/BackupsView.swift`

**What to do:**

### 5a. Add state vars to `BackupDetailSheet`

After `@State private var selectedRestoreMode: ImportMode = .merge`, add:

```swift
@State private var pendingBackupDefinitions: [CustomCounterDefinition]? = nil
@State private var showingDefinitionConflict = false
```

### 5b. Update `performRestore()` in `BackupDetailSheet`

Replace the existing body of `performRestore()` with:

```swift
private func performRestore() {
    LogManager.shared.info("performRestore called")
    LogManager.shared.info("📁 Backup URL: \(backup.url.path)")
    LogManager.shared.info("🔀 Restore mode: \(selectedRestoreMode)")

    if selectedRestoreMode == .replace {
        // Replace mode: always overwrite definitions
        executeRestore(definitionsBehavior: .replaceAll)
        return
    }

    // Merge mode: check for definition conflicts
    let backupDefs = FileImportService.shared.extractBackupDefinitions(
        url: backup.url, skipSecurityScoping: true
    )

    if let backupDefs = backupDefs,
       !backupDefs.isEmpty,
       !CustomCounterService.shared.definitions.isEmpty,
       backupDefs != CustomCounterService.shared.definitions {
        // Conflict: backup has definitions AND device has different definitions
        pendingBackupDefinitions = backupDefs
        showingDefinitionConflict = true
    } else {
        // No conflict: merge-if-empty
        executeRestore(definitionsBehavior: .mergeIfEmpty)
    }
}

private func executeRestore(definitionsBehavior: DefinitionsBehavior) {
    isRestoring = true
    FileImportService.shared.quickRestoreFromBackup(
        url: backup.url,
        mode: selectedRestoreMode,
        skipSecurityScoping: true,
        definitionsBehavior: definitionsBehavior
    ) { result in
        isRestoring = false
        switch result {
        case .success(let importResult):
            var message = "Restore Summary\n\n"
            message += "Mode: \(self.selectedRestoreMode == .merge ? "Merge" : "Overwrite")\n\n"
            message += "✓ Successfully restored: \(importResult.successCount) flights\n"
            if importResult.duplicateCount > 0 {
                message += "⊘ Skipped \(importResult.duplicateCount) duplicated flights\n"
            }
            if importResult.failureCount > 0 {
                message += "Failed to restore: \(importResult.failureCount) flights\n"
            }
            resultMessage = message
            showingResultAlert = true
        case .failure(let error):
            if (error as? ImportError) == .notLoggerFormat {
                resultMessage = "This file is not in Block-Time backup format. Please use 'Import with Field Mapping' to import files from other logbook apps."
            } else {
                resultMessage = "Restore failed: \(error.localizedDescription)"
            }
            showingResultAlert = true
        }
    }
}
```

### 5c. Attach `.sheet(isPresented: $showingDefinitionConflict)` to the view

In `BackupDetailSheet.body`, after the existing `.sheet(isPresented: $showingRestoreConfirmation)` modifier, add:

```swift
.sheet(isPresented: $showingDefinitionConflict) {
    if let backupDefs = pendingBackupDefinitions {
        DefinitionConflictSheet(
            backupDefinitions: backupDefs,
            deviceDefinitions: CustomCounterService.shared.definitions,
            onKeepExisting: {
                showingDefinitionConflict = false
                executeRestore(definitionsBehavior: .skip)
            },
            onUseBackup: {
                showingDefinitionConflict = false
                executeRestore(definitionsBehavior: .replaceAll)
            },
            onCancel: {
                showingDefinitionConflict = false
            }
        )
        .presentationDetents([.height(500)])
    }
}
```

---

## Task 6 — `BackupsView`: definition conflict handling in `ManageBackupsView.performExternalRestore`

**File:** `Block-Time/Views/Screens/Settings/BackupsView.swift`

**What to do:**

### 6a. Add state vars to `ManageBackupsView`

`ManageBackupsView` is a `struct ManageBackupsView: View`. Add after `@State private var selectedRestoreMode`:

```swift
@State private var pendingBackupDefinitions: [CustomCounterDefinition]? = nil
@State private var showingDefinitionConflict = false
```

### 6b. Replace `performExternalRestore()` body

```swift
private func performExternalRestore() {
    guard let fileURL = selectedExternalFile else { return }

    if selectedRestoreMode == .replace {
        executeExternalRestore(url: fileURL, definitionsBehavior: .replaceAll)
        return
    }

    let backupDefs = FileImportService.shared.extractBackupDefinitions(
        url: fileURL, skipSecurityScoping: false
    )

    if let backupDefs = backupDefs,
       !backupDefs.isEmpty,
       !CustomCounterService.shared.definitions.isEmpty,
       backupDefs != CustomCounterService.shared.definitions {
        pendingBackupDefinitions = backupDefs
        showingDefinitionConflict = true
    } else {
        executeExternalRestore(url: fileURL, definitionsBehavior: .mergeIfEmpty)
    }
}

private func executeExternalRestore(url: URL, definitionsBehavior: DefinitionsBehavior) {
    isRestoring = true
    FileImportService.shared.quickRestoreFromBackup(
        url: url,
        mode: selectedRestoreMode,
        skipSecurityScoping: false,
        definitionsBehavior: definitionsBehavior
    ) { result in
        isRestoring = false
        switch result {
        case .success(let importResult):
            var message = "Restore Summary\n\n"
            message += "Mode: \(selectedRestoreMode == .merge ? "Merge" : "Overwrite")\n\n"
            message += "✓ Successfully restored: \(importResult.successCount) flights\n"
            if importResult.duplicateCount > 0 {
                message += "⊘ Skipped \(importResult.duplicateCount) duplicated flights\n"
            }
            if importResult.failureCount > 0 {
                message += "Failed to restore: \(importResult.failureCount) flights\n"
            }
            resultMessage = message
            showingResultAlert = true
        case .failure(let error):
            if (error as? ImportError) == .notLoggerFormat {
                resultMessage = "This file is not in Block-Time backup format. Please use 'Import with Field Mapping' to import files from other logbook apps."
            } else {
                resultMessage = "Restore failed: \(error.localizedDescription)"
            }
            showingResultAlert = true
        }
    }
}
```

### 6c. Attach `.sheet(isPresented: $showingDefinitionConflict)` to `ManageBackupsView.body`

Find the outermost view modifier chain in `ManageBackupsView.body` and add after other `.sheet` modifiers:

```swift
.sheet(isPresented: $showingDefinitionConflict) {
    if let backupDefs = pendingBackupDefinitions, let fileURL = selectedExternalFile {
        DefinitionConflictSheet(
            backupDefinitions: backupDefs,
            deviceDefinitions: CustomCounterService.shared.definitions,
            onKeepExisting: {
                showingDefinitionConflict = false
                executeExternalRestore(url: fileURL, definitionsBehavior: .skip)
            },
            onUseBackup: {
                showingDefinitionConflict = false
                executeExternalRestore(url: fileURL, definitionsBehavior: .replaceAll)
            },
            onCancel: {
                showingDefinitionConflict = false
            }
        )
        .presentationDetents([.height(500)])
    }
}
```

---

## Task 7 — Add `DefinitionConflictSheet` struct

**File:** `Block-Time/Views/Screens/Settings/BackupsView.swift`

**Where:** After `RestoreModeSheet` struct (line ~994), add a new private struct.

**What to do:**

```swift
// MARK: - Definition Conflict Sheet
private struct DefinitionConflictSheet: View {
    let backupDefinitions: [CustomCounterDefinition]
    let deviceDefinitions: [CustomCounterDefinition]
    let onKeepExisting: () -> Void
    let onUseBackup: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Counter Definitions Conflict")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("The backup contains counter definitions that differ from your current settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("On This Device")
                        .font(.headline)
                    ForEach(deviceDefinitions) { def in
                        Text("• \(def.label)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("In Backup")
                        .font(.headline)
                    ForEach(backupDefinitions) { def in
                        Text("• \(def.label)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                Button(action: onKeepExisting) {
                    Text("Keep Existing")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: onUseBackup) {
                    Text("Use Backup Definitions")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
```

**Note on `Equatable` for conflict detection:** The `backupDefs != CustomCounterService.shared.definitions` comparison in Tasks 5b and 6b requires `CustomCounterDefinition` to conform to `Equatable`. `CustomCounterDefinition` already conforms to `Hashable` (which implies `Equatable`), so this comparison is valid — no change to `CustomCounterDefinition.swift` needed.

**Verify:** Build succeeds. When restoring a backup whose definitions differ from device definitions in merge mode, the conflict sheet appears. "Keep Existing" skips definitions. "Use Backup" replaces them. "Cancel" aborts.

---

## Execution Order

Run tasks sequentially: 1 → 2 → 3 → 4 → 5 → 6 → 7.

Tasks 3 and 4 are both in `FileImportService.swift` and can be done in one edit pass after Task 2.

## Success Criteria

- Export: file starts with `#DEFINITIONS:[...]` when definitions exist; `Custom Count` column still present; `Counter1`…`Counter10` columns appended.
- Import (old backup, no `#DEFINITIONS:`): imports cleanly, definitions untouched.
- Import (new backup, `.mergeIfEmpty`): definitions applied only if device has none.
- Import (new backup, `.replaceAll`): definitions always overwritten.
- Conflict sheet: appears when merge-mode backup has definitions that differ from device.
- No Swift 6 concurrency warnings: all `CustomCounterService.shared` calls are on main thread via `DispatchQueue.main.async` in the service layer and direct `@MainActor` context in the UI.
