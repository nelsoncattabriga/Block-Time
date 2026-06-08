# SH FRMS Compliance Reference
## A320 / B737 — Revision 5 (15 June 2026)

**Status vocabulary**
- `IMPLEMENTED` — rule is encoded in Swift and used in calculations
- `PARTIAL` — partially implemented; gap noted
- `NOT IMPLEMENTED` — not yet in code
- `OUT OF SCOPE` — scheduling/roster rule the app cannot check from flight logs
- `HTML DOCS ONLY` — displayed in the in-app HTML reference but not tracked in code

---

## FD1–FD2 | Sign-On / Sign-Off

### Sign-On
| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Operating crew: 60 min before STD | FD13.1 (via FD3.2.3 reference) | `FRMSCalculationService.calculateSignOn` — `configuration.signOnMinutesBeforeSTD` defaults to 60 | `IMPLEMENTED` |
| Deadheading domestic AU (SH): 30 min before STD | FD13.1 | `calculateSignOn` — overrides to 30 min when `isPositioning && isAU && fleet == .a320B737` | `IMPLEMENTED` |
| SIM: 45 min before start | Operational convention | `calculateSignOn(isSim:true)` — hardcoded 45 min | `IMPLEMENTED` |

### Sign-Off
| Rule | PDF | Code | Status |
|------|-----|------|--------|
| International sectors: 30 min after actual IN | FD7.2.1 | `FRMSCalculationService.calculateSignOff` — overrides to 30 min when `!isSim && fleet == .a320B737 && !isAU` | `IMPLEMENTED` |
| Domestic AU sectors: 15 min after actual IN | FD7.1.1 | `FRMSConfiguration.signOffMinutesAfterIN` defaults to 15 for `.a320B737` | `IMPLEMENTED` |
| SIM: 30 min after end | Operational convention | `calculateSignOff(isSim:true)` — hardcoded 30 min | `IMPLEMENTED` |

---

## FD11 | Flight Time — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — flight time limits are displayed in `sh_frms_planning_limits.html`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max FT any 28 consecutive days: 100 hrs | FD11.1(a) | `FRMSFleet.maxFlightTime28Days = 100.0`, `flightTimePeriodDays = 28` | `IMPLEMENTED` |
| Max FT any 365 days: 1,000 hrs | FD11.1(b) | `FRMSFleet.maxFlightTime365Days = 1000.0` | `IMPLEMENTED` |
| Max FT 13 bid periods: 950 hrs | FD11.1(c) | Not tracked — roster-only rule | `OUT OF SCOPE` |

---

## FD12 | Cumulative Duty — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`. Tracked via `FRMSCumulativeTotals`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max duty time any 7 consecutive days: 60 hrs | FD12.1(a) | `FRMSFleet.maxDutyTime7Days = 60.0` | `IMPLEMENTED` |
| Max duty time in initial 14-day period: 90 hrs | FD12.1(b) | `FRMSFleet.maxDutyTime14DaysInitial = 90.0` | `IMPLEMENTED` |
| Max duty time any 14 consecutive days: 100 hrs | FD12.1(c) | `FRMSFleet.maxDutyTime14Days = 100.0` | `IMPLEMENTED` |
| Simulator factor: 1.5× duty time (for cumulative calculations) | FD12.2 | `FRMSCalculationService.calculateCumulativeTotals` — sim flights multiplied by 1.5 | `IMPLEMENTED` |
| Sim instructor role (INS): 1.5× for cumulative duty; 0 flight time | INS rule | `calculateCumulativeTotals` — `isInstructor && isSim → dutyFactor = 1.5, flightTime = 0` | `IMPLEMENTED` |

---

## FD13 | Duty Period Limitations — Planning

### FD13.1 Maximum Duty Periods — 2 Pilot

