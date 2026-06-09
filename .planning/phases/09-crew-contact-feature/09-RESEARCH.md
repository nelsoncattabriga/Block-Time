# Phase 09: Crew Contact Feature - Research

**Researched:** 2026-05-31
**Domain:** Core Data entity addition, SwiftUI sheet presentation, CSV backup format extension
**Confidence:** HIGH

---

## Summary

The Crew Contact Feature adds a `CrewContactEntity` to the existing Core Data model (lightweight migration, purely additive) and surfaces it via an ⓘ info button injected into `ModernCrewField`. The codebase already has a complete pattern for embedding metadata JSON in backup CSV files via the `#DEFINITIONS:` prefix line; crew contacts follow the same pattern using a `#CONTACTS:` prefix line appended after `#DEFINITIONS:`. The restore path in `quickRestoreFromBackup` will need an additional parsing pass for this line.

All crew contact CRUD sits in a new `CrewContactService` (`@Observable @MainActor` singleton) matching the pattern of `CustomCounterService`. The Core Data `viewContext.performAndWait` pattern from `FlightDatabaseService` applies directly.

**Primary recommendation:** Follow the `CustomCounterService` + `#DEFINITIONS:` backup pattern exactly — the planner should model the new service, Core Data entity, and backup extension on those two existing patterns.

---

## Project Constraints (from CLAUDE.md)

- Do not make changes until 95% confidence. Ask follow-up questions if needed.
- Never remove existing features, buttons, logic, or behaviour.
- Use Swift 6 strict concurrency, `@Observable`, `async/await`.
- `NavigationView` → `NavigationStack`; toolbar placements `.topBarLeading`/`.topBarTrailing`.
- Previews using `ThemeService` child views must inject `.environment(ThemeService.shared)`.
- Always use semantic font sizes; never `Font.system(size:)`.
- Always apply changes to both `FlightsSplitView.swift` and `FlightsView.swift` for flight list changes (not relevant here, but noted).
- `swiftui-pro` skill must be invoked before writing or editing Swift code.

---

## Research Question Answers

### 1. Core Data schema — exact structure

File: `Block-Time/FlightDataModel.xcdatamodeld/FlightDataModel.xcdatamodel/contents`

Entities present:
- `AircraftEntity` — all attributes `optional="YES"` (CloudKit-compatible)
- `FlightEntity` — all attributes `optional="YES"` (CloudKit-compatible)

No `CrewContactEntity` exists yet. Adding it is a purely additive lightweight migration — no existing attributes change, so no `NSMigratePersistentStoresAutomaticallyOption`/mapping model complexity is needed.

**CloudKit constraint confirmed:** Every existing attribute uses `optional="YES"`. `CrewContactEntity` must follow the same rule — both `name` and `notes` must be declared `optional="YES"` in the `.xcdatamodel`, even though `name` is logically required. Enforce non-nil at the application layer (Swift guard, service layer), not at the data model layer.

The model XML line to add:
```xml
<entity name="CrewContactEntity" representedClassName="CrewContactEntity" syncable="YES" codeGenerationType="class">
    <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
    <attribute name="name" optional="YES" attributeType="String"/>
    <attribute name="notes" optional="YES" attributeType="String"/>
    <attribute name="createdAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="modifiedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
</entity>
```

A new model version is required. The existing model is unversioned (`userDefinedModelVersionIdentifier=""`). The correct approach for a lightweight migration is:
1. Duplicate the `.xcdatamodel` directory inside the `.xcdatamodeld` bundle to create `FlightDataModel 2.xcdatamodel`.
2. Add the entity to the new version.
3. Set the new version as current.
4. Set `NSMigratePersistentStoresAutomaticallyOption = true` and `NSInferMappingModelAutomaticallyOption = true` (already set by `NSPersistentCloudKitContainer` by default).

Lightweight migration is automatic for additive changes — no custom mapping model needed.

---

### 2. FlightDatabaseService CRUD patterns

File: `Block-Time/Services/FlightDatabaseService.swift`

The service uses `viewContext.performAndWait { }` for all synchronous read/write operations. The standard pattern:

```swift
// Fetch
let request: NSFetchRequest<CrewContactEntity> = CrewContactEntity.fetchRequest()
request.predicate = NSPredicate(format: "name ==[c] %@", name)
request.fetchLimit = 1
let results = try viewContext.fetch(request)

// Save
let contact = CrewContactEntity(context: viewContext)
contact.id = UUID()
contact.name = name
contact.notes = notes
contact.createdAt = Date()
contact.modifiedAt = Date()
try viewContext.save()

// Delete
viewContext.delete(contact)
try viewContext.save()
```

`FlightDatabaseService` is an `ObservableObject` singleton with `var viewContext: NSManagedObjectContext { persistentContainer.viewContext }` (line 175). The `CrewContactService` should use this same `viewContext` — it does not need its own Core Data stack.

`FlightDatabaseService` is still `ObservableObject` (not yet migrated to `@Observable` — this is by design per MEMORY.md: "do not migrate"). The new `CrewContactService` should use `@Observable @MainActor` matching `CustomCounterService`.

---

### 3. ModernCrewField layout — where to insert ⓘ button

File: `Block-Time/Views/Components/AddFlightView/FlightFormFields.swift`, lines 294–361

`ModernCrewField` is an `HStack` with three elements:
1. `Image(systemName: icon)` — left icon
2. `VStack` with label + value text — centre (fills Spacer)
3. Either lock icon or `Image(systemName: "chevron.right")` — right

The ⓘ button inserts as a fourth element between the value VStack and the chevron, only when `!isDisabled`. It is disabled (greyed out, no tap) when `value.isEmpty`.

```swift
// After Spacer(), before the existing chevron/lock block:
Button {
    showingContactSheet = true
} label: {
    Image(systemName: "info.circle")
        .font(.subheadline)
        .foregroundColor(value.isEmpty ? .secondary.opacity(0.4) : .blue)
}
.buttonStyle(PlainButtonStyle())
.disabled(value.isEmpty || isDisabled)
```

`ModernCrewField` needs two new parameters:
- `crewContactService: CrewContactService` (injected, not a singleton call inside the view — keeps it testable)
- Or simpler: the view looks up the contact by `value` from a shared service in `.sheet`

The simplest approach matching the codebase style: add `@State private var showingContactSheet = false` to `ModernCrewField` and present a `CrewContactSheet` as an additional `.sheet(isPresented:)`. The view does not need to be passed a contact directly — the sheet fetches/creates on appear using the name binding.

**Risk:** `ModernCrewField` already has one `.sheet(isPresented: $showingPicker)`. iOS supports chained `.sheet` modifiers but behaviour can be unpredictable in some iOS versions. Safer pattern: use a single `@State private var activeSheet: CrewFieldSheet?` enum with two cases (`.picker`, `.contact`).

`ModernCrewField` is defined in `FlightFormFields.swift` and used in `CrewOpsCard.swift` (lines 85, 99, 115, 129). No changes needed to `CrewOpsCard.swift` if the ⓘ button is embedded in `ModernCrewField` itself.

`BulkEditCrewField` (file: `Views/Screens/BulkEdit/BulkEditCrewFields.swift`) is a separate component used in `BulkEditSheet`. The feature spec says "all crew name picker fields" — verify with Nelson whether BulkEdit is in scope before adding ⓘ there. The feature spec mentions only "captain, FO, SO1, SO2" in AddFlightView context; BulkEdit is likely out of scope for this phase.

---

### 4. CSV backup format — exact spec

File: `Block-Time/Services/FileImportService.swift`, lines 1258–1324 (export) and 835–956 (restore)

**Current export order:**
```
#DEFINITIONS:{json}\n        ← line 1 if definitions exist, omitted otherwise
Date,Flight Number,...\n     ← header row
row1\n
row2\n
...
```

**Restore parsing order (quickRestoreFromBackup):**
1. Read raw content.
2. If `lines.first?.hasPrefix("#DEFINITIONS:")` → extract definitions JSON, strip line, write remainder to temp file, parse as CSV.
3. Otherwise parse directly.

The `#DEFINITIONS:` line is always **first** (before the CSV header row). This is important — crew contacts cannot also go on line 1.

**Crew contacts backup placement:** Append a `#CONTACTS:` line **after** the `#DEFINITIONS:` line (if present) and **before** the CSV header row. The restore parser must check both lines before reaching the CSV header.

