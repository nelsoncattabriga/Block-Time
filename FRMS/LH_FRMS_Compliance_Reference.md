# LH FRMS Compliance Reference — A380/A330/B787

**Source PDF:** `A380_A330_B787_FRMS_Ruleset_Revision_5-QFA-AUTO-51DFFB5E5-1-20260607-100946.pdf`
**Revision:** 5 | **Issue Date:** 15 June 2026
**Scope:** Australia-based crew — Chapter 1A (FD3, FD4–FD9, Planning) and Chapter 1B (FD10–FD14, Operational)

**Status Key:** `IMPLEMENTED` | `PARTIAL` | `NOT IMPLEMENTED` | `NOT APPLICABLE` | `NEEDS REVIEW`

---

## CHAPTER 1A — PLANNING

---

### FD3.1 — 2 Pilot Duty Period Limits and Sector Limits (Planning)

| Clause | Local Sign-On | Duty Period Limit | Sector Limit | Swift Implementation | Status |
|---|---|---|---|---|---|
| FD3.1 | 0500–0759 | 11 hrs | 1 if any sector FT > 6; otherwise 4 | `LH_Planning_FltDuty.twoPilotLimits[0]` | IMPLEMENTED |
| FD3.1 | 0800–1359 | 11 hrs | 1 if any sector FT > 6; otherwise 4 | `LH_Planning_FltDuty.twoPilotLimits[1]` | IMPLEMENTED |
| FD3.1 | 0800–1359 | 12 hrs | 1 DAY PATTERN ONLY, max 4 sectors | `LH_Planning_FltDuty.twoPilotLimits[2]` | IMPLEMENTED |
| FD3.1 | 1400–1559 | 11 hrs | 1 if any sector FT > 6; otherwise 4 | `LH_Planning_FltDuty.twoPilotLimits[3]` | IMPLEMENTED |
| FD3.1 | 1600–0459 | 10 hrs | 1 if any sector FT > 6; OR 2 if sign-on 2100–0300 LT; OR 2 if any sector FT > 2; otherwise 3 | `LH_Planning_FltDuty.twoPilotLimits[4]` | IMPLEMENTED |

#### FD3.1 — 2 Pilot Minimum Pre-Duty Rest (Planning)

| Duty Period | Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|---|
| ≤ 11 | 11 hrs | flight time ≤ 8 hrs | `LH_Planning_FltDuty.twoPilotPreDutyRest[0]` | IMPLEMENTED |
| ≤ 11 | 22 hrs | — | `LH_Planning_FltDuty.twoPilotPreDutyRest[1]` | IMPLEMENTED |
| > 11 | 11 hrs | operate ≤ 11 duty then pax to base or posting | `LH_Planning_FltDuty.twoPilotPreDutyRest[2]` | IMPLEMENTED |
| > 11 | 22 hrs | — | `LH_Planning_FltDuty.twoPilotPreDutyRest[3]` | IMPLEMENTED |

#### FD3.1 — 2 Pilot Minimum Post-Duty Rest (Planning)

Note: If next duty is solely deadheading, minimum pre-duty deadheading limits apply.

| Duty Period | Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|---|
| ≤ 11 | 11 hrs | flight time ≤ 8 hrs | `LH_Planning_FltDuty.twoPilotPostDutyRest[0]` | IMPLEMENTED |
| ≤ 11 | 22 hrs | — | `LH_Planning_FltDuty.twoPilotPostDutyRest[1]` | IMPLEMENTED |
| > 11 | 22 hrs | — | `LH_Planning_FltDuty.twoPilotPostDutyRest[2]` | IMPLEMENTED |

---

### FD3.1 — 3 Pilot Duty Period Limits and Sector Limits (Planning)

| Clause | Crew Rest Facility | Duty Period Limit | Sector Limit | Swift Implementation | Status |
|---|---|---|---|---|---|
| FD3.1 | Class 2 Rest | 12 hrs | 3 if DP > 11 hrs; otherwise max 4 | `LH_Planning_FltDuty.threePilotLimits[0]` | IMPLEMENTED |
| FD3.1 | Class 1 Rest | 14 hrs | 3 if DP > 11 hrs; otherwise max 4 | `LH_Planning_FltDuty.threePilotLimits[1]` | IMPLEMENTED |

#### FD3.1 — 3 Pilot Minimum Pre-Duty Rest (Planning)

| Duty Period | Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|---|
| ≤ 12 | 12 hrs | — | `LH_Planning_FltDuty.threePilotPreDutyRest[0]` | IMPLEMENTED |
| > 12 | 12 hrs | operate ≤ 12 duty then pax to base or posting | `LH_Planning_FltDuty.threePilotPreDutyRest[1]` | IMPLEMENTED |
| > 12 | 22 hrs | — | `LH_Planning_FltDuty.threePilotPreDutyRest[2]` | IMPLEMENTED |

#### FD3.1 — 3 Pilot Minimum Post-Duty Rest (Planning)

| Duty Period | Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|---|
| ≤ 12 | 12 hrs | flight time ≤ 9 hrs | `LH_Planning_FltDuty.threePilotPostDutyRest[0]` | IMPLEMENTED |
| ≤ 12 | 18 hrs | — | `LH_Planning_FltDuty.threePilotPostDutyRest[1]` | IMPLEMENTED |
| > 12 | 22 hrs | acclimated crew | `LH_Planning_FltDuty.threePilotPostDutyRest[2]` | IMPLEMENTED |
| > 12 | 32 hrs | — | `LH_Planning_FltDuty.threePilotPostDutyRest[3]` | IMPLEMENTED |

