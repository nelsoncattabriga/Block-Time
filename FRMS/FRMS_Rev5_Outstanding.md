# FRMS Rev 5 — Outstanding Implementation Items

Last updated: 2026-06-08

## Completed
- [x] All 4 HTML reference files updated to Rev 5 (15 June 2026)
- [x] SH 2-pilot start bands corrected (0500–1259 / 1300–1759 / 1800–0459)
- [x] SH 3-pilot duty limits added to model + service (band × rest facility, planning + operational)
- [x] LNO model constants updated to Rev 5 — 40-hr/7-night cap removed; replaced with max 4 LNO duties in any 168-hr window (`lateNightMaxDutiesIn168Hours`)
- [x] Stale Rev 4.2 constants removed — `lateNightMaxConsecutiveNightsException`, `lateNightExceptionPeriodDays`, `lateNightMaxDutyHoursIn7NightPeriod`, `lateNightMaxDutyPeriodsIn7NightPeriod`
- [x] BOC 2-in-168-hours limit implemented — `backOfClockMaxDutiesIn168Hours = 2` in both model files; counted in rolling window in service; displayed in SH_NextDutyView
- [x] `LateNightStatus` struct updated — `lnoDutiesIn168Hours`/`maxLnoDutiesIn168Hours` and `bocDutiesIn168Hours`/`maxBocDutiesIn168Hours`
- [x] `SH_NextDutyView` updated — "Duty Hours (7 nights)" row replaced with "LNO Duties (168 hrs)" and "BOC Duties (168 hrs)" counts
- [x] Reserve 18-hr combined max — `reserveCombinedMaxDutyHoursOperationalNecessity = 18` in `SH_Operational_FltDuty`; surfaced via `ReserveDutyRules.combinedMaxDutyHoursOperationalNecessity`
- [x] 3-pilot TAFB-based post-pattern rest tables — `ThreePilotPatternRest` structs + `threePilotMinPostPatternRestHours()` in both `SH_Planning_FltDuty` (FD19) and `SH_Operational_FltDuty` (FD28)

---

## Outstanding

None — all Rev 5 items complete.
