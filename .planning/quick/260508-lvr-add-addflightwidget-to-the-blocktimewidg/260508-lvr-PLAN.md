---
phase: quick
plan: 260508-lvr
type: execute
wave: 1
depends_on: []
files_modified:
  - BlockTimeWidget/AddFlightWidgetView.swift
  - BlockTimeWidget/BlockTimeWidgetBundle.swift
  - Block-Time/Info.plist
  - Block-Time/Block_TimeApp.swift
  - Block-Time/Services/AppState.swift
  - Block-Time/Views/Screens/MainTabView.swift
  - Block-Time/Views/Screens/FlightsView.swift
  - Block-Time/Views/Screens/AddFlightView.swift
  - Block-Time/Extensions/Notification+Names.swift
autonomous: false
requirements: [QUICK-260508-LVR]

must_haves:
  truths:
    - "User can long-press home screen, add the new AddFlightWidget in small or medium size"
    - "Tapping the small widget opens Block-Time and pushes AddFlightView"
    - "Tapping medium widget left tile opens AddFlightView"
    - "Tapping medium widget right tile opens AddFlightView and auto-triggers the ACARS camera (only when fleet supports capture)"
    - "Right tile is hidden / not rendered when selectedFleetID is not in the supported set (B737, A330, B787, A320, A380)"
    - "No existing widget, button, or behaviour is removed"
  artifacts:
    - path: "BlockTimeWidget/AddFlightWidgetView.swift"
      provides: "AddFlightWidget definition + view (small + medium)"
      contains: "struct AddFlightWidget: Widget"
    - path: "BlockTimeWidget/BlockTimeWidgetBundle.swift"
      provides: "Bundle with both NextFlight and AddFlight widgets"
      contains: "AddFlightWidget()"
    - path: "Block-Time/Info.plist"
      provides: "blocktime URL scheme registration"
      contains: "CFBundleURLSchemes"
    - path: "Block-Time/Extensions/Notification+Names.swift"
      provides: "openAddFlight + openAddFlightCapture notification names"
  key_links:
    - from: "Widget Link(destination:)"
      to: "Block_TimeApp.handleIncomingURL"
      via: "blocktime://add-flight URL scheme"
      pattern: "blocktime://add-flight"
    - from: "Block_TimeApp.handleIncomingURL"
      to: "FlightsView.isAddingNewFlight"
      via: "NotificationCenter (.openAddFlight / .openAddFlightCapture)"
      pattern: "NotificationCenter.default.post"
    - from: "FlightsView capture path"
      to: "AddFlightView camera"
      via: "AppState.shared.triggerCamera flag → onAppear → viewModel.showCamera()"
      pattern: "AppState.shared.triggerCamera"
---

<objective>
Add a new `AddFlightWidget` to the BlockTimeWidget extension that lets pilots open Add Flight (and optionally jump straight into ACARS photo capture) directly from the home screen, in small and medium sizes.

Purpose: Reduce friction for the most common pilot workflow — logging a sector after landing — by removing the launch-app-then-navigate steps.
Output: New widget file, URL-scheme deep link plumbing, AppState camera trigger flag, and notification listeners in MainTabView / FlightsView / AddFlightView. No existing functionality removed.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@BlockTimeWidget/BlockTimeWidgetBundle.swift
@BlockTimeWidget/NextFlightWidgetView.swift
@Block-Time/Block_TimeApp.swift
@Block-Time/Info.plist
@Block-Time/Views/Screens/MainTabView.swift
@Block-Time/Views/Screens/FlightsView.swift
@Block-Time/Views/Screens/AddFlightView.swift

<interfaces>
<!-- These are the existing contracts the executor must wire into. -->

App Group identifier (already configured):
  "group.com.thezoolab.blocktime"

Shared UserDefaults key for fleet selection:
  "selectedFleetID"  (String) — fleet IDs that support ACARS capture: B737, A330, B787, A320, A380

URL scheme to register and handle:
  blocktime://add-flight
  blocktime://add-flight?capture=true

Notification names (NEW — to be added):
  Notification.Name.openAddFlight
  Notification.Name.openAddFlightCapture

AppState (existing @Observable singleton, AppState.shared):
  // ADD: var triggerCamera: Bool = false

FlightsView (existing):
  @State private var isAddingNewFlight: Bool
  .navigationDestination(isPresented: $isAddingNewFlight) { AddFlightView(...) }

AddFlightView (existing):
  viewModel.showCamera()  // method already exists for ACARS capture flow

