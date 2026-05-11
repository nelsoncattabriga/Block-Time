# Features Research

**Domain:** Professional airline pilot logbook (iOS/Mac)
**Researched:** 2026-05-07
**Scope:** Table stakes, differentiators, anti-features, regulatory requirements

---

## Table Stakes (users expect these — absence causes churn)

These features exist in every credible competitor (LogTen, Logbook Pro, APDL, ForeFlight Logbook). Missing any one causes immediate rejection.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Flight entry — core fields | Date, dep/arr airport, aircraft type/reg, block time, role (PIC/SIC/P2), day/night, takeoffs/landings | Low | Already in v1 |
| Simulator entry | Separate from flight time, FSTD type/name/location | Low | CASA + EASA require distinct SIM records |
| Time totals / running totals | Pilots constantly query total PIC, total hours, last 28 days, last 90 days, last year | Medium | Core of every currency check |
| Multi-role time fields | PIC, PICUS (P1U), SIC/P2, dual, instructor — not just "flight time" | Low | EASA FCL.050 mandates role separation |
| Night time | Separate logged field, not derived from departure time | Low | CASA CASR 61.345 explicitly requires it |
| Instrument approaches | Type of approach procedure logged per sector | Low | CASA + EASA + FAA all require this |
| Multi-engine / single-engine split | Separate time columns | Low | Standard logbook column |
| PDF export | Print-ready, professional layout for CASA/EASA/FAA compliance and airline interviews | Medium | CASA requires printed copy on request; recruiter standard |
| CSV export | Data portability — pilots fear vendor lock-in more than any other issue | Low | Non-negotiable for trust |
| iCloud sync across devices | iPhone + iPad + Mac seamless sync | Medium | Already in v1; pilots use multiple devices |
| Search and filter | Find flights by date range, aircraft, route, role | Medium | Baseline usability |
| Aircraft roster / type list | Pilots fly many types; app should remember aircraft with ICAO type designators | Low | Needed for autocomplete; EASA requires correct ICAO type |
| Bulk import (CSV) | Pilots transferring from paper or another app bring years of history | High | Must-have for new user acquisition |
| ACARS / roster import | Australian/airline-specific: parsing duty info from printed or digital rosters | High | Block-Time differentiator vs generic apps; already in v1 |
| Dashboard / totals view | At-a-glance summary — total hours, 90-day, last 28 days, night, IFR | Medium | Every competitor has this |
| Dark mode | Professional expectation in 2025 | Low | Already in v1 |

---

## Differentiators (competitive advantage — worth building well)

Features that set a logbook apart from the generic field. LogTen has most of these but executes them poorly (slow, buggy imports, confusing UI per user reviews).

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| FRMS / fatigue limit tracking | Real-time display of remaining FDP, cumulative duty, 28-day/90-day/365-day limits | High | Block-Time's primary differentiator; no other AU-focused app does LH + SH correctly |
| Local time entry with UTC storage | Pilots work in local time; logbooks require UTC — seamless conversion eliminates errors | Medium | Already in v1; confuses competitors |
| ACARS photo parsing | Snap photo of printed ACARS; app extracts times automatically | High | Already in v1; genuinely unique in AU market |
| Spreadsheet view | Power-user view for auditing and bulk corrections | Medium | Already in v1 |
| Flight map | Visual route history on map | Medium | Already in v1; pilots love it but rarely act on it |
| Widget (next flight / hours summary) | Lock screen / home screen at-a-glance | Medium | Already in v1 |
| Offline-first | Full functionality without network; sync on reconnect | Medium | Critical for pilots in remote airspace or international |
| Smart defaults / autofill | Remember crew, aircraft, routes — reduce entry time to under 30 seconds per sector | Medium | Top complaint driver in competitor reviews |
| Per-flight crew tracking | Record FO/captain name for hire, multi-crew currency evidence | Low | Required for some airline applications |
| Calendar export (.ics) | Roster visibility in native calendar | Low | Already in v1; pleasant differentiator |
| Approach type statistics | Count and chart ILS, RNAV, visual approaches over time | Low | Useful for recency; cheap to build given data is already stored |

---

## Anti-Features (large effort, marginal value — avoid)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Weather briefing | This is a full EFB feature (ForeFlight, Garmin Pilot). Airline pilots use company tools. Adding this doubles scope for near-zero uptake among target users | Link out to BOM / ATIS |
| Weight and balance | Aircraft-specific, company-specific, requires POH data entry per type. Full EFB feature; logbook users don't want it here | Out of scope entirely |
| Instructor endorsement signatures | Requires PKI infrastructure, legal validity questions per jurisdiction, complex UI. Primary market (airline pilots) never needs this — they're not students | Defer to V3 at earliest |
| Career matching / job board | LogTen added this; it is a distraction from logbook quality. Airline pilots use ALPAQ, LinkedIn, airline careers pages | Out of scope entirely |
| Built-in flight planning | Overlap with every EFB app; no logbook user wants this here; airline pilots use OFP | Out of scope entirely |
| Real-time ATC / OOOI integration | APDL (US market) pulls gate data. Australian airlines have no equivalent API. Medium effort, near-zero viability in AU | Revisit if airline partnerships form |
| Checklist management | EFB feature; zero relation to logbook record-keeping | Out of scope entirely |
| Maintenance logging (aircraft log) | Different regulatory domain (CASA Part 43/CASR), different user, different workflow | Separate product if ever |
| Social / sharing ("flew with" feed) | Logbook is private regulatory record; pilots do not want social features in it | Out of scope entirely |
| AI auto-fill from flight number lookup | Flight data APIs (AeroDataBox, FlightAware) are rate-limited, cost money, have ~3-month history limits. Already in v1 as optional lookup, not as AI | Keep as manual lookup; don't over-automate |
| Subscription model for basic logging | Pilots will pay once (Logbook Pro lifetime licence is a selling point). Subscription for core logging features triggers immediate distrust | Monetise via one-time purchase or paywalled advanced features |

