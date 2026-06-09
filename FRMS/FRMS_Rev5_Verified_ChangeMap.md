# FRMS Revision 5 — Verified Change Map

**Purpose:** Independent, clean-room verification of the V4 → Revision 5 changes for both rulesets, reconciled against the two pre-existing draft notes (`FRMS_SH_Rev5_Changes.md`, `FRMS_LH_Rev5_Changes.md`).

**Method:** Text extracted directly from the four PDFs (watermark stripped), compared clause-by-clause. Every entry below cites the document and **page number printed in the PDF**. Nothing here is inferred; where a draft note could not be confirmed it is marked accordingly.

**Sources**

- SH old: `FRMS_Ruleset_V4_2_A320_B737.pdf` (Revision 4.2, 30 pp)
- SH new: `A320_B737_FRMS_Ruleset_Revision_5.pdf` (Revision 5, Issue 15 June 2026, 34 pp)
- LH old: `FRMS_Ruleset_V4_1_A380_A330_B787.pdf` (Revision 4.1, 30 pp)
- LH new: `A380_A330_B787_FRMS_Ruleset_Revision_5.pdf` (Revision 5, Issue 15 June 2026, 32 pp)

**Legend:** ✅ draft note correct · ⚠️ draft note imprecise · ❌ draft note wrong · ➕ real change the draft note omitted

---

## A. Corrections to the existing draft notes (read this first)

These are the items where the pre-existing `_Changes.md` files are **wrong, backwards, or missing**. Each is verified against the PDFs below.

| # | Note | Draft note says | Verified fact (PDF) | Severity |
|---|---|---|---|---|
| 1 | SH | FD14.6 early-start threshold changed "0700 → 0706" | **No change.** V4.2 FD13.6 already says **0706** (V4.2 p12); Rev5 FD14.6 says **0706** (Rev5 p14). The Swift code on `main` already stores `706`. | ❌ + no-op |
| 2 | SH | (silent) | Rev5 **removes the SH 2-pilot and augmented flight-time limits** (V4.2 FD13.3/13.4 = 9.5/10/10.5 & 10.5, p12; FD23.3/23.4, p16). Those clause numbers are reused for reserve rules in Rev5. `SH_FRMS_Evaluation.txt` lists these FT limits as still modelled. | ➕ major |
| 3 | SH | FD23.4 "adds a **third** exception to the existing 16-hour reserve call-out" | V4.2 has **no reserve call-out / combined-duration clause** in this chapter at all. The whole clause (16 h + exceptions (a) augmented, (b) split, **(c) 18 h**) is new in Rev5 (p19). The 18 h is new along with everything else. | ⚠️ |
| 4 | SH | (silent) | **FD2.2 local-midnight** definition changed from one reference port to **per-base** ports (see B-1). | ➕ |
| 5 | LH | FD3.2.1(c) pilot-discretion rest reduction **"Removed … gone in Rev 5"** | **Retained, reworded.** V4.1 p13 "*At the pilot's discretion*, the above pre-duty rest may be reduced…"; Rev5 p14 "**(c) If the pilot considers themselves physically and mentally fit for duty**, the above pre-duty rest may be reduced…". The provision still exists. | ❌ major |
| 6 | LH | Crew-rest Class 2 aircraft "A330-200 **ALL** → A330-200**L** … narrows scope" | **Backwards.** V4.1 p13 says "A330-200**L** (International Configuration)…seat 5A"; Rev5 p15 says "A330-200 **ALL** dedicated crew rest area located at seat 5A". The change is **L → ALL (broadens)**. | ❌ major |
| 7 | LH | FD6.2 "total flight time in any consecutive **28 days**: 100 hours (**unchanged**)" | **Period changed.** V4.1 FD6.2 = "any consecutive **30 days**" (p17); Rev5 FD6.2 = "any consecutive **28 days**" (p18). Value 100 h unchanged; the window changed 30→28. | ❌ |
| 8 | LH | FD6.3 "roster promulgation limit: **950 hours** … (**unchanged**)" | **Changed.** V4.1 FD6.3 = **900 hours**/365 days (p17); Rev5 FD6.3 = **950 hours**/365 days (p18). | ❌ |
| 9 | LH | FD6.1 "clarified that the 50-hour duty count **explicitly includes Standbys**" | The "(including Standbys)" text is in **both** V4.1 (p17) and Rev5 (p18) — not new. The real Rev5 change is "duty" → "**completed** duty" plus a new sentence permitting a duty to start before 50 h is reached and be completed in full. | ⚠️ |
| 10 | LH | (silent) | **FD11 (operational cumulative) changed**: FD11.4 30→**28 days** (100 h); FD11.5 900→**1000 hours**/365 days (V4.1 p26 → Rev5 p28). The note covers FD6 but omits the parallel FD11 changes. | ➕ |
| 11 | LH | (silent) | **FD2 — CASA definition alignment** (Rev5 Revision Record, p3). E.g. "Acclimated" redefined; detailed acclimatisation logic moved to definitions per FD3.2.3(e). Low implementation impact but real. | ➕ |

