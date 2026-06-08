---
phase: quick-260608-ptl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Services/UnifiedRosterParser.swift
  - Block-Time/Services/PlannedFlightService.swift
  - Block-Time/Views/Screens/Settings/UnifiedRosterImportView.swift
autonomous: true
requirements: [STALE-01]
must_haves:
  truths:
    - "After import, unflown logbook flights within the roster's date range but absent from the new roster are detected as stale"
    - "A flown flight is never offered for removal"
    - "If there are zero stale flights, the import goes straight to the result screen (no extra sheet)"
    - "Stale flights are shown in an interstitial review sheet, all toggled on (remove) by default"
    - "User can deselect any stale flight to keep it; only selected stale flights are deleted on Continue"
  artifacts:
    - path: "Block-Time/Services/PlannedFlightService.swift"
      provides: "findStaleFlights() and deleteFlights(byEntityIDs:) and ImportResult.staleFlights"
      contains: "func findStaleFlights"
    - path: "Block-Time/Views/Screens/Settings/UnifiedRosterImportView.swift"
      provides: "Stale review interstitial sheet between import and result"
      contains: "case staleReview"
  key_links:
    - from: "UnifiedRosterImportView.importSelectedFlights"
      to: "PlannedFlightService.findStaleFlights"
      via: "called after importFlights, before showing result"
      pattern: "findStaleFlights"
    - from: "Stale review sheet Continue action"
      to: "PlannedFlightService.deleteFlights"
      via: "deletes selected stale FlightEntity objects then shows result"
      pattern: "deleteStaleFlights|deleteFlights"
---

<objective>
Detect "stale" roster flights — unflown logbook flights inside the imported roster's bid-period date window that are NOT present in the new roster — and let the user review/remove them in an interstitial sheet inserted between the existing Preview and Result screens.

Purpose: Keeps the logbook in sync when rosters change (cancelled/swapped trips) without ever touching flown flights.
Output: New service methods on `PlannedFlightService`, a date range on `UnifiedParseResult`, and a new stale-review sheet case in `UnifiedRosterImportView`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md

# Source files being modified
@Block-Time/Services/UnifiedRosterParser.swift
@Block-Time/Services/PlannedFlightService.swift
@Block-Time/Views/Screens/Settings/UnifiedRosterImportView.swift
@Block-Time/Views/Screens/Settings/UnifiedRosterPreviewView.swift

<interfaces>
<!-- Existing contracts the executor must use directly. Do NOT re-explore. -->

PlannedFlightService (existing, reuse):
```swift
func importFlights(_ parsedFlights: [RosterParserService.ParsedFlight]) async throws -> ImportResult
func isFlown(_ flight: FlightEntity) -> Bool   // returns true if blockTime/p1Time/p2Time logged. NEVER remove a flown flight.
private let databaseService = FlightDatabaseService.shared   // .viewContext is main-thread NSManagedObjectContext

struct ImportResult {
    let imported: Int
    let duplicates: Int
    let errors: Int
    let flights: [ImportedFlight]
    // ADD: let staleFlights: [FlightEntity]
}
```

UnifiedParseResult (existing, in UnifiedRosterParser.swift):
```swift
struct UnifiedParseResult {
    let flights: [UnifiedParsedFlight]   // each has .date (local Date), .flightNumber, .departureAirport, .arrivalAirport
    let pilotName: String
    let staffNumber: String
    let bidPeriod: String
    let base: String
    let category: String
    let rosterType: RosterType
    // ADD: let periodStartDate: Date?   // min of flights[].date
    // ADD: let periodEndDate: Date?     // max of flights[].date
}
```
NOTE: `UnifiedParseResult` is built in TWO places — `SHRosterParser.convertToUnified` and `LHRosterParser.convertToUnified`. Both initialisers must be updated.

FlightEntity (Core Data): `.date: Date?` (stored UTC), `.flightNumber: String?`, `.fromAirport: String?` (ICAO), `.toAirport: String?` (ICAO), `.blockTime/p1Time/p2Time: String?`, `.id: UUID?`.

AirportService.shared.convertToICAO(_ iata: String) -> String   // for matching roster IATA codes to stored ICAO.

