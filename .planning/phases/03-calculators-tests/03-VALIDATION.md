---
phase: 3
slug: calculators-tests
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-17
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (XCTestCase subclasses — matches existing pattern) |
| **Config file** | `Package.swift` — `BlockTimeCalculatorsTests` target (Wave 0 adds this) |
| **Quick run command** | `xcodebuild test -scheme BlockTimeCalculators -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -scheme BlockTime -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme BlockTimeCalculators -destination 'platform=macOS'`
- **After every plan wave:** Run `xcodebuild test -scheme BlockTime -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 3-W0-01 | 01 | 0 | CALC-01 | build | `xcodebuild build -scheme BlockTimeCalculators` | ❌ W0 | ⬜ pending |
| 3-01-01 | 01 | 1 | CALC-03 | unit | `xcodebuild test -scheme BlockTimeCalculators -only-testing:BlockTimeCalculatorsTests/FRMSCalculatorTests` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 1 | CALC-04 | unit | `xcodebuild test -scheme BlockTimeCalculators -only-testing:BlockTimeCalculatorsTests/NightTimeCalculatorTests` | ❌ W0 | ⬜ pending |
| 3-01-03 | 01 | 1 | CALC-05 | unit | `xcodebuild test -scheme BlockTimeCalculators -only-testing:BlockTimeCalculatorsTests/UTCConverterTests` | ❌ W0 | ⬜ pending |
| 3-01-04 | 01 | 1 | CALC-06 | unit | `xcodebuild test -scheme BlockTimeCalculators -only-testing:BlockTimeCalculatorsTests/TimeFormatterTests` | ❌ W0 | ⬜ pending |
| 3-02-01 | 02 | 2 | CALC-07 | unit | `xcodebuild test -scheme BlockTimeCalculators -only-testing:BlockTimeCalculatorsTests/FRMSCalculatorTests` | ❌ W0 | ⬜ pending |
| 3-02-02 | 02 | 2 | CALC-08 | unit | `xcodebuild test -scheme BlockTimeCalculators -only-testing:BlockTimeCalculatorsTests/NightTimeCalculatorTests` | ❌ W0 | ⬜ pending |
| 3-02-03 | 02 | 2 | CALC-09 | unit | `xcodebuild test -scheme BlockTimeCalculators -only-testing:BlockTimeCalculatorsTests/TimeFormatterTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `BlockTimeCalculators/Tests/BlockTimeCalculatorsTests/FRMSCalculatorTests.swift` — XCTestCase stub for CALC-03, CALC-07
- [ ] `BlockTimeCalculators/Tests/BlockTimeCalculatorsTests/NightTimeCalculatorTests.swift` — XCTestCase stub for CALC-04, CALC-08
- [ ] `BlockTimeCalculators/Tests/BlockTimeCalculatorsTests/UTCConverterTests.swift` — XCTestCase stub for CALC-05
- [ ] `BlockTimeCalculators/Tests/BlockTimeCalculatorsTests/TimeFormatterTests.swift` — XCTestCase stub for CALC-06, CALC-09
- [ ] `Package.swift` updated with `BlockTimeCalculatorsTests` test target

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| App target still compiles after extraction | CALC-01, CALC-02 | Requires Xcode build with app target, not just package | Build `Block-Time` scheme in Xcode; confirm no missing-symbol errors |
| Call sites in `FRMSCalculationService` continue to work correctly | CALC-02 | Coordinator stays in app target; integration not testable in package alone | Build + smoke-test FRMS display in the running app |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