| Sign-On Window | Max Duty — Sectors 1–4 (hrs) | Max Duty — Sectors 5–6 (hrs) | Code | Status |
|----------------|------------------------------|------------------------------|------|--------|
| Early (0500–1259) | 12 | 11 | `SH_Planning_FltDuty.twoPilotLimits[0]` | `IMPLEMENTED` |
| Afternoon (1300–1759) | 11 | 10 | `SH_Planning_FltDuty.twoPilotLimits[1]` | `IMPLEMENTED` |
| Night (1800–0459) | 10 | 10 | `SH_Planning_FltDuty.twoPilotLimits[2]` | `IMPLEMENTED` |

#### 2 Pilot — Minimum Pre-Duty Rest (Planning)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 10 | 10 | `SH_Planning_FltDuty.twoPilotPreDutyRest[0]` | `IMPLEMENTED` |
| > 10 ≤ 12 | 11 | `SH_Planning_FltDuty.twoPilotPreDutyRest[1]` | `IMPLEMENTED` |
| > 12 | 12 | `SH_Planning_FltDuty.twoPilotPreDutyRest[2]` | `IMPLEMENTED` |

#### 2 Pilot — Minimum Post-Duty Rest (Planning)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 10 | 10 | `SH_Planning_FltDuty.twoPilotPostDutyRest[0]` | `IMPLEMENTED` |
| > 10 ≤ 12 | 11 | `SH_Planning_FltDuty.twoPilotPostDutyRest[1]` | `IMPLEMENTED` |
| > 12 | 12 | `SH_Planning_FltDuty.twoPilotPostDutyRest[2]` | `IMPLEMENTED` |

---

### FD13.1 Maximum Duty Periods — 3 Pilot (Planning)

| Sign-On Window | Class 2 Rest (hrs) | Business Seat Rest (hrs) | Code | Status |
|----------------|-------------------|------------------------|------|--------|
| Early (0500–1259) | 14 | 14 | `SH_Planning_FltDuty.threePilotLimits[0]` | `IMPLEMENTED` |
| Afternoon (1300–1759) | 14 | 13 | `SH_Planning_FltDuty.threePilotLimits[1]` | `IMPLEMENTED` |
| Night (1800–0459) | 14 | 12 | `SH_Planning_FltDuty.threePilotLimits[2]` | `IMPLEMENTED` |

Note: Class 2 = separate screened seat; Business seat = in passenger compartment.

#### 3 Pilot — Minimum Pre-Duty Rest (Planning)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 12 | 12 | `SH_Planning_FltDuty.threePilotPreDutyRest[0]` | `IMPLEMENTED` |
| > 12 | 12 | `SH_Planning_FltDuty.threePilotPreDutyRest[1]` | `IMPLEMENTED` |

#### 3 Pilot — Minimum Post-Duty Rest (Planning)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 12 | 12 | `SH_Planning_FltDuty.threePilotPostDutyRest[0]` | `IMPLEMENTED` |
| > 12 | 12 | `SH_Planning_FltDuty.threePilotPostDutyRest[1]` | `IMPLEMENTED` |

---

### FD13.1 Maximum Duty Periods — Augmented (Planning)

| Crew Rest Facility | Max Duty (hrs) | Max Sectors | Code | Status |
|-------------------|---------------|-------------|------|--------|
| Screened seat | 16 | 2 | `SH_Planning_FltDuty.augmentedLimits[0]` | `IMPLEMENTED` |
| Seat in passenger compartment | 14 | 2 | `SH_Planning_FltDuty.augmentedLimits[1]` | `IMPLEMENTED` |

#### Augmented — Minimum Pre-Duty Rest (Planning)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 14 | 12 | `SH_Planning_FltDuty.augmentedPreDutyRest[0]` | `IMPLEMENTED` |
| > 14 | 14 | `SH_Planning_FltDuty.augmentedPreDutyRest[1]` | `IMPLEMENTED` |

#### Augmented — Minimum Post-Duty Rest (Planning)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 14 | 12 | `SH_Planning_FltDuty.augmentedPostDutyRest[0]` | `IMPLEMENTED` |
| > 14 | 14 | `SH_Planning_FltDuty.augmentedPostDutyRest[1]` | `IMPLEMENTED` |