Existing import flow in UnifiedRosterImportView:
- enum SheetType: Identifiable { case preview(...), case result(...) }
- importSelectedFlights(_ flights:) calls plannedFlightService.importFlights(...), then sets currentSheet = .result(importResult: result)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add bid-period date range to UnifiedParseResult</name>
  <files>Block-Time/Services/UnifiedRosterParser.swift</files>
  <action>
    Add two stored properties to `struct UnifiedParseResult`:
    `let periodStartDate: Date?` and `let periodEndDate: Date?`.

    Populate them in BOTH `SHRosterParser.convertToUnified(_:)` and `LHRosterParser.convertToUnified(_:)`.
    Compute from the mapped `flights` array (the local `flights` constant already built in each function):
    `periodStartDate: flights.map(\.date).min()`, `periodEndDate: flights.map(\.date).max()`.
    Both are nil when `flights` is empty (min()/max() on empty returns nil — correct).

    Do not change any other field or existing behaviour.
  </action>
  <verify>
    <automated>grep -n "periodStartDate" Block-Time/Services/UnifiedRosterParser.swift</automated>
  </verify>
  <done>UnifiedParseResult has periodStartDate/periodEndDate; both convertToUnified initialisers set them from flights.map(\.date).min()/.max().</done>
</task>

<task type="auto">
  <name>Task 2: Add findStaleFlights + stale deletion to PlannedFlightService</name>
  <files>Block-Time/Services/PlannedFlightService.swift</files>
  <action>
    1. Extend `struct ImportResult` with `let staleFlights: [FlightEntity]`. Update the single `ImportResult(...)` initialiser at the end of `importFlights` to pass `staleFlights: []` (stale detection is computed separately by the caller, not inside importFlights — keep importFlights behaviour unchanged otherwise).

    2. Add method:
    ```swift
    /// Find unflown logbook flights inside [start...end] (inclusive, by day) that are NOT in the new roster.
    /// Roster flights are matched by normalised flight number + ICAO route + same calendar day (UTC).
    func findStaleFlights(
        periodStart: Date,
        periodEnd: Date,
        rosterFlights: [RosterParserService.ParsedFlight]
    ) async -> [FlightEntity]
    ```
    Implementation, mirroring existing patterns in this file:
    - Run the fetch inside `databaseService.viewContext.perform { }` wrapped in `withCheckedContinuation` (Sendable-safe — access `AirportService.shared` and build the roster match-set inside the closure, like `findExistingFlights` does).
    - Expand `periodStart`/`periodEnd` to whole-day UTC bounds: predicate `date >= startOfDay(periodStart) AND date <= endOfDay(periodEnd)` using a `Calendar` with `TimeZone(secondsFromGMT: 0)`.
    - Fetch all `FlightEntity` in that window.
    - Build a Set of roster keys from `rosterFlights`: key = `"\(normaliseFlightNumber(flightNumber))|\(AirportService.shared.convertToICAO(departureAirport))|\(AirportService.shared.convertToICAO(arrivalAirport))|\(utcDayString)"`. Reuse the existing local→UTC date conversion logic already present in `isDuplicate`/`findExistingFlights` to derive the flight's stored UTC day (use `convertFromLocalToUTCDate` then format `dd/MM/yyyy`). Reuse the existing private `normaliseFlightNumber(_:)`.
    - For each fetched FlightEntity, build the same key from its `.flightNumber`/`.fromAirport`/`.toAirport`/`.date` (date already UTC → format day with UTC formatter). A flight is STALE if its key is NOT in the roster key set.
    - EXCLUDE any flight where `isFlown(flight)` returns true — never offer a flown flight for removal. Apply this filter regardless of key match.
    - Return the stale FlightEntity array sorted by `.date` ascending.

    3. Add deletion helper:
    ```swift
    /// Delete the given stale flight entities from the logbook. Returns count deleted.
    @discardableResult
    func deleteStaleFlights(_ flights: [FlightEntity]) async -> Int
    ```
    Implement via `databaseService.viewContext.perform { }` + `withCheckedContinuation`: collect the objectIDs / re-fetch by `id`, `context.delete(...)` each, `try? context.save()`, return count. (Direct FlightEntity deletion through the context — do not route through FlightSector-based deleteFlights since these are FlightEntity objects.)

    Do not remove or alter any existing method or behaviour.
  </action>
  <verify>
    <automated>grep -n "func findStaleFlights\|func deleteStaleFlights\|staleFlights" Block-Time/Services/PlannedFlightService.swift</automated>
  </verify>
  <done>findStaleFlights returns unflown out-of-roster in-window flights (flown always excluded); deleteStaleFlights removes given entities; ImportResult carries staleFlights.</done>
</task>

