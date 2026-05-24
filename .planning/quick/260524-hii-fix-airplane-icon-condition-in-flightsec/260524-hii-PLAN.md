---
phase: quick
plan: 260524-hii
type: execute
wave: 1
depends_on: []
files_modified: [Block-Time/Views/Components/FlightSectorRow.swift]
autonomous: true
requirements: [QUICK-260524-hii]

must_haves:
  truths:
    - "INS|Simulator flights (spInsTimeValue > 0, simTimeValue == 0) with no airports hide the airplane icon"
    - "Flights with both airports set still show the airplane icon"
    - "Real flights (simTimeValue == 0, spInsTimeValue == 0) with airports still show the icon"
  artifacts:
    - path: "Block-Time/Views/Components/FlightSectorRow.swift"
      provides: "Corrected airplane icon visibility condition"
      contains: "spInsTimeValue == 0"
  key_links:
    - from: "FlightSectorRow icon condition"
      to: "sector.spInsTimeValue"
      via: "guard clause on line 261"
      pattern: "spInsTimeValue == 0"
---

<objective>
Fix the airplane icon visibility condition in FlightSectorRow so INS|Simulator flights (spInsTimeValue > 0, simTimeValue == 0) without airports hide the icon.

Purpose: Currently `simTimeValue == 0` evaluates true for INS|Sim flights, incorrectly showing the airplane icon even when no airports are set.
Output: One-line change to the condition at line 261.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
Target file: Block-Time/Views/Components/FlightSectorRow.swift

Current condition (line 261):
```swift
if sector.simTimeValue == 0 || (!sector.fromAirport.isEmpty && !sector.toAirport.isEmpty) {
```

`spInsTimeValue` confirmed available: `nonisolated var spInsTimeValue: Double` in Block-Time/Models/FlightLogbook.swift:252.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add spInsTimeValue guard to airplane icon condition</name>
  <files>Block-Time/Views/Components/FlightSectorRow.swift</files>
  <action>
    At line 261, change the condition from:
    ```swift
    if sector.simTimeValue == 0 || (!sector.fromAirport.isEmpty && !sector.toAirport.isEmpty) {
    ```
    to:
    ```swift
    if (sector.simTimeValue == 0 && sector.spInsTimeValue == 0) || (!sector.fromAirport.isEmpty && !sector.toAirport.isEmpty) {
    ```
    This treats spInsTimeValue > 0 (INS|Sim) flights as sim-type, requiring both airports before the airplane icon shows. Do not change any other lines.
  </action>
  <verify>
    <automated>grep -q "sector.simTimeValue == 0 && sector.spInsTimeValue == 0" Block-Time/Views/Components/FlightSectorRow.swift</automated>
  </verify>
  <done>Line 261 condition includes `sector.spInsTimeValue == 0`; no other lines changed.</done>
</task>

</tasks>

<verification>
- grep confirms the updated condition string is present at line 261.
- Nelson builds locally to confirm INS|Sim flights without airports no longer show the airplane icon.
</verification>

<success_criteria>
- INS|Simulator flights (spInsTimeValue > 0) with no airports hide the airplane icon.
- Flights with both airports still show the icon.
- Real flights with airports unaffected.
</success_criteria>

<output>
After completion, create `.planning/quick/260524-hii-fix-airplane-icon-condition-in-flightsec/260524-hii-SUMMARY.md`
</output>
