---
phase: quick-260523-qbo
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/ViewModels/BulkEditViewModel.swift
  - Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift
  - Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift
autonomous: false
requirements: [QBO-01, QBO-02, QBO-03]
must_haves:
  truths:
    - "User can set a single flight date that applies to all selected flights via a date picker (matching iOS 26 pattern)"
    - "User can toggle INS (Sp/Ins) on/off for selected flights and bulk-set spInsTime"
    - "User sees a Custom Fields card driven by CustomCounterService.shared.definitions; card is hidden when definitions are empty"
    - "Each custom field uses the correct keyboard (time → numberPad+isTimeField, decimal → decimalPad, integer → numberPad, text → default)"
    - "Save button enables when any new field is modified (flightDate, isSpIns, spInsTime, or any customCounterStates entry)"
    - "applyChanges writes flight.date (from flightDate), spInsTime (mirroring isSimulator pattern via isSpIns), and flight.counterEntries[columnIndex] (from customCounterStates)"
  artifacts:
    - path: "Block-Time/ViewModels/BulkEditViewModel.swift"
      provides: "flightDate, isSpIns, spInsTime, customCounterStates state + analysis + modification tracking + applyChanges logic"
    - path: "Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift"
      provides: "Flight Date card (first), INS row in Operations card, Custom Fields card (hidden when empty)"
    - path: "Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift"
      provides: "BulkEditDateField component (iOS 26 pattern with FieldState<String>) and updated BulkEditFlightTypeToggle to include INS"
  key_links:
    - from: "BulkEditSheet.Flight Date card"
      to: "BulkEditViewModel.flightDate"
      via: "BulkEditDateField binding"
      pattern: "BulkEditDateField.*flightDate"
    - from: "BulkEditSheet.Operations card"
      to: "BulkEditViewModel.isSpIns/spInsTime"
      via: "BulkEditFlightTypeToggle + BulkEditTextField"
      pattern: "isSpIns|spInsTime"
    - from: "BulkEditSheet.Custom Fields card"
      to: "CustomCounterService.shared.definitions"
      via: "ForEach iteration binding into customCounterStates"
      pattern: "CustomCounterService.shared.definitions"
    - from: "BulkEditViewModel.applyChanges"
      to: "FlightSector.counterEntries[columnIndex]"
      via: "customCounterStates write-back loop"
      pattern: "counterEntries\\["
---

<objective>
Add three missing field groups to BulkEditSheet so it matches AddFlightView feature coverage:
1. Flight Date — bulk-set the same date on all selected flights
2. Sp/Ins (INS) — toggle + spInsTime field, mirroring isSimulator/simTime
3. Custom Fields — dynamic card driven by CustomCounterService.shared.definitions

Purpose: BulkEditSheet currently lets the user edit aircraft, crew, times, schedule, ops, T/O, landings, and remarks — but cannot set flight date, cannot mark flights as INS, and cannot edit any user-defined custom fields. This closes those gaps so bulk-edit has parity with single-flight editing for the fields users actually need to fix in bulk (date corrections, INS retro-flagging, and custom field backfill after adding a new column).

Output: Updated BulkEditViewModel + BulkEditSheet + BulkEditFields; checkpoint for visual verification.
</objective>

<context>
@CLAUDE.md
@.planning/quick/260523-qbo-add-missing-fields-to-bulkeditsheet-flig/260523-qbo-CONTEXT.md

# Existing code being extended
@Block-Time/ViewModels/BulkEditViewModel.swift
@Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift
@Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift

# Reference patterns
@Block-Time/Models/FlightLogbook.swift
@Block-Time/Models/CustomCounterDefinition.swift
@Block-Time/Services/CustomCounterService.swift
@Block-Time/Views/Components/AddFlightView/FlightFormFields.swift
@Block-Time/Views/Components/AddFlightView/FlightInfoCard.swift

<interfaces>
<!-- Known facts already established — do NOT re-derive -->

