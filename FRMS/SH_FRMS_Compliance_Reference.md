# SH FRMS Compliance Reference — A320/B737

**Source PDF:** `A320_B737_FRMS_Ruleset_Revision_5-QFA-AUTO-8293A3B89-1-20260607-100935.pdf`
**Revision:** 5 | **Issue Date:** 15 June 2026
**Scope:** Australia-based crew — Chapter 1A (FD11–FD20, Planning) and Chapter 1B (FD21–FD28, Operational)
**Excludes:** NZ-based crew chapters (FD40–FD68)

**Status Key:** `IMPLEMENTED` | `PARTIAL` | `NOT IMPLEMENTED` | `NOT APPLICABLE` | `NEEDS REVIEW`

---

## CHAPTER 1A — PLANNING

---

### FD11 — Flight Time Limits (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD11.1(a) | Max flight time in any consecutive 28 days | 100 hrs | `SH_Planning_FltDuty.cumulativeFlightTime28DaysHours` | IMPLEMENTED |
| FD11.1(b) | Max flight time in any consecutive 365 days | 1,000 hrs | `SH_Planning_FltDuty.cumulativeFlightTime365DaysHours` | IMPLEMENTED |
| FD11.2 | Max flight time in any 13 consecutive bid periods (at roster promulgation) | 950 hrs | `SH_Planning_FltDuty.cumulativeFlightTime13BidPeriodsHours` | IMPLEMENTED |

---

### FD12 — Cumulative Duty Time Limits (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD12.1(a) | Max cumulative duty in any consecutive 7 days | 60 hrs | `SH_Planning_FltDuty.cumulativeDutyTime7DaysHours` | IMPLEMENTED |
| FD12.1(b) | Max cumulative duty in any consecutive 14 days (initial roster publication) | 90 hrs | `SH_Planning_FltDuty.cumulativeDutyTime14DaysInitialHours` | IMPLEMENTED |
| FD12.1(b) | Max cumulative duty in any consecutive 14 days (pilot agreement / open time) | 100 hrs | `SH_Planning_FltDuty.cumulativeDutyTime14DaysExtendedHours` | IMPLEMENTED |
| FD12.1 | Simulator/training duty factoring (trainee and support pilot, excl. line training/checks/DH) | ×1.5 | `SH_Planning_FltDuty.simulatorTrainingDutyFactor` | IMPLEMENTED |
| FD20.2(a) | Max duty days in any 11-day period | 9 days | `SH_Planning_FltDuty.maxDutyDaysIn11Days` | IMPLEMENTED (stored in FD20 section of code) |
| FD20.2(b) | Max consecutive duty days | 6 days | `SH_Planning_FltDuty.maxConsecutiveDutyDays` | IMPLEMENTED |
| FD20.1(a) | Min 36 consecutive hours free of all duty in any consecutive 7 days | 36 hrs | `SH_Planning_FltDuty.minHoursFreeIn7ConsecutiveDays` | IMPLEMENTED |

---

### FD13 — Maximum Duty Periods (Planning)

#### FD13.1 — 2 Pilot Duty Period Limits

| Clause | Local Start | Sectors | Max Duty | Swift Implementation | Status |
|---|---|---|---|---|---|
| FD13.1 | 0500–1259 | 1–4 | 12 hrs | `SH_Planning_FltDuty.twoPilotDutyLimits[.early].maxDutySectors1to4` | IMPLEMENTED |
| FD13.1 | 0500–1259 | 5 or 6 | 11 hrs | `SH_Planning_FltDuty.twoPilotDutyLimits[.early].maxDutySectors5or6` | IMPLEMENTED |
| FD13.1 | 1300–1759 | 1–4 | 11 hrs | `SH_Planning_FltDuty.twoPilotDutyLimits[.afternoon].maxDutySectors1to4` | IMPLEMENTED |
| FD13.1 | 1300–1759 | 5 or 6 | 10 hrs | `SH_Planning_FltDuty.twoPilotDutyLimits[.afternoon].maxDutySectors5or6` | IMPLEMENTED |
| FD13.1 | 1800–0459 | 1–4 | 10 hrs | `SH_Planning_FltDuty.twoPilotDutyLimits[.night].maxDutySectors1to4` | IMPLEMENTED |
| FD13.1 | 1800–0459 | 5 or 6 | 10 hrs | `SH_Planning_FltDuty.twoPilotDutyLimits[.night].maxDutySectors5or6` | IMPLEMENTED |

