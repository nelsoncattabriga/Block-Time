---
phase: quick-260603-tmj
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Services/CalendarExportSettings.swift
  - Block-Time/Services/CalendarExportService.swift
  - Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift
  - Block-Time/Views/Screens/Settings/CalendarExportView.swift
autonomous: true
requirements: [CAL-EXPORT-CUSTOM]

must_haves:
  truths:
    - "User can choose export mode: all-day only, sectors only, or both"
    - "User can reorder and toggle which components appear in all-day event titles"
    - "User can reorder and toggle which components appear in sector event titles"
    - "Format choices persist across app launches"
    - "Live previews show how titles will render with placeholder data"
    - "Generated .ics reflects the chosen mode and component order"
    - "Positioning (PAX) flights show a PAX indicator in titles"
  artifacts:
    - path: "Block-Time/Services/CalendarExportSettings.swift"
      provides: "@Observable settings model with UserDefaults-backed JSON component arrays, export mode, enums"
      contains: "CalendarExportMode"
    - path: "Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift"
      provides: "Format customisation sheet with mode picker, two reorderable component lists, live previews"
      contains: "CalendarFormatSheet"
    - path: "Block-Time/Services/CalendarExportService.swift"
      provides: "generateICS(from:settings:) with title builders for sector and all-day events grouped by date"
      contains: "buildSectorTitle"
    - path: "Block-Time/Views/Screens/Settings/CalendarExportView.swift"
      provides: "Customise button + sheet presentation; passes settings to export; mode-aware count subtitle"
      contains: "showFormatSheet"
  key_links:
    - from: "CalendarFormatSheet"
      to: "CalendarExportSettings"
      via: "@Bindable binding to shared @Observable settings"
      pattern: "@Bindable.*settings"
    - from: "CalendarExportView.export"
      to: "CalendarExportService.generateICS"
      via: "passes settings argument"
      pattern: "generateICS\\(from:.*settings:"
    - from: "CalendarExportService.buildSectorTitle"
      to: "FlightSector.isPositioning"
      via: "PAX indicator gated on isPositioning"
      pattern: "isPositioning"
---

<objective>
Add calendar export customisation: let the user choose what appears in exported calendar
event titles and in what order, choose between all-day duty events, individual sector
events, or both, and persist those choices.

Purpose: Different pilots want different calendar detail. Some want one all-day block per
duty day; others want a separate event per sector. This makes the export format
user-configurable instead of the current fixed "FN FROM -> TO" per-flight title.

Output: New CalendarExportSettings model + CalendarFormatSheet UI, rewritten
CalendarExportService title/event builders, and CalendarExportView wired to the new sheet
and settings.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@Block-Time/Services/CalendarExportService.swift
@Block-Time/Views/Screens/Settings/CalendarExportView.swift

<interfaces>
FlightSector relevant fields (from Block-Time/Models/FlightLogbook.swift):

```swift
struct FlightSector: Identifiable, Codable, Hashable {
    let id: UUID
    var date: String            // "dd/MM/yyyy" (UTC)
    var flightNumber: String
    var fromAirport: String
    var toAirport: String
    var isPositioning: Bool     // true => PAX flight
    var outTime: String         // "HH:MM" (colon) actual gate out, may be ""
    var inTime: String          // "HH:MM" (colon) actual gate in, may be ""
    var scheduledDeparture: String  // STD - stored in HHMM format (NO colon), may be ""
    var scheduledArrival: String    // STA - stored in HHMM format (NO colon), may be ""
}
```

FlightSector init (required fields, from Models/FlightLogbook.swift) - other params have
defaults: id, date, flightNumber, aircraftReg, aircraftType, fromAirport, toAirport,
captainName, foName, blockTime, nightTime, p1Time, instrumentTime, simTime, isPilotFlying.
Optional with defaults includes: isPositioning, scheduledDeparture, scheduledArrival,
outTime, inTime. Pass "0.0"/"" for irrelevant fields.

FORMAT NOTE (critical):
- outTime/inTime are "HH:MM" (colon, count 5). The existing firstNonEmpty() helper checks
  for ':' and count==5.
- scheduledDeparture/scheduledArrival are HHMM (no colon). To display "HH:MM" you must
  insert the colon yourself. To display "HHmm" use as-is (or strip colon from outTime).