---

### FD13.3 Flight Time Limits — 2 Pilot (Planning)

| Condition | Max FT (hrs) | Code | Status |
|-----------|-------------|------|--------|
| > 7 hrs darkness during duty | 9.5 | `SH_Planning_FltDuty.twoPilotFlightTimeLimits.withDarkness` | `IMPLEMENTED` |
| > 1 sector | 10.0 | `SH_Planning_FltDuty.twoPilotFlightTimeLimits.multiSector` | `IMPLEMENTED` |
| All other (1 sector, darkness ≤ 7 hrs) | 10.5 | `SH_Planning_FltDuty.twoPilotFlightTimeLimits.standard` | `IMPLEMENTED` |

### FD13.4 Flight Time Limits — Augmented (Planning)

| Condition | Max FT (hrs) | Code | Status |
|-----------|-------------|------|--------|
| All augmented | 10.5 | `SH_Planning_FltDuty.augmentedFlightTimeLimit` | `IMPLEMENTED` |

---

### FD13.5 Reserve — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max reserve duration: 12 hrs | FD13.5 | `SH_Planning_FltDuty.maxReserveHours = 12.0` | `IMPLEMENTED` (data only) |

---

### FD13.6 Early Starts — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`. Tracked via `FRMSCumulativeTotals.earlyStartCount`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max 4 early starts (sign-on before 0706 LT) in 7 consecutive days | FD13.6 | `FRMSFleet.maxEarlyStartsIn7Days = 4` — tracked in `calculateCumulativeTotals` | `IMPLEMENTED` |

---

## FD14 | Late Night Operations (LNO) / Back of Clock (BOC) — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`. Tracked via `FRMSCumulativeTotals`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max 4 LNO nights (2200–0559 LT) in 7 consecutive days | FD14.1 | `FRMSFleet.maxLateNightDutiesIn7Days = 4` — tracked in `calculateCumulativeTotals` | `IMPLEMENTED` |
| LNO recovery: 24 hrs free from duty after > 2 consecutive LNO nights | FD14.2 | `FRMSFleet.lnoRecoveryRequiredAfterConsecutiveLNO = 2` — tracked | `IMPLEMENTED` |
| Max 2 Back of Clock (BOC) duties in any 168 consecutive hours | FD14.3 | `FRMSFleet.maxBOCDutiesIn168Hours = 2` — tracked in `calculateCumulativeTotals` | `IMPLEMENTED` |

---

## FD15 | Deadheading — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Deadheading combined with flight duty: max 16 hrs | FD15 | `SH_Planning_FltDuty.maxDeadheadCombinedWithDuty = 16.0` | `IMPLEMENTED` (data only, not enforced) |

---

## FD16 | Consecutive Duty Days — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`. Tracked via `FRMSCumulativeTotals`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max 9 consecutive duty days (standard) | FD16.1 | `FRMSFleet.maxConsecutiveDutyDays = 9` — tracked | `IMPLEMENTED` |
| Max 11 consecutive duty days (extended) | FD16.1 | `FRMSFleet.maxConsecutiveDutyDaysExtended = 11` — tracked | `IMPLEMENTED` |
| Max 6 consecutive duty days before a day free from duty | FD16.2 | `FRMSFleet.maxConsecutiveDaysBeforeDayOff = 6` — tracked | `IMPLEMENTED` |
| Max 4 early starts in consecutive duty block | FD16.3 | `FRMSFleet.maxEarlyStartsIn7Days = 4` (overlapping period) — tracked | `IMPLEMENTED` |

---

## FD17 | Split Duty — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Min rest in split: 6 hrs | FD17.1(a) | `SH_Planning_FltDuty.splitDutyRules.minRestHours = 6.0` | `IMPLEMENTED` (data only) |
| Duty period extension for split: + 4 hrs | FD17.1(b) | `SH_Planning_FltDuty.splitDutyRules.dutyExtensionHours = 4.0` | `IMPLEMENTED` (data only) |
| Max total duty in split duty day: 16 hrs | FD17.1(c) | `SH_Planning_FltDuty.splitDutyRules.maxTotalDutyHours = 16.0` | `IMPLEMENTED` (data only) |
| Rest discount: 50% of rest up to max 4 hrs | FD17.1(d) | `SH_Planning_FltDuty.splitDutyRules.restDiscountPercent = 50; maxDiscountHours = 4.0` | `IMPLEMENTED` (data only) |

---

## FD18 | Time Free From Duty Within Pattern — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Duty ≤ 12 hrs: time free = max(10 hrs, duty hrs) | FD18.1(a) | `SH_Planning_FltDuty.timeFreeWithinPattern` | `IMPLEMENTED` (data only) |
| Duty > 12 hrs: time free = 12 + 1.5 × (duty − 12) hrs | FD18.1(b) | `SH_Planning_FltDuty.timeFreeWithinPattern` | `IMPLEMENTED` (data only) |

---

## FD19 | Post-Pattern Rest — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`.

| Pattern Length | Min Post-Pattern Rest (hrs) | Code | Status |
|----------------|---------------------------|------|--------|
| 1–2 day pattern | 12 | `SH_Planning_FltDuty.postPatternRest[0]` | `IMPLEMENTED` (data only) |
| 3–4 day pattern | 15 | `SH_Planning_FltDuty.postPatternRest[1]` | `IMPLEMENTED` (data only) |

---

## FD20 | Weekly Rest — Planning — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`. These are roster construction limits.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| 36 consecutive hrs free from duty in each 7 days, OR 2 consecutive nights in each 8 days | FD20.1 | `SH_Planning_FltDuty.weeklyRestOptions` | `IMPLEMENTED` (data only) |
| Additional 7-day/28-day/84-day/monthly rest requirements | FD20.2–20.5 | `SH_Planning_FltDuty.weeklyRestRequirements` | `IMPLEMENTED` (data only) |

---

## FD21 | Flight Time — Operational

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max FT any 28 consecutive days: 100 hrs | FD21.1(a) | `FRMSFleet.maxFlightTime28Days = 100.0` | `IMPLEMENTED` |
| Max FT any 365 days: 1,000 hrs | FD21.1(b) | `FRMSFleet.maxFlightTime365Days = 1000.0` | `IMPLEMENTED` |
| Max FT 13 bid periods: 950 hrs | FD21.1(c) | Not tracked — roster-only rule | `OUT OF SCOPE` |

---

## FD22 | Cumulative Duty — Operational

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max duty time any 7 consecutive days: 60 hrs | FD22.1(a) | `FRMSFleet.maxDutyTime7Days = 60.0` | `IMPLEMENTED` |
| Max duty time in initial 14-day period: 90 hrs | FD22.1(b) | `FRMSFleet.maxDutyTime14DaysInitial = 90.0` | `IMPLEMENTED` |
| Max duty time any 14 consecutive days: 100 hrs | FD22.1(c) | `FRMSFleet.maxDutyTime14Days = 100.0` | `IMPLEMENTED` |
| Simulator factor: 1.5× (for cumulative calculations) | FD22.2 | `FRMSCalculationService.calculateCumulativeTotals` — sim multiplied by 1.5 | `IMPLEMENTED` |

---

## FD23 | Duty Period Limitations — Operational

### FD23.1 Maximum Duty Periods — 2 Pilot

| Sign-On Window | Sectors 1–4 (hrs) | Sectors 5 (hrs) | Sectors 6 (hrs) | Code | Status |
|----------------|-------------------|-----------------|-----------------|------|--------|
| Early (0500–1259) | 14 | 13 | 12 | `SH_Operational_FltDuty.twoPilotLimits[0]` | `IMPLEMENTED` |
| Afternoon (1300–1759) | 13 | 12 | 11 | `SH_Operational_FltDuty.twoPilotLimits[1]` | `IMPLEMENTED` |
| Night (1800–0459) | 12 | 12 | 11 | `SH_Operational_FltDuty.twoPilotLimits[2]` | `IMPLEMENTED` |

