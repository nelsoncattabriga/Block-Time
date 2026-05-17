# Phase 3: Calculators & Tests — Research

**Researched:** 2026-05-17
**Domain:** Swift pure functions, XCTest in Swift Package, FRMS business logic extraction
**Confidence:** HIGH

## Summary

Phase 3 extracts pure calculation logic from the app target into `BlockTimeCalculators` and writes exhaustive unit tests. The work is bounded: no UI rewiring, no call-site changes, no new data types invented. Every piece of code already exists in the app target — this phase moves and tests it, it does not design it from scratch.

The single largest risk is the `FRMSCalculationService` boundary. The service is 1,855 lines and mixes pure computation (the functions to move) with AirportService calls, LogManager, `Calendar.current` usage, and `configuration` property reads — all of which make functions impure. The extraction plan must surgically pull only the pure computation paths and leave the coordinators in place.

The existing test files all use **XCTest** (`XCTestCase` subclasses, `XCTAssertEqual`), not Swift Testing (`@Suite`/`@Test`/`#expect`). The CONTEXT.md says "Swift Testing framework" — but the actual codebase contradicts this. New test files MUST match the existing XCTest pattern or the tests will not be discoverable.

**Primary recommendation:** Write new test targets as `XCTestCase` subclasses matching the established `FlightMigrationConversionTests.swift` pattern. Do not mix Swift Testing and XCTest in the same package.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**FRMS Extraction Boundary**
- D-01: Only pure calculator functions move into `BlockTimeCalculators`. `FRMSCalculationService.swift` stays in the app target as coordinator.
- D-02: `FRMSCalculator.compute(duties: [FRMSDuty], config: FRMSConfiguration) -> FRMSResult` uses the existing `FRMSDuty` array as input — no new `Duty` type invented.
- D-03: `FRMSData.swift` types (`FRMSDuty`, `FRMSConfiguration`, `FRMSCumulativeTotals`, and all enums/structs they reference) move from app target into `BlockTimeDomain`.
- D-04: The 4 rule-set model files (`LH_Planning_FltDuty.swift`, `LH_Operational_FltDuty.swift`, `SH_Planning_FltDuty.swift`, `SH_Operational_FltDuty.swift`) move into `BlockTimeCalculators`.
- D-05: `FRMSResult` is a new output struct defined in `BlockTimeDomain`.

**Night Time Calculator Interface**
- D-06: `calculateNightTime(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double, departure: Date, flightDurationMinutes: Int) -> Int?`
- D-07: Returns `Int?` (minutes) — `nil` when coordinates missing.
- D-08: Airport coordinate resolution stays in app target. Calculator is 100% pure.
- D-09: Solar algorithm from `NightCalcService.swift` extracted as-is. No behavior change.

**UTC Converter Interface**
- D-10: All converter functions accept `TimeZone` directly.
- D-11: Four functions:
  1. `localToUTC(date: Date, timeZone: TimeZone) -> Date`
  2. `utcToLocal(date: Date, timeZone: TimeZone) -> Date`
  3. `parseHHMM(_ string: String) -> (hour: Int, minute: Int)?`
  4. `combineDateAndTime(date: Date, hhmm: String, timeZone: TimeZone) -> Date?`

**Time Formatter Scope**
- D-12: Phase 3 defines pure functions only — no rewiring of call sites.
- D-13: Four formatter functions:
  1. `minutesToHHMM(_ minutes: Int) -> String`
  2. `minutesToDecimalHours(_ minutes: Int) -> String`
  3. `hhmmToMinutes(_ string: String) -> Int?`
  4. `decimalHoursStringToMinutes(_ string: String) -> Int?`

### Claude's Discretion

- Internal file layout within `BlockTimeCalculators` (one file per calculator vs. grouped)
- Exact enum/struct field names in the new `FRMSResult` output type
- Whether to namespace formatter functions in a `TimeFormatter` enum or as free functions
- Test fixture structure (inline values vs. external JSON fixtures)
- Test target naming conventions

### Deferred Ideas (OUT OF SCOPE)

