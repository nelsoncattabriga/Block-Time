---
phase: quick-260522-tsl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Models/CustomCounterDefinition.swift
  - Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift
  - Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
  - Block-Time/Views/Screens/Settings/SettingsView.swift
  - Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift
autonomous: true
requirements:
  - TSL-01

must_haves:
  truths:
    - "User can create a custom field with type 'Text' in Settings"
    - "Text fields render as a remarks-style multi-line input with placeholder 'Add text...' on Add/Edit Flight"
    - "Text fields show no totalling toggle in Settings field editor and never produce dashboard totals"
    - "Existing counter/integer/decimal/time field behaviour is unchanged"
  artifacts:
    - path: "Block-Time/Models/CustomCounterDefinition.swift"
      provides: ".text case on CounterType enum with displayName 'Text' and subtitle 'Notes, codes, or any text value'"
    - path: "Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift"
      provides: "ModernRemarksField with optional placeholder parameter (default 'Add remarks...')"
    - path: "Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift"
      provides: ".text branch in fieldRow switch using ModernRemarksField"
    - path: "Block-Time/Views/Screens/Settings/SettingsView.swift"
      provides: "iconFor/colorFor coverage for .text + hidden Total toggle when type==.text"
    - path: "Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift"
      provides: "loadStats early-return for .text + iconForType/colorForType coverage"
  key_links:
    - from: "CrewOpsCard.fieldRow"
      to: "ModernRemarksField"
      via: "switch case .text"
      pattern: "case \\.text:\\s*\\n\\s*ModernRemarksField"
    - from: "SettingsView.FieldEditSheet"
      to: "showTotal state"
      via: "onChange(of: type) forcing showTotal=false when .text"
      pattern: "if type != \\.text"
---

<objective>
Add a `.text` case to `CounterType` so users can create custom fields that store arbitrary text (notes, codes, identifiers) similar to the Remarks field. Text fields have no totalling and no dashboard card values — storage already supports them because counter1–counter10 are `String?` in Core Data.

Purpose: Round out the custom fields feature with non-numeric input. Pilots have asked for free-form text fields for crew names, route codes, etc.
Output: A new `.text` case wired through model, form input, Settings editor, and dashboard card so existing fields keep working and text fields behave correctly everywhere.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@Block-Time/Models/CustomCounterDefinition.swift
@Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift
@Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
@Block-Time/Views/Screens/Settings/SettingsView.swift
@Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift

<notes>
- Storage layer (counter1–counter10 as `String?`) is already text-capable. No Core Data migration.
- `ModernRemarksField` lives in `FlightTimeFields.swift` around line 415 with hardcoded "Add remarks..." placeholder — must accept a parameter while preserving default for existing Remarks usage.
- `SettingsView.swift` has THREE separate `iconFor`/`colorFor` switch blocks (around lines 2530-2544, 2633-2645, 2779-2792) and one `FieldEditSheet` Toggle (~line 2731) — every one must be updated.
- Always invoke the `swiftui-pro` skill before editing any Swift code (per CLAUDE.md).
- Do not remove or rename existing cases — additive change only.
</notes>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add .text case to CounterType and propagate placeholder support</name>
  <files>
    Block-Time/Models/CustomCounterDefinition.swift,
    Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift,
    Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
  </files>
  <action>
    Invoke the `swiftui-pro` skill before editing.

    1. `Block-Time/Models/CustomCounterDefinition.swift`
       - Add `case text` to the `CounterType` enum.
       - Update `displayName` switch to return `"Text"` for `.text`.
       - Update `subtitle` switch to return `"Notes, codes, or any text value"` for `.text`.
       - `id` and `CaseIterable` conformance pick this up automatically — verify nothing else in this file needs an exhaustive switch update; if there are other switches over `CounterType`, add the `.text` branch with the most sensible default (e.g. no totalling, treat-as-string).

    2. `Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift`
       - Locate `ModernRemarksField` (around line 415 with hardcoded `"Add remarks..."`).
       - Add a `placeholder: String = "Add remarks..."` parameter to the struct's stored properties and init.
       - Replace the hardcoded literal in the field's placeholder/prompt usage with the new `placeholder` property.
       - Default must remain `"Add remarks..."` so the existing Remarks invocation compiles unchanged.

    3. `Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift`
       - In `fieldRow(for:viewModel:keyboardToolbar:)` switch over `definition.type`, add:
         ```swift
         case .text:
             ModernRemarksField(
                 label: definition.label,
                 value: binding,
                 icon: "text.alignleft",
                 placeholder: "Add text...",
                 keyboardToolbar: keyboardToolbar
             )
         ```
       - Match the existing parameter order/labels used by `ModernRemarksField` after Task 1 step 2 — adjust if the real init differs (e.g. `text:` vs `value:`).

    Do NOT modify any other behaviour. Do NOT remove or rename existing enum cases or fields.
  </action>
  <verify>
    <automated>grep -n "case text" Block-Time/Models/CustomCounterDefinition.swift &amp;&amp; grep -n "placeholder:" Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift &amp;&amp; grep -n "case .text:" Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift</automated>
  </verify>
  <done>
    - `CounterType.text` exists with displayName "Text" and subtitle "Notes, codes, or any text value".
    - `ModernRemarksField` accepts a `placeholder` parameter defaulting to "Add remarks...".
    - `CrewOpsCard.fieldRow` renders `ModernRemarksField` with placeholder "Add text..." for `.text` definitions.
    - Existing Remarks field call site still compiles without changes.
  </done>
</task>

<task type="auto">
  <name>Task 2: Wire .text into SettingsView (icons, colours, hide Total toggle)</name>
  <files>Block-Time/Views/Screens/Settings/SettingsView.swift</files>
  <action>
    Invoke the `swiftui-pro` skill before editing.

    `Block-Time/Views/Screens/Settings/SettingsView.swift` has THREE `iconFor`/`colorFor` switch blocks (around lines 2530-2544, 2633-2645, 2779-2792) and one `FieldEditSheet` Toggle around line 2731.

    1. In every `iconFor` switch over `CounterType`, add:
       ```swift
       case .text: return "text.alignleft"
       ```

    2. In every `colorFor` switch over `CounterType`, add:
       ```swift
       case .text: return .purple
       ```

    3. In `FieldEditSheet` (around line 2731), wrap the existing `Toggle` for `showTotal` in:
       ```swift
       if type != .text {
           Toggle(/* existing toggle */) { ... }
       }
       ```
       so the Total toggle is hidden when Text is selected.

    4. Still in `FieldEditSheet`, add an `.onChange(of: type)` (on the type Picker or a parent container) that forces `showTotal = false` whenever `type` becomes `.text`. Use the iOS 17+ two-parameter onChange signature already used elsewhere in this file. Example:
       ```swift
       .onChange(of: type) { _, newValue in
           if newValue == .text { showTotal = false }
       }
       ```

    Scan the entire file for any other `switch` over `CounterType` that is non-exhaustive after adding `.text` (Swift compiler will flag these). Add a sensible `.text` branch to each — typically icon `"text.alignleft"`, colour `.purple`, and skip any totalling logic.

    Do NOT change any existing cases, labels, or wiring.
  </action>
  <verify>
    <automated>grep -n "case .text" Block-Time/Views/Screens/Settings/SettingsView.swift | wc -l | awk '$1 &gt;= 6 {exit 0} {exit 1}' &amp;&amp; grep -n "if type != .text" Block-Time/Views/Screens/Settings/SettingsView.swift &amp;&amp; grep -n "onChange(of: type)" Block-Time/Views/Screens/Settings/SettingsView.swift</automated>
  </verify>
  <done>
    - All three `iconFor` switches handle `.text → "text.alignleft"`.
    - All three `colorFor` switches handle `.text → .purple`.
    - `FieldEditSheet` hides the Total toggle when `type == .text`.
    - Selecting `.text` in the type picker forces `showTotal` to `false`.
    - No non-exhaustive switch warnings remain in SettingsView.
  </done>
</task>

<task type="auto">
  <name>Task 3: Wire .text into CustomCounterDashboardCard (no display, icon + colour)</name>
  <files>Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift</files>
  <action>
    Invoke the `swiftui-pro` skill before editing.

    `Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift`:

    1. In `loadStats()` switch (around line 129), add:
       ```swift
       case .text:
           displayValue = "—"
           return
       ```
       (Place this as the first/early case so we exit before any numeric aggregation.)

    2. In `iconForType` switch, add:
       ```swift
       case .text: return "text.alignleft"
       ```

    3. In `colorForType` switch, add:
       ```swift
       case .text: return .purple
       ```

    Scan the file for any other `switch` over `CounterType` (e.g. formatting helpers) and add a `.text` branch returning a no-op / pass-through value.

    Do NOT alter existing counter/integer/decimal/time aggregation logic.
  </action>
  <verify>
    <automated>grep -n "case .text" Block-Time/Views/Components/Dashboard/CustomCounterDashboardCard.swift | wc -l | awk '$1 &gt;= 3 {exit 0} {exit 1}'</automated>
  </verify>
  <done>
    - `loadStats()` early-returns for `.text` with displayValue "—" (or equivalent no-data state) so no totalling runs.
    - `iconForType` returns `"text.alignleft"` for `.text`.
    - `colorForType` returns `.purple` for `.text`.
    - File compiles with no non-exhaustive switch warnings.
  </done>
</task>

</tasks>

<verification>
- Project compiles cleanly (Nelson will build locally — do NOT run `xcodebuild`).
- Create a new custom field of type "Text" in Settings → Crew & Ops Data → Custom Fields. Confirm:
  - Type picker shows "Text" with subtitle "Notes, codes, or any text value".
  - Total toggle is hidden while Text is selected.
- Open Add Flight → Crew & Ops Data card. The new text field renders as a multi-line remarks-style input with placeholder "Add text...". Typing and saving persists the value across reopen.
- Existing Remarks field still shows "Add remarks..." placeholder and behaves unchanged.
- Existing counter/integer/decimal/time fields still show their Total toggles and dashboard cards.
- Dashboard does not crash or display garbage for a `.text` field; no aggregation card is generated (or it shows "—").
</verification>

<success_criteria>
- Users can add, edit, and reorder a text custom field in Settings without any totalling UI.
- Text fields appear and persist on Add/Edit Flight with placeholder "Add text...".
- All `CounterType` switches across the app are exhaustive — no Swift warnings about missing cases.
- Existing custom field types (counter / integer / decimal / time / time-decimal etc.) behave identically to before this change.
- No Core Data migration needed; counter1–counter10 columns continue to store text values verbatim.
</success_criteria>

<output>
After completion, create `.planning/quick/260522-tsl-add-text-type-to-custom-fields-counterty/260522-tsl-SUMMARY.md` documenting:
- Files changed and line ranges
- The new `.text` case behaviour (no totalling, no dashboard value)
- Any non-exhaustive `CounterType` switches found and fixed outside the listed files
- Confirmation that no model/migration changes were required
</output>
