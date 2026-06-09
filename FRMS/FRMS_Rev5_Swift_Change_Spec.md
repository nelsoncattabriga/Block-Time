# FRMS Revision 5 — Swift Change Spec

**For:** Block-Time (Xcode). Apply on a branch forked from `main`.
**Companion:** `FRMS_Rev5_Verified_ChangeMap.md` (every value below traces to a PDF page cited there).
**Baseline read:** the symbols/paths below are from `main` at the time of writing. Confirm against current source before editing.

**Conventions:** each item lists `File → symbol`, the current value, the Rev5 value, and the PDF reference. ⚠️ marks a structural change (not a one-line value swap).

> Note on the existing `rev5-compliance` branch: per your instruction it was **not** used as a source. This spec is derived only from the PDFs. Where it happens to agree with that branch, treat that as corroboration, not provenance.

---

## 0. Decisions locked & handoff state

**Decisions confirmed by Nelson:**
- **SH 3-pilot rest:** introduce a **dedicated SH 3-pilot rest enum** (`class2`, `businessSeat`) separate from `RestFacilityClass`, with its own picker. See §1.4 / §2.3 (the `ThreePilotRest` enum). Do **not** overload `RestFacilityClass`.
- **NZ-based crew:** model as an explicit **ruleset dimension** derived from Home Base (SH-Australia / SH-NZ / LH), not a fleet. NZ has its own cumulative-duty limits (55/95/190 h initial; 60/100 extended) and its own 2-pilot operational table. NZ Home Base option = `"NZ"`.
- **Branching:** work on `frms-v5` (forked from `main`); land as two commits — (1) Rev5 spec, (2) NZ.

**Already applied to the `frms-v5` working tree (uncommitted):**
- SH band shift in `SH_Planning_FltDuty`, `SH_Operational_FltDuty` (+ `classify()`), and `SH_NextDutyView` picker labels.
- `FRMSData`: LH `flightTimePeriodDays` 30→28; `maxFlightTime365Days` 900→1000.
- Rev5 HTML copied into `Block-Time/Resources/FRMS/` (and top-level `FRMS/`).

**Not yet applied** (the rest of this spec): SH FT removal, 3-pilot tables, reserve call-out, LNO/BOC engine; all LH model/service items; NZ (Commit 2).

**Commit environment:** the working tree edits are on disk on `frms-v5`, but commits could not be made from the Cowork sandbox (OneDrive-backed `.git` denies lock/object writes). Before committing locally: `rm -f .git/index.lock`, then review `git status`. This refactor is best continued in **Claude Code CLI on the local machine**, where git + `xcodebuild` work natively and each stage can be built/tested before the next.

---

## 1. `Block-Time/Models/SH_Planning_FltDuty.swift`

### 1.1 Duty-period start-time bands ⚠️  (FD13.1, Rev5 SH p13)
`enum LocalStartTime` and its `range` use the old band boundaries. Shift them.

| Case | Current `range` | Rev5 `range` |
|---|---|---|
| `.early` (`"0500–1459"`) | `500...1459` | **`500...1259`**, label `"0500–1259"` |
| `.afternoon` (`"1500–1959"`) | `1500...1959` | **`1300...1759`**, label `"1300–1759"` |
| `.night` (`"2000–0459"`) | `2000...2459` | **`1800...2459`**, label `"1800–0459"` |

`twoPilotDutyLimits` **values stay the same** (12/11, 11/10, 10/10) — only the bands move.

### 1.2 Remove 2-pilot flight-time limits ⚠️  (FD13.3 deleted, Rev5 SH p14)
Delete: `struct FlightTimeLimit`, `static let twoPilotFlightTimeLimits`, and `static func maxFlightTimeHours(...)`. Rev5 SH has no 2-pilot flight-time limits. (Audit all callers — see §6.)

### 1.3 Remove augmented flight-time limit  (FD13.4 deleted, Rev5 SH p14)
Delete `static let augmentedFlightTimeLimitHours: Double = 10.5`.