---

### FD3.1 — 4 Pilot Duty Period Limits (Planning)

| Crew Rest Facility | Duty Period Limit | Inflight Management | Sector Limit | Swift Implementation | Status |
|---|---|---|---|---|---|
| 2 × Class 2 Rest | 16 hrs | Max 8 hrs continuous + 14 hrs total on flight deck | ≤ 2 rostered sectors if DP > 14 hrs | `LH_Planning_FltDuty.fourPilotLimits[0]` | IMPLEMENTED |
| 1 × Class 1 & 1 × Class 2 Rest *1 | 17.5 hrs | Same | ≤ 2 rostered sectors if DP > 14 hrs | `LH_Planning_FltDuty.fourPilotLimits[1]` | IMPLEMENTED |
| 2 × Class 1 Rest | 20 hrs | Same | 1 rostered sector if DP > 16 hrs | `LH_Planning_FltDuty.fourPilotLimits[2]` | IMPLEMENTED |

*1: Priority of higher class rest facility for landing crew.

Note: **Rev 5 removed flight time limits for 2-pilot and 3-pilot LH planning operations.** No flight time limit values in `LH_Planning_FltDuty`.

#### FD3.1 — 4 Pilot Minimum Pre-Duty Rest (Planning)

| Duty Period | Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|---|
| ≤ 14 | 12 hrs | — | `LH_Planning_FltDuty.fourPilotPreDutyRest[0]` | IMPLEMENTED |
| > 14 (≤ 16) | 12 hrs | operate ≤ 14 duty then pax to base or posting | `LH_Planning_FltDuty.fourPilotPreDutyRest[1]` | IMPLEMENTED |
| > 14 (≤ 16) | 22 hrs | — | `LH_Planning_FltDuty.fourPilotPreDutyRest[2]` | IMPLEMENTED |
| > 16 | 32 hrs | within West Coast North America | `LH_Planning_FltDuty.fourPilotPreDutyRest[3]` | IMPLEMENTED |
| > 16 | 48 hrs | — | `LH_Planning_FltDuty.fourPilotPreDutyRest[4]` | IMPLEMENTED |
| — | 22 hrs | Only if prior duty was deadheading | `LH_Planning_FltDuty.fourPilotPreDutyRest[5]` | IMPLEMENTED |

#### FD3.1 — 4 Pilot Minimum Post-Duty Rest (Planning)

| Duty Period | Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|---|
| ≤ 12 | 12 hrs | flight time ≤ 9.5 hrs | `LH_Planning_FltDuty.fourPilotPostDutyRest[0]` | IMPLEMENTED |
| ≤ 12 | 18 hrs | — | `LH_Planning_FltDuty.fourPilotPostDutyRest[1]` | IMPLEMENTED |
| > 12 | 22 hrs | acclimated crew OR between two 4P duties OR next duty to base/posting + augmented + DP < 5 hrs | `LH_Planning_FltDuty.fourPilotPostDutyRest[2]` | IMPLEMENTED |
| > 12 | 32 hrs | — | `LH_Planning_FltDuty.fourPilotPostDutyRest[3]` | IMPLEMENTED |
| > 14 | 22 hrs | acclimated crew OR next duty to base/posting + augmented + DP < 5 hrs | `LH_Planning_FltDuty.fourPilotPostDutyRest[4]` | IMPLEMENTED |
| > 14 | 32 hrs | — | `LH_Planning_FltDuty.fourPilotPostDutyRest[5]` | IMPLEMENTED |
| > 16 | 22 hrs | next duty to base/posting + augmented + DP < 5 hrs | `LH_Planning_FltDuty.fourPilotPostDutyRest[6]` | IMPLEMENTED |
| > 16 | 32 hrs | within West Coast North America | `LH_Planning_FltDuty.fourPilotPostDutyRest[7]` | IMPLEMENTED |
| > 16 | 48 hrs | — | `LH_Planning_FltDuty.fourPilotPostDutyRest[8]` | IMPLEMENTED |

---

### FD3.2.1 — Rest Requirements (Application)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD3.2.1(a) | Rest = sum of rostered FT + FT between 2000–0800 LT; minimum per tables | formula | Not encoded as named constant; applied at scheduling level | NOT IMPLEMENTED |
| FD3.2.1(b) | All rest periods must include min 6 hrs within 2100–0900 LT | 6 hrs within 2100–0900 | Not encoded | NOT IMPLEMENTED |
| FD3.2.1(c) | If pilot fit, pre-duty rest may be reduced to Operational Limits (Ch 1B) | pilot discretion | Handled by `FD3.3` operational extension logic | PARTIAL |
| FD3.2.1(d)(i) | Min rest at location > 6 time zones from acclimated zone | 48 hrs | Not encoded as named constant in LH Swift files | NOT IMPLEMENTED |
| FD3.2.1(d)(ii) | London pattern exception (4-pilot, Asia slip ≥ 2 days, direct return) | 34 hrs | Not encoded | NOT IMPLEMENTED |
| FD3.2.1(e) | SIN/BKK–Europe double shuttle: mid-pattern Asia rest reduction | 22 hrs | Not encoded | NOT IMPLEMENTED |

---

### FD3.2.2 — Crew Rest Classification

