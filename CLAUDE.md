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

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Block-Time v2.0**

Block-Time is an iOS (and Mac) pilot logbook app for professional airline pilots. It records flight sectors, calculates FRMS fatigue limits, tracks time totals, and exports logbook PDFs. v2.0 is a full architectural rewrite of the existing app, replacing Core Data with SwiftData, moving to a clean domain model, and making FRMS and time calculations fully unit-testable — while preserving every feature the current app has and migrating existing user data.

**Core Value:** A pilot's logbook must be accurate and never lose data — every architectural decision serves that constraint first.

### Constraints

- **Tech stack:** SwiftData (not Core Data), Swift 6 strict concurrency, `@Observable`, iOS 18.6+, macOS 15+
- **Data safety:** Migration from v1 Core Data store is mandatory — no data loss acceptable
- **Feature parity:** Every feature in v1 must exist in v2.0 before shipping
- **App Store continuity:** v2.0 ships as an update to the existing app, not a new listing
- **No UI regressions:** Existing users must not notice a visual difference
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## SwiftData + CloudKit Setup
### Version Requirements
### ModelContainer Configuration
### Required Xcode Capabilities
- **iCloud** capability with CloudKit checked and your container registered.
- **Background Modes** capability with **Remote notifications** checked (so the app wakes on CloudKit push and syncs).
- These are identical to what v1 already has — no new entitlements needed.
### App entry point
### CloudKit Data Model Constraints (NON-NEGOTIABLE)
### CloudKit Schema Initialisation
## Swift Package for Shared Business Logic
### Recommended Structure
### Package.swift minimum
### What Goes in the Package vs the App Target
| BlockTimeCore (package) | App Target |
|-------------------------|-----------|
| Domain structs (`Flight`, `Aircraft`) | `@Model` classes (SwiftData) |
| `FlightRepository` protocol | `SwiftDataFlightRepository` implementation |
| FRMS calculator (pure functions) | SwiftUI views |
| Parsers (CSV, ACARS, roster) | `@Environment` wiring |
| Time/night/UTC calculations | Widget extension |
| In-memory repository (for tests) | App Intents |
### Gotcha: @Model cannot live in a Swift Package
## SwiftData Testing (In-Memory)
### Pattern
### Testing the Repository Protocol
### Migration Testing
## @Observable + @Model Constraints
### What @Model Gives You
### Sendability Rules (Swift 6 Strict Concurrency)
| Type | Sendable | Crosses actor boundary? |
|------|----------|------------------------|
| `ModelContainer` | YES | Can be passed freely |
| `PersistentIdentifier` | YES | Can be passed freely |
| `ModelContext` | NO | Create one per actor |
| `@Model` instances | NO | Pass `PersistentIdentifier`, refetch on other actor |
### ModelActor for Background Work
### Relationship Gotcha
### @Query in Views
### No Predicate on Optional Relationships (CloudKit-forced optionals)
## Core Data → SwiftData Migration
### The Options
#### Option A: Native Coexistence (Core Data + SwiftData same store) — NOT RECOMMENDED
- Identical entity names between Core Data and SwiftData classes (or careful namespacing).
- Persistent history tracking enabled on the Core Data stack.
- Schema must stay perfectly synchronised between both stacks.
- No CloudKit schema divergence.
#### Option B: One-Time Migration at First Launch — RECOMMENDED
#### Option C: SwiftData VersionedSchema / SchemaMigrationPlan — NOT APPLICABLE
### Data Risk Assessment
| Risk | Mitigation |
|------|-----------|
| Migration runs twice | `UserDefaults` boolean flag, set only after verified row count |
| App killed mid-migration | Migration is idempotent if SwiftData store is cleared on restart; or use a transaction per batch |
| CloudKit sync during migration | Disable CloudKit during migration (`cloudKitDatabase: .none` temporarily), re-enable after |
| Data loss on old device running v1 | Migration is one-way; v2.0 ships as a hard cutover, not a dual-support release |
## Confidence Levels
| Area | Confidence | Rationale |
|------|-----------|-----------|
| SwiftData + CloudKit setup | HIGH | Apple documentation + multiple verified sources confirm ModelConfiguration API and CloudKit constraints |
| ModelConfiguration `.none` for in-memory | HIGH | Directly documented in Apple Developer Docs for the initialiser |
| All-optional CloudKit requirement | HIGH | Consistent across Apple docs, WWDC sessions, and community sources |
| `@Attribute(.unique)` CloudKit incompatibility | HIGH | Multiple sources; Apple docs confirm |
| `@Model` in Swift Package fails | MEDIUM | Consistent forum reports; verify with a spike at project start |
| ModelActor background execution behaviour | MEDIUM | Documented but has known quirk re: initialisation thread; test early |
| One-time Core Data→SwiftData migration approach | MEDIUM | Pattern is widely used; the CloudKit re-sync behaviour after migration is less documented and needs a real device test |
| `#Predicate` on optional relationships | MEDIUM | Known limitation as of iOS 18; may be fixed in later releases |
| SwiftData VersionedSchema for future changes | HIGH | WWDC23 + WWDC24 sessions and Hacking with Swift documentation |
## Sources
- [Apple: Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Apple: ModelConfiguration init (including cloudKitDatabase parameter)](https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(_:schema:isstoredinmemoryonly:allowssave:groupcontainer:cloudkitdatabase:))
- [Apple: ModelConfiguration.CloudKitDatabase](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct)
- [Apple: Organizing your code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
- [Hacking with Swift: Syncing SwiftData with CloudKit](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit)
- [Hacking with Swift: How to write unit tests for SwiftData](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code)
- [Hacking with Swift: How SwiftData works with Swift concurrency](https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency)
- [Hacking with Swift: Migrating from Core Data to SwiftData](https://www.hackingwithswift.com/quick-start/swiftdata/migrating-from-core-data-to-swiftdata)
- [Hacking with Swift: Core Data and SwiftData coexistence](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-make-core-data-and-swiftdata-coexist-in-the-same-app)
- [Hacking with Swift: VersionedSchema complex migration](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema)
- [fatbobman: Rules for adapting data models to CloudKit](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
- [fatbobman: initializeCloudKitSchema fix](https://fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-in-ios-development-using-initializecloudkitschema/)
- [fatbobman: Concurrent programming in SwiftData](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/)
- [fatbobman: Relationships in SwiftData](https://fatbobman.com/en/posts/relationships-in-swiftdata-changes-and-considerations/)
- [BrightDigit: Using ModelActor in SwiftData](https://brightdigit.com/tutorials/swiftdata-modelactor/)
- [Use Your Loaf: SwiftData background tasks](https://useyourloaf.com/blog/swiftdata-background-tasks/)
- [pol piella: Core Data and SwiftData side by side](https://www.polpiella.dev/core-data-and-swift-data/)
- [WWDC23: Migrate to SwiftData](https://developer.apple.com/videos/play/wwdc2023/10189/)
- [Apple Developer Forums: Migrate Core Data to SwiftData](https://developer.apple.com/forums/thread/756615)
- [Apple Developer Forums: SwiftData and CloudKit](https://developer.apple.com/forums/thread/761434)
- [Donny Wals: Deep dive into SwiftData migrations](https://www.donnywals.com/a-deep-dive-into-swiftdata-migrations/)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

For simple, single-file changes make edits inline directly. Reserve GSD commands for complex or multi-file tasks — ask for approval before using GSD.

Use these entry points when GSD is appropriate:
- `/gsd:quick` for multi-step fixes and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
