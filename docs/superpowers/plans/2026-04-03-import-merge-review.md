# Import Merge Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Before any import saves changes to existing flights (reg/type merges), show the user a reviewable list of exactly what will change, with per-row accept/reject toggles, so nothing is silently modified.

**Architecture:** Split the merge logic into two phases — a dry-run "plan" phase that returns a list of proposed changes without writing anything, and an "apply" phase that only executes user-approved changes. A new `ImportMergeReviewSheet` view (modelled on the existing `ImportSessionReviewSheet`) presents the proposed changes as a selectable list. The `saveFlightsBatch` return tuple gains a `mergedFields` array so callers can thread it through to the UI.

**Tech Stack:** SwiftUI, Core Data (`NSManagedObjectContext`), existing `FlightDatabaseService`, `FileImportService`, `ImportExportView`, `ImportSessionReviewSheet`.

---

## Files

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `Block-Time/Services/FlightDatabaseService.swift` | Add `MergeProposal` struct; split merge into dry-run + apply; return proposals in batch result |
| Modify | `Block-Time/Views/Screens/Settings/ImportExportView.swift` | Wire merge proposals into review sheet trigger; pass proposals to `ImportMergeReviewSheet` |
| Modify | `Block-Time/Views/Screens/Settings/ImportSessionReviewSheet.swift` | Add merged-fields stat row (count only, no detail) |
| Create | `Block-Time/Views/Screens/Settings/ImportMergeReviewSheet.swift` | New sheet: selectable list of proposed field changes, Approve All / Reject All, Confirm button |
| Modify | `Block-Time/Services/FileImportService.swift` | Propagate `mergeProposals` from `saveFlightsBatch` result through `ImportResult` |

---

## Task 1: Add `MergeProposal` and dry-run to `FlightDatabaseService`

**Files:**
- Modify: `Block-Time/Services/FlightDatabaseService.swift:939-1200`

The `saveFlightsBatch` function currently performs merges inline and discards the change details. We'll refactor it so the merge detection step produces a list of `MergeProposal` values that are returned to the caller. The actual Core Data writes for merges will be extracted into a separate `applyMergeProposals(_:)` function. The existing new-flight save logic is unchanged.

- [ ] **Step 1: Add `MergeProposal` struct above `saveFlightsBatch`**

Find the line `// MARK: - OPTIMIZED: Save multiple flights` (around line 937) and insert before it:

```swift
// MARK: - Merge Proposal

/// Describes a single field change proposed by duplicate detection before it is committed.
/// The caller presents these to the user for approval; only approved proposals are applied.
struct MergeProposal: Identifiable {
    let id: UUID = UUID()
    /// Human-readable date string for display (e.g. "05/03/2026")
    let flightDate: String
    /// Route string for display (e.g. "BNE → MEL")
    let route: String
    /// Core Data objectID of the flight to patch
    let objectID: NSManagedObjectID
    /// Field name shown to the user (e.g. "Aircraft Reg")
    let fieldName: String
    /// Value currently stored in the database (may be empty)
    let oldValue: String
    /// Value that the import source wants to write
    let newValue: String
}
```

- [ ] **Step 2: Update the `saveFlightsBatch` return tuple to include `mergeProposals`**

Change the function signature from:

```swift
func saveFlightsBatch(_ sectors: [FlightSector], sessionID: UUID = UUID()) -> (successCount: Int, failureCount: Int, duplicateCount: Int, sessionID: UUID) {
```

to:

```swift
func saveFlightsBatch(_ sectors: [FlightSector], sessionID: UUID = UUID()) -> (successCount: Int, failureCount: Int, duplicateCount: Int, sessionID: UUID, mergeProposals: [MergeProposal]) {
```

- [ ] **Step 3: Add a `var mergeProposals: [MergeProposal] = []` local var inside `saveFlightsBatch`**

At the top of the function body alongside the existing `var successCount = 0` declarations:

```swift
var mergeProposals: [MergeProposal] = []
```

- [ ] **Step 4: Replace the UUID-match merge write with a proposal**

Locate the UUID-match merge block (around line 1046–1065). Replace the direct Core Data writes with proposal construction:

```swift
// Before (writes immediately):
if existingType.isEmpty && !incomingType.isEmpty {
    existing.aircraftType = incomingType
    existing.modifiedAt = Date()
    patched = true
}
if existingReg.isEmpty && !incomingReg.isEmpty {
    existing.aircraftReg = incomingReg
    existing.modifiedAt = Date()
    patched = true
}
if patched {
    LogManager.shared.info("✎ Merged blank fields (UUID match): ...")
}
```