| Class | Aircraft | Swift Implementation | Status |
|---|---|---|---|
| Class 1 | A380-800; B787-9; A330-300 (intl config, dedicated facility); A330-200L (intl config, mid-cabin) | `LH_Operational_FltDuty.class1Aircraft` | IMPLEMENTED |
| Class 2 | A330-200L (intl config, seat 5A) | `LH_Operational_FltDuty.class2Aircraft` | IMPLEMENTED |

---

### FD3.2.3 — Duty Limitations

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD3.2.3(a)(i) | Sign-on minimum before departure — operating | 60 min | `FRMSCalculationService` — `minutesBefore` for LH = 45 min domestic / 60 min international | NEEDS REVIEW |
| FD3.2.3(a)(ii) | Sign-on minimum before departure — deadheading (domestic AU: 45 min) | 60 min (45 min domestic) | `FRMSCalculationService` line 124: `configuration.fleet == .a380A330B787 ? 45 : 30` | NEEDS REVIEW |
| FD3.2.3(b)(i) | 2P: max 2 consecutive duties sign-on before 0600 LT | 2 | Not encoded in `LH_Planning_FltDuty` | NOT IMPLEMENTED |
| FD3.2.3(b)(ii) | 2P: max 3 consecutive duties sign-on before 0700 LT | 3 | Not encoded in `LH_Planning_FltDuty` | NOT IMPLEMENTED |
| FD3.2.3(b)(iii) | 2P: BOC duty (≥ 2 hrs between 0100–0459 LT at departure airport) → next AU flying sign-on ≥ 1000 LT | 1000 LT | Not encoded in `LH_Planning_FltDuty` (note: not same as SH BOC restriction) | NOT IMPLEMENTED |
| FD3.2.3(c)(i) | 3P: same BOC restriction as 2P above | 1000 LT | Not encoded | NOT IMPLEMENTED |
| FD3.2.3(d)(i) | Max planned pattern length — Captains and F/Os | 12 days | Not encoded | NOT IMPLEMENTED |
| FD3.2.3(d)(ii) | Max planned pattern length — Second Officers | 14 days | Not encoded | NOT IMPLEMENTED |
| FD3.2.3(d)(iii) | Max planned pattern length — Domestic patterns | 5 days | Not encoded | NOT IMPLEMENTED |
| FD3.2.3(d)(iv) | Max planned pattern length — Patterns transiting base/posting (not first/last day) | 6 days | Not encoded | NOT IMPLEMENTED |

> **NOTE on sign-on times (FD3.2.3(a)):** The PDF specifies 60 min for operating and 60 min for deadheading (45 min domestic AU). The `FRMSCalculationService` currently uses 45 min for LH international (not 60 min) and 30 min for SH. This may be incorrect for LH international operating sign-on.

---

### FD3.3 — Extending Limitations to Operational Limits

| Clause | Rule | Swift Implementation | Status |
|---|---|---|---|
| FD3.3.1 | Duty commenced: may extend to Ch 1B limits (pilot physically/mentally fit) | `FRMSConfiguration` / UI — Planning vs. Operational toggle | IMPLEMENTED |
| FD3.3.2 | Exceptional circumstances: may extend to Ch 1B limits | Handled by operational limit toggle | PARTIAL |
| FD3.3.3 | Planned recovery (home base): may extend with fatigue assessment | Handled by operational limit toggle | PARTIAL |
| FD3.3.4 | DH before duty before 0959 LT: rest may reduce to Ch 1B limits | Not explicitly modelled | NOT IMPLEMENTED |

---

### FD3.4 — Patterns > 18 Hours / Relevant Sectors (A380 & B787 Only)

| Clause | Relevant Sector | Swift Implementation | Status |
|---|---|---|---|
| FD3.4 | a) Any planned duty period > 18 hours | `LH_Planning_FltDuty.relevantSectors[0]` | IMPLEMENTED |
| FD3.4 | b) Sydney to Dallas and vice versa | `LH_Planning_FltDuty.relevantSectors[1]` | IMPLEMENTED |
| FD3.4 | c) Melbourne to Dallas and vice versa | `LH_Planning_FltDuty.relevantSectors[2]` | IMPLEMENTED |
| FD3.4 | d) Perth to London and vice versa | `LH_Planning_FltDuty.relevantSectors[3]` | IMPLEMENTED |
| FD3.4 | e) Auckland to New York and vice versa | `LH_Planning_FltDuty.relevantSectors[4]` | IMPLEMENTED |
| FD3.4 | f) Perth to Paris and vice versa *(Rev 5 new)* | `LH_Planning_FltDuty.relevantSectors[5]` | IMPLEMENTED |

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD3.4.1 | Minimum crew complement for Relevant Sectors | 4 pilots | `LH_Planning_FltDuty.relevantSectorMinimumCrew` | IMPLEMENTED |
| FD3.4.2 | MBTT increased by 1 local night after pattern including duty > 18 hrs | +1 local night | `LH_Planning_FltDuty.relevantSectorMBTTIncrease` | IMPLEMENTED |
| FD3.4.3 | Home transport provided after pattern with duty > 18 hrs | — | `LH_Planning_FltDuty.relevantSectorHomeTransport` | IMPLEMENTED |

#### FD3.4.4 — Downline Disruption Rest (Relevant Sectors)

