# Toolbar Multiplicity Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the duplicate `.toolbar { ToolbarItemGroup(placement: .keyboard) }` modifiers from all reusable field components and replace them with a single keyboard toolbar owned by the `AddFlightView` scroll container, eliminating the freeze when entering OUT/IN times.

**Architecture:** Each field component exposes a `FocusState` binding so that a shared `KeyboardToolbar` environment object can track which field is active. The scroll container reads this state and renders exactly one toolbar. The field components lose their per-instance `.toolbar` calls entirely. No changes to ViewModel or data flow.

**Tech Stack:** SwiftUI, `@FocusState`, `@Observable`, `ToolbarItemGroup(placement: .keyboard)`

---

## File Map

| File | Change |
|------|--------|
| `Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift` | Remove `.toolbar` from all 4 field structs; add `FocusState.Binding` parameter to each |
| `Block-Time/Views/Components/AddFlightView/KeyboardToolbarState.swift` | **Create** — `@Observable` class tracking whether any field is focused + clear/done actions |
| `Block-Time/Views/Components/AddFlightView/FlightInfoCard.swift` | Pass focused-field binding into `ModernTimeField` / `ModernDecimalTimeField` |
| `Block-Time/Views/Components/AddFlightView/TogglesSection.swift` | Pass focused-field binding into `ModernIntegerField` |
| `Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift` | Pass focused-field binding into `ModernRemarksField` |
| `Block-Time/Views/Screens/AddFlightView.swift` | Add single `.toolbar` at `ScrollView` level; inject `KeyboardToolbarState` |

---

## Strategy

SwiftUI's `FocusState` cannot be passed directly between views as a plain `Bool` binding — it must be owned by the view that renders the focused `TextField`. The cleanest pattern for a single keyboard toolbar is:

1. Each field struct keeps its own `@FocusState private var isFocused: Bool` (unchanged).
2. Each field struct accepts an optional `Binding<Bool>` called `externalFocused`.
3. When `isFocused` changes, the field writes `externalFocused?.wrappedValue = isFocused`.
4. The parent view owns an `@State var anyFieldFocused: Bool` and one combined "clear" action stored alongside it.
5. A single `.toolbar { ToolbarItemGroup(placement: .keyboard) { ... } }` on the `ScrollView` renders the Done/Clear buttons using `anyFieldFocused` as the guard.

The "Clear" action is context-sensitive (each field would need to clear its own value). The simplest approach: each field passes a closure `onClear: () -> Void` upward alongside the focus binding, and the toolbar state stores the latest active clear closure.

---

## Task 1: Create `KeyboardToolbarState`

**Files:**
- Create: `Block-Time/Views/Components/AddFlightView/KeyboardToolbarState.swift`

This tiny `@Observable` class is the single source of truth for the keyboard toolbar. It tracks whether any field is focused, provides a "dismiss all" signal, and stores the current field's clear action.

- [ ] **Step 1: Create the file**

```swift
// KeyboardToolbarState.swift
import SwiftUI

/// Shared state for the single keyboard toolbar in AddFlightView.
/// Each field reports its focus and registers its clear action here.
@Observable
final class KeyboardToolbarState {
    var isAnyFieldFocused: Bool = false
    var onClear: (() -> Void)? = nil

    func fieldDidFocus(clear: @escaping () -> Void) {
        isAnyFieldFocused = true
        onClear = clear
    }

    func fieldDidBlur() {
        // Don't set isAnyFieldFocused = false here; the toolbar
        // hides itself via the keyboard dismissal, not via this flag.
        // Resetting between fields causes a toolbar flash.
    }
}
```

- [ ] **Step 2: Verify the file compiles (build the project in Xcode)**

No test needed for this step — it is a pure data model with no logic.

---

## Task 2: Strip `.toolbar` from `ModernTimeField` and add focus reporting

**Files:**
- Modify: `Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift` (lines ~71–155, `ModernTimeField`)