**Revised export order (with both features):**
```
#DEFINITIONS:{json}\n        ← optional, line 1
#CONTACTS:{json}\n           ← optional, line 2 (or line 1 if no definitions)
Date,Flight Number,...\n     ← CSV header
rows...
```

**Crew contacts JSON format** (consistent with `CustomCounterDefinition` pattern):
```json
[{"id":"UUID-string","name":"John Smith","notes":"Notes text here"}]
```

**Restore merge rule:** When a `CrewContactEntity` with the same `name` already exists, keep the record whose `notes` string is longer. If lengths are equal, keep existing (no-op).

**exportToCSV signature impact:** The existing `exportToCSV(flights:definitions:useLabelsAsHeaders:writeDefinitionsHeader:)` receives `definitions` as a passed-in parameter (thread-safe). The same pattern applies: the backup service captures crew contacts on the main thread before dispatching to `DispatchQueue.global(qos: .utility)`.

In `AutomaticBackupService.performBackup` (line 268): currently captures `counterDefinitions` before background dispatch. Add `let crewContacts = CrewContactService.shared.fetchAll()` alongside it.

---

### 5. CloudKit constraints checklist

| Constraint | Status for CrewContactEntity |
|------------|------------------------------|
| All attributes optional="YES" | Required — enforce at app layer |
| No @Attribute(.unique) | Not used — name lookup is by predicate, not unique constraint |
| No non-optional relationships | No relationships defined |
| syncable="YES" on entity | Required |
| UUID primary key | id: UUID, optional="YES" |
| No default non-nil values at model layer | Confirmed — use Swift defaults in service layer |

The entity gets CloudKit sync for free via the existing `NSPersistentCloudKitContainer` — no additional configuration needed.

---

### 6. Swift 6 concurrency for Core Data

`FlightDatabaseService` uses `viewContext.performAndWait { }` (synchronous, main-thread-safe). It is an `ObservableObject`, not `@Observable`, and all calls to `viewContext` happen via `performAndWait`.

`CrewContactService` should be `@Observable @MainActor` (like `CustomCounterService`). Its Core Data calls should use `FlightDatabaseService.shared.viewContext.performAndWait { }` or (simpler) call a dedicated method on `FlightDatabaseService` that performs the work on its `viewContext`.

The spec requires only 3 operations: fetch-by-name, upsert (create-or-update), delete. These are all synchronous on the main actor — no background thread needed. No `ModelActor` complexity.

---

### 7. AutomaticBackupService injection point

File: `Block-Time/Services/AutomaticBackupService.swift`, lines 257–312

The `performBackup` function:
1. Line 268: captures `counterDefinitions` on main thread.
2. Line 270: dispatches to `DispatchQueue.global(qos: .utility)`.
3. Line 290: calls `FileImportService.shared.exportToCSV(flights:definitions:)`.

**Crew contacts injection:**
- Add `let crewContactsSnapshot = CrewContactService.shared.fetchAll()` alongside line 268 (main thread capture).
- Pass `crewContacts: crewContactsSnapshot` into `exportToCSV`.
- `exportToCSV` prepends `#CONTACTS:{json}\n` after `#DEFINITIONS:` line.

---

## Architecture Patterns

### Recommended File Structure

```
Block-Time/Services/
└── CrewContactService.swift      ← new @Observable @MainActor singleton

Block-Time/Views/Components/AddFlightView/
├── FlightFormFields.swift         ← modify ModernCrewField (add ⓘ button + sheet)
└── CrewContactSheet.swift         ← new sheet view (name read-only, notes TextEditor, Save/Cancel)

Block-Time/FlightDataModel.xcdatamodeld/
├── FlightDataModel.xcdatamodel/   ← existing (keep as version 1)
└── FlightDataModel 2.xcdatamodel/ ← new version with CrewContactEntity added
```

### CrewContactService Pattern

Modelled directly on `CustomCounterService` (`@Observable @MainActor singleton`) but backed by Core Data instead of UserDefaults:

```swift
@Observable @MainActor
final class CrewContactService {
    static let shared = CrewContactService()

    // fetchAll, fetchContact(name:), upsert(name:notes:), delete(name:)
    // All call FlightDatabaseService.shared.viewContext.performAndWait { }
}
```

### Sheet Enum Pattern for ModernCrewField

