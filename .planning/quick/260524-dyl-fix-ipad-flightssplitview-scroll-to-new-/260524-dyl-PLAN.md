---
phase: quick-260524-dyl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Views/Screens/FlightsSplitView.swift
autonomous: true
requirements:
  - fix-ipad-scroll-to-new-flight

must_haves:
  truths:
    - "After saving a new flight on iPad split view, the list scrolls to show that flight"
    - "Existing launch-scroll behaviour (scroll to current day on first load) is unchanged"
  artifacts:
    - path: "Block-Time/Views/Screens/FlightsSplitView.swift"
      provides: "FlightsListContent with pendingScrollToLatest flag"
      contains: "pendingScrollToLatest"
  key_links:
    - from: "AddFlightView (save action)"
      to: "FlightsListContent.flightListContent"
      via: "NotificationCenter .flightAdded -> pendingScrollToLatest = true -> onChange scroll"
---

<objective>
Fix iPad FlightsSplitView not scrolling to a newly saved flight.

Purpose: After saving, the user should immediately see the new entry without manually scrolling.
Output: Three surgical edits inside FlightsListContent in FlightsSplitView.swift — no other files touched.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@Block-Time/Views/Screens/FlightsSplitView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add pendingScrollToLatest flag and wire into flightAdded + onChange</name>
  <files>Block-Time/Views/Screens/FlightsSplitView.swift</files>
  <action>
Three targeted edits inside the `FlightsListContent` struct. Do NOT touch any other struct, function, or file.

**Sort order confirmed:** `filteredFlightSectors` is newest-first (default sort). The newest flight (just added) will be at index 0 — scroll target is `sectors.first?.id`.

**Edit 1 — Add state var** (immediately after line 207 `@State private var hasScrolledOnLaunch = false`):
```swift
@State private var pendingScrollToLatest = false
```

**Edit 2 — Update `.onReceive(.flightAdded)` handler** (lines 308-310, currently):
```swift
.onReceive(NotificationCenter.default.publisher(for: .flightAdded)) { _ in
    hasScrolledOnLaunch = false
}
```
Replace body with:
```swift
.onReceive(NotificationCenter.default.publisher(for: .flightAdded)) { _ in
    hasScrolledOnLaunch = false
    pendingScrollToLatest = true
}
```

**Edit 3 — Update `.onChange(of: filteredFlightSectors)`** (lines 296-307, currently):
```swift
.onChange(of: filteredFlightSectors) { _, sectors in
    guard !hasScrolledOnLaunch, !sectors.isEmpty else { return }
    hasScrolledOnLaunch = true
    let anchorID = sectors.first(where: {
        $0.blockTimeValue > 0 || $0.simTimeValue > 0 || $0.isPositioning
    })?.id ?? sectors.last?.id
    if let id = anchorID {
        Task { @MainActor in
            proxy.scrollTo(id, anchor: .top)
        }
    }
}
```
Replace with:
```swift
.onChange(of: filteredFlightSectors) { _, sectors in
    if pendingScrollToLatest, !sectors.isEmpty {
        pendingScrollToLatest = false
        if let id = sectors.first?.id {
            Task { @MainActor in
                proxy.scrollTo(id, anchor: .top)
            }
        }
        return
    }
    guard !hasScrolledOnLaunch, !sectors.isEmpty else { return }
    hasScrolledOnLaunch = true
    let anchorID = sectors.first(where: {
        $0.blockTimeValue > 0 || $0.simTimeValue > 0 || $0.isPositioning
    })?.id ?? sectors.last?.id
    if let id = anchorID {
        Task { @MainActor in
            proxy.scrollTo(id, anchor: .top)
        }
    }
}
```

Note: `proxy` is in scope — the `.onChange` modifier is inside the `ScrollViewReader { proxy in ... }` closure (line 266).
  </action>
  <verify>
Build succeeds. On iPad: add a new flight, save it — the list scrolls to the top showing the new entry. Re-launch the app — existing launch-scroll still works (scrolls to current-day flight).
  </verify>
  <done>
- `pendingScrollToLatest` state var present in FlightsListContent
- `.onReceive(.flightAdded)` sets both `hasScrolledOnLaunch = false` and `pendingScrollToLatest = true`
- `.onChange(of: filteredFlightSectors)` checks `pendingScrollToLatest` first; if set, scrolls to `sectors.first` and returns; otherwise falls through to existing launch-scroll logic unchanged
- No other code modified
  </done>
</task>

</tasks>

<verification>
- Build with no new errors or warnings
- On iPad landscape: save new flight → list scrolls to top showing new entry
- On iPad launch: list still auto-scrolls to most-recent flown flight (existing behaviour intact)
</verification>

<success_criteria>
New flight is visible immediately after save without manual scroll. Launch scroll is unaffected.
</success_criteria>

<output>
After completion, create `.planning/quick/260524-dyl-fix-ipad-flightssplitview-scroll-to-new-/260524-dyl-SUMMARY.md`
</output>
