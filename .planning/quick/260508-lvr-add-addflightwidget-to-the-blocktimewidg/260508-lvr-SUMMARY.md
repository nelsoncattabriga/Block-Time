---
phase: quick
plan: 260508-lvr
subsystem: widgets
tags: [widget, deep-link, url-scheme, notification, camera]
key-files:
  created:
    - BlockTimeWidget/AddFlightWidgetView.swift
  modified:
    - BlockTimeWidget/BlockTimeWidgetBundle.swift
    - Block-Time/Info.plist
    - Block-Time/Models/Notifications.swift
    - Block-Time/Services/AppState.swift
    - Block-Time/Block_TimeApp.swift
    - Block-Time/Views/Screens/MainTabView.swift
    - Block-Time/Views/Screens/FlightsView.swift
    - Block-Time/Views/Screens/AddFlightView.swift
decisions:
  - Notification names added to existing Notifications.swift (not a new file) — file already existed with correct naming pattern
  - triggerCamera added as @Published on AppState (ObservableObject) to match existing class design
metrics:
  duration: ~15m
  completed: 2026-05-08
---

# Quick Task 260508-LVR: Add AddFlightWidget Summary

**One-liner:** New AddFlightWidget (small + medium) with blocktime:// URL scheme deep-linking into AddFlightView and optional ACARS camera auto-trigger.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Widget file + bundle + URL scheme | 121d50a | AddFlightWidgetView.swift (new), BlockTimeWidgetBundle.swift, Info.plist |
| 2 | Deep-link handler + AppState + notifications | e177e9b | Block_TimeApp.swift, AppState.swift, Notifications.swift |
| 3 | Listener wiring + camera trigger | 54cc7d3 | MainTabView.swift, FlightsView.swift, AddFlightView.swift |
| 4 | Manual verification | (checkpoint — Nelson to verify) | — |

## What Was Built

### AddFlightWidgetView.swift
- `AddFlightProvider` reads `selectedFleetID` from App Group UserDefaults (`group.com.thezoolab.blocktime`) to determine `captureSupported`
- Small widget: full-tile `Link` to `blocktime://add-flight` with `plus.circle.fill` icon and WT orange styling
- Medium widget: two-tile layout (Add Flight | Capture ACARS) when fleet is in `{B737, A330, B787, A320, A380}`; degrades to single full-width tile otherwise
- `WT` design-token enum duplicated from `NextFlightWidgetView.swift` (widget targets cannot share code with app target)
- `.contentMarginsDisabled()` + `.containerBackground(for: .widget) { Color.clear }` for iOS 17+ widget rendering

### URL scheme plumbing
- `blocktime://add-flight` → posts `.openAddFlight`
- `blocktime://add-flight?capture=true` → posts `.openAddFlightCapture`
- Added to `handleIncomingURL` as a first check with early `return` — all existing file-extension logic preserved

### Notification names
- `.openAddFlight` and `.openAddFlightCapture` added to existing `Notifications.swift`

### AppState
- `@Published var triggerCamera: Bool = false` added — reset to `false` inside `AddFlightView.onAppear` before calling `showCamera()` to prevent double-fire

### Listener chain
- `MainTabView` → switches to tab 0 on either notification
- `FlightsView` → sets `AppState.shared.triggerCamera = true` BEFORE `isAddingNewFlight = true` (order critical)
- `AddFlightView.onAppear` → reads flag, resets it, calls `viewModel.showCamera()`

## Task 4: Manual Verification Checklist

Nelson to verify after build:

1. Long-press home screen → "Add Flight" widget appears in gallery, both small and medium previews render with orange WT styling
2. Small widget tap → Block-Time foregrounds, Logbook tab selected, AddFlightView pushed
3. With fleet set to B737/A330/B787/A320/A380: medium widget shows two tiles (Add Flight | Capture ACARS)
   - Left tile tap → AddFlightView opens, no camera
   - Right tile tap → AddFlightView opens, ACARS camera sheet auto-presents
4. With fleet set to unsupported type: medium widget shows single full-width Add Flight tile
5. Existing NextFlightWidget unchanged and functional

## Deviations from Plan

None — plan executed exactly as written. One minor note: the plan mentioned creating a `Notification+Names.swift` file in `Extensions/`, but the project already had `Models/Notifications.swift` with the same pattern. Names were added there to keep notification constants in one place (no functional difference).

## Known Stubs

None.

## Self-Check: PASSED

Files exist:
- BlockTimeWidget/AddFlightWidgetView.swift — created
- BlockTimeWidget/BlockTimeWidgetBundle.swift — AddFlightWidget() added
- Block-Time/Info.plist — CFBundleURLTypes with blocktime scheme added
- Block-Time/Models/Notifications.swift — openAddFlight + openAddFlightCapture added
- Block-Time/Services/AppState.swift — triggerCamera added
- Block-Time/Block_TimeApp.swift — blocktime:// handler added
- Block-Time/Views/Screens/MainTabView.swift — two onReceive handlers added
- Block-Time/Views/Screens/FlightsView.swift — two onReceive handlers added
- Block-Time/Views/Screens/AddFlightView.swift — camera trigger in onAppear added

Commits verified: 121d50a, e177e9b, 54cc7d3 — all present in git log.
