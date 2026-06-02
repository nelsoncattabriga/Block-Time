## Main Rules
Do not make any changes until you have 95% confidence in what you need to build. Ask me follow-up questions until you reach that confidence.
I will build locally - don't build unless i ask you to.
Be concise, be direct, don't waffle your answers and never use flowery language.
Never remove any existing feature, button, logic, or behaviour without explicit approval — this includes during refactors, compiler fixes, or cleanups.

## Applied Learning
When something fails repeatedly, when Nelson has to re-explain, add a one-line bullet here. Keep each bullet under 15 words. No explanations. Only add things that will save time in future sessions.
- Replace any `NavigationView` encountered with `NavigationStack` and update toolbar placements to `.topBar*`.
- Previews using `ThemeService` child views must inject `.environment(ThemeService.shared)` or crash with SIGTRAP.
- For simple single-file changes, edit inline. Use GSD for complex/multi-file tasks — ask first.

## Coding Standards

### Swift Style
- Use Swift 6 strict concurrency
- Prefer `@Observable` over `ObservableObject`
- Use `async/await` for all async operations
- Follow Apple's Swift API Design Guidelines
- Use `guard` for early exits
- Prefer value types (structs) over reference types (classes)

### SwiftUI Patterns
- Extract views when they exceed 500 lines
- Use `@State` for local view state only
- Use `@Environment` for dependency injection
- Prefer `NavigationStack` over deprecated `NavigationView`
- Use `@Bindable` for bindings to @Observable objects

### Navigation Pattern
```swift
// Use NavigationStack with type-safe routing
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

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

For simple, single-file changes make edits inline directly. Reserve GSD commands for complex or multi-file tasks — ask for approval before using GSD.

Use these entry points when GSD is appropriate:
- `/gsd:quick` for multi-step fixes and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work
<!-- GSD:workflow-end -->
