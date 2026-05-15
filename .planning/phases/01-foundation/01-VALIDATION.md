---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-15
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | Xcode test scheme (no external config) |
| **Quick run command** | `xcodebuild test -scheme BlockTimeKit -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -scheme "Block-Time" -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~30s (package tests, macOS), ~90s (full suite, simulator) |

Package tests (`BlockTimeDomain`, `BlockTimeData`) run on macOS without a simulator — fast feedback loop.
Migration service tests require a simulator (they instantiate `ModelContainer`).

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme BlockTimeKit -destination 'platform=macOS'`
- **After every plan wave:** Run full suite on simulator
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30s (package tests)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 1-01-01 | 01 | 1 | FOUND-03 | Build | `swift build --package-path BlockTimeKit` | ⬜ pending |
| 1-01-02 | 01 | 1 | FOUND-04 | Unit | `xcodebuild test -scheme BlockTimeKit` (Sendable/Hashable check) | ⬜ pending |
| 1-01-03 | 01 | 1 | FOUND-05 | Unit | `xcodebuild test -scheme BlockTimeKit -only-testing:BlockTimeDataTests` | ⬜ pending |
| 1-02-01 | 02 | 1 | FOUND-10 | Unit | `xcodebuild test -scheme BlockTimeKit -only-testing:BlockTimeDataTests/TimeStringConverterTests` | ⬜ pending |
| 1-03-01 | 03 | 2 | FOUND-01 | Integration | `xcodebuild test -scheme Block-Time -only-testing:Block-TimeTests/SchemaVersionTests` | ⬜ pending |
| 1-03-02 | 03 | 2 | FOUND-02 | Integration | `xcodebuild test -scheme Block-Time -only-testing:Block-TimeTests/ModelContainerFactoryTests` | ⬜ pending |
| 1-03-03 | 03 | 2 | FOUND-06 | Integration | TimeInterval round-trip test | ⬜ pending |
| 1-03-04 | 03 | 2 | FOUND-07 | Integration | UTC Date round-trip test | ⬜ pending |
| 1-03-05 | 03 | 2 | FOUND-08 | Integration | CloudKit container init test | ⬜ pending |
| 1-04-01 | 04 | 2 | FOUND-09 | Integration | `xcodebuild test -scheme Block-Time -only-testing:Block-TimeTests/MigrationServiceTests` | ⬜ pending |
| 1-04-02 | 04 | 2 | FOUND-09 | Integration | Crash recovery test | ⬜ pending |
| 1-04-03 | 04 | 2 | FOUND-10 | Integration | Real .sqlite fixture migration test | ⬜ pending |
| 1-04-04 | 04 | 2 | FOUND-11 | Integration | Background thread assertion | ⬜ pending |
| 1-05-01 | 05 | 3 | FOUND-12 | Manual | Xcode preview renders with InMemoryFlightRepository | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All test stubs must be created before implementation begins:

- [ ] `BlockTimeKit/Tests/BlockTimeDataTests/FlightRepositoryTests.swift` — InMemoryFlightRepository protocol conformance (FOUND-05)
- [ ] `BlockTimeKit/Tests/BlockTimeDataTests/TimeStringConverterTests.swift` — all 13 format variants (FOUND-10)
- [ ] `Block-Time/Block-TimeTests/MigrationServiceTests.swift` — row-count, crash recovery, field mapping (FOUND-09/10/11)
- [ ] `Block-Time/Block-TimeTests/SchemaVersionTests.swift` — VersionedSchema container init (FOUND-01)
- [ ] `Block-Time/Block-TimeTests/ModelContainerFactoryTests.swift` — App Group URL resolution (FOUND-02)
- [ ] `Block-Time/Block-TimeTests/Fixtures/` — directory for real production `.sqlite` fixture file

---

## Critical Test Cases

### TimeStringConverter — All Variants Must Pass

```swift
assert(TimeStringConverter.toSeconds(nil)      == 0)       // nil
assert(TimeStringConverter.toSeconds("")        == 0)       // empty
assert(TimeStringConverter.toSeconds("0")       == 0)       // zero decimal
assert(TimeStringConverter.toSeconds("0.0")     == 0)       // zero decimal
assert(TimeStringConverter.toSeconds("4.53")    == 16308)   // decimal hours (4h 31m 48s)
assert(TimeStringConverter.toSeconds("4.5")     == 16200)   // decimal hours (4h 30m)
assert(TimeStringConverter.toSeconds("4")       == 14400)   // integer hours
assert(TimeStringConverter.toSeconds("4:32")    == 16320)   // HH:MM
assert(TimeStringConverter.toSeconds("9:05")    == 32700)   // HH:MM with leading zero minutes
assert(TimeStringConverter.toSeconds("4:5")     == 14700)   // H:M single-digit
assert(TimeStringConverter.toSeconds("-")       == 0)       // malformed placeholder
assert(TimeStringConverter.toSeconds("N/A")     == 0)       // malformed
assert(TimeStringConverter.toSeconds("  4.53  ") == 16308)  // whitespace trimmed
```

### Migration Crash Recovery

```swift
// 1. Set migrationStarted = true, migrationComplete = false
// 2. Write a partial SwiftData store at App Group URL
// 3. Call migrationService.runIfNeeded()
// 4. Assert partial store was deleted and replaced
// 5. Assert migrationComplete = true
// 6. Assert SwiftData count == Core Data count
```

### Real .sqlite Fixture (Hard Prerequisite)

A real production `FlightDataModel.sqlite` must be obtained from a device running the v1 app and committed to `Block-Time/Block-TimeTests/Fixtures/` before migration tests can be fully validated. Cannot be synthesised.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SwiftUI preview renders with InMemoryFlightRepository | FOUND-12 | Xcode previews can't be automated in CI | Open preview in Xcode, confirm no CloudKit connection required, confirm data shows |
| App Group URL produces same path as widget extension | FOUND-02 | Cross-target URL matching needs manual check | Build app + widget, log URL from both targets, confirm match |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] Real `.sqlite` fixture committed to `Block-Time/Block-TimeTests/Fixtures/`
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