#### FD13.1 — 3 Pilot Duty Period Limits (max 2 sectors; total min rest ≥ 2 hrs)

| Clause | Local Start | Rest Facility | Max Duty | Swift Implementation | Status |
|---|---|---|---|---|---|
| FD13.1 | 0500–1259 | Class 2 | 14 hrs | `SH_Planning_FltDuty.threePilotDutyLimits[.early].class2MaxDuty` | IMPLEMENTED |
| FD13.1 | 0500–1259 | Business Seat | 14 hrs | `SH_Planning_FltDuty.threePilotDutyLimits[.early].businessSeatMaxDuty` | IMPLEMENTED |
| FD13.1 | 1300–1759 | Class 2 | 14 hrs | `SH_Planning_FltDuty.threePilotDutyLimits[.afternoon].class2MaxDuty` | IMPLEMENTED |
| FD13.1 | 1300–1759 | Business Seat | 13 hrs | `SH_Planning_FltDuty.threePilotDutyLimits[.afternoon].businessSeatMaxDuty` | IMPLEMENTED |
| FD13.1 | 1800–0459 | Class 2 | 14 hrs | `SH_Planning_FltDuty.threePilotDutyLimits[.night].class2MaxDuty` | IMPLEMENTED |
| FD13.1 | 1800–0459 | Business Seat | 12 hrs | `SH_Planning_FltDuty.threePilotDutyLimits[.night].businessSeatMaxDuty` | IMPLEMENTED |

#### FD13.1 — Augmented Duty Period Limits

| Clause | Rest Facility | Max Duty | Sector Limit | Swift Implementation | Status |
|---|---|---|---|---|---|
| FD13.1 | Separate screened seat | 16 hrs | ≤ 2 sectors if DP > 14 hrs | `SH_Planning_FltDuty.augmentedDutyLimits[.separateScreenedSeat]` | IMPLEMENTED |
| FD13.1 | Passenger compartment seat | 14 hrs | — | `SH_Planning_FltDuty.augmentedDutyLimits[.passengerCompartmentSeat]` | IMPLEMENTED |

#### FD13.2 — EPT Extension

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD13.2 | Max duty for EPT at non-home base (not SYD/MEL pilots) | 15 hrs | `SH_Planning_FltDuty.emergencyProceduresTrainingMaxDutyHours` | IMPLEMENTED |

#### FD13.3 — Reserve Duty

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD13.3 | Max reserve duty (consecutive hours; access to sleeping accommodation) | 12 hrs | `SH_Planning_FltDuty.reserveDutyMaxConsecutiveHours` | IMPLEMENTED |

#### FD13.4 — Reserve Callout Combined Limit

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD13.4 | Max combined reserve + subsequent duty period | 16 hrs | `FRMSCalculationService` (applied in next-duty calculation) | PARTIAL |
| FD13.4(a) | Exception: augmented crew operation | exempt | Not explicitly modelled as named constant | PARTIAL |
| FD13.4(b) | Exception: split duty (FD17) | exempt | Not explicitly modelled as named constant | PARTIAL |

#### FD13.5 — Reserve Night Period Exclusion

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD13.5 | If reserve starts 2300–0600, time before callout in that window excluded from combined limit | 2300–0600 | Not implemented as explicit constant | NOT IMPLEMENTED |

#### FD13.6 — Consecutive Early Starts

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD13.6 | Max consecutive duties with sign-on before 0706 LT | 4 | `SH_Planning_FltDuty.maxConsecutiveEarlyStarts` | IMPLEMENTED |
| FD13.6 | Early start sign-on threshold | 0706 LT | `SH_Planning_FltDuty.earlyStartSignOnThreshold` | IMPLEMENTED |

#### FD13.3 — Flight Time Limits (2 Pilot)

| Clause | Condition | Max Flight Time | Swift Implementation | Status |
|---|---|---|---|---|
| FD13.3 | >7 hrs flight time in darkness | 9.5 hrs | `SH_Planning_FltDuty.twoPilotFlightTimeLimits[.darknessHeavy]` | IMPLEMENTED |
| FD13.3 | More than 1 sector scheduled | 10.0 hrs | `SH_Planning_FltDuty.twoPilotFlightTimeLimits[.multiSector]` | IMPLEMENTED |
| FD13.3 | All other occasions | 10.5 hrs | `SH_Planning_FltDuty.twoPilotFlightTimeLimits[.standard]` | IMPLEMENTED |