| Condition | Min Rest | Swift Implementation | Status |
|---|---|---|---|
| (a) Prior to operating a Relevant Sector | 22 hrs | `LH_Planning_FltDuty.relevantSectorPreDutyRestHours` | IMPLEMENTED |
| (b)(i) Captain OR First Officer | 27 hrs | `LH_Planning_FltDuty.relevantSectorPostDutyRest[0]` | IMPLEMENTED |
| (b)(ii) Captain OR F/O and DP > 20 hrs | 36 hrs | `LH_Planning_FltDuty.relevantSectorPostDutyRest[1]` | IMPLEMENTED |
| (b)(iii) Captain AND First Officer | 36 hrs | `LH_Planning_FltDuty.relevantSectorPostDutyRest[2]` | IMPLEMENTED |
| (b)(iv) Second Officer(s) *(Rev 5 new)* | 27 hrs | `LH_Planning_FltDuty.relevantSectorPostDutyRest[3]` | IMPLEMENTED |
| (b)(v) If DP < 18 hrs | Ch 1B (FD10.1) applies | `LH_Planning_FltDuty.relevantSectorPostDutyRest[4]` | IMPLEMENTED |
| (b)(vi) DP > 18 hrs; pilot fit; next sector FT < 4 hrs | 24 hrs (then 36 hrs before next Relevant Sector) | `LH_Planning_FltDuty.relevantSectorPostDutyRest[5]` | IMPLEMENTED |
| (c)(i) Inbound AU/NZ; next op returns to same TZ destination | 36 hrs | `LH_Planning_FltDuty.relevantSectorInboundAUNZRest[0]` | IMPLEMENTED |
| (c)(ii) Inbound AU/NZ; next op is domestic or trans-Tasman | 22 hrs | `LH_Planning_FltDuty.relevantSectorInboundAUNZRest[1]` | IMPLEMENTED |

---

### FD4 — Duty Limitations Applicable to Deadheading (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD4.1 | Pilot won't be scheduled to DH and operate in excess of applicable duty limits | per crew complement | Enforced via `LH_Planning_FltDuty` duty limits | PARTIAL |
| FD4.2 | Max operate + DH duty period (not to base/posting) | 14.5 hrs | `LH_Planning_FltDuty.deadheadLimits[1].dutyPeriodLimit` | IMPLEMENTED |
| FD4.2 | Max operate + DH duty period (to base/posting to complete pattern) | 18 hrs | `LH_Planning_FltDuty.deadheadLimits[2].dutyPeriodLimit` | IMPLEMENTED |
| FD4.2.1 | Pilot may slip at upline port rather than DH if limits exceeded | pilot election | Not modelled | NOT APPLICABLE |
| Solely DH | Max solely deadheading duty period | 26 hrs | `LH_Planning_FltDuty.deadheadLimits[0].dutyPeriodLimit` | IMPLEMENTED |

#### Deadheading — Minimum Pre-Duty Rest (Planning)

| Duty Period | Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|---|
| ≤ 12 | 11 hrs | — | `LH_Planning_FltDuty.deadheadPreDutyRest[0]` | IMPLEMENTED |
| > 12 | 12 hrs | Pax to home base or posting | `LH_Planning_FltDuty.deadheadPreDutyRest[1]` | IMPLEMENTED |
| > 12 | 18 hrs | — | `LH_Planning_FltDuty.deadheadPreDutyRest[2]` | IMPLEMENTED |

#### Deadheading — Minimum Post-Duty Rest (Planning)

| Duty Period | Min Rest | Swift Implementation | Status |
|---|---|---|---|
| ≤ 12 | 11 hrs | `LH_Planning_FltDuty.deadheadPostDutyRest[0]` | IMPLEMENTED |
| > 12 | 18 hrs | `LH_Planning_FltDuty.deadheadPostDutyRest[1]` | IMPLEMENTED |

---

### FD5 — Standby / Ground Duty Limitations (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD5.1 | Max standby duty per scheduling period | 12 consecutive hrs | Not encoded in `LH_Planning_FltDuty` | NOT IMPLEMENTED |
| FD5.2 | Standby must have suitable sleeping accommodation; free of employment duties | — | Not encoded | NOT IMPLEMENTED |
| FD5.3 | Callout during standby: FDP begins at actual or required reporting time, whichever later | — | Not encoded | NOT IMPLEMENTED |
| FD5.4 | Callout after standby (no intervening off duty): FDP deemed to begin at end of standby | — | Not encoded | NOT IMPLEMENTED |

---

### FD6 — Cumulative Limitations (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD6.1 | After 50 hrs accumulated duty of any nature: min 24 consecutive hrs rest before next duty | 24 hrs after 50 hrs duty | Not encoded in `LH_Planning_FltDuty`; not in `FRMSData.swift` for LH | NOT IMPLEMENTED |
| FD6.2 | Max flight time in any consecutive 28 days | 100 hrs | `FRMSData.FRMSFleet.a380A330B787.maxFlightTime28Days` | IMPLEMENTED |
| FD6.3 | Max flight time in any consecutive 365 days (at roster promulgation) | **950 hrs** | `FRMSData.FRMSFleet.a380A330B787.maxFlightTime365Days` returns **900** — **BUG** | NEEDS REVIEW |
| FD6.4.2 | Max cumulative duty in any consecutive 7 days (excl. standby) | 60 hrs | `FRMSData.FRMSFleet.a380A330B787.maxDutyTime7Days` | IMPLEMENTED |
| FD6.4.3 | Max cumulative duty in any consecutive 14 days (excl. standby) | 100 hrs | `FRMSData.FRMSFleet.a380A330B787.maxDutyTime14Days` | IMPLEMENTED |
| FD6.5 | Simulator/training duty factor (trainee/support, excl. line training/checks/DH) | ×1.5 | **Not in `LH_Planning_FltDuty`** | NOT IMPLEMENTED |