CalendarExportService existing helpers to REUSE (do not rewrite):
resolveTimes(for:), parseFlightDate(_:), allDayString(_:), utcDateTimeString(date:hhmm:),
iCalTimestamp(_:), icsEscape(_:), flightDateFormatter, firstNonEmpty(...).

CalendarExportViewModel.export() currently calls:
CalendarExportService.shared.generateICS(from: flights).
CalendarExportFlightCountCard shows a fixed inflected "N flights" subtitle.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create CalendarExportSettings model</name>
  <files>Block-Time/Services/CalendarExportSettings.swift</files>
  <action>
Create a new file with the settings model and supporting enums.

Define enums exactly as specified:
- enum CalendarExportMode: String, CaseIterable { case allDayOnly, sectorsOnly, both }
  Add a displayName: allDayOnly = "All-day only", sectorsOnly = "Individual sectors",
  both = "Both".
- enum AllDayComponent: String, CaseIterable, Identifiable
  { case firstSTD, route, lastSTA, flightNumbers }, var id: String { rawValue }.
  Add displayName (firstSTD = "First STD (0900)", route = "Route (BNE -> SYD)",
  lastSTA = "Last STA (1700)", flightNumbers = "Flight numbers in route").
- enum SectorComponent: String, CaseIterable, Identifiable
  { case std, flightNumber, from, to, sta, paxIndicator }, var id: String { rawValue }.
  Add displayName (std = "STD (09:00)", flightNumber = "Flight number",
  from = "From (BNE)", to = "To (SYD)", sta = "STA (11:30)", paxIndicator = "PAX indicator").

Persist order + enabled flag. Generics over RawRepresentable can cause Codable friction,
so prefer a simple per-list Codable struct stored as JSON and mapped to/from the enum:
```swift
struct OrderedComponent: Codable, Identifiable {
    var rawValue: String
    var enabled: Bool
    var id: String { rawValue }
}
```
Pick whatever compiles cleanly and keep it simple.

Create @Observable @MainActor final class CalendarExportSettings:
- static let shared = CalendarExportSettings() (singleton, parallels other services).
- @AppStorage cannot store arrays directly. Use plain stored properties with didSet that
  write JSON to UserDefaults.standard under keys:
  "CalendarExport.mode", "CalendarExport.allDayComponents", "CalendarExport.sectorComponents".
  Load them in init with sensible defaults if absent.
- var mode: CalendarExportMode
- var allDayComponents: [OrderedComponent]  (ordered)
- var sectorComponents: [OrderedComponent]  (ordered)

Sensible defaults:
- mode = .both
- allDayComponents order: firstSTD(true), route(true), lastSTA(true), flightNumbers(false)
- sectorComponents order: std(true), flightNumber(true), from(true), to(true), sta(true),
  paxIndicator(true)

Defaults must MERGE with persisted data: if a new component case is added later, append any
missing cases (disabled) so each list always contains every enum case exactly once, and
drop any unknown rawValues.

Add convenience:
- func enabledAllDay() -> [AllDayComponent] returns enabled components in order.
- func enabledSector() -> [SectorComponent] returns enabled components in order.

Swift 6 strict concurrency: mark the class @MainActor. No emoji. No Font.system.
  </action>
  <verify>
    <automated>test -f Block-Time/Services/CalendarExportSettings.swift && grep -q "CalendarExportMode" Block-Time/Services/CalendarExportSettings.swift && grep -q "@Observable" Block-Time/Services/CalendarExportSettings.swift && grep -q "enabledSector" Block-Time/Services/CalendarExportSettings.swift</automated>
  </verify>
  <done>File exists; defines the three enums, the persisted settings class with shared singleton, JSON-backed persistence, default merging, and enabled* helpers. Nelson confirms it compiles.</done>
</task>

<task type="auto">
  <name>Task 2: Rewrite CalendarExportService with settings-driven title builders</name>
  <files>Block-Time/Services/CalendarExportService.swift</files>
  <action>
Change the public signature to:
func generateICS(from flights: [FlightSector], settings: CalendarExportSettings) -> String

