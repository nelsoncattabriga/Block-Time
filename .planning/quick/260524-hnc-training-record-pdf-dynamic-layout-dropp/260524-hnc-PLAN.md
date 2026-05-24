---
phase: quick-260524-hnc
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Block-Time/Services/LogbookPDFLayout.swift
  - Block-Time/Services/LogbookPDFTotals.swift
  - Block-Time/Services/LogbookPDFPageDrawer.swift
  - Block-Time/Services/LogbookPDFRenderer.swift
  - Block-Time/Views/Screens/Settings/LogbookPDFExportView.swift
autonomous: true
requirements: [TRPDF-01]
must_haves:
  truths:
    - "Training Record PDF drops CAPT and F/O crew columns"
    - "Training Record PDF can show 0–7 user-selected custom field columns"
    - "Remarks column width shrinks as more custom fields are added"
    - "Numeric custom fields total in the footer; text custom fields do not"
    - "Standard mode PDF output is byte-for-byte unchanged"
    - "User selects which custom fields appear, capped at 7, persisted across launches"
  artifacts:
    - path: "Block-Time/Services/LogbookPDFLayout.swift"
      provides: "trainingRecordColumns(customFields:) factory + columnOffsets(for:) + groupGeometry(for:in:)"
      contains: "trainingRecordColumns"
    - path: "Block-Time/Services/LogbookPDFPageDrawer.swift"
      provides: "Drawer rendering custom cells using injected columns/offsets"
      contains: "customFields"
    - path: "Block-Time/Services/LogbookPDFTotals.swift"
      provides: "PageTotals.customTotals accumulation"
      contains: "customTotals"
    - path: "Block-Time/Views/Screens/Settings/LogbookPDFExportView.swift"
      provides: "Custom field picker UI (Training Record mode)"
      contains: "logbookPDFTrainingCustomFields"
  key_links:
    - from: "LogbookPDFExportView.generatePDF"
      to: "LogbookPDFRenderer.render"
      via: "customFields parameter"
      pattern: "customFields:"
    - from: "LogbookPDFRenderer.render"
      to: "LogbookPDFPageDrawer"
      via: "columns + columnOffsets + customFields injection"
      pattern: "columns:|columnOffsets:|customFields:"
---

<objective>
Add a Training Record PDF variant that drops the CAPT/F/O crew columns and lets the user add up to 7 of their defined custom fields as columns, with the Remarks column shrinking to fit. Standard mode output must remain completely unchanged.

Purpose: Training Record exports are used for instructor/check records where crew names are irrelevant but custom training metrics (e.g. assessment counters) matter.
Output: Dynamic Training Record column layout, custom-cell rendering, custom-field totals in footer, and a custom-field picker in the export UI.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

@Block-Time/Services/LogbookPDFLayout.swift
@Block-Time/Services/LogbookPDFRenderer.swift
@Block-Time/Services/LogbookPDFTotals.swift
@Block-Time/Services/LogbookPDFPageDrawer.swift
@Block-Time/Views/Screens/Settings/LogbookPDFExportView.swift
@Block-Time/Models/CustomCounterDefinition.swift
@Block-Time/Services/CustomCounterService.swift
@Block-Time/Models/FlightLogbook.swift

<interfaces>
<!-- Contracts the executor needs. Use directly — no codebase exploration. -->

ColumnDef (LogbookPDFLayout.swift):
```swift
struct ColumnDef { let id: Int; let title: String; let width: CGFloat; let alignment: NSTextAlignment; let group: ColumnGroup }
enum ColumnGroup: String { case date, aircraft, crew, route, remarks, time }
```

Existing fixed columns (Standard) and their widths:
DATE 46(.date), TYPE 36 / REG 36(.aircraft), CAPT 85 / F/O 85(.crew), FLT# 30 / FROM 34 / TO 34(.route), REMARKS 176(.remarks), BLOCK 32 / NIGHT 32 / P1 30 / ICUS 30 / P2 30 / INST 30 / SIM 30 / TRNG 30(.time). contentWidth = 806, marginH = 18.