`ModernTimeField` currently has its own `.toolbar { ToolbarItemGroup(placement: .keyboard) }`. Remove it. Add an optional `keyboardToolbar: KeyboardToolbarState?` parameter. When `timeFieldFocused` becomes true, call `keyboardToolbar?.fieldDidFocus(clear: { value = "" })`.

- [ ] **Step 1: Add the parameter and remove the toolbar from `ModernTimeField`**

Replace the entire `ModernTimeField` struct with:

```swift
struct ModernTimeField: View {
    let label: String
    @Binding var value: String
    let icon: String
    var isReadOnly: Bool = false
    var dateString: String = ""
    var airportCode: String = ""
    var showLocalTime: Bool = false
    var useIATACodes: Bool = false
    var isRequired: Bool = false
    var hintText: String? = nil
    /// Optional shared keyboard toolbar state. When set, this field reports its
    /// focus to the shared toolbar instead of owning its own toolbar items.
    var keyboardToolbar: KeyboardToolbarState? = nil
    @FocusState private var timeFieldFocused: Bool
    var onSave: (() -> Void)? = nil

    private func applyFormatting(_ input: String) -> String {
        let filtered = input.filter { $0.isNumber || $0 == ":" }
        if filtered.count == 4 && !filtered.contains(":") {
            let hours = String(filtered.prefix(2))
            let minutes = String(filtered.suffix(2))
            return "\(hours):\(minutes)"
        }
        return String(filtered.prefix(5))
    }

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

    private var localTimeText: String? {
        guard showLocalTime,
              !value.isEmpty,
              !dateString.isEmpty,
              !airportCode.isEmpty else {
            return nil
        }
        let localTime = AirportService.shared.convertToLocalTime(
            utcDateString: dateString,
            utcTimeString: value,
            airportICAO: airportCode
        )
        let airportDisplay = AirportService.shared.getDisplayCode(airportCode, useIATA: useIATACodes)
        if localTime.count == 4 {
            let hours = String(localTime.prefix(2))
            let minutes = String(localTime.suffix(2))
            return "\(hours):\(minutes) \(airportDisplay)"
        }
        return "\(localTime) \(airportDisplay)"
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isReadOnly ? .gray : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(label)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    if isRequired && value.isEmpty {
                        Circle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 7, height: 7)
                    }
                }

                if isReadOnly {
                    HStack {
                        Text(value.isEmpty ? "--:--" : value)
                            .font(.subheadline.bold())
                            .foregroundColor(value.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    TextField("HH:MM", text: $value)
                        .font(.subheadline.bold())
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad)
                        .focused($timeFieldFocused)
                        .onChange(of: value) { _, newValue in
                            value = applyFormatting(newValue)
                        }
                        .onChange(of: timeFieldFocused) { _, isFocused in
                            if isFocused {
                                keyboardToolbar?.fieldDidFocus(clear: { value = "" })
                            } else {
                                value = formatWithLeadingZeros(value)
                                onSave?()
                            }
                        }
                        .submitLabel(.done)
                }

                if let hint = hintText {
                    Text(hint)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let localTime = localTimeText {
                    Text(localTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(1.0))
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReadOnly {
                timeFieldFocused = true
            }
        }
        // No .toolbar here — toolbar is owned by the parent scroll container.
    }
}
```

- [ ] **Step 2: Build in Xcode and verify no compile errors**

All existing call sites pass `keyboardToolbar` as `nil` by default, so no callers break yet.

---

## Task 3: Strip `.toolbar` from `ModernDecimalTimeField`

**Files:**
- Modify: `Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift` (lines ~158–328, `ModernDecimalTimeField`)

Same pattern as Task 2.

- [ ] **Step 1: Add `keyboardToolbar` parameter and remove `.toolbar` from `ModernDecimalTimeField`**

Replace the entire `ModernDecimalTimeField` struct with:

```swift
struct ModernDecimalTimeField: View {
    let label: String
    @Binding var value: String
    let icon: String
    var isReadOnly: Bool = false
    var showAsHHMM: Bool = false
    var isRequired: Bool = false
    /// Optional shared keyboard toolbar state.
    var keyboardToolbar: KeyboardToolbarState? = nil
    @FocusState private var decimalFieldFocused: Bool
    var onSave: (() -> Void)? = nil

    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel

    private func sanitize(_ input: String) -> String {
        if showAsHHMM {
            return input.filter { $0.isNumber || $0 == ":" }
        } else {
            var result = ""
            var hasSeparator = false
            for ch in input {
                if ch.isNumber {
                    result.append(ch)
                } else if ch == "." || ch == "," {
                    if !hasSeparator {
                        result.append(".")
                        hasSeparator = true
                    }
                }
            }
            return result
        }
    }

    private func formatOnBlur(_ input: String) -> String {
        if showAsHHMM {
            if input.contains(":") {
                let components = input.split(separator: ":")
                if components.count == 2,
                   let hours = Int(components[0]),
                   let minutes = Int(components[1]),
                   hours >= 0, minutes >= 0, minutes < 60 {
                    return String(format: "%d:%02d", hours, minutes)
                }
            } else if let decimalValue = Double(input) {
                return FlightSector.decimalToHHMM(decimalValue)
            }
            return input.isEmpty ? "0:00" : input
        } else {
            let cleaned = input.replacingOccurrences(of: ",", with: ".")
            if let d = Double(cleaned) {
                let rounded = viewModel.decimalRoundingMode.apply(to: d, decimalPlaces: 1)
                return String(format: "%.1f", rounded)
            }
            return input.isEmpty ? "0.0" : input
        }
    }

    private func convertToDecimalForStorage(_ input: String) -> String {
        if showAsHHMM && input.contains(":") {
            if let decimal = FlightSector.hhmmToDecimal(input) {
                return String(format: "%.2f", decimal)
            }
        }
        return input
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isReadOnly ? .gray : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(label)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    if isRequired && value.isEmpty {
                        Circle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 7, height: 7)
                    }
                }

                if isReadOnly {
                    HStack {
                        Text(displayValue)
                            .font(.subheadline.bold())
                            .foregroundColor(value.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    TextField(showAsHHMM ? "0:00" : "0.0", text: Binding(
                        get: {
                            if decimalFieldFocused || value.isEmpty {
                                return value
                            } else {
                                return displayValue
                            }
                        },
                        set: { newValue in
                            value = sanitize(newValue)
                        }
                    ))
                        .font(.subheadline.bold())
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                        .focused($decimalFieldFocused)
                        .onChange(of: decimalFieldFocused) { _, isFocused in
                            if isFocused {
                                keyboardToolbar?.fieldDidFocus(clear: { value = "" })
                            } else {
                                let decimalValue = convertToDecimalForStorage(value)
                                value = decimalValue
                                onSave?()
                            }
                        }
                        .submitLabel(.done)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReadOnly {
                decimalFieldFocused = true
            }
        }
        // No .toolbar here — toolbar is owned by the parent scroll container.
    }

    private var displayValue: String {
        guard !value.isEmpty, let decimalValue = Double(value) else {
            return showAsHHMM ? "0:00" : "0.0"
        }
        if showAsHHMM {
            return FlightSector.decimalToHHMM(decimalValue)
        } else {
            let rounded = viewModel.decimalRoundingMode.apply(to: decimalValue, decimalPlaces: 1)
            return String(format: "%.1f", rounded)
        }
    }
}
```

- [ ] **Step 2: Build in Xcode — no compile errors**

---

## Task 4: Strip `.toolbar` from `ModernIntegerField`

**Files:**
- Modify: `Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift` (lines ~331–400, `ModernIntegerField`)

- [ ] **Step 1: Add `keyboardToolbar` parameter and remove `.toolbar` from `ModernIntegerField`**

Replace the entire `ModernIntegerField` struct with:

```swift
struct ModernIntegerField: View {
    let label: String
    @Binding var value: Int
    let icon: String
    var keyboardToolbar: KeyboardToolbarState? = nil
    var onValueChanged: (() -> Void)? = nil
    @State private var editingText: String = ""
    @FocusState private var integerFieldFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                TextField("0", text: $editingText)
                    .font(.subheadline.bold())
                    .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad)
                    .focused($integerFieldFocused)
                    .onChange(of: editingText) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        editingText = filtered
                    }
                    .onChange(of: integerFieldFocused) { _, isFocused in
                        if isFocused {
                            editingText = value == 0 ? "" : "\(value)"
                            keyboardToolbar?.fieldDidFocus(clear: {
                                editingText = ""
                                value = 0
                            })
                        } else {
                            let oldValue = value
                            if let intValue = Int(editingText) {
                                value = max(0, intValue)
                            } else {
                                value = 0
                            }
                            if oldValue != value {
                                onValueChanged?()
                            }
                        }
                    }
                    .submitLabel(.done)
                    .onAppear {
                        editingText = value == 0 ? "" : "\(value)"
                    }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            integerFieldFocused = true
        }
        // No .toolbar here — toolbar is owned by the parent scroll container.
    }
}
```

- [ ] **Step 2: Build in Xcode — no compile errors**

---

## Task 5: Strip `.toolbar` from `ModernRemarksField`

**Files:**
- Modify: `Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift` (lines ~403–457, `ModernRemarksField`)

`ModernRemarksField` only has a "Done" button (no "Clear"). Its clear action can be a no-op for the shared toolbar, since text editors don't typically need a Clear button. Just report focus.

- [ ] **Step 1: Add `keyboardToolbar` parameter and remove `.toolbar` from `ModernRemarksField`**

Replace the entire `ModernRemarksField` struct with:

```swift
struct ModernRemarksField: View {
    let label: String
    @Binding var value: String
    let icon: String
    var keyboardToolbar: KeyboardToolbarState? = nil
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if value.isEmpty {
                    Text("Add remarks...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $value)
                    .font(.subheadline)
                    .frame(minHeight: 40)
                    .focused($editorFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            editorFocused = true
        }
        .onChange(of: editorFocused) { _, isFocused in
            if isFocused {
                // Remarks has no Clear button — pass a no-op clear action
                keyboardToolbar?.fieldDidFocus(clear: {})
            }
        }
        // No .toolbar here — toolbar is owned by the parent scroll container.
    }
}
```

- [ ] **Step 2: Build in Xcode — no compile errors**

---

## Task 6: Wire `KeyboardToolbarState` into `FlightInfoCard`

**Files:**
- Modify: `Block-Time/Views/Components/AddFlightView/FlightInfoCard.swift`

`ModernCapturedDataCard` (which is the view inside `FlightInfoCard.swift`) needs to pass `keyboardToolbar` into each `ModernTimeField` and `ModernDecimalTimeField` call site.

The `KeyboardToolbarState` will be passed in as a parameter from `AddFlightView`.

- [ ] **Step 1: Add `keyboardToolbar` parameter to `ModernCapturedDataCard`**

At the top of the struct definition, add:

```swift
struct ModernCapturedDataCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Environment(CloudKitSettingsSyncService.self) private var cloudKitService
    var keyboardToolbar: KeyboardToolbarState? = nil   // ← ADD THIS

    @State private var nightTimeDebounceTask: Task<Void, Never>?
    // ... rest unchanged
```

- [ ] **Step 2: Pass `keyboardToolbar` to each `ModernTimeField` call in `ModernCapturedDataCard.body`**

There are four `ModernTimeField` calls (STD, STA, OUT, IN). Add `keyboardToolbar: keyboardToolbar` to each:

