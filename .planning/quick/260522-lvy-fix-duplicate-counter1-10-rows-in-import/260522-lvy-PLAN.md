---
phase: quick
plan: 260522-lvy
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Views/Screens/Settings/ImportMappingView.swift
autonomous: true
requirements:
  - QUICK-260522-LVY
must_haves:
  truths:
    - "Counter1…Counter10 rows appear ONLY inside the 'Custom Fields' section of ImportMappingView"
    - "The generic 'Field Mapping' section does NOT render any Counter1…Counter10 rows"
    - "Non-Counter mappings still render in the generic 'Field Mapping' section"
    - "Edits to Counter mappings in the 'Custom Fields' section still mutate the same underlying fieldMappings array (single source of truth preserved)"
  artifacts:
    - path: "Block-Time/Views/Screens/Settings/ImportMappingView.swift"
      provides: "Filtered ForEach in 'Field Mapping' section that excludes Counter\\d+ entries"
  key_links:
    - from: "ForEach($fieldMappings) in 'Field Mapping' section (~line 301)"
      to: "fieldMappings array"
      via: "filtered binding that drops entries whose logbookField matches /^Counter\\d+$/"
      pattern: "ForEach.*fieldMappings"
---

<objective>
Fix duplicate rendering of Counter1…Counter10 rows in ImportMappingView. Currently the generic `ForEach($fieldMappings)` loop in the "Field Mapping" section renders every mapping (including Counter1…10), and the dedicated "Custom Fields" section iterates slots 1–10 and renders them again via `CustomFieldSlotRow`. The fix excludes Counter\d+ entries from the generic loop so they appear only in the "Custom Fields" section.

Purpose: Eliminate visual duplication, prevent user confusion, and keep Counter slots controlled exclusively by `CustomFieldSlotRow` (which knows about slot definitions/labels).
Output: A single-file edit in `ImportMappingView.swift` that filters the generic ForEach binding without touching `createInitialMappings` or the "Custom Fields" section.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@Block-Time/Views/Screens/Settings/ImportMappingView.swift

<interfaces>
<!-- Relevant existing structure in ImportMappingView.swift -->

Generic "Field Mapping" section (~line 289–307):
```swift
Section(header: Text("Field Mapping")) {
    if let profileName = detectedProfileName { ... }
    ForEach($fieldMappings) { $mapping in
        FieldMappingRow(
            mapping: $mapping,
            availableHeaders: importData.headers
        )
    }
}
```

Dedicated "Custom Fields" section (~line 309–329) — DO NOT MODIFY:
```swift
Section(header: Text("Custom Fields")) {
    ForEach(1...10, id: \.self) { slot in
        let service = CustomCounterService.shared
        let def = service.definition(for: slot)
        let mappingIndex = fieldMappings.firstIndex { $0.logbookField == "Counter\(slot)" }
        if let idx = mappingIndex {
            CustomFieldSlotRow(
                slot: slot,
                mapping: $fieldMappings[idx],
                ...
            )
        }
    }
}
```

`createInitialMappings` (~line 610–632) appends Counter1…Counter10 FieldMapping entries to `fieldMappings`. DO NOT MODIFY — the array must continue to hold these entries because the "Custom Fields" section looks them up by `logbookField == "Counter\(slot)"`.

FieldMapping.logbookField is a `String` (e.g. "Date", "BlockTime", "Counter1" … "Counter10").
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Filter Counter\d+ entries out of the generic Field Mapping ForEach</name>
  <files>Block-Time/Views/Screens/Settings/ImportMappingView.swift</files>
  <action>
In `ImportMappingView.swift`, locate the generic `ForEach($fieldMappings) { $mapping in ... }` block inside the `Section(header: Text("Field Mapping"))` (around line 301).

Replace the unfiltered ForEach with a filtered-binding version that excludes any `FieldMapping` whose `logbookField` matches the pattern `Counter` followed by one or more digits and nothing else (so it skips Counter1…Counter10 — and any future Counter\d+ slots — while still rendering ordinary fields like "Date", "BlockTime", etc.).

