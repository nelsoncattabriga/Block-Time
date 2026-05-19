---
phase: quick-260519-jer
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Views/Screens/Settings/SettingsView.swift
autonomous: true
requirements:
  - QUICK-260519-JER-01
must_haves:
  truths:
    - '"Add Field" button appears at the TOP of InlineCustomFieldsView, above the field list / empty state'
    - 'Field list (when populated) blends into parent card — no nested rounded background or fixed-height frame'
    - 'List sizes naturally to its row content (no per-row 44pt frame math)'
    - 'Drag-to-reorder still works via edit mode + onMove'
    - 'Tapping a row still opens FieldEditSheet via editingDefinition'
    - 'Empty state text "No fields added yet." still shown when service.definitions is empty'
    - 'CustomFieldsSettingsView is completely untouched'
  artifacts:
    - path: 'Block-Time/Views/Screens/Settings/SettingsView.swift'
      provides: 'Restructured InlineCustomFieldsView (Add Field at top, natural list height, no nested background)'
      contains: 'struct InlineCustomFieldsView'
  key_links:
    - from: 'InlineCustomFieldsView body VStack'
      to: 'Add Field button'
      via: 'first child element (before if/else)'
      pattern: 'VStack.*Button\("Add Field"'
    - from: 'List of CustomCounterDefinition rows'
      to: 'parent Crew & Ops card background'
      via: 'no .background / .clipShape / .frame(height:) modifiers on the List'
      pattern: 'List.*\.environment\(\\\.editMode'
---

<objective>
Surgically restructure `InlineCustomFieldsView` in `SettingsView.swift` so the "Add Field" button sits at the top, the inner List sizes naturally, and the List no longer has its own rounded background — letting it blend into the parent Crew & Ops card.

Purpose: Improve visual hierarchy (primary action up top, easier to reach) and remove a visually noisy nested card-within-a-card.
Output: Modified `InlineCustomFieldsView` block in `Block-Time/Views/Screens/Settings/SettingsView.swift` (~lines 2441–2525). No other types, no other files.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md
@Block-Time/Views/Screens/Settings/SettingsView.swift

# Prior related quick tasks (for context only — do not re-read unless needed):
# - 260519-ir7: converted InlineCustomFieldsView to List with drag-reorder + swipe-delete
# - 260519-j10: suppressed swipe-to-delete circles (delete moved to FieldEditSheet)

<interfaces>
<!-- Current shape of InlineCustomFieldsView body (lines 2447–2495 of SettingsView.swift). -->
<!-- Executor edits this single struct only. CustomFieldsSettingsView (line 2529+) MUST NOT be touched. -->

Outer container: VStack(alignment: .leading, spacing: 8)

Current order inside VStack:
  1. if service.definitions.isEmpty { Text("No fields added yet.") } else { List { ... }.<modifiers> }
  2. Divider()
  3. Button("Add Field", systemImage: "plus.circle.fill") { showingAddSheet = true }

Sheet modifiers on the VStack (KEEP as-is):
  .sheet(isPresented: $showingAddSheet) { FieldEditSheet(mode: .add) { ... } }
  .sheet(item: $editingDefinition) { definition in FieldEditSheet(mode: .edit(definition)) { ... } onDelete: { ... } }

Service: `CustomCounterService.shared` exposes `.definitions` (array) and `.move(fromOffsets:toOffset:)`.
Helpers `iconFor(_:)` and `colorFor(_:)` (lines 2510–2524) MUST remain unchanged.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Restructure InlineCustomFieldsView body</name>
  <files>Block-Time/Views/Screens/Settings/SettingsView.swift</files>
  <action>
Invoke the `swiftui-pro` skill via the Skill tool before writing any Swift.

Edit ONLY the `body` of `struct InlineCustomFieldsView` (lines ~2447–2495). Do NOT touch the sheet modifiers, the helpers (`iconFor`, `colorFor`), or `CustomFieldsSettingsView`.

Apply these changes in order:

