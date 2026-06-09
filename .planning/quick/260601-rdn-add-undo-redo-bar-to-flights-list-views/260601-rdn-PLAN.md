---
phase: quick
plan: 260601-rdn
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Services/FlightDatabaseService.swift
  - Block-Time/Views/Screens/FlightsView.swift
  - Block-Time/Views/Screens/FlightsSplitView.swift
autonomous: false
requirements: [UNDO-01]
must_haves:
  truths:
    - "After deleting or editing a flight, an undo bar appears in the flights list"
    - "Tapping Undo reverts the last change and the list updates"
    - "Redo appears only after an undo and re-applies the change"
    - "The undo bar disappears when there is nothing left to undo"
    - "Undo history clears when the app is killed (in-memory NSUndoManager)"
  artifacts:
    - path: "Block-Time/Services/FlightDatabaseService.swift"
      provides: "NSUndoManager on viewContext, canUndo/canRedo, undoLastChange()/redoLastChange()"
    - path: "Block-Time/Views/Screens/FlightsView.swift"
      provides: "undoBar below filterStatusBanner (iPhone)"
    - path: "Block-Time/Views/Screens/FlightsSplitView.swift"
      provides: "undoBar below filterStatusBanner (iPad split)"
  key_links:
    - from: "FlightsView.swift / FlightsSplitView.swift undoBar"
      to: "FlightDatabaseService.shared.canUndo / undoLastChange()"
      via: "@State refresh on NSManagedObjectContextDidSave + button actions"
      pattern: "FlightDatabaseService.shared.(canUndo|canRedo|undoLastChange|redoLastChange)"
---

<objective>
Add an undo/redo capability to the flights list. Wire an NSUndoManager to the Core Data viewContext so each main-thread save is one undoable step, then surface an undo/redo bar in both FlightsView (iPhone) and FlightsSplitView (iPad), styled identically to the existing filterStatusBanner.

Purpose: Let pilots reverse an accidental delete or edit before the app is closed — directly serving the "never lose data" core value.
Output: NSUndoManager wiring on the database service plus a matching undo bar in both list views.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md

<interfaces>
<!-- Key existing code the executor must work with. No exploration needed. -->

FlightDatabaseService is a singleton `ObservableObject` (do NOT migrate it):
```swift
class FlightDatabaseService: ObservableObject {
    static let shared = FlightDatabaseService()
    lazy var persistentContainer: NSPersistentCloudKitContainer = { ... }()
    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }
}
```

Main-thread mutating methods that call `viewContext.save()` inside `viewContext.performAndWait { ... }`:
- `saveFlight(_:) -> Bool`
- `updateFlight(_:) -> Bool`
- `updateScheduledFlightWithActualData(_:actualData:) -> Bool`
- `deleteFlight(_:) -> Bool`
- `deleteFlights(_:) -> Bool`
- `applyMergeProposals(_:)`

IMPORTANT — methods that save on a BACKGROUND context (`newBackgroundContext()`) must NOT be undo-grouped (the undo manager belongs to viewContext only): `updateFlightsBulk`, `saveFlightsBatch`, `fetch*Async`. Leave these untouched.
`clearAllFlights`, `deleteImportSession`, `duplicateFlights`, `regenerateAllFlightUUIDs`, and the one-time `migrate*` methods also call viewContext.save() — these are explicitly destructive/bulk or migration operations and should NOT be grouped into the undo stack (we do not want "Undo" to resurrect a cleared database or reverse a migration). Only group the per-flight save/update/delete paths listed above.

Existing filterStatusBanner styling (replicate exactly for the undo bar):
```swift
HStack(spacing: 10) { ... }
.padding(.horizontal, 16)
.padding(.vertical, 10)
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 12))
.overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accentColor.opacity(0.4), lineWidth: 1))
.padding(.horizontal, 12)
.padding(.bottom, 4)
.transition(.move(edge: .top).combined(with: .opacity))
```

In `FlightsView.body` the banner is placed in a VStack:
```swift
filterStatusBanner
flightListContent
```

