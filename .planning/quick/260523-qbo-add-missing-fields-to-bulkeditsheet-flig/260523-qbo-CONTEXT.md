# Quick Task 260523-qbo: Add Missing Fields to BulkEditSheet - Context

**Gathered:** 2026-05-23
**Status:** Ready for planning

<domain>
## Task Boundary

Add three missing field groups to BulkEditSheet so it has feature parity with AddFlightView:
1. Flight Date — set exact date for all selected flights
2. Sp/Ins — isSpIns toggle + spInsTime field
3. Custom Fields — dynamic card driven by CustomCounterService.shared.definitions

Direct flight number editing is explicitly out of scope (prefix manager is sufficient).

</domain>

<decisions>
## Implementation Decisions

### Flight Date
- Use "set exact date" — all selected flights get the same date
- UI: date picker (matching the iOS 26 DatePicker pattern used elsewhere in the app — Button + sheet with .graphical picker)
- Storage: FlightSector.date is a String (format "DD/MM/YYYY"), so FieldState<String> with formatted string
- Placement: New "Flight Date" card, positioned first in the scroll view (above Aircraft Information)

### Sp/Ins Fields
- Add isSpIns: FieldState<Bool> to BulkEditViewModel alongside isPositioning/isSimulator
- Add spInsTime: FieldState<String> to BulkEditViewModel alongside simTime
- UI: BulkEditFlightTypeToggle extended to include INS, or a separate row — mirror the existing isSimulator pattern
- applyChanges: mirror the isSimulator conversion logic for spInsTime
- Placement: in the existing Operations card alongside the isPositioning/isSimulator toggles

### Custom Fields Card
- BulkEditViewModel holds `var customCounterStates: [Int: FieldState<String>]` keyed by columnIndex
- analyzeFields reads CustomCounterService.shared.definitions and for each, analyzes FlightSector.counterEntries[columnIndex] across selected flights
- applyChanges iterates definitions and writes back to flight.counterEntries[columnIndex]
- BulkEditSheet renders a "Custom Fields" SectionCard (color: .mint) only when CustomCounterService.shared.definitions is non-empty
- Each definition renders as BulkEditTextField with keyboard type appropriate to CounterType:
  - .time → numberPad (HH:MM, isTimeField: true)
  - .decimal → decimalPad
  - .integer → numberPad
  - .text → default (multiline not needed in bulk context; single-line BulkEditTextField is fine)
- Modification tracking: customCounterStates changes trigger checkForModifications

### Claude's Discretion
- FieldState<String> is used for all custom counter types (time, decimal, integer, text) — consistent with how simTime/blockTime are stored as String
- The dynamic card observes CustomCounterService.shared.definitions directly (it's @Observable), so no manual refresh needed
- spInsTime field only shown in bulk if at least one selected flight has isSpIns; otherwise hidden (mirrors how simTime behaves conceptually) — actually, since bulk edit sets values uniformly, always show spInsTime alongside the toggle

</decisions>

<specifics>
## Specific References

- BulkEditViewModel: `Block-Time/ViewModels/BulkEditViewModel.swift` — add isSpIns, spInsTime, flightDate, customCounterStates properties; extend analyzeFields, storeInitialStates, setupModificationTracking, applyChanges
- BulkEditSheet: `Block-Time/Views/Screens/BulkEdit/BulkEditSheet.swift` — add Flight Date card, INS row in Operations card, Custom Fields card
- BulkEditFields: `Block-Time/Views/Screens/BulkEdit/BulkEditFields.swift` — no new component needed; reuse BulkEditTextField for all custom fields; date picker can be inline in BulkEditSheet
- FlightSector.date format: "DD/MM/YYYY" string — use DateFormatter with "dd/MM/yyyy"
- iOS 26 DatePicker pattern: Button → .sheet with .graphical DatePicker + .presentationDetents([.height(420)]) + auto-dismiss via onChange (see project memory)
- CustomCounterService.shared.definitions: [CustomCounterDefinition] — each has .columnIndex (Int), .label (String), .type (CounterType)
- FlightSector.counterEntries: [Int: String] — keyed by columnIndex

</specifics>

<canonical_refs>
## Canonical References

- Existing isSimulator/simTime pattern in BulkEditViewModel (lines 77, 66, 539-555) — replicate for isSpIns/spInsTime
- AddFlightView iOS 26 DatePicker pattern in project memory — replicate for flight date field
- CustomCounterService.shared.definitions iteration in CrewOpsCard (lines 148-154) — replicate in BulkEditSheet

</canonical_refs>