Keep ALL existing private helpers (resolveTimes, parseFlightDate, allDayString,
utcDateTimeString, iCalTimestamp, icsEscape, firstNonEmpty, formatters). Do NOT remove
existing behaviour - only the title source and the event loop change.

Main loop:
1. Build calendar header (unchanged).
2. Group flights by flight.date (dd/MM/yyyy string), preserving day order: sort dates
   chronologically via flightDateFormatter; within a day sort by STD/OUT ascending.
3. For each day:
   - if mode is .allDayOnly or .both: append buildDailyEvent(date:flights:settings:)
   - if mode is .sectorsOnly or .both: append buildSectorEvent(for:settings:) for each
     flight in that day.
4. Append END:VCALENDAR (unchanged).

Add a private helper hhmmToColon(_ s: String) -> String? that turns "0900" into "09:00"
(guard 4 digits). Add hhmmStripColon(_ s: String) -> String to turn "09:00"/"0900" into
"0900". Reuse these for std/sta/firstSTD/lastSTA.

func buildSectorTitle(for flight: FlightSector, settings: CalendarExportSettings) -> String
- Iterate settings.enabledSector() in order, building an ordered token list:
  - std: STD as "HH:MM" from scheduledDeparture (HHMM, insert colon); fall back to outTime
    (already HH:MM). Skip token if both empty.
  - flightNumber: flight.flightNumber (skip if empty).
  - from: flight.fromAirport.
  - to: flight.toAirport.
  - sta: STA as "HH:MM" from scheduledArrival (HHMM->colon); fall back to inTime. Skip if both empty.
  - paxIndicator: only if flight.isPositioning -> "PAX". If flightNumber is also enabled and
    present, "PAX" must sit immediately before the flight number ("PAX QF123"); otherwise
    render "PAX" standalone at its ordered position.
- After building tokens, collapse adjacent enabled from/to into "FROM -> TO" when both are
  enabled and present. Join remaining tokens with spaces. Trim.

func buildDailyTitle(for flights: [FlightSector], settings: CalendarExportSettings) -> String
- flights are one day's sectors, sorted by STD ascending.
- Iterate settings.enabledAllDay() in order, producing top-level tokens:
  - firstSTD: earliest STD (scheduledDeparture, fall back outTime) formatted "HHmm" no colon
    (e.g. "0900").
  - route: airport chain in STD order - from[0] -> to[0] -> to[1] ... deduping consecutive
    equal codes (BNE -> SYD -> MEL -> BNE). When flightNumbers is ALSO enabled, insert each
    sector's flight number before its departure airport segment:
    "QF101 BNE -> SYD -> QF203 MEL -> BNE". Positioning sectors prefix the flight number
    with "PAX " (e.g. "PAX QF101").
  - lastSTA: latest STA (scheduledArrival, fall back inTime) formatted "HHmm".
  - flightNumbers: route content is annotated within the route token. If route is DISABLED
    but flightNumbers enabled, emit the annotated route chain here instead. Never duplicate
    the route when both are enabled.
- Join top-level tokens with spaces. Trim.

private func buildSectorEvent(for flight: FlightSector, settings:) -> [String]?
- Mirror the existing buildEvent: resolveTimes(for:) for DTSTART/DTEND/all-day,
  UID = flight.id.uuidString + "@block-time-sector", SUMMARY = icsEscape(buildSectorTitle),
  DTSTAMP = now. Return nil if times unresolved (same guard as before).

private func buildDailyEvent(date: String, flights: [FlightSector], settings:) -> [String]?
- Parse date via parseFlightDate. Produce an ALL-DAY VEVENT:
  DTSTART;VALUE=DATE:<allDayString(date)>, DTEND;VALUE=DATE:<allDayString(date + 1 day)>.
  UID = "<yyyymmdd>@block-time-daily", SUMMARY = icsEscape(buildDailyTitle), DTSTAMP = now.
  Return nil if date unparseable.

The old private buildEvent(for:) and eventTitle(for:) may be removed ONLY because they are
internal helpers fully replaced by the new builders and the only caller (the viewModel) is
updated in Task 4. Do NOT remove resolveTimes or any date/time helper. eventDescription was
already empty/unused - leaving or removing it is fine.