Replace with:

```swift
let displayDate = sector.date
let displayRoute = "\(sector.fromAirport) → \(sector.toAirport)"
if existingType.isEmpty && !incomingType.isEmpty {
    mergeProposals.append(MergeProposal(
        flightDate: displayDate,
        route: displayRoute,
        objectID: existing.objectID,
        fieldName: "Aircraft Type",
        oldValue: existingType,
        newValue: incomingType
    ))
}
if existingReg.isEmpty && !incomingReg.isEmpty {
    mergeProposals.append(MergeProposal(
        flightDate: displayDate,
        route: displayRoute,
        objectID: existing.objectID,
        fieldName: "Aircraft Reg",
        oldValue: existingReg,
        newValue: incomingReg
    ))
}
LogManager.shared.info("✎ Proposed \(mergeProposals.count) field update(s) for UUID match: \(displayDate) \(displayRoute)")
```

- [ ] **Step 5: Replace the fuzzy-match merge write with a proposal**

Locate the fuzzy-match merge block (around line 1092–1108). Replace direct writes with proposals:

```swift
// Before:
if !incomingReg.isEmpty {
    existing.aircraftReg = incomingReg
    existing.modifiedAt = Date()
    patched = true
}
if existingType.isEmpty && !incomingType.isEmpty {
    existing.aircraftType = incomingType
    existing.modifiedAt = Date()
    patched = true
}
if patched {
    LogManager.shared.info("✎ Merged fields (fuzzy match): ...")
}
```

Replace with:

```swift
let displayDate = sector.date
let displayRoute = "\(sector.fromAirport) → \(sector.toAirport)"
let existingRegValue = (existing.aircraftReg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
if !incomingReg.isEmpty {
    mergeProposals.append(MergeProposal(
        flightDate: displayDate,
        route: displayRoute,
        objectID: existing.objectID,
        fieldName: "Aircraft Reg",
        oldValue: existingRegValue,
        newValue: incomingReg
    ))
}
if existingType.isEmpty && !incomingType.isEmpty {
    mergeProposals.append(MergeProposal(
        flightDate: displayDate,
        route: displayRoute,
        objectID: existing.objectID,
        fieldName: "Aircraft Type",
        oldValue: existingType,
        newValue: incomingType
    ))
}
LogManager.shared.info("✎ Proposed \(mergeProposals.count) field update(s) for fuzzy match: \(displayDate) \(displayRoute)")
```

- [ ] **Step 6: Update the return statement at the bottom of `saveFlightsBatch`**

Find the existing `return` at the bottom of `viewContext.performAndWait` closure. After the `viewContext.save()` call, the function returns a tuple. Update it:

```swift
// Before:
return (successCount: successCount, failureCount: failureCount, duplicateCount: duplicateCount, sessionID: sessionID)

// After:
return (successCount: successCount, failureCount: failureCount, duplicateCount: duplicateCount, sessionID: sessionID, mergeProposals: mergeProposals)
```

Note: `saveFlightsBatch` uses `viewContext.performAndWait` which assigns into an outer variable. Make sure the outer variable also captures `mergeProposals`. The pattern will be:

```swift
var successCount = 0
var failureCount = 0
var duplicateCount = 0
var mergeProposals: [MergeProposal] = []

viewContext.performAndWait {
    // ... all existing logic, now populating mergeProposals instead of writing ...
}

return (successCount: successCount, failureCount: failureCount, duplicateCount: duplicateCount, sessionID: sessionID, mergeProposals: mergeProposals)
```

- [ ] **Step 7: Add `applyMergeProposals(_:)` to `FlightDatabaseService`**

Add this function after `saveFlightsBatch`:

```swift
/// Applies a subset of approved merge proposals to Core Data and saves.
/// Call this after the user has reviewed and confirmed their selection.
func applyMergeProposals(_ proposals: [MergeProposal]) {
    guard !proposals.isEmpty else { return }
    viewContext.performAndWait {
        for proposal in proposals {
            guard let entity = try? viewContext.existingObject(with: proposal.objectID) as? FlightEntity else {
                LogManager.shared.error("applyMergeProposals: could not find entity for \(proposal.flightDate) \(proposal.route)")
                continue
            }
            switch proposal.fieldName {
            case "Aircraft Reg":
                entity.aircraftReg = proposal.newValue
            case "Aircraft Type":
                entity.aircraftType = proposal.newValue
            default:
                LogManager.shared.error("applyMergeProposals: unknown field '\(proposal.fieldName)'")
                continue
            }
            entity.modifiedAt = Date()
            LogManager.shared.info("✎ Applied merge: \(proposal.flightDate) \(proposal.route) \(proposal.fieldName): '\(proposal.oldValue)' → '\(proposal.newValue)'")
        }
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                LogManager.shared.info("applyMergeProposals: saved \(proposals.count) change(s)")
            } catch {
                viewContext.rollback()
                LogManager.shared.error("applyMergeProposals: save failed: \(error.localizedDescription)")
            }
        }
    }
}
```

