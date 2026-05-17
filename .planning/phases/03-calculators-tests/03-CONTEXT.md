# Phase 3: Calculators & Tests - Context

**Gathered:** 2026-05-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract pure function calculators into `BlockTimeCalculators` and write exhaustive unit tests for all four FRMS rule sets, night time calculation, UTC↔local conversion, and time formatting. No UI rewiring — existing call sites in `FlightDatabaseService` and ViewModels keep their inline conversions until Phase 4/5 refactors those files anyway. `xcodebuild test` must pass without a simulator.

</domain>

<decisions>
## Implementation Decisions

### FRMS Extraction Boundary
- **D-01:** Only the **pure calculator functions** move into `BlockTimeCalculators` in Phase 3 — limit-lookup tables and computation functions. `FRMSCalculationService.swift` stays in the app target as the coordinator. Phase 4 (God Object Breakup) refactors `FRMSViewModel` and the coordination layer.
- **D-02:** `FRMSCalculator.compute(duties: [FRMSDuty], config: FRMSConfiguration) -> FRMSResult` uses the **existing `FRMSDuty` array** as input — no new `Duty` type invented. No mapping layer needed.
- **D-03:** `FRMSData.swift` types (`FRMSDuty`, `FRMSConfiguration`, `FRMSCumulativeTotals`, and all enums/structs they reference) **move from the app target into `BlockTimeDomain`**. App target imports `BlockTimeDomain` to get these types — no duplication.
- **D-04:** The 4 rule-set model files (`LH_Planning_FltDuty.swift`, `LH_Operational_FltDuty.swift`, `SH_Planning_FltDuty.swift`, `SH_Operational_FltDuty.swift`) move into `BlockTimeCalculators` alongside the pure computation functions.
- **D-05:** `FRMSResult` is a new output struct defined in `BlockTimeDomain` — captures `FRMSCumulativeTotals` plus compliance status for each rule set. Researcher/planner should define fields to match what `FRMSViewModel` currently reads from `FRMSCalculationService`.

### Night Time Calculator Interface
- **D-06:** Pure function signature: `calculateNightTime(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double, departure: Date, flightDurationMinutes: Int) -> Int?`
- **D-07:** Returns **`Int?` (minutes)** — `nil` when either airport has no coordinates (matches current `NightCalcService` nil-return behavior). Caller decides what to display.
- **D-08:** Airport coordinate resolution stays in the app target via `AirportService`. Calculator is 100% pure — no file I/O, no `AirportLookup` inside `BlockTimeCalculators`.
- **D-09:** The solar calculation algorithm from `NightCalcService.swift` is extracted as-is into `BlockTimeCalculators`. The twilight definition (civil vs. astronomical) stays as-is — no behavior change.

### UTC↔Local Converter Interface
- **D-10:** All converter functions accept `TimeZone` directly — caller resolves ICAO → `TimeZone` via `AirportService`. Consistent with the lat/lon decision for night calc.
- **D-11:** Four functions exposed:
  1. `localToUTC(date: Date, timeZone: TimeZone) -> Date`
  2. `utcToLocal(date: Date, timeZone: TimeZone) -> Date`
  3. `parseHHMM(_ string: String) -> (hour: Int, minute: Int)?` — strict parser, nil for malformed
  4. `combineDateAndTime(date: Date, hhmm: String, timeZone: TimeZone) -> Date?` — replaces `flightDateForStorage` computed property logic

### Time Formatter Scope
- **D-12:** Phase 3 **defines pure functions only** — no rewiring of existing call sites. `FlightDatabaseService`, ViewModels, and other files keep their inline `minutesToHours` / `safeDoubleFromString` conversions until those files are refactored in Phase 4/5.
- **D-13:** Four formatter functions:
  1. `minutesToHHMM(_ minutes: Int) -> String` — `90 → "1:30"`
  2. `minutesToDecimalHours(_ minutes: Int) -> String` — `90 → "1.50"`
  3. `hhmmToMinutes(_ string: String) -> Int?` — `"1:30"` or `"01:30"` → `90`, nil for malformed
  4. `decimalHoursStringToMinutes(_ string: String) -> Int?` — `"1.5"` or `"90"` (legacy integer string) → `90`

### Claude's Discretion
- Internal file layout within `BlockTimeCalculators` (one file per calculator vs. grouped)
- Exact enum/struct field names in the new `FRMSResult` output type
- Whether to namespace formatter functions in a `TimeFormatter` enum or as free functions
- Test fixture structure (inline values vs. external JSON fixtures)
- Test target naming conventions

### Swift 6 Strict Concurrency Requirements (NON-NEGOTIABLE)
- **D-14:** ALL extracted code MUST use Swift 6 strict concurrency - NO force unwraps (`!`), NO implicitly unwrapped optionals
- **D-15:** ALL `TimeZone` and `Calendar` creation MUST use safe patterns: `guard let timeZone = TimeZone(identifier: "UTC") else { return default }`
- **D-16:** ALL test helpers MUST use `XCTUnwrap` instead of force unwraps for better failure messages
- **D-17:** NO `@MainActor` annotations in pure calculator functions - they must be safely callable from any context
- **D-18:** ALL types moved to `BlockTimeDomain` MUST conform to `Sendable` - verify before moving

