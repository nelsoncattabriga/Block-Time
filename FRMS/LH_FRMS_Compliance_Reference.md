# LH FRMS Compliance Reference
## A380 / A330 / B787 — Revision 5 (15 June 2026)

**Status vocabulary**
- `IMPLEMENTED` — rule is encoded in Swift and used in calculations
- `PARTIAL` — partially implemented; gap noted
- `NOT IMPLEMENTED` — not yet in code
- `OUT OF SCOPE` — scheduling/roster rule the app cannot check from flight logs
- `HTML DOCS ONLY` — displayed in the in-app HTML reference but not tracked in code

---

## FD1–FD2 | Sign-On / Sign-Off

### FD3.2.3 Sign-On (Operating)
| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Operating crew: 60 min before STD | FD3.2.3 | `FRMSCalculationService.calculateSignOn` — `configuration.signOnMinutesBeforeSTD` defaults to 60 | `IMPLEMENTED` |
| Deadheading domestic AU (LH): 45 min before STD | FD3.2.3 | `calculateSignOn` — overrides to 45 min when `isPositioning && isAU && fleet == .a380A330B787` | `IMPLEMENTED` |
| SIM: 45 min before start | Operational convention | `calculateSignOn(isSim:true)` — hardcoded 45 min | `IMPLEMENTED` |

### FD7.1.1 / FD7.2.1 Sign-Off
| Rule | PDF | Code | Status |
|------|-----|------|--------|
| All sectors (LH): 30 min after actual IN | FD7.1.1/7.2.1 | `FRMSConfiguration.signOffMinutesAfterIN` defaults to 30 for `.a380A330B787` | `IMPLEMENTED` |
| SIM: 30 min after end | Operational convention | `calculateSignOff(isSim:true)` — hardcoded 30 min | `IMPLEMENTED` |

---

## FD3 | Chapter 1A — Planning Limits

### FD3.1 Flight & Duty Time Limits (Planning) — 2 Pilot

| Sign-On Window | Max Duty (hrs) | Sector Limit | Code | Status |
|----------------|---------------|--------------|------|--------|
| 0500–0759 | 11 | 1 if any sector FT > 6, otherwise 4 | `LH_Planning_FltDuty.twoPilotLimits[0]` | `IMPLEMENTED` |
| 0800–1359 (standard) | 11 | 1 if any sector FT > 6, otherwise 4 | `LH_Planning_FltDuty.twoPilotLimits[1]` | `IMPLEMENTED` |
| 0800–1359 (1 day pattern only) | 12 | 1 DAY PATTERN ONLY, max 4 sectors | `LH_Planning_FltDuty.twoPilotLimits[2]` | `IMPLEMENTED` |
| 1400–1559 | 11 | 1 if any sector FT > 6, otherwise 4 | `LH_Planning_FltDuty.twoPilotLimits[3]` | `IMPLEMENTED` |
| 1600–0459 | 10 | 1 if FT > 6; 2 if sign-on 2100–0300 LT; 2 if FT > 2, otherwise 3 | `LH_Planning_FltDuty.twoPilotLimits[4]` | `IMPLEMENTED` |

**Note (Rev 5):** Flight time limits have been removed from LH Planning (FD3.1). The code correctly sets `maxFlightTime: nil` for planning rows in `getSignOnBasedLimits2PilotA380A330B787`.

#### 2 Pilot — Minimum Pre-Duty Rest (Planning) — FD3.1
| Duty Period | Min Rest (hrs) | Condition | Code | Status |
|-------------|---------------|-----------|------|--------|
| ≤ 11 | 11 | Flight time < 8 | `LH_Planning_FltDuty.twoPilotPreDutyRest[0]` | `IMPLEMENTED` |
| ≤ 11 | 22 | — | `LH_Planning_FltDuty.twoPilotPreDutyRest[1]` | `IMPLEMENTED` |
| > 11 | 11 | Operate ≤ 11 duty then pax to base or posting | `LH_Planning_FltDuty.twoPilotPreDutyRest[2]` | `IMPLEMENTED` |
| > 11 | 22 | — | `LH_Planning_FltDuty.twoPilotPreDutyRest[3]` | `IMPLEMENTED` |