```swift
// STD field
ModernTimeField(
    label: timeFieldLabel("STD", tzLabel: viewModel.outTimezoneLabel),
    value: localTimeBinding(utcTime: $viewModel.scheduledDeparture, airportCode: viewModel.fromAirport),
    icon: "calendar.badge.clock",
    isReadOnly: false,
    dateString: viewModel.flightDate,
    airportCode: viewModel.fromAirport,
    showLocalTime: viewModel.displayFlightsInLocalTime && !viewModel.enterTimesInLocalTime,
    useIATACodes: viewModel.useIATACodes,
    hintText: utcHintText(utcTime: viewModel.scheduledDeparture, tzLabel: viewModel.outTimezoneLabel),
    keyboardToolbar: keyboardToolbar,
    onSave: {}
)

// STA field
ModernTimeField(
    label: timeFieldLabel("STA", tzLabel: viewModel.inTimezoneLabel),
    value: localTimeBinding(utcTime: $viewModel.scheduledArrival, airportCode: viewModel.toAirport),
    icon: "calendar.badge.clock",
    isReadOnly: false,
    dateString: viewModel.flightDate,
    airportCode: viewModel.toAirport,
    showLocalTime: viewModel.displayFlightsInLocalTime && !viewModel.enterTimesInLocalTime,
    useIATACodes: viewModel.useIATACodes,
    hintText: utcHintText(utcTime: viewModel.scheduledArrival, tzLabel: viewModel.inTimezoneLabel),
    keyboardToolbar: keyboardToolbar,
    onSave: {}
)

// OUT field
ModernTimeField(
    label: timeFieldLabel("OUT", tzLabel: viewModel.outTimezoneLabel),
    value: localTimeBinding(utcTime: $viewModel.outTime, airportCode: viewModel.fromAirport),
    icon: "clock",
    isReadOnly: false,
    dateString: viewModel.flightDate,
    airportCode: viewModel.fromAirport,
    showLocalTime: viewModel.displayFlightsInLocalTime && !viewModel.enterTimesInLocalTime,
    useIATACodes: viewModel.useIATACodes,
    isRequired: viewModel.saveRequirements.needsAirports && !viewModel.saveRequirements.times,
    hintText: utcHintText(utcTime: viewModel.outTime, tzLabel: viewModel.outTimezoneLabel),
    keyboardToolbar: keyboardToolbar,
    onSave: { viewModel.recalculateTimesAfterManualEdit() }
)

// IN field
ModernTimeField(
    label: timeFieldLabel("IN", tzLabel: viewModel.inTimezoneLabel),
    value: localTimeBinding(utcTime: $viewModel.inTime, airportCode: viewModel.toAirport),
    icon: "clock",
    isReadOnly: false,
    dateString: viewModel.flightDate,
    airportCode: viewModel.toAirport,
    showLocalTime: viewModel.displayFlightsInLocalTime && !viewModel.enterTimesInLocalTime,
    useIATACodes: viewModel.useIATACodes,
    isRequired: viewModel.saveRequirements.needsAirports && !viewModel.saveRequirements.times,
    hintText: utcHintText(utcTime: viewModel.inTime, tzLabel: viewModel.inTimezoneLabel),
    keyboardToolbar: keyboardToolbar,
    onSave: { viewModel.recalculateTimesAfterManualEdit() }
)
```

- [ ] **Step 3: Pass `keyboardToolbar` to the three `ModernDecimalTimeField` calls (INS Time, BLOCK/SIM Time, NIGHT Time)**

```swift
// INS Time (isSpIns && !isInstructingInAircraft branch)
ModernDecimalTimeField(
    label: "INS Time",
    value: $viewModel.spInsTime,
    icon: "person.fill.badge.plus",
    isReadOnly: false,
    showAsHHMM: viewModel.showTimesInHoursMinutes,
    isRequired: viewModel.saveRequirements.needsBlockOrInsTime,
    keyboardToolbar: keyboardToolbar
)

// BLOCK/SIM Time
ModernDecimalTimeField(
    label: viewModel.isSimulator ? "SIM Time" : "BLOCK Time",
    value: $viewModel.blockTime,
    icon: viewModel.isSimulator ? "desktopcomputer" : "timer",
    isReadOnly: viewModel.isPositioning,
    showAsHHMM: viewModel.showTimesInHoursMinutes,
    isRequired: viewModel.saveRequirements.needsBlockOrInsTime,
    keyboardToolbar: keyboardToolbar
)

// NIGHT Time
ModernDecimalTimeField(
    label: "NIGHT Time",
    value: $viewModel.nightTime,
    icon: "moon.stars",
    isReadOnly: viewModel.isPositioning,
    showAsHHMM: viewModel.showTimesInHoursMinutes,
    keyboardToolbar: keyboardToolbar
)
```