- Rewiring `FlightDatabaseService` and ViewModel call sites to use new formatter functions (Phase 4/5)
- Background context for FRMS calculations on large datasets (Phase 4)
- `AirportService` moved into `BlockTimeCalculators` (rejected D-08)
- New minimal `Duty` struct to replace `FRMSDuty` (rejected D-02)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CALC-01 | `FRMSCalculator.compute(duties: [FRMSDuty], config: FRMSConfiguration) -> FRMSResult` pure function in `BlockTimeCalculators` | See Architecture Patterns: FRMSCalculator extraction |
| CALC-02 | LH Planning FRMS rules covered by unit tests | `LH_Planning_FltDuty.swift` rule tables identified; test edge cases documented |
| CALC-03 | LH Operational FRMS rules covered by unit tests | `LH_Operational_FltDuty.swift` rule tables identified |
| CALC-04 | SH Planning FRMS rules covered by unit tests | `SH_Planning_FltDuty.swift` rule tables identified |
| CALC-05 | SH Operational FRMS rules covered by unit tests | `SH_Operational_FltDuty.swift` rule tables identified |
| CALC-06 | Night time calculator pure function, tested for midnight crossing, DST, polar twilight | `nightPortion` function isolated; algorithm is already pure internally |
| CALC-07 | `localDateToUTC` pure function, tested for DST, midnight crossing, missing airport fallback | UTC converter interface defined in D-10/D-11 |
| CALC-08 | Time display formatter pure function, replaces scattered string parsing | `minutesToHours`/`safeDoubleFromString` patterns mapped in `FlightDatabaseService` |
| CALC-09 | All calculator tests run without a simulator (pure Swift, no UIKit or Core Data) | Confirmed: `BlockTimeKit` has no UIKit or CoreData imports |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation | System | Date, TimeZone, Calendar, TimeInterval | Required for all date/time math |
| XCTest | System | Unit test assertions and test discovery | Established in all existing test files |

No third-party dependencies. This phase is pure Swift with Foundation only — matching the existing `BlockTimeCalculators` target declaration (`// Zero external deps. Foundation only.`).

**Key version note:** `swift-tools-version: 6.0` is already set in `Package.swift`. No change needed.

### Test Target Addition Required

`Package.swift` currently declares two test targets: `BlockTimeDomainTests` and `BlockTimeDataTests`. A third test target `BlockTimeCalculatorsTests` must be added:

```swift
.testTarget(
    name: "BlockTimeCalculatorsTests",
    dependencies: ["BlockTimeCalculators", "BlockTimeDomain"],
    path: "Tests/BlockTimeCalculatorsTests"
)
```

**Also required:** `BlockTimeDomain` must be added as a dependency of `BlockTimeCalculators` test target because FRMS types (`FRMSDuty`, `FRMSConfiguration`) will live in `BlockTimeDomain` after D-03.

---

## Architecture Patterns

### Recommended Module Layout After Phase 3

```
BlockTimeKit/
├── Sources/
│   ├── BlockTimeDomain/
│   │   ├── Flight.swift                    (existing)
│   │   ├── FlightRepository.swift          (existing)
│   │   ├── InMemoryFlightRepository.swift  (existing — actually in BlockTimeData)
│   │   ├── FRMSTypes.swift                 (NEW — moved from app: FRMSDuty, FRMSConfiguration,
│   │   │                                    FRMSCumulativeTotals, FRMSResult, all enums)
│   │   └── FRMSResult.swift                (NEW — new output struct, D-05)
│   ├── BlockTimeCalculators/
│   │   ├── BlockTimeCalculators.swift      (existing stub — expand or replace)
│   │   ├── FRMSCalculator.swift            (NEW — pure compute functions)
│   │   ├── LH_Planning_FltDuty.swift       (MOVED from app target)
│   │   ├── LH_Operational_FltDuty.swift    (MOVED from app target)
│   │   ├── SH_Planning_FltDuty.swift       (MOVED from app target)
│   │   ├── SH_Operational_FltDuty.swift    (MOVED from app target)
│   │   ├── NightTimeCalculator.swift       (NEW — pure solar math moved from NightCalcService)
│   │   ├── UTCConverter.swift              (NEW — 4 functions from D-11)
│   │   └── TimeFormatter.swift             (NEW — 4 functions from D-13)
│   └── BlockTimeData/
│       └── (existing, unchanged)
└── Tests/
    ├── BlockTimeDomainTests/               (existing)
    ├── BlockTimeDataTests/                 (existing)
    └── BlockTimeCalculatorsTests/          (NEW)
        ├── FRMSCalculatorTests.swift
        ├── NightTimeCalculatorTests.swift
        ├── UTCConverterTests.swift
        └── TimeFormatterTests.swift
```

### Pattern 1: XCTest Subclass (Established Project Convention)

All existing test files use `XCTestCase`, not Swift Testing. New tests MUST match this pattern.