#### 2 Pilot — Minimum Post-Duty Rest (Planning) — FD3.1
| Duty Period | Min Rest (hrs) | Condition | Code | Status |
|-------------|---------------|-----------|------|--------|
| ≤ 11 | 11 | Flight time < 8 | `LH_Planning_FltDuty.twoPilotPostDutyRest[0]` | `IMPLEMENTED` |
| ≤ 11 | 22 | — | `LH_Planning_FltDuty.twoPilotPostDutyRest[1]` | `IMPLEMENTED` |
| > 11 | 22 | — | `LH_Planning_FltDuty.twoPilotPostDutyRest[2]` | `IMPLEMENTED` |

Note: If the next duty period is solely deadheading, the minimum pre-duty deadheading limits apply.

---

### FD3.1 Flight & Duty Time Limits (Planning) — 3 Pilot

| Crew Rest Facility | Max Duty (hrs) | Sector Limit | Code | Status |
|-------------------|---------------|--------------|------|--------|
| Class 2 Rest | 12 | 3 if DP > 11, otherwise max 4 | `LH_Planning_FltDuty.threePilotLimits[0]` | `IMPLEMENTED` |
| Class 1 Rest | 14 | 3 if DP > 11, otherwise max 4 | `LH_Planning_FltDuty.threePilotLimits[1]` | `IMPLEMENTED` |

#### 3 Pilot — Minimum Pre-Duty Rest (Planning) — FD3.1
| Duty Period | Min Rest (hrs) | Condition | Code | Status |
|-------------|---------------|-----------|------|--------|
| ≤ 12 | 12 | — | `LH_Planning_FltDuty.threePilotPreDutyRest[0]` | `IMPLEMENTED` |
| > 12 | 12 | Operate ≤ 12 duty then pax to base or posting | `LH_Planning_FltDuty.threePilotPreDutyRest[1]` | `IMPLEMENTED` |
| > 12 | 22 | — | `LH_Planning_FltDuty.threePilotPreDutyRest[2]` | `IMPLEMENTED` |

#### 3 Pilot — Minimum Post-Duty Rest (Planning) — FD3.1
| Duty Period | Min Rest (hrs) | Condition | Code | Status |
|-------------|---------------|-----------|------|--------|
| ≤ 12 | 12 | Flight time < 9 | `LH_Planning_FltDuty.threePilotPostDutyRest[0]` | `IMPLEMENTED` |
| ≤ 12 | 18 | — | `LH_Planning_FltDuty.threePilotPostDutyRest[1]` | `IMPLEMENTED` |
| > 12 | 22 | Acclimated crew | `LH_Planning_FltDuty.threePilotPostDutyRest[2]` | `IMPLEMENTED` |
| > 12 | 32 | — | `LH_Planning_FltDuty.threePilotPostDutyRest[3]` | `IMPLEMENTED` |

Note: If the next duty period is solely deadheading, the minimum pre-duty deadheading limits apply.

---

### FD3.1 Flight & Duty Time Limits (Planning) — 4 Pilot

| Crew Rest Facility | Max Duty (hrs) | Inflight Management | Sector Limit | Code | Status |
|-------------------|---------------|---------------------|--------------|------|--------|
| 2 × Class 2 Rest | 16 | Max 8 hrs continuous & 14 hrs total on flight deck | ≤ 2 rostered sectors if DP scheduled > 14 hrs | `LH_Planning_FltDuty.fourPilotLimits[0]` | `IMPLEMENTED` |
| 1 × Class 1 & 1 × Class 2 Rest *1 | 17.5 | Max 8 hrs continuous & 14 hrs total on flight deck | ≤ 2 rostered sectors if DP scheduled > 14 hrs | `LH_Planning_FltDuty.fourPilotLimits[1]` | `IMPLEMENTED` |
| 2 × Class 1 Rest | 20 | Max 8 hrs continuous & 14 hrs total on flight deck | 1 rostered sector if DP scheduled > 16 hrs | `LH_Planning_FltDuty.fourPilotLimits[2]` | `IMPLEMENTED` |

*1: Consideration to be given to management of mixed crew rest facilities with priority of the higher class for landing crew.

