# Quick Task: Variable SIM Time for INS Simulator Flights

**ID:** 260517-ins-sim-variable-time  
**Date:** 2026-05-17  
**Goal:** Instructors in a simulator can now log 0 to full INS time as SIM time. The SIM field autofills to match INS but is user-editable. Full INS time always stored in spInsTime; simTime stores only the seat-time portion.

## Tasks

- [ ] 1. Fix `isSpInsOnly` classifier in `FlightLogbook.swift` — use blockTime==0 heuristic instead of simTime==spInsTime
- [ ] 2. Fix `entityIsSpInsOnly` in `FlightDatabaseService.swift` — same logic change
- [ ] 3. Update `totalSIM` accumulation in all 3 stats loops — INS Sim simTime now contributes to totalSIM
- [ ] 4. Add `simInsTime` + `simInsTimeIsManual` published properties to `FlightTimeExtractorViewModel`
- [ ] 5. Autofill `simInsTime` from `spInsTime` changes (when not manually overridden)
- [ ] 6. Update all 3 save paths to use `simInsTime` (clamped ≤ spInsTime) as the stored simTime value
- [ ] 7. Update `loadFlightForEditing` to restore `simInsTime` from stored simTime
- [ ] 8. Update change detection / `buildChangeLog` to include simInsTime
- [ ] 9. Reset `simInsTime` and `simInsTimeIsManual` on flight reset
- [ ] 10. Add SIM field next to INS field in `FlightInfoCard.swift` (HStack, autofills, editable)

## Files

- `Block-Time/Models/FlightLogbook.swift`
- `Block-Time/Services/FlightDatabaseService.swift`
- `Block-Time/ViewModels/FlightTimeExtractorViewModel.swift`
- `Block-Time/Views/Components/AddFlightView/FlightInfoCard.swift`