FlightSector relevant fields (Block-Time/Models/FlightLogbook.swift):
```swift
var date: String                          // "DD/MM/YYYY" via en_AU formatter
var spInsTime: String                     // numeric string, validated via validateTimeString
var counterEntries: [Int: String] = [:]   // keyed by columnIndex (1-10)
```

CustomCounterDefinition:
```swift
enum CounterType: String { case time, decimal, integer, text }
struct CustomCounterDefinition {
    let columnIndex: Int     // 1-10
    var label: String
    var type: CounterType
    var showTotal: Bool
}
```

CustomCounterService:
```swift
@Observable @MainActor final class CustomCounterService {
    static let shared = CustomCounterService()
    private(set) var definitions: [CustomCounterDefinition]
}
```

BulkEditViewModel.FieldState<T> (already defined):
```swift
enum FieldState<T: Equatable>: Equatable {
    case notEdited
    case mixed
    case value(T)
}
```

BulkEditFlightTypeToggle (existing — currently 2 toggles: positioning + simulator)
- Located in BulkEditFields.swift (not shown in read above but referenced from BulkEditSheet.swift lines 228-231)
- Will be extended to include 3rd toggle: isSpIns

iOS 26 date picker pattern (from FlightInfoCard / ModernDatePickerField):
- Button shows formatted "d MMM yyyy" label
- Tap → .sheet with DatePicker(..., displayedComponents: .date).datePickerStyle(.graphical)
- .presentationDetents([.height(420)])
- Auto-dismiss via .onChange of selectedDate
- Use static DateFormatter "dd/MM/yyyy" en_AU UTC for storage parse/format
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extend BulkEditViewModel with flightDate, isSpIns, spInsTime, customCounterStates</name>
  <files>Block-Time/ViewModels/BulkEditViewModel.swift</files>
  <action>
Add four new published state groups to BulkEditViewModel, mirroring existing patterns. Do NOT change or remove any existing field, behaviour, or modification tracking.

1. Add `import SwiftUI` if not already present (needed to call CustomCounterService.shared from MainActor context — service is @MainActor).

2. Add new @Published properties near matching siblings:
   - `@Published var flightDate: FieldState<String> = .notEdited` (near aircraftReg block)
   - `@Published var isSpIns: FieldState<Bool> = .notEdited` (next to `isSimulator`)
   - `@Published var spInsTime: FieldState<String> = .notEdited` (next to `simTime`)
   - `@Published var customCounterStates: [Int: FieldState<String>] = [:]` (new section at end, before `hasModifications`)

3. Extend `analyzeFields()` (per CONTEXT D-Flight Date / D-Sp/Ins / D-Custom Fields):
   - `flightDate = Self.analyzeStringField(selectedFlights) { $0.date }`
   - `spInsTime = Self.analyzeStringField(selectedFlights) { $0.spInsTime }`
   - `isSpIns = Self.analyzeBoolField(selectedFlights) { flight in (Double(flight.spInsTime) ?? 0.0) > 0.0 }` (mirrors isSimulator analysis on line 158-161)
   - Wrap CustomCounterService access in a MainActor.assumeIsolated block (BulkEditViewModel is not @MainActor — keep it that way to match existing code). Acceptable alternative: snapshot definitions in init by jumping briefly to MainActor — but simplest is `let defs = MainActor.assumeIsolated { CustomCounterService.shared.definitions }` since BulkEditSheet which constructs the VM is in a SwiftUI view on the main thread. For each definition: `customCounterStates[def.columnIndex] = Self.analyzeStringField(selectedFlights) { $0.counterEntries[def.columnIndex] ?? "" }`

4. Extend `storeInitialStates()`:
   - Add entries for "flightDate", "isSpIns", "spInsTime"
   - For each custom counter slot, store under key `"customCounter_\(columnIndex)"` so each is independently tracked