```swift
private enum ActiveSheet: Identifiable {
    case picker
    case contact
    var id: Int { hashValue }
}
@State private var activeSheet: ActiveSheet?
```

Use `.sheet(item: $activeSheet)` with a switch to present either `CrewNamePickerSheet` or `CrewContactSheet`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| JSON encoding crew contacts | Custom serializer | `JSONEncoder`/`JSONDecoder` (same as `CustomCounterDefinition`) |
| Lightweight Core Data migration | Manual mapping model | `NSMigratePersistentStoresAutomaticallyOption` + `NSInferMappingModelAutomaticallyOption` (already active) |
| CloudKit sync for new entity | Any custom sync code | Inherited from `NSPersistentCloudKitContainer` automatically |

---

## Common Pitfalls

### Pitfall 1: Non-optional `name` attribute breaks CloudKit
**What goes wrong:** Declaring `name` as `optional="NO"` in the `.xcdatamodel` causes CloudKit to refuse to sync the record type — CloudKit requires all attributes to be optional.
**How to avoid:** Set `optional="YES"` in XML. Guard against nil at the service layer with `guard let name = entity.name, !name.isEmpty else { return }`.

### Pitfall 2: Multiple `.sheet()` modifiers on same view
**What goes wrong:** iOS can silently ignore or misbehave when two `.sheet(isPresented:)` modifiers are on the same view hierarchy level.
**How to avoid:** Use a single `.sheet(item:)` with an enum (see ActiveSheet pattern above).

### Pitfall 3: Model version not set as current
**What goes wrong:** Adding attributes to the existing unversioned model without creating a new version causes Core Data to fail lightweight migration on devices that already have the store.
**How to avoid:** Always create a new `.xcdatamodel` version. Set it as the current version in Xcode's Data Model Inspector. The existing (unversioned) model becomes version 1 for devices doing first install; devices upgrading from v1 get the automatic lightweight migration.

### Pitfall 4: Capturing `CrewContactService.shared` on background thread
**What goes wrong:** `CrewContactService` is `@MainActor`. Accessing it from `DispatchQueue.global` (inside `performBackup`) without a capture will cause a concurrency violation at runtime.
**How to avoid:** Capture `let contacts = CrewContactService.shared.fetchAll()` on the main thread before the `DispatchQueue.global` dispatch — exactly as done for `counterDefinitions` at line 268 of `AutomaticBackupService`.

### Pitfall 5: `#CONTACTS:` line position breaks CSV parse
**What goes wrong:** The CSV parser in `parseFile` uses the first line as headers. If `#CONTACTS:` is not stripped before the temp file is written, `"#CONTACTS:..."` becomes the header row.
**How to avoid:** Strip both `#DEFINITIONS:` and `#CONTACTS:` prefix lines from `rawContent` before passing to `parseFile`. Process all prefix lines in a loop: strip any line starting with `#` and ending with a JSON payload before the first non-`#` line.

---

## Code Examples

### Add entity to XML model (verified — matches existing pattern)
```xml
<!-- In FlightDataModel 2.xcdatamodel/contents, alongside existing entities -->
<entity name="CrewContactEntity" representedClassName="CrewContactEntity" syncable="YES" codeGenerationType="class">
    <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
    <attribute name="name" optional="YES" attributeType="String"/>
    <attribute name="notes" optional="YES" attributeType="String"/>
    <attribute name="createdAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="modifiedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
</entity>
```

### exportToCSV crew contacts injection (based on existing #DEFINITIONS: pattern)
```swift
// In exportToCSV, immediately after the #DEFINITIONS: block:
if writeDefinitionsHeader,
   !crewContacts.isEmpty,
   let data = try? JSONEncoder().encode(crewContacts),
   let json = String(data: data, encoding: .utf8) {
    result += "#CONTACTS:\(json)\n"
}
```

### Restore: strip both prefix lines
```swift
var remainingLines = rawContent.components(separatedBy: .newlines)
var extractedDefinitions: [CustomCounterDefinition]? = nil
var extractedContacts: [CrewContactBackup]? = nil

while let first = remainingLines.first, first.hasPrefix("#") {
    if first.hasPrefix("#DEFINITIONS:") {
        // decode definitions...
    } else if first.hasPrefix("#CONTACTS:") {
        // decode contacts...
    }
    remainingLines.removeFirst()
}
// remainingLines now starts with the CSV header row
```