- [ ] **Step 8: Build and verify no compile errors before proceeding**

In Xcode press ⌘B. Fix any "extra argument in call" errors at the `saveFlightsBatch` call sites — they are addressed in Tasks 2 and 3.

---

## Task 2: Propagate `mergeProposals` through `FileImportService` and `ImportResult`

**Files:**
- Modify: `Block-Time/Services/FileImportService.swift:1619-1626` (ImportResult struct)
- Modify: `Block-Time/Services/FileImportService.swift:294-318` (batch save call site)

- [ ] **Step 1: Add `mergeProposals` to `ImportResult`**

Find the `ImportResult` struct (around line 1619):

```swift
// Before:
struct ImportResult {
    let successCount: Int
    let failureCount: Int
    let duplicateCount: Int
    let failureReasons: [String: Int]
    let sampleFailures: [(row: Int, reason: String)]
    let sessionID: UUID?
}
```

```swift
// After:
struct ImportResult {
    let successCount: Int
    let failureCount: Int
    let duplicateCount: Int
    let failureReasons: [String: Int]
    let sampleFailures: [(row: Int, reason: String)]
    let sessionID: UUID?
    let mergeProposals: [MergeProposal]
}
```

- [ ] **Step 2: Capture `mergeProposals` at the `saveFlightsBatch` call site**

Find the `DispatchQueue.main.sync` block around line 297. Add capture of the new field:

```swift
// Before:
DispatchQueue.main.sync {
    let result = databaseService.saveFlightsBatch(flights)
    successCount = result.successCount
    let dbFailures = result.failureCount
    duplicateCount = result.duplicateCount
    importSessionID = result.sessionID
    ...
}
```

```swift
// After:
var mergeProposals: [MergeProposal] = []
DispatchQueue.main.sync {
    let result = databaseService.saveFlightsBatch(flights)
    successCount = result.successCount
    let dbFailures = result.failureCount
    duplicateCount = result.duplicateCount
    importSessionID = result.sessionID
    mergeProposals = result.mergeProposals
    ...
}
```

- [ ] **Step 3: Include `mergeProposals` in the returned `ImportResult`**

Around line 311:

```swift
// Before:
let result = ImportResult(
    successCount: successCount,
    failureCount: failureCount,
    duplicateCount: duplicateCount,
    failureReasons: failureReasons,
    sampleFailures: sampleFailures,
    sessionID: importSessionID
)
```

```swift
// After:
let result = ImportResult(
    successCount: successCount,
    failureCount: failureCount,
    duplicateCount: duplicateCount,
    failureReasons: failureReasons,
    sampleFailures: sampleFailures,
    sessionID: importSessionID,
    mergeProposals: mergeProposals
)
```

- [ ] **Step 4: Fix the `MigrationImportService` call site**

Open `Block-Time/Services/MigrationImportService.swift` and find the `saveFlightsBatch` call (around line 482). The return tuple now has an extra field — add a discard:

```swift
let result = await MainActor.run {
    updateProgress(.importingFlights, current: flights.count, total: flights.count, message: "Saving flights to database...")
    return databaseService.saveFlightsBatch(flightSectors)
}
// result.mergeProposals intentionally ignored for migration imports (data was already the user's own)
```

No other change needed here — migration imports are restoring the user's own data so silent merges are acceptable.

- [ ] **Step 5: Build (⌘B) — should compile clean**

---

## Task 3: Create `ImportMergeReviewSheet`

**Files:**
- Create: `Block-Time/Views/Screens/Settings/ImportMergeReviewSheet.swift`

This sheet is shown **before** the import summary when there are merge proposals. It lists each proposed change as a toggleable row. The user can deselect rows they don't want applied. Tapping "Apply Selected" calls `applyMergeProposals` with only the approved subset and then dismisses so the caller can show the success summary.

- [ ] **Step 1: Create the file**

