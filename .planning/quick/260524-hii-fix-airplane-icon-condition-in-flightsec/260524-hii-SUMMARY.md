---
phase: quick
plan: 260524-hii
subsystem: FlightSectorRow
tags: [bug-fix, ins-simulator, airplane-icon]
key-files:
  modified:
    - Block-Time/Views/Components/FlightSectorRow.swift
decisions:
  - Extend sim-type guard to include spInsTimeValue so INS|Sim flights require airports before showing airplane icon
metrics:
  duration: "< 5 minutes"
  completed: 2026-05-24
  tasks: 1
  files: 1
---

# Quick Task 260524-hii: Fix Airplane Icon Condition in FlightSectorRow

## One-liner

Guard `spInsTimeValue == 0` added alongside `simTimeValue == 0` so INS|Simulator flights without airports hide the airplane icon.

## What Changed

**File:** `Block-Time/Views/Components/FlightSectorRow.swift` line 261

**Before:**
```swift
if sector.simTimeValue == 0 || (!sector.fromAirport.isEmpty && !sector.toAirport.isEmpty) {
```

**After:**
```swift
if (sector.simTimeValue == 0 && sector.spInsTimeValue == 0) || (!sector.fromAirport.isEmpty && !sector.toAirport.isEmpty) {
```

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 75c1c25 | fix(quick-260524-hii): hide airplane icon for INS|Sim flights without airports |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- File modified: Block-Time/Views/Components/FlightSectorRow.swift — FOUND
- Condition string `sector.simTimeValue == 0 && sector.spInsTimeValue == 0` at line 261 — FOUND
- Commit 75c1c25 — FOUND