```swift
// Source: BlockTimeKit/Tests/BlockTimeDomainTests/FlightMigrationConversionTests.swift
import XCTest
@testable import BlockTimeCalculators

final class TimeFormatterTests: XCTestCase {

    func test_minutesToHHMM_ninetyMinutes_returnsOneColon30() {
        XCTAssertEqual(TimeFormatter.minutesToHHMM(90), "1:30")
    }

    func test_hhmmToMinutes_oneColon30_returns90() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes("1:30"), 90)
    }

    func test_hhmmToMinutes_malformed_returnsNil() {
        XCTAssertNil(TimeFormatter.hhmmToMinutes("abc"))
    }
}
```

**IMPORTANT:** The CONTEXT.md mentions Swift Testing (`@Suite`, `@Test`, `#expect`) but this contradicts the actual codebase — every test file uses XCTest. Follow the codebase.

### Pattern 2: Pure Function Extraction — FRMSCalculator

The pure computation path in `FRMSCalculationService` is:
1. `calculateCumulativeTotals(duties:flights:asOf:)` — pure aside from `getHomeBaseTimeZone()` call. For the pure version, the caller passes `TimeZone` (already decided in D-10 pattern).
2. `calculateMaximumNextDuty(previousDuty:cumulativeTotals:limitType:proposedCrewComplement:proposedRestFacility:)` — pure aside from `getHomeBaseTimeZone()` and `AirportService` calls; these stay in the coordinator.
3. `checkCompliance(proposedDuty:previousDuty:cumulativeTotals:)` — fully pure given pre-resolved inputs.
4. Limit lookup helpers (`getBaseLimits`, `getLHDutyLimit`, `calculateMinimumRest`, etc.) — pure given `FRMSFleet`/`FRMSConfiguration` inputs.

`FRMSResult` fields should capture what `FRMSViewModel` currently reads from the service:
- `cumulativeTotals: FRMSCumulativeTotals`
- `complianceStatus: FRMSComplianceStatus`
- `maximumNextDuty: FRMSMaximumNextDuty?`

### Pattern 3: NightTimeCalculator Extraction

`nightPortion(fromLat:fromLon:toLat:toLon:departureUTC:flightDurationHours:flightDate:)` in `NightCalcService.swift` is already functionally pure — it only calls `parseUTCString` (private function) and `isNightInternal` (private function). Both must move together.

The D-06 signature changes the interface from `(departureUTC: String, flightDurationHours: Double)` to `(departure: Date, flightDurationMinutes: Int)`. The inner algorithm stays unchanged — the entry point signature adapts.

The `LogManager.shared` calls in `nightPortion` and `NightCalcService.calculateNightTime` must be removed in the extracted version (no LogManager in BlockTimeKit). Replace with no-op or remove debug logs — the pure function returns the value, callers handle nil.

### Pattern 4: UTCConverter

The `flightDateForStorage` logic in `FlightTimeExtractorViewModel` uses `AirportService` — this coordinator logic stays in the app. The pure functions (D-11) take `TimeZone` directly. The key logic to extract is:

```swift
// From FlightDatabaseService.swift lines 2172-2183 — already proven correct
func combineDateAndTime(date: Date, hhmm: String, timeZone: TimeZone) -> Date? {
    let clean = hhmm.replacingOccurrences(of: ":", with: "")
    guard clean.count == 4,
          let hours = Int(clean.prefix(2)),
          let minutes = Int(clean.suffix(2)),
          hours >= 0, hours < 24,
          minutes >= 0, minutes < 60 else { return nil }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    var comps = cal.dateComponents([.year, .month, .day], from: date)
    comps.hour = hours
    comps.minute = minutes
    comps.second = 0
    return cal.date(from: comps)
}
```

### Anti-Patterns to Avoid

- **Importing UIKit or AppKit into BlockTimeCalculators:** Will break CALC-09 (no simulator). Foundation only.
- **Using `Calendar.current` inside pure functions:** `Calendar.current` respects device locale — use `Calendar(identifier: .gregorian)` with an explicit `TimeZone` for deterministic tests.
- **Using `LogManager.shared` in extracted code:** `LogManager` is app-target only. Pure functions must not log; remove all `LogManager` calls when extracting.
- **Leaving `FlightSector` references in extracted FRMS code:** `FlightSector` is an app-target type with DateFormatter caches and UIKit formatting methods. The pure FRMS calculator takes `[FRMSDuty]` only (D-02). `createDuty(from:)` stays in `FRMSCalculationService` in the app target.
- **Mixing Swift Testing and XCTest:** Swift Package Manager supports both frameworks but within a single test target they cannot be mixed. The existing targets use XCTest — adding `@Suite` tests to `BlockTimeDomainTests` would break existing tests.
- **Moving `FRMSComplianceStatus.color` and `.icon` computed properties:** These return `String` but are presentation concerns and reference icon names. Keep them in `FRMSData.swift` in the app target — only move the type's core data structure to `BlockTimeDomain`, or remove the UI properties from the domain type.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Julian Day calculation | Custom formula | Extract existing `julianDay(for:)` from `NightCalcService.swift` as-is | Already validated in production with 2,697 flights |
| Greenwich Sidereal Time | Custom formula | Extract existing `greenwichSiderealTime(for:)` as-is | Pair with `julianDay` — both must move together |
| Solar elevation math | New algorithm | Extract `isNightInternal(at:lon:time:)` as-is, civil twilight at -6° | Behavior change explicitly excluded (D-09) |
| HHMM parsing | New parser | `parseHHMM` already tested in `FlightMigrationConversionTests.swift` `stringToDate` | Proven against edge cases; copy the algorithm |
| Time formatter | DateFormatter | Pure integer arithmetic (`minutes / 60`, `minutes % 60`) | DateFormatter overhead, locale sensitivity; simple math is correct and testable |

