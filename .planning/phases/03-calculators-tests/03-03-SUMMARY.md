---
phase: 03-calculators-tests
plan: 03
subsystem: calculators
tags: [swift, night-time, solar-calculation, pure-functions, XCTest, BlockTimeCalculators]

# Dependency graph
requires:
  - phase: 03-01
    provides: BlockTimeCalculatorsTests test target scaffold in Package.swift
provides:
  - NightTimeCalculator pure static function (D-06 signature) in BlockTimeCalculators
  - Same-airport division-by-zero guard
  - Int minutes return type (not Double hours)
  - 10-case XCTest suite for NightTimeCalculatorTests
affects:
  - Phase 4/5 — call sites in NightCalcService/FlightDatabaseService can delegate to this pure function

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NightTimeCalculator: public enum namespace — pure static functions only, Foundation import only"
    - "Same-airport guard: distRad < 1e-10 before sin(distRad) division — prevents NaN propagation"
    - "Unit conversion: Int((nightHours * 60).rounded()) clamped to [0, flightDurationMinutes]"
    - "acos argument clamped to [-1, 1] via max/min — prevents NaN from floating-point rounding at exactly same-airport"

key-files:
  created:
    - BlockTimeKit/Sources/BlockTimeCalculators/NightTimeCalculator.swift
    - BlockTimeKit/Tests/BlockTimeCalculatorsTests/NightTimeCalculatorTests.swift
  modified: []

key-decisions:
  - "acos argument clamped to max(-1.0, min(1.0, ...)) in addition to distRad guard — belt-and-suspenders against floating-point edge cases slightly outside [-1,1]"
  - "Return 0 (not nil) for same-airport case — nil is reserved for non-finite results per D-07"
  - "10 tests (plan required ≥7) — added range-contract multi-case test and zero-duration test for completeness"

patterns-established:
  - "Pattern 3: NightTimeCalculator extracted verbatim from NightCalcService — algorithm unchanged, interface adapted (D-09)"

requirements-completed: [CALC-06, CALC-09]

# Metrics
duration: 3min
completed: 2026-05-17
---

# Phase 3 Plan 03: NightTimeCalculator Extraction Summary

**Pure solar night-time calculator extracted from NightCalcService.swift — D-06 signature, same-airport guard, Int minutes, 10 XCTest cases all green**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-17T02:22:28Z
- **Completed:** 2026-05-17T02:25:28Z
- **Tasks:** 1
- **Files created:** 2

## Accomplishments

- `NightTimeCalculator.calculateNightTime(fromLat:fromLon:toLat:toLon:departure:flightDurationMinutes:) -> Int?` — public pure static function with D-06 signature
- Algorithm extracted verbatim from `NightCalcService.nightPortion` — civil twilight at -6°, 200-segment great-circle interpolation, `julianDay`, `greenwichSiderealTime`, `isNightInternal` all preserved (D-09)
- Same-airport guard: `if distRad < 1e-10 { return 0 }` — prevents NaN from `sin(0)` division (RESEARCH.md "Division-by-Zero Risk")
- Unit conversion: `Int((nightHours * 60).rounded())` clamped to `[0, flightDurationMinutes]` (D-07, RESEARCH.md Pitfall 5)
- `import Foundation` only — no LogManager, no AirportService, no UIKit, no Calendar.current
- `NightTimeCalculatorTests`: 10 XCTest cases covering same-airport, unit conversion, half-night, midnight crossing, polar twilight summer solstice, DST boundary, all-night sector, range contract
- All 10 tests pass; `NightCalcService.swift` in app target unchanged

## Task Commits

1. **Task 1: NightTimeCalculator extraction with same-airport guard and unit conversion** — `4d8bcd3` (feat)

## Files Created/Modified

- `BlockTimeKit/Sources/BlockTimeCalculators/NightTimeCalculator.swift` — pure enum; public entry point + 3 private static helpers
- `BlockTimeKit/Tests/BlockTimeCalculatorsTests/NightTimeCalculatorTests.swift` — 10 XCTest cases

## Decisions Made

- `acos` argument clamped to `max(-1.0, min(1.0, ...))` — belt-and-suspenders in addition to the `distRad < 1e-10` guard. Floating-point arithmetic can produce values like `1.0000000000000002` which `acos` would return `NaN` on. Clamp is the correct defense.
- Returned value is `0` (not `nil`) for same-airport — per D-07, `nil` is reserved for callers indicating missing coordinates. Same-airport with known coordinates is a defined result of `0` night minutes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] TimeFormatter.swift and UTCConverter.swift already present from parallel agents**
- **Found during:** Task 1 (running `swift test --filter NightTimeCalculatorTests`)
- **Issue:** `BlockTimeCalculatorsTests` target compiles all test files together. `UTCConverterTests.swift` and `TimeFormatterTests.swift` already existed (created by parallel agents 03-04 and 03-05), referencing `UTCConverter` and `TimeFormatter`. These files were already fully implemented by those agents — no action needed.
- **Fix:** None required — implementations already in place.
- **Files modified:** None

None — plan executed exactly as written for the implementation tasks. The parallel agent scenario was handled transparently.

## Issues Encountered

None.

## User Setup Required

None.

## Next Phase Readiness

- `NightTimeCalculator` is ready for Phase 4/5 call-site rewiring in `NightCalcService` and `FlightDatabaseService`
- All `BlockTimeCalculatorsTests` (10 NightTimeCalculator + UTCConverter + TimeFormatter) pass green

## Known Stubs

None — `NightTimeCalculator` is fully implemented with complete solar calculation algorithm.

---
*Phase: 03-calculators-tests*
*Completed: 2026-05-17*