#### FD13.4 — Flight Time Limits (Augmented / 3 Pilot)

| Clause | Condition | Max Flight Time | Swift Implementation | Status |
|---|---|---|---|---|
| FD13.4 | All occasions | 10.5 hrs | `SH_Planning_FltDuty.augmentedFlightTimeLimitHours` | IMPLEMENTED |

---

### FD14 — Late Night Operations, Back of Clock Operations and Early Starts (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD14.1 | Max consecutive LNO flying duties before 24-hr free period required | 2 consecutive | `SH_Planning_FltDuty.lateNightMaxConsecutiveNights` (value = 4 — see note) | NEEDS REVIEW |
| FD14.2 | Max LNO flying duty periods in rolling 168 hrs | 4 | `SH_Planning_FltDuty.lateNightMaxDutiesIn168Hours` | IMPLEMENTED |
| FD14.3 | FD14.1 and FD14.2 not applicable to reserve duty periods | exempt | `FRMSCalculationService` — `duty.dutyType != .standby` filter in LNO count | IMPLEMENTED |
| FD14.4 | Max BOC flying duty periods in rolling 168 hrs | 2 | `SH_Planning_FltDuty.backOfClockMaxDutiesIn168Hours` | IMPLEMENTED |
| FD14.5 | Following BOC duty: next flying duty sign-on (if in Australia) no earlier than 1000 LT next day | 1000 LT | `SH_Planning_FltDuty.backOfClockEarliestSignOnLocalHHMM` | IMPLEMENTED |
| FD14.6 | Max consecutive duties with sign-on before 0706 LT | 4 | `SH_Planning_FltDuty.maxConsecutiveEarlyStarts` | IMPLEMENTED |

> **NOTE — FD14.1 `lateNightMaxConsecutiveNights` value:** The PDF FD14.1 states "more than **2** consecutive LNO duties requires 24-hr rest". The Swift constant `lateNightMaxConsecutiveNights = 4` is used as the limit for the `consecutiveLateNights` counter, but the recovery logic in `FRMSCalculationService` triggers at `>= 2` for `require24HoursOff`. This needs verification — the constant name implies a max of 4 consecutive nights, but the rule says 2.

> **NOTE — BOC threshold:** `backOfClockMinutesThreshold = 120` (2 hours between 0100–0459 LT). This is the correct BOC definition.

---

### FD15 — Deadheading Following a Flight Duty (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD15.1 | May deadhead following flight duty up to Operational Limits (FD23.1) | per FD23.1 | `SH_Planning_FltDuty` references `SH_Operational_FltDuty` duty limits | IMPLEMENTED |
| FD15.2 | At pilot discretion, FD23.1 limits may be extended when deadheading | pilot discretion | Not modelled (pilot-only decision) | NOT APPLICABLE |
| FD15.3 | Deadheading included in total duty for rest and FDT calculations | — | Applied in `FRMSCalculationService` duty period calculations | IMPLEMENTED |
| FD15.4 | DH sector (if last sector) not counted for sector limit determination | — | Not explicitly flagged in model but referenced in `FRMSDuty` | PARTIAL |
| FD15.5 | DH sector before flight duty counts as a sector | — | Not explicitly modelled | PARTIAL |
| FD15.6 | No duty period with flight duty to exceed 16 hrs | 16 hrs | `SH_Planning_FltDuty.deadheadingAbsoluteMaxDutyHours` | IMPLEMENTED |

---

### FD16 — Pilot Projected to Exceed Limits (Planning)

| Clause | Rule | Swift Implementation | Status |
|---|---|---|---|
| FD16.1 | Company must remove / pilot relinquishes minimum flight duty to avoid breach | Informational — no calculation required | NOT IMPLEMENTED |

---

