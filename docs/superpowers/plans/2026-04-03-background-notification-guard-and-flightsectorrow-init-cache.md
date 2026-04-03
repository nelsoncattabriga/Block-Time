# Background Notification Guard & FlightSectorRow Init Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent `.flightDataChanged` notifications firing while the app is backgrounded, and eliminate the two-render flash on `FlightSectorRow` first appearance.

**Architecture:** Fix 1 adds background-state tracking to `FlightDatabaseService` using `UIScene` notifications — all notification post sites gain an `isAppInBackground` guard that defers to a pending flag, flushed on foreground activation. Fix 2 replaces `@State` cached properties in `FlightSectorRow` with `let` constants computed in a custom `init`, eliminating the `onAppear`/`onChange` update cycle.

**Tech Stack:** Swift 6, SwiftUI, UIKit (`UIScene` notifications), Core Data / CloudKit, iOS 18.6+

---

## File Map

| File | Change |
|------|--------|
| `Block-Time/Services/FlightDatabaseService.swift` | Add `isAppInBackground`, `pendingDataChanged` properties; add scene lifecycle observers; add guard to immediate and debounced notification post sites |
| `Block-Time/Views/Components/FlightSectorRow.swift` | Replace `@State cached*` with `let` constants; add custom `init`; remove `onAppear`, `onChange`, `updateCachedValues()`, pass-through computed vars |

---

## Task 1: Add background-state properties to `FlightDatabaseService`

**Files:**
- Modify: `Block-Time/Services/FlightDatabaseService.swift` (near line 54, in the rate-limiting properties section)

- [ ] **Step 1: Add the two new properties**

Open `FlightDatabaseService.swift`. Locate the `// MARK: - Rate limiting for remote store changes` block (around line 54). Add the following two properties directly after it:

```swift
// MARK: - Background state tracking
private var isAppInBackground: Bool = false
private var pendingDataChanged: Bool = false
```

- [ ] **Step 2: Verify the file compiles**

Build the project (`Cmd+B`). Expected: build succeeds with no new errors.

- [ ] **Step 3: Commit**

```bash
git add "Block-Time/Services/FlightDatabaseService.swift"
git commit -m "feat: add isAppInBackground and pendingDataChanged properties to FlightDatabaseService"
```

---

## Task 2: Register scene lifecycle observers and handler methods

**Files:**
- Modify: `Block-Time/Services/FlightDatabaseService.swift`

- [ ] **Step 1: Add observers in `setupCloudKitNotifications()`**

Locate `setupCloudKitNotifications()` (around line 2512). At the end of the method, just before the closing `}`, add:

```swift
// Monitor scene lifecycle to suppress notifications while backgrounded
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

- [ ] **Step 2: Add the handler methods**

Add the following two methods directly after `handleRemoteStoreChange(_:)` (around line 2580):

```swift
@objc private func handleAppDidEnterBackground() {
    isAppInBackground = true
    LogManager.shared.debug("FlightDatabaseService: App entered background — notifications suppressed")
}

