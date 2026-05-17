---
phase: 03-calculators-tests
plan: 01
subsystem: testing
tags: [swift, frms, BlockTimeDomain, BlockTimeCalculators, pure-functions, unit-tests]

# Dependency graph
requires:
  - phase: 02-coredata-repository
    provides: BlockTimeKit package structure with BlockTimeDomain, BlockTimeCalculators, BlockTimeData targets
provides:
  - BlockTimeDomain exports 13 FRMS domain types as public Sendable structs/enums
  - FRMSResult output struct (D-05) in BlockTimeDomain
  - TimeInterval.toDecimalHours extension in BlockTimeDomain
  - BlockTimeCalculatorsTests test target declared in Package.swift
  - App target imports BlockTimeDomain for all FRMS type resolution
affects:
  - 03-02 (FRMS calculator extraction — uses FRMSDuty, FRMSConfiguration, FRMSResult)
  - 03-03 (Night time calculator — uses BlockTimeCalculators module scaffold)
  - 03-04 (UTC converter — uses BlockTimeDomain types)
  - 03-05 (Time formatter tests — uses BlockTimeCalculatorsTests target)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "FRMS domain types are public Sendable in BlockTimeDomain — no app-target-only types in calculator inputs"
    - "Calendar(identifier: .gregorian) with explicit TimeZone — never Calendar.current in package code"
    - "CrewRestFacility moved to BlockTimeDomain alongside SignOnTimeRange to avoid BlockTimeCalculators dependency"

key-files:
  created:
    - BlockTimeKit/Sources/BlockTimeDomain/FRMSTypes.swift
    - BlockTimeKit/Sources/BlockTimeDomain/FRMSResult.swift
    - BlockTimeKit/Sources/BlockTimeDomain/TimeIntervalExtensions.swift
    - BlockTimeKit/Tests/BlockTimeCalculatorsTests/.gitkeep
  modified:
    - BlockTimeKit/Package.swift
    - Block-Time/Models/FRMSData.swift
    - Block-Time/Models/LH_Operational_FltDuty.swift
    - Block-Time/Models/LH_Planning_FltDuty.swift
    - Block-Time/Models/SH_Planning_FltDuty.swift
    - Block-Time/Models/SH_Operational_FltDuty.swift
    - Block-Time/Services/FRMSCalculationService.swift
    - Block-Time/ViewModels/FRMSViewModel.swift
    - plus 20 additional view/viewmodel files with import BlockTimeDomain

key-decisions:
  - "CrewRestFacility moved to BlockTimeDomain (not BlockTimeCalculators) — SignOnTimeRange in FRMSMaximumNextDuty requires it; keeping it in BlockTimeCalculators would create a circular dep"
  - "OperationTimeClass.classify uses Calendar(identifier: .gregorian) not Calendar.current — deterministic for unit tests"
  - "FRMSCumulativeTotals gets memberwise public init — app target must construct it from app-side computation"

patterns-established:
  - "Pattern 1: All FRMS domain types imported via BlockTimeDomain — no duplicate declarations in app target"
  - "Pattern 2: Pure package types never use Calendar.current, TimeZone.current, LogManager, AirportService"

requirements-completed: [CALC-01, CALC-09]

# Metrics
duration: 6min
completed: 2026-05-17
---

# Phase 3 Plan 01: FRMS Domain Types Extraction Summary

**13 FRMS domain types moved to BlockTimeDomain as public Sendable, FRMSResult + TimeInterval.toDecimalHours added, BlockTimeCalculatorsTests test scaffold created — app target builds green with no behavior change**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-17T02:13:24Z
- **Completed:** 2026-05-17T02:20:15Z
- **Tasks:** 3
- **Files modified:** 30

## Accomplishments
- BlockTimeDomain now exports all 13 FRMS value types required by the pure `FRMSCalculator` in Plans 02–05
- FRMSResult (D-05) output struct created with `cumulativeTotals`, `complianceStatus`, `maximumNextDuty`
- BlockTimeCalculatorsTests test target scaffold added to Package.swift — ready for Plan 02 test files
- All 26 app-target files that reference FRMS types updated with `import BlockTimeDomain`
- Existing 37 BlockTimeKit tests all pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Add BlockTimeCalculatorsTests test target + create empty tests directory** - `7957e5b` (feat)
2. **Task 2: Move FRMS domain types into BlockTimeDomain + add FRMSResult and TimeInterval.toDecimalHours** - `1650e1c` (feat)
3. **Task 3: Remove duplicated FRMS types from app target FRMSData.swift and import BlockTimeDomain** - `337a769` (feat)