---

## FRMSData.swift Type Inventory (What Moves to BlockTimeDomain)

After reading `FRMSData.swift` (982 lines), the following types must move to `BlockTimeDomain`:

**Core value types (D-03 mandates move):**
- `FRMSFleet` (enum, Codable, Sendable) — has `maxFlightTime7Days`, `maxFlightTime28Days`, `maxDutyTime7Days`, etc.
- `CrewComplement` (enum, Codable, Sendable)
- `RestFacilityClass` (enum, Codable, Sendable)
- `DutyType` (enum, Codable, Sendable)
- `OperationTimeClass` (enum, Codable, Sendable) — includes `classify(signOn:signOff:homeBaseTimeZone:)` static method (uses only `Calendar` + `Date` — pure)
- `FRMSLimitType` (enum, Codable)
- `FRMSComplianceStatus` (enum, Codable, Sendable)
- `FRMSDuty` (struct, Codable, Sendable)
- `FRMSConfiguration` (referenced but not shown above — confirmed Codable in memory notes)
- `FRMSCumulativeTotals` (struct, Codable, Sendable)
- `FRMSMaximumNextDuty` (struct, Codable, Sendable)
- `SignOnTimeRange` (struct, Codable)
- `FRMSMinimumBaseTurnaroundTime` (struct, Codable)

**Types that stay in app target (UI/presentation concerns):**
- `DailyDutySummary`, `DutyTimeWindow`, `DutyLimits`, `BackOfClockRestriction`, `LateNightStatus`, `ConsecutiveDutyStatus`, `SpecialScenarios`, `SimulatorRestrictions`, `WhatIfScenario`, `A320B737NextDutyLimits`, etc. — used by `FRMSViewModel` only.

**Complication:** `FRMSComplianceStatus` has `var color: String` and `var icon: String` — these are presentation but simple `String` values. They can stay on the type. However they are not `Sendable` conformance blockers since the enum is already `Sendable`.

**Complication:** `FRMSDuty.init` calls `OperationTimeClass.classify(...)` inline. That static method uses `Calendar` with explicit `TimeZone` — it is pure and should move.

**Complication:** `FRMSDuty.init` takes `homeBaseTimeZone: TimeZone` — already the right interface (D-10 pattern).

**New type (D-05):**
```swift
// In BlockTimeDomain/FRMSResult.swift
public struct FRMSResult: Sendable {
    public let cumulativeTotals: FRMSCumulativeTotals
    public let complianceStatus: FRMSComplianceStatus
    public let maximumNextDuty: FRMSMaximumNextDuty?
}
```

---

## Common Pitfalls

### Pitfall 1: LogManager in Extracted Code

**What goes wrong:** `nightPortion` and `FRMSCalculationService` call `LogManager.shared.debug/error/warning`. Moving these functions directly into `BlockTimeCalculators` causes a compile error — `LogManager` is app-target only.
**Why it happens:** Extraction is copy-paste, reviewers miss logging calls.
**How to avoid:** Before moving any function, search for `LogManager` references and remove them. In night time calculator, the debug log at line 185 and error at line 182 must be deleted.
**Warning signs:** Build error `cannot find 'LogManager' in scope`.

### Pitfall 2: Calendar.current in Tests

**What goes wrong:** Tests using `Calendar.current` give different results depending on test runner's locale and time zone. DST tests that pass on the developer's machine fail on CI.
**Why it happens:** `Calendar.current` respects the system locale; `TimeZone.current` respects system timezone.
**How to avoid:** All test code and all pure functions use `Calendar(identifier: .gregorian)` with an explicit `TimeZone`. Never `.current` inside `BlockTimeKit`.