The Rev5 LH document's own **Revision Record (Rev5 p3)** is an authoritative change list and corroborates items 5–11. It reads: *FD2 alignment to CASA definitions; FD3.1 & FD10.1 removal of flight time limits for 2 and 3 pilot; FD3.2.1 clarification; FD3.2.1 & FD3.3 & FD10.4 & FD14.1.1 removal of pilot discretion replaced by physically and mentally fit; FD3.3.2 clarification of aircraft type crew rest; FD3.2.3(e) acclimated zone moved to definitions; FD3.4 and FD10.4 inclusion of Perth to Paris; FD3.4.4 moved to FD10.4; FD6 clarification of 50 h completed duty, update to 28 and 365 day flight time; FD6.6.3(b) updated 2 pilot cumulative rest; FD10.1 4-pilot additional crew rest facility; FD10.2 application of duty limitations; FD10.4 inclusion of S/O min rest post relevant sector.* The SH Rev5 document has no comparable Rev5 entry in its Revision Record.

---

## B. Short Haul (A320/B737): Rev 4.2 → Rev 5 — verified

Scope of the existing SH draft note is "Australia-based crew" (chapters covering FD1–FD30). The NZ-based section (FD40–FD68) is addressed separately in section D.

### B-1. FD2.2 — Local midnight reference port  ➕ (omitted by note)
- **V4.2 (p8):** "the place for determining local midnight is **Sydney** for the Adelaide, Brisbane, Melbourne and Sydney bases and **Perth** for the Perth base."
- **Rev5 (p9):** "**Adelaide** for the Adelaide base, **Brisbane** for the Brisbane base, **Sydney** for the Melbourne and Sydney bases and **Perth** for the Perth base."
- Effect: local midnight is now determined per home base. Affects any local-midnight-dependent logic (LNO/BOC windows).

### B-2. FD13.1 — 2-pilot duty bands (Planning)  ✅
Band boundaries shifted; **hour values unchanged**.

| Band | V4.2 (p11) | Rev5 (p13) | S1–4 | S5–6 |
|---|---|---|---|---|
| Early | 0500–1459 | **0500–1259** | 12 | 11 |
| Mid | 1500–1959 | **1300–1759** | 11 | 10 |
| Night | 2000–0459 | **1800–0459** | 10 | 10 |

Net effect: a duty signing on 1300–1459 now falls in the mid band (11 h / 10 h) rather than early (12 h / 11 h).

### B-3. FD13.1 — NEW 3-pilot planning table (max 2 sectors)  ✅ (Rev5 p13)

| Local start | Class 2 | Business Seat |
|---|---|---|
| 0500–1259 | 14 h | 14 h |
| 1300–1759 | 14 h | 13 h |
| 1800–0459 | 14 h | 12 h |

Table note: "Total min rest period of not less than 2 hours."

### B-4. FD13.3 / FD13.4 — Flight time limits REMOVED  ➕ (omitted by note)
- **V4.2 (p12):** FD13.3 2-pilot FT limits — 9.5 h (>7 h darkness), 10 h (>1 sector), 10.5 h (otherwise); FD13.4 augmented FT limit 10.5 h.
- **Rev5:** these clause numbers are now **Reserves** clauses; no 2-pilot or augmented flight-time limits exist in SH planning.