In `FlightsSplitView` -> `FlightsListContent.body`:
```swift
flightCountHeader.background(Color.clear)
filterStatusBanner
flightListContent
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Wire NSUndoManager to viewContext in FlightDatabaseService</name>
  <files>Block-Time/Services/FlightDatabaseService.swift</files>
  <action>
Add NSUndoManager support to the Core Data stack so each per-flight save is one undoable step.

1. In the `persistentContainer` lazy closure, after the existing lines:
   ```swift
   container.viewContext.automaticallyMergesChangesFromParent = true
   container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
   ```
   add:
   ```swift
   container.viewContext.undoManager = UndoManager()
   ```
   (UndoManager is the Foundation type bridged as NSUndoManager; this enables undo registration on the context.)

2. Add computed vars and methods to the class (place them in a new `// MARK: - Undo / Redo` section, e.g. just after the `viewContext` computed property):
   ```swift
   // MARK: - Undo / Redo
   var canUndo: Bool { viewContext.undoManager?.canUndo ?? false }
   var canRedo: Bool { viewContext.undoManager?.canRedo ?? false }

   /// Number of grouped, undoable changes currently on the stack.
   /// NSUndoManager exposes no public count, so we track it ourselves.
   private(set) var undoableChangeCount: Int = 0

   @discardableResult
   func undoLastChange() -> Bool {
       guard let undoManager = viewContext.undoManager, undoManager.canUndo else { return false }
       var ok = false
       viewContext.performAndWait {
           undoManager.undo()
           do {
               try viewContext.save()
               ok = true
           } catch {
               LogManager.shared.error("Undo save failed: \(error.localizedDescription)")
               viewContext.rollback()
           }
       }
       if ok {
           undoableChangeCount = max(0, undoableChangeCount - 1)
           NotificationCenter.default.post(name: .flightDataChanged, object: nil)
       }
       return ok
   }

   @discardableResult
   func redoLastChange() -> Bool {
       guard let undoManager = viewContext.undoManager, undoManager.canRedo else { return false }
       var ok = false
       viewContext.performAndWait {
           undoManager.redo()
           do {
               try viewContext.save()
               ok = true
           } catch {
               LogManager.shared.error("Redo save failed: \(error.localizedDescription)")
               viewContext.rollback()
           }
       }
       if ok {
           undoableChangeCount += 1
           NotificationCenter.default.post(name: .flightDataChanged, object: nil)
       }
       return ok
   }
   ```

3. Wrap each save in the per-flight mutating methods with an undo group. For EACH of these methods only — `saveFlight`, `updateFlight`, `updateScheduledFlightWithActualData`, `deleteFlight`, `deleteFlights` — add `viewContext.undoManager?.beginUndoGrouping()` immediately before the `try viewContext.save()` line and `viewContext.undoManager?.endUndoGrouping()` immediately after a successful save, inside the existing `performAndWait` block. On the success path (after the save succeeds) also increment the count: `undoableChangeCount += 1`. Example shape for `deleteFlight`:
   ```swift
   viewContext.delete(flight)
   viewContext.undoManager?.beginUndoGrouping()
   try viewContext.save()
   viewContext.undoManager?.endUndoGrouping()
   undoableChangeCount += 1
   success = true
   ```
   On the catch/rollback path do NOT increment and do NOT leave a dangling open group — call `endUndoGrouping()` only when a group was begun. Safest pattern: begin the group, then `do { try save; endGrouping; count += 1 } catch { endGrouping; rollback }`. Keep the existing rollback calls.

   Do NOT touch `applyMergeProposals` grouping unless trivial — leave it as-is (it is a review-confirmed merge, not a primary user action). Do NOT add grouping to any background-context method (`updateFlightsBulk`, `saveFlightsBatch`, async fetches) or to `clearAllFlights`, `deleteImportSession`, `duplicateFlights`, `regenerateAllFlightUUIDs`, or any `migrate*` method.

CRITICAL: Do not remove or alter any existing logic, logging, CloudKit enable/disable behaviour, or rollback handling. Only add the lines described.
  </action>
  <verify>
    <automated>cd "/Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time" && grep -n "undoManager = UndoManager()" Block-Time/Services/FlightDatabaseService.swift && grep -c "beginUndoGrouping" Block-Time/Services/FlightDatabaseService.swift</automated>
  </verify>
  <done>`undoManager` is assigned on viewContext; `canUndo`/`canRedo`/`undoLastChange()`/`redoLastChange()`/`undoableChangeCount` exist; `beginUndoGrouping` appears exactly 5 times (one per per-flight save method). Background/bulk/migration methods are unchanged.</done>
</task>

<task type="auto">
  <name>Task 2: Add undoBar to FlightsView and FlightsSplitView</name>
  <files>Block-Time/Views/Screens/FlightsView.swift, Block-Time/Views/Screens/FlightsSplitView.swift</files>
  <action>
Add a matching undo/redo bar to both list views, below the filterStatusBanner. Apply the SAME change to BOTH files (FlightsView struct and the FlightsListContent struct inside FlightsSplitView).

1. Add two @State properties to each view (alongside the other @State vars):
   ```swift
   @State private var undoCount: Int = 0
   @State private var canRedo: Bool = false
   ```

2. Add a `refreshUndoState()` helper to each view:
   ```swift
   private func refreshUndoState() {
       undoCount = FlightDatabaseService.shared.undoableChangeCount
       canRedo = FlightDatabaseService.shared.canRedo
   }
   ```

