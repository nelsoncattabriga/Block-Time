# Quick Task: FRMS Rev5 Remaining Items

## Goal
Fix three FRMS Rev5 view/logic items: FD2.2 timezone comment, SH 3-pilot rest picker, and LH column label rename.

## Analysis Notes

**Item 1 — FD2.2 timezone:**
`getHomeBaseTimeZone()` calls `AirportService.shared.getTimezoneOffset(for:)` which returns the **raw** (non-DST) offset from `airports.dat`. ADL (YPAD) = +9.5, BNE (YBBN) = +10, SYD (YSSY) = +10, MEL (YMML) = +10. ADL is already distinct. BNE is the same raw offset as SYD/MEL but correct (BNE has no DST, SYD/MEL do — but `getHomeBaseTimeZone` uses fixed seconds, not a named timezone, so DST is NOT applied for home base). This is a known limitation: home base uses fixed offset, not a named TZ with DST. The classify call at line 1810 passes `homeBaseTimeZone` from the same function. Comment only needed — no logic to fix.

**Item 2 — SH 3-pilot rest picker:**
`SH_NextDutyView` has no `ThreePilotRest` type or `@AppStorage` key yet. Need to add the enum, the AppStorage property, and a conditional picker. The picker must appear in both iPhone (`headerSection` compact branch) and iPad (`headerSection` non-compact branch). The displayed max duty already uses the banded model value (from `displayWindow`), so no model changes needed — the picker only captures user preference.

**Item 3a — LH column rename:**
`LH_NextDutyView` line 67: `Text("Duty & Flight Time Limits")` — this is the card title, not a column label. The column label for flight time is inside `AdaptiveLimitLayout` (label `"Max Flight Time"`). The spec rename target is the per-section column header in the 3-pilot and 4-pilot sign-on limit cards. In `LH_NextDutyView` there is no separate "3-pilot" / "4-pilot" section label — `signOnTimeRangeCard` shows the time range text, and `AdaptiveLimitLayout` shows "Max Flight Time". So the rename is in `AdaptiveLimitLayout`.

**Item 3b — AdaptiveLimitLayout label:**
`flightTimeDisplay` returns `"—"` when `getMaxFlight` returns nil (LH 3/4-pilot). The label still says "Max Flight Time". Need to rename label to "Inflight Management" for LH context and hide/omit the row for SH (where `maxFlightTime` is nil AND notes is nil). `AdaptiveLimitLayout` has no fleet context — needs a parameter. Simplest approach: add a `Bool` parameter `isLongHaul` (or use presence of notes/nil maxFlightTime as proxy). Better: add `isLongHaul: Bool` parameter and thread it from `LH_NextDutyView.signOnTimeRangeCard`. For SH the row is always "—" (nil) and has no notes, so hiding it is correct for SH.

**Item 3c — S/O 27h row:**
The model entry at index 3 has `condition: "Second Officer(s)"`, `minimumRestHours: 27`. The view iterates `postDutyRest.indices` with no filter, so the row IS rendered. The `ForEach` at line 443 renders all rows including index 3. No fix needed — already rendering correctly. Just needs verification comment in plan.

## Tasks

- [x] T1: Add clarifying comment in `FRMSCalculationService.getHomeBaseTimeZone()` confirming FD2.2 per-base compliance — note that ADL gets +9.5 (distinct from SYD/MEL +10), BNE gets +10 (same raw offset as SYD/MEL, correct since BNE has no DST), and that home base is used rather than departure port by design — `Block-Time/Services/FRMSCalculationService.swift` lines 44–61

- [x] T2: Add `enum ThreePilotRestType: String, CaseIterable` (`class2 = "Class 2"`, `businessSeat = "Business Seat"`) and `@AppStorage("frmsThreePilotRest") private var threePilotRest: ThreePilotRestType = .class2` to `SH_NextDutyView` — `Block-Time/Views/Screens/FRMS/SH_NextDutyView.swift`

- [x] T3: Add a segmented `Picker("3-Pilot Rest", selection: $threePilotRest)` in `headerSection` — appears below `limitTypePicker` in the compact (iPhone) `VStack`, and below the `limitTypePicker` in the non-compact (iPad) `HStack` — only visible when `viewModel.crewComplement == .threePilot` (or inferred complement is `.threePilot`); check how complement is surfaced in `FRMSViewModel` before wiring — `Block-Time/Views/Screens/FRMS/SH_NextDutyView.swift`

- [x] T4: Add `isLongHaul: Bool` parameter to `AdaptiveLimitLayout` (default `false`). Rename `"Max Flight Time"` label to `"Inflight Management"` when `isLongHaul == true`. Hide the flight-time row entirely when `!isLongHaul && flightTimeDisplay == "—"` (SH has no flight time limit in Rev5, row is always "—"). Thread `isLongHaul: true` from `LH_NextDutyView.signOnTimeRangeCard` — `Block-Time/Views/Screens/FRMS/AdaptiveLimitLayout.swift`, `Block-Time/Views/Screens/FRMS/LH_NextDutyView.swift`

- [x] T5: Verify S/O 27h row renders: `LH_Operational_FltDuty.relevantSectorPostDutyRest[3]` has `condition: "Second Officer(s)"`, `minimumRestHours: 27`. The `ForEach` at `LH_NextDutyView.swift` line 443 iterates all indices with no filter, so this row renders. No code change needed — add a comment `// FD10.4(b) Rev5: S/O 27h row — rendered by ForEach above, index 3` above line 443 to confirm — `Block-Time/Views/Screens/FRMS/LH_NextDutyView.swift`
