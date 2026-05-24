---
phase: quick-260524-iw3
plan: 01
subsystem: PDF Export
tags: [pdf, cover-page, typography, layout]
dependency_graph:
  requires: []
  provides: [title-width-derived-rule-line]
  affects: [LogbookPDFCoverDrawer]
tech_stack:
  added: []
  patterns: [NSString.size(withAttributes:) for CoreGraphics text measurement]
key_files:
  modified:
    - Block-Time/Services/LogbookPDFPageDrawer.swift
decisions:
  - Used NSString.size(withAttributes:) with in-scope titleFont; +8pt padding each side
metrics:
  duration: "< 5 minutes"
  completed: 2026-05-24
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
---

# Quick Task 260524-iw3: Fix Cover Page Rule Line to Match Title Width

**One-liner:** Cover page decorative rule now spans measured title text width (+8pt padding) instead of a fixed 240pt.

## What Was Done

In `LogbookPDFCoverDrawer.draw()`, replaced the hardcoded `centreX ± 120` rule line endpoints with a measurement-derived width. The title string is measured using `(title as NSString).size(withAttributes: [.font: titleFont])`, half that width plus 8pt of padding becomes `ruleHalfWidth`, and the `move`/`addLine` calls use `centreX ± ruleHalfWidth`.

## Tasks

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Derive rule line width from rendered title text | c260347 | Block-Time/Services/LogbookPDFPageDrawer.swift |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `grep -n "ruleHalfWidth"` returns lines 50, 53, 54 — confirmed present.
- No `centreX - 120` / `centreX + 120` remaining.
- Commit c260347 exists in git log.