Block_TimeApp (existing):
  func handleIncomingURL(_ url: URL)  // extend, do not replace
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add AddFlightWidget + bundle entry + URL scheme</name>
  <files>
    BlockTimeWidget/AddFlightWidgetView.swift,
    BlockTimeWidget/BlockTimeWidgetBundle.swift,
    Block-Time/Info.plist
  </files>
  <action>
    1. Create `BlockTimeWidget/AddFlightWidgetView.swift` with:
       - `struct AddFlightWidget: Widget` using `StaticConfiguration` (kind: "AddFlightWidget", display name "Add Flight", description "Quickly log a new sector").
       - `.supportedFamilies([.systemSmall, .systemMedium])`.
       - A `SimpleEntry: TimelineEntry` with just `date: Date` and a `Provider: TimelineProvider` returning a single static entry (no refresh logic needed).
       - `struct AddFlightWidgetEntryView: View` that branches on `widgetFamily`:
           * Small: a single `Link(destination: URL(string: "blocktime://add-flight")!)` containing centered `Image(systemName: "plus.circle.fill")` + `Text("Add Flight")` using the `WT` design tokens (orange accent, gradient/solid background, dark/light adaptive). Use `.containerBackground(...)` for iOS 17+ widgets.
           * Medium: read `selectedFleetID` from `UserDefaults(suiteName: "group.com.thezoolab.blocktime")?.string(forKey: "selectedFleetID")`. Define a const set `let captureSupportedFleets: Set<String> = ["B737", "A330", "B787", "A320", "A380"]`.
             - If `selectedFleetID` is in the set: HStack with two equal `Link`s — left "Add Flight" (`plus.circle.fill`, → `blocktime://add-flight`), right "Capture ACARS" (`camera.fill`, → `blocktime://add-flight?capture=true`).
             - Otherwise: a single full-width "Add Flight" link (centered).
       - Duplicate the `WT` design-token enum from `NextFlightWidgetView.swift` (DO NOT import — widget targets cannot import app target). Match orange accent, gradient/solid backgrounds, light/dark mode behaviour exactly.
       - Use `@Environment(\.widgetFamily) private var widgetFamily`.
    2. Edit `BlockTimeWidget/BlockTimeWidgetBundle.swift`: add `AddFlightWidget()` to the `body` alongside the existing `BlockTimeWidget()`. Do not remove or reorder existing entries.
    3. Edit `Block-Time/Info.plist`: under (or add) `CFBundleURLTypes` array, add a dict with:
       - `CFBundleURLName` = `com.thezoolab.blocktime`
       - `CFBundleURLSchemes` = `[blocktime]`
       If `CFBundleURLTypes` already exists, append (do not replace) — preserve any existing schemes.
  </action>
  <verify>
    <automated>MISSING — verify manually: project builds (`Build_1.18.1` scheme), widget gallery on iOS shows "Add Flight" widget, both small and medium previews render with WT styling.</automated>
  </verify>
  <done>
    `AddFlightWidgetView.swift` exists in BlockTimeWidget folder, bundle contains both widgets, Info.plist registers the `blocktime` scheme, project compiles.
  </done>
</task>