#### 4 Pilot — Minimum Pre-Duty Rest (Planning) — FD3.1
| Duty Period | Min Rest (hrs) | Condition | Code | Status |
|-------------|---------------|-----------|------|--------|
| ≤ 14 | 12 | — | `LH_Planning_FltDuty.fourPilotPreDutyRest[0]` | `IMPLEMENTED` |
| > 14 ≤ 16 | 12 | Operate ≤ 14 duty then pax to base or posting | `LH_Planning_FltDuty.fourPilotPreDutyRest[1]` | `IMPLEMENTED` |
| > 14 ≤ 16 | 22 | — | `LH_Planning_FltDuty.fourPilotPreDutyRest[2]` | `IMPLEMENTED` |
| > 16 | 32 | Within West Coast North America | `LH_Planning_FltDuty.fourPilotPreDutyRest[3]` | `IMPLEMENTED` |
| > 16 | 48 | — | `LH_Planning_FltDuty.fourPilotPreDutyRest[4]` | `IMPLEMENTED` |
| > 16 | 22 | Prior duty was deadheading only | `LH_Planning_FltDuty.fourPilotPreDutyRest[5]` | `IMPLEMENTED` |

#### 4 Pilot — Minimum Post-Duty Rest (Planning) — FD3.1
| Duty Period | Min Rest (hrs) | Condition | Code | Status |
|-------------|---------------|-----------|------|--------|
| ≤ 12 | 12 | Flight time ≤ 9.5 | `LH_Planning_FltDuty.fourPilotPostDutyRest[0]` | `IMPLEMENTED` |
| ≤ 12 | 18 | — | `LH_Planning_FltDuty.fourPilotPostDutyRest[1]` | `IMPLEMENTED` |
| > 12 | 22 | Acclimated crew OR between two 4-pilot duties OR next duty to home base/posting, augmented crew, DP < 5 hrs | `LH_Planning_FltDuty.fourPilotPostDutyRest[2]` | `IMPLEMENTED` |
| > 12 | 32 | — | `LH_Planning_FltDuty.fourPilotPostDutyRest[3]` | `IMPLEMENTED` |
| > 14 | 22 | Acclimated crew OR next duty to home base/posting, augmented crew, DP < 5 hrs | `LH_Planning_FltDuty.fourPilotPostDutyRest[4]` | `IMPLEMENTED` |
| > 14 | 32 | — | `LH_Planning_FltDuty.fourPilotPostDutyRest[5]` | `IMPLEMENTED` |
| > 16 | 22 | Next duty to home base/posting, augmented crew, DP < 5 hrs | `LH_Planning_FltDuty.fourPilotPostDutyRest[6]` | `IMPLEMENTED` |
| > 16 | 32 | Within West Coast North America | `LH_Planning_FltDuty.fourPilotPostDutyRest[7]` | `IMPLEMENTED` |
| > 16 | 48 | — | `LH_Planning_FltDuty.fourPilotPostDutyRest[8]` | `IMPLEMENTED` |

Note: If the next duty period is solely deadheading, the minimum pre-duty deadheading limits apply.

---

### FD3.1 Deadheading (Planning)

| Duty Type | Max Duty (hrs) | Sector Limit | Code | Status |
|-----------|---------------|--------------|------|--------|
| Solely deadhead | 26 | 2 | `LH_Planning_FltDuty.deadheadLimits[0]` | `IMPLEMENTED` |
| Operate then deadhead (not to home base/posting) | 14.5 | Additional paxing sector above operate-only limit | `LH_Planning_FltDuty.deadheadLimits[1]` | `IMPLEMENTED` |
| Operate then deadhead (to home base/posting) | 18 | Additional paxing sector above operate-only limit | `LH_Planning_FltDuty.deadheadLimits[2]` | `IMPLEMENTED` |

#### Deadheading — Minimum Pre-Duty Rest (Planning)
| Duty Period | Min Rest (hrs) | Condition | Code | Status |
|-------------|---------------|-----------|------|--------|
| ≤ 12 | 11 | — | `LH_Planning_FltDuty.deadheadPreDutyRest[0]` | `IMPLEMENTED` |
| > 12 | 12 | Pax to base or posting | `LH_Planning_FltDuty.deadheadPreDutyRest[1]` | `IMPLEMENTED` |
| > 12 | 18 | — | `LH_Planning_FltDuty.deadheadPreDutyRest[2]` | `IMPLEMENTED` |

Note: Solely deadhead only. Any duty involving operating — the 2, 3 or 4 Pilot limits apply.

#### Deadheading — Minimum Post-Duty Rest (Planning)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 12 | 11 | `LH_Planning_FltDuty.deadheadPostDutyRest[0]` | `IMPLEMENTED` |
| > 12 | 18 | `LH_Planning_FltDuty.deadheadPostDutyRest[1]` | `IMPLEMENTED` |