CustomCounterDefinition (CustomCounterDefinition.swift):
```swift
struct CustomCounterDefinition: Codable, Identifiable, Hashable {
    let columnIndex: Int   // 1–10
    var label: String
    var type: CounterType  // .time | .decimal | .integer | .text
    var showTotal: Bool
}
```

FlightSector custom values (FlightLogbook.swift):
```swift
var counterEntries: [Int: String] = [:]   // columnIndex → raw string value
static func hhmmToDecimal(_ s: String) -> Double?
```

CustomCounterService (MainActor):
```swift
CustomCounterService.shared.definitions  // [CustomCounterDefinition]
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add Training Record column factory + dynamic geometry helpers to LogbookPDFLayout</name>
  <files>Block-Time/Services/LogbookPDFLayout.swift</files>
  <action>
Add the dynamic layout contracts WITHOUT touching existing `columns`, `columnOffsets`, or `groupGeometry(for:)` (Standard mode must stay identical).

1. Add a new static factory:
```swift
static nonisolated func trainingRecordColumns(customFields: [CustomCounterDefinition]) -> [ColumnDef]
```
- Cap custom fields at 7 (use `customFields.prefix(7)`).
- Fixed Training Record columns (NO crew): DATE 46(.date), TYPE 36 / REG 36(.aircraft), FLT# 30 / FROM 34 / TO 34(.route), TRNG 30(.time, id 16). Fixed non-remarks total = 246pt.
- Custom field columns: one ColumnDef per custom field, width 44, alignment .center, group .time (per key_context: reuse .time group for vertical-line treatment). Assign id = 100 + arrayIndex (100, 101, …) so they never collide with 0–16. Title = the definition's label (uppercased to match header style). Keep a stable mapping from column id → CustomCounterDefinition.columnIndex (id 100+n maps to customFields[n]); the drawer/totals will need columnIndex, so the simplest stable rule is id = 100 + n and the nth element of the passed customFields array. Document this rule in a comment.
- Remarks width = 560 - (customCount * 44), group .remarks, id 8, alignment .left.
- Column ORDER in returned array: DATE, TYPE, REG, FLT#, FROM, TO, REMARKS, then custom fields, then TRNG. (Remarks before the .time group, matching Standard where remarks precedes times.)

2. Add a non-cached offsets function (factory companion to the cached `columnOffsets`):
```swift
static nonisolated func columnOffsets(for columns: [ColumnDef]) -> [Int: CGFloat]
```
Iterate the passed columns in array order accumulating x from `marginH`. Do NOT modify the existing cached `columnOffsets` property.

3. Add a groupGeometry overload that accepts a column array + its offsets:
```swift
static nonisolated func groupGeometry(for group: ColumnGroup, in columns: [ColumnDef], offsets: [Int: CGFloat]) -> (x: CGFloat, width: CGFloat)
```
Mirror the existing implementation but operate on the passed arrays/dict instead of the statics. Leave the existing `groupGeometry(for:)` untouched.

Note: groupOrder for Training Record is the same enum order [.date,.aircraft,.crew,.route,.remarks,.time]; the .crew group simply has zero columns so it contributes nothing — that's fine, but the drawer must skip groups with zero columns (handled in Task 2).
  </action>
  <verify>
    <automated>MISSING — no test target; verify by code inspection + local build. Confirm `LogbookPDFLayout.trainingRecordColumns`, `columnOffsets(for:)`, and `groupGeometry(for:in:offsets:)` exist and existing `columns`/`columnOffsets` are unchanged.</automated>
  </verify>
  <done>trainingRecordColumns(customFields:) returns 7 fixed columns + N custom (≤7) + dynamically-sized Remarks; helper offsets/groupGeometry functions accept arrays; existing Standard statics untouched.</done>
</task>

<task type="auto">
  <name>Task 2: Inject columns/offsets/customFields into LogbookPDFPageDrawer and render custom cells</name>
  <files>Block-Time/Services/LogbookPDFPageDrawer.swift</files>
  <action>
Make `LogbookPDFPageDrawer` operate on injected layout instead of reading `L.columns` / `L.columnOffsets` directly. Do NOT change `LogbookPDFCoverDrawer`.

1. Add stored properties to `LogbookPDFPageDrawer`:
```swift
let columns: [ColumnDef]
let columnOffsets: [Int: CGFloat]
let customFields: [CustomCounterDefinition]
```
For Standard callers these will be passed `LogbookPDFLayout.columns` / `LogbookPDFLayout.columnOffsets` / `[]` (wired in Task 4), so behaviour is byte-identical.

2. Replace every `L.columns` with `self.columns` and every `L.columnOffsets` with `self.columnOffsets` throughout the struct (drawColumnHeaders, drawFlightRow's `cellRect`, drawFooter, drawGridLines). Keep all other `L.` constants (fonts, colours, geometry) as-is.

3. Replace `L.groupGeometry(for: group)` calls with `L.groupGeometry(for: group, in: columns, offsets: columnOffsets)`.

4. In header + grid drawing loops over `L.groupOrder`, SKIP any group whose geometry width is 0 (empty .crew group in Training Record). Add `guard geo.width > 0 else { continue }`.

5. Custom cell rendering in `drawFlightRow`: after the existing time-columns loop, render custom field columns. For each column in `columns` with `id >= 100`:
   - Map id → definition: `let n = col.id - 100; guard n < customFields.count else { continue }; let def = customFields[n]`.
   - Look up `flight.counterEntries[def.columnIndex]` (raw string). If nil/empty, skip (blank cell).
   - Draw the raw string value via `drawTextVCentred` using `cellRect(col.id)`, `L.fontDataCell`, `L.bodyText`, alignment `.center`.
   Note: `cellRect` currently looks up `L.columns.first(where:)` — after step 2 it uses `self.columns`, so custom columns resolve correctly.

6. Footer: the loop `for colId in 9...16` must become a loop over the time-group columns actually present. Replace with iterating `columns.filter { $0.group == .time }` and using each col's id. The footer value for a column comes from `row.totals.formattedValue(...)` (extended in Task 3 to handle custom ids). Keep the existing label-area / box geometry but base `col9X` on the FIRST .time-group column's offset rather than hardcoded id 9 — in Training Record the first time column is a custom field (id 100) or TRNG (id 16) if zero custom fields. Compute: `let firstTimeCol = columns.first(where: { $0.group == .time }); let col9X = columnOffsets[firstTimeCol?.id ?? 9]`. Use this same firstTimeCol id everywhere the footer/grid currently hardcodes `9` (footer box left, internal footer dividers).

7. `mergedHeaderGroups` stays `[.date, .remarks]` — unchanged. Custom fields live in `.time` group so they get leaf headers and vertical dividers automatically.
  </action>
  <verify>
    <automated>MISSING — verify by inspection + local build. Confirm no remaining `L.columns`/`L.columnOffsets` references in LogbookPDFPageDrawer (cover drawer excepted), custom id>=100 cells render counterEntries values, zero-width groups skipped.</automated>
  </verify>
  <done>Drawer renders any injected column set; custom columns (id≥100) show raw counterEntries values; empty crew group produces no artifacts; footer/grid derive the time-group start dynamically instead of hardcoding id 9.</done>
</task>

<task type="auto">
  <name>Task 3: Add custom-field accumulation + formatting to PageTotals</name>
  <files>Block-Time/Services/LogbookPDFTotals.swift</files>
  <action>
Extend `PageTotals` to carry custom-field totals keyed by the definition's `columnIndex`. Standard mode must be unaffected (customTotals stays empty).

1. Add stored property:
```swift
var customTotals: [Int: Double] = [:]   // keyed by CustomCounterDefinition.columnIndex
```
Add it to the memberwise-style `init` with a default of `[:]` so existing call sites compile unchanged.

2. Extend the `+` operator to merge customTotals (sum values per key, union of keys).

3. Add an overloaded accumulate (do NOT break the existing `accumulate(_:)` — keep it; Standard pagination uses it):
```swift
nonisolated mutating func accumulate(_ flight: FlightSector, customFields: [CustomCounterDefinition])
```
- First call the existing `accumulate(flight)` for the standard time fields.
- Then for each definition in customFields:
  - `.text` → skip.
  - `.time`, `.decimal`, `.integer` → read `flight.counterEntries[def.columnIndex]`; parse numeric. For `.time` values stored as HH:MM use `FlightSector.hhmmToDecimal`; fall back to `Double(raw)`. For `.decimal`/`.integer` use `Double(raw)`. If parse fails or empty, contribute 0.
  - Add into `customTotals[def.columnIndex, default: 0]`.

4. Footer value formatting — extend `formattedValue(for:useHHMM:)` so it returns custom-field totals for ids ≥ 100. The drawer knows the id→columnIndex mapping (id 100+n → customFields[n].columnIndex). Cleanest approach: add a new method the drawer calls for custom columns:
```swift
nonisolated func formattedCustomValue(columnIndex: Int, type: CounterType, useHHMM: Bool) -> String
```
- Look up `customTotals[columnIndex] ?? 0`.
- `.text` → return "" (no total).
- numeric, value ≤ 0 → "".
- `.time` → HH:MM if useHHMM else one-decimal; `.decimal` → one decimal; `.integer` → integer string.
Reuse the existing private `formatTime` / `formatHHMM` / `formatInt` helpers.

5. Update `LogbookPDFPaginator.computeTotals` to accept and thread custom fields so per-page custom totals accumulate:
```swift
static nonisolated func computeTotals(pages: [[RowSlot]], seed: PageTotals = PageTotals(), customFields: [CustomCounterDefinition] = []) -> [(page: PageTotals, broughtForward: PageTotals)]
```
Inside, call `pageTotals.accumulate(f, customFields: customFields)` when customFields is non-empty, else the existing `pageTotals.accumulate(f)`. The seed merge via `+` now carries customTotals forward.

Coordination note for Task 2 footer: the drawer, when rendering a custom time-group column (id≥100), must call `formattedCustomValue(columnIndex: customFields[id-100].columnIndex, type: customFields[id-100].type, useHHMM: useHHMM)` instead of `formattedValue(for:useHHMM:)`. Add that branch in the Task 2 footer loop (id ≥ 100 → custom; TRNG id 16 → existing formattedValue path).
  </action>
  <verify>
    <automated>MISSING — verify by inspection + local build. Confirm PageTotals.customTotals exists with default [:], `+` merges it, accumulate(_:customFields:) parses by type, computeTotals threads customFields, and Standard call sites still compile.</automated>
  </verify>
  <done>PageTotals carries per-columnIndex custom totals; numeric custom fields sum and format per type, text fields skip; paginator threads customFields; existing Standard accumulate/computeTotals paths unchanged.</done>
</task>

<task type="auto">
  <name>Task 4: Thread customFields through renderer + add custom-field picker UI</name>
  <files>Block-Time/Services/LogbookPDFRenderer.swift, Block-Time/Views/Screens/Settings/LogbookPDFExportView.swift</files>
  <action>
Wire the dynamic layout end-to-end and add the picker UI.

RENDERER (LogbookPDFRenderer.swift):
1. Add parameter `customFields: [CustomCounterDefinition] = []` to `render(...)`.
2. Compute the active column set + offsets once:
```swift
let columns = customFields.isEmpty ? LogbookPDFLayout.columns : LogbookPDFLayout.trainingRecordColumns(customFields: customFields)
let offsets = customFields.isEmpty ? LogbookPDFLayout.columnOffsets : LogbookPDFLayout.columnOffsets(for: columns)
```
3. Pass `customFields` into `LogbookPDFPaginator.computeTotals(pages:seed:customFields:)`.
4. Pass `columns: columns, columnOffsets: offsets, customFields: customFields` into every `LogbookPDFPageDrawer(...)` init (matching the new stored properties from Task 2). Standard callers (empty customFields) get `LogbookPDFLayout.columns`/`columnOffsets`/`[]` → identical output.

UI (LogbookPDFExportView.swift):
5. Add persistence: `@AppStorage("logbookPDFTrainingCustomFields") private var trainingCustomFieldsRaw: String = ""` (comma-separated columnIndex ints).
6. Add a computed property resolving raw → `[CustomCounterDefinition]` in saved order, intersected with current `CustomCounterService.shared.definitions`, capped at 7:
```swift
private var selectedCustomFields: [CustomCounterDefinition] { ... }
```
7. Add a new section in `setupView`, shown ONLY when `contentMode == .instructorHoursOnly` (Training Record) AND `showSpInsSelector` is true (matches the Content picker gating). Place it directly below the Content picker card.
   - If `CustomCounterService.shared.definitions.isEmpty`: show a single muted hint row "No custom fields defined — add them in Settings". Do not show toggles.
   - Else: section header "Custom Fields"; a row per definition with its label and a checkmark toggle (selected = columnIndex present in the raw list). Tapping toggles membership in `trainingCustomFieldsRaw`. Show "\(selectedCount) of 7 selected"; when 7 are selected, disable (greyed, non-tappable) the unselected rows so no 8th can be added.
   - Style consistent with existing cards: `.padding().background(Color.brown.opacity(0.06)).cornerRadius(12)`. Use `swiftui-pro` skill patterns; @Environment for any service access (CustomCounterService is @MainActor singleton — read `.definitions` on main actor in the view body).
8. In `generatePDF()`: compute `let customFields = contentMode == .instructorHoursOnly ? selectedCustomFields : []` on the main actor (capture into a local before `Task.detached`), and pass `customFields: customFields` into `LogbookPDFRenderer.render(...)`.

Do NOT remove or alter any existing UI control, the Standard path, cover title threading, or content-mode filtering.
  </action>
  <verify>
    <automated>MISSING — verify by inspection + local build, then manual: Training Record mode with 0/3/7 selected fields renders correct columns; Standard mode unchanged.</automated>
  </verify>
  <done>render() accepts customFields and uses dynamic layout when non-empty; picker appears only in Training Record mode, capped at 7, persisted via @AppStorage, threaded into render; Standard export visually unchanged.</done>
</task>

</tasks>

<verification>
- Standard mode export (Content = Standard, or Log Instructor Time off) produces byte-identical layout to before: 17 columns, crew present, Remarks 176pt.
- Training Record mode with 0 custom fields: crew columns gone, Remarks 560pt, TRNG present, footer totals TRNG only.
- Training Record mode with N (1–7) custom fields: N extra 44pt columns between Remarks and TRNG; Remarks = 560 - N*44; numeric custom fields total in footer, text fields blank.
- Selecting an 8th custom field is prevented (cap at 7).
- Custom field selection persists across app relaunch.
</verification>

<success_criteria>
- Crew columns dropped in Training Record mode only.
- Up to 7 user-selected custom fields render as columns with correct widths.
- Remarks shrinks to fit; numeric custom totals shown, text totals blank.
- Standard mode completely unchanged (layout, columns, totals, footer).
- Builds locally with no warnings introduced; Swift 6 strict concurrency respected (new helpers nonisolated, UI work on main actor).
</success_criteria>

<output>
After completion, create `.planning/quick/260524-hnc-training-record-pdf-dynamic-layout-dropp/260524-hnc-SUMMARY.md`
</output>