### 1.4 Replace augmented-crew duty model with 3-pilot table ⚠️  (FD13.1, Rev5 SH p13)
The old `augmentedDutyLimits` (16 h screened / 14 h pax) is superseded by a start-time-banded 3-pilot table (max 2 sectors), with Class 2 vs Business Seat columns:

| Local start | Class 2 | Business Seat |
|---|---|---|
| 0500–1259 | 14 | 14 |
| 1300–1759 | 14 | 13 |
| 1800–0459 | 14 | 12 |

Suggested model:
```swift
enum ThreePilotRest { case class2, businessSeat }
struct ThreePilotDutyLimit { let band: LocalStartTime; let class2: Double; let businessSeat: Double }
static let threePilotDutyLimits: [ThreePilotDutyLimit] = [
    .init(band: .early,     class2: 14, businessSeat: 14),
    .init(band: .afternoon, class2: 14, businessSeat: 13),
    .init(band: .night,     class2: 14, businessSeat: 12),
]
static let threePilotMaxSectors = 2          // planning
static let threePilotMinTotalRestHours = 2.0 // table note
```

### 1.5 Reserve call-out (NEW) ⚠️  (FD13.3–13.5, Rev5 SH p14)
`reserveDutyMaxConsecutiveHours = 12` stays (now FD13.3). Add:
```swift
static let reserveCallOutMaxCombinedHours: Double = 16   // FD13.4
// exceptions (a) augmented crew operation, (b) split duty per FD17
static let reserveNightWindowStartHHMM = 2300            // FD13.5
static let reserveNightWindowEndHHMM   = 600
```

### 1.6 Late Night Ops — replace model ⚠️  (FD14, Rev5 SH p14)
**Remove** (no longer in Rev5): `lateNightMaxConsecutiveNights (4)`, `lateNightMaxConsecutiveNightsException (5)`, `lateNightExceptionPeriodDays (28)`, `lateNightMaxDutyHoursIn7NightPeriod (40)`, `lateNightMaxDutyPeriodsIn7NightPeriod (4)`, `lateNightRecoveryMinFreeHours (24 as the old "consecutive nights" rule)`.
**Add:**
```swift
static let lnoConsecutiveTriggerCount = 2          // FD14.1 ">2 consecutive LNO"
static let lnoPostExcessFreeHours: Double = 24     // FD14.1
static let lnoMaxPeriodsIn168h = 4                 // FD14.2
static let lnoRollingWindowHours = 168             // FD14.2/14.4
static let bocMaxPeriodsIn168h = 2                 // FD14.4 (pilot may waive)
// FD14.3 — LNO/BOC caps do not apply to reserve duty periods
```
Keep `backOfClockMinutesThreshold = 120` and `backOfClockEarliestSignOnLocalHHMM = 1000` (FD14.5, pilot may waive).

### 1.7 Early starts — NO CHANGE  (FD14.6, Rev5 SH p14)
`maxConsecutiveEarlyStarts = 4` and `earlyStartSignOnThreshold = 706` are already correct. The draft note's "0700→0706" is wrong; V4.2 was already 0706. Do **not** change this value. (Only the clause number moved FD13.6 → FD14.6.)

### 1.8 Post-augmented TAFB rest table (NEW)  (FD19, Rev5 SH p16)
2-pilot FD19.1/19.2 (12 h / 15 h) unchanged. Add the 3-pilot table:
```swift
struct AugmentedPatternRest { let tafbMaxHours: Double?; let dayReturn: Double?; let multiDay: Double? }
// next duty day must be > 9.59 h where noted; refer FD14.5
static let threePilotPatternRestPlanning: [AugmentedPatternRest] = [
    .init(tafbMaxHours: 52,  dayReturn: 14.5, multiDay: 15),
    .init(tafbMaxHours: 124, dayReturn: nil,  multiDay: 22),  // 52+ to <124
    .init(tafbMaxHours: nil, dayReturn: nil,  multiDay: 32),  // 124+
]
```

---

## 2. `Block-Time/Models/SH_Operational_FltDuty.swift`

### 2.1 Start-time bands ⚠️  (FD23.1, Rev5 SH p18)
Same band shift as §1.1 in `enum LocalStartTime` — update both `range` and the `classify(signOn:homeBaseTimeZone:)` thresholds (currently hard-coded `500/1459/1500/1959`) to **`500/1259/1300/1759/1800`**. `twoPilotDutyLimits` values unchanged (14/13/12, 13/12/11, 12/12/11).