5. Extend `setupModificationTracking()`:
   - Add `$flightDate`, `$isSpIns`, `$spInsTime` to a new Publishers.CombineLatest3 sink calling checkForModifications
   - Add `$customCounterStates.sink { [weak self] _ in self?.checkForModifications() }` for the dictionary as a whole (a single change to any key publishes)

6. Extend `checkForModifications()`:
   - Add `|| hasFieldBeenModified(flightDate, key: "flightDate")`
   - Add `|| hasFieldBeenModified(isSpIns, key: "isSpIns")`
   - Add `|| hasFieldBeenModified(spInsTime, key: "spInsTime")`
   - Add `|| customCounterStates.contains(where: { (col, state) in hasFieldBeenModified(state, key: "customCounter_\(col)") })`

7. Extend `applyChanges(to:)`:
   - At top of loop (per D-Flight Date): `if case .value(let d) = flightDate { updated.date = d }`
   - Add Sp/Ins handling MIRRORING the existing isSimulator block (lines 539-555). Place it directly after the isSimulator block so simulator handling stays untouched:
     ```
     if case .value(let isSp) = isSpIns {
         if isSp {
             // Converting to Sp/Ins: move blockTime to spInsTime, set blockTime to 0
             let currentBlock = updated.blockTime
             if let v = Double(currentBlock), v > 0 {
                 updated.spInsTime = currentBlock
                 updated.blockTime = "0.0"
             }
         } else {
             let currentSp = updated.spInsTime
             if let v = Double(currentSp), v > 0 {
                 updated.blockTime = currentSp
                 updated.spInsTime = "0.0"
             }
         }
     }
     ```
   - After the existing simTime apply block (line 611-613), add:
     ```
     if case .value(let sp) = spInsTime {
         updated.spInsTime = sp
     }
     ```
   - At the end of the loop (before `updatedFlights[flight.id] = updated`), iterate customCounterStates and write back:
     ```
     for (columnIndex, state) in customCounterStates {
         if case .value(let v) = state {
             if v.isEmpty {
                 updated.counterEntries.removeValue(forKey: columnIndex)
             } else {
                 updated.counterEntries[columnIndex] = v
             }
         }
     }
     ```

Do NOT remove or alter any existing field, tracking entry, or apply-branch.
  </action>
  <verify>
    <automated>grep -n "flightDate\|isSpIns\|spInsTime\|customCounterStates" Block-Time/ViewModels/BulkEditViewModel.swift | wc -l</automated>
    Expect: count >= 20 (multiple references across declarations, analyze, store, tracking, check, apply).
  </verify>
  <done>
- BulkEditViewModel has 4 new published state groups
- analyzeFields populates all 4 from selectedFlights and CustomCounterService.shared.definitions
- storeInitialStates includes all 4 (custom counters keyed per columnIndex)
- setupModificationTracking subscribes to all 4
- checkForModifications considers all 4
- applyChanges writes flight.date, mirrors isSimulator pattern for isSpIns, writes spInsTime override, and writes counterEntries[columnIndex]
- No existing field removed or altered
  </done>
</task>

<task type="auto">
  <name>Task 2: Add BulkEditDateField component and extend BulkEditFlightTypeToggle</name>
  <files>Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift</files>
  <action>
1. Add a new `BulkEditDateField` component at end of BulkEditFields.swift implementing the iOS 26 pattern (per CONTEXT D-Flight Date — see ModernDatePickerField for reference, but bound to FieldState<String> instead of Binding<String>):

```swift
// MARK: - BulkEditDateField

struct BulkEditDateField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>

    @State private var selectedDate: Date = Date()
    @State private var showingPicker: Bool = false
    @State private var hasInitialised: Bool = false

    private static let storageFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    private var buttonLabelText: String {
        if case .value(let s) = fieldState, let d = Self.storageFormatter.date(from: s) {
            return Self.displayFormatter.string(from: d)
        }
        if fieldState.isMixed { return "(Mixed)" }
        return "Select date"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button {
                showingPicker = true
                HapticManager.shared.impact(.light)
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text(buttonLabelText)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingPicker) {
            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .presentationDetents([.height(420)])
            .onChange(of: selectedDate) { _, newValue in
                let s = Self.storageFormatter.string(from: newValue)
                fieldState = .value(s)
                showingPicker = false
            }
        }
        .onAppear {
            guard !hasInitialised else { return }
            hasInitialised = true
            if case .value(let s) = fieldState, let d = Self.storageFormatter.date(from: s) {
                selectedDate = d
            }
        }
    }
}
```