### Modern Swift API Requirements (NON-NEGOTIABLE)
- **D-19:** NO `String(format:)` usage - use `.formatted(.number.precision(.fractionLength(N)))` instead
- **D-20:** NO `replacingOccurrences(of:with:)` usage - use `.replacing(_:with:)` instead
- **D-21:** NO `Calendar.current` or `TimeZone.current` usage - use explicit `Calendar(identifier: .gregorian)` with specific TimeZone
- **D-22:** NO `Date()` instantiation - use `Date.now` for clarity when appropriate

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing FRMS Engine (extraction source)
- `Block-Time/Services/FRMSCalculationService.swift` — 1,855-line FRMS engine. Pure computation methods to be extracted; coordination methods stay.
- `Block-Time/Models/FRMSData.swift` — All FRMS data types (`FRMSDuty`, `FRMSConfiguration`, `FRMSCumulativeTotals`, enums). Move into `BlockTimeDomain`.
- `Block-Time/Models/LH_Planning_FltDuty.swift` — LH planning rule-set lookup tables.
- `Block-Time/Models/LH_Operational_FltDuty.swift` — LH operational rule-set lookup tables.
- `Block-Time/Models/SH_Planning_FltDuty.swift` — SH planning rule-set lookup tables.
- `Block-Time/Models/SH_Operational_FltDuty.swift` — SH operational rule-set lookup tables.

### Existing Night Time Engine (extraction source)
- `Block-Time/Services/NightCalcService.swift` — 341-line solar calculation engine. Algorithm extracted as-is.
- `Block-Time/Services/TimeCalculationManager.swift` — Wrapper around `NightCalcService`. Understand what it adds before deciding if it stays or dissolves.

### Existing UTC Conversion Logic (extraction source)
- `Block-Time/ViewModels/FlightTimeExtractorViewModel.swift` — `localTimeBinding(utcTime:airportCode:)`, `flightDateForStorage` property, `enterTimesInLocalTime` logic. Search for these to find the conversion code to extract.

### Existing Time Formatter Logic (extraction source)
- `Block-Time/Services/FlightDatabaseService.swift` — `minutesToHours()` and `safeDoubleFromString()` usage; defines inline what the pure formatter replaces.

### BlockTimeKit Package (destination)
- `BlockTimeKit/Package.swift` — Module declarations; confirm `BlockTimeDomain` and `BlockTimeCalculators` are linked correctly.
- `BlockTimeKit/Sources/BlockTimeDomain/Flight.swift` — Reference for how domain types are structured.
- `BlockTimeKit/Sources/BlockTimeCalculators/BlockTimeCalculators.swift` — Current placeholder stub; this is where calculator implementations go.
- `BlockTimeKit/Tests/BlockTimeDomainTests/FlightTests.swift` — Reference for test structure and conventions used in Phase 1.

### Requirements
- `.planning/REQUIREMENTS.md` — CALC-01 through CALC-09 are all in scope for Phase 3.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NightCalcService.swift`: Solar calculation algorithm (sun angle, twilight threshold) is correct and tested in production. Extract the inner `nightPortion(fromLat:fromLon:toLat:toLon:departureUTC:flightDurationHours:flightDate:)` function as-is — no algorithm changes.
- `FRMSData.swift`: `FRMSDuty` and `FRMSConfiguration` are already `Codable, Sendable` — they will move to `BlockTimeDomain` with no structural changes.
- `FlightTests.swift` and `FlightRepositoryTests.swift`: Existing test structure to follow — `@Suite`, `@Test` with `#expect`, no `XCTestCase`.
- `FlightMigrationConversionTests.swift`: Shows how to write tests for pure conversion functions — use as a template for formatter and UTC converter tests.

### Established Patterns
- Test style: Swift Testing framework (`@Suite`, `@Test`, `#expect`) — not XCTest. All new tests must follow this.
- Module placement: Domain types in `BlockTimeDomain`; pure functions in `BlockTimeCalculators`; tests in `BlockTimeDataTests` or `BlockTimeDomainTests` (add new test target if needed for calculators).
- Sendability: All types crossing module boundaries must be `Sendable`. `FRMSDuty` and `FRMSConfiguration` already qualify.

### Integration Points
- `FRMSViewModel.swift` currently calls `FRMSCalculationService` — after Phase 3, it will call the pure `FRMSCalculator` functions from `BlockTimeCalculators`. Phase 3 does NOT rewire this — just defines the pure functions.
- `FlightTimeExtractorViewModel.swift` currently embeds UTC conversion inline — Phase 3 defines pure functions but does NOT rewire the ViewModel.
- App target still imports `BlockTimeDomain` (which will now include FRMS types) — no new import paths needed.

</code_context>

<specifics>
## Specific Ideas

- `FRMSCalculationService.getHomeBaseTimeZone()` uses `AirportService` — this stays in the app target. The pure `FRMSCalculator` functions receive pre-resolved `TimeZone` values (consistent with UTC converter design).
- `NightCalcService.nightPortion(...)` already takes lat/lon — it's essentially already pure. The extraction is mostly moving it to `BlockTimeCalculators` and adding tests, not redesigning the algorithm.
- FRMS tests should cover the known edge cases: LH augmented crew rest facility classification, SH early/late start time buckets, cumulative rolling-window calculations.

</specifics>

<deferred>
## Deferred Ideas

- Rewiring existing `FlightDatabaseService` and ViewModel call sites to use new formatter functions — deferred to Phase 4 (God Object Breakup) and Phase 5 (Core UI).
- Background context for FRMS calculations on large datasets — deferred to Phase 4.
- `AirportService` moved into `BlockTimeCalculators` — evaluated (D-08) and rejected for Phase 3; stays in app target.
- New minimal `Duty` struct to replace `FRMSDuty` at the API boundary — evaluated (D-02) and deferred; existing `FRMSDuty` used as-is.

</deferred>

---

*Phase: 03-calculators-tests*
*Context gathered: 2026-05-17*