### 2.2 Remove FT limits ⚠️  (FD23.3/23.4 deleted, Rev5 SH p19)
Delete `FlightTimeLimit`, `twoPilotFlightTimeLimits`, `augmentedFlightTimeLimitHours`, and `maxFlightTimeHours(...)` — as in §1.2/§1.3.

### 2.3 3-pilot operational table (replace augmented) ⚠️  (FD23.1, Rev5 SH p18, max 3 sectors)

| Local start | Class 2 | Business Seat |
|---|---|---|
| 0500–1259 | 16 | 14.5 |
| 1300–1759 | 16 | 13.5 |
| 1800–0459 | 16 | 12.5 |

`threePilotMaxSectors = 3` (operational); min total rest 2 h.

### 2.4 Reserve call-out with 18 h exception (NEW) ⚠️  (FD23.4, Rev5 SH p19)
```swift
static let reserveCallOutMaxCombinedHours: Double = 16
static let reserveCallOutMaxCombinedHoursOpNecessity: Double = 18  // (c) operationally necessary + pilot fit
// exceptions (a) augmented, (b) split per FD27, (c) 18 h
```

### 2.5 LNO operational — mirror §1.6  (FD24.1–24.5, Rev5 SH p19)
Same replacement as planning, minus an early-start clause (operational FD24 has no FD24.6).

### 2.6 Post-augmented TAFB rest table (NEW)  (FD28, Rev5 SH p21)
```swift
// ≤52: day 12, multi 12 (or if last duty >12h: 12 + 1.5×(duty−12)); next duty >9.59
// 52+ to <124: same formula
// 124+: 22 (next duty >9.59).  Refer FD24.5.
```
Also note (lower priority, currently unmodelled): new FD28.5 (upline-port time-free recognition); FD28.4 gains consecutive-night sub-clauses; former FD28.4/28.5 renumber to FD28.6/28.7.

---

## 3. `Block-Time/Models/LH_Planning_FltDuty.swift`

### 3.1 Header metadata
`rulesetRevision = 4` → **5**; `issueDate = "26 June 2023"` → **`"15 June 2026"`**.

### 3.2 Remove 2-pilot flight-time limits ⚠️  (FD3.1, Rev5 LH p11)
`struct TwoPilotPlanningLimit` has `flightTimeLimit: Double`. Rev5 removes the FT column for 2-pilot. Either make `flightTimeLimit` optional (`Double?`) and set the four rows to `nil`, or drop the field. Duty/sector values unchanged (11 / 11 (or 12, 1-day) / 11 / 10).

### 3.3 Remove 3-pilot flight-time limits ⚠️  (FD3.1, Rev5 LH p12)
`struct ThreePilotPlanningLimit.flightTimeLimit` — same treatment. Was Class 2 = 8.5, Class 1 = 12.5. Duty values unchanged (12 / 14).

### 3.4 4-pilot column rename  (FD3.1, Rev5 LH p13)
`FourPilotPlanningLimit.flightTimeLimitNote` content is retained but is now labelled "**Inflight Management**" (rename the display label only; the 8 h continuous / 14 h total text is unchanged).

### 3.5 Relevant sectors — add Perth–Paris  (FD3.4, Rev5 LH p16)
`relevantSectors` array: append `"Perth to Paris and vice versa"`.

### 3.6 Move disruption rest out of Planning ⚠️  (FD3.4.4 → FD10.4, Rev5 LH p16/p27)
The downline-disruption rest data (`relevantSectorPreDutyRestHours`, `relevantSectorPostDutyRest`, `relevantSectorInboundAUNZRest`) is **operational** in Rev5. Keep a single source of truth in `LH_Operational_FltDuty` (§4) and have planning reference it, or remove from planning. Avoid divergent duplicates.

### 3.7 Pre-duty rest reduction — keep, reword (do NOT delete)  (FD3.2.1(c), Rev5 LH p14)
If/where the "pre-duty rest may be reduced to operational limits" provision is surfaced, change the trigger text from *pilot discretion* to *"if the pilot considers themselves physically and mentally fit for duty"*. **The provision is retained** — the draft note's "removed" is wrong.