```swift
//
//  ImportMergeReviewSheet.swift
//  Block-Time
//

import SwiftUI

struct ImportMergeReviewSheet: View {
    let proposals: [MergeProposal]
    /// Called with the user-approved subset (may be empty if all rejected)
    let onConfirm: ([MergeProposal]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var approved: Set<UUID>

    init(proposals: [MergeProposal], onConfirm: @escaping ([MergeProposal]) -> Void) {
        self.proposals = proposals
        self.onConfirm = onConfirm
        // Default: all approved
        _approved = State(initialValue: Set(proposals.map { $0.id }))
    }

    private var approvedCount: Int { approved.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The import found \(proposals.count) field update\(proposals.count == 1 ? "" : "s") for existing flights.")
                            .font(.subheadline)
                        Text("Review and deselect any changes you don't want applied. Deselected rows will be left unchanged.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Proposed Changes")) {
                    ForEach(proposals) { proposal in
                        MergeProposalRow(
                            proposal: proposal,
                            isApproved: approved.contains(proposal.id)
                        ) { isOn in
                            if isOn {
                                approved.insert(proposal.id)
                            } else {
                                approved.remove(proposal.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review Updates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Select All") {
                        approved = Set(proposals.map { $0.id })
                    }
                    .disabled(approved.count == proposals.count)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let selected = proposals.filter { approved.contains($0.id) }
                        onConfirm(selected)
                        dismiss()
                    } label: {
                        Text(approvedCount > 0 ? "Apply \(approvedCount)" : "Skip All")
                            .fontWeight(.semibold)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(role: .destructive) {
                    onConfirm([])
                    dismiss()
                } label: {
                    Text("Reject All Changes")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Row

private struct MergeProposalRow: View {
    let proposal: MergeProposal
    let isApproved: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isApproved)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isApproved ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isApproved ? Color.accentColor : Color.secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(proposal.flightDate)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(proposal.route)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text(proposal.fieldName + ":")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if proposal.oldValue.isEmpty {
                            Text("(empty)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            Text(proposal.oldValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .strikethrough(!isApproved)
                        }
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(proposal.newValue)
                            .font(.caption)
                            .foregroundStyle(isApproved ? .primary : .secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build (⌘B)**

---

## Task 4: Wire `ImportMergeReviewSheet` into `ImportExportView`

**Files:**
- Modify: `Block-Time/Views/Screens/Settings/ImportExportView.swift`

The review sheet must appear whenever an import (file or WebCIS) returns merge proposals, **before** the success summary sheet. The flow is:

1. Import completes → if `mergeProposals.count > 0`, show `ImportMergeReviewSheet`
2. User confirms (with approved subset) → `applyMergeProposals` is called → `ImportMergeReviewSheet` dismisses
3. Then show `ImportSessionReviewSheet` as today

- [ ] **Step 1: Add state for merge review**

Find the existing `@State` block in `ImportExportView`. Add two new state vars:

```swift
@State private var pendingMergeProposals: [MergeProposal] = []
@State private var showingMergeReview = false
```

Also add a reference to the database service (it is likely already accessible via environment or singleton — check the file for how `FlightDatabaseService.shared` is referenced elsewhere in the view):

```swift
private let databaseService = FlightDatabaseService.shared
```

- [ ] **Step 2: Attach the merge review sheet**

Find where `.sheet(item: $lastImportResult)` is declared. Add a new sheet above it:

```swift
.sheet(isPresented: $showingMergeReview) {
    ImportMergeReviewSheet(proposals: pendingMergeProposals) { approved in
        databaseService.applyMergeProposals(approved)
    }
}
```

- [ ] **Step 3: Update the file import completion handler**

In the `case .success(let importResult):` block for file import (around line 464), after setting `lastImportResult`, add the merge review trigger:

```swift
case .success(let importResult):
    viewModel.reloadSavedCrewNames()

    // Show merge review first if there are proposed changes
    if !importResult.mergeProposals.isEmpty {
        pendingMergeProposals = importResult.mergeProposals
        showingMergeReview = true
    }

    if importResult.successCount > 0 {
        lastImportSuccessCount = importResult.successCount
        lastImportResult = ImportSessionResult(
            sessionID: importResult.sessionID ?? UUID(),
            successCount: importResult.successCount,
            duplicateCount: importResult.duplicateCount,
            mergedCount: importResult.mergeProposals.count
        )
    } else {
        var message = "Import Summary\n\n"
        if importResult.duplicateCount > 0 {
            message += "⊘ \(importResult.duplicateCount) flight(s) already exist — nothing new imported.\n"
        }
        if !importResult.mergeProposals.isEmpty {
            message += "✎ \(importResult.mergeProposals.count) field update(s) were proposed for review.\n"
        }
        // ... rest of existing failure message logic unchanged
    }