---

### FD3.4 Relevant Sectors — Patterns > 18 Hours (A380 & B787 Only) — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `lh_frms_planning_limits.html`. Not currently tracked by the app from flight data alone.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Minimum crew = 4 pilots | FD3.4.1 | `LH_Planning_FltDuty.relevantSectorMinimumCrew = 4` | `IMPLEMENTED` (data only) |
| MBTT increased by 1 local night | FD3.4.2 | `LH_Planning_FltDuty.relevantSectorMBTTIncrease` | `IMPLEMENTED` (data only) |
| Home transport provided | FD3.4.3 | `LH_Planning_FltDuty.relevantSectorHomeTransport` | `IMPLEMENTED` (data only) |
| Pre-duty rest (disruption): 22 hrs before Relevant Sector | FD3.4.4(a) | `LH_Planning_FltDuty.relevantSectorPreDutyRestHours = 22` | `IMPLEMENTED` |
| Post-duty: Captain OR FO = 27 hrs | FD3.4.4(b)(i) | `LH_Planning_FltDuty.relevantSectorPostDutyRest[0]` | `IMPLEMENTED` (data only) |
| Post-duty: Captain OR FO + DP > 20 hrs = 36 hrs | FD3.4.4(b)(ii) | `LH_Planning_FltDuty.relevantSectorPostDutyRest[1]` | `IMPLEMENTED` (data only) |
| Post-duty: Captain AND FO = 36 hrs | FD3.4.4(b)(iii) | `LH_Planning_FltDuty.relevantSectorPostDutyRest[2]` | `IMPLEMENTED` (data only) |
| Post-duty: Second Officer(s) = 27 hrs | FD3.4.4(b)(iv) | `LH_Planning_FltDuty.relevantSectorPostDutyRest[3]` | `IMPLEMENTED` (data only) |
| Post-duty: DP < 18 hrs → Chapter 1B limits apply | FD3.4.4(b)(v) | `LH_Planning_FltDuty.relevantSectorPostDutyRest[4]` | `IMPLEMENTED` (data only) |
| Post-duty: DP > 18 hrs + pilot fit + next FT < 4 hrs = 24 hrs (min 36 hrs before next Relevant Sector) | FD3.4.4(b)(vi) | `LH_Planning_FltDuty.relevantSectorPostDutyRest[5]` | `IMPLEMENTED` (data only) |
| Inbound AU/NZ to same time zone destination: 36 hrs | FD3.4.4(c)(i) | `LH_Planning_FltDuty.relevantSectorInboundAUNZRest[0]` | `IMPLEMENTED` (data only) |
| Inbound AU/NZ to domestic or trans-Tasman: 22 hrs | FD3.4.4(c)(ii) | `LH_Planning_FltDuty.relevantSectorInboundAUNZRest[1]` | `IMPLEMENTED` (data only) |

**Relevant Sectors (A380 & B787 only):**
- Any planned duty period > 18 hours
- Sydney to Dallas and vice versa
- Melbourne to Dallas and vice versa
- Perth to London and vice versa
- Auckland to New York and vice versa
- Perth to Paris and vice versa

---

### FD6 | Cumulative Limits (Planning) — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `lh_frms_planning_limits.html`. These are roster construction limits that the app tracks via `FRMSCumulativeTotals`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max flight time any 28 consecutive days: 100 hrs | FD6.1 | `FRMSFleet.maxFlightTime28Days = 100.0`, `flightTimePeriodDays = 28` (Rev 5) | `IMPLEMENTED` |
| Max flight time any 365 consecutive days: 1,000 hrs | FD6.2 | `FRMSFleet.maxFlightTime365Days = 1000.0` | `IMPLEMENTED` |
| Max 7-day flight time (2-pilot): 30 hrs | FD6.3 | `FRMSFleet.maxFlightTime7Days = 30.0` | `IMPLEMENTED` |
| Max duty time any 7 consecutive days: 60 hrs | FD6.4.2 | `FRMSFleet.maxDutyTime7Days = 60.0` | `IMPLEMENTED` |
| Total duty per fortnight (2-pilot): 90 hrs | FD11.1 | `FRMSFleet.maxDutyTime14Days = 90.0` (Rev 5) | `IMPLEMENTED` |
| 50 hrs duty as 3 or 4-pilot crew → 24 hrs consecutive rest before next duty | FD11.2 (Operational) | Not tracked in cumulative totals | `NOT IMPLEMENTED` |