### B-5. FD13.3–13.5 — Reserves (Planning)  ➕ (partly omitted)
- Rev5 FD13.3 (p14): reserve duty ≤ 12 consecutive hours (was FD13.5 in V4.2 — unchanged value).
- Rev5 **FD13.4 (p14, NEW):** if called out from reserve, max combined reserve + duty = **16 hours**, except (a) augmented crew operation, (b) split duty per FD17. *(V4.2 had no such clause in this chapter.)*
- Rev5 **FD13.5 (p14, NEW):** reserve starting 2300–0600 — that window does not count toward the FD13.4 combined limit until the crew member is contacted.

### B-6. FD14 — LNO / BOC / Early Starts (Planning)  ✅ (one ❌ inside)
Rev5 (p14):
- FD14.1 — > 2 consecutive LNO flying duties → 24 h free of duty before any other flying duty.
- FD14.2 — max **4 LNO** flying duty periods in **168 hours**.
- FD14.3 — FD14.1 & FD14.2 not applicable to reserve duty.
- FD14.4 — max **2 BOC** flying duty periods in **168 hours** (pilot may waive). **NEW.**
- FD14.5 — BOC → next flying duty in Australia sign-on ≥ 1000 local next day (pilot may waive).
- FD14.6 — max **4** consecutive duties signing on before **0706** local.

Removed from V4.2 (p12): 4-consecutive-nights-in-7 limit (FD14.1); 5-nights-once-per-28-days exception (FD14.2); 40 h-in-7-night-period limit and 4-duty-periods-in-7-night-period limit (FD14.3).

❌ **FD14.6 is not a change** — V4.2 FD13.6 (p12) already specified 0706.

### B-7. FD19 — Time free after pattern (Planning)  ✅ (Rev5 p16)
- 2-pilot: FD19.1 = 12 h after a 1–2 day pattern; FD19.2 = 15 h after a 3–4 day pattern. **Unchanged.**
- **NEW 3-pilot augmented rest table:**

| TAFB (h) | Day return | Multi-day pattern |
|---|---|---|
| ≤ 52 | 14.5 h | 15 h (next duty day > 9.59 h) |
| 52+ to < 124 | N/A | 22 h (next duty day > 9.59 h) |
| 124+ | N/A | 32 h |

Note: refer FD14.5 (BOC early-start restriction).

### B-8. FD20.1 — consecutive-nights clarification  ➕ (minor, omitted)
Rev5 (p16) adds sub-clauses (i)/(ii) defining how the "two consecutive local nights" window is counted relative to a 05:00 start. FD20.2 content renumbered.

### B-9. FD23.1 — 2-pilot duty bands (Operational)  ✅ / ⚠️
Same band shift as B-2; **hour values unchanged**.

| Band | V4.2 (p15) | Rev5 (p18) | S1–4 | S5 | S6 |
|---|---|---|---|---|---|
| Early | 0500–1459 | **0500–1259** | 14 | 13 | 12 |
| Mid | 1500–1959 | **1300–1759** | 13 | 12 | 11 |
| Night | 2000–0459 | **1800–0459** | 12 | 12 | 11 |