### FD17 — Split Duty (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD17.1 | Min rest at suitable sleeping accommodation for split duty | 6 hrs | `SH_Planning_FltDuty.splitDutyRules.minimumRestHours` | IMPLEMENTED |
| FD17.2 | Max duty extension above FD13.1 limits | +4 hrs | `SH_Planning_FltDuty.splitDutyRules.maxDutyExtensionHours` | IMPLEMENTED |
| FD17.2 | Absolute max duty period with split duty | 16 hrs | `SH_Planning_FltDuty.splitDutyRules.absoluteMaxDutyHours` | IMPLEMENTED |
| FD17.3 | Rest discount: 50% of rest period (max 4 hrs) for subsequent TFD and cumulative duty | 50%, max 4 hrs | `SH_Planning_FltDuty.splitDutyRules.restDiscountPercent`, `.maxRestDiscountHours` | IMPLEMENTED |
| FD17.4 | If rest includes 2300–0530: min 7 hrs uninterrupted; max duty → 16 hrs; no discount | 7 hrs, 2300–0530 | `SH_Planning_FltDuty.splitDutyRules.nightWindowStart/End`, `.nightWindowMinRestHours` | IMPLEMENTED |
| FD17.4(b) | No rest discounting when rest includes 2300–0530 | prohibited | `SH_Planning_FltDuty.splitDutyRules` (flag) | IMPLEMENTED |

---

### FD18 — Time Free from Duty Within a Pattern (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD18.1 | Min time free if previous duty ≤ 12 hrs | max(10 hrs, previous duty) | `SH_Planning_FltDuty.timeFreeWithinPattern.minimumRestHours` | IMPLEMENTED |
| FD18.1 | If previous duty > 12 hrs: 12 hrs + 1.5 × (duty − 12 hrs) | formula | `SH_Planning_FltDuty.timeFreeWithinPattern.formula` | IMPLEMENTED |

---

### FD19 — Time Free from Duty Following a Pattern (Planning)

#### 2 Pilot Operations

| Clause | Pattern Length | Min TFD | Swift Implementation | Status |
|---|---|---|---|---|
| FD19.1 | 1 or 2 day pattern | 12 hrs | `SH_Planning_FltDuty.patternTimeFreeRequirements[0]` | IMPLEMENTED |
| FD19.2 | 3 or 4 day pattern | 15 hrs | `SH_Planning_FltDuty.patternTimeFreeRequirements[1]` | IMPLEMENTED |

#### 3 Pilot (Augmented) Operations

| Clause | TAFB | Day Return | Multi-day Pattern | Swift Implementation | Status |
|---|---|---|---|---|---|
| FD19 | ≤ 52 hrs | 14.5 hrs | 15 hrs (if next duty day > 9.59 hrs)¹ | `SH_Planning_FltDuty.threePilotPatternRestRequirements[0]` | IMPLEMENTED |
| FD19 | 52+ to < 124 hrs | N/A | 22 hrs (if next duty day > 9.59 hrs)¹ | `SH_Planning_FltDuty.threePilotPatternRestRequirements[1]` | IMPLEMENTED |
| FD19 | ≥ 124 hrs | N/A | 32 hrs | `SH_Planning_FltDuty.threePilotPatternRestRequirements[2]` | IMPLEMENTED |

¹ Refer to FD14.5 (BOC sign-on restriction)

---

### FD20 — Time Free from Duty (Planning)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD20.1(a) | Min 36 consecutive hours free of duty in any 7 consecutive days | 36 hrs | `SH_Planning_FltDuty.minHoursFreeIn7ConsecutiveDays` | IMPLEMENTED |
| FD20.1(b) | Alternative: 2 consecutive local nights (start ≤ 2200, end ≥ 0500) in any 8 consecutive nights | 2 nights | `FRMSCumulativeTotals` (tracked) | PARTIAL |
| FD20.2(a) | Max duty days in any 11-day period | 9 days | `SH_Planning_FltDuty.maxDutyDaysIn11Days` | IMPLEMENTED |
| FD20.2(b) | Max consecutive duty days | 6 days | `SH_Planning_FltDuty.maxConsecutiveDutyDays` | IMPLEMENTED |
| FD20.3(a) | Min 7 days free in any consecutive 28 days | 7 days | `SH_Planning_FltDuty.daysFreeRequirements[0]` | IMPLEMENTED |
| FD20.3(a) | Min 24 days free in any consecutive 84 days | 24 days | `SH_Planning_FltDuty.daysFreeRequirements[1]` | IMPLEMENTED |
| FD20.3(b) | Min 8 days free in any calendar month | 8 days | `SH_Planning_FltDuty.daysFreeRequirements[2]` | IMPLEMENTED |
| FD20.3(c) | Min 26 days free in any 3 consecutive calendar months | 26 days | `SH_Planning_FltDuty.daysFreeRequirements[3]` | IMPLEMENTED |