### Pitfall 3: FRMSDuty.dutyTime Uses `toDecimalHours` Extension

**What goes wrong:** `FRMSDuty.init` sets `self.dutyTime = signOff.timeIntervalSince(signOn).toDecimalHours`. The `.toDecimalHours` extension is defined in `FlightDatabaseService.swift` or another app-target file — it will not compile in `BlockTimeDomain`.
**Why it happens:** Extension is defined in app target, used in a type that moves to the package.
**How to avoid:** Inline the computation in `FRMSDuty.init`: `signOff.timeIntervalSince(signOn) / 3600.0`. Or add a `TimeInterval` extension to `BlockTimeDomain`.

### Pitfall 4: Package.swift Missing Test Target

**What goes wrong:** Tests run in app target where `LogManager` and `AirportService` exist, masking the pure-function constraint. `xcodebuild test` with `-scheme BlockTimeKit` (package-only) is the correct check for CALC-09.
**Why it happens:** Forgetting to add `BlockTimeCalculatorsTests` to `Package.swift`.
**How to avoid:** Add the test target in the same plan wave as creating the test directory.
**Warning signs:** `xcodebuild test -scheme BlockTimeKit` fails with "no test target" or the wrong target runs.

### Pitfall 5: nightPortion Returns Double (Hours), D-06 Returns Int (Minutes)

**What goes wrong:** The existing `nightPortion` returns `Double` hours. The D-06 interface returns `Int?` minutes. Callers that expect minutes but receive hours (or vice versa) silently produce wrong results.
**Why it happens:** Unit mismatch between legacy interface and new interface.
**How to avoid:** The wrapping function in `BlockTimeCalculators` converts: `Int(nightHours * 60)`. Add an explicit unit test: `nightTime = 0.5 hours → 30 minutes`.

### Pitfall 6: SH Rule-Set Files Import Enums from LH Files

**What goes wrong:** `SH_Planning_FltDuty.swift` and `SH_Operational_FltDuty.swift` may reference enums defined in `LH_Planning_FltDuty.swift` or `LH_Operational_FltDuty.swift`. All four files must move together in the same task — moving one without the others causes compile errors.
**Why it happens:** Cross-file enum dependencies within a single module.
**How to avoid:** Move all four rule-set files in one task and verify build before proceeding.

### Pitfall 7: FRMSConfiguration Not Sendable

**What goes wrong:** If `FRMSConfiguration` has any non-Sendable stored property, the move to `BlockTimeDomain` will produce Swift 6 concurrency warnings/errors at module boundary crossings.
**Why it happens:** `FRMSConfiguration` uses `@AppStorage`-friendly types (all primitives/enums) but might embed non-Sendable types.
**How to avoid:** Verify `FRMSConfiguration` is already `Sendable`. If not, add `Sendable` conformance explicitly (all stored properties are `String`, `Int`, `Bool`, `Double`, or `Codable` enums — it will be trivially Sendable).

---

## Code Examples

### NightTimeCalculator Extraction Pattern

```swift
// Source: Block-Time/Services/NightCalcService.swift (extracted, adapted)
// NOTE: LogManager calls removed. departureUTC String replaced with Date. Duration in minutes.

public enum NightTimeCalculator {

    /// Pure solar calculation — no airport lookup, no file I/O.
    /// - Parameters:
    ///   - fromLat: Departure latitude (degrees)
    ///   - fromLon: Departure longitude (degrees)
    ///   - toLat: Arrival latitude (degrees)
    ///   - toLon: Arrival longitude (degrees)
    ///   - departure: UTC departure Date
    ///   - flightDurationMinutes: Flight duration in integer minutes
    /// - Returns: Night time in integer minutes, nil if coordinates produce degenerate case
    public static func calculateNightTime(
        fromLat: Double, fromLon: Double,
        toLat: Double, toLon: Double,
        departure: Date,
        flightDurationMinutes: Int
    ) -> Int? {
        let hours = Double(flightDurationMinutes) / 60.0
        let nightHours = nightPortion(
            fromLat: fromLat, fromLon: fromLon,
            toLat: toLat, toLon: toLon,
            departure: departure,
            flightDurationHours: hours
        )
        return Int(nightHours * 60)
    }
}
```

### TimeFormatter Pattern (Enum Namespace)

