# Swift 6 & Modern API Verification Checklist

**Purpose:** Ensure all planning phases produce Swift 6-compliant, modern Swift code before implementation begins.

## Swift 6 Strict Concurrency Requirements

### Sendable Conformance
- [ ] All public types crossing module boundaries conform to `Sendable`
- [ ] No non-Sendable stored properties in `Sendable` types (closures, classes, actors)
- [ ] No `@MainActor` annotations on pure calculation functions
- [ ] No shared mutable state without actor protection

### Force Unwrap Elimination
- [ ] NO force unwraps (`!`) in production code
- [ ] NO implicitly unwrapped optionals (`T!`)
- [ ] All `TimeZone` creation uses `guard let` or safe defaults
- [ ] All `Calendar.date(from:)` calls use `guard let` or `XCTUnwrap` in tests
- [ ] All `Bundle` or file access uses safe optional handling

### Safe Optional Handling
- [ ] Use `guard let` for early exits with clear error handling
- [ ] Use `if let` for conditional branching
- [ ] Use nil-coalescing (`??`) for defaults
- [ ] Test code uses `XCTUnwrap` for better failure messages

### Concurrency Patterns
- [ ] NO `DispatchQueue` usage - use `async/await` instead
- [ ] NO `Task.sleep(nanoseconds:)` - use `Task.sleep(for:)` instead  
- [ ] NO `@MainActor.run()` unless project defaults require it
- [ ] NO `Task.detached()` without careful review

## Modern Swift API Requirements

### String Formatting
- [ ] NO `String(format:)` usage
- [ ] Use `.formatted(.number.precision(.fractionLength(N)))` for numbers
- [ ] Use `.formatted()` for dates/times with `FormatStyle` APIs
- [ ] Use Text formatting APIs in SwiftUI: `Text(value, format: .number.precision(.fractionLength(2)))`

### String Methods
- [ ] NO `replacingOccurrences(of:with:)` usage
- [ ] Use `.replacing(_:with:)` instead
- [ ] Use `.localizedStandardContains()` for user-input filtering
- [ ] Prefer native Swift string methods over Foundation equivalents

### Date/Time Handling
- [ ] NO `Calendar.current` usage
- [ ] NO `TimeZone.current` usage  
- [ ] Use `Calendar(identifier: .gregorian)` with explicit `TimeZone`
- [ ] Use `Date.now` instead of `Date()` for current time
- [ ] Use modern `Date` initializers: `Date(myString, strategy: .iso8601)`

### Type Safety
- [ ] Prefer `Double` over `CGFloat` except when required
- [ ] Use `count(where:)` instead of `filter().count`
- [ ] Prefer static member lookup: `.circle` instead of `Circle()`
- [ ] Use modern `if let value {` shorthand syntax

### Foundation APIs
- [ ] Use `URL.documentsDirectory` instead of `FileManager` lookups
- [ ] Use `.appending(path:)` instead of path string manipulation
- [ ] No manual date formatting strings with "yyyy" - use "y" for localization

## Testing Requirements

### Test Safety
- [ ] NO force unwraps in test code
- [ ] Use `XCTUnwrap` for optional unwrapping in tests
- [ ] Use `try XCTUnwrap` for throwing optional unwrapping
- [ ] Clear test failure messages with descriptive assertions

### Test Structure  
- [ ] One test method per behavior/edge case
- [ ] Test helpers use safe optional handling
- [ ] No shared mutable state between tests
- [ ] Tests are deterministic (no `Calendar.current`, no `Date()`)

## Project-Specific Requirements

### Block-Time Project
- [ ] NO `LogManager` references in extracted pure functions
- [ ] NO `AirportService` references in pure calculator functions
- [ ] NO UIKit/AppKit imports in BlockTimeKit modules
- [ ] All `FRMS` types moved to BlockTimeDomain are `Sendable`
- [ ] Test targets use XCTest pattern (not Swift Testing) to match existing code

## Verification Commands

### Swift 6 Concurrency Checks
```bash
# Check for force unwraps in new code
grep -r "!" BlockTimeKit/Sources/BlockTimeCalculators/ | grep -v "// " | grep -v "!="

# Check for Sendable conformance
swift package dump-package | grep -A 10 "BlockTimeDomain"

# Build with strict concurrency
swift build -Xswiftc -warn-concurrency
```

### Modern API Checks
```bash
# Check for String(format:) usage
grep -r "String(format:" BlockTimeKit/Sources/

# Check for replacingOccurrences usage
grep -r "replacingOccurrences" BlockTimeKit/Sources/

# Check for Calendar.current usage
grep -r "Calendar.current" BlockTimeKit/Sources/

# Check for TimeZone.current usage  
grep -r "TimeZone.current" BlockTimeKit/Sources/
```

### Test Safety Checks
```bash
# Check for force unwraps in tests
grep -r "!" BlockTimeKit/Tests/ | grep -v "// " | grep -v "!="

# Verify XCTUnwrap usage
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

## During Implementation Review

When reviewing pull requests or implementation:

- [ ] All force unwraps eliminated
- [ ] All modern APIs used correctly
- [ ] Sendable conformance verified
- [ ] Tests use safe unwrapping
- [ ] No concurrency violations
- [ ] All verification commands pass

## Post-Implementation Verification

Before marking phase complete:

- [ ] `swift build` succeeds with strict concurrency warnings
- [ ] `swift test` passes all tests
- [ ] All grep checks for banned patterns return no results
- [ ] Code review confirms Swift 6 compliance
- [ ] Performance tests show no regressions
- [ ] Documentation updated with Swift 6 patterns

---

**Usage:** Include this checklist in all planning phases. Update phase-specific requirements in CONTEXT.md files. Ensure all plans reference these requirements before implementation begins.