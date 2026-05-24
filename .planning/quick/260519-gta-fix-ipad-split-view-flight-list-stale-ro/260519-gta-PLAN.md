---
phase: quick-260519-gta
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Views/Screens/FlightsSplitView.swift
autonomous: true
requirements: [GTA-01]

must_haves:
  truths:
    - "After saving via the 'Save Changes?' alert, the flight row in the left-hand list immediately shows the updated data without leaving the view"
  artifacts:
    - path: "Block-Time/Views/Screens/FlightsSplitView.swift"
      provides: "UUID-based refresh trigger wired from save alert to FlightsListContent"
      contains: "listRefreshTrigger"
  key_links:
    - from: "FlightsSplitView (Save alert button)"
      to: "FlightsListContent.loadFlights()"
      via: "listRefreshTrigger UUID state change → onChange handler"
      pattern: "listRefreshTrigger = UUID()"
---

<objective>
Fix the stale flight row bug on iPad split view: after tapping "Save" in the "Save Changes?" alert, the left-hand flight list does not refresh until the user navigates away and back.

Purpose: The `onReceive(.flightDataChanged)` handler in `FlightsListContent` is torn down and re-created when `selectedFlight` changes during the alert flow, so the notification is missed. Replacing this with a direct `@Binding var refreshTrigger: UUID` + `onChange` bypasses the flaky notification path entirely.

Output: `FlightsSplitView.swift` modified — no new files.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add UUID refresh trigger and wire save alert to force list reload</name>
  <files>Block-Time/Views/Screens/FlightsSplitView.swift</files>
  <action>
    Invoke the `swiftui-pro` skill before making any edits.

    Make exactly five targeted edits to `FlightsSplitView.swift` — do not change anything else:

    1. Add `@Binding var refreshTrigger: UUID` as a new stored property on `FlightsListContent` (after the existing `let onFlightSelected` property, before the `private let databaseService` line).

    2. Add `.onChange(of: refreshTrigger)` to `FlightsListContent.body` — place it immediately after the existing `.onReceive(NotificationCenter.default.publisher(for: .flightDataChanged))` modifier (around line 652). Use the two-argument closure form required by Swift 6:
       ```swift
       .onChange(of: refreshTrigger) { _, _ in
           Task { await loadFlights() }
       }
       ```

    3. Add `@State private var listRefreshTrigger: UUID = UUID()` to `FlightsSplitView` — place it after the existing `@State private var showingSaveFailedAlert: Bool = false` declaration (around line 22).

    4. Pass `refreshTrigger: $listRefreshTrigger` when constructing `FlightsListContent` in `FlightsSplitView.body` (around line 37). The call site already passes `filterViewModel:`, `selectedFlight:`, `isAddingNewFlight:`, `isSelectMode:`, `onFlightSelected:` — add `refreshTrigger: $listRefreshTrigger` after `isSelectMode:` and before `onFlightSelected:`.

    5. In the "Save" alert button handler (around line 94-108), after the successful `viewModel.updateExistingFlight()` branch (both the `pending` and non-pending paths, inside `if viewModel.updateExistingFlight() { ... }`), add:
       ```swift
       listRefreshTrigger = UUID()
       ```
       Add it as the LAST statement inside the `if viewModel.updateExistingFlight()` block, after all `selectedFlight`/`viewModel` mutations. Do NOT add it in the `else` (save failed) branch.

    Do not remove or change any existing logic, including the existing `onReceive(.flightDataChanged)` handler — leave it in place.
  </action>
  <verify>
    Build succeeds in Xcode (no compiler errors).
    Manual test on iPad: edit a flight, tap a different flight row, tap "Save" in the alert — the previously edited row in the left-hand list must immediately reflect the saved changes without navigating away.
  </verify>
  <done>
    `FlightsSplitView.swift` compiles. After "Save" in the alert, the edited row updates immediately in the left list. The `onReceive(.flightDataChanged)` handler is still present and untouched.
  </done>
</task>

</tasks>

<verification>
Build must succeed with zero new warnings or errors. The stale-row scenario described above must be resolved. No existing behaviour (Discard, Cancel, delete, select mode, filters) is affected.
</verification>

<success_criteria>
- `listRefreshTrigger` state exists on `FlightsSplitView`
- `refreshTrigger: $listRefreshTrigger` is passed to `FlightsListContent`
- `FlightsListContent` has `@Binding var refreshTrigger: UUID` and a matching `.onChange` that calls `loadFlights()`
- `listRefreshTrigger = UUID()` is set inside the successful save path of the alert
- Build is clean
</success_criteria>

<output>
After completion, create `.planning/quick/260519-gta-fix-ipad-split-view-flight-list-stale-ro/260519-gta-SUMMARY.md` using the summary template.
</output>
