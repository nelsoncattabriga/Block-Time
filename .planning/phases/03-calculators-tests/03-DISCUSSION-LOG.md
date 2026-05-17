# Phase 3: Calculators & Tests - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-17
**Phase:** 03-calculators-tests
**Areas discussed:** FRMS extraction boundary, Night time calculator interface, UTC↔local converter design, Time formatter scope

---

## FRMS Extraction Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Pure calculator only | Move limit-lookup tables and pure computation functions into BlockTimeCalculators. FRMSCalculationService stays as coordinator. Phase 4 handles ViewModel/coordination refactor. | ✓ |
| Full extraction | Move all of FRMSCalculationService into BlockTimeCalculators now. FRMSViewModel becomes thin pass-through in Phase 3. | |
| FRMSData models only | Move types only, write pure function stubs, leave extraction to Phase 4. Minimum viable for CALC-01–05. | |

**User's choice:** Pure calculator only (recommended)
**Notes:** Keeps Phase 3 scoped to the calculator layer. God Object Breakup (Phase 4) handles the coordination and ViewModel refactor.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Existing FRMSDuty array | compute(duties: [FRMSDuty], config: FRMSConfiguration) — no new type, no mapping layer | ✓ |
| New Duty type | Define minimal Duty struct, add mapping from FRMSDuty. Cleaner long-term but more work. | |
| Flight array | Calculator groups flights into duties internally. Duplicates existing duty-grouping logic. | |

**User's choice:** Existing FRMSDuty array (recommended)

---

| Option | Description | Selected |
|--------|-------------|----------|
| Move to BlockTimeDomain | FRMSData.swift types move into BlockTimeDomain. App target imports BlockTimeDomain. No duplicate types. | ✓ |
| Stay in app target, duplicate minimally | BlockTimeCalculators defines its own input/output types. App target maps between them. | |

**User's choice:** Move to BlockTimeDomain (recommended)

---

## Night Time Calculator Interface

| Option | Description | Selected |
|--------|-------------|----------|
| Accept lat/lon directly | calculateNightTime(fromLat:fromLon:toLat:toLon:departure:flightDurationMinutes:) -> Int?. Caller resolves ICAO via AirportService. 100% pure. | ✓ |
| Bundle airports.dat in BlockTimeKit | Calculator looks up coordinates internally given ICAO codes. Simpler call site, less pure. | |
| Protocol-injected lookup | AirportCoordinateProvider protocol. Mock for tests, real AirportService in production. | |

**User's choice:** Accept lat/lon directly (recommended)

---

| Option | Description | Selected |
|--------|-------------|----------|
| Return nil | nil when coordinates missing. Caller decides display. Matches current NightCalcService behavior. | ✓ |
| Return 0 | Simple, never breaks display, loses unknown-vs-zero distinction. | |
| Throw an error | Explicit but forces all call sites to handle errors for display-only calculation. | |

**User's choice:** Return nil (recommended)

---

## UTC↔Local Converter Design

| Option | Description | Selected |
|--------|-------------|----------|
| Accept TimeZone directly | localToUTC/utcToLocal take TimeZone. Caller resolves ICAO. Consistent with night calc approach. | ✓ |
| Accept UTC offset (Int seconds) | Most explicit but loses DST handling. | |
| Bundle offset lookup table | Self-contained but impure (reads data), duplicates AirportService. | |

**User's choice:** Accept TimeZone directly (recommended)

---

**Functions selected (all four):**
- `localToUTC(date: Date, timeZone: TimeZone) -> Date`
- `utcToLocal(date: Date, timeZone: TimeZone) -> Date`
- `parseHHMM(_ string: String) -> (hour: Int, minute: Int)?`
- `combineDateAndTime(date: Date, hhmm: String, timeZone: TimeZone) -> Date?`

---

## Time Formatter Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Define pure function only | Add functions to BlockTimeCalculators with tests. Existing call sites unchanged. | ✓ |
| Define and rewire all call sites now | Project-wide sweep replacing safeDoubleFromString etc. Risky, out of Phase 3 scope. | |

**User's choice:** Define pure function only (recommended)
**Notes:** Existing inline conversions in FlightDatabaseService and ViewModels stay until those files are refactored in Phase 4/5.

---

**Functions selected (all four):**
- `minutesToHHMM(_ minutes: Int) -> String`
- `minutesToDecimalHours(_ minutes: Int) -> String`
- `hhmmToMinutes(_ string: String) -> Int?`
- `decimalHoursStringToMinutes(_ string: String) -> Int?`

---

## Claude's Discretion

- Internal file layout within BlockTimeCalculators
- FRMSResult output struct field names
- Whether formatter functions are namespaced or free functions
- Test fixture structure
- Test target naming

## Deferred Ideas

- Rewiring existing call sites to use new formatter functions — Phase 4/5
- Background context for large FRMS datasets — Phase 4
- Moving AirportService into BlockTimeCalculators — evaluated and rejected
- New minimal Duty struct — evaluated and deferred