---

## Regulatory Considerations

### CASA (Australia) — CASR 61.345

Required to record per flight, as soon as practicable after completion:

- Full name and date of birth (in logbook header)
- Date of flight
- Departure and arrival places and times
- Aircraft make, model, and registration
- Whether flight was by day, night, or both
- Whether an instrument approach was conducted, and the type of procedure
- Flight time in role: PIC, PICUS, P2 (co-pilot), dual, instructor time (if applicable)
- Simulator entries: date, FSTD name and location, flight time, day/night simulated, description of activity, instructor time if applicable

Retention: 7 years from last entry.

Electronic logbooks: must be capable of producing a printed copy certified by the holder as a true copy. PDF export with per-page certification satisfies this.

Production requirement: must supply to CASA within 7 days of direction.

### EASA — FCL.050 / AMC1 FCL.050

Required columns (AMC1 specifies these explicitly):

- Date
- Departure place and time
- Arrival place and time
- Aircraft make, model, and variant
- Aircraft registration
- ICAO type designator (correct, not airline nickname)
- PIC name
- Function: exactly one of PIC, PICUS, dual, or instructor time
- Single-pilot / multi-pilot time (separate columns)
- Total flight time
- Day landings and night landings (separate counts)
- Instrument time (actual and simulated)
- Night flight time
- Type of instrument approach procedure (if flown)
- Remarks

Simulator time must be clearly separated from actual flight time. Electronic format must be acceptable to the competent authority.

### FAA — 14 CFR §61.51

Required per flight entry:

- Date of flight
- Total flight time (or lesson time for training)
- Departure and destination locations
- Aircraft type and N-number (registration)
- Name of safety pilot (if using instrument hood)
- Type of pilot experience (solo, PIC, SIC, flight instruction received)
- Conditions of flight (day, night, actual IMC, simulated IMC)
- Type of instrument approaches performed

FAA does not mandate a specific logbook format — any format meeting these requirements is valid. Electronic logbooks are accepted.

### Common ground across CASA / EASA / FAA

Every authority requires: date, dep/arr airports, aircraft type + registration, role-based time (PIC/co-pilot), day/night split, instrument approaches by type, separate simulator entries. Block-Time's v1 data model covers all of this. The v2.0 rewrite must preserve every field.

---

## Feature Dependencies

Dependencies where feature B cannot ship without feature A being solid first.

```
Core flight entry → Everything else
  └─ Time fields as numeric (TimeInterval) → FRMS calculations → FRMS display
  └─ UTC date storage → Local time display → Local time entry
  └─ Aircraft type database → Autocomplete → ICAO type in PDF export
  └─ Airport database → Dep/arr validation → Flight map route drawing

FRMS calculations (pure function) → FRMS dashboard view → FRMS widget
  └─ Must be unit-tested before UI is built — regressions are invisible

CSV import → Data migration from v1 Core Data → App Store update safety
  └─ Cannot ship v2.0 without this working; any data loss = App Store reviews crater

PDF export → CASA compliance → Airline recruiter readiness
  └─ Must reflect correct ICAO types, all role columns, dep/arr times

Roster import → ACARS photo parsing (independent path)
  └─ Both feed the merge review sheet (duplicate detection)
  └─ Merge review sheet must exist before either importer can be trusted

iCloud sync (SwiftData + CloudKit) → Widget data (shared app group)
  └─ Widget reads from app group container written by sync layer
```

---

## Sources

- [CASA — Flight Crew Logbooks](https://www.casa.gov.au/licences-and-certificates/pilots/flight-crew-logbooks)
- [CASR 61.345 — Personal logbooks, pilots](https://classic.austlii.edu.au/au/legis/cth/consol_reg/casr1998333/s61.345.html)
- [EASA AMC1 FCL.050 — General logbook requirements (capzlog.aero)](https://capzlog.aero/academy/regulatory-frameworks/general-logbook-requirements)
- [FAA 14 CFR §61.51 — Pilot logbooks](https://www.ecfr.gov/current/title-14/chapter-I/subchapter-D/part-61/subpart-A/section-61.51)
- [LogTen — Features overview](https://logten.com/how-it-works/)
- [APDL — Airline Pilot Logbook (FAR Part 117)](https://www.nc-software.com/apdl-airline-pilot-logbook)
- [Best Pilot Logbook Apps 2025 — Axis Intelligence](https://axis-intelligence.com/best-pilot-logbook-apps-2025-tested/)
- [Choosing a Digital Logbook 2025 — limanovember.aero](https://limanovember.aero/post/2024/12/digital-logbook-updated-2025/)
- [Electronic vs Paper Logbooks for Airline Pilots — AirlineGeeks](https://airlinegeeks.com/2025/03/08/electronic-vs-paper-logbooks-for-airline-pilots/)
- [Best way to print a digital logbook for interviews — Aileron](https://shopaileron.com/blogs/news/best-way-to-print-a-digital-pilot-logbook-for-interviews)