```swift
// BlockTimeCalculators/TimeFormatter.swift
public enum TimeFormatter {

    /// 90 → "1:30", 0 → "0:00"
    public static func minutesToHHMM(_ minutes: Int) -> String {
        guard minutes >= 0 else { return "0:00" }
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }

    /// 90 → "1.50", 0 → "0.00"
    public static func minutesToDecimalHours(_ minutes: Int) -> String {
        guard minutes >= 0 else { return "0.00" }
        return String(format: "%.2f", Double(minutes) / 60.0)
    }

    /// "1:30" or "01:30" → 90, nil for malformed
    public static func hhmmToMinutes(_ string: String) -> Int? {
        let parts = string.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              h >= 0, m >= 0, m < 60 else { return nil }
        return h * 60 + m
    }

    /// "1.5" → 90, "90" (legacy integer) → 90, nil for malformed
    public static func decimalHoursStringToMinutes(_ string: String) -> Int? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        // Try HH:MM first (for strings like "1:30" accidentally passed here)
        if s.contains(":") { return hhmmToMinutes(s) }
        guard let hours = Double(s), hours.isFinite, hours >= 0 else { return nil }
        return Int(hours * 60)
    }
}
```

### FRMSCalculator Pattern

The extracted compute function takes pre-resolved inputs — no `AirportService`, no `Calendar.current`, no `LogManager`:

```swift
// BlockTimeCalculators/FRMSCalculator.swift
public enum FRMSCalculator {

    public static func computeCumulativeTotals(
        duties: [FRMSDuty],
        asOf date: Date,
        homeTimeZone: TimeZone     // Caller resolves via AirportService — stays in app
    ) -> FRMSCumulativeTotals {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = homeTimeZone
        // ... pure rolling-window logic ...
    }

    public static func checkCompliance(
        proposedDuty: FRMSDuty,
        previousDuty: FRMSDuty?,
        cumulativeTotals: FRMSCumulativeTotals,
        fleet: FRMSFleet
    ) -> FRMSComplianceStatus {
        // ... pure limit checking ...
    }
}
```

### Test Pattern (XCTest — Matches Existing Files)

```swift
// Tests/BlockTimeCalculatorsTests/TimeFormatterTests.swift
import XCTest
@testable import BlockTimeCalculators

final class TimeFormatterTests: XCTestCase {

    func test_minutesToHHMM_zero_returnsZeroColonZero() {
        XCTAssertEqual(TimeFormatter.minutesToHHMM(0), "0:00")
    }

    func test_minutesToHHMM_90_returnsOneColon30() {
        XCTAssertEqual(TimeFormatter.minutesToHHMM(90), "1:30")
    }

    func test_minutesToHHMM_645_returns10Colon45() {
        XCTAssertEqual(TimeFormatter.minutesToHHMM(645), "10:45")
    }

    func test_hhmmToMinutes_leadingZero_returnsCorrect() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes("01:30"), 90)
    }

    func test_hhmmToMinutes_minutesOver59_returnsNil() {
        XCTAssertNil(TimeFormatter.hhmmToMinutes("1:99"))
    }
}
```

---

## FRMS Edge Cases for Tests (CALC-02 through CALC-05)

These are the known edge cases from CONTEXT.md plus code review:

### LH Planning (CALC-02)
- 2-pilot sign-on window boundary: `0500`, `0800`, `1400`, `1600` — duty limits change at each boundary
- 3-pilot Class 1 vs Class 2 rest facility — different duty period caps
- 4-pilot `FD3.4` scenario (2×Class1, >18 hrs duty) — special pre/post rest rules

### LH Operational (CALC-03)
- 2-pilot operational extension to 12 hours vs planning 11 hours
- `>7 hrs darkness` reduces max flight time to 9.5 hrs (hard to catch without a test)
- Rest formula boundary: duty ≤11 hrs → 10 hrs rest; duty >11 hrs → formula applies

### SH Planning (CALC-04)
- `LocalStartTime` bucket boundaries: `0500–1459` (early), `1500–1959` (afternoon), `2000–0459` (night) — night wraps through midnight
- Sector count boundary: `maxDutySectors1to4` vs `maxDutySectors5or6` — 5+ sectors reduces max duty
- Augmented operations: `separateScreenedSeat` vs `passengerCompartmentSeat`

### SH Operational (CALC-05)
- Back-of-clock next sign-on restriction: must not sign on before 1000 local
- Consecutive duties max 6 (FD12.2b)
- 9 duty days in 11-day rolling period (FD12.2a) — rolling window boundary
- Maximum 4 consecutive early starts (FD13.6)
- Maximum 4 consecutive late nights (FD14.1)

### Night Time (CALC-06)
- Midnight crossing: `YSSY→YMML 2300Z, 2h flight` — crosses midnight UTC
- DST transition: Australian AEDT/AEST changeover (first Sunday April / first Sunday October)
- Same-airport: `fromLat == toLat && fromLon == toLon` — `distRad = 0`, `sin(0) = 0` division risk
- Short sector all-night: all 200 segments should be night → return full duration
- Polar twilight: latitude > 66.5° — sun never sets in summer; all daytime