<task type="auto">
  <name>Task 3: Insert stale-review interstitial sheet in UnifiedRosterImportView</name>
  <files>Block-Time/Views/Screens/Settings/UnifiedRosterImportView.swift</files>
  <action>
    Wire the flow: Preview -> import -> [if stale flights] StaleReview sheet -> delete selected -> Result. If no stale flights, go straight to Result (current behaviour).

    1. Add a `SheetType` case:
    `case staleReview(staleFlights: [FlightEntity], importResult: PlannedFlightService.ImportResult)`
    Give it an `id` (e.g. "staleReview").

    2. In `importSelectedFlights(_:)`, after `let result = try await plannedFlightService.importFlights(convertedFlights)` and BEFORE showing the result:
       - Capture the parse result's period range. `importSelectedFlights` currently only receives `[UnifiedParsedFlight]`; thread the `UnifiedParseResult` through. Change the `.preview` onImport closure to also pass the `parseResult` (capture it from the existing `case .preview(let parseResult, ...)` binding), and update `importSelectedFlights` signature to `importSelectedFlights(_ flights: [UnifiedParsedFlight], parseResult: UnifiedParseResult)`.
       - Guard `let start = parseResult.periodStartDate, let end = parseResult.periodEndDate` (else skip stale step).
       - Call `let stale = await plannedFlightService.findStaleFlights(periodStart: start, periodEnd: end, rosterFlights: convertedFlights)`.
       - On `MainActor`: if `stale.isEmpty` -> `currentSheet = .result(importResult: result)` (unchanged path). Else -> `currentSheet = .staleReview(staleFlights: stale, importResult: result)`.

    3. In the `.sheet(item:)` switch, add the `.staleReview` case rendering a new `StaleFlightReviewView` (define it in this file, file-private struct):
       - Inputs: `staleFlights: [FlightEntity]`, `onContinue: (_ toDelete: [FlightEntity]) -> Void`, `onSkip: () -> Void`.
       - NavigationStack, title "Review Removals", inline.
       - Header explanation text: "These flights are no longer in your latest roster. Remove the ones you did not fly." (no emoji).
       - An ImportStatCard-style count card showing the stale count (reuse the existing `ImportStatCard` style — same struct is private in this file; you may reuse it directly).
       - Scrollable list: each stale flight as a row matching `FlightSummaryRow`/`UnifiedFlightPreviewRow` style (checkmark.circle.fill / circle toggle, QF + flightNumber, route fromAirport -> toAirport, date). Default ALL selected (remove). Tapping toggles a `Set<UUID>` keyed by `flight.id`.
       - Use `RoundedRectangle(cornerRadius: 5)` for any badge pill (not Capsule).
       - Bottom bar: primary "Continue" button -> `onContinue(selectedEntities)`; a secondary "Skip" (topBarLeading or text button) -> `onSkip()` (deletes nothing).
       - Build rows via a `private func` returning the view to avoid @ViewBuilder type-check timeouts.

    4. In the import view, handle the sheet callbacks:
       - `onContinue: { toDelete in currentSheet = nil; Task { await plannedFlightService.deleteStaleFlights(toDelete); await MainActor.run { currentSheet = .result(importResult: importResult) } } }`
       - `onSkip: { currentSheet = .result(importResult: importResult) }`
       (Add the same ~0.6s settle sleep used elsewhere if a sheet-swap glitch appears; match the existing `importSelectedFlights` Task.sleep approach.)

    Do not remove or change any existing feature, button, or the no-stale-flights fast path.
  </action>
  <verify>
    <automated>grep -n "case staleReview\|StaleFlightReviewView\|findStaleFlights\|deleteStaleFlights" Block-Time/Views/Screens/Settings/UnifiedRosterImportView.swift</automated>
  </verify>
  <done>Importing a roster with stale flights shows the review sheet (all toggled to remove); deselecting keeps a flight; Continue deletes only selected then shows result; zero stale flights skips straight to result; flown flights never appear.</done>
</task>

</tasks>

<verification>
- `grep -n "periodStartDate" Block-Time/Services/UnifiedRosterParser.swift` shows both parsers populated.
- `grep -n "func findStaleFlights\|func deleteStaleFlights" Block-Time/Services/PlannedFlightService.swift` present.
- `grep -n "case staleReview" Block-Time/Views/Screens/Settings/UnifiedRosterImportView.swift` present.
- Manual: import a roster after deleting one trip from it — stale sheet appears with that trip, default selected; flown flights absent. Build locally (Nelson builds).
</verification>

<success_criteria>
- Stale = unflown logbook flight in [periodStart...periodEnd] not in new roster; flown flights never included.
- Date range derived from min/max of roster flight dates.
- Zero stale flights -> straight to result, no extra sheet.
- Stale flights default selected; only selected deleted on Continue; Skip deletes none.
- Style matches existing rows/cards; cornerRadius 5 badges; no emoji; Swift 6 async/await + @MainActor.
- No existing feature/behaviour removed.
</success_criteria>

<output>
After completion, create `.planning/quick/260608-ptl-implement-stale-roster-flight-removal-wi/260608-ptl-SUMMARY.md`
</output>
