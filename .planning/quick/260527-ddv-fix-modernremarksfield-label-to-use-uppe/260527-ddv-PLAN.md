---
phase: quick-260527-ddv
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift
autonomous: true
requirements: [QUICK-260527-ddv]
must_haves:
  truths:
    - "Text-type custom field label in ModernRemarksField renders in uppercase, matching time/decimal/integer field labels"
  artifacts:
    - path: "Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift"
      provides: "ModernRemarksField label rendered with .uppercased()"
      contains: "Text(label.uppercased())"
  key_links:
    - from: "ModernRemarksField.body"
      to: "label"
      via: "Text(label.uppercased())"
      pattern: "Text\\(label\\.uppercased\\(\\)\\)"
---

<objective>
Make the text-type custom field label match the capitalisation of time/decimal/integer custom field types by uppercasing the label in `ModernRemarksField`.

Purpose: Visual consistency — text-type custom fields currently show their label in mixed case while all other custom field types uppercase the label. Pilots see an inconsistent header style in AddFlightView.

Output: One-line change in `FlightTimeFields.swift` so `ModernRemarksField` renders `Text(label.uppercased())`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md

Invoke the `swiftui-pro` skill before editing the Swift file (per CLAUDE.md).
</execution_context>

<context>
Target file and surrounding code (verified at planning time):

`Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift`, struct `ModernRemarksField`:

```swift
HStack {
    Image(systemName: icon)
        .foregroundColor(.blue)
        .frame(width: 20)

    Text(label)              // line 420 — change to Text(label.uppercased())
        .font(.caption.bold())
        .foregroundColor(.secondary)
}
```

The other custom field types (time/decimal/integer) already uppercase their labels — this brings the text type into line with them.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Uppercase the ModernRemarksField label</name>
  <files>Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift</files>
  <action>In struct `ModernRemarksField` `body`, change the label `Text(label)` (currently at line 420) to `Text(label.uppercased())`. Do not change `.font(.caption.bold())` or `.foregroundColor(.secondary)`. Do not touch any other `Text(label)` occurrences elsewhere in the file — only the one inside `ModernRemarksField`.</action>
  <verify>
    <automated>grep -n "Text(label.uppercased())" "Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift"</automated>
  </verify>
  <done>`ModernRemarksField` renders the label via `Text(label.uppercased())`; no other label sites changed.</done>
</task>

</tasks>

<verification>
- `grep -n "Text(label" Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift` shows the `ModernRemarksField` occurrence now reads `Text(label.uppercased())`.
- No other `Text(label)` site was modified.
</verification>

<success_criteria>
Text-type custom field header in AddFlightView displays in uppercase, matching the other custom field types. Single-line edit, no behaviour or feature removed.
</success_criteria>

<output>
After completion, create `.planning/quick/260527-ddv-fix-modernremarksfield-label-to-use-uppe/260527-ddv-SUMMARY.md`
</output>
