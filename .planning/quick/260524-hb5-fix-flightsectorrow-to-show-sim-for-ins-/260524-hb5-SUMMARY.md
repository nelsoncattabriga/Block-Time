---
phase: quick
plan: 260524-hb5
subsystem: FlightSectorRow
tags: [bug-fix, INS, simulator, flight-list]
key-files:
  modified:
    - Block-Time/Views/Components/FlightSectorRow.swift
decisions:
  - OR spInsTimeValue > 0 into Sim/Flt ternary — minimal change, no side effects
metrics:
  duration: "< 5 minutes"
  completed: 2026-05-24
  tasks: 1
  files: 1
---

# Phase quick Plan 260524-hb5: Fix FlightSectorRow Sim/Flt Label for INS Simulator Flights Summary

**One-liner:** Added `|| sector.spInsTimeValue > 0` to the Sim/Flt ternary so INS|Simulator flights correctly show "Sim".

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Include spInsTimeValue in the Sim/Flt label condition | 80ab8f2 | Block-Time/Views/Components/FlightSectorRow.swift |

## What Changed

`FlightSectorRow.swift` line 218:

Before: `Text(sector.simTimeValue > 0 ? "Sim" : "Flt")`
After: `Text((sector.simTimeValue > 0 || sector.spInsTimeValue > 0) ? "Sim" : "Flt")`

INS|Simulator flights (isSpIns=true, isInstructingInAircraft=false) store their time in `spInsTime`, not `simTime`. The old condition only checked `simTime`, so these rows displayed "Flt" instead of "Sim". The OR clause corrects this without affecting any other flight type.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- File modified: Block-Time/Views/Components/FlightSectorRow.swift — FOUND
- Commit 80ab8f2 — FOUND
- grep confirms `sector.simTimeValue > 0 || sector.spInsTimeValue > 0` at line 218