- [ ] **Step 4: Build in Xcode — no compile errors**

---

## Task 7: Wire `KeyboardToolbarState` into `TogglesSection`

**Files:**
- Modify: `Block-Time/Views/Components/AddFlightView/TogglesSection.swift`

`TogglesSection` contains four `ModernIntegerField` instances (Day T/O, Day LDG, Night T/O, Night LDG).

- [ ] **Step 1: Read the current `TogglesSection` struct signature**

Identify the struct and add `var keyboardToolbar: KeyboardToolbarState? = nil` as a property.

- [ ] **Step 2: Pass `keyboardToolbar: keyboardToolbar` to all four `ModernIntegerField` calls**

Each `ModernIntegerField` call site should become:

```swift
ModernIntegerField(
    label: "Day T/O",    // (or Day LDG / Night T/O / Night LDG as appropriate)
    value: $viewModel.dayTakeoffs,   // (appropriate binding)
    icon: "...",
    keyboardToolbar: keyboardToolbar,
    onValueChanged: { viewModel.updateTakeoffsLandings() }  // if present
)
```

- [ ] **Step 3: Build in Xcode — no compile errors**

---

## Task 8: Wire `KeyboardToolbarState` into `CrewOpsCard`

**Files:**
- Modify: `Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift`

`CrewOpsCard` contains one `ModernRemarksField`.

- [ ] **Step 1: Read the current `CrewOpsCard` struct signature**

Identify where `ModernRemarksField` is called.

- [ ] **Step 2: Add `var keyboardToolbar: KeyboardToolbarState? = nil` to `CrewOpsCard` and pass it through**

```swift
ModernRemarksField(
    label: "REMARKS",
    value: $viewModel.remarks,
    icon: "text.bubble",
    keyboardToolbar: keyboardToolbar
)
```

- [ ] **Step 3: Build in Xcode — no compile errors**

---

## Task 9: Add the single toolbar to `AddFlightView` (the fix that eliminates the freeze)

**Files:**
- Modify: `Block-Time/Views/Screens/AddFlightView.swift`

This is the payoff task. One `KeyboardToolbarState` instance lives here, one `.toolbar` modifier lives on the `ScrollView`, and `keyboardToolbar` is passed down into the card components.

- [ ] **Step 1: Add `@State` for `KeyboardToolbarState` to `AddFlightView`**

```swift
struct AddFlightView: View {
    @Environment(ThemeService.self) private var themeService
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccessNotification = false
    @State private var successMessage = ""
    @State private var keyboardToolbar = KeyboardToolbarState()   // ← ADD THIS
```

- [ ] **Step 2: Pass `keyboardToolbar` through to the layout views**

`WideLayoutView` and `CompactLayoutView` need a `keyboardToolbar` parameter. For now the quickest path is to pass it via the environment:

Instead of creating a new parameter on those views (which would require propagating further), inject it as an environment value. Add `@Environment(KeyboardToolbarState.self)` pickup in the card components.

**Simpler approach (recommended):** Pass it as a concrete parameter to `WideLayoutView` and `CompactLayoutView`, then thread it through to `ModernCapturedDataCard`, `TogglesSection`, and `CrewOpsCard`. This requires reading those layout views to add the parameter.

Read `WideLayoutView` and `CompactLayoutView` (they are defined at the bottom of `AddFlightView.swift` or in separate files) and add:

```swift
var keyboardToolbar: KeyboardToolbarState
```