---

## FD8 | Minimum Off Duty Periods En Route — OUT OF SCOPE

**OUT OF SCOPE** — scheduling/rostering rule applied when grouping flights into patterns. Cannot be checked from flight logs alone.

Key factors (per FD8.1): duration/time of day of preceding/following duty, local time, longitudinal time shift, accommodation suitability, available services.

FD8.2: Irregular charter/special flights may be planned to operational limits (Chapter 1B) subject to fatigue assessment and crew discretion.

FD8.3: Under exceptional circumstances (civil riot, cyclone, mercy flight), planning minimums may be reduced to operational minimums at pilot discretion.

---

## FD9 | Minimum Base Turnaround Time (MBTT) — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `lh_frms_planning_limits.html`. MBTT is calculated by the app via `FRMSCalculationService.calculateMBTT`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| 1 day away: 12 hrs | FD9.3(a) | `calculateMBTT` — `minHours = 12.0` | `IMPLEMENTED` |
| 2–4 days away: 1 local night | FD9.3(b) | `calculateMBTT` — `localNights = 1` | `IMPLEMENTED` |
| Accrued credited FT > 20 hrs: 2 local nights | FD9.3(c) | `calculateMBTT` — `creditedFlightHours > 20 → max(localNights, 2)` | `IMPLEMENTED` |
| 5–8 days away: 2 local nights | FD9.3(d) | `calculateMBTT` — `localNights = 2` | `IMPLEMENTED` |
| Accrued credited FT > 40 hrs: 3 local nights | FD9.3(e) | `calculateMBTT` — `creditedFlightHours > 40 → max(localNights, 3)` | `IMPLEMENTED` |
| 9–12 days away: 3 local nights | FD9.3(f) | `calculateMBTT` — `localNights = 3` | `IMPLEMENTED` |
| Accrued credited FT > 60 hrs OR days away > 12: 4 local nights | FD9.3(g) | `calculateMBTT` — `creditedFlightHours > 60 or daysAway > 12 → max(localNights, 4)` | `IMPLEMENTED` |
| 100 hrs in 30 days during pattern → additional MBTT (1 or 2 nights for excess hrs) | FD9.3(h) | Not tracked | `NOT IMPLEMENTED` |
| Planned duty > 18 hrs: MBTT +1 local night (per FD3.4.2) | FD9.4 | `calculateMBTT(hadPlannedDutyOver18Hours:true)` adds 1 night | `IMPLEMENTED` |
| Company may vary MBTT; max 4 local nights (except FD9.3(h)) | FD9.5 | Not applicable to app | `OUT OF SCOPE` |

---

## FD10 | Chapter 1B — Operational Limits

### FD10.1 Flight & Duty Time Limits (Operational) — 2 Pilot

| Sign-On | Max Duty (hrs) | Code | Status |
|---------|---------------|------|--------|
| ALL | 12 | `LH_Operational_FltDuty.twoPilotLimits[0].dutyPeriodLimitPlanned = 12` | `IMPLEMENTED` |

**Flight time limits (2-pilot operational — not in a table in FD10, applied via code):**
| Condition | Max FT (hrs) | Code | Status |
|-----------|-------------|------|--------|
| > 7 hrs darkness | 9.5 | Shown in `getSignOnBasedLimits2PilotA380A330B787` notes | `PARTIAL` (displayed, not enforced) |
| > 1 sector | 10.0 | Shown in notes | `PARTIAL` (displayed, not enforced) |
| All other (1 sector, no darkness) | 10.5 | Shown in notes | `PARTIAL` (displayed, not enforced) |

#### 2 Pilot — Minimum Pre-Duty Rest (Operational) — FD10.1
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 11 | 10 | `LH_Operational_FltDuty.twoPilotPreDutyRest[0]` | `IMPLEMENTED` |
| > 11 | 12 | `LH_Operational_FltDuty.twoPilotPreDutyRest[1]` | `IMPLEMENTED` |
| Within 7 days: 1 continuous period embracing 2200–0600 on 2 consecutive nights | FD10.1 | `LH_Operational_FltDuty.twoPilotPreDutyRest[2]` (data only) | `NOT IMPLEMENTED` (not enforced) |