---

## CHAPTER 1B — OPERATIONAL

---

### FD21 — Flight Time Limits (Operational)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD21.1(a) | Max flight time in any consecutive 28 days | 100 hrs | `SH_Operational_FltDuty.cumulativeFlightTime28DaysHours` | IMPLEMENTED |
| FD21.1(b) | Max flight time in any consecutive 365 days | 1,000 hrs | `SH_Operational_FltDuty.cumulativeFlightTime365DaysHours` | IMPLEMENTED |

---

### FD22 — Cumulative Duty Time Limits (Operational)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD22.1(a) | Max cumulative duty in any consecutive 7 days | 60 hrs | `SH_Operational_FltDuty.cumulativeDutyTime7DaysHours` | IMPLEMENTED |
| FD22.1(b) initial | Max cumulative duty in any 14 days (initial roster) | 90 hrs | `SH_Operational_FltDuty.cumulativeDutyTime14DaysInitialHours` | IMPLEMENTED |
| FD22.1(b) extended | Max cumulative duty in any 14 days (pilot agreement) | 100 hrs | `SH_Operational_FltDuty.cumulativeDutyTime14DaysExtendedHours` | IMPLEMENTED |
| FD22.1 | Simulator/training duty factor (trainee/support, excl. line training/checks/DH) | ×1.5 | `SH_Operational_FltDuty.simulatorTrainingDutyFactor` | IMPLEMENTED |
| FD28.6(a) | Max duty days in any 11-day period | 9 days | `SH_Operational_FltDuty.maxDutyDaysIn11Days` | IMPLEMENTED |
| FD28.6(b) | Max consecutive duty days | 6 days | `SH_Operational_FltDuty.maxConsecutiveDutyDays` | IMPLEMENTED |
| FD28.4(a) | Min 36 consecutive hours free of duty in any 7 consecutive days | 36 hrs | `SH_Operational_FltDuty.minHoursFreeIn7ConsecutiveDays` | IMPLEMENTED |
| FD28.4(b) | Alternative: 2 consecutive local nights in any 8 nights (start ≤ 2200, end ≥ 0500) | 2 nights | `SH_Operational_FltDuty.minConsecutiveLocalNightsIn8Nights` | IMPLEMENTED |

---

### FD23 — Maximum Duty Periods (Operational)

#### FD23.1 — 2 Pilot Duty Period Limits

| Clause | Local Start | Sectors | Max Duty | Swift Implementation | Status |
|---|---|---|---|---|---|
| FD23.1 | 0500–1259 | 1–4 | 14 hrs | `SH_Operational_FltDuty.twoPilotDutyLimits[.early].maxDutySectors1to4` | IMPLEMENTED |
| FD23.1 | 0500–1259 | 5 | 13 hrs | `SH_Operational_FltDuty.twoPilotDutyLimits[.early].maxDutySectors5` | IMPLEMENTED |
| FD23.1 | 0500–1259 | 6 | 12 hrs | `SH_Operational_FltDuty.twoPilotDutyLimits[.early].maxDutySectors6` | IMPLEMENTED |
| FD23.1 | 1300–1759 | 1–4 | 13 hrs | `SH_Operational_FltDuty.twoPilotDutyLimits[.afternoon].maxDutySectors1to4` | IMPLEMENTED |
| FD23.1 | 1300–1759 | 5 | 12 hrs | `SH_Operational_FltDuty.twoPilotDutyLimits[.afternoon].maxDutySectors5` | IMPLEMENTED |
| FD23.1 | 1300–1759 | 6 | 11 hrs | `SH_Operational_FltDuty.twoPilotDutyLimits[.afternoon].maxDutySectors6` | IMPLEMENTED |
| FD23.1 | 1800–0459 | 1–4 | 12 hrs | `SH_Operational_FltDuty.twoPilotDutyLimits[.night].maxDutySectors1to4` | IMPLEMENTED |
| FD23.1 | 1800–0459 | 5 | 12 hrs | `SH_Operational_FltDuty.twoPilotDutyLimits[.night].maxDutySectors5` | IMPLEMENTED |
| FD23.1 | 1800–0459 | 6 | 11 hrs | `SH_Operational_FltDuty.twoPilotDutyLimits[.night].maxDutySectors6` | IMPLEMENTED |

#### FD23.1 — 3 Pilot Duty Period Limits (max 3 sectors; total min rest ≥ 2 hrs)