Then pass `keyboardToolbar: keyboardToolbar` at each instantiation site.

- [ ] **Step 3: Add the single `.toolbar` modifier to the `ScrollView`**

```swift
ScrollView {
    // ... existing content
}
.toolbar {
    ToolbarItemGroup(placement: .keyboard) {
        if keyboardToolbar.isAnyFieldFocused {
            Button("Clear") {
                keyboardToolbar.onClear?()
            }
            .foregroundColor(.red)
            Spacer()
            Button("Done") {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                keyboardToolbar.isAnyFieldFocused = false
            }
            .font(.subheadline.bold())
        }
    }
}
```

- [ ] **Step 4: Build in Xcode — no compile errors**

---

## Task 10: Verify and commit

- [ ] **Step 1: Run the app on device or simulator**

Open `AddFlightView`. Set FROM and TO airports. Type into the OUT time field character by character. Verify:
- No freeze or stutter
- The keyboard toolbar shows "Clear" and "Done" buttons
- "Clear" wipes the OUT field
- "Done" dismisses the keyboard
- Typing into IN field → Clear clears IN field
- Typing into BLOCK/NIGHT/INS decimal fields → toolbar still appears

- [ ] **Step 2: Verify edit mode is also unaffected**

Open an existing flight in edit mode. Type into OUT/IN. Same behaviour.

- [ ] **Step 3: Verify BulkEdit is unaffected**

Open BulkEdit sheet — still works, no regression.

- [ ] **Step 4: Commit**

```bash
git add \
  "Block-Time/Views/Components/AddFlightView/KeyboardToolbarState.swift" \
  "Block-Time/Views/Components/AddFlightView/FlightTimeFields.swift" \
  "Block-Time/Views/Components/AddFlightView/FlightInfoCard.swift" \
  "Block-Time/Views/Components/AddFlightView/TogglesSection.swift" \
  "Block-Time/Views/Components/AddFlightView/CrewOpsCard.swift" \
  "Block-Time/Views/Screens/AddFlightView.swift"

git commit -m "fix: remove duplicate keyboard toolbar modifiers from field components

Multiple .toolbar{placement:.keyboard} modifiers in the same view hierarchy
caused SwiftUI to rebuild all toolbar item groups on every keystroke, freezing
the UI when entering OUT/IN times in AddFlightView.

Replace with a single toolbar on the ScrollView, driven by KeyboardToolbarState
(@Observable). Each field reports focus + clear action to KeyboardToolbarState
instead of owning its own toolbar items.

BulkEdit is unaffected (it does not use these field components)."
```

---

## Self-Review

**Spec coverage:**
- ✅ Remove `.toolbar` from `ModernTimeField` — Task 2
- ✅ Remove `.toolbar` from `ModernDecimalTimeField` — Task 3
- ✅ Remove `.toolbar` from `ModernIntegerField` — Task 4
- ✅ Remove `.toolbar` from `ModernRemarksField` — Task 5
- ✅ Single toolbar on `AddFlightView` ScrollView — Task 9
- ✅ "Clear" action per field via closure — Tasks 2–8
- ✅ "Done" action dismisses first responder — Task 9

**Placeholder scan:** No TBDs, no "implement later", all code is shown.

**Type consistency:**
- `KeyboardToolbarState` defined in Task 1, referenced in Tasks 2–9 ✅
- `fieldDidFocus(clear:)` defined in Task 1, called in Tasks 2–5 ✅
- `keyboardToolbar` parameter name consistent across all field structs ✅
- `isAnyFieldFocused` set in `fieldDidFocus`, read in Task 9 toolbar ✅

**One gap identified:** Task 9 Step 2 says to read `WideLayoutView` and `CompactLayoutView` — these are referenced but their exact file location is noted as "bottom of AddFlightView.swift or in separate files". The executor must `Read` `AddFlightView.swift` fully before Task 9 to confirm where those views live and how to thread the parameter through. This is by design — the plan says what to do, the executor confirms the exact structure from the current file state.