#### 2 Pilot — Minimum Post-Duty Rest (Operational) — FD10.1
| Duty Period / FT | Min Rest | Code | Status |
|------------------|---------|------|--------|
| ≤ 11 | 10 hrs | `LH_Operational_FltDuty.twoPilotPostDutyRest[0]` | `IMPLEMENTED` |
| DP > 11 or FT > 8 (extension beyond planned) | 10 + 1 hr per 15 min TOD exceeded 11 hrs (if next duty includes operating sectors; 12 hrs if solely deadheading) | `LH_Operational_FltDuty.twoPilotPostDutyRest[1]` / `calculateMinimumRestA380A330B787` | `IMPLEMENTED` |
| DP > 12 or FT > 9 (extension beyond planned) | 24 hrs | `LH_Operational_FltDuty.twoPilotPostDutyRest[2]` | `IMPLEMENTED` |

**FD10.1 Footnote *1 (consecutive duty rule):** If 2 consecutive duty periods aggregate > 8 hrs FT or 11 hrs duty and intervening rest < 12 hrs (embracing 2200–0600) or < 24 hrs — must rest ≥ 12 hrs (embracing 2200–0600) or 24 hrs. Stored in `LH_Operational_FltDuty.twoPilotConsecutiveDutyNote`. Not enforced by calculation engine. `NOT IMPLEMENTED`

---

### FD10.1 Flight & Duty Time Limits (Operational) — 3 Pilot

| Crew Rest Facility | Max Duty (hrs) | Inflight Management | Sector Limit | Code | Status |
|-------------------|---------------|---------------------|--------------|------|--------|
| Seat in Passenger Compartment | 14 | 8 consecutive hrs of active duty | — | `LH_Operational_FltDuty.threePilotLimits[0]` | `IMPLEMENTED` |
| Class 2 Rest | 16 | Max 8 hrs continuous & 14 hrs total on flight deck | ≤ 2 sectors if DP scheduled > 14 | `LH_Operational_FltDuty.threePilotLimits[1]` | `IMPLEMENTED` |
| Class 1 Rest | 18 | Max 8 hrs continuous & 14 hrs total on flight deck | ≤ 2 sectors if DP scheduled > 14 | `LH_Operational_FltDuty.threePilotLimits[2]` | `IMPLEMENTED` |

#### 3 Pilot — Minimum Pre-Duty Rest (Operational) — FD10.2
| Min Rest (hrs) | Condition | Code | Status |
|---------------|-----------|------|--------|
| 10 | If 12 hrs rest was rostered between 2 consecutive duties, first duty ≤ 11 hrs, total of both duties ≤ 24 hrs | `LH_Operational_FltDuty.threePilotPreDutyRest[0]` | `IMPLEMENTED` (data only) |
| 12 | Default | `LH_Operational_FltDuty.threePilotPreDutyRest[1]` | `IMPLEMENTED` |

#### 3 Pilot — Minimum Post-Duty Rest (Operational) — FD10.2
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 16 | 12 | `LH_Operational_FltDuty.threePilotPostDutyRest[0]` | `IMPLEMENTED` |
| > 16 | 24 | `LH_Operational_FltDuty.threePilotPostDutyRest[1]` | `IMPLEMENTED` |

Note: If next duty is solely deadheading, minimum pre-duty deadheading limits apply.

---

### FD10.2 Flight & Duty Time Limits (Operational) — 4 Pilot

| Crew Rest Facility | Max Duty (hrs) | Inflight Management | Sector Limit | Code | Status |
|-------------------|---------------|---------------------|--------------|------|--------|
| Seats in Passenger Compartment | 14 | 8 consecutive hrs of active duty | — | `LH_Operational_FltDuty.fourPilotLimits[0]` | `IMPLEMENTED` |
| 1 × Class 2 Rest & 1 × Seat *1 | 16 | Max 8 hrs continuous & 14 hrs total on flight deck | ≤ 2 sectors if DP scheduled > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[1]` | `IMPLEMENTED` |
| 2 × Class 2 Rest | 16 | Max 8 hrs continuous & 14 hrs total on flight deck | ≤ 2 sectors if DP scheduled > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[2]` | `IMPLEMENTED` |
| 1 × Class 1 Rest & 1 × Seat *1 | 18 | Max 8 hrs continuous & 14 hrs total on flight deck | ≤ 2 sectors if DP scheduled > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[3]` | `IMPLEMENTED` |
| 1 × Class 1 & 1 × Class 2 Rest *1 | 20 | Max 8 hrs continuous & 14 hrs total on flight deck | ≤ 2 sectors if DP scheduled > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[4]` | `IMPLEMENTED` |
| 2 × Class 1 Rest | 20 | Max 8 hrs continuous & 14 hrs total on flight deck | ≤ 2 sectors if DP scheduled > 14 hrs | `LH_Operational_FltDuty.fourPilotLimits[5]` | `IMPLEMENTED` |
| 2 × Class 1 Rest (FD10.4 Relevant Sectors) | 21 (A380 & B787 only) | — | — | `LH_Operational_FltDuty.fourPilotLimits[6]` | `IMPLEMENTED` |

