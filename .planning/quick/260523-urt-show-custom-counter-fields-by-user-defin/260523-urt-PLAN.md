---
id: 260523-urt
type: quick
autonomous: true
files_modified:
  - Block-Time/Views/Screens/Settings/ImportMappingView.swift
---

<objective>
Show custom counter fields by user-defined label in ImportMappingView instead of the generic "Counter1"–"Counter10" key string.

Two display sites to fix:
1. Mapping list row header (line 888) — currently `Text(mapping.logbookField)`
2. PreviewRowView label column (line 2012) — currently `Text(mapping.logbookField + ":")`

`logbookFieldDescription` already holds the correct display value (user label or "Custom Field N") and is set during `fieldMappings` construction (line 639). `logbookField` must remain unchanged — it is used for all logic and matching.
</objective>

<context>
@Block-Time/Views/Screens/Settings/ImportMappingView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Use logbookFieldDescription for display in both mapping row header and PreviewRowView</name>
  <files>Block-Time/Views/Screens/Settings/ImportMappingView.swift</files>
  <action>
Make exactly two changes — no other modifications:

CHANGE 1 — Mapping list row header (around line 888):
Find:
```swift
Text(mapping.logbookField)
    .font(.subheadline)
    .fontWeight(.semibold)
```
Replace with:
```swift
Text(mapping.logbookFieldDescription.isEmpty ? mapping.logbookField : mapping.logbookFieldDescription)
    .font(.subheadline)
    .fontWeight(.semibold)
```

CHANGE 2 — PreviewRowView label column (around line 2012):
Find:
```swift
Text(mapping.logbookField + ":")
```
Replace with:
```swift
Text((mapping.logbookFieldDescription.isEmpty ? mapping.logbookField : mapping.logbookFieldDescription) + ":")
```

Do NOT change any other uses of `mapping.logbookField` — those are logic/matching uses and must stay as-is.
  </action>
  <verify>
grep -n "logbookFieldDescription.isEmpty ? mapping.logbookField : mapping.logbookFieldDescription" "Block-Time/Views/Screens/Settings/ImportMappingView.swift" | wc -l
# Should output 2 (one for each change site)
  </verify>
  <done>Both display sites show logbookFieldDescription (e.g. "Approaches") instead of "Counter1". All logic uses of logbookField remain unchanged.</done>
</task>

</tasks>

<success_criteria>
- In the import mapping sheet, custom field rows display user-defined labels (e.g. "Approaches", "Landings") not "Counter1", "Counter2"
- PreviewRowView left-column labels show the same user-defined labels
- Undefined slots still show "Custom Field N" (the fallback already set in logbookFieldDescription)
- All field matching, save/load logic, and profile storage continue to use logbookField unchanged
</success_criteria>

<output>
After completion, create `.planning/quick/260523-urt-show-custom-counter-fields-by-user-defin/260523-urt-SUMMARY.md`
</output>
