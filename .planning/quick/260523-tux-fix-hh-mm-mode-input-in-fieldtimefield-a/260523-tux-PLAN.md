---
phase: quick-260523-tux
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
  - Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift
autonomous: false
requirements:
  - TUX-01
must_haves:
  truths:
    - "On iPhone in HH:MM mode, FieldTimeField shows numberPad keyboard (no decimal point)"
    - "On iPhone in HH:MM mode, BulkEditTimeField shows numberPad keyboard (no decimal point)"
    - "Both fields show '00:00' placeholder in HH:MM mode (matching ModernTimeField pattern)"
    - "When focusing a populated time field in HH:MM mode, displayed text shows leading zero on hours (e.g. '01:30' not '1:30')"
    - "Decimal mode behaviour is unchanged (decimalPad keyboard, '0.0' placeholder)"
    - "iPad behaviour is unchanged (.numbersAndPunctuation keyboard)"
  artifacts:
    - path: "Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift"
      provides: "FieldTimeField with corrected HH:MM keyboard, placeholder, and display formatting"
      contains: "showAsHHMM ? .numberPad : .decimalPad"
    - path: "Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift"
      provides: "BulkEditTimeField with corrected HH:MM placeholder and display formatting"
      contains: "showAsHHMM ? \"00:00\" : \"0.0\""
  key_links:
    - from: "FieldTimeField / BulkEditTimeField"
      to: "FlightSector.decimalToHHMM (via FlightLogbook.swift)"
      via: "wrap result with String(format: \"%02d:%02d\", h, m)"
      pattern: "decimalToHHMM"
---

<objective>
Fix HH:MM mode input behaviour in two custom Time field views so they match the OUT/IN ModernTimeField pattern.

Purpose: Custom Time fields currently use `.decimalPad` keyboard (showing a decimal point that does nothing in HH:MM mode) and display unpadded hours (e.g. `1:30` instead of `01:30`). This is inconsistent with how the OUT/IN time fields behave and confuses users in HH:MM mode.

Output: `FieldTimeField` (CrewOpsCard.swift) and `BulkEditTimeField` (BulkEditFields.swift) updated to use `.numberPad` on iPhone in HH:MM mode, `"00:00"` placeholder in HH:MM mode, and `%02d:%02d` formatted display whenever the field shows an HH:MM string.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift
@Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift
@Block-Time/Models/FlightLogbook.swift

<interfaces>
<!-- Key reference: FlightSector.decimalToHHMM (defined in FlightLogbook.swift line 485) -->
<!-- Returns "H:MM" with NO leading zero on hours (uses %d:%02d format). -->
<!-- Example: 1.5 → "1:30", 13.67 → "13:40", 0.0 → "0:00" -->
<!-- Therefore all assignment sites in HH:MM mode MUST re-parse and reformat with %02d:%02d -->

```swift
// FlightLogbook.swift line 485
static func decimalToHHMM(_ decimalHours: Double) -> String {
    guard decimalHours > 0 else { return "0:00" }
    let totalMinutes = Int(round(decimalHours * 60.0))
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    return String(format: "%d:%02d", hours, minutes)   // ← NO leading zero
}
```

<!-- Reference: ModernTimeField (FlightTimeFields.swift line 4) is the OUT/IN field these custom -->
<!-- Time fields must match. Its formatWithLeadingZeros helper is the pattern to mimic: -->

```swift
// FlightTimeFields.swift line 34
private func formatWithLeadingZeros(_ input: String) -> String {
    if input.contains(":") {
        let components = input.split(separator: ":")
        if components.count == 2,
           let hours = Int(components[0]),
           let minutes = Int(components[1]),
           hours < 24, minutes < 60 {
            return String(format: "%02d:%02d", hours, minutes)
        }
    }
    return input
}
```

<!-- BulkEditTextField in BulkEditFields.swift already has an equivalent helper -->
<!-- (formatTimeWithLeadingZeros at line 35). BulkEditTimeField currently does NOT. -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix FieldTimeField HH:MM mode (CrewOpsCard.swift)</name>
  <files>Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift</files>
  <action>
Invoke the `swiftui-pro` skill before editing.