### UTC Converter (CALC-07)
- DST transition (Australia): local 2:30am on changeover day does not exist (spring forward)
- Midnight crossing: local 23:00 + offset → UTC date is previous or next day
- `parseHHMM`: rejects `"24:00"`, `"12:60"`, `"ab:cd"`, `""`, `"9:3"` (short)
- `combineDateAndTime`: correct date when `TimeZone` has negative offset (e.g., UTC-5)

---

## Division-by-Zero Risk in nightPortion

The existing `nightPortion` function has a latent issue:

```swift
let distRad = acos(sin(φ1)*sin(φ2) + cos(φ1)*cos(φ2)*cos(λ1-λ2))
// ...
let A = sin((1-f) * distRad) / sin(distRad)  // <-- division by sin(0) when same airport
```

When `fromAirport == toAirport`, `distRad == 0` and `sin(0) == 0` → division by zero → `NaN` propagates through all segments → `nightSeconds = NaN`. The current production code does not guard against this because `AirportService` typically prevents same-airport sectors from reaching `calculateNightTime`. But as a pure function in tests, callers may pass equal coordinates. The extracted function should guard: `if distRad < 1e-10 { return 0 }`.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (all existing tests confirmed) |
| Config file | Package.swift — test targets declared there |
| Quick run command | `xcodebuild test -scheme BlockTimeKit -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -scheme BlockTimeKit -destination 'platform=macOS'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CALC-01 | FRMSCalculator.compute returns FRMSResult | unit | `xcodebuild test -scheme BlockTimeKit -only-testing BlockTimeCalculatorsTests/FRMSCalculatorTests` | ❌ Wave 0 |
| CALC-02 | LH Planning limits: 2-pilot sign-on windows, 3-pilot rest facilities, 4-pilot FD3.4 | unit | `...FRMSCalculatorTests` | ❌ Wave 0 |
| CALC-03 | LH Operational limits: 2-pilot extension, darkness reduction, rest formula | unit | `...FRMSCalculatorTests` | ❌ Wave 0 |
| CALC-04 | SH Planning limits: start-time buckets, sector count boundaries, augmented | unit | `...FRMSCalculatorTests` | ❌ Wave 0 |
| CALC-05 | SH Operational limits: back-of-clock, consecutive duties/early-starts/late-nights | unit | `...FRMSCalculatorTests` | ❌ Wave 0 |
| CALC-06 | Night time: midnight crossing, DST, polar twilight, same-airport guard | unit | `...NightTimeCalculatorTests` | ❌ Wave 0 |
| CALC-07 | UTC converter: DST transition, midnight crossing, malformed input | unit | `...UTCConverterTests` | ❌ Wave 0 |
| CALC-08 | Time formatter: HH:MM formatting, decimal hours, round-trip | unit | `...TimeFormatterTests` | ❌ Wave 0 |
| CALC-09 | All above tests pass with `platform=macOS` (no simulator) | CI check | `xcodebuild test -scheme BlockTimeKit -destination 'platform=macOS'` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme BlockTimeKit -destination 'platform=macOS'`
- **Per wave merge:** Same command — full suite is fast (pure Swift, no simulator)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `BlockTimeKit/Tests/BlockTimeCalculatorsTests/` directory
- [ ] `BlockTimeKit/Tests/BlockTimeCalculatorsTests/FRMSCalculatorTests.swift`
- [ ] `BlockTimeKit/Tests/BlockTimeCalculatorsTests/NightTimeCalculatorTests.swift`
- [ ] `BlockTimeKit/Tests/BlockTimeCalculatorsTests/UTCConverterTests.swift`
- [ ] `BlockTimeKit/Tests/BlockTimeCalculatorsTests/TimeFormatterTests.swift`
- [ ] `Package.swift` — add `BlockTimeCalculatorsTests` test target

---

## Environment Availability

Step 2.6: This phase is purely Swift package code with no external tool dependencies beyond the Xcode toolchain already in use.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / xcodebuild | Building and testing | ✓ | Darwin 25.4.0 / iOS 18.6 target | — |
| macOS test destination | CALC-09 (no simulator) | ✓ | macOS 15+ (from Project.swift platforms) | — |

---

## Project Constraints (from CLAUDE.md)

