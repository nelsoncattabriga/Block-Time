# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 01-foundation
**Areas discussed:** Package module structure, @Model placement, Migration crash safety, CloudKit during migration

---

## Package Module Structure

| Option | Description | Selected |
|--------|-------------|----------|
| 3 modules: Domain, Calculators, Data | Parsers live in BlockTimeCalculators. Simpler import graph. | ✓ |
| 4 modules: Domain, Calculators, Parsers, Data | Parsers get own module. Cleaner but more complexity. | |

**User's choice:** 3 modules

| Option | Description | Selected |
|--------|-------------|----------|
| Migration in app target | Keeps Core Data out of the package. One-shot concern. | ✓ |
| Migration in BlockTimeData | Puts it alongside the repository but drags Core Data into the package. | |

**User's choice:** App target only

| Option | Description | Selected |
|--------|-------------|----------|
| FlightRepository protocol in BlockTimeData | One import for all data access. ViewModels import BlockTimeData. | ✓ |
| FlightRepository protocol in BlockTimeDomain | Tighter coupling between domain and data access contract. | |

**User's choice:** BlockTimeData

| Option | Description | Selected |
|--------|-------------|----------|
| No services in Phase 1 (singletons stay in app target) | Phase 1 scope is schema + package + migration only. | ✓ |
| AirportService into BlockTimeCalculators now | Night-time calculation needs it but drags file parsing in early. | |

**User's choice:** None in Phase 1

---

## @Model Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Accept as known — @Model stays in app target from day one | Skip the spike. Saves time. | ✓ |
| Spike it in Phase 1 | 30 min experiment to confirm. Validates assumption. | |

**User's choice:** Accept as known — no spike needed

---

## Migration Crash Safety

| Option | Description | Selected |
|--------|-------------|----------|
| Clear SwiftData store + retry from scratch | Safe, simple. Core Data is read-only so retry is always safe. | ✓ |
| Batch-by-batch with row-count checkpoint | More complex, faster resume for large logbooks. | |

**User's choice:** Clear-and-retry

| Option | Description | Selected |
|--------|-------------|----------|
| Two flags: migrationStarted + migrationComplete | Can distinguish "never run" from "crashed mid-run". | ✓ |
| Single migrationComplete flag | Simpler. Can't distinguish states without heuristics. | |

**User's choice:** Two flags

| Option | Description | Selected |
|--------|-------------|----------|
| Verify row count before marking complete | Count match required. Surface diagnostic on mismatch. | ✓ |
| Trust the write loop | Faster. No count verification. | |

**User's choice:** Yes — verify row count

---

## CloudKit During Migration

| Option | Description | Selected |
|--------|-------------|----------|
| cloudKitDatabase: .none during migration, re-enable after | Prevents partial records syncing to v1 devices. | ✓ |
| Let CloudKit run during migration | Simpler setup. Risk of garbled records on v1 devices. | |

**User's choice:** Disable CloudKit during migration

| Option | Description | Selected |
|--------|-------------|----------|
| Force relaunch via exit(0) after migration completes | Simple. New launch creates the real CloudKit container. | ✓ |
| Swap containers in-process | Seamless UX but high complexity and risk. | |

**User's choice:** exit(0) relaunch

---

## Claude's Discretion

- Internal field layout of `Flight` domain struct
- Exact UserDefaults keys for migration flags
- Whether to show migration progress UI (deferred to Phase 3)
- `InMemoryFlightRepository` API surface detail

## Deferred Ideas

- AirportService into BlockTimeCalculators — deferred to Phase 2/3
- Migration progress UI — deferred to Phase 3
- Batch-by-batch checkpoint migration — evaluated, rejected
- In-process container swap — evaluated, rejected