@objc private func handleAppDidBecomeActive() {
    isAppInBackground = false
    LogManager.shared.debug("FlightDatabaseService: App became active — isAppInBackground cleared")
    if pendingDataChanged {
        pendingDataChanged = false
        LogManager.shared.info("FlightDatabaseService: Posting deferred .flightDataChanged (background→foreground)")
        NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        Task { @MainActor in
            WidgetDataWriter.shared.updateWidgetSnapshot()
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Build the project (`Cmd+B`). Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add "Block-Time/Services/FlightDatabaseService.swift"
git commit -m "feat: register UIScene lifecycle observers in FlightDatabaseService for background notification guard"
```

---

## Task 3: Guard the immediate notification post site in `contextDidSave`

**Files:**
- Modify: `Block-Time/Services/FlightDatabaseService.swift` (around line 2606–2612)

- [ ] **Step 1: Locate the immediate post in `contextDidSave`**

Find the `else` branch in `contextDidSave` that handles local (non-CloudKit, non-batch) saves. It currently reads:

```swift
} else {
    // Local user change - post immediate notification for instant UI feedback
    LogManager.shared.debug("FlightDatabaseService: Context saved (local change): +\(insertedObjects.count) ~\(updatedObjects.count) -\(deletedObjects.count)")
    DispatchQueue.main.async {
        LogManager.shared.info("FlightDatabaseService: Posting .flightDataChanged (immediate)")
        NotificationCenter.default.post(name: .flightDataChanged, object: nil)
    }
}
```

- [ ] **Step 2: Replace with the background-guarded version**

```swift
} else {
    // Local user change - post immediate notification for instant UI feedback
    LogManager.shared.debug("FlightDatabaseService: Context saved (local change): +\(insertedObjects.count) ~\(updatedObjects.count) -\(deletedObjects.count)")
    DispatchQueue.main.async {
        if self.isAppInBackground {
            self.pendingDataChanged = true
            LogManager.shared.debug("FlightDatabaseService: Deferred .flightDataChanged (app in background)")
        } else {
            LogManager.shared.info("FlightDatabaseService: Posting .flightDataChanged (immediate)")
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Build the project (`Cmd+B`). Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add "Block-Time/Services/FlightDatabaseService.swift"
git commit -m "feat: guard immediate .flightDataChanged post against background state in contextDidSave"
```

---

## Task 4: Guard the debounced notification post site in `postDebouncedFlightDataChangedNotification`

**Files:**
- Modify: `Block-Time/Services/FlightDatabaseService.swift` (around line 1553–1568)

- [ ] **Step 1: Locate `postDebouncedFlightDataChangedNotification`**

Find the method (around line 1553). The timer callback currently reads:

```swift
notificationDebounceTimer = Timer.scheduledTimer(withTimeInterval: notificationDebounceInterval, repeats: false) { _ in
    DispatchQueue.main.async {
        LogManager.shared.info("FlightDatabaseService: Posting .flightDataChanged (debounced)")
        NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        // Refresh widget snapshot whenever flight data changes
        Task { @MainActor in
            WidgetDataWriter.shared.updateWidgetSnapshot()
        }
    }
}
```

- [ ] **Step 2: Replace the timer callback with the background-guarded version**

```swift
notificationDebounceTimer = Timer.scheduledTimer(withTimeInterval: notificationDebounceInterval, repeats: false) { _ in
    DispatchQueue.main.async {
        if self.isAppInBackground {
            self.pendingDataChanged = true
            LogManager.shared.debug("FlightDatabaseService: Deferred .flightDataChanged (app in background, debounced)")
        } else {
            LogManager.shared.info("FlightDatabaseService: Posting .flightDataChanged (debounced)")
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
            // Refresh widget snapshot whenever flight data changes
            Task { @MainActor in
                WidgetDataWriter.shared.updateWidgetSnapshot()
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Build the project (`Cmd+B`). Expected: build succeeds.

- [ ] **Step 4: Manual smoke test — background suppression**

1. Run the app on device or simulator
2. Add a new flight (or trigger a CloudKit sync from another device/simulator)
3. Immediately background the app (`Cmd+H` on simulator)
4. Wait a few seconds
5. Bring the app to foreground
6. Expected: flight list refreshes on return to foreground (pending notification fires)
7. Check Xcode console for: `"Deferred .flightDataChanged (app in background"` and `"Posting deferred .flightDataChanged (background→foreground)"`

- [ ] **Step 5: Commit**

```bash
git add "Block-Time/Services/FlightDatabaseService.swift"
git commit -m "feat: guard debounced .flightDataChanged post against background state"
```

---

## Task 5: Replace `@State` cache with `let` constants and custom `init` in `FlightSectorRow`

**Files:**
- Modify: `Block-Time/Views/Components/FlightSectorRow.swift`

This task replaces the entire caching mechanism. Read the full current file before editing.

- [ ] **Step 1: Replace `@State` declarations with `let` constants**

Find the cached property block (lines 16–25):

```swift
// Cached computed values - initialized once
@State private var cachedAirlineLogo: String?
@State private var cachedFromAirportCode: String = ""
@State private var cachedToAirportCode: String = ""
@State private var cachedCrewNames: String = ""
@State private var cachedIsFutureFlight: Bool = false
@State private var cachedOutTime: String = ""
@State private var cachedInTime: String = ""
@State private var cachedDayOfMonth: String = ""
@State private var cachedFormattedDate: String = ""
@State private var cachedDisplayDate: String = ""
```

Replace with:

```swift
// Display values computed once at init
private let cachedAirlineLogo: String?
private let cachedFromAirportCode: String
private let cachedToAirportCode: String
private let cachedCrewNames: String
private let cachedIsFutureFlight: Bool
private let cachedOutTime: String
private let cachedInTime: String
private let cachedDayOfMonth: String
private let cachedFormattedDate: String
private let cachedDisplayDate: String
```

- [ ] **Step 2: Add a custom `init` that computes all display values**

Add the following `init` directly after the `@AppStorage` and `@Environment` property declarations (after the `let` constants block, before the `Equatable` conformance):

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

    // Compute display values once — avoids onAppear two-render flash
    let displayDate = sector.getDisplayDate(useLocalTime: useLocalTime)
    cachedOutTime = sector.getOutTime(useLocalTime: useLocalTime)
    cachedInTime = sector.getInTime(useLocalTime: useLocalTime)
    cachedDisplayDate = displayDate
    cachedFormattedDate = sector.getFormattedDate(useLocalTime: useLocalTime)
    cachedDayOfMonth = sector.getDayOfMonth(useLocalTime: useLocalTime)
    cachedFromAirportCode = AirportService.shared.getDisplayCode(sector.fromAirport, useIATA: useIATACodes)
    cachedToAirportCode = AirportService.shared.getDisplayCode(sector.toAirport, useIATA: useIATACodes)

    // Airline logo
    let includePrefix = UserDefaults.standard.bool(forKey: "includeAirlinePrefixInFlightNumber")
    let isCustomPrefix = UserDefaults.standard.bool(forKey: "isCustomAirlinePrefix")
    if !includePrefix || isCustomPrefix {
        cachedAirlineLogo = nil
    } else {
        let uppercased = sector.flightNumberFormatted.uppercased()
        cachedAirlineLogo = Airline.airlines.first(where: {
            !$0.iconName.isEmpty && uppercased.hasPrefix($0.prefix)
        })?.iconName
    }

    // Crew names
    var crew: [String] = []
    if !sector.captainName.isEmpty { crew.append(sector.captainName) }
    if !sector.foName.isEmpty { crew.append(sector.foName) }
    if let so1 = sector.so1Name, !so1.isEmpty { crew.append(so1) }
    if let so2 = sector.so2Name, !so2.isEmpty { crew.append(so2) }
    cachedCrewNames = crew.isEmpty ? "Self" : crew.joined(separator: ", ")

    // Future flight flag (depends on displayDate computed above)
    let blockTime = sector.blockTimeValue
    let simTime = sector.simTimeValue
    if blockTime != 0 || simTime != 0 {
        cachedIsFutureFlight = false
    } else if sector.isPositioning {
        let hasOutTime = !sector.outTime.isEmpty
        let hasInTime = !sector.inTime.isEmpty
        if hasOutTime && hasInTime {
            cachedIsFutureFlight = false
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            dateFormatter.timeZone = useLocalTime ? TimeZone.current : TimeZone(secondsFromGMT: 0)
            dateFormatter.locale = Locale(identifier: "en_AU")
            if let flightDate = dateFormatter.date(from: displayDate) {
                let todayMidnight = Calendar.current.startOfDay(for: Date())
                cachedIsFutureFlight = flightDate >= todayMidnight
            } else {
                cachedIsFutureFlight = false
            }
        }
    } else {
        cachedIsFutureFlight = true
    }
}
```

- [ ] **Step 3: Remove the private computed pass-through vars and helper functions**

Delete the following blocks entirely from the file:

```swift
// Cache expensive time conversions - computed once per render cycle
private var outTime: String {
    return sector.getOutTime(useLocalTime: useLocalTime)
}

private var inTime: String {
    return sector.getInTime(useLocalTime: useLocalTime)
}

private var displayDate: String {
    return sector.getDisplayDate(useLocalTime: useLocalTime)
}

private var formattedDate: String {
    return sector.getFormattedDate(useLocalTime: useLocalTime)
}

private var dayOfMonth: String {
    return sector.getDayOfMonth(useLocalTime: useLocalTime)
}

// Calculate airline logo lookup
private func calculateAirlineLogo() -> String? { ... }

// Calculate crew names formatting
private func calculateCrewNames() -> String { ... }
```

Also delete `private func updateCachedValues()` and its call sites.

- [ ] **Step 4: Remove `onAppear` and `onChange` from `body`**

In `body`, remove these two modifiers:

```swift
.onAppear {
    updateCachedValues()
}
.onChange(of: sector) { _, _ in
    updateCachedValues()
}
```

- [ ] **Step 5: Build to verify**

Build the project (`Cmd+B`). Expected: build succeeds with no errors. (SourceKit false-positive type errors can be ignored if build succeeds.)

- [ ] **Step 6: Manual smoke test — no flash on scroll**

1. Run the app on device or simulator with a logbook that has several flights
2. Scroll the flight list quickly up and down
3. Expected: flight rows appear fully rendered immediately — no blank date/time flash before content appears
4. Expected: future (rostered) flights show correctly dimmed from first render

- [ ] **Step 7: Commit**

```bash
git add "Block-Time/Views/Components/FlightSectorRow.swift"
git commit -m "feat: replace @State cache with init-computed let constants in FlightSectorRow, eliminating two-render flash"
```

---

## Task 6: Final integration check

- [ ] **Step 1: Full build and run**

Build and run on a device or simulator (`Cmd+R`). Verify:
- App launches without crash
- Flight list scrolls smoothly
- Adding/editing a flight updates the list
- Backgrounding and foregrounding the app while CloudKit syncs (or after editing) still shows updated data

- [ ] **Step 2: Check logs**

In the Xcode console, verify expected log lines appear:
- On background: `"FlightDatabaseService: App entered background — notifications suppressed"`
- On foreground after a background change: `"Posting deferred .flightDataChanged (background→foreground)"`
- On foreground with no background change: no deferred post log

- [ ] **Step 3: Final commit tag**

```bash
git commit --allow-empty -m "chore: background notification guard and FlightSectorRow init cache complete"
```