<task type="auto">
  <name>Task 2: Wire deep-link handling — AppState, notifications, App URL handler</name>
  <files>
    Block-Time/Extensions/Notification+Names.swift,
    Block-Time/Services/AppState.swift,
    Block-Time/Block_TimeApp.swift
  </files>
  <action>
    1. Create `Block-Time/Extensions/Notification+Names.swift` (or add to an existing Notification.Name extensions file if one already exists in `Extensions/` — check first):
       ```swift
       import Foundation
       extension Notification.Name {
           static let openAddFlight = Notification.Name("openAddFlight")
           static let openAddFlightCapture = Notification.Name("openAddFlightCapture")
       }
       ```
    2. Edit `Block-Time/Services/AppState.swift` (locate file — it's the `@Observable` singleton with `AppState.shared`). Add a new property:
       ```swift
       var triggerCamera: Bool = false
       ```
       Place near other transient UI flags. Do not remove or rename anything.
    3. Edit `Block-Time/Block_TimeApp.swift` `handleIncomingURL(_ url:)`:
       - Add a branch for `url.scheme == "blocktime"` and `url.host == "add-flight"`.
       - Parse `URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems` for `capture=true`.
       - If `capture=true`: `NotificationCenter.default.post(name: .openAddFlightCapture, object: nil)`.
       - Else: `NotificationCenter.default.post(name: .openAddFlight, object: nil)`.
       - Preserve all existing URL handling — add this as an additional branch, do not replace.
  </action>
  <verify>
    <automated>MISSING — verify manually: paste `xcrun simctl openurl booted "blocktime://add-flight"` into terminal with simulator running; app foregrounds and posts notification (next task wires the listener).</automated>
  </verify>
  <done>
    Notification names exist, `AppState.triggerCamera` exists, `handleIncomingURL` posts the correct notification for both URL variants, project compiles.
  </done>
</task>

<task type="auto">
  <name>Task 3: Listener wiring — MainTabView, FlightsView, AddFlightView camera trigger</name>
  <files>
    Block-Time/Views/Screens/MainTabView.swift,
    Block-Time/Views/Screens/FlightsView.swift,
    Block-Time/Views/Screens/AddFlightView.swift
  </files>
  <action>
    1. `MainTabView.swift`: add `.onReceive(NotificationCenter.default.publisher(for: .openAddFlight)) { _ in selectedTab = 0 }` and identical handler for `.openAddFlightCapture`. Both switch to tab 0 only — the actual sheet/navigation push happens in FlightsView. Do not remove existing onReceive handlers.
    2. `FlightsView.swift`: add two `.onReceive` modifiers on the root view (alongside any existing onReceive):
       - `.onReceive(NotificationCenter.default.publisher(for: .openAddFlight)) { _ in isAddingNewFlight = true }`
       - `.onReceive(NotificationCenter.default.publisher(for: .openAddFlightCapture)) { _ in AppState.shared.triggerCamera = true; isAddingNewFlight = true }`
       Order matters: set `triggerCamera` BEFORE `isAddingNewFlight` so AddFlightView's `.onAppear` reads the flag set to true.
    3. `AddFlightView.swift`: in the existing `.onAppear` (or add one if absent — but check first, do not duplicate):
       ```swift
       if AppState.shared.triggerCamera {
           AppState.shared.triggerCamera = false   // reset BEFORE invoking to avoid double-fire
           viewModel.showCamera()
       }
       ```
       Place this AFTER any existing onAppear logic — do not remove or reorder existing logic.
  </action>
  <verify>
    <automated>MISSING — verify end-to-end: install widget, tap small → opens AddFlightView. On supported fleet (e.g. B737), tap medium right tile → opens AddFlightView with camera sheet auto-presented. On unsupported fleet, medium shows only Add Flight (full width) — tap → opens AddFlightView (no camera).</automated>
  </verify>
  <done>
    Tapping the widget from home screen launches the app, switches to Flights tab, pushes AddFlightView, and (capture variant) auto-opens the ACARS camera. No existing onReceive / onAppear logic removed.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 4: Manual verification on device/simulator</name>
  <what-built>
    AddFlightWidget (small + medium), URL scheme deep link, AppState camera trigger, listener wiring across MainTabView / FlightsView / AddFlightView.
  </what-built>
  <how-to-verify>
    1. Build the app locally (Nelson will trigger build — do not auto-build).
    2. Install on simulator or device.
    3. Long-press home screen, search for "Add Flight" widget — confirm both small and medium previews render with WT orange styling.
    4. Add the small widget. Tap it → Block-Time opens, switches to Flights tab, pushes AddFlightView.
    5. Set fleet to B737 (or any of B737/A330/B787/A320/A380) in app settings, then add the medium widget. Confirm two tap targets appear (Add Flight | Capture ACARS).
       - Tap left → opens AddFlightView (no camera).
       - Tap right → opens AddFlightView and ACARS camera sheet auto-appears.
    6. Switch fleet to an unsupported one (e.g. C172 or whatever non-listed fleet exists). Re-add medium widget — confirm it shows only "Add Flight" full-width.
    7. Confirm existing NextFlightWidget still works and is unchanged.
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues found.</resume-signal>
</task>

</tasks>

<verification>
- Both widgets coexist in the bundle.
- `blocktime://add-flight` and `blocktime://add-flight?capture=true` URLs route correctly.
- Camera auto-trigger fires exactly once per capture deep link (no double-fire on subsequent appears).
- Medium widget conditionally renders capture tile based on `selectedFleetID` from App Group UserDefaults.
- No existing feature, button, or behaviour removed.
</verification>

<success_criteria>
- AddFlightWidget appears in widget gallery and is addable in small + medium sizes.
- Tapping any tap target opens Block-Time and lands on AddFlightView.
- Capture variant auto-presents the ACARS camera on supported fleets only.
- Project compiles cleanly under Swift 6 strict concurrency.
- Existing NextFlightWidget functionality untouched.
</success_criteria>

<output>
After completion, create `.planning/quick/260508-lvr-add-addflightwidget-to-the-blocktimewidg/260508-lvr-SUMMARY.md`
</output>
