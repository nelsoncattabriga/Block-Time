# Design: Background Notification Guard & FlightSectorRow Init Cache

**Date:** 2026-04-03  
**Branch:** Build_1.7.4

---

## Overview

Two independent fixes addressing layout churn and a potential background-triggered layout crash found in crash log analysis.

---

## Fix 1 — Background Notification Guard in `FlightDatabaseService`

### Problem

`contextDidSave` and `handleRemoteStoreChange` post `.flightDataChanged` unconditionally. CloudKit sync can fire these handlers while the app is backgrounded, causing `loadFlights()` to run and trigger a full list re-render while the UI is not visible. This was identified as a contributing factor in crash logs where the app was backgrounded when killed and a background data change may have triggered layout work.

### Solution

Track app background state inside `FlightDatabaseService` using `UIScene` notifications. Suppress `.flightDataChanged` posts while backgrounded; set a pending flag instead. Post once on foreground activation if the flag is set.

### Changes to `FlightDatabaseService`

**New properties:**
```swift
private var isAppInBackground: Bool = false
private var pendingDataChanged: Bool = false
```

**In `setupCloudKitNotifications()`**, add two new observers:
```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleAppDidEnterBackground),
    name: UIScene.didEnterBackgroundNotification,
    object: nil
)
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleAppDidBecomeActive),
    name: UIScene.didActivateNotification,
    object: nil
)
```

**New handler methods:**
```swift
@objc private func handleAppDidEnterBackground() {
    isAppInBackground = true
}

@objc private func handleAppDidBecomeActive() {
    isAppInBackground = false
    if pendingDataChanged {
        pendingDataChanged = false
        NotificationCenter.default.post(name: .flightDataChanged, object: nil)
    }
}
```

**Posting guard** — applied at every `.flightDataChanged` post site:
- Immediate post path in `contextDidSave` (local changes)
- Debounce timer callback in `postDebouncedFlightDataChangedNotification`

Pattern at each site:
```swift
if isAppInBackground {
    pendingDataChanged = true
} else {
    NotificationCenter.default.post(name: .flightDataChanged, object: nil)
}
```

The existing `isBatchImporting` early-return in `handleRemoteStoreChange` is preserved; the background guard is additive.

### Affected files

- `Block-Time/Services/FlightDatabaseService.swift`

---

## Fix 2 — `FlightSectorRow` Init-Computed `let` Properties

### Problem

`FlightSectorRow` stores computed display values (times, airport codes, crew names, future-flight flag) as `@State` properties initialised to empty/default values. They are only populated in `onAppear`. This causes a two-render flash on first appearance: the view renders with empty values, then `onAppear` fires and updates the state, changing sizes and triggering layout churn that amplifies list scroll performance issues.

### Solution

Replace all `@State private var cached*` properties with stored `let` constants computed once in a custom `init`. Since `FlightSectorRow` is an `Equatable` struct, SwiftUI re-creates it (re-running `init`) whenever a compared field on `sector` changes — the `@State` persistence was providing no benefit.

### Changes to `FlightSectorRow`

**Remove:**
- All `@State private var cached*` declarations
- `onAppear { updateCachedValues() }`
- `onChange(of: sector) { updateCachedValues() }`
- `private func updateCachedValues()`
- Private computed `var outTime`, `var inTime`, `var displayDate`, `var formattedDate`, `var dayOfMonth` (pass-through properties no longer needed)
- `private func calculateAirlineLogo()` and `private func calculateCrewNames()` — inlined into `init` or kept as `private static func` for clarity

**Add a custom `init`** that accepts the same parameters as the current memberwise init and computes all display values eagerly:

```swift
init(
    sector: FlightSector,
    useLocalTime: Bool = false,
    useIATACodes: Bool = false,
    showTimesInHoursMinutes: Bool = false,
    roundingMode: RoundingMode = .standard
) {
    self.sector = sector
    self.useLocalTime = useLocalTime
    self.useIATACodes = useIATACodes
    self.showTimesInHoursMinutes = showTimesInHoursMinutes
    self.roundingMode = roundingMode

    // Compute display values once
    let displayDate = sector.getDisplayDate(useLocalTime: useLocalTime)
    self.cachedOutTime = sector.getOutTime(useLocalTime: useLocalTime)
    self.cachedInTime = sector.getInTime(useLocalTime: useLocalTime)
    self.cachedDisplayDate = displayDate
    self.cachedFormattedDate = sector.getFormattedDate(useLocalTime: useLocalTime)
    self.cachedDayOfMonth = sector.getDayOfMonth(useLocalTime: useLocalTime)
    self.cachedFromAirportCode = AirportService.shared.getDisplayCode(sector.fromAirport, useIATA: useIATACodes)
    self.cachedToAirportCode = AirportService.shared.getDisplayCode(sector.toAirport, useIATA: useIATACodes)
    // ... crew names and airline logo logic inline
    // ... isFutureFlight computed last (depends on displayDate)
}
```

**Property declarations** change from `@State private var` to `private let`.

**`body`** references the `let` constants directly — no behaviour change.

The `Equatable` conformance and `static let cachedDateFormatter` are unchanged.

### Affected files

- `Block-Time/Views/Components/FlightSectorRow.swift`

---

## What is NOT changing

- Finding 3 (cold launch < 60s background fetch crash) — informational, no code change needed.
- `FlightDatabaseService` debounce timer logic — unchanged, only the post sites gain the background guard.
- `FlightSectorRow` `Equatable` conformance — unchanged.
- All call sites of `FlightSectorRow` — the init signature is compatible.