1. **Move "Add Field" button to the TOP of the outer VStack.** It becomes the first child, before the `if service.definitions.isEmpty` block. Keep the exact same button definition:
   ```swift
   Button("Add Field", systemImage: "plus.circle.fill", action: { showingAddSheet = true })
       .font(.subheadline)
       .foregroundStyle(.blue)
       .buttonStyle(.plain)
   ```
   Remove the `.padding(.top, 8)` from the button — it's no longer the last item, so the leading top-padding is no longer appropriate. (The outer VStack's `spacing: 8` already provides spacing to the next element.)

2. **Delete the `Divider()`** that previously sat between the List and the button. Not needed any more.

3. **Remove from the List modifier chain:**
   - `.frame(height: CGFloat(service.definitions.count) * 44)`
   - `.clipShape(RoundedRectangle(cornerRadius: 8))`
   - `.background(Color(.secondarySystemBackground).clipShape(RoundedRectangle(cornerRadius: 8)))`

4. **KEEP all of these on the List exactly as they are:**
   - `.listStyle(.plain)`
   - `.scrollContentBackground(.hidden)`
   - `.scrollDisabled(true)`
   - `.environment(\.editMode, .constant(.active))`
   - `.onMove { source, destination in service.move(fromOffsets: source, toOffset: destination) }`

5. **KEEP unchanged inside each row:**
   - The `Button { editingDefinition = definition } label: { HStack ... }` row body
   - `.buttonStyle(.plain)`
   - `.listRowBackground(Color(.secondarySystemBackground))`
   - `.deleteDisabled(true)`

6. **KEEP unchanged:** the empty-state `Text("No fields added yet.")` with its modifiers, and both `.sheet` modifiers at the end of the body.

Final structure of the VStack body should be:
```
VStack(alignment: .leading, spacing: 8) {
    Button("Add Field", ...) { showingAddSheet = true }
        .font(.subheadline)
        .foregroundStyle(.blue)
        .buttonStyle(.plain)

    if service.definitions.isEmpty {
        Text("No fields added yet.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    } else {
        List { ... rows unchanged ... }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .environment(\.editMode, .constant(.active))
    }
}
.sheet(isPresented: $showingAddSheet) { ... }
.sheet(item: $editingDefinition) { ... }
```

Do NOT add new modifiers, do NOT change spacing values, do NOT refactor the row Button, do NOT touch `CustomFieldsSettingsView` further down the file.
  </action>
  <verify>
    <automated>MISSING — Nelson builds locally. Run `grep -n 'Add Field\|frame(height: CGFloat(service.definitions\|secondarySystemBackground).clipShape' Block-Time/Views/Screens/Settings/SettingsView.swift` and confirm: (a) "Add Field" appears inside InlineCustomFieldsView before the if/else, (b) no `frame(height: CGFloat(service.definitions...` line remains inside InlineCustomFieldsView, (c) no `secondarySystemBackground).clipShape` on the List inside InlineCustomFieldsView (the row-level `listRowBackground(Color(.secondarySystemBackground))` MUST still be present).</automated>
  </verify>
  <done>
    - "Add Field" button is the first element inside InlineCustomFieldsView's outer VStack
    - Divider() between list and button is gone
    - List has no `.frame(height:)`, no `.clipShape`, no `.background` modifier
    - All other modifiers, sheets, helpers, and `CustomFieldsSettingsView` are unchanged
    - File still compiles (Nelson builds locally)
  </done>
</task>

</tasks>

<verification>
- `grep -n "struct InlineCustomFieldsView" Block-Time/Views/Screens/Settings/SettingsView.swift` — still exists
- `grep -n "struct CustomFieldsSettingsView" Block-Time/Views/Screens/Settings/SettingsView.swift` — still exists, unchanged
- Manual diff vs prior version shows only the four targeted changes inside `InlineCustomFieldsView.body`
</verification>

<success_criteria>
- "Add Field" button is at the top of `InlineCustomFieldsView`
- List sizes to its rows naturally (no fixed-height math, no nested rounded background)
- All existing behaviour preserved: drag-reorder, tap-to-edit, empty state, both sheets
- `CustomFieldsSettingsView` untouched
- Nelson builds locally and confirms visually
</success_criteria>

<output>
After completion, create `.planning/quick/260519-jer-restructure-inlinecustomfieldsview-add-f/260519-jer-SUMMARY.md`.
</output>