Swift 6 strict concurrency: builders are pure and synchronous. If settings access forces
@MainActor, mark generateICS and helpers @MainActor (the calling viewModel is already
@MainActor). No emoji.
  </action>
  <verify>
    <automated>grep -q "settings: CalendarExportSettings" Block-Time/Services/CalendarExportService.swift && grep -q "func buildSectorTitle" Block-Time/Services/CalendarExportService.swift && grep -q "func buildDailyTitle" Block-Time/Services/CalendarExportService.swift && grep -q "buildDailyEvent" Block-Time/Services/CalendarExportService.swift</automated>
  </verify>
  <done>generateICS takes settings; groups flights by day; emits all-day and/or sector events per mode; PAX indicator gated on isPositioning; std/sta rendered "HH:MM", firstSTD/lastSTA "HHmm"; existing time/date helpers preserved. Nelson confirms it compiles.</done>
</task>

<task type="auto">
  <name>Task 3: Create CalendarFormatSheet with mode picker, reorderable lists, live previews</name>
  <files>Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift</files>
  <action>
Create struct CalendarFormatSheet: View. Inject the settings:
@Bindable var settings: CalendarExportSettings (passed in from CalendarExportView using the
shared singleton). @Environment(\.dismiss) private var dismiss.
@Environment(ThemeService.self) private var themeService.

Wrap in NavigationStack, navigationTitle "Event Format", inline display mode, Done button
(.topBarTrailing) calling dismiss(). Use a List with sections so .onMove works.

Section 1 - Export Mode:
- Header "Export Mode".
- Segmented Picker bound to $settings.mode over CalendarExportMode.allCases, label =
  displayName (.pickerStyle(.segmented)).

Section 2 - All-day event format:
- Header "All-day event format".
- Live preview row at the top: a single Text rendering
  CalendarExportService.shared.buildDailyTitle(for: Self.placeholderDuty, settings: settings).
  .font(.subheadline).fontWeight(.medium).lineLimit(1).minimumScaleFactor(0.7). Wrap in a
  RoundedRectangle(cornerRadius: 5) tinted background pill.
- ForEach over $settings.allDayComponents with a Toggle per row (label = displayName for the
  matching enum case) bound to the row's enabled flag. Add .onMove to reorder
  allDayComponents. Match the existing reorder pattern used in InlineCustomFieldsView in this
  codebase (List + .onMove, EditButton if required for drag handles).

Section 3 - Individual sector format (ONLY when settings.mode != .allDayOnly):
- Header "Individual sector format".
- Live preview Text rendering
  CalendarExportService.shared.buildSectorTitle(for: Self.placeholderSector, settings: settings)
  with same styling/pill as Section 2.
- ForEach over $settings.sectorComponents with Toggle per row + .onMove.

Placeholder data (static lets in the sheet, using the FlightSector init - see interfaces):
- placeholderSector: QF123 BNE->SYD, scheduledDeparture "0900", scheduledArrival "1130",
  isPositioning false.
- placeholderDuty: two FlightSectors on the same date:
  (1) QF101 BNE->SYD, scheduledDeparture "0900", isPositioning true (PAX example),
  (2) QF203 SYD->MEL, scheduledDeparture "1200", scheduledArrival "1700", isPositioning false.
  Pass "0.0"/"" for time/name fields not relevant.

Previews recompute reactively because settings is @Observable and read in body via
build*Title - reorder/toggle/mode changes re-render automatically.

To map an OrderedComponent row back to displayName: look up the enum case by rawValue
(AllDayComponent(rawValue:) / SectorComponent(rawValue:)) and use its displayName.

Styling: semantic fonts only, no Font.system, no emoji, RoundedRectangle(cornerRadius: 5)
for the preview pill, Toggle tint .purple to match the export screen. Add a #Preview
injecting .environment(ThemeService.shared) and CalendarExportSettings.shared.
  </action>
  <verify>
    <automated>test -f Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift && grep -q "struct CalendarFormatSheet" Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift && grep -q "onMove" Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift && grep -q "buildDailyTitle" Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift && grep -q "buildSectorTitle" Block-Time/Views/Screens/Settings/CalendarFormatSheet.swift</automated>
  </verify>
  <done>Sheet exists with mode segmented picker, two reorderable+toggleable component lists, live previews above each list, Section 3 hidden when mode is allDayOnly, Done dismisses. Nelson confirms it compiles and previews correctly.</done>