---

## 4. `Block-Time/Models/LH_Operational_FltDuty.swift`

### 4.1 Header metadata
`rulesetRevision = 4` → **5**; `issueDate` → **`"15 June 2026"`**.

### 4.2 2-pilot table ⚠️  (FD10.1, Rev5 LH p23)
The three `DutyLimit` rows for `.twoPilot` carry `dutyPeriodLimitPlanned: 11 / dutyPeriodLimitDiscretion: 12 / flightTimeLimit: 9.5|10|10.5`. Rev5: a single 2-pilot row with **duty period limit 12** and **no flight-time limit**. Collapse to one row; set `flightTimeLimit: nil`. (The "11 planned" is a planning value; the operational limit is 12.)

### 4.3 3-pilot & 4-pilot column rename  (FD10.1, Rev5 LH p24–25)
`flightTimeLimitNote` retained as data; display label becomes "**Inflight Management**". Duty values unchanged (3-pilot 14/16/18).

### 4.4 4-pilot — add two new rest-facility combinations ⚠️  (FD10.1, Rev5 LH p25)
Extend `enum CrewRestFacility` and `fourPilotLimits`:
```swift
case oneClass2OneSeat   // "1 × Class 2 Rest & 1 × Seat in Pax"  -> 16
case oneClass1OneSeat   // "1 × Class 1 Rest & 1 × Seat in Pax"  -> 18
```
Resulting 4-pilot operational order: Seats in Pax 14; **1×Class2 & 1×Seat 16 (NEW)**; 2×Class2 16; **1×Class1 & 1×Seat 18 (NEW)**; 1×Class1 & 1×Class2 20; 2×Class1 20; 2×Class1 relevant-sectors 21 (A380 & B787 only).
Also rename `.twoClass1FD34` reference text `"FD3.4"` → `"FD10.4"`.