*1: Consideration to be given to management of mixed crew rest facilities with priority of higher class for landing crew.

#### 4 Pilot — Minimum Pre-Duty Rest (Operational) — FD10.2
| Min Rest (hrs) | Condition | Code | Status |
|---------------|-----------|------|--------|
| 10 | If 12 hrs rest was rostered between 2 consecutive duties, first duty ≤ 11 hrs, total of both duties ≤ 24 hrs | `LH_Operational_FltDuty.fourPilotPreDutyRest[0]` | `IMPLEMENTED` (data only) |
| 12 | Default | `LH_Operational_FltDuty.fourPilotPreDutyRest[1]` | `IMPLEMENTED` |
| Relevant Sector disruption limits | > 18 hrs (FD3.4) | `LH_Operational_FltDuty.fourPilotPreDutyRest[2]` | `IMPLEMENTED` (data only) |

#### 4 Pilot — Minimum Post-Duty Rest (Operational) — FD10.2
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 16 | 12 | `LH_Operational_FltDuty.fourPilotPostDutyRest[0]` | `IMPLEMENTED` |
| > 16 | 24 | `LH_Operational_FltDuty.fourPilotPostDutyRest[1]` | `IMPLEMENTED` |
| Relevant Sector disruption limits | > 18 hrs (FD10.4) | `LH_Operational_FltDuty.fourPilotPostDutyRest[2]` | `IMPLEMENTED` (data only) |

Note: If next duty is solely deadheading, minimum pre-duty deadheading limits apply.

---

### FD10.3.2 Crew Rest Classification — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `lh_frms_operational_limits.html`.

| Class | Aircraft | Code | Status |
|-------|---------|------|--------|
| Class 1 | A380-800; B787-9; A330-300 (Intl, dedicated crew rest facility); A330-200L (Intl, dedicated crew rest facility mid cabin) | `LH_Operational_FltDuty.class1Aircraft` | `IMPLEMENTED` (data only) |
| Class 2 | A330-200L (dedicated crew rest area at seat 5A) | `LH_Operational_FltDuty.class2Aircraft` | `IMPLEMENTED` (data only) |

---

### FD10.4 Patterns > 18 Hours — Relevant Sectors (A380 & B787 Only) — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `lh_frms_operational_limits.html`. Same content as FD3.4, applicable in operational context.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Pre-disruption rest before Relevant Sector: 22 hrs | FD10.4(a) | `LH_Operational_FltDuty.relevantSectorPreDutyRestHours = 22` | `IMPLEMENTED` (data only) |
| Post-disruption rest — Captain OR FO: 27 hrs | FD10.4(b)(i) | `LH_Operational_FltDuty.relevantSectorPostDutyRest[0]` | `IMPLEMENTED` (data only) |
| Post-disruption rest — Captain OR FO + DP > 20 hrs: 36 hrs | FD10.4(b)(ii) | `LH_Operational_FltDuty.relevantSectorPostDutyRest[1]` | `IMPLEMENTED` (data only) |
| Post-disruption rest — Captain AND FO: 36 hrs | FD10.4(b)(iii) | `LH_Operational_FltDuty.relevantSectorPostDutyRest[2]` | `IMPLEMENTED` (data only) |
| Post-disruption rest — Second Officer(s): 27 hrs | FD10.4(b)(iv) | `LH_Operational_FltDuty.relevantSectorPostDutyRest[3]` | `IMPLEMENTED` (data only) |
| DP < 18 hrs → Chapter 1B limits apply | FD10.4(b)(v) | `LH_Operational_FltDuty.relevantSectorPostDutyRest[4]` | `IMPLEMENTED` (data only) |
| DP > 18 hrs, fit, next FT < 4 hrs → 24 hrs (36 hrs before next Relevant Sector) | FD10.4(b)(vi) | `LH_Operational_FltDuty.relevantSectorPostDutyRest[5]` | `IMPLEMENTED` (data only) |
| Inbound AU/NZ — same time zone: 36 hrs | FD10.4(c)(i) | `LH_Operational_FltDuty.relevantSectorInboundAUNZRest[0]` | `IMPLEMENTED` (data only) |
| Inbound AU/NZ — domestic/trans-Tasman: 22 hrs | FD10.4(c)(ii) | `LH_Operational_FltDuty.relevantSectorInboundAUNZRest[1]` | `IMPLEMENTED` (data only) |

