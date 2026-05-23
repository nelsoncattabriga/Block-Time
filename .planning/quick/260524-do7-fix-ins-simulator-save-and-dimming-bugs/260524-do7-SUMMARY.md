---
id: 260524-do7
type: quick
date: 2026-05-24
duration: ~5 min
tasks_completed: 1/1
files_modified:
  - Block-Time/ViewModels/FlightTimeExtractorViewModel.swift
  - Block-Time/Views/Components/FlightSectorRow.swift
commits:
  - 6e08dbf
tags: [ins, simulator, dimming, bug-fix]
---

# Quick Task 260524-do7: Fix INS|Simulator Save and Dimming Bugs

**One-liner:** Fixed blank SIM field saving full INS time as simTime, and INS-only flights incorrectly dimming as rostered.

## Changes

### Fix 1 — FlightTimeExtractorViewModel.swift (3 sites)

Replaced `?? ins` fallback with `?? 0` in all three INS sim-time calculations:

```swift
// Before (wrong — blank field copied full INS value)
let sim = min(Double(simInsTime) ?? ins, ins)

// After (correct — blank field gives 0)
let sim = min(Double(simInsTime) ?? 0, ins)
```

Sites: ~lines 1584, 1897, 2815.

### Fix 2 — FlightSectorRow.swift

Added `sector.spInsTimeValue == 0` to `calculateIsFutureFlight()` guard so INS|Sim flights with spInsTime > 0 are not dimmed:

```swift
// Before
guard blockTime == 0 && simTime == 0 else { return false }

// After
guard blockTime == 0 && simTime == 0 && sector.spInsTimeValue == 0 else { return false }
```

## Deviations from Plan

None — executed exactly as specified.

## Self-Check: PASSED

- Commit 6e08dbf exists: confirmed
- No remaining `?? ins` in FlightTimeExtractorViewModel.swift: confirmed (grep returns no matches)
- `spInsTimeValue` in FlightSectorRow.swift guard: confirmed (line 75)
