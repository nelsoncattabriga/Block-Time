---
plan: 02-02
phase: 02-coredata-repository
status: complete
completed: 2026-05-16
commits:
  - 9f1b49a (Task 1 — FlightEntityMigrationPolicy)
  - d389d79 (Task 2 checkpoint — V2 model, mapping model, compilation fixes)
key-files:
  created:
    - Block-Time/Migration/FlightEntityMigrationPolicy.swift
    - Block-Time/FlightDataModel.xcdatamodeld/FlightDataModelV2.xcdatamodel/contents
    - FlightDataModelV1toV2.xcmappingmodel/xcmapping.xml
    - Block-Time/FlightDataModel.xcdatamodeld/.xccurrentversion
  modified:
    - Block-Time/Models/FlightLogbook.swift
    - Block-Time/Services/PlannedFlightService.swift
---

## What Was Built

### Task 1: FlightEntityMigrationPolicy (automated)
- `Block-Time/Migration/FlightEntityMigrationPolicy.swift` created with inline `stringToMinutes` (→ Int16) and `stringToDate` (→ Date?) conversion
- No import SwiftData, no reference to TimeStringConverter (D-01)
- Algorithm character-identical to the copy verified by Plan 02-01's FlightMigrationConversionTests

### Task 2: Xcode UI checkpoint (human-completed)
- `FlightDataModelV1.xcdatamodel` — V1 renamed inside bundle
- `FlightDataModelV2.xcdatamodel` — V2 added, set as current version (.xccurrentversion points to V2)
- V2 FlightEntity: 12 String? attributes renamed to *Legacy; 9 new Int16 scalar attributes (Use Scalar Type checked); 4 new Date? gate attributes
- `FlightDataModelV1toV2.xcmappingmodel` — mapping model saved at project root, target membership: Block-Time
- FlightEntityMigrationPolicy attached to FlightEntityToFlightEntity entity mapping (no module prefix)

### Compilation fixes (schema migration fallout)
- `FlightLogbook.swift` `from(entity:)`: removed `if let` on Int16 scalars; added `minutesToDecimal()` (Int16→decimal-hour String) and `dateToTimeString()` (Date?→"HH:mm" UTC String); added `cachedUTCTimeFormatter`
- `PlannedFlightService.swift`: fixed write sites (String→Int16 literals, String→Date? via `parseTimeString`); fixed `isFlown()` to compare Int16 > 0; added `parseTimeString(_:on:)` static helper

## V2 FlightEntity Final Attribute List

**Carried over unchanged (straight-mapped):**
id (UUID), date (Date), createdAt (Date), modifiedAt (Date?), importedAt (Date?), importSessionID (String?),
fromAirport, toAirport, flightNumber, aircraftType, aircraftReg, captainName, foName, so1Name, so2Name, remarks (String?),
dayTakeoffs, nightTakeoffs, dayLandings, nightLandings, customCount (Int16 scalar),
isILS, isGLS, isRNP, isNPA, isAIII, isPilotFlying, isPositioning (Bool scalar)

**Renamed *Legacy (kept as Optional String):**
blockTimeLegacy, simTimeLegacy, nightTimeLegacy, p1TimeLegacy, p1usTimeLegacy, p2TimeLegacy, instrumentTimeLegacy, spInsTimeLegacy,
outTimeLegacy, inTimeLegacy, scheduledDepartureLegacy, scheduledArrivalLegacy

**New Int16 scalar (default 0, Use Scalar Type checked):**
blockTime, simTime, nightTime, p1Time, p1usTime, p2Time, instrumentTime, spInsTime, dualTime

**New Date? (optional, no scalar):**
outTime, inTime, scheduledDeparture, scheduledArrival

## Entity Mapping
- Mapping model name: `FlightDataModelV1toV2`
- Entity mapping name: `FlightEntityToFlightEntity`
- Custom Policy: `FlightEntityMigrationPolicy` (no module prefix — D-15)

## Deviations
- Mapping model saved at project root (`FlightDataModelV1toV2.xcmappingmodel/`) rather than `Block-Time/` — functionally identical, Xcode includes it in the bundle via project.pbxproj target membership
- 118 build errors remain from `SwiftDataFlightRepository.swift` — this file is deleted in Plan 02-04 (Wave 3); errors are expected at this stage