</task>

<task type="auto">
  <name>Task 4: Wire CalendarExportView to the format sheet and settings</name>
  <files>Block-Time/Views/Screens/Settings/CalendarExportView.swift</files>
  <action>
In CalendarExportView:
- Add @State private var showFormatSheet = false.
- Add a reference to settings: let settings = CalendarExportSettings.shared (or read via the
  shared singleton directly where needed).
- Add a toolbar button with the SF Symbol "slider.horizontal.3" as a SECOND .topBarLeading
  item (after Cancel): Button { showFormatSheet = true } label: { Image(systemName: "slider.horizontal.3") }.
- Present the sheet: .sheet(isPresented: $showFormatSheet) {
      CalendarFormatSheet(settings: CalendarExportSettings.shared)
          .environment(themeService)
  }
  Add appropriate presentation detents only if needed; otherwise full sheet.

In CalendarExportViewModel.export():
- Change the generateICS call to:
  let icsContent = CalendarExportService.shared.generateICS(from: flights, settings: CalendarExportSettings.shared)
  (viewModel is @MainActor so accessing the @MainActor settings singleton is fine.)

Mode-aware count subtitle in CalendarExportFlightCountCard:
- The card currently shows fixed inflected "N flights" + "Each flight becomes one calendar
  event". Make the subtitle reflect CalendarExportSettings.shared.mode:
  - allDayOnly: "<dutyDays> duty days will be exported as all-day events"
  - sectorsOnly: "<flightCount> sector events will be exported"
  - both: "<dutyDays> duty days + <flightCount> sector events"
- dutyDays = number of distinct flight dates among the filtered flights. Add a computed
  property dutyDayCount on the viewModel that groups the filtered flights by date and counts
  distinct days (reuse filteredFlights()). Update it in refreshCount() alongside flightCount,
  and add an onChange so the subtitle updates when the mode changes (the sheet mutates the
  shared settings; add .onChange(of: CalendarExportSettings.shared.mode) or recompute on
  sheet dismiss to refresh the card). Pass mode into the card or read the shared singleton
  inside it.

Preserve all existing behaviour: Cancel, Export button, filter card, date rows, share sheet,
error alert, unflown selection. Do not remove any existing feature.

Styling: keep existing card styles, semantic fonts, no emoji.
  </action>
  <verify>
    <automated>grep -q "showFormatSheet" Block-Time/Views/Screens/Settings/CalendarExportView.swift && grep -q "CalendarFormatSheet" Block-Time/Views/Screens/Settings/CalendarExportView.swift && grep -q "generateICS(from: flights, settings:" Block-Time/Views/Screens/Settings/CalendarExportView.swift && grep -q "slider.horizontal.3" Block-Time/Views/Screens/Settings/CalendarExportView.swift</automated>
  </verify>
  <done>Customise (sliders) button opens CalendarFormatSheet; export passes settings; count card subtitle reflects mode (duty days / sectors / both); existing features intact. Nelson confirms it compiles and runs.</done>
</task>

</tasks>

<verification>
- CalendarExportSettings persists mode + component order/enabled across launches (UserDefaults JSON).
- generateICS honours mode: all-day only, sectors only, or both; events grouped by duty day.
- Sector titles render enabled components in stored order; PAX only on isPositioning flights.
- All-day titles render firstSTD ("HHmm"), route chain with optional inline flight numbers, lastSTA ("HHmm").
- Format sheet lists are drag-reorderable and toggleable, with live previews that update reactively.
- Section 3 hidden when mode is allDayOnly. Count card subtitle matches selected mode.
- No existing CalendarExportView feature removed.
</verification>

<success_criteria>
- Four files created/updated as listed in files_modified.
- buildSectorTitle and buildDailyTitle produce correct strings for the documented placeholder data.
- std/sta display "HH:MM"; firstSTD/lastSTA display "HHmm"; from/to collapse to "FROM -> TO".
- Settings survive an app relaunch.
- Project compiles under Swift 6 strict concurrency (Nelson builds locally).
</success_criteria>

<output>
After completion, create `.planning/quick/260603-tmj-implement-calendar-export-customisation-/260603-tmj-SUMMARY.md`
</output>