| Clause | Local Start | Rest Facility | Max Duty | Swift Implementation | Status |
|---|---|---|---|---|---|
| FD23.1 | 0500–1259 | Class 2 | 16 hrs | `SH_Operational_FltDuty.threePilotDutyLimits[.early].class2MaxDuty` | IMPLEMENTED |
| FD23.1 | 0500–1259 | Business Seat | 14.5 hrs | `SH_Operational_FltDuty.threePilotDutyLimits[.early].businessSeatMaxDuty` | IMPLEMENTED |
| FD23.1 | 1300–1759 | Class 2 | 16 hrs | `SH_Operational_FltDuty.threePilotDutyLimits[.afternoon].class2MaxDuty` | IMPLEMENTED |
| FD23.1 | 1300–1759 | Business Seat | 13.5 hrs | `SH_Operational_FltDuty.threePilotDutyLimits[.afternoon].businessSeatMaxDuty` | IMPLEMENTED |
| FD23.1 | 1800–0459 | Class 2 | 16 hrs | `SH_Operational_FltDuty.threePilotDutyLimits[.night].class2MaxDuty` | IMPLEMENTED |
| FD23.1 | 1800–0459 | Business Seat | 12.5 hrs | `SH_Operational_FltDuty.threePilotDutyLimits[.night].businessSeatMaxDuty` | IMPLEMENTED |

#### FD23.1 — Augmented Duty Period Limits

Same values as planning (FD13.1) — screened seat 16 hrs, pax compartment 14 hrs.

| Clause | Rest Facility | Max Duty | Swift Implementation | Status |
|---|---|---|---|---|
| FD23.1 | Separate screened seat | 16 hrs | `SH_Operational_FltDuty.augmentedDutyLimits[.separateScreenedSeat]` | IMPLEMENTED |
| FD23.1 | Passenger compartment seat | 14 hrs | `SH_Operational_FltDuty.augmentedDutyLimits[.passengerCompartmentSeat]` | IMPLEMENTED |

#### FD23.2 — EPT Extension

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD23.2 | Max duty for EPT at non-home base | 15 hrs | `SH_Operational_FltDuty.emergencyProceduresTrainingMaxDutyHours` | IMPLEMENTED |

#### FD23.3 — Reserve Duty

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD23.3 | Max reserve duty (consecutive hours) | 12 hrs | `SH_Operational_FltDuty.reserveDutyMaxConsecutiveHours` | IMPLEMENTED |

#### FD23.4 — Reserve Callout Combined Limit

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD23.4 | Max combined reserve + subsequent duty (standard) | 16 hrs | Referenced in `FRMSCalculationService` | PARTIAL |
| FD23.4(c) | Operational necessity extension: max combined reserve + duty | 18 hrs | `SH_Operational_FltDuty.reserveCombinedMaxDutyHoursOperationalNecessity` | IMPLEMENTED |

#### FD23.5 — Reserve Night Period Exclusion

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD23.5 | Reserve starting 2300–0600: time before callout excluded from combined limit | 2300–0600 | Not implemented as explicit constant | NOT IMPLEMENTED |

#### FD23.3 — 2 Pilot Flight Time Limits (Operational)

Same conditions and values as planning (FD13.3).

| Clause | Condition | Max Flight Time | Swift Implementation | Status |
|---|---|---|---|---|
| FD23.3 | >7 hrs flight time in darkness | 9.5 hrs | `SH_Operational_FltDuty.twoPilotFlightTimeLimits[.darknessHeavy]` | IMPLEMENTED |
| FD23.3 | More than 1 sector scheduled | 10.0 hrs | `SH_Operational_FltDuty.twoPilotFlightTimeLimits[.multiSector]` | IMPLEMENTED |
| FD23.3 | All other occasions | 10.5 hrs | `SH_Operational_FltDuty.twoPilotFlightTimeLimits[.standard]` | IMPLEMENTED |

#### FD23.4 — Augmented Flight Time Limits (Operational)

| Clause | Condition | Max Flight Time | Swift Implementation | Status |
|---|---|---|---|---|
| FD23.4 | All occasions | 10.5 hrs | `SH_Operational_FltDuty.augmentedFlightTimeLimitHours` | IMPLEMENTED |

---