### 4.5 Crew-rest Class 2 aircraft: L → ALL ⚠️  (FD3.2.2/FD10.2.2, Rev5 LH p15)
`CrewRestAircraftDefinition` Class-2 entry is currently `aircraft: "A330-200L"`. Rev5 broadens it to **`"A330-200 ALL"`** (`configuration: "dedicated crew rest area at seat 5A"`). Class 1 list unchanged. (Draft note's "ALL→L narrows" is backwards.)

### 4.6 Relevant sectors + disruption rest (now FD10.4) ⚠️  (Rev5 LH p27)
- `relevantSectors`: append `"Perth to Paris and vice versa"`.
- `relevantSectorPostDutyRest`: **add** `RelevantSectorDisruptionRest(condition: "Second Officer(s)", minimumRestHours: 27, note: nil)` (FD10.4(b)(iv)).
- The "Duty Period > 18 hours" row: change `"at crew discretion"` → `"pilot considers themselves physically and mentally fit"` (FD10.4(b)(vi)).
- Add `RelevantSectorRole.secondOfficer` to the enum.
- Update references FD3.4 → FD10.4.

### 4.7 New informational sections (low priority, optional to model)
- FD10.2 "Application of Flight Duty Time Tables (Operational)" — guidance, no numeric limits (Rev5 LH p26).
- FD10.3.1 post-disruption rest: (i) operational/fit not exceeding hourly limits; (ii) 10 h, or previous duty (max 12) + 1.5×(time over 12) + timezone diff over 3 h; (iii) 24 h where duty was/planned >16 h (Rev5 LH p26).

---

## 5. `Block-Time/Models/FRMSData.swift`

### 5.1 LH flight-time period 30 → 28 days ⚠️  (FD6.2 / FD11.4, Rev5 LH p18/p28)
`flightTimePeriodDays` for `.a380A330B787` returns `30` → change to **`28`**. Update the stale comment on `maxFlightTime28Days` (`"Actually uses 30 days"`). Value stays 100 h. (SH already 28.)

### 5.2 LH 365-day flight time 900 → 1000 ⚠️  (FD11.5, Rev5 LH p28)
`maxFlightTime365Days` for `.a380A330B787` returns `900.0` → **`1000.0`**. (SH already 1000.)

### 5.3 LH roster-promulgation 365-day limit 950 (FD6.3, planning) — confirm coverage  (Rev5 LH p18)
V4.1 FD6.3 was 900; Rev5 is **950** (this is the *planning roster-promulgation* limit, distinct from the operational 1000 in §5.2). SH already models this as `SH_Planning_FltDuty.cumulativeFlightTime13BidPeriodsHours = 950`. If LH has no equivalent constant, add one (`LH_Planning_FltDuty.rosterPromulgation365DayHours = 950`) or confirm it is intentionally untracked. **Confirm with rule-owner before adding** — don't infer enforcement.

---

## 6. `Block-Time/Services/FRMSCalculationService.swift`

### 6.1 SH band classification
Any place that classifies SH sign-on into early/afternoon/night must use the new boundaries (§1.1/§2.1). If the service relies on `SH_*_FltDuty.LocalStartTime`, fixing the model covers it; verify no duplicated hard-coded `1459/1500/1959/2000` in the service.

### 6.2 Remove SH flight-time-limit usage ⚠️
The service computes/derives SH flight-time limits (the deleted `maxFlightTimeHours`, `twoPilotFlightTimeLimits`). Remove those code paths for SH so a removed limit isn't treated as `0`/violation. (LH 2-/3-pilot FT removal likewise: the LH branch around lines ~600–750 reads `limit.flightTimeLimit`; guard for `nil` / make `maxFlightTime` optional so no FT constraint is applied where Rev5 removed it.)

### 6.3 LNO/BOC engine ⚠️
The service references `SH_Planning_FltDuty.lateNightMaxConsecutiveNights`, `lateNightMaxDutyHoursIn7NightPeriod`, etc. (e.g. lines ~428, ~1300, ~1312). Replace the "4 consecutive nights / 40 h / 5-per-28" logic with Rev5: a rolling **168-hour** window counting LNO (max 4) and BOC (max 2, waivable) flying duty periods, the **>2 consecutive LNO → 24 h free** rule, and **reserve exemption** (FD14.3/24.3). `timeClass == .lateNight | .backOfClock` tagging can be reused; the counting window changes from "7 nights" to "168 hours".

### 6.4 Reserve call-out
Add combined reserve+duty limit handling (16 h; 18 h operational with fitness; SH only) and the 2300–0600 non-counting window (§1.5/§2.4). Check `ReserveDutyRules` (≈ line 1405) for where to surface it.

### 6.5 LH cumulative status strings
`status28Or30Days` prints `"\(periodDays) days"` — will read "28 days" automatically once §5.1 lands. No code change beyond §5.1.

---

## 7. Views (display only)

- `SH_NextDutyView.swift`, `LH_NextDutyView.swift`, `AdaptiveLimitLayout.swift`, `LHRestRequirementsView.swift`, `DisruptionRestSection.swift`: surface the new 3-pilot Class 2 / Business Seat columns (SH), the removal of FT-limit rows (SH+LH), the renamed "Inflight Management" column (LH), the two new 4-pilot rows (LH), and the Second Officer disruption row (LH). These follow the model changes; no rule values live here, but labels and any hard-coded band strings (`"0500–1459"` etc.) must be updated to the Rev5 bands.

---

## 8. Suggested order & tests

1. Models first: §1–§5 (data is the source of truth).
2. Service: §6 (LNO/BOC and FT-removal are the highest-risk logic changes — add unit tests).
3. Views: §7.
4. Regression tests to add: SH duty signing on 1300–1459 now returns the **mid-band** limit (11/10 planning, 13/12/11 operational), not early; SH 2-pilot/augmented FT limit lookups are gone (no false 0-hour cap); LNO/BOC counted over 168 h with reserve exempt; LH 2-/3-pilot show no FT limit; LH 28-day and 1000 h cumulative thresholds; LH relevant-sector list includes Perth–Paris and S/O 27 h.
5. Cross-check every changed value against `FRMS_Rev5_Verified_ChangeMap.md` (which carries the PDF page citations).