### CrewContactService fetch pattern
```swift
func fetchContact(name: String) -> CrewContactEntity? {
    var result: CrewContactEntity?
    FlightDatabaseService.shared.viewContext.performAndWait {
        let request: NSFetchRequest<CrewContactEntity> = CrewContactEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1
        result = try? FlightDatabaseService.shared.viewContext.fetch(request).first
    }
    return result
}
```

---

## Backup Format Specification

```
#DEFINITIONS:{CustomCounterDefinition JSON array}\n   ← omitted if no counter definitions
#CONTACTS:{CrewContactBackup JSON array}\n             ← omitted if no crew contacts
Date,Flight Number,Aircraft Reg,...,Counter1,...\n    ← CSV header (existing, unchanged)
row1\n
...
```

`CrewContactBackup` struct (Codable, used only for backup serialisation):
```swift
struct CrewContactBackup: Codable {
    let id: String          // UUID string
    let name: String
    let notes: String       // empty string if nil
}
```

**Restore merge logic:**
```swift
// On restore, for each contact in extractedContacts:
if let existing = fetchContact(name: contact.name) {
    if contact.notes.count > (existing.notes?.count ?? 0) {
        existing.notes = contact.notes
        existing.modifiedAt = Date()
    }
    // else keep existing — no-op
} else {
    // create new
}
```

---

## Open Questions

1. **BulkEditCrewField scope**
   - What we know: `BulkEditCrewField` (in `BulkEditCrewFields.swift`) also presents crew name pickers for Captain, F/O, SO1, SO2.
   - What's unclear: Feature spec says "all crew name picker fields" but only lists AddFlight fields by name.
   - Recommendation: Confirm with Nelson whether ⓘ is wanted in BulkEdit. Default assumption: out of scope for this phase.

2. **Notes field max length**
   - What we know: Core Data `String` has no practical size limit; CloudKit String field limit is 1 MB.
   - What's unclear: Whether a UI character limit or line limit is desired.
   - Recommendation: No programmatic limit; TextEditor will scroll naturally.

3. **Versioning the unversioned model**
   - What we know: The current `.xcdatamodeld` has `userDefinedModelVersionIdentifier=""` (unversioned, single model).
   - What's unclear: Whether Nelson has already set a model version in Xcode (not visible in XML, set in `.xccurrentversion` plist).
   - Recommendation: Check for `.xccurrentversion` file before creating version 2. If absent, the model is truly unversioned and creating version 2 is straightforward.

---

## Environment Availability

Step 2.6: SKIPPED — no external dependencies. This is a pure Core Data + SwiftUI change within the existing app target.

---

## Sources

### Primary (HIGH confidence)
- Direct reading of `FlightDataModel.xcdatamodel/contents` — entity XML confirmed
- Direct reading of `FileImportService.swift` lines 1258–1324 (export), 835–956 (restore) — backup format confirmed
- Direct reading of `CustomCounterService.swift` — service pattern confirmed
- Direct reading of `FlightFormFields.swift` lines 294–361 — `ModernCrewField` layout confirmed
- Direct reading of `FlightDatabaseService.swift` lines 235–314, 983–1007 — CRUD pattern confirmed
- Direct reading of `AutomaticBackupService.swift` lines 257–312 — backup injection point confirmed
- Stack research (`STACK.md` in CLAUDE.md) — CloudKit all-optional constraint confirmed HIGH

### Secondary (MEDIUM confidence)
- Project MEMORY.md — `FlightDatabaseService` intentionally stays `ObservableObject`, confirmed by project notes

---

## Metadata

**Confidence breakdown:**
- Core Data schema + migration: HIGH — read directly from source XML
- CloudKit constraints: HIGH — verified against existing entity XML and STACK.md research
- ModernCrewField layout + ⓘ insertion: HIGH — read exact view code
- Backup format spec: HIGH — read exact export/restore code paths
- Swift 6 concurrency pattern: HIGH — existing codebase uses `performAndWait` throughout
- BulkEdit scope: LOW — feature spec ambiguous; needs clarification

**Research date:** 2026-05-31
**Valid until:** 2026-06-30 (stable codebase, no fast-moving deps)

---

## RESEARCH COMPLETE