#### FD6.6 — Mixed Two, Three or More Person Crew Operations (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD6.6.2 | If any portion of FDP involves < 3 pilots, 2-pilot rules apply to entire duty period | — | Not encoded | NOT IMPLEMENTED |
| FD6.6.3(a) | 2-pilot crew only: max flight time in any 7 consecutive days | 30 hrs | Not encoded | NOT IMPLEMENTED |
| FD6.6.3(b) | 2-pilot crew only: 1 duty-free period (start ≤ 2200, end ≥ 0500) in any 8 consecutive nights | 1 period per 8 nights | Not encoded | NOT IMPLEMENTED |
| FD6.6.3(c) | 3+ pilot crew only: no 7-day flight time limit | no limit | Not encoded | NOT IMPLEMENTED |
| FD6.6.3(d)(i) | Mixed crew; next flight as 2-pilot: max 30 hrs in 7 days | 30 hrs | Not encoded | NOT IMPLEMENTED |
| FD6.6.3(d)(ii) | Mixed crew; next flight as 3+ pilot: max 40 hrs in 7 days | 40 hrs | Not encoded | NOT IMPLEMENTED |

---

### FD7 — Measurement of Duty Time

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD7.1.1 | Scheduled FDP: begins at required reporting time; ends 30 min after scheduled blocks-on | 30 min post blocks | `FRMSDuty.signOff` calculated in `FRMSCalculationService` | PARTIAL |
| FD7.1.2 | Actual FDP: begins at actual or required reporting (whichever later); ends 30 min after actual blocks-on; may reduce to 15 min at crew discretion | 30 min (or 15 min) | `FRMSCalculationService` — sign-off calculation | PARTIAL |
| FD7.2.1/2 | Deadhead duty: same 30/15 min block-time rules | 30 / 15 min | Applied in duty calculations | PARTIAL |
| FD7.3.1/2 | Standby duty: begins at required availability time; ends at release or planned end | — | Not explicitly encoded for LH | NOT IMPLEMENTED |
| FD7.3.3/4 | Callout cancelled: return to standby; if before 0730, next duty calculated from cancelled sign-on | 0730 threshold | Not encoded | NOT IMPLEMENTED |
| FD7.4.1/2 | Ground duty: begins at reporting time; ends at actual release | — | Not encoded | NOT IMPLEMENTED |

---

### FD8 — Minimum Off Duty Periods En Route (Planning)

| Clause | Rule | Swift Implementation | Status |
|---|---|---|---|
| FD8.1 | Factors for grouping flights into patterns (qualitative — 7 factors) | Informational / scheduling guidance only | NOT APPLICABLE |
| FD8.2 | Irregular charter/special flights may use Ch 1B limits with fatigue assessment and crew discretion | Handled by operational toggle | PARTIAL |
| FD8.3 | Exceptional circumstances: minimum off duty may reduce to Ch 1B limits at pilot discretion | Handled by operational toggle | PARTIAL |

---

### FD9 — Minimum Base Turnaround Time (Planning)

| Clause | Condition | MBTT | Swift Implementation | Status |
|---|---|---|---|---|
| FD9.3(a) | Pattern of 1 day away | 12 hrs | `FRMSMinimumBaseTurnaroundTime` struct exists; no static table in `LH_Planning_FltDuty` | NOT IMPLEMENTED |
| FD9.3(b) | Pattern of 2–4 days away | 1 local night | (same) | NOT IMPLEMENTED |
| FD9.3(c) | Credited FT of pattern > 20 hrs | 2 local nights | (same) | NOT IMPLEMENTED |
| FD9.3(d) | Pattern of 5–8 days away | 2 local nights | (same) | NOT IMPLEMENTED |
| FD9.3(e) | Credited FT of pattern > 40 hrs | 3 local nights | (same) | NOT IMPLEMENTED |
| FD9.3(f) | Pattern of 9–12 days away | 3 local nights | (same) | NOT IMPLEMENTED |
| FD9.3(g) | Credited FT > 60 hrs or days > 12 | 4 local nights | (same) | NOT IMPLEMENTED |
| FD9.3(h)(i) | Excess 100 hrs/30 days up to 5 hrs excess | +1 local night | (same) | NOT IMPLEMENTED |
| FD9.3(h)(ii) | Excess 100 hrs/30 days ≥ 5 hrs excess | +2 local nights | (same) | NOT IMPLEMENTED |
| FD9.4 | Additional MBTT for Relevant Sector pattern (FD3.4.2) | +1 local night | `LH_Planning_FltDuty.relevantSectorMBTTIncrease` | IMPLEMENTED |
| FD9.5 | Max MBTT (except FD9.3(h)) | 4 local nights | Not encoded | NOT IMPLEMENTED |

---

## CHAPTER 1B — OPERATIONAL

---

### FD10.1 — 2 Pilot Duty Period Limits (Operational)

| Clause | Local Sign-On | Duty Period Limit | Swift Implementation | Status |
|---|---|---|---|---|
| FD10.1 | ALL | 12 hrs | `LH_Operational_FltDuty.twoPilotLimits[0].dutyPeriodLimitPlanned` | IMPLEMENTED |

Note: **Rev 5 removed flight time limits for 2-pilot LH operational.** No flight time limit value.

#### FD10.1 — 2 Pilot Minimum Pre-Duty Rest (Operational)

