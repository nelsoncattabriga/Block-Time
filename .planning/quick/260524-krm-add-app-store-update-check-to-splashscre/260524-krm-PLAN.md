---
phase: quick-260524-krm
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Services/AppUpdateService.swift
  - Block-Time/Views/Screens/SplashScreenView.swift
autonomous: true
requirements: [KRM-01, KRM-02]

must_haves:
  truths:
    - "On launch the app checks the iTunes Search API for a newer App Store version"
    - "If a newer version exists, the splash pauses and shows an alert with Update and Later buttons"
    - "Tapping Update opens the App Store page; tapping Later proceeds into the app"
    - "If up to date, offline, or the lookup returns no results, the app proceeds normally"
    - "The version check result is cached for 24h to avoid hitting the API on every launch"
  artifacts:
    - path: "Block-Time/Services/AppUpdateService.swift"
      provides: "Pure async update-check returning store version String? when newer"
      contains: "itunes.apple.com/lookup"
    - path: "Block-Time/Views/Screens/SplashScreenView.swift"
      provides: "Update alert + App Store deep link wired into existing .task animation"
      contains: "AppUpdateService"
  key_links:
    - from: "Block-Time/Views/Screens/SplashScreenView.swift"
      to: "AppUpdateService"
      via: "await call inside .task before setting isActive"
      pattern: "AppUpdateService"
    - from: "Block-Time/Views/Screens/SplashScreenView.swift"
      to: "App Store URL"
      via: "openURL on Update button"
      pattern: "id6758280518"
---

<objective>
Add an App Store update check to the launch splash screen. On launch the app asks the
iTunes Search API whether a newer version is published; if so it pauses the splash and
offers an Update / Later choice before entering the app.

Purpose: Prompt pilots to stay on the current build (accuracy/data-safety matters), without
adding a dependency or a singleton service.
Output: New `AppUpdateService.swift` (pure async check) + update alert wired into `SplashScreenView`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

@Block-Time/Views/Screens/SplashScreenView.swift

<facts>
<!-- Verified during planning — use directly, do not re-discover. -->
- Bundle ID: com.thezoolab.blocktime
- App Store trackId / app ID: 6758280518
- App Store URL: https://apps.apple.com/app/id6758280518
- iTunes lookup endpoint: https://itunes.apple.com/lookup?bundleId=com.thezoolab.blocktime
- IMPORTANT: the bundleId-only lookup (no country param) currently returns
  {"resultCount":0,"results":[]} because the app is region-listed. The service MUST treat
  an empty results array exactly like "up to date" (return nil, proceed to app). Do NOT
  hardcode a country param — empty/zero results and network errors must both fail safe.
- Xcode uses folder-based file inclusion: a new .swift file dropped under Block-Time/Services/
  is compiled automatically. Confirm Block-Time/Services/ exists; if not, create it.
- Existing SplashScreenView has: @State private var isActive, a .task {} that animates for
  ~1s then sets isActive = true, an appVersion computed property, and a TRIAL Capsule badge.
