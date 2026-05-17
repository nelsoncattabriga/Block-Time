# Swift Development Skills for Block-Time Project

**Purpose:** Ensure all Swift development follows modern Swift 6, SwiftUI, and project-specific conventions.

## Swift 6 Strict Concurrency (NON-NEGOTIABLE)

### Sendable Conformance
- ALL public types crossing module boundaries MUST conform to `Sendable`
- NO non-Sendable stored properties in `Sendable` types (closures, classes, actors)
- NO `@MainActor` annotations on pure calculation functions
- NO shared mutable state without actor protection

### Force Unwrap Elimination
- NO force unwraps (`!`) in production code
- NO implicitly unwrapped optionals (`T!`)
- ALL `TimeZone` creation MUST use `guard let` or safe defaults
- ALL `Calendar.date(from:)` calls MUST use `guard let` or `XCTUnwrap` in tests
- ALL `Bundle` or file access MUST use safe optional handling

### Safe Optional Handling
- Use `guard let` for early exits with clear error handling
- Use `if let` for conditional branching
- Use nil-coalescing (`??`) for defaults
- Test code MUST use `XCTUnwrap` for better failure messages

### Concurrency Patterns
- NO `DispatchQueue` usage - use `async/await` instead
- NO `Task.sleep(nanoseconds:)` - use `Task.sleep(for:)` instead  
- NO `@MainActor.run()` unless project defaults require it
- NO `Task.detached()` without careful review

## Modern Swift API Requirements (NON-NEGOTIABLE)

### String Formatting
- NO `String(format:)` usage
- Use `.formatted(.number.precision(.fractionLength(N)))` for numbers
- Use `.formatted()` for dates/times with `FormatStyle` APIs
- Use Text formatting APIs in SwiftUI: `Text(value, format: .number.precision(.fractionLength(2)))`

### String Methods
- NO `replacingOccurrences(of:with:)` usage
- Use `.replacing(_:with:)` instead
- Use `.localizedStandardContains()` for user-input filtering
- Prefer native Swift string methods over Foundation equivalents

### Date/Time Handling
- NO `Calendar.current` usage
- NO `TimeZone.current` usage  
- Use `Calendar(identifier: .gregorian)` with explicit `TimeZone`
- Use `Date.now` instead of `Date()` for current time
- Use modern `Date` initializers: `Date(myString, strategy: .iso8601)`

### Type Safety
- Prefer `Double` over `CGFloat` except when required
- Use `count(where:)` instead of `filter().count`
- Prefer static member lookup: `.circle` instead of `Circle()`
- Use modern `if let value {` shorthand syntax

### Foundation APIs
- Use `URL.documentsDirectory` instead of `FileManager` lookups
- Use `.appending(path:)` instead of path string manipulation
- No manual date formatting strings with "yyyy" - use "y" for localization

## SwiftUI Patterns

### View Architecture
- Extract views when they exceed 500 lines
- Use `@State` for local view state only
- Use `@Environment` for dependency injection
- Prefer `NavigationStack` over deprecated `NavigationView`
- Use `@Bindable` for bindings to @Observable objects

### Data Flow
- Prefer `@Observable` over `ObservableObject`
- Use `async/await` for all async operations
- Follow Apple's Swift API Design Guidelines
- Use `guard` for early exits
- Prefer value types (structs) over reference types (classes)

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

## Block-Time Project Specific Requirements

### Module Structure
- NO `LogManager` references in extracted pure functions
- NO `AirportService` references in pure calculator functions
- NO UIKit/AppKit imports in BlockTimeKit modules
- All `FRMS` types moved to BlockTimeDomain MUST be `Sendable`
- Test targets MUST use XCTest pattern (not Swift Testing) to match existing code

### Testing Requirements
- NO force unwraps in test code
- Use `XCTUnwrap` for optional unwrapping in tests
- Use `try XCTUnwrap` for throwing optional unwrapping
- Clear test failure messages with descriptive assertions
- One test method per behavior/edge case
- No shared mutable state between tests
- Tests MUST be deterministic (no `Calendar.current`, no `Date()`)

### @AppStorage Safety
- NEVER store display names or labels as `@AppStorage` selection keys
- ALWAYS store stable IDs (enum raw values, fixed string constants) only
- When reading a stored selection, ALWAYS validate it against the current valid set
- Enum raw values stored in `@AppStorage` MUST have `?? .default` fallback at every read site

### Build and Verification
```bash
# Swift 6 Concurrency Checks
grep -r "!" BlockTimeKit/Sources/ | grep -v "// " | grep -v "!="
swift build -Xswiftc -warn-concurrency

# Modern API Checks  
grep -r "String(format:" BlockTimeKit/Sources/
grep -r "replacingOccurrences" BlockTimeKit/Sources/
grep -r "Calendar.current" BlockTimeKit/Sources/
grep -r "TimeZone.current" BlockTimeKit/Sources/

# Test Safety Checks
grep -r "!" BlockTimeKit/Tests/ | grep -v "// " | grep -v "!="
grep -c "XCTUnwrap" BlockTimeKit/Tests/BlockTimeCalculatorsTests/
```

## Pre-Implementation Checklist

Before any implementation phase begins:

- [ ] Plan includes Swift 6 requirements in `must_haves` section
- [ ] Plan includes modern API requirements in acceptance criteria  
- [ ] Plan specifies safe optional handling patterns
- [ ] Test patterns specify `XCTUnwrap` usage
- [ ] Verification commands included in automated checks
- [ ] Sendable conformance verification steps documented

## During Development Review

When reviewing code:

- [ ] All force unwraps eliminated
- [ ] All modern APIs used correctly
- [ ] Sendable conformance verified
- [ ] Tests use safe unwrapping
- [ ] No concurrency violations
- [ ] All verification commands pass

## Skill Integration

This project integrates with the following skills:

1. **swiftui-pro** - SwiftUI and modern Swift code review
   - Automatically invoked before Swift/SwiftUI changes
   - Checks deprecated APIs, performance, accessibility
   - Ensures modern SwiftUI patterns

2. **swift-concurrency-pro** - Swift concurrency best practices
   - Use for complex concurrency scenarios
   - Actor isolation, data race prevention
   - Task and async/await patterns

3. **swiftdata-pro** - SwiftData specific guidance
   - Model configuration, CloudKit sync
   - Query optimization, relationship handling

---

**Usage:** This file is automatically included in all planning phases via the GSD workflow. Agents must reference these requirements before planning or implementing any Swift code.