⚠️ Preamble wording: V4.2 "**At the discretion of the pilot** when it is operationally necessary … and the pilot considers himself or herself physically and mentally fit…"; Rev5 drops "At the discretion of the pilot" and opens "**When it is operationally necessary** … and the pilot considers himself or herself physically and mentally fit…". The fitness condition was present in **both**; only the discretion lead-in was removed. (The draft note's "standalone note → preamble" description is imprecise.)

### B-10. FD23.1 — NEW 3-pilot operational table (max 3 sectors)  ✅ (Rev5 p18)

| Local start | Class 2 | Business Seat |
|---|---|---|
| 0500–1259 | 16 h | 14.5 h |
| 1300–1759 | 16 h | 13.5 h |
| 1800–0459 | 16 h | 12.5 h |

Table note: "Total min rest period of not less than 2 hours."

### B-11. FD23.3 / FD23.4 — Flight time limits REMOVED  ➕ (omitted by note)
Same as B-4 but operational (V4.2 p16): FD23.3 2-pilot FT (9.5/10/10.5) and FD23.4 augmented FT (10.5) are gone in Rev5.

### B-12. FD23.3–23.5 — Reserves (Operational)  ⚠️ (Rev5 p19)
- FD23.3 — reserve duty ≤ 12 consecutive hours (unchanged value).
- **FD23.4 (NEW clause):** called out from reserve → max combined = **16 hours** except (a) augmented, (b) split per FD27, **(c) 18 hours** when operationally necessary and the pilot considers themselves physically and mentally fit. *(V4.2 had no reserve call-out clause here at all — see correction #3.)*
- FD23.5 — reserve 2300–0600 not counted until contacted (note: the Rev5 text cross-references "FD13.4" — a typo in the source; should be FD23.4).

### B-13. FD24 — LNO / BOC (Operational)  ✅ (Rev5 p19)
FD24.1–24.5 mirror FD14.1–14.5 (no operational early-start clause). Removed from V4.2 (p16): 40 h / 4-periods / 5-nights items.

### B-14. FD28 — Time free from duty (Operational)  ✅ + ➕ (Rev5 p21)
- 2-pilot FD28.1/28.2/28.3 unchanged.
- **NEW 3-pilot augmented rest table:**

| TAFB (h) | Day return | Multi-day pattern |
|---|---|---|
| ≤ 52 | 12 h | 12 h; or if last duty > 12 h then 12 h + 1.5 × time over 12 h (next duty day > 9.59 h) |
| 52+ to < 124 | N/A | same formula (next duty day > 9.59 h) |
| 124+ | N/A | 22 h (next duty day > 9.59 h) |

Note: refer FD24.5.
- ➕ **NEW FD28.5:** time-free completed at an upline port may, on request, satisfy the FD28.6/28.7 requirements. FD28.6/28.7 are the renumbered former FD28.4/28.5 content; FD28.4 gains the same consecutive-nights sub-clauses as FD20.1.

---

## C. Long Haul (A380/A330/B787): Rev 4.1 → Rev 5 — verified

### C-1. FD3.1 — Planning flight & duty tables  ✅
- **2-pilot (Rev5 p11 / V4.1 p9):** FLIGHT TIME LIMIT column **removed** (was 8 / 8.5 / 9.5 / 8 h by band). Duty period limits unchanged: 0500–0759 = 11; 0800–1359 = 11 (or 12, 1-day pattern only, max 4 sectors); 1400–1559 = 11; 1600–0459 = 10. Sector limits and pre/post-duty rest tables unchanged.
- **3-pilot (Rev5 p12 / V4.1 p10):** FLIGHT TIME LIMIT column **removed** (was Class 2 = 8.5 h, Class 1 = 12.5 h). Duty limits unchanged: Class 2 = 12 h, Class 1 = 14 h. Sector limit (3 if duty > 11, else max 4) unchanged.
- **4-pilot (Rev5 p13 / V4.1 p11):** column header **renamed** "FLIGHT TIME LIMIT" → "**INFLIGHT MANAGEMENT**" (same text: ≤ 8 continuous h on flight deck, ≤ 14 h total flight deck). Duty limits unchanged: 2×Class 2 = 16; 1×Class 1 & 1×Class 2 = 17.5; 2×Class 1 = 20.

### C-2. FD3.2.1(c) — Pre-duty rest reduction  ❌ note (Rev5 p14 / V4.1 p13)
**Retained, reworded** (see correction #5). Trigger changed from "At the pilot's discretion" to "If the pilot considers themselves physically and mentally fit for duty." The rest-reduction provision is **not** removed.

### C-3. FD3.2.2 — Crew rest aircraft types  ❌ note direction (Rev5 p15 / V4.1 p13)
- **Class 1 — unchanged** (both): A380-800; B787-9; A330-300 (International) dedicated crew rest; A330-200L (International) dedicated crew rest located mid-cabin.
- **Class 2 — changed:** V4.1 = "A330-200**L** (International Configuration) dedicated crew rest area located at seat 5A"; Rev5 = "A330-200 **ALL** dedicated crew rest area located at seat 5A". Direction is **L → ALL** (broadened), opposite to the draft note.

### C-4. FD3.4 — Relevant sectors (Planning)  ✅ (Rev5 p16 / V4.1 p15)
- Added **(f) Perth to Paris and vice versa**. Existing (a)–(e) unchanged: any planned duty > 18 h; SYD–DFW; MEL–DFW; PER–LHR; AKL–JFK.
- The downline-disruption rest limits that were embedded here in V4.1 are **moved to FD10.4** (operational) — planning FD3.4 now ends after the MBTT/home-transport provisions.
- Title qualifier "(A380 & B787 Only)" dropped from the heading (the 21 h relevant-sector limit in the 4-pilot operational table still states A380 & B787 only).

### C-5. FD6 — Cumulative limitations (Planning)  mixed (Rev5 p18 / V4.1 p17)
- **FD6.1** ⚠️ — "duty" → "**completed** duty"; new sentence allowing a duty to start before 50 h is reached and complete in full before the 24 h rest. "(including Standbys)" present in both versions.
- **FD6.2** ❌ note — flight time window **30 days → 28 days** (100 h unchanged).
- **FD6.3** ❌ note — roster promulgation **900 h → 950 h** per 365 days.
- **FD6.4** ✅ — 60 h / 7 days and 100 h / 14 days unchanged.
- **FD6.5** ✅ — 1.5× simulator/training factor unchanged.

### C-6. FD6.6.3(b) — 2-pilot cumulative rest (Planning)  ✅ (Rev5 p19)
One period free of all duty starting no later than **22:00** local and finishing not earlier than **05:00** local in any consecutive **8 nights** for a pilot operating entirely as 2-pilot crew.

### C-7. FD10.1 — Operational flight & duty tables  ✅ + ➕
- **2-pilot (Rev5 p23 / V4.1 p22):** FLIGHT TIME LIMIT column **removed** (was 9.5 / 10 / 10.5 h). The "11 planned / 12 pilot discretion" duty rows collapse to a single **12 h** duty period limit. Pre/post-duty rest unchanged.
- **3-pilot (Rev5 p24 / V4.1 p23):** duty limits unchanged — Seat in Pax = 14; Class 2 = 16; Class 1 = 18. Column renamed "FLIGHT TIME LIMIT" → "INFLIGHT MANAGEMENT".
- **4-pilot (Rev5 p25 / V4.1 p24):** two **NEW** crew-rest facility combinations:

| Crew rest facility | V4.1 | Rev5 |
|---|---|---|
| Seats in Pax compartment | 14 | 14 |
| **1×Class 2 REST & 1×Seat in Pax** | — | **16 (NEW)** |
| 2×Class 2 REST | 16 | 16 |
| **1×Class 1 REST & 1×Seat in Pax** | — | **18 (NEW)** |
| 1×Class 1 & 1×Class 2 REST | 20 | 20 |
| 2×Class 1 REST | 20 | 20 |
| 2×Class 1 REST (relevant sectors per FD10.4) | 21 (A380 & B787) | 21 (A380 & B787) |

  Column renamed to "INFLIGHT MANAGEMENT".

### C-8. FD10.2 — Application of Flight Duty Time Tables (Operational)  ➕ NEW (Rev5 p26)
New guidance section (commencement of take-off only if completable within limits; fastest flight time, ATC holding, INTER/TEMPO, en-route factors, diversion). Informational — no numeric limits.

### C-9. FD10.3.1 — Rest requirements post-disruption (Operational)  ✅ restructured (Rev5 p26)
Minimum rest after a disruption (pattern commenced): (i) per operational limits / pilot fitness, not exceeding the hourly rest limitations; (ii) 10 h, or previous duty hours (max 12) + 1.5× time over 12 h + timezone difference over 3 h; (iii) 24 h pre/post where duty was/was planned > 16 h.

### C-10. FD10.4 — Relevant sectors disruption limits (Operational)  ✅ + ➕ (Rev5 p27)
- **Moved** from V4.1 FD3.4.4 (planning) into the operational chapter.
- Relevant sectors include new **Perth to Paris**.
- Prior to operating a relevant sector: 22 h. After operating: (i) Captain OR F/O 27 h; (ii) Cap OR F/O & duty > 20 h → 36 h; (iii) Cap AND F/O 36 h; **(iv) Second Officer(s) 27 h — NEW**; (v) duty < 18 h → Chapter 1B per FD10.1; (vi) duty > 18 h, pilot physically/mentally fit, next sector FT < 4 h → 24 h then 36 h before next relevant sector. Inbound to Aus/NZ: 36 h (same time zone) / 22 h (domestic or trans-Tasman).
- "At crew discretion" in (vi) replaced by "physically and mentally fit".

### C-11. FD11 — Cumulative limitations (Operational)  ➕ (omitted by note) (Rev5 p28 / V4.1 p26)
- FD11.3 — 30 h / 7 days for 2-pilot operations — unchanged.
- **FD11.4 — 30 days → 28 days** (100 h).
- **FD11.5 — 900 h → 1000 h** per 365 days.

### C-12. FD2 — Definitions (CASA alignment)  ➕ (omitted by note)
Per Revision Record (Rev5 p3). Example verified: "Acclimated" redefined ("the local time at the location where an FCM is acclimatised") vs V4.1's "remained within for 72 hours … within three time zones"; the detailed acclimatisation logic relocates to definitions per FD3.2.3(e). Low implementation impact; flagged for completeness.

---

## D. Out-of-(note)-scope items found

- **SH NZ-based crew (FD40–FD68):** the SH draft note is explicitly Australia-based-crew only. The Rev5 SH document also contains a NZ-based section. At least one numeric change exists there: **FD42.1/FD42.2 minimum rostered days off 10 → 11** (V4.2 p20 → Rev5 p23). This section has **not** been exhaustively diffed because it appears outside the app's current SH model scope — **confirm whether Block-Time models NZ-based SH crew** before relying on this.

---

## E. Net implementation impact (summary)

**SH — code/HTML changes required**
1. Shift 2-pilot duty bands to 0500–1259 / 1300–1759 / 1800–0459 (planning FD13.1 & operational FD23.1). Row values stay the same.
2. **Remove** 2-pilot and augmented flight-time limits (planning FD13.3/13.4, operational FD23.3/23.4) from models and HTML.
3. **Add** 3-pilot Class 2 / Business Seat duty tables (planning, max 2 sectors; operational, max 3 sectors) — new structure.
4. **Add** post-augmented TAFB rest tables (planning FD19; operational FD28).
5. Replace the LNO model: drop 4-nights/5-per-28/40 h/4-periods; add >2-consecutive-LNO → 24 h, 4 LNO / 168 h, 2 BOC / 168 h (waivable), reserve exemption.
6. **Add** reserve call-out combined-duration rule (16 h; exceptions augmented, split; operational also 18 h).
7. Update FD2.2 local-midnight handling to per-base ports.
8. No change needed for early-start threshold — already 0706 / `706`.

**LH — code/HTML changes required**
1. **Remove** flight-time limits for 2-pilot and 3-pilot (planning FD3.1 & operational FD10.1); rename the 4-pilot/3-pilot column to "Inflight Management".
2. Reword FD3.2.1(c) trigger (discretion → physically/mentally fit) — **keep** the provision.
3. Crew-rest Class 2 aircraft: **A330-200L → A330-200 ALL**.
4. Add **Perth to Paris** to relevant sectors (FD3.4 planning and FD10.4 operational).
5. Move relevant-sector disruption limits to operational FD10.4; add **Second Officer 27 h**.
6. FD6.2 30→28 days; FD6.3 900→950 h; FD11.4 30→28 days; FD11.5 900→1000 h.
7. Add 4-pilot operational rest combos: 1×Class 2 + 1×Seat = 16 h; 1×Class 1 + 1×Seat = 18 h.
8. FD6.1 "completed duty" wording + new sentence; FD6.6.3(b) 8-night rest wording; FD10.2 new guidance section; FD2 CASA definitions.

Detailed Swift edits are in `FRMS_Rev5_Swift_Change_Spec.md`. HTML edits are applied in the four `*_frms_*_limits.html` files.