| Duty Period | Min Rest | Swift Implementation | Status |
|---|---|---|---|
| ≤ 11 | 10 hrs | `LH_Operational_FltDuty.twoPilotPreDutyRest[0]` | IMPLEMENTED |
| > 11 | 12 hrs | `LH_Operational_FltDuty.twoPilotPreDutyRest[1]` | IMPLEMENTED |
| Within 7 days | 1 continuous period embracing 2200 and 0600 on 2 consecutive nights | `LH_Operational_FltDuty.twoPilotPreDutyRest[2]` | IMPLEMENTED |

#### FD10.1 — 2 Pilot Minimum Post-Duty Rest (Operational)

| Duty Period / Flight Time | Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|---|
| ≤ 11 | 10 hrs | — | `LH_Operational_FltDuty.twoPilotPostDutyRest[0]` | IMPLEMENTED |
| DP > 11 OR FT > 8 (extension beyond planned DP) | 10 + 1 hr per 15 min (or part) TOD exceeded 11 hrs | If next duty includes operating sectors; if solely DH, 12 hrs only | `LH_Operational_FltDuty.twoPilotPostDutyRest[1]` | IMPLEMENTED |
| DP > 12 OR FT > 9 (extension beyond planned DP) | 24 hrs | — | `LH_Operational_FltDuty.twoPilotPostDutyRest[2]` | IMPLEMENTED |

**Footnote *1 — Consecutive duties rule (FD10.1):** If pilot completes 2 consecutive duty periods with aggregate > 8 hrs FT or > 11 hrs duty, AND intervening rest < 12 hrs embracing 2200–0600 (or < 24 hrs consecutive), pilot must have ≥ 12 hrs embracing 2200–0600 or ≥ 24 hrs before further duty.

| Rule | Swift Implementation | Status |
|---|---|---|
| Consecutive duties footnote | `LH_Operational_FltDuty.twoPilotConsecutiveDutyNote` (text only) | PARTIAL |

---

### FD10.2 — 3 Pilot Duty Period Limits (Operational)

| Crew Rest Facility | Duty Period Limit | Inflight Management | Requirements | Swift Implementation | Status |
|---|---|---|---|---|---|
| Seat in Passenger Compartment | 14 hrs | 8 consecutive hrs of active duty | — | `LH_Operational_FltDuty.threePilotLimits[0]` | IMPLEMENTED |
| Class 2 Rest | 16 hrs | Max 8 hrs continuous + 14 hrs total on flight deck | ≤ 2 sectors if DP scheduled > 14 hrs | `LH_Operational_FltDuty.threePilotLimits[1]` | IMPLEMENTED |
| Class 1 Rest | 18 hrs | Same | ≤ 2 sectors if DP scheduled > 14 hrs | `LH_Operational_FltDuty.threePilotLimits[2]` | IMPLEMENTED |

Note: **Rev 5 removed flight time limits for 3-pilot LH operational.** No flight time limit value.

#### FD10.2 — 3 Pilot Minimum Pre-Duty Rest (Operational)

| Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|
| 10 hrs | If 12 hrs rest rostered between 2 consecutive duties AND first duty ≤ 11 hrs AND total of both ≤ 24 hrs | `LH_Operational_FltDuty.threePilotPreDutyRest[0]` | IMPLEMENTED |
| 12 hrs | Standard | `LH_Operational_FltDuty.threePilotPreDutyRest[1]` | IMPLEMENTED |

#### FD10.2 — 3 Pilot Minimum Post-Duty Rest (Operational)

| Duty Period | Min Rest | Swift Implementation | Status |
|---|---|---|---|
| ≤ 16 | 12 hrs | `LH_Operational_FltDuty.threePilotPostDutyRest[0]` | IMPLEMENTED |
| > 16 | 24 hrs | `LH_Operational_FltDuty.threePilotPostDutyRest[1]` | IMPLEMENTED |

---

### FD10.2 — 4 Pilot Duty Period Limits (Operational)

