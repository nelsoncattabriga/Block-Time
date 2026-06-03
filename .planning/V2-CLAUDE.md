# CLAUDE.md — Block Time V2.0

## Main Rules
Do not make any changes until you have 95% confidence in what you need to build. Ask me follow-up questions until you reach that confidence.
I will build locally - don't build unless i ask you to.
Be concise, be direct, don't waffle your answers and never use flowery language.
Never remove any existing feature, button, logic, or behaviour without explicit approval — this includes during refactors, compiler fixes, or cleanups.

## V1 Reference
V1 project: `/Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time`
V2 plan: `/Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/.planning/V2-PLAN.md`

Read V1 source files freely when rebuilding a feature — they are the authoritative reference for existing behaviour.

## Applied Learning
- For simple single-file changes, edit inline. Use GSD for complex/multi-file tasks — ask first.
- Always invoke `swiftui-pro` skill before writing or editing any Swift or SwiftUI code.
- Replace any `NavigationView` with `NavigationStack` and update toolbar placements to `.topBar*`.
- Previews using environment objects must inject them or crash with SIGTRAP.
- Before removing any symbol, grep the full codebase for all usages first.
- Use `cd` + relative paths with `sed`; never use a `$BASE` variable (doesn't expand in single-quoted sed args).

## Swift Development
Always invoke the `swiftui-pro` skill (via Skill tool) before writing or editing any Swift or SwiftUI code.

## Coding Standards

### Swift Style
- Use Swift 6 strict concurrency throughout — no exceptions
- `@Observable` only — no `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`
- `async/await` and `TaskGroup` for all async operations
- Follow Apple's Swift API Design Guidelines
- Use `guard` for early exits
- Prefer value types (structs) over reference types (classes)
- No singletons — inject dependencies via `@Environment`

### SwiftUI Patterns
- Extract views when they exceed 500 lines
- `@State` for local view state only
- `@Environment` for dependency injection (ModelContext, services)
- `@Bindable` for bindings to `@Observable` objects
- `NavigationStack` only — never `NavigationView`
- Use `private func computation() -> T` instead of chained closures in `@ViewBuilder` to avoid type-check timeouts

### Navigation Pattern
```swift
enum Route: Hashable {
    case detail(Item)
    case settings
}

NavigationStack(path: $router.path) {
    ContentView()
        .navigationDestination(for: Route.self) { route in
            // Handle routing
        }
}
```

### Data Layer
- SwiftData with `@Model` — no `.xcdatamodeld` file
- Time stored as `Int` (minutes) — never `String` or `Double`
- `ModelContext` injected via `@Environment` — never a singleton
- iCloud Drive JSON for sync — not CloudKit directly

### Font Sizes
- Never smaller than `.footnote` on iPhone
- `.caption` and `.caption2` are iPad only
- Always use semantic font sizes — never `Font.system(size:)`

### Text Overflow
- For text that may wrap at large dynamic type: `.lineLimit(1).minimumScaleFactor(0.7)` on the container (not individual Text views)
- Never truncate or restructure layout to fix overflow

## UI Conventions

### Badges and Tags
- Use `RoundedRectangle(cornerRadius: 5)` for legend pills and badge-style labels
- Never `Capsule()` unless explicitly requested
- Default padding: `.padding(.horizontal, 8).padding(.vertical, 4)`

### Loading States
- Full-sheet dimmed overlay with material-backed ProgressView
- Never replace a toolbar button with a spinner
```swift
ZStack {
    ScrollView { ... }
    if isLoading {
        Color.black.opacity(0.35).ignoresSafeArea()
        ProgressView("Working…")
            .progressViewStyle(.circular)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
.allowsHitTesting(!isLoading)
```

### No Emoji
Never use emoji anywhere — UI text, banners, alerts, log output. Plain words and SF Symbols only.

## Mac Target
Always use native macOS controls (AppKit / NSViewRepresentable) over custom SwiftUI equivalents.
Reach for NSComboBox, NSDatePicker (stepperField style), etc. rather than building custom SwiftUI components.

## Git
- No `Co-Authored-By:` line in commit messages
- Never commit to the BlockTimeWebsite repo — Nelson does this manually

## GSD Workflow
For simple, single-file changes make edits inline directly. Reserve GSD commands for complex or multi-file tasks — ask for approval before using GSD.

Use these entry points when GSD is appropriate:
- `/gsd:quick` for multi-step fixes and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work
