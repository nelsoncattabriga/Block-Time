---
phase: quick-260523-req
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/ViewModels/BulkEditViewModel.swift
autonomous: false
requirements: [QUICK-260523-req]
must_haves:
  truths:
    - "When user enters a value into a custom field added after BulkEditSheet opened, the Save button enables"
    - "Existing custom fields (present at sheet init) continue to enable Save when their state changes"
    - "Empty state for new custom fields does not enable Save"
  artifacts:
    - path: "Block-Time/ViewModels/BulkEditViewModel.swift"
      provides: "checkForModifications() with handling for custom fields missing from initialStates"
      contains: "customCounter_"
  key_links:
    - from: "BulkEditViewModel.checkForModifications()"
      to: "customCounterStates iteration"
      via: "fallback logic when initialStates[key] is nil"
      pattern: "initialStates\\[key\\] != nil"
---

<objective>
Fix Save button not enabling in BulkEditSheet when user edits a custom field whose definition was added after the sheet was initialized.

Purpose: `checkForModifications()` currently calls `hasFieldBeenModified` for each custom counter, which returns `false` when the key is missing from `initialStates`. Custom field definitions added after sheet init have no initial state, so any value entered is silently treated as "unchanged" and Save stays disabled.

Output: Updated `checkForModifications()` logic that treats absence of an initial state as baseline `.notEdited`, so any non-empty `.value` for a new custom field correctly enables Save.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@Block-Time/ViewModels/BulkEditViewModel.swift

<interfaces>
From Block-Time/ViewModels/BulkEditViewModel.swift:

```swift
// FieldState enum used by all bulk-edit fields
enum FieldState<T: Equatable>: Equatable {
    case notEdited
    case value(T)
}

// Custom counter state map (columnIndex -> FieldState<String>)
var customCounterStates: [Int: FieldState<String>]

// Stored initial state snapshot used for diffing
private var initialStates: [String: Any]

// The function being modified
var hasModifications: Bool { /* checkForModifications body */ }

private func hasFieldBeenModified<T: Equatable>(_ field: FieldState<T>, key: String) -> Bool {
    guard let initialState = initialStates[key] as? FieldState<T> else {
        return false
    }
    return field != initialState
}
```

Current custom counter block (lines 505-507):
```swift
customCounterStates.contains(where: { (col, state) in
    hasFieldBeenModified(state, key: "customCounter_\(col)")
})
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Patch checkForModifications to handle missing initialStates key for custom counters</name>
  <files>Block-Time/ViewModels/BulkEditViewModel.swift</files>
  <behavior>
    - Custom field present at init + user edits → Save enables (existing behavior preserved)
    - Custom field added after init + user enters non-empty value → Save enables (the bug fix)
    - Custom field added after init + state remains `.notEdited` → Save does NOT enable
    - Custom field added after init + `.value("")` (empty string) → Save does NOT enable
  </behavior>
  <action>
    In `Block-Time/ViewModels/BulkEditViewModel.swift`, locate the custom counter check inside `checkForModifications()` (currently at lines 505-507):

    ```swift
    customCounterStates.contains(where: { (col, state) in
        hasFieldBeenModified(state, key: "customCounter_\(col)")
    })
    ```

    Replace with:

    ```swift
    customCounterStates.contains(where: { (col, state) in
        let key = "customCounter_\(col)"
        if initialStates[key] != nil {
            return hasFieldBeenModified(state, key: key)
        }
        // New definition added after sheet init — any non-empty value is a modification
        if case .value(let v) = state { return !v.isEmpty }
        return false
    })
    ```

    Do NOT modify `hasFieldBeenModified` itself (other callers depend on its current "missing key = false" semantics). Do NOT modify how `initialStates` is populated at init. Do NOT touch `applyChanges` or any other method. The change is scoped strictly to the closure body in `checkForModifications()`.

    Use the `swiftui-pro` Skill before editing per project CLAUDE.md.
  </action>
  <verify>
    <automated>swift -e "print(\"manual verify required\")" ; grep -n "initialStates\\[key\\] != nil" Block-Time/ViewModels/BulkEditViewModel.swift</automated>
  </verify>
  <done>
    - `checkForModifications()` contains the new branch checking `initialStates[key] != nil` before falling back to `.value(non-empty)` check.
    - `hasFieldBeenModified` body unchanged.
    - File compiles (Nelson builds locally).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Verify Save button enables for newly added custom field</name>
  <what-built>
    Patched `BulkEditViewModel.checkForModifications()` so the Save button enables when a user enters a value into a custom field whose definition did not exist when BulkEditSheet first opened.
  </what-built>
  <how-to-verify>
    1. Build and run the app locally.
    2. Open BulkEditSheet for one or more flights.
    3. While the sheet is open (or with the sheet's ViewModel already initialized from the current session), add a NEW custom field definition in Settings → Custom Fields. (Alternative repro: re-open the sheet on flights whose definitions array contains a field added after the ViewModel snapshot.)
    4. Return to BulkEditSheet and enter a value into the newly added custom field row.
    5. Confirm the Save button enables (illuminates) as soon as a non-empty value is entered.
    6. Clear the value → Save should disable again.
    7. Regression check: edit an EXISTING custom field (one present at sheet init) → Save still enables as before.
    8. Regression check: edit other fields (e.g. INS toggle, remarks) → Save still enables as before.
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues</resume-signal>
</task>

</tasks>

<verification>
- Save button enables when value entered into custom field added after BulkEditSheet init.
- Save button still enables for pre-existing custom fields and all other tracked fields.
- Empty values do not enable Save.
- No other behavior in BulkEditViewModel changed.
</verification>

<success_criteria>
- Single targeted edit to `checkForModifications()` in `BulkEditViewModel.swift`.
- Manual verification of new-field-Save-enables flow passes.
- No regressions in existing bulk-edit field-change detection.
</success_criteria>

<output>
After completion, create `.planning/quick/260523-req-fix-save-button-not-enabling-for-new-cus/260523-req-SUMMARY.md`
</output>