### FD24 — Late Night Operations, Back of Clock Operations and Early Starts (Operational)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD24.1 | Max consecutive LNO flying duties before 24-hr free period required | 2 consecutive | `SH_Operational_FltDuty.lateNightMaxConsecutiveNights` (see FD14.1 note) | NEEDS REVIEW |
| FD24.2 | Max LNO flying duty periods in rolling 168 hrs | 4 | `SH_Operational_FltDuty.lateNightMaxDutiesIn168Hours` | IMPLEMENTED |
| FD24.3 | FD24.1 and FD24.2 not applicable to reserve duty periods | exempt | Applied in `FRMSCalculationService` | IMPLEMENTED |
| FD24.4 | Max BOC flying duty periods in rolling 168 hrs | 2 | `SH_Operational_FltDuty.backOfClockMaxDutiesIn168Hours` | IMPLEMENTED |
| FD24.5 | Following BOC duty: next sign-on (if in Australia) no earlier than 1000 LT | 1000 LT | **Missing from `SH_Operational_FltDuty`** — only in `SH_Planning_FltDuty.backOfClockEarliestSignOnLocalHHMM` | PARTIAL |
| FD24 | FD14.6 equivalent (max 4 consecutive early starts) | **Not present in Chapter 1B** | Not applicable | NOT APPLICABLE |

> **DISCREPANCY FD24.5:** The BOC 1000 LT next-day sign-on restriction is in the operational chapter (FD24.5) but `backOfClockEarliestSignOnLocalHHMM` only exists in `SH_Planning_FltDuty`. The `FRMSCalculationService` should apply this from the operational model when computing operational limits.

---

### FD25 — Deadheading Following a Flight Duty (Operational)

Same rules as FD15 (Planning), referencing FD23.1 operational limits.

| Clause | Rule | Swift Implementation | Status |
|---|---|---|---|
| FD25.1–25.5 | Same as FD15.1–15.5 with FD23.1 reference | Applied in `FRMSCalculationService` | PARTIAL |
| FD25.6 | No duty period with flight duty to exceed 16 hrs | `SH_Operational_FltDuty.deadheadingAbsoluteMaxDutyHours` | IMPLEMENTED |

---

### FD26 — Pilot Projected to Exceed Limits (Operational)

| Clause | Rule | Swift Implementation | Status |
|---|---|---|---|
| FD26.1 | Remove minimum flight duty to avoid breach | Informational only | NOT IMPLEMENTED |

---

### FD27 — Split Duty (Operational)

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD27.1 | Split duty requires: no reasonable alternative; and pilot consent | conditions | Not modelled (operational/scheduling decision) | NOT APPLICABLE |
| FD27.2 | Min rest at **sleeping** accommodation: +4 hrs duty, max 16 hrs; 50% rest discount, max 4 hrs | 6 hrs rest; +4 hrs; 50% discount | `SH_Operational_FltDuty.splitDutyRulesBySleeping` | IMPLEMENTED |
| FD27.3 | Min rest at **resting** accommodation: +2 hrs duty only; no discount | 6 hrs rest; +2 hrs; no discount | `SH_Operational_FltDuty.splitDutyRulesByResting` | IMPLEMENTED |
| FD27.4 | If rest includes 2300–0530: 7 hrs uninterrupted; max 16 hrs; no discount | 7 hrs; 2300–0530 | `SH_Operational_FltDuty.splitDutyRulesBySleeping.nightWindow*` | IMPLEMENTED |

---

### FD28 — Time Free from Duty (Operational)

#### 2 Pilot Operations

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD28.1 | Min TFD if previous duty ≤ 12 hrs | max(10 hrs, previous duty) | `SH_Operational_FltDuty.timeFreeFromDuty.minimumRestHours` | IMPLEMENTED |
| FD28.1 | If previous duty > 12 hrs: 12 hrs + 1.5 × (duty − 12 hrs) | formula | `SH_Operational_FltDuty.timeFreeFromDuty.formula` | IMPLEMENTED |
| FD28.2 | If previous duty ≤ 10 hrs AND rest includes 2200–0600: reduced rest | 9 hrs | `SH_Operational_FltDuty.timeFreeFromDuty.reducedRestConditions` | IMPLEMENTED |
| FD28.3 | Standby with no callout: min TFD afterward | 10 hrs | `SH_Operational_FltDuty.timeFreeFromDuty` (standby clause) | IMPLEMENTED |

