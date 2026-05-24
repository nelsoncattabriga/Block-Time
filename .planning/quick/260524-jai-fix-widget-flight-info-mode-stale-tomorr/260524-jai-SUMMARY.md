---
phase: quick-260524-jai
plan: 01
subsystem: widget
tags: [widgetkit, timeline, reload-policy, flight-info]
dependency_graph:
  requires: []
  provides: [midnight-timeline-rebuild]
  affects: [BlockTimeWidget/NextFlightProvider.swift]
tech_stack:
  added: []
  patterns: [TimelineReloadPolicy.after]
key_files:
  modified: [BlockTimeWidget/NextFlightProvider.swift]
decisions:
  - Use .after(nextMidnight) with .atEnd nil-fallback per plan specification
metrics:
  duration: 5m
  completed: 2026-05-24
---

# Quick 260524-jai: Fix Widget Flight Info Mode Stale Tomorrow Label Summary

**One-liner:** `flightInfoTimeline` now uses `.after(nextMidnight)` reload policy so WidgetKit rebuilds at local midnight without an app launch.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Use .after(nextMidnight) reload policy in flightInfoTimeline | 5105bfd | BlockTimeWidget/NextFlightProvider.swift |

## What Was Done

Replaced the final `return Timeline(entries: entries, policy: .atEnd)` in `flightInfoTimeline` (line 134) with a midnight-aware reload policy:

```swift
let nextMidnight = cal.nextDate(
    after: now,
    matching: DateComponents(hour: 0, minute: 0, second: 0),
    matchingPolicy: .nextTime
)
let policy: TimelineReloadPolicy = nextMidnight.map { .after($0) } ?? .atEnd
return Timeline(entries: entries, policy: policy)
```

`cal` was already in scope at the top of `flightInfoTimeline` — reused without redeclaring.

`countdownTimeline` (line 189) and the empty-flights guard (line 49) are untouched — both retain `.atEnd`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- BlockTimeWidget/NextFlightProvider.swift modified: FOUND
- Commit 5105bfd: FOUND
- `.after` in flightInfoTimeline: FOUND (line 139)
- `countdownTimeline` still uses `.atEnd`: FOUND (line 189)
- Empty-flights guard still uses `.atEnd`: FOUND (line 49)