---

## FD11 | Cumulative Limitations (Operational)

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Total duty per fortnight (2-pilot) ≤ 90 hrs | FD11.1 | `FRMSFleet.maxDutyTime14Days = 90.0` (fixed Rev 5) | `IMPLEMENTED` |
| After 50 hrs duty as 3 or 4-pilot crew → 24 hrs consecutive rest | FD11.2 | Not tracked | `NOT IMPLEMENTED` |
| Max 7-day flight time (2-pilot only): 30 hrs | FD11.3 | `FRMSFleet.maxFlightTime7Days = 30.0` | `IMPLEMENTED` |
| Max flight time any 28 days: 100 hrs | FD11.4 | `FRMSFleet.maxFlightTime28Days = 100.0`, `flightTimePeriodDays = 28` (Rev 5 changed from 30 to 28) | `IMPLEMENTED` |
| Max flight time any 365 days: 1,000 hrs | FD11.5 | `FRMSFleet.maxFlightTime365Days = 1000.0` | `IMPLEMENTED` |

### FD11.6 Mixed Two, Three or More Person Crew Operations — OUT OF SCOPE

**OUT OF SCOPE** — these are rostering rules applied when a pilot operates both 2-pilot and augmented duties within the same 7 days. Cannot be fully enforced from post-flight data.

---

## FD12 | Duty Limitations — Standby / Ground Duties (Operational)

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max standby duration: 12 consecutive hrs | FD12.1 | `FRMSCalculationService.buildA320B737SpecialScenarios` (SH equivalent) — not specifically tracked for LH | `NOT IMPLEMENTED` |
| Standby must have access to suitable sleeping accommodation | FD12.2 | Not tracked | `OUT OF SCOPE` |
| Callout from standby: duty period decreased by reserve time excess over 12 hrs | FD12.3 | Not tracked | `NOT IMPLEMENTED` |
| Standby during flight duty: FDP begins at actual/required reporting time, whichever is later | FD12.4/12.5 | Not tracked | `NOT IMPLEMENTED` |

---

## FD13 | Simulator Roster Limitations — OUT OF SCOPE

**OUT OF SCOPE** for scheduling rules. Simulator duty factor (1.5×) IS tracked.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Simulator planning — refer 2-pilot Chapter 1A rules | FD13.1 | Referenced | `OUT OF SCOPE` |
| Deadheading after simulator: max 14.5 hrs duty | FD13.2 | Not tracked | `NOT IMPLEMENTED` |
| TRE A/B: cannot have 2 rostered duties on same calendar day | FD13.3(a) | Not tracked | `OUT OF SCOPE` |
| TRE A/B: no 2 consecutive late night simulator sessions | FD13.3(b) | Not tracked | `OUT OF SCOPE` |
| TRE A/B: MBTT of at least 12 hrs following duty | FD13.3(c) | Not tracked | `OUT OF SCOPE` |

---

## Summary of Issues

| Priority | Issue | Clause |
|----------|-------|--------|
| **MEDIUM** | 2-pilot operational flight time limits (9.5/10.0/10.5 hrs) displayed in FRMS tab but not enforced by calculation engine | FD10.1 |
| **LOW** | FD11.2: After 50 hrs as 3/4-pilot crew → 24 hrs rest. Not tracked. | FD11.2 |
| **LOW** | FD10.1 consecutive duty footnote (*1) stored as data but not enforced by calculation engine | FD10.1 |

---

*Source: QF FRMS Ruleset A380/A330/B787 — Revision 5 — 15 June 2026*
*Verified against: PDF (all 32 pages), LH_Planning_FltDuty.swift, LH_Operational_FltDuty.swift, FRMSData.swift, FRMSCalculationService.swift*
*Last updated: 2026-06-08*