Use a small private helper computed on the view (or an inline closure) so the predicate is readable. Recommended implementation:

```swift
// Add this helper inside ImportMappingView (near other private helpers):
private func isCustomCounterField(_ logbookField: String) -> Bool {
    guard logbookField.hasPrefix("Counter") else { return false }
    let suffix = logbookField.dropFirst("Counter".count)
    return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
}
```

Then change the generic ForEach to use a filtered binding. The pattern for filtering a SwiftUI binding to a collection is to bind to indices of the filtered subset. Use this approach:

```swift
ForEach($fieldMappings) { $mapping in
    if !isCustomCounterField(mapping.logbookField) {
        FieldMappingRow(
            mapping: $mapping,
            availableHeaders: importData.headers
        )
    }
}
```

Rationale for the conditional-inside-ForEach approach (rather than `.filter` on the binding):
- `Binding<[FieldMapping]>` does not have a `.filter` that preserves write-back; using `.filter` on the array would break two-way binding.
- ForEach over the full bindings collection with an `if` inside is the SwiftUI-idiomatic way to conditionally render a subset while keeping each row's binding write-back intact.
- `FieldMappingRow` and `CustomFieldSlotRow` both bind into the same `fieldMappings` array, so edits stay consistent — we are only suppressing the DUPLICATE rendering, not removing the underlying data.

DO NOT:
- Modify `createInitialMappings` — Counter entries must remain in `fieldMappings` because the "Custom Fields" section looks them up by `logbookField`.
- Modify the "Custom Fields" Section (~line 309–329).
- Use a regex literal (`/^Counter\d+$/`) — keep the helper simple and Swift 5/6 compatible without `Regex` overhead.
- Rename or restructure `FieldMapping`.
  </action>
  <verify>
    <automated>grep -n "isCustomCounterField" Block-Time/Views/Screens/Settings/ImportMappingView.swift && grep -n "ForEach(\$fieldMappings)" Block-Time/Views/Screens/Settings/ImportMappingView.swift</automated>
    Manual (user will build locally, per CLAUDE.md): open ImportMappingView, trigger an import with any CSV, confirm Counter1…Counter10 appear ONLY under "Custom Fields" and NOT under "Field Mapping".
  </verify>
  <done>
    - `isCustomCounterField(_:)` helper exists in ImportMappingView.
    - Generic `ForEach($fieldMappings)` inside `Section(header: Text("Field Mapping"))` wraps `FieldMappingRow` in `if !isCustomCounterField(mapping.logbookField)`.
    - `createInitialMappings` is unchanged.
    - "Custom Fields" Section is unchanged.
    - No other call sites of `fieldMappings` are altered.
  </done>
</task>

</tasks>

<verification>
- `grep -c "FieldMappingRow(" Block-Time/Views/Screens/Settings/ImportMappingView.swift` still returns the same count as before (only the WRAPPING `if` is added, not removed).
- Counter1…Counter10 rows render exactly once in the UI (under "Custom Fields").
- Non-Counter fields (Date, BlockTime, etc.) render exactly once in "Field Mapping".
- Editing a Counter mapping via `CustomFieldSlotRow` still writes back to `fieldMappings` (single source of truth maintained).
</verification>

<success_criteria>
- Single file modified: `Block-Time/Views/Screens/Settings/ImportMappingView.swift`.
- Duplicate Counter1…Counter10 rendering is eliminated.
- `createInitialMappings` and the "Custom Fields" section are byte-for-byte unchanged.
- No existing feature, button, or behavior removed (per CLAUDE.md).
- No build invoked by Claude (Nelson builds locally).
</success_criteria>

<output>
After completion, create `.planning/quick/260522-lvy-fix-duplicate-counter1-10-rows-in-import/260522-lvy-SUMMARY.md`.
</output>
