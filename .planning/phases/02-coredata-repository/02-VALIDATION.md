---
phase: 2
slug: coredata-repository
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-16
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift Package, swift-tools-version 6.0) |
| **Config file** | `BlockTimeKit/Package.swift` |
| **Quick run command** | `cd BlockTimeKit && swift test --filter BlockTimeDomainTests` |
| **Full suite command** | `cd BlockTimeKit && swift test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd BlockTimeKit && swift test`
- **After every plan wave:** Run `cd BlockTimeKit && swift test` + `xcodebuild build -scheme Block-Time -destination 'generic/platform=iOS'`
- **Before `/gsd:verify-work`:** Full suite green + app builds + launches on device
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | REPO-05, REPO-09 | unit | `cd BlockTimeKit && swift test --filter FlightTests` | ✅ (needs update) | ⬜ pending |
| 2-01-02 | 01 | 1 | REPO-09 | unit | `cd BlockTimeKit && swift test --filter FlightRepositoryTests` | ✅ (needs update) | ⬜ pending |
| 2-02-01 | 02 | 1 | REPO-02, REPO-04 | compile-time | `xcodebuild build -scheme Block-Time` | ❌ Wave 0 | ⬜ pending |
| 2-03-01 | 03 | 2 | REPO-01 | compile-time | `xcodebuild build -scheme Block-Time` | ❌ Wave 0 | ⬜ pending |
| 2-04-01 | 04 | 3 | REPO-07, REPO-08 | compile-time | `xcodebuild build -scheme Block-Time` | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `BlockTimeKit/Tests/BlockTimeDomainTests/FlightTests.swift` — update `sample()` fixture to new `Flight` init (covers REPO-05)
- [ ] `BlockTimeKit/Tests/BlockTimeDataTests/FlightRepositoryTests.swift` — update `makeFlight()` fixture to new `Flight` init (covers REPO-09)

*No new test files needed — existing tests cover domain struct and in-memory repository.*
*Migration policy conversion logic is not separately unit-tested per D-01 design.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Time string → Int16 minutes conversion in production | REPO-02 | Runs inside Core Data migration engine; no test harness access | After migration on device, open any flight with non-zero blockTime — verify displayed value matches original hours×60 |
| Gate string + date → UTC Date? migration | REPO-04 | Same — runs inside migration engine | After migration, verify outTime/inTime fields display correctly in FlightInfoCard |
| CloudKit sync survives migration | REPO-10 | Requires two physical devices | After migration on device A, verify flights appear on device B within 60 seconds |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