2. Locate existing `BulkEditFlightTypeToggle` in this file (referenced from BulkEditSheet line 228 with `isPositioning:` + `isSimulator:` args). Extend its signature to add a third binding for INS:
   - Add property: `@Binding var isSpIns: BulkEditViewModel.FieldState<Bool>`
   - Add a third row in its body matching the visual style of the existing simulator row (label "INS"), reusing whatever internal toggle/segmented helper the existing rows use
   - Do NOT remove or change the positioning or simulator rows or their behaviour

If `BulkEditFlightTypeToggle` is defined in a separate file in this directory (look in the same folder), edit that file instead. The file list above includes BulkEditFields.swift — if not there, locate via grep first.
  </action>
  <verify>
    <automated>grep -n "BulkEditDateField\|isSpIns" Block-Time/Views/Screens/BulkEdit/*.swift</automated>
    Expect: BulkEditDateField struct present; isSpIns binding added to BulkEditFlightTypeToggle.
  </verify>
  <done>
- BulkEditDateField struct exists with iOS 26 pattern (Button + .sheet + .graphical DatePicker + presentationDetents([.height(420)]))
- BulkEditFlightTypeToggle accepts isSpIns binding and renders an INS row
- Existing positioning/simulator behaviour preserved
  </done>
</task>

<task type="auto">
  <name>Task 3: Add Flight Date card, INS row, and Custom Fields card to BulkEditSheet</name>
  <files>Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift</files>
  <action>
1. Add `@Environment(CustomCounterService.self) private var customCounterService` near the top of the struct (alongside the existing `@Environment(ThemeService.self)`). The service is @Observable so the card auto-refreshes when definitions change.
   - If injection isn't set up where BulkEditSheet is presented, fall back to `private var customCounterService: CustomCounterService { CustomCounterService.shared }` as a computed property. Choose the @Environment approach first; if it causes a crash on present (no environment), switch to the computed-property fallback. Document the choice with a brief inline comment.

2. Add the Flight Date SectionCard as the FIRST card in the ScrollView VStack (above the Aircraft Information card on line 46):
```swift
SectionCard(title: "Flight Date", icon: "calendar", color: .blue) {
    BulkEditDateField(
        label: "Date",
        fieldState: $bulkEditViewModel.flightDate
    )
}
```

3. In the Operations card (line 226-246), update the BulkEditFlightTypeToggle call to pass the new isSpIns binding:
```swift
BulkEditFlightTypeToggle(
    isPositioning: $bulkEditViewModel.isPositioning,
    isSimulator: $bulkEditViewModel.isSimulator,
    isSpIns: $bulkEditViewModel.isSpIns
)
```
Do NOT remove or reorder other elements in the Operations card.

4. In the Flight Times card (line 142-186), add a `BulkEditTextField` for SP/INS Time directly after the SIM Time field (line 180-184):
```swift
BulkEditTextField(
    label: "SP/INS Time",
    fieldState: $bulkEditViewModel.spInsTime,
    keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
)
```

5. Add the Custom Fields SectionCard at the end of the VStack (after the Remarks card on line 278-282), conditional on definitions being non-empty (per CONTEXT D-Custom Fields):
```swift
if !customCounterService.definitions.isEmpty {
    SectionCard(title: "Custom Fields", icon: "slider.horizontal.below.square.filled.and.square", color: .mint) {
        VStack(spacing: 12) {
            ForEach(customCounterService.definitions) { def in
                BulkEditTextField(
                    label: def.label,
                    fieldState: Binding(
                        get: { bulkEditViewModel.customCounterStates[def.columnIndex] ?? .notEdited },
                        set: { bulkEditViewModel.customCounterStates[def.columnIndex] = $0 }
                    ),
                    keyboardType: keyboardType(for: def.type),
                    isTimeField: def.type == .time
                )
            }
        }
    }
}
```

6. Add a helper inside BulkEditSheet body or as a private method:
```swift
private func keyboardType(for type: CounterType) -> UIKeyboardType {
    switch type {
    case .time:    return .numberPad
    case .decimal: return UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
    case .integer: return .numberPad
    case .text:    return .default
    }
}
```

7. Do NOT remove or alter any existing card or field. Verify the existing Cancel/Save toolbar still works.
  </action>
  <verify>
    <automated>grep -n "Flight Date\|Custom Fields\|SP/INS Time\|isSpIns:" Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift</automated>
    Expect: matches for all four new pieces.
  </verify>
  <done>
- Flight Date card appears first in scroll view
- INS toggle present in Operations card
- SP/INS Time field present in Flight Times card after SIM Time
- Custom Fields card renders one row per definition with correct keyboard, hidden when definitions empty
- All existing cards and fields untouched
- File compiles (verified manually by user — see checkpoint)
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 4: Verify BulkEditSheet shows new fields and bulk-edits correctly</name>
  <what-built>
- BulkEditViewModel state for flightDate, isSpIns, spInsTime, customCounterStates
- BulkEditDateField component (iOS 26 date picker pattern)
- Extended BulkEditFlightTypeToggle with INS row
- Flight Date card (first), SP/INS Time in Flight Times, INS row in Operations, Custom Fields card (mint, last)
- applyChanges writes date / spInsTime+blockTime swap / counterEntries
  </what-built>
  <how-to-verify>
Build locally (do not auto-build — Nelson runs builds), then in the app:

1. Select 2+ flights and open Bulk Edit. Confirm a "Flight Date" card appears first with a date button. Tap it; date picker sheet should appear (.graphical, ~420pt). Pick a date; sheet auto-dismisses; button shows new date.

2. In the Operations card, confirm an INS toggle is present alongside Positioning and Simulator. Toggle it on.

3. In the Flight Times card, confirm a "SP/INS Time" field appears after SIM Time with decimalPad keyboard.

4. If you have custom field definitions in Settings, confirm a mint "Custom Fields" card appears at the bottom with one row per definition, correct keyboard per type (time = numeric HH:MM, decimal = decimal, integer = numeric, text = default).

5. If you have NO custom field definitions, confirm the Custom Fields card is hidden entirely.

6. Modify each new field and confirm the Save button enables. Tap Save; reopen the bulk-edited flights and confirm:
   - flight.date matches the chosen date
   - flights flagged INS show spInsTime populated and blockTime zeroed (or vice versa when un-flagged)
   - flight.counterEntries[columnIndex] contains the value typed for each custom field
   - Existing fields (rego, crew, times, ops, T/O, landings, remarks) still bulk-edit as before

7. Confirm Cancel + discard-alert still work.
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues for revision</resume-signal>
</task>

</tasks>

<verification>
- All 3 new fields visible and functional in BulkEditSheet
- applyChanges writes all 3 new field groups without breaking existing applies
- Save enables on any modification (including custom field edits)
- Custom Fields card hidden when CustomCounterService.shared.definitions is empty
- No existing BulkEditSheet feature lost
</verification>

<success_criteria>
- BulkEditSheet has parity with AddFlightView for: flight date, INS / spInsTime, custom fields
- Direct flight number editing remains out of scope (prefix manager untouched)
- User confirms via checkpoint
</success_criteria>

<output>
After completion, create `.planning/quick/260523-qbo-add-missing-fields-to-bulkeditsheet-flig/260523-qbo-SUMMARY.md`
</output>