```

- [ ] **Step 4: Update the WebCIS import completion handler**

In `performWebCISImportWithMappings` (around line 583):

```swift
case .success(let importResult):
    viewModel.reloadSavedCrewNames()

    // Show merge review first if there are proposed changes
    if !importResult.mergeProposals.isEmpty {
        pendingMergeProposals = importResult.mergeProposals
        showingMergeReview = true
    }

    lastImportSuccessCount = importResult.successCount
    lastImportResult = ImportSessionResult(
        sessionID: importResult.sessionID ?? UUID(),
        successCount: importResult.successCount,
        duplicateCount: importResult.duplicateCount,
        mergedCount: importResult.mergeProposals.count
    )
```

- [ ] **Step 5: Build (⌘B) and fix any remaining compile errors**

---

## Task 5: Update `ImportSessionReviewSheet` to show merge count

**Files:**
- Modify: `Block-Time/Views/Screens/Settings/ImportSessionReviewSheet.swift`

The existing `mergedCount` field in `ImportSessionResult` is already defined but hardcoded to `0`. Now it will carry a real value. Add a row to the stats card.

- [ ] **Step 1: Add merged-fields row to the stats card**

In `ImportSessionReviewSheet.body`, find the stats `VStack` (around line 30). Add after the duplicates row:

```swift
if result.mergedCount > 0 {
    ImportStatRow(
        icon: "pencil.circle.fill",
        color: .orange,
        label: "Existing flights updated",
        value: result.mergedCount
    )
}
```

- [ ] **Step 2: Build (⌘B)**

---

## Task 6: Manual test checklist

No unit test harness exists for Core Data services in this project — verify manually.

- [ ] **Test A — WebCIS re-import (merge proposals expected)**
  1. Run the app. Go to Settings → Import.
  2. Import WebCIS history for a month you have already imported.
  3. Expected: `ImportMergeReviewSheet` appears listing the reg/type proposals.
  4. Deselect one row. Tap "Apply X".
  5. Expected: Only selected rows are written. Navigate to a flight from that month and verify the reg/type values match your choices.

- [ ] **Test B — File import with no merges**
  1. Import a CSV file with no flights matching existing records.
  2. Expected: `ImportMergeReviewSheet` does NOT appear. `ImportSessionReviewSheet` shows 0 "Existing flights updated".

- [ ] **Test C — Reject all**
  1. Re-import WebCIS. When merge sheet appears, tap "Reject All Changes".
  2. Expected: No field changes written. Flight records unchanged. Success summary still appears.

- [ ] **Test D — Select All button**
  1. Re-import WebCIS. Deselect a few rows. Tap "Select All". Tap "Apply X".
  2. Expected: All proposals applied.

- [ ] **Step: Commit**

```bash
git add Block-Time/Services/FlightDatabaseService.swift \
        Block-Time/Services/FileImportService.swift \
        Block-Time/Services/MigrationImportService.swift \
        Block-Time/Views/Screens/Settings/ImportMergeReviewSheet.swift \
        Block-Time/Views/Screens/Settings/ImportExportView.swift \
        Block-Time/Views/Screens/Settings/ImportSessionReviewSheet.swift
git commit -m "feat: show merge review sheet before applying import field updates"
```

---

## Self-Review

**Spec coverage:**
- ✅ Reviewable list of what will change → `ImportMergeReviewSheet` with per-row detail
- ✅ Per-row accept/reject toggles → `approved: Set<UUID>` with `MergeProposalRow` toggle
- ✅ Nothing silently modified → merge writes moved from `saveFlightsBatch` to `applyMergeProposals` called only after user confirmation
- ✅ Both import paths covered → file import and WebCIS import handlers both updated
- ✅ Approve All / Reject All → "Select All" toolbar button + "Reject All Changes" footer button
- ✅ Count shown in success summary → `ImportSessionReviewSheet` updated with `mergedCount` row

**Placeholder scan:** None found.

**Type consistency:**
- `MergeProposal` defined in Task 1, used identically in Tasks 2, 3, 4.
- `applyMergeProposals(_:)` defined in Task 1 step 7, called in Task 4 step 2.
- `ImportResult.mergeProposals: [MergeProposal]` added in Task 2, read in Task 4.
- `ImportSessionResult.mergedCount` already exists — Task 5 reads it, Task 4 sets it.