#### 2 Pilot — Minimum Pre-Duty Rest (Operational)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 12 | 10 | `SH_Operational_FltDuty.twoPilotPreDutyRest[0]` | `IMPLEMENTED` |
| > 12 ≤ 14 | 11 | `SH_Operational_FltDuty.twoPilotPreDutyRest[1]` | `IMPLEMENTED` |
| > 14 | 12 | `SH_Operational_FltDuty.twoPilotPreDutyRest[2]` | `IMPLEMENTED` |

#### 2 Pilot — Minimum Post-Duty Rest (Operational)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 12 | 10 | `SH_Operational_FltDuty.twoPilotPostDutyRest[0]` | `IMPLEMENTED` |
| > 12 ≤ 14 | 11 | `SH_Operational_FltDuty.twoPilotPostDutyRest[1]` | `IMPLEMENTED` |
| > 14 | 12 | `SH_Operational_FltDuty.twoPilotPostDutyRest[2]` | `IMPLEMENTED` |

---

### FD23.1 Maximum Duty Periods — 3 Pilot (Operational)

| Sign-On Window | Class 2 Rest (hrs) | Business Seat Rest (hrs) | Code | Status |
|----------------|-------------------|------------------------|------|--------|
| Early (0500–1259) | 16 | 14.5 | `SH_Operational_FltDuty.threePilotLimits[0]` | `IMPLEMENTED` |
| Afternoon (1300–1759) | 16 | 13.5 | `SH_Operational_FltDuty.threePilotLimits[1]` | `IMPLEMENTED` |
| Night (1800–0459) | 16 | 12.5 | `SH_Operational_FltDuty.threePilotLimits[2]` | `IMPLEMENTED` |

#### 3 Pilot — Minimum Pre-Duty Rest (Operational)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 12 | 12 | `SH_Operational_FltDuty.threePilotPreDutyRest[0]` | `IMPLEMENTED` |
| > 12 | 12 | `SH_Operational_FltDuty.threePilotPreDutyRest[1]` | `IMPLEMENTED` |

#### 3 Pilot — Minimum Post-Duty Rest (Operational)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 12 | 12 | `SH_Operational_FltDuty.threePilotPostDutyRest[0]` | `IMPLEMENTED` |
| > 12 | 12 | `SH_Operational_FltDuty.threePilotPostDutyRest[1]` | `IMPLEMENTED` |

---

### FD23.1 Maximum Duty Periods — Augmented (Operational)

| Crew Rest Facility | Max Duty (hrs) | Max Sectors | Code | Status |
|-------------------|---------------|-------------|------|--------|
| Screened seat | 16 | 2 | `SH_Operational_FltDuty.augmentedLimits[0]` | `IMPLEMENTED` |
| Seat in passenger compartment | 14 | 2 | `SH_Operational_FltDuty.augmentedLimits[1]` | `IMPLEMENTED` |

#### Augmented — Minimum Pre-Duty Rest (Operational)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 14 | 12 | `SH_Operational_FltDuty.augmentedPreDutyRest[0]` | `IMPLEMENTED` |
| > 14 | 14 | `SH_Operational_FltDuty.augmentedPreDutyRest[1]` | `IMPLEMENTED` |

#### Augmented — Minimum Post-Duty Rest (Operational)
| Duty Period | Min Rest (hrs) | Code | Status |
|-------------|---------------|------|--------|
| ≤ 14 | 12 | `SH_Operational_FltDuty.augmentedPostDutyRest[0]` | `IMPLEMENTED` |
| > 14 | 14 | `SH_Operational_FltDuty.augmentedPostDutyRest[1]` | `IMPLEMENTED` |

---

### FD23.3 Flight Time Limits — 2 Pilot (Operational)

