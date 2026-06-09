# SH FRMS — Rev 4.2 → Rev 5 Change Summary (Australia-Based Crew)

Document: A320/B737 FRMS Ruleset Revision 5, Issue Date: 15 June 2026  
Scope: Chapters 1A (Planning) and 1B (Operational) — Australia-based crew only

---

## Chapter 1A — Planning

### FD13 — Maximum Duty Periods (Planning)

**2-pilot start time bands have shifted:**

| Band | Rev 4.2 | Rev 5 |
|---|---|---|
| Early | 0500–1459 | 0500–1259 |
| Mid | 1500–1959 | 1300–1759 |
| Night | 2000–0459 | 1800–0459 |

Duty hour values (12/11/10 for sectors 1–4, 11/10/10 for sectors 5–6) are unchanged. The band shift means duties starting 1300–1459 now fall in the mid band (11 hrs) instead of the early band (12 hrs).

**New 3-pilot planning table (max 2 sectors):**

| Local start time | Class 2 | Business Seat | Notes |
|---|---|---|---|
| 0500–1259 | 14 hrs | 14 hrs | Total min rest period of not less than 2 hours |
| 1300–1759 | 14 hrs | 13 hrs | |
| 1800–0459 | 14 hrs | 12 hrs | |

This entire table is new — not in our current implementation.

---

### FD14 — Late Night Operations, Back of Clock Operations and Early Starts (Planning)

Restructured significantly. Key changes vs Rev 4.2:

- FD14.1: >2 consecutive LNO duties → 24 hrs free of duty before any other flying duty (same concept, reworded)
- FD14.2: Max **4 LNO** flying duty periods in **168 hours** (previously framed as "4 consecutive nights in any 7-night period")
- FD14.3: FD14.1 & FD14.2 not applicable for reserve duty periods
- FD14.4: Max **2 BOC** flying duty periods in **168 hours** — **NEW** (waivable by pilot)
- FD14.5: BOC duty → next sign-on in Australia no earlier than **1000 local** the following day (waivable) — same rule, new clause number
- FD14.6: Max **4 consecutive** duties with sign-on prior to **0706** local — was "0700" in Rev 4.2

**Removed from Rev 4.2:**
- 40-hour duty limit in any 7-night period with >2 LNO duties
- 4-duty-periods limit in 7-night period
- 24-hour free of duty after consecutive late nights rule
- "5 nights once per 28 days" exception

---

### FD19 — Time Free After Pattern for Roster Construction (Planning)

2-pilot rules (FD19.1/FD19.2) unchanged (12 hrs after 1–2 day pattern, 15 hrs after 3–4 day pattern).

**New 3-pilot augmented rest table:**

| TAFB (hours) | Day return | Multi-day pattern |
|---|---|---|
| ≤52 | 14.5 hrs | 15 hrs (next duty day >9.59 hrs) |
| 52+ to <124 | N/A | 22 hrs (next duty day >9.59 hrs) |
| 124+ | N/A | 32 hrs |

Note: Refer to FD14.5 for BOC early start restriction.  
Entirely new — not in our current implementation.

---

## Chapter 1B — Operational

### FD23 — Maximum Duty Periods (Operational)

**2-pilot start time bands — same shift as planning:**

| Band | Rev 4.2 | Rev 5 |
|---|---|---|
| Early | 0500–1459 | 0500–1259 |
| Mid | 1500–1959 | 1300–1759 |
| Night | 2000–0459 | 1800–0459 |

Sector 1–4 / Sector 5 / Sector 6 values (14/13/12, 13/12/11, 12/12/11) are unchanged.

**Pilot discretion language:** Rev 4.2 had a standalone note below the table. Rev 5 moves the condition into the FD23.1 preamble — duty extension now explicitly requires both operational necessity AND pilot fitness affirmation (not just advisory).

**New 3-pilot operational table (max 3 sectors):**

| Local start time | Class 2 | Business Seat | Notes |
|---|---|---|---|
| 0500–1259 | 16 hrs | 14.5 hrs | Total min rest period of not less than 2 hours |
| 1300–1759 | 16 hrs | 13.5 hrs | |
| 1800–0459 | 16 hrs | 12.5 hrs | |

Entirely new — not in our current implementation.

---

### FD23 — Reserves (Operational)

FD23.4 adds a **new third exception** to the 16-hour max combined reserve+duty period:

> (c) When it is operationally necessary in order to complete the objective of the duty and the pilot considers themselves physically and mentally fit for operation, the maximum combined duration can be **18 hours**.

Rev 4.2 only had two exceptions (augmented crew, split duty).

---

### FD24 — Late Night Operations, Back of Clock Operations and Early Starts (Operational)

Same restructure as FD14 on the planning side:

- FD24.1: >2 consecutive LNO → 24 hrs free before any other flying duty
- FD24.2: Max **4 LNO** in **168 hours**
- FD24.3: FD24.1 & FD24.2 not applicable for reserve
- FD24.4: Max **2 BOC** in **168 hours** (waivable) — **NEW**
- FD24.5: BOC → next sign-on ≥1000 local (waivable) — same rule, renumbered

**Removed from Rev 4.2:** 40-hr limit, 4-periods-in-7-nights, 24-hr-after-consecutive-late-nights, 5-nights-once-per-28-days exception.

---

### FD28 — Time Free from Duty (Operational)

2-pilot rules unchanged (FD28.1/28.2/28.3).

**New 3-pilot augmented rest table:**

| TAFB (hours) | Day return | Multi-day pattern |
|---|---|---|
| ≤52 | 12 hrs | 12 hrs; or if last duty >12 hrs: 12 + 1.5× time over 12 hrs (next duty day >9.59 hrs) |
| 52+ to <124 | N/A | Same formula (next duty day >9.59 hrs) |
| 124+ | N/A | 22 hrs (next duty day >9.59 hrs) |

Note: Refer to FD24.5.  
Entirely new — not in our current implementation.

---

## Implementation Impact Summary

| Area | Priority | Detail |
|---|---|---|
| 2-pilot duty time bands | **High** | Start times shift — 1300–1459 duties get 11 hrs (not 12 hrs) for 1–4 sectors. Affects `calculateMaximumNextDuty` lookup table. |
| 3-pilot planning limits | **New feature** | Entire table missing — Class 2 vs Business Seat by start time, max 2 sectors |
| 3-pilot operational limits | **New feature** | Entire table missing — Class 2 vs Business Seat by start time, max 3 sectors |
| Post-augmented rest tables (planning & operational) | **New feature** | TAFB-based rest matrix for 3-pilot patterns |
| LNO section restructure | **Medium** | BOC 2-in-168-hours limit is new; 40-hr / 5-night rules removed |
| Early starts threshold | **Low** | "0700" → "0706" |
| Reserve call-out max combined duration | **Medium** | 18-hour max added as new exception (was 16 hrs max) |
