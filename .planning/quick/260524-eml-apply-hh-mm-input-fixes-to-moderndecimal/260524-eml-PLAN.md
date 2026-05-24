---
phase: quick
plan: 260524-eml
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift
autonomous: true
requirements: [EML-01]
must_haves:
  truths:
    - "ModernDecimalTimeField in HH:MM mode uses numberPad (iPhone) or numbersAndPunctuation (iPad)"
    - "ModernDecimalTimeField placeholder in HH:MM mode shows 00:00 not 0:00"
    - "Typing 4 digits without colon in HH:MM mode auto-inserts colon (e.g. 0130 → 01:30)"
    - "Blurring after typing 4 digits without colon in HH:MM mode normalises correctly"
  artifacts:
    - path: "Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift"
      provides: "Updated ModernDecimalTimeField with HH:MM input fixes"
  key_links:
    - from: "ModernDecimalTimeField.sanitize()"
      to: "TextField onChange"
      via: "auto-colon insertion on 4-digit input"
    - from: "ModernDecimalTimeField.formatOnBlur()"
      to: "value write-back on focus loss"
      via: "bare 4-digit normalisation"
---

<objective>
Apply four surgical HH:MM input fixes to `ModernDecimalTimeField` to match the behaviour of `FieldTimeField` (the gold standard).

Purpose: Block/INS/SIM time fields currently misbehave in HH:MM mode — wrong keyboard type, wrong placeholder, no auto-colon, no blur normalisation for bare 4-digit entry.
Output: `FlightTimeFields.swift` with four targeted changes, all gated on `showAsHHMM`. No other structs touched.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

Reference implementation (gold standard):
- `FieldTimeField` in `Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift` — already correct for all four behaviours
- `ModernDecimalTimeField` in `Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift` — target struct (lines 148–324)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Apply four HH:MM input fixes to ModernDecimalTimeField</name>
  <files>Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift</files>
  <action>
Read the file first. Make exactly these four changes inside `ModernDecimalTimeField` only — do NOT touch `ModernTimeField`, `FieldTimeField`, `BulkEditTimeField`, or any other struct.

**Change 1 — Keyboard type (line ~270):**
Replace:
```swift
.keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
```
With:
```swift
.keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : (showAsHHMM ? .numberPad : .decimalPad))
```

**Change 2 — Placeholder (line ~268):**
Replace:
```swift
TextField(showAsHHMM ? "0:00" : "0.0", text: $editingText)
```
With:
```swift
TextField(showAsHHMM ? "00:00" : "0.0", text: $editingText)
```

**Change 3 — sanitize() HH:MM branch (lines ~163–171):**
Replace the HH:MM branch body:
```swift
// Allow digits and colon for HH:MM format
return input.filter { $0.isNumber || $0 == ":" }
```
With:
```swift
// Allow digits and colon; auto-insert colon on exactly 4 digits without one
let digitsAndColon = input.filter { $0.isNumber || $0 == ":" }
if digitsAndColon.count == 4 && !digitsAndColon.contains(":") {
    return "\(digitsAndColon.prefix(2)):\(digitsAndColon.suffix(2))"
}
return String(digitsAndColon.prefix(5))
```

**Change 4 — formatOnBlur() HH:MM branch (lines ~191–206):**
The current HH:MM branch starts with `if input.contains(":")`. Before that `if`, add normalisation for bare 4-digit entry. Replace the entire `if showAsHHMM {` block with:
```swift
if showAsHHMM {
    // Normalise bare 4-digit entry (e.g. "0130" → "01:30")
    let blurInput: String
    if input.count == 4 && !input.contains(":") && input.allSatisfy(\.isNumber) {
        blurInput = "\(input.prefix(2)):\(input.suffix(2))"
    } else {
        blurInput = input
    }
    // Convert to HH:MM format
    if blurInput.contains(":") {
        // Already in HH:MM, validate and reformat
        let components = blurInput.split(separator: ":")
        if components.count == 2,
           let hours = Int(components[0]),
           let minutes = Int(components[1]),
           hours >= 0, minutes >= 0, minutes < 60 {
            return String(format: "%d:%02d", hours, minutes)
        }
    } else if let decimalValue = Double(blurInput) {
        // Convert decimal to HH:MM
        return FlightSector.decimalToHHMM(decimalValue)
    }
    return blurInput.isEmpty ? "0:00" : blurInput
```
Close the `}` for this block, then leave the `else {` decimal branch unchanged.
  </action>
  <verify>
    <automated>grep -n 'showAsHHMM ? .numberPad' /Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift && grep -n '"00:00"' /Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift && grep -n 'digitsAndColon.prefix(2)' /Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift && grep -n 'blurInput' /Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift</automated>
  </verify>
  <done>
    - `.keyboardType` on ModernDecimalTimeField uses `.numberPad` in HH:MM mode on iPhone
    - Placeholder shows `00:00` in HH:MM mode
    - `sanitize()` auto-inserts colon for 4-digit input
    - `formatOnBlur()` normalises bare 4-digit input before parsing
    - No other struct in the file is modified
  </done>
</task>

</tasks>

<verification>
grep confirms all four patterns present in FlightTimeFields.swift. FieldTimeField and other structs are unchanged (line count of other structs matches pre-edit state).
</verification>

<success_criteria>
ModernDecimalTimeField HH:MM mode behaves identically to FieldTimeField: correct keyboard type, 00:00 placeholder, auto-colon on 4-digit input, and blur normalisation for bare 4-digit entry.
</success_criteria>

<output>
After completion, create `.planning/quick/260524-eml-apply-hh-mm-input-fixes-to-moderndecimal/260524-eml-SUMMARY.md`
</output>