| Condition | Max FT (hrs) | Code | Status |
|-----------|-------------|------|--------|
| > 7 hrs darkness during duty | 9.5 | `SH_Operational_FltDuty.twoPilotFlightTimeLimits.withDarkness` | `IMPLEMENTED` |
| > 1 sector | 10.0 | `SH_Operational_FltDuty.twoPilotFlightTimeLimits.multiSector` | `IMPLEMENTED` |
| All other | 10.5 | `SH_Operational_FltDuty.twoPilotFlightTimeLimits.standard` | `IMPLEMENTED` |

### FD23.4 Flight Time Limits — Augmented (Operational)

| Condition | Max FT (hrs) | Code | Status |
|-----------|-------------|------|--------|
| All augmented | 10.5 | `SH_Operational_FltDuty.augmentedFlightTimeLimit` | `IMPLEMENTED` |

---

### FD23.4(c) Reserve + Duty — Operational Necessity

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Reserve duration + subsequent flight duty, operational necessity: max 18 hrs combined | FD23.4(c) | `SH_Operational_FltDuty.maxReserveAndDutyHours = 18.0` | `IMPLEMENTED` (data only) |

---

### FD23.5 Reserve — Operational — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_operational_limits.html`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max reserve duration: 12 hrs | FD23.5 | `SH_Operational_FltDuty.maxReserveHours = 12.0` | `IMPLEMENTED` (data only) |

---

## FD24 | Late Night Operations (LNO) / Back of Clock (BOC) — Operational — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_operational_limits.html`. Tracked via `FRMSCumulativeTotals`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max 4 LNO nights in 7 consecutive days | FD24.1 | `FRMSFleet.maxLateNightDutiesIn7Days = 4` — tracked | `IMPLEMENTED` |
| LNO recovery: 24 hrs free from duty after > 2 consecutive LNO nights | FD24.2 | `FRMSFleet.lnoRecoveryRequiredAfterConsecutiveLNO = 2` — tracked | `IMPLEMENTED` |
| Max 2 BOC duties in any 168 consecutive hours | FD24.3 | `FRMSFleet.maxBOCDutiesIn168Hours = 2` — tracked | `IMPLEMENTED` |

---

## FD25 | Deadheading — Operational — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_operational_limits.html`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Deadheading combined with flight duty: max 16 hrs | FD25 | `SH_Operational_FltDuty.maxDeadheadCombinedWithDuty = 16.0` | `IMPLEMENTED` (data only, not enforced) |

---

## FD26 | Consecutive Duty Days — Operational — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_operational_limits.html`. Tracked via `FRMSCumulativeTotals`.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Max 9 consecutive duty days (standard) | FD26.1 | `FRMSFleet.maxConsecutiveDutyDays = 9` — tracked | `IMPLEMENTED` |
| Max 11 consecutive duty days (extended) | FD26.1 | `FRMSFleet.maxConsecutiveDutyDaysExtended = 11` — tracked | `IMPLEMENTED` |
| Max 6 consecutive duty days before a day free from duty | FD26.2 | `FRMSFleet.maxConsecutiveDaysBeforeDayOff = 6` — tracked | `IMPLEMENTED` |
| Max 4 early starts in consecutive duty block | FD26.3 | `FRMSFleet.maxEarlyStartsIn7Days = 4` (overlapping period) — tracked | `IMPLEMENTED` |

---

## FD27 | Split Duty — Operational — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_operational_limits.html`.

### FD27.1 Sleeping Accommodation Available

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Duty extension: + 4 hrs | FD27.1(a) | `SH_Operational_FltDuty.splitDutyRulesBySleeping.dutyExtensionHours = 4.0` | `IMPLEMENTED` (data only) |
| Max total duty: 16 hrs | FD27.1(b) | `SH_Operational_FltDuty.splitDutyRulesBySleeping.maxTotalDutyHours = 16.0` | `IMPLEMENTED` (data only) |
| Rest discount: 50% up to max 4 hrs | FD27.1(c) | `SH_Operational_FltDuty.splitDutyRulesBySleeping.restDiscountPercent = 50; maxDiscountHours = 4.0` | `IMPLEMENTED` (data only) |

### FD27.2 Resting Accommodation Available (No Sleeping)

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Duty extension: + 2 hrs | FD27.2(a) | `SH_Operational_FltDuty.splitDutyRulesByResting.dutyExtensionHours = 2.0` | `IMPLEMENTED` (data only) |

---

## FD28 | Time Free From Duty — Operational — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_operational_limits.html`.

### FD28.1 Time Free — 2 Pilot

| Condition | Rule | Code | Status |
|-----------|------|------|--------|
| Duty ≤ 12 hrs | Time free = max(10 hrs, duty hrs) | `SH_Operational_FltDuty.twoPilotTimeFree` | `IMPLEMENTED` (data only) |
| Duty > 12 hrs | Time free = 12 + 1.5 × (duty − 12) hrs | `SH_Operational_FltDuty.twoPilotTimeFree` | `IMPLEMENTED` (data only) |

### FD28.2 Time Free — 3 Pilot

| Condition | Rule | Code | Status |
|-----------|------|------|--------|
| Duty ≤ 16 hrs | Time free = max(12 hrs, duty hrs) | `SH_Operational_FltDuty.threePilotTimeFree` | `IMPLEMENTED` (data only) |
| Duty > 16 hrs | Time free = 16 + 1.5 × (duty − 16) hrs | `SH_Operational_FltDuty.threePilotTimeFree` | `IMPLEMENTED` (data only) |

---

## FD30 | Simulator Limitations — HTML DOCS ONLY

**HTML DOCS ONLY** — displayed in `sh_frms_planning_limits.html`. Simulator duty factor tracked for cumulative duty.

| Rule | PDF | Code | Status |
|------|-----|------|--------|
| Simulator duty factor: 1.5× for cumulative duty calculations | FD30 | `calculateCumulativeTotals` — sim flights multiplied by 1.5 | `IMPLEMENTED` |
| TRE A/B: cannot have 2 rostered duties on same calendar day | FD30 | Not tracked | `OUT OF SCOPE` |
| TRE A/B: no 2 consecutive late night simulator sessions | FD30 | Not tracked | `OUT OF SCOPE` |
| TRE A/B: MBTT of at least 12 hrs following duty | FD30 | Not tracked | `OUT OF SCOPE` |

---

## Chapters 4A & 4B | NZ-Based Crew — OUT OF SCOPE

All FD40–FD68 rules (Chapters 4A and 4B) apply to NZ-based crew only. The app does not track NZ crew. These rules are noted in the in-app HTML reference files for completeness.

| Clause Range | Subject | Status |
|-------------|---------|--------|
| FD40–FD46 | NZ sign-on/off, RDOs, general provisions | `OUT OF SCOPE` |
| FD47–FD55 | NZ Chapter 4A planning limits (FT, duty, rest, split) | `OUT OF SCOPE` |
| FD60–FD68 | NZ Chapter 4B operational limits (FT, duty, rest, split) | `OUT OF SCOPE` |

---

## Summary of Issues

| Priority | Issue | Clause |
|----------|-------|--------|
| **MEDIUM** | Split duty rules (FD17/FD27) — data stored in Swift structs but not enforced by calculation engine against actual logged duty periods | FD17, FD27 |
| **MEDIUM** | Time free from duty (FD18/FD28) — data stored but not enforced | FD18, FD28 |
| **MEDIUM** | Deadhead max 16 hrs (FD15/FD25) — constant stored but not enforced from flight data | FD15, FD25 |
| **LOW** | Post-pattern rest (FD19) — data stored but not enforced | FD19 |
| **LOW** | Weekly rest (FD20) — data stored but not enforced; roster-level rule | FD20 |

---

*Source: QF FRMS Ruleset A320/B737 — Revision 5 — 15 June 2026*
*Verified against: PDF (pages 1–22; NZ pages 23–34 noted as OUT OF SCOPE), SH_Planning_FltDuty.swift, SH_Operational_FltDuty.swift, FRMSData.swift, FRMSCalculationService.swift*
*Last updated: 2026-06-08*
