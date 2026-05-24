---
phase: quick-260524-jai
plan: 01
type: execute
wave: 1
depends_on: []
files_modified: [BlockTimeWidget/NextFlightProvider.swift]
autonomous: true
requirements: [QUICK-260524-jai]

must_haves:
  truths:
    - "Flight Info widget flips 'Tomorrow' to 'Today' at local midnight without opening the app"
    - "WidgetKit is guaranteed to rebuild the Flight Info timeline at the next local midnight"
    - "Countdown mode behaviour is unchanged"
  artifacts:
    - path: "BlockTimeWidget/NextFlightProvider.swift"
      provides: "flightInfoTimeline using .after(nextMidnight) reload policy"
      contains: "policy: .after"
  key_links:
    - from: "flightInfoTimeline return statement"
      to: "WidgetKit reload scheduler"
      via: "TimelineReloadPolicy.after(nextMidnight)"
      pattern: "policy: .after"
---

<objective>
Fix the Flight Info widget showing a stale "Tomorrow" label for a flight that has become today's flight.

Purpose: WidgetKit defers `.atEnd` timeline refreshes by hours, so the midnight entry that flips "Tomorrow" → "Today" is not guaranteed to render on time. The widget only corrects itself when the app launches and calls `WidgetCenter.shared.reloadTimelines`.

Output: `flightInfoTimeline` returns a `Timeline` with `policy: .after(nextMidnight)` so WidgetKit rebuilds the timeline at the next local midnight, guaranteeing the label flip.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

@BlockTimeWidget/NextFlightProvider.swift

<interfaces>
<!-- Relevant existing code in NextFlightProvider.swift -->

`flightInfoTimeline(flights:now:configuration:) -> Timeline<NextFlightTimelineEntry>`
- Builds `entries: [NextFlightTimelineEntry]` including midnight rollover entries.
- Currently ends with: `return Timeline(entries: entries, policy: .atEnd)` (line 134).
- `let cal = Calendar.current` is already in scope (line 64).
- Midnight is computed elsewhere in the function via:
  `cal.nextDate(after:, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime)`

`countdownTimeline(...)` — separate function, uses `Text(.relative)` for live timer. MUST NOT be changed (its `.atEnd` is correct).

The empty-flights guard in `timeline(for:in:)` (line 49) is unrelated and stays `.atEnd`.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Use .after(nextMidnight) reload policy in flightInfoTimeline</name>
  <files>BlockTimeWidget/NextFlightProvider.swift</files>
  <action>
In `flightInfoTimeline` only, replace the final `return Timeline(entries: entries, policy: .atEnd)` (line 134) with a version that computes the next local midnight after `now` and uses `.after(nextMidnight)`.

Compute next midnight using the same Calendar pattern already used in this function:
```swift
let nextMidnight = cal.nextDate(
    after: now,
    matching: DateComponents(hour: 0, minute: 0, second: 0),
    matchingPolicy: .nextTime
)
let policy: TimelineReloadPolicy = nextMidnight.map { .after($0) } ?? .atEnd
return Timeline(entries: entries, policy: policy)
```
`cal` is already defined at the top of the function — reuse it, do not redeclare.

This guarantees WidgetKit rebuilds the timeline at the next local midnight even when no flight occurs before midnight (label still flips daily). The `.atEnd` fallback only applies in the (effectively impossible) case where `nextDate` returns nil.

Do NOT touch `countdownTimeline` — its `.atEnd` policy is correct because `Text(.relative)` drives its live timer.
Do NOT touch the empty-flights guard at line 49.
Invoke the `swiftui-pro` skill before editing (project rule).
  </action>
  <verify>
    <automated>grep -n "policy: .after" BlockTimeWidget/NextFlightProvider.swift && grep -c "policy: .atEnd" BlockTimeWidget/NextFlightProvider.swift</automated>
  </verify>
  <done>`flightInfoTimeline` returns a Timeline with `.after(nextMidnight)` policy; `countdownTimeline` and the empty-flights guard still use `.atEnd` (so exactly 2 `.atEnd` occurrences remain). File compiles.</done>
</task>

</tasks>

<verification>
- `grep -n "policy: .after" BlockTimeWidget/NextFlightProvider.swift` returns the new line inside `flightInfoTimeline`.
- `countdownTimeline` still ends with `policy: .atEnd`.
- The empty-flights guard (line ~49) still uses `policy: .atEnd`.
- Project builds (Nelson builds locally — do not build unless asked).
</verification>

<success_criteria>
- Flight Info widget flips "Tomorrow" → "Today" at local midnight without launching the app.
- Countdown mode behaviour unchanged.
- No other widget logic altered.
</success_criteria>

<output>
After completion, create `.planning/quick/260524-jai-fix-widget-flight-info-mode-stale-tomorr/260524-jai-SUMMARY.md`
</output>