#### 3 Pilot (Augmented) Operations — Post-Pattern Rest

| Clause | TAFB | Day Return | Multi-day Pattern | Swift Implementation | Status |
|---|---|---|---|---|---|
| FD28 | ≤ 52 hrs | 12 hrs | 12 hrs (or formula if last duty > 12 hrs; next duty > 9.59 hrs)¹ | `SH_Operational_FltDuty.threePilotPatternRestRequirements[0]` | IMPLEMENTED |
| FD28 | 52+ to < 124 hrs | N/A | 12 hrs + 1.5 × (duty − 12 hrs) (next duty > 9.59 hrs)¹ | `SH_Operational_FltDuty.threePilotPatternRestRequirements[1]` | IMPLEMENTED |
| FD28 | ≥ 124 hrs | N/A | 22 hrs | `SH_Operational_FltDuty.threePilotPatternRestRequirements[2]` | IMPLEMENTED |

¹ Refer to FD24.5 (BOC sign-on restriction)

#### All Operations

| Clause | Rule | Value | Swift Implementation | Status |
|---|---|---|---|---|
| FD28.4(a) | Min 36 consecutive hours free in any 7 days | 36 hrs | `SH_Operational_FltDuty.minHoursFreeIn7Days` | IMPLEMENTED |
| FD28.4(b) | Alternative: 2 consecutive local nights (start ≤ 2200, end ≥ 0500) in any 8 nights | 2 nights | `SH_Operational_FltDuty.minConsecutiveLocalNightsIn8NightsFree` | IMPLEMENTED |
| FD28.6(a) | Max duty days in any 11-day period | 9 days | `SH_Operational_FltDuty.maxDutyDaysIn11Days` | IMPLEMENTED |
| FD28.6(b) | Max consecutive duty days | 6 days | `SH_Operational_FltDuty.maxConsecutiveDutyDays` | IMPLEMENTED |
| FD28.7(a) | Min 7 days free in any consecutive 28 days; min 24 days free in any 84 days | 7 / 24 days | `SH_Operational_FltDuty.daysFreeRequirements[0,1]` | IMPLEMENTED |
| FD28.7(b) | Min 8 days free in any calendar month | 8 days | `SH_Operational_FltDuty.daysFreeRequirements[2]` | IMPLEMENTED |
| FD28.7(c) | Min 26 days free in any 3 consecutive calendar months | 26 days | `SH_Operational_FltDuty.daysFreeRequirements[3]` | IMPLEMENTED |

---

## Known Gaps and Discrepancies

1. **FD14.1 / FD24.1 — `lateNightMaxConsecutiveNights` value vs. PDF rule:** The PDF says recovery required after >**2** consecutive LNO duties. The Swift constant is named/valued as 4 (matching the LNO-in-168-hour limit). Verify that `FRMSCalculationService` triggers the 24-hr recovery at `consecutiveLateNights > 2` not `>= 4`.

2. **FD24.5 BOC 1000 LT restriction — missing from Operational model:** `backOfClockEarliestSignOnLocalHHMM = 1000` exists only in `SH_Planning_FltDuty`. The same restriction applies operationally (FD24.5). Add to `SH_Operational_FltDuty`.

3. **FD13.4 / FD23.4 Reserve Night Exclusion (2300–0600):** The rule that time before callout during 2300–0600 is excluded from the combined reserve+duty limit is not encoded as a named constant in either planning or operational models.

4. **FD15.4 / FD25.4 — DH sector counting logic:** Whether the last DH sector is excluded from sector count for duty period determination is not explicitly modelled as a rule in the Swift model — it may be applied ad hoc in the calculation service.

5. **FD16 / FD26 — Projected to exceed limits:** No implementation. These are procedural rules (remove minimum duty to fix breach) rather than calculable limits.

6. **`FRMSData.swift` header comment:** States "Rev 4.1 (A320/B737)" — should read Rev 5 (15 June 2026).

7. **FD20.1(b) / FD28.4(b) — 2 consecutive local nights alternative:** The night-window alternative to the 36-hr rule is tracked in `FRMSCumulativeTotals` but it is unclear if it is fully computed and surfaced in the UI.

8. **NZ-based crew (FD40–FD68):** Not in scope for this app. Confirm with Nelson if NZ pilots use the app.

---

*Last updated: 2026-06-08 | Source: QF FRMS Ruleset A320/B737 Rev 5, 15 June 2026*
