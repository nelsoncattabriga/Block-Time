---
phase: quick-260523-qsz
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/ViewModels/BulkEditViewModel.swift
autonomous: true
requirements:
  - QSZ-01
must_haves:
  truths:
    - "Tapping the INS toggle in BulkEditSheet illuminates the Save button immediately"
    - "Existing CombineLatest3($flightDate, $isSpIns, $spInsTime) tracker continues to work for other changes"
    - "No other modification-tracking behaviour regresses"
  artifacts:
    - path: "Block-Time/ViewModels/BulkEditViewModel.swift"
      provides: "Dedicated $isSpIns sink that triggers checkForModifications() independently"
      contains: "$isSpIns"
  key_links:
    - from: "BulkEditViewModel.setupModificationTracking()"
      to: "checkForModifications()"
      via: "dedicated $isSpIns.sink (additive to the existing CombineLatest3)"
      pattern: "\\$isSpIns[\\s\\S]*?\\.sink"
---

<objective>
Fix Save button not illuminating in BulkEditSheet when the INS toggle is tapped.

Purpose: The INS button mutates `isPositioning`, `isSimulator`, and `isSpIns` sequentially in one closure. The existing `CombineLatest4($scheduledArrival, $isPilotFlying, $isPositioning, $isSimulator)` fires `checkForModifications()` before `isSpIns` is updated, producing a stale read and leaving the Save button disabled.

Output: A dedicated `$isSpIns` sink in `setupModificationTracking()` so any change to `isSpIns` independently triggers `checkForModifications()` — same pattern already used for `$blockTimeRole` and `$remarks`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@Block-Time/ViewModels/BulkEditViewModel.swift

<interfaces>
<!-- Existing pattern in BulkEditViewModel.setupModificationTracking() (lines 395-400, 434-438) -->

```swift
$blockTimeRole
    .receive(on: RunLoop.main)
    .sink { [weak self] _ in
        self?.checkForModifications()
    }
    .store(in: &cancellables)

$remarks
    .sink { [weak self] _ in
        self?.checkForModifications()
    }
    .store(in: &cancellables)
```

<!-- Existing CombineLatest3 that has the ordering bug (lines 440-446) — must remain in place: -->

```swift
Publishers.CombineLatest3(
    $flightDate, $isSpIns, $spInsTime
)
.sink { [weak self] _ in
    self?.checkForModifications()
}
.store(in: &cancellables)
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add dedicated $isSpIns sink in setupModificationTracking()</name>
  <files>Block-Time/ViewModels/BulkEditViewModel.swift</files>
  <action>
In `BulkEditViewModel.setupModificationTracking()`, add a dedicated `$isSpIns` Combine sink that calls `checkForModifications()` independently. Place it adjacent to the existing `CombineLatest3($flightDate, $isSpIns, $spInsTime)` block (around line 440) so the intent is obvious to future readers.

Use the exact same shape as the `$remarks` sink (lines 434-438):

```swift
$isSpIns
    .sink { [weak self] _ in
        self?.checkForModifications()
    }
    .store(in: &cancellables)
```

Do NOT remove or alter the existing `CombineLatest3($flightDate, $isSpIns, $spInsTime)` — it stays as-is. The dedicated sink is additive.

Why: when the INS button's action closure mutates `isPositioning`, `isSimulator`, then `isSpIns` in sequence, the `CombineLatest4($scheduledArrival, $isPilotFlying, $isPositioning, $isSimulator)` fires `checkForModifications()` before `isSpIns` updates, producing a stale read. A dedicated `$isSpIns` sink guarantees a fresh `checkForModifications()` call regardless of mutation ordering.

Do not change any other behaviour, property, or sink. No refactors.
  </action>
  <verify>
    <automated>grep -n -A4 '\$isSpIns' Block-Time/ViewModels/BulkEditViewModel.swift | grep -q 'checkForModifications'</automated>
    Manual confirmation (per CLAUDE.md, Nelson builds locally): open BulkEditSheet for any flight, tap the INS toggle, confirm the Save button illuminates immediately.
  </verify>
  <done>
A dedicated `$isSpIns.sink { [weak self] _ in self?.checkForModifications() }.store(in: &cancellables)` exists in `setupModificationTracking()`. The existing `CombineLatest3($flightDate, $isSpIns, $spInsTime)` is unchanged. No other lines modified.
  </done>
</task>

</tasks>

<verification>
- `grep` confirms a dedicated `$isSpIns` sink exists and calls `checkForModifications`.
- Existing `CombineLatest3($flightDate, $isSpIns, $spInsTime)` block still present at original location.
- No other sinks, properties, or methods touched.
</verification>

<success_criteria>
- Tapping the INS toggle in BulkEditSheet enables the Save button on the first tap.
- All other BulkEdit modification-tracking behaviour unchanged (flightDate, spInsTime, isPositioning, isSimulator, etc. all still drive `checkForModifications`).
- No build regressions.
</success_criteria>

<output>
After completion, create `.planning/quick/260523-qsz-fix-save-button-not-illuminating-when-in/260523-qsz-SUMMARY.md`
</output>