Modify `FieldTimeField` (struct begins at line 181) to match the OUT/IN `ModernTimeField` HH:MM behaviour. Make these three edits ONLY — do not touch other fields, do not refactor, do not remove behaviour:

1. **Keyboard (line 201)** — change:
   ```swift
   .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
   ```
   to:
   ```swift
   .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : (showAsHHMM ? .numberPad : .decimalPad))
   ```

2. **Placeholder (line 199)** — change:
   ```swift
   TextField(showAsHHMM ? "0:00" : "0.0", text: $editingText)
   ```
   to:
   ```swift
   TextField(showAsHHMM ? "00:00" : "0.0", text: $editingText)
   ```

3. **Leading-zero formatting on display** — `FlightSector.decimalToHHMM` returns `"H:MM"` (no leading zero, confirmed via `%d:%02d` format string). Add a private helper inside `FieldTimeField` and apply it to every site that assigns an HH:MM string to `editingText`:

   Add inside the struct (above `var body`):
   ```swift
   private func padHHMM(_ s: String) -> String {
       guard s.contains(":") else { return s }
       let parts = s.split(separator: ":")
       guard parts.count == 2,
             let h = Int(parts[0]),
             let m = Int(parts[1]),
             h >= 0, m >= 0, m < 60 else { return s }
       return String(format: "%02d:%02d", h, m)
   }
   ```

   Wrap the THREE assignment sites in HH:MM branches:
   - Line ~224 (`onChange` focus branch, HH:MM, `value.contains(":")`): change `editingText = value` → `editingText = padHHMM(value)`
   - Line ~226 (`onChange` focus branch, HH:MM, `Double(value)`): change `editingText = FlightSector.decimalToHHMM(d)` → `editingText = padHHMM(FlightSector.decimalToHHMM(d))`
   - Line ~228 (`onChange` focus branch, HH:MM, fallback): change `editingText = value` → `editingText = padHHMM(value)`
   - Line ~264 (`onAppear`, HH:MM, `Double(value)`): change `editingText = FlightSector.decimalToHHMM(d)` → `editingText = padHHMM(FlightSector.decimalToHHMM(d))`
   - Line ~266 (`onAppear`, HH:MM, fallback): change `editingText = value` → `editingText = padHHMM(value)`

   Do NOT modify the decimal-mode branches (the `else` branches that handle non-HH:MM display).
   Do NOT modify the blur (`onChange(of: isFocused)` `else` branch around lines 239–256) — `value` stays decimal-encoded for storage.

Preserve all other behaviour: keyboardToolbar `fieldDidFocus(clear:)` registration, `onAppear` reset logic, decimal-mode filtering, and the existing decimal `String(format: "%.1f", ...)` storage encoding all remain untouched.
  </action>
  <verify>
    <automated>swift -e 'print("manual verification only — UI keyboard + display")' 2>/dev/null || true; grep -n "showAsHHMM ? .numberPad : .decimalPad\|showAsHHMM ? \"00:00\"\|padHHMM" Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift</automated>
  </verify>
  <done>
    - `grep` shows the three new patterns present in CrewOpsCard.swift
    - File compiles cleanly (no build run as part of this plan — user builds locally)
    - All five `editingText` assignment sites in HH:MM branches are wrapped with `padHHMM(...)`
    - Decimal-mode branches are unchanged
  </done>
</task>

<task type="auto">
  <name>Task 2: Fix BulkEditTimeField HH:MM mode (BulkEditFields.swift)</name>
  <files>Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift</files>
  <action>
Invoke the `swiftui-pro` skill before editing.

Modify `BulkEditTimeField` (struct begins at line 374). Keyboard is already correct (`computedKeyboardType` at line 383 already does `showAsHHMM ? .numberPad : .decimalPad` on non-iPad). Make TWO edits ONLY:

1. **Placeholder (line 397)** — change:
   ```swift
   fieldState.isMixed ? "(Mixed)" : (showAsHHMM ? "0:00" : "0.0"),
   ```
   to:
   ```swift
   fieldState.isMixed ? "(Mixed)" : (showAsHHMM ? "00:00" : "0.0"),
   ```

2. **Leading-zero formatting on display** — Add a private helper inside `BulkEditTimeField` (above `var body`):
   ```swift
   private func padHHMM(_ s: String) -> String {
       guard s.contains(":") else { return s }
       let parts = s.split(separator: ":")
       guard parts.count == 2,
             let h = Int(parts[0]),
             let m = Int(parts[1]),
             h >= 0, m >= 0, m < 60 else { return s }
       return String(format: "%02d:%02d", h, m)
   }
   ```

   Wrap the assignment sites in HH:MM branches inside `onChange(of: isFocused)` (lines ~428–435) and `onAppear` (lines ~478–483):
   - `onChange` focus, HH:MM, `v.contains(":")`: `editingText = v` → `editingText = padHHMM(v)`
   - `onChange` focus, HH:MM, `Double(v)`: `editingText = FlightSector.decimalToHHMM(d)` → `editingText = padHHMM(FlightSector.decimalToHHMM(d))`
   - `onChange` focus, HH:MM, fallback else: `editingText = v` → `editingText = padHHMM(v)`
   - `onAppear`, HH:MM, `v.contains(":")`: `editingText = v` → `editingText = padHHMM(v)`
   - `onAppear`, HH:MM, `Double(v)`: `editingText = FlightSector.decimalToHHMM(d)` → `editingText = padHHMM(FlightSector.decimalToHHMM(d))`
   - `onAppear`, HH:MM, fallback else: `editingText = v` → `editingText = padHHMM(v)`

   Do NOT modify decimal-mode branches.
   Do NOT modify the blur branch (lines ~450–469) — `fieldState` stays decimal-encoded for storage.
   Do NOT alter `BulkEditTextField` or any other struct in this file.
  </action>
  <verify>
    <automated>grep -n "showAsHHMM ? \"00:00\"\|padHHMM" Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift</automated>
  </verify>
  <done>
    - `grep` shows new patterns present in BulkEditFields.swift
    - File compiles cleanly (user builds locally)
    - All six `editingText` assignment sites in HH:MM branches are wrapped with `padHHMM(...)`
    - Decimal-mode and blur branches are unchanged
    - `BulkEditTextField` (other struct in same file) is untouched
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: Verify HH:MM input on device/simulator</name>
  <what-built>
    `FieldTimeField` (Crew & Ops custom Time fields) and `BulkEditTimeField` (BulkEditSheet custom Time fields) now mirror the OUT/IN field behaviour in HH:MM mode: numberPad keyboard on iPhone, "00:00" placeholder, and leading-zero formatted display.
  </what-built>
  <how-to-verify>
    Settings → enable "Show times in hours & minutes" (sets `showTimesInHoursMinutes = true`).

    On iPhone:
    1. AddFlightView → Crew & Ops Data card → tap any custom Time field. Confirm:
       - Keyboard is numberPad (no decimal point key visible)
       - Empty field placeholder reads `00:00`
       - Populate a flight with decimal value 1.5 in storage, edit again → field displays `01:30` (not `1:30`)
    2. BulkEditSheet → select 2+ flights → custom Time field. Confirm same three points.

    On iPad:
    3. Both fields show `.numbersAndPunctuation` keyboard (unchanged from before)

    Toggle "Show times in hours & minutes" OFF and confirm decimal mode still:
    - Uses decimalPad on iPhone
    - Shows `0.0` placeholder
    - Displays e.g. `1.5` correctly

    Verify OUT/IN time fields are still unchanged (regression check).
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues</resume-signal>
</task>

</tasks>

<verification>
- Both files modified per spec, no unrelated edits
- HH:MM keyboard: `.numberPad` on iPhone (both fields)
- HH:MM placeholder: `"00:00"` (both fields)
- HH:MM display: leading-zero formatted via `padHHMM` helper (both fields)
- Decimal mode unchanged
- iPad behaviour unchanged
- OUT/IN fields (`ModernTimeField`) untouched
- No removal of features, toolbar registration, or blur storage encoding
</verification>

<success_criteria>
- iPhone HH:MM input matches OUT/IN field behaviour in all three respects (keyboard, placeholder, display)
- No regressions in decimal mode, iPad, or OUT/IN fields
- User verifies on-device via checkpoint
</success_criteria>

<output>
After completion, create `.planning/quick/260523-tux-fix-hh-mm-mode-input-in-fieldtimefield-a/260523-tux-SUMMARY.md`
</output>