| Crew Rest Facility | Duty Period Limit | Inflight Management | Requirements | Swift Implementation | Status |
|---|---|---|---|---|---|
| Seats in Passenger Compartment | 14 hrs | 8 consecutive hrs active duty | — | `LH_Operational_FltDuty.fourPilotLimits[0]` | IMPLEMENTED |
| 1 × Class 2 *1 & 1 × Seat | 16 hrs | Max 8 continuous + 14 total on deck | ≤ 2 sectors if DP > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[1]` | IMPLEMENTED |
| 2 × Class 2 Rest | 16 hrs | Same | ≤ 2 sectors if DP > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[2]` | IMPLEMENTED |
| 1 × Class 1 *1 & 1 × Seat | 18 hrs | Same | ≤ 2 sectors if DP > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[3]` | IMPLEMENTED |
| 1 × Class 1 & 1 × Class 2 *1 | 20 hrs | Same | ≤ 2 sectors if DP > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[4]` | IMPLEMENTED |
| 2 × Class 1 Rest | 20 hrs | Same | ≤ 2 sectors if DP > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[5]` | IMPLEMENTED |
| 2 × Class 1 REST — Relevant Sectors (FD10.4) | **21 hrs** (A380 & B787 only) | Same | — | `LH_Operational_FltDuty.fourPilotLimits[6]` | IMPLEMENTED |

*1: Priority of higher class rest facility for landing crew.

#### FD10.2 — 4 Pilot Minimum Pre-Duty Rest (Operational)

| Min Rest | Requirement | Swift Implementation | Status |
|---|---|---|---|
| 10 hrs | If 12 hrs rest rostered between 2 consecutive duties AND first duty ≤ 11 hrs AND total ≤ 24 hrs | `LH_Operational_FltDuty.fourPilotPreDutyRest[0]` | IMPLEMENTED |
| 12 hrs | Standard | `LH_Operational_FltDuty.fourPilotPreDutyRest[1]` | IMPLEMENTED |
| > 18 hrs (Relevant Sector) | Refer to FD10.4 disruption limits | `LH_Operational_FltDuty.fourPilotPreDutyRest[2]` (reference row) | IMPLEMENTED |

#### FD10.2 — 4 Pilot Minimum Post-Duty Rest (Operational)

| Duty Period | Min Rest | Swift Implementation | Status |
|---|---|---|---|
| ≤ 16 | 12 hrs | `LH_Operational_FltDuty.fourPilotPostDutyRest[0]` | IMPLEMENTED |
| > 16 | 24 hrs | `LH_Operational_FltDuty.fourPilotPostDutyRest[1]` | IMPLEMENTED |
| > 18 hrs (Relevant Sector) | Refer to FD10.4 disruption limits | `LH_Operational_FltDuty.fourPilotPostDutyRest[2]` (reference row) | IMPLEMENTED |

---

### FD10.3.1 — Rest Requirements (Application, Operational)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD10.3.1(a)(i) | Disruption after pattern commenced: min rest per Ch 1B or pilot discretion options (ii)/(iii) | per FD10.1 | Handled by operational limit toggle | PARTIAL |
| FD10.3.1(a)(ii) | Disruption rest option: 10 hrs + formula for TZ shift > 3 hrs from first departure point + previous DP contribution | formula | Not encoded as named constant | NOT IMPLEMENTED |
| FD10.3.1(a)(iii) | Disruption: 24 hrs pre and post if DP was planned or actual > 16 hrs | 24 hrs | Not encoded as named constant | NOT IMPLEMENTED |

---

### FD10.3.2 — Crew Rest Classification (Operational)

Same as FD3.2.2 — see above. Implemented in `LH_Operational_FltDuty.class1Aircraft` and `class2Aircraft`.

---

### FD10.4 — Relevant Sectors (Operational)

Identical to FD3.4 — same 6 routes, same disruption rest table.

| Clause | Relevant Sector | Swift Implementation | Status |
|---|---|---|---|
| FD10.4(a–f) | All 6 routes (including Perth–Paris, Rev 5 new) | `LH_Operational_FltDuty.relevantSectors` | IMPLEMENTED |
| FD10.4(a) | Pre-Relevant Sector rest | 22 hrs | `LH_Operational_FltDuty.relevantSectorPreDutyRestHours` | IMPLEMENTED |
| FD10.4(b)(i–vi) | Post-Relevant Sector disruption rest (all conditions) | 27/36/24 hrs | `LH_Operational_FltDuty.relevantSectorPostDutyRest` | IMPLEMENTED |
| FD10.4(c)(i–ii) | Inbound AU/NZ rest | 36 / 22 hrs | `LH_Operational_FltDuty.relevantSectorInboundAUNZRest` | IMPLEMENTED |

---

### FD11 — Cumulative Limitations (Operational)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD11.1 | Max total duty in each fortnight for 2-pilot operations | 90 hrs | Not encoded in LH Swift files (FRMSData has no LH-specific fortnightly limit) | NOT IMPLEMENTED |
| FD11.2 | After 50 hrs duty (3 or 4 pilot): min 24 consecutive hrs rest | 24 hrs after 50 hrs | Not encoded | NOT IMPLEMENTED |
| FD11.3 | Max flight time in any consecutive 7 days (2-pilot operations only) | 30 hrs | `FRMSData.FRMSFleet.a380A330B787.maxFlightTime7Days` = 30.0 | IMPLEMENTED |
| FD11.4 | Max flight time in any consecutive 28 days | 100 hrs | `FRMSData.FRMSFleet.a380A330B787.maxFlightTime28Days` | IMPLEMENTED |
| FD11.5 | Max flight time in any consecutive 365 days (operational hard cap) | **1,000 hrs** | `FRMSData.FRMSFleet.a380A330B787.maxFlightTime365Days` = **900** — **BUG** | NEEDS REVIEW |

> **CRITICAL BUG — FD6.3 vs FD11.5:** There are two distinct 365-day limits:
> - **FD6.3 (Planning):** 950 hrs — applies at roster promulgation
> - **FD11.5 (Operational):** 1,000 hrs — hard operational cap
> 
> `FRMSData.swift` returns **900 hrs** for `FRMSFleet.a380A330B787.maxFlightTime365Days`. This is wrong for both limits. The app should use 1,000 hrs as the operational cap (what the cumulative card displays), and ideally also flag at 950 hrs as a roster-promulgation warning. Fix: change `return 900.0` to `return 1000.0` for LH in `FRMSFleet.maxFlightTime365Days`.

#### FD11.6 — Mixed Two, Three or More Person Crew Operations (Operational)

Same structure as FD6.6 (Planning).

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD11.6.2 | If any FDP portion < 3 pilots, 2-pilot rules apply to entire duty | — | Not encoded | NOT IMPLEMENTED |
| FD11.6.3(a) | 2-pilot only: max 30 hrs flight time in any 7 consecutive days | 30 hrs | Not encoded | NOT IMPLEMENTED |
| FD11.6.3(b) | 2-pilot only: 1 duty-free period per 8 consecutive nights (2200–0500 window) | 1 period per 8 nights | Not encoded | NOT IMPLEMENTED |
| FD11.6.3(c) | 3+ pilot only: no 7-day FT limit | no limit | Not encoded | NOT IMPLEMENTED |
| FD11.6.3(d)(i) | Mixed; next as 2-pilot: max 30 hrs | 30 hrs | Not encoded | NOT IMPLEMENTED |
| FD11.6.3(d)(ii) | Mixed; next as 3+ pilot: max 40 hrs | 40 hrs | Not encoded | NOT IMPLEMENTED |

---

### FD12 — Standby / Ground Duty Limitations (Operational)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD12.1 | Max standby duty | 12 consecutive hrs | Not encoded in `LH_Operational_FltDuty` | NOT IMPLEMENTED |
| FD12.2 | Standby must have sleeping accommodation; free of employment duties | — | Not encoded | NOT IMPLEMENTED |
| FD12.3 | Callout from standby: duty period must be decreased by hrs reserve exceeded 12 hrs | — | Not encoded | NOT IMPLEMENTED |
| FD12.4 | Callout during standby: FDP begins at actual or required reporting time, whichever later | — | Not encoded | NOT IMPLEMENTED |
| FD12.5 | Callout after standby: FDP deemed to begin at end of standby | — | Not encoded | NOT IMPLEMENTED |

---

### FD13 — Simulator Roster Limitations

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD13.1 | Simulator planning: use Ch 1A (FD3) 2-pilot planning limits | per FD3 | Referenced but not enforced in Swift | NOT IMPLEMENTED |
| FD13.2 | Simulator then DH to base within same duty: max duty period | 14.5 hrs | Not encoded in `LH_Operational_FltDuty` | NOT IMPLEMENTED |
| FD13.3(a) | TRE A/B: max 1 rostered duty per calendar day (meeting exception allowed) | — | Not encoded | NOT IMPLEMENTED |
| FD13.3(b) | TRE A/B: no 2 consecutive late-night sessions (start < 0700 or end > 2300) | 0700 / 2300 | Not encoded | NOT IMPLEMENTED |
| FD13.3(c) | TRE A/B: min MBTT of 12 hrs after duty (unless agreed) | 12 hrs | Not encoded | NOT IMPLEMENTED |

---

### FD14 — Rest Requirement Flowcharts (Appendix)

| Clause | Rule | Swift Implementation | Status |
|---|---|---|---|
| FD14.1.1 | 3/4 Pilot TOD rest flowchart (complex conditional logic) | Partially captured in `LH_Operational_FltDuty` rest tables; flowchart logic not fully implemented | PARTIAL |
| FD14.1.2 | 2 Pilot TOD rest flowchart (complex conditional logic including consecutive duties rule) | Core rest values in `twoPilotPostDutyRest`; full flowchart branching not implemented | PARTIAL |

---

## Known Gaps and Discrepancies

1. **CRITICAL — LH 365-day flight time limit (`FRMSData.swift`):** Returns 900 hrs for LH. PDF specifies 950 hrs (planning/FD6.3) and 1,000 hrs (operational/FD11.5). The displayed cumulative card limit should be **1,000 hrs** (operational cap). Change `FRMSFleet.a380A330B787` case in `maxFlightTime365Days` from 900 to 1,000.

2. **FD6.3 Planning 950-hr limit:** Should ideally be a separate warning threshold (at roster promulgation). Currently not surfaced at all for LH.

3. **FD6.1 / FD11.2 — 50-hour accumulated duty rule:** After 50 hrs of any duty, 24 hrs rest required. Not encoded for LH. The SH fleet does not have this rule; it is LH-specific.

4. **FD3.2.3(b)/(c) — Consecutive early/BOC duty restrictions (2P and 3P):** Max 2 consecutive duties before 0600, max 3 before 0700, and BOC 1000 LT restriction — not encoded in any LH Swift file.

5. **FD3.2.3(a) — Sign-on lead time for LH international:** PDF says 60 min for operating. `FRMSCalculationService` uses 45 min for LH. Review and correct if needed.

6. **FD5 / FD12 — Standby rules:** Entirely absent from LH Swift files.

7. **FD6.5 / FD11 — 1.5× sim factor:** Not encoded in LH Swift files (exists in SH only).

8. **FD6.6 / FD11.6 — Mixed crew operations:** Entirely absent from implementation. The 30/40/7-day limits and 2-consecutive-nights alternative are significant operational rules.

9. **FD9 — MBTT table:** `FRMSMinimumBaseTurnaroundTime` struct exists in `FRMSData.swift` but no static MBTT values are encoded in `LH_Planning_FltDuty.swift`. Only the Relevant Sector +1 night rule is implemented.

10. **FD3.2.1(d) — Acclimated zone rest (48/34 hrs):** Not encoded.

11. **FD11.1 — 2-pilot fortnightly duty cap (90 hrs):** Not encoded for LH operational. The 100-hr/14-day cap is encoded but not the 90-hr/fortnight cap specific to 2-pilot LH operational.

12. **FRMSData.swift header comment:** States "Rev 4.1 (A320/B737) and Rev 4 (A380/A330/B787)" — stale, should read Rev 5 (15 June 2026) for both.

---

*Last updated: 2026-06-08 | Source: QF FRMS Ruleset A380/A330/B787 Rev 5, 15 June 2026*