- Project rule: invoke the swiftui-pro skill (Skill tool) BEFORE writing or editing any Swift.
- Swift 6 strict concurrency: use async/await; mark UI-touching code @MainActor.
</facts>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Create AppUpdateService with cached iTunes lookup</name>
  <files>Block-Time/Services/AppUpdateService.swift</files>
  <behavior>
    - Returns nil when the device's CFBundleShortVersionString is >= the store version
    - Returns the store version String when the store version is strictly newer
    - Returns nil on network error, decode error, or empty results array (fail-safe)
    - Skips the network fetch entirely when a check ran within the last 24h, returning the
      cached "newer version" string (or nil) from that prior check
  </behavior>
  <action>
    Invoke the swiftui-pro skill first.

    Create `Block-Time/Services/AppUpdateService.swift`. Make it a non-singleton `struct`
    (or `enum` namespace) with a static `func checkForUpdate() async -> String?`. NOT a
    class, NOT @Observable, NOT a shared instance — per task constraints.

    Behaviour:
    1. Read current version from `Bundle.main.infoDictionary?["CFBundleShortVersionString"]`.
    2. 24h cache: store two UserDefaults keys —
       `"appUpdateLastCheckDate"` (Date) and `"appUpdateCachedStoreVersion"` (String, the
       newer version, or absent/empty when none). If `Date().timeIntervalSince(lastCheck) < 86_400`,
       skip the fetch and return the cached newer-version string (nil if none cached). Otherwise
       proceed to fetch and update both keys after a successful comparison.
    3. Fetch `https://itunes.apple.com/lookup?bundleId=com.thezoolab.blocktime` via
       `URLSession.shared.data(from:)`. Decode JSON. Expected shape:
       `{ "resultCount": Int, "results": [ { "version": String } ] }`.
       Use a small Decodable struct (LookupResponse / LookupResult) — do not pull in any
       dependency. Do NOT append a country parameter.
    4. If `results` is empty OR the request throws OR decode fails → return nil WITHOUT
       writing a misleading cache; you MAY still stamp `appUpdateLastCheckDate` so transient
       offline launches don't hammer the API, but clear/omit the cached store version so a
       later online launch re-checks. (Simplest correct approach: on error, return nil and
       do not update the cache at all.)
    5. Compare current vs store version with a numeric, component-wise comparison
       (`compare(_:options: .numeric)` on the version strings, or split on "." and compare
       Int components). Treat store-version-newer as the only case that returns non-nil.
    6. On a successful comparison, write `appUpdateLastCheckDate = Date()` and
       `appUpdateCachedStoreVersion` = the newer version string (or remove the key when up to date).

    Keep it small and pure: no UI imports beyond Foundation. Add doc comments explaining the
    region-locked empty-results fail-safe (see <facts>).
  </action>
  <verify>
    <automated>MISSING — no unit test target wired for this quick task; verify by build + manual launch. Project policy: Nelson builds locally.</automated>
  </verify>
  <done>
    AppUpdateService.swift exists under Block-Time/Services/, exposes a static
    `checkForUpdate() async -> String?`, hits the iTunes lookup with the correct bundleId,
    caches per 24h, and returns nil on empty results / errors. No singleton, no class.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Wire update check + alert into SplashScreenView</name>
  <files>Block-Time/Views/Screens/SplashScreenView.swift</files>
  <action>
    Invoke the swiftui-pro skill first.

    Edit `Block-Time/Views/Screens/SplashScreenView.swift`. Preserve ALL existing behaviour
    (animation, isActive transition, TRIAL badge, version display, and every .onAppear
    migration block — do not touch or remove any of them).

    1. Add `@Environment(\.openURL) private var openURL`.
    2. Add state:
       - `@State private var availableUpdateVersion: String? = nil`
       - `@State private var showUpdateAlert = false`
    3. In the existing `.task {}`: keep the animation. Run the update check CONCURRENTLY with
       the existing 1s sleep so it doesn't add latency. Pattern:
         - start the animation withAnimation as today
         - `async let update = AppUpdateService.checkForUpdate()`
         - `try? await Task.sleep(...)` for the existing initialDelay
         - `let newVersion = await update`
         - if `newVersion != nil`: set `availableUpdateVersion = newVersion` and
           `showUpdateAlert = true` (do NOT set isActive — the alert gates entry)
         - else: `withAnimation { isActive = true }` exactly as today
       Ensure UI mutations happen on the main actor (the .task body in a View runs on the
       MainActor already — keep it that way).
    4. Add `.alert(...)` to the ZStack:
       - title: "Update Available"
       - message: show the new version, e.g. "Version \(availableUpdateVersion ?? "") is
         available on the App Store."
       - Button "Update": call `openURL(URL(string: "https://apps.apple.com/app/id6758280518")!)`,
         then `withAnimation { isActive = true }` so the app proceeds after the App Store opens.
       - Button "Later" (role .cancel): `withAnimation { isActive = true }`.
       Bind to `isPresented: $showUpdateAlert`.
    5. Add a small "Update Available!" label below the existing `Text(appVersion)` shown only
       when `availableUpdateVersion != nil`. Use a semantic font (`.footnote` or `.caption` —
       respect the iPhone minimum-font rule, never smaller than .footnote on iPhone). Style it
       to read clearly on the gradient (e.g. `.fontWeight(.semibold)`, secondary/white-ish color
       consistent with the existing TRIAL badge treatment).

    Do not add a country parameter anywhere; do not introduce a singleton.
  </action>
  <verify>
    <automated>MISSING — verify via local build (Nelson builds locally) and manual launch with a forced lower CFBundleShortVersionString to confirm the alert appears, Update opens the App Store, Later proceeds.</automated>
  </verify>
  <done>
    SplashScreenView calls AppUpdateService concurrently during the splash; when a newer
    version exists it pauses, shows the "Update Available" alert (Update opens
    apps.apple.com/app/id6758280518, Later proceeds) and renders the "Update Available!" label
    below the version. When no update / offline, the splash transitions exactly as before. All
    existing migrations and UI preserved.
  </done>
</task>

</tasks>

<verification>
- AppUpdateService.swift compiles, is a struct/enum (no singleton), uses Foundation only.
- iTunes lookup uses bundleId com.thezoolab.blocktime with no country param.
- Empty results and network errors both return nil (verified by reading the code path).
- SplashScreenView still performs every existing onAppear migration unchanged.
- Update button targets https://apps.apple.com/app/id6758280518.
- 24h cache keys present: appUpdateLastCheckDate, appUpdateCachedStoreVersion.
</verification>

<success_criteria>
- Newer store version → splash pauses, alert shows, Update opens App Store, Later enters app.
- Up to date / offline / region-empty results → splash transitions to app with no alert.
- Update check runs concurrently with the 1s animation (no added launch latency).
- No existing feature, migration, badge, or version display removed or altered.
</success_criteria>

<output>
After completion, create `.planning/quick/260524-krm-add-app-store-update-check-to-splashscre/260524-krm-SUMMARY.md`
</output>