## Files Created/Modified
- `BlockTimeKit/Sources/BlockTimeDomain/FRMSTypes.swift` — 13 FRMS domain types as public Sendable (FRMSDuty, FRMSConfiguration, FRMSCumulativeTotals, FRMSMaximumNextDuty, FRMSFleet, CrewComplement, RestFacilityClass, DutyType, OperationTimeClass, FRMSLimitType, FRMSComplianceStatus, SignOnTimeRange, FRMSMinimumBaseTurnaroundTime) + CrewRestFacility
- `BlockTimeKit/Sources/BlockTimeDomain/FRMSResult.swift` — D-05 output struct
- `BlockTimeKit/Sources/BlockTimeDomain/TimeIntervalExtensions.swift` — `TimeInterval.toDecimalHours` for FRMSDuty.init
- `BlockTimeKit/Tests/BlockTimeCalculatorsTests/.gitkeep` — empty test directory
- `BlockTimeKit/Package.swift` — third test target added
- `Block-Time/Models/FRMSData.swift` — 13 moved types deleted; UI/presentation types retained; import BlockTimeDomain added
- `Block-Time/Models/LH_Operational_FltDuty.swift` — CrewRestFacility definition removed; import BlockTimeDomain added
- `Block-Time/Models/LH_Planning_FltDuty.swift`, `SH_Planning_FltDuty.swift`, `SH_Operational_FltDuty.swift` — import BlockTimeDomain added
- `Block-Time/Services/FRMSCalculationService.swift`, `Block-Time/ViewModels/FRMSViewModel.swift`, `Block-Time/ViewModels/NewDashboardViewModel.swift` — import BlockTimeDomain added
- 17 Dashboard/FRMS view files — import BlockTimeDomain added

## Decisions Made
- CrewRestFacility moved to BlockTimeDomain alongside SignOnTimeRange — `FRMSMaximumNextDuty.signOnBasedLimits: [SignOnTimeRange]?` references it; keeping it in `BlockTimeCalculators` (LH_Operational_FltDuty.swift) would require BlockTimeDomain to import BlockTimeCalculators (circular). Moving it to BlockTimeDomain is cleaner and all raw values match the original.
- `OperationTimeClass.classify` changed from `Calendar.current` to `Calendar(identifier: .gregorian)` — required for deterministic unit tests (anti-pattern documented in RESEARCH.md).
- `FRMSCumulativeTotals` and `FRMSMaximumNextDuty` gained public memberwise `init` — original structs only had auto-synthesized init (internal), which can't be called from app target code across module boundary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] CrewRestFacility moved to BlockTimeDomain**
- **Found during:** Task 2 (creating FRMSTypes.swift)
- **Issue:** `SignOnTimeRange.restFacility: CrewRestFacility?` requires `CrewRestFacility` to be in the same module or a dependency. `CrewRestFacility` was defined in `LH_Operational_FltDuty.swift` (app target), which `BlockTimeDomain` cannot import. Without this fix, `FRMSTypes.swift` would not compile.
- **Fix:** Added `CrewRestFacility` to `FRMSTypes.swift` in BlockTimeDomain. Removed the duplicate definition from `LH_Operational_FltDuty.swift`.
- **Files modified:** `BlockTimeKit/Sources/BlockTimeDomain/FRMSTypes.swift`, `Block-Time/Models/LH_Operational_FltDuty.swift`
- **Verification:** `swift build` passes in BlockTimeKit; `LH_Operational_FltDuty.swift` uses type from BlockTimeDomain via `import BlockTimeDomain`
- **Committed in:** `1650e1c`, `337a769`

**2. [Rule 3 - Blocking] 20 additional app-target files needed import BlockTimeDomain**
- **Found during:** Task 3 (app target build)
- **Issue:** Plan specified adding `import BlockTimeDomain` to 7 files. Build revealed 20 additional dashboard/FRMS view files also reference the moved types directly.
- **Fix:** Added `import BlockTimeDomain` to all affected files (Dashboard cards, FRMS views, FRMSRollingLineCard, DisruptionRestSection, etc.).
- **Files modified:** 20 Swift files across Views/Components/Dashboard, Views/Screens/FRMS, ViewModels
- **Verification:** BUILD SUCCEEDED
- **Committed in:** `337a769`

**3. [Rule 2 - Missing Critical] Public memberwise initialisers on FRMSCumulativeTotals and FRMSMaximumNextDuty**
- **Found during:** Task 2 (writing FRMSTypes.swift)
- **Issue:** Structs with only stored properties get auto-synthesized internal memberwise init; when moved to a different module, the app target cannot call the init without an explicit `public init`.
- **Fix:** Added explicit `public init` to `FRMSCumulativeTotals`, `FRMSMaximumNextDuty`, `SignOnTimeRange`, `FRMSMinimumBaseTurnaroundTime`.
- **Files modified:** `BlockTimeKit/Sources/BlockTimeDomain/FRMSTypes.swift`
- **Committed in:** `1650e1c`

---

**Total deviations:** 3 auto-fixed (1 missing critical, 1 blocking, 1 missing critical)
**Impact on plan:** All three auto-fixes necessary for correctness. No scope creep.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- BlockTimeDomain has all FRMS domain types required for `FRMSCalculator.compute(duties:config:)` in Plan 02
- `BlockTimeCalculatorsTests` test target scaffold is ready for test file addition in Plan 02
- App target builds green — no regressions

## Known Stubs
None — all types are complete value types with no placeholder values.

---
*Phase: 03-calculators-tests*
*Completed: 2026-05-17*