3. Add an `undoBar` @ViewBuilder computed property to each view, styled exactly like filterStatusBanner (orange accent). Only visible when `undoCount > 0`:
   ```swift
   @ViewBuilder
   private var undoBar: some View {
       if undoCount > 0 {
           HStack(spacing: 10) {
               Image(systemName: "arrow.uturn.backward.circle.fill")
                   .font(.subheadline)
                   .foregroundColor(.orange)
               VStack(alignment: .leading, spacing: 1) {
                   Text("↩ \(undoCount) \(undoCount == 1 ? "change" : "changes") to undo")
                       .font(.subheadline.weight(.medium))
                       .foregroundColor(.primary)
                   Text("History clears when app closes")
                       .font(.footnote)
                       .foregroundColor(.secondary)
               }
               Spacer()
               if canRedo {
                   Button {
                       HapticManager.shared.impact(.light)
                       FlightDatabaseService.shared.redoLastChange()
                       withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                           refreshUndoState()
                       }
                   } label: {
                       Text("Redo")
                           .font(.subheadline.weight(.semibold))
                           .foregroundColor(.white)
                           .padding(.horizontal, 14)
                           .padding(.vertical, 6)
                           .background(Color.gray)
                           .clipShape(Capsule())
                   }
                   .buttonStyle(PlainButtonStyle())
               }
               Button {
                   HapticManager.shared.impact(.light)
                   FlightDatabaseService.shared.undoLastChange()
                   withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                       refreshUndoState()
                   }
               } label: {
                   Text("Undo")
                       .font(.subheadline.weight(.semibold))
                       .foregroundColor(.white)
                       .padding(.horizontal, 14)
                       .padding(.vertical, 6)
                       .background(Color.orange)
                       .clipShape(Capsule())
               }
               .buttonStyle(PlainButtonStyle())
           }
           .padding(.horizontal, 16)
           .padding(.vertical, 10)
           .background(.ultraThinMaterial)
           .clipShape(RoundedRectangle(cornerRadius: 12))
           .overlay(
               RoundedRectangle(cornerRadius: 12)
                   .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
           )
           .padding(.horizontal, 12)
           .padding(.bottom, 4)
           .transition(.move(edge: .top).combined(with: .opacity))
       }
   }
   ```

4. Place `undoBar` directly below `filterStatusBanner` in the body VStack of each view:
   - FlightsView.body: change `filterStatusBanner` / `flightListContent` to `filterStatusBanner` / `undoBar` / `flightListContent`.
   - FlightsListContent.body (in FlightsSplitView): same — insert `undoBar` between `filterStatusBanner` and `flightListContent`.

5. Keep the bar's visibility animated. Add `.animation(.spring(response: 0.3, dampingFraction: 0.7), value: undoCount)` near the existing `.animation(...)` modifiers on each view's root.

6. Refresh undo state automatically so the bar appears/disappears on its own:
   - In each view's existing `.onReceive(NotificationCenter.default.publisher(for: .flightDataChanged))` handler, call `refreshUndoState()` (in addition to the existing reload logic).
   - Add an `.onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave))` modifier on each view's root that calls `refreshUndoState()`. Import is already CoreData.
   - Also call `refreshUndoState()` in the existing `.onAppear`.

CRITICAL: Do not remove or alter any existing feature, button, banner, toolbar, or behaviour. The undo bar is purely additive and sits alongside filterStatusBanner (both can show at once). Use `.footnote` for the secondary label (never `.caption` on iPhone).
  </action>
  <verify>
    <automated>cd "/Users/nelson/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time" && grep -c "private var undoBar" Block-Time/Views/Screens/FlightsView.swift Block-Time/Views/Screens/FlightsSplitView.swift && grep -c "refreshUndoState" Block-Time/Views/Screens/FlightsView.swift Block-Time/Views/Screens/FlightsSplitView.swift && grep -c "NSManagedObjectContextDidSave" Block-Time/Views/Screens/FlightsView.swift Block-Time/Views/Screens/FlightsSplitView.swift</automated>
  </verify>
  <done>Both files contain an `undoBar` view, a `refreshUndoState()` helper, the two new @State vars, and an NSManagedObjectContextDidSave onReceive. The bar renders below filterStatusBanner and only when `undoCount > 0`. No existing UI removed.</done>
</task>

</tasks>

<verification>
- `undoManager` assigned on viewContext; per-flight saves grouped (5 occurrences of beginUndoGrouping); background/bulk/migration saves untouched.
- Undo bar appears in both views below filterStatusBanner after a delete/edit, with orange Undo (always) and grey Redo (only after an undo).
- Bar auto-hides when undoCount returns to 0.
- Build locally (Nelson builds) — no compiler regressions; existing features intact.
</verification>

<success_criteria>
- Deleting or editing a flight shows the undo bar; Undo reverts it and the list refreshes.
- Redo appears only after an undo and re-applies the change.
- Secondary label uses `.footnote`; styling matches filterStatusBanner (orange).
- Both FlightsView and FlightsSplitView have identical behaviour.
</success_criteria>

<output>
After completion, create `.planning/quick/260601-rdn-add-undo-redo-bar-to-flights-list-views/260601-rdn-SUMMARY.md`
</output>