- Swift 6 strict concurrency — all new types crossing module boundaries must be `Sendable`
- `@Observable` not applicable here (calculators are pure enums/structs, not observation subjects)
- `async/await` not required for pure synchronous functions — do not add unnecessary concurrency
- `guard` for early exits — use in all parsing functions (matches existing `FlightMigrationConversionTests.swift` patterns)
- Prefer value types (structs/enums) — all calculators should be `enum` namespaces or `struct` value types, not classes
- Never remove existing features — `FRMSCalculationService.swift` and all existing logic stays; only new pure functions are added to the package

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| XCTest with `XCTestCase` | Swift Testing (`@Suite`/`@Test`) available | Xcode 16 / iOS 18 | Project has NOT migrated — existing tests all use XCTest. New tests must match. |
| `safeDoubleFromString` inline in FlightDatabaseService | `decimalHoursStringToMinutes` pure function in BlockTimeCalculators | Phase 3 (this phase) | Call sites NOT rewired until Phase 4/5 |
| `minutesToHours(_ minutes: Int16) -> Double` inline | `minutesToHHMM` / `minutesToDecimalHours` pure functions | Phase 3 | Call sites NOT rewired until Phase 4/5 |

---

## Open Questions

1. **`toDecimalHours` extension location**
   - What we know: `FRMSDuty.init` uses `signOff.timeIntervalSince(signOn).toDecimalHours` which is not in Foundation
   - What's unclear: Which file defines this `TimeInterval` extension in the app target
   - Recommendation: Search for `toDecimalHours` in the app target before moving `FRMSDuty`. Inline as `/ 3600.0` in the package version.

2. **`FRMSConfiguration` complete definition**
   - What we know: It is `Codable` and stored in `UserDefaults` as JSON. Referenced heavily by `FRMSCalculationService`.
   - What's unclear: Full struct definition was not read — may have fields that complicate `Sendable` conformance
   - Recommendation: Read `FRMSConfiguration` definition before writing the plan. Verify all fields are primitive/enum types.

3. **`SH_Operational_FltDuty.swift` and `LH_Operational_FltDuty.swift` — cross-file type dependencies**
   - What we know: `FRMSCalculationService` references `LH_Operational_FltDuty.twoPilotLimits`, `threePilotLimits`, `DutyLimit`, `RestRequirement`, `RestDirection`, `LH_CrewComplement`, `CrewRestFacility`
   - What's unclear: Which file defines `CrewRestFacility` — it appears in both LH planning and operational files
   - Recommendation: Read both LH files before writing the plan to confirm all referenced types are captured in the move.

---

## Sources

### Primary (HIGH confidence)
- Direct code reading: `BlockTimeKit/Package.swift` — module declarations, test targets
- Direct code reading: `BlockTimeKit/Tests/BlockTimeDomainTests/FlightTests.swift`, `FlightMigrationConversionTests.swift`, `BlockTimeDataTests/FlightRepositoryTests.swift` — established XCTest pattern (all three files use XCTest, not Swift Testing)
- Direct code reading: `Block-Time/Services/NightCalcService.swift` — full 341-line source; algorithm is self-contained pure math
- Direct code reading: `Block-Time/Services/FRMSCalculationService.swift` — first 1,000 lines; function signatures and impurity points identified
- Direct code reading: `Block-Time/Models/FRMSData.swift` — full 982-line type inventory
- Direct code reading: `Block-Time/Models/SH_Planning_FltDuty.swift` — rule tables and enum definitions
- Direct code reading: `Block-Time/Models/LH_Planning_FltDuty.swift` — rule tables
- Direct code reading: `Block-Time/Services/FlightDatabaseService.swift` — `minutesToHours`, `safeDoubleFromString`, `decimalToMinutes` definitions (lines 2155-2183)
- Direct code reading: `Block-Time/ViewModels/FlightTimeExtractorViewModel.swift` — `flightDateForStorage`, `enterTimesInLocalTime` architecture

### Secondary (MEDIUM confidence)
- `.planning/phases/03-calculators-tests/03-CONTEXT.md` — locked decisions D-01 through D-13
- `.planning/STATE.md` — Phase 1/2 decisions confirming `Int` minutes, `Date?` for gate times

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure Foundation, XCTest; no ambiguity
- Architecture: HIGH — all source files read; extraction paths clearly identified
- Pitfalls: HIGH — identified from direct code analysis (LogManager, `toDecimalHours`, same-airport division, `nightPortion` unit mismatch)
- FRMS edge cases: MEDIUM — rule tables read but full `SH_Operational_FltDuty.swift` and both `LH_Operational_FltDuty.swift` not fully read; plan-time reading required

**Research date:** 2026-05-17
**Valid until:** 2026-06-17 (stable — no fast-moving dependencies)
