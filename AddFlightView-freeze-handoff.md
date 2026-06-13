# Block-Time — AddFlightView Freeze: Handoff Brief

## Symptom

- One user (iPhone 16 Pro, iOS 26.5) reports the app **freezing** when entering a flight **manually**.
- **No freeze** when data is entered via **ACARS capture**.

## Crash report analysis (9 files)

- **5× `.ips` (bug_type 309):** all `0x8BADF00D` watchdog hangs — main thread pinned in SwiftUI’s layout engine for 10s+, then killed by FRONTBOARD. Not logic crashes.
  - Stacks: `LazyLayout.sizeThatFits` recursion, `StackLayout.explicitAlignment` recursion, `DisplayList.transform` / `_ShapeStyle_InterpolatorGroup.rewriteInterpolation`.
  - Latest (12 Jun, v1.27) is the smoking gun: hang kicked off by `_keyboardAboutToShow` → `UISheetPresentationController` relayout → `_UIHostingView.layoutSubviews`. i.e. **keyboard animating up inside the sheet forces a full SwiftUI layout pass that never finishes in time.**
- **1× CPU resource report (bug_type 202):** 90s CPU over 156s (58% sustained). Heaviest stack = run-loop `UpdateCycle → SwiftUI → QuartzCore` layout cycle spinning continuously. Confirms a layout/recompute feedback loop, not a one-off slow frame.
- **3× JetsamEvent:** device-wide memory pressure (Oura / WebKit are the heavy procs; dozens of daemons reaped as `long-idle-exit`/`highwater`). **Block-Time is NOT killed in any of them.** Unrelated — ignore for this issue.

Why ACARS is fine: it writes all fields once, programmatically, with no keyboard and no per-keystroke recompute, so it never enters the loop.

## Root cause (structural amplifiers in AddFlightView.swift)

The expensive recompute lives in the child cards / view model, but the top-level structure turns a normal keystroke into a full-tree relayout storm. In priority order:

1. **`GeometryReader` wrapping the entire `ScrollView` — primary suspect.**
   `GeometryReader` is greedy and re-proposes its child’s size whenever available space changes — i.e. every frame of the keyboard animation. It’s only used to read `geometry.size.width` to pick wide-vs-compact layout, a decision already available from `horizontalSizeClass` in the environment. Matches the `DisplayList.transform` / interpolation churn during keyboard show.
1. **`LazyVStack` for ~4 fixed cards (in `CompactLayoutView`).**
   The `LazyVStack` does incremental measurement passes (the `LazyLayout.sizeThatFits` recursion in the crash stacks) that are pointless for a known-small set of cards, and it re-measures under the GeometryReader’s changing proposal.
1. **One big `@Published` view model (`FlightTimeExtractorViewModel`) bound directly to the text fields — NEEDS CONFIRMATION.**
   The VM is shared by every card. If `STD/STA/OUT/IN` `TextField`s bind directly to its `@Published` properties, every keystroke republishes the whole VM → invalidates every card → full re-layout. Combined with #1 and #2, that’s the spin.

## What to confirm in the full codebase

In `ModernManualEntryDataCard` and `FlightTimeExtractorViewModel`:

- **Time-field bindings:** are they `TextField(..., text: $viewModel.std)` directly to `@Published`?
- **BLOCK/NIGHT recompute:** find the `onChange`/`didSet`/Combine pipeline that recalculates them. NIGHT especially — if it runs a sunrise/sunset-along-great-circle calc on each keystroke, it’s the heavy item sitting inside the layout-invalidation path.
- **Any card `body` reading a computed property that does real work** — re-evaluated on every invalidation.

## Fix plan (try in this order)

1. **Drop the outer `GeometryReader`.** Drive the wide/compact decision from `horizontalSizeClass` (already in the environment); if a width threshold is truly needed, isolate it so it doesn’t re-propose the whole content during keyboard animation. *Low risk.*
1. **`LazyVStack` → `VStack`** in `CompactLayoutView` (only ~4 children). *Low risk.*
1. **Decouple the time fields from the shared `@Published` VM.** Give each time field local `@State` and commit to the VM on `.onSubmit`/focus-loss, or use a debounced binding. Move BLOCK/NIGHT recompute off the per-keystroke path (debounce or commit-time), and gate it so it only runs when OUT/IN/route are all valid *and* changed. *Structural fix.*

Steps 1–2 are low-risk and may resolve it alone; step 3 is the durable fix.

## Verify the fix

- Reproduce on an iPhone 16 Pro (or sheet + keyboard on any device): open Add Flight manually, tap STD/OUT, type — should not hang.
- Instruments: SwiftUI template — watch for repeated layout passes / long `body` evaluations during keyboard show. Confirm CPU no longer spins at ~58% while typing.