---
phase: 02-coredata-repository
plan: 01
subsystem: BlockTimeKit / BlockTimeDomain
tags: [domain-model, flight-struct, unit-tests, migration-algorithms]
dependency_graph:
  requires: []
  provides: [Flight-Int-minutes, Flight-Date-gates, InMemoryFlightRepository-updated, migration-algorithm-tests]
  affects: [02-02-CoreDataFlightRepository, 02-03-SwiftDataDeletion]
tech_stack:
  added: []
  patterns: [Int-minutes-for-logbook-times, Date?-for-gate-times, standalone-algorithm-copy-for-testability]
key_files:
  created:
    - BlockTimeKit/Tests/BlockTimeDomainTests/FlightMigrationConversionTests.swift
  modified:
    - BlockTimeKit/Sources/BlockTimeDomain/Flight.swift
    - BlockTimeKit/Tests/BlockTimeDomainTests/FlightTests.swift
    - BlockTimeKit/Tests/BlockTimeDataTests/FlightRepositoryTests.swift
decisions:
  - "outTime/inTime use Date(timeIntervalSince1970:) in test fixtures for semantic preservation of 09:00/11:00 UTC values"
  - "InMemoryFlightRepository required no changes — contains no Flight construction internally"
  - "stringToMinutes returns Int (not Int16) — Flight.blockTime is Int; production policy uses Int16 with same clamp"
metrics:
  duration_minutes: 8
  completed_date: "2026-05-16"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 4
---

# Phase 2 Plan 01: Flight Struct Update and Migration Algorithm Tests — Summary

**One-liner:** Flight domain struct updated to Int minutes + Date? gates with 4 new fields; 25 migration algorithm unit tests added covering stringToMinutes and stringToDate verbatim copies.

## What Was Done

Updated `Flight` from TimeInterval seconds to Int minutes, replaced gate time fields with proper Date?, added 4 new fields, updated all test consumers atomically, and added a standalone test file covering the exact conversion algorithms that `FlightEntityMigrationPolicy` (Plan 02-02) inlines.

## Final Flight Init Signature

```swift
public init(
    id: UUID,
    date: Date,
    fromAirport: String,
    toAirport: String,
    flightNumber: String,
    aircraftType: String,
    aircraftReg: String,
    blockTime: Int,
    simTime: Int,
    nightTime: Int,
    p1Time: Int,
    p1usTime: Int,
    p2Time: Int,
    instrumentTime: Int,
    spInsTime: Int,
    dualTime: Int,
    outTime: Date?,
    inTime: Date?,
    scheduledDeparture: Date?,
    scheduledArrival: Date?,
    dayTakeoffs: Int,
    nightTakeoffs: Int,
    dayLandings: Int,
    nightLandings: Int,
    customCount: Int,
    isPilotFlying: Bool,
    isPositioning: Bool,
    isILS: Bool,
    isGLS: Bool,
    isRNP: Bool,
    isNPA: Bool,
    isAIII: Bool,
    captainName: String,
    foName: String,
    so1Name: String,
    so2Name: String,
    remarks: String
)
```

## Numeric Conversion Choices in Test Fixtures

- Old `blockTime: 7200` (seconds = 2h) → New `blockTime: 120` (minutes)
- Old `p1Time: 7200` (seconds = 2h) → New `p1Time: 120` (minutes)
- Old `outTimeSeconds: 32400` (09:00 in seconds-from-midnight) → New `outTime: Date(timeIntervalSince1970: 32400)` (09:00 UTC on 1970-01-01 — preserves semantic meaning)
- Old `inTimeSeconds: 39600` (11:00 in seconds-from-midnight) → New `inTime: Date(timeIntervalSince1970: 39600)` (11:00 UTC on 1970-01-01)

## Preserved Computed Properties

The old `Flight.swift` had no computed properties or static `sample` helpers — only stored properties and the memberwise init. Nothing to preserve.

## InMemoryFlightRepository

Required zero changes. The repository stores `[UUID: Flight]` and sorts/filters by `date` only — no internal Flight construction and no references to removed field names.

## Test Counts

| File | Before | After | Delta |
|------|--------|-------|-------|
| FlightTests.swift | 4 | 4 | 0 (no tests deleted) |
| FlightRepositoryTests.swift | 8 | 8 | 0 (no tests deleted) |
| FlightMigrationConversionTests.swift | 0 | 25 | +25 (new file) |
| **Total** | **12** | **37** | **+25** |

## FlightMigrationConversionTests Algorithm Identity

The `stringToMinutes` and `stringToDate` functions in `FlightMigrationConversionTests.swift` are character-for-character identical to the algorithm body that `FlightEntityMigrationPolicy.swift` (Plan 02-02) inlines, with one intentional difference:

- Test copy: `-> Int` return type (matches `Flight.blockTime: Int`)
- Production copy: `-> Int16` return type (for direct Core Data scalar assignment on `FlightEntity.blockTime: Int16`)

The clamp `min(..., Int(Int16.max))` is bit-identical in both copies. The `testStringToMinutes_overflow_clampsToInt16Max` test verifies the clamp value is 32767 in both.

## Conversion Test Coverage (25 tests)

**stringToMinutes (16 tests):**
- Decimal-hour: "1.5" → 90, "0.25" → 15
- HH:MM: "01:30" → 90, "00:00" → 0, "10:45" → 645
- nil → 0, "" → 0, "0" → 0, "0.0" → 0, "   " → 0
- Malformed: "abc" → 0, "1:99" → 0, "ab:cd" → 0
- Negative: "-1.5" → 0
- Infinite: "inf" → 0
- Overflow: "10000.0" → 32767 (Int16.max)

**stringToDate (9 tests):**
- Valid "09:30" → midnight + 9h30m
- Valid "1430" (no colon) → midnight + 14h30m
- nil → nil, "" → nil
- Short "9:3" → nil
- Out-of-range: "24:00" → nil, "12:60" → nil
- Non-numeric "ab:cd" → nil
- Whitespace-trimmed " 09:30 " → midnight + 9h30m

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- Flight.swift exists and has 0 TimeInterval references
- InMemoryFlightRepository.swift unchanged — no old field references
- FlightTests.swift: 4 tests preserved, all pass
- FlightRepositoryTests.swift: 8 tests preserved, all pass
- FlightMigrationConversionTests.swift: 25 tests, all pass
- Full suite: 37 tests, 0 failures
- Commits: fe257c1 (Task 1), ec1972f (Task 2), 059c84a (Task 3)
