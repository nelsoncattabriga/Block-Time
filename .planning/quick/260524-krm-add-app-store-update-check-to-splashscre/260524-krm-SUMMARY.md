---
phase: quick-260524-krm
plan: 01
subsystem: splash-screen, update-check
tags: [app-store, update-check, splash, networking, caching]
dependency_graph:
  requires: []
  provides: [AppUpdateService, splash-update-alert]
  affects: [SplashScreenView]
tech_stack:
  added: []
  patterns: [static-enum-namespace, async-let-concurrency, userdefaults-cache]
key_files:
  created:
    - Block-Time/Services/AppUpdateService.swift
  modified:
    - Block-Time/Views/Screens/SplashScreenView.swift
decisions:
  - "Static enum namespace (not class/singleton) for AppUpdateService — pure, testable, no shared state"
  - "async let for concurrent update check — check runs during 1s splash delay, no added latency"
  - "Fail-safe empty results: region-locked lookup returning resultCount=0 treated as up to date"
  - "Cache on successful comparison only: network/decode errors do not poison the cache"
metrics:
  duration: ~4 minutes
  completed: 2026-05-24
  tasks_completed: 2
  files_modified: 2
---

# Quick Task 260524-krm: Add App Store Update Check to SplashScreenView Summary

**One-liner:** iTunes lookup on splash with 24h UserDefaults cache, concurrent with 1s animation, alert gates app entry when newer version found.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create AppUpdateService with cached iTunes lookup | 10a1c5a | Block-Time/Services/AppUpdateService.swift |
| 2 | Wire update check + alert into SplashScreenView | c5e9e7b | Block-Time/Views/Screens/SplashScreenView.swift |

## What Was Built

### AppUpdateService.swift (new)

Static `enum` namespace with a single public entry point:

```swift
static func checkForUpdate() async -> String?
```

- Fetches `https://itunes.apple.com/lookup?bundleId=com.thezoolab.blocktime`
- Numeric component-wise version comparison (`1.10.0 > 1.9.0` handled correctly)
- 24h cache via two UserDefaults keys: `appUpdateLastCheckDate` + `appUpdateCachedStoreVersion`
- Empty results array (`resultCount: 0`) → nil (fail-safe for region-locked lookup)
- Network/decode errors → nil, cache NOT updated
- No UIKit/SwiftUI import — Foundation only

### SplashScreenView.swift (modified)

- `@Environment(\.openURL)` added
- `@State private var availableUpdateVersion: String? = nil`
- `@State private var showUpdateAlert = false`
- `.task` uses `async let updateCheck = AppUpdateService.checkForUpdate()` concurrent with existing 1s sleep — zero added latency
- `.alert("Update Available")` gating entry: Update button opens `https://apps.apple.com/app/id6758280518` then proceeds; Later proceeds immediately
- "Update Available!" footnote badge (orange Capsule, `.white.opacity(0.85)`) shown below version text when update detected
- All existing `.onAppear` migrations, TRIAL badge, version display, animation — untouched

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Verification Checklist

- [x] AppUpdateService.swift exists under Block-Time/Services/
- [x] Static enum, no singleton, no class, Foundation-only
- [x] iTunes lookup uses bundleId `com.thezoolab.blocktime`, no country param
- [x] Empty results and network errors both return nil
- [x] All existing SplashScreenView migrations preserved unchanged
- [x] Update button targets `https://apps.apple.com/app/id6758280518`
- [x] 24h cache keys: `appUpdateLastCheckDate`, `appUpdateCachedStoreVersion`
- [x] Update check runs concurrently with 1s animation (async let pattern)

## Self-Check: PASSED

Files created:
- Block-Time/Services/AppUpdateService.swift — FOUND
- Block-Time/Views/Screens/SplashScreenView.swift — modified FOUND

Commits:
- 10a1c5a — FOUND
- c5e9e7b — FOUND
