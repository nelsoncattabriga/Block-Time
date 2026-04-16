# Block-Time Mac — Interface Design Specification
> macOS 15+ companion app. Professional aviation logbook. Native macOS aesthetic.

---

## Aesthetic Direction: **Instrument Panel**

**Concept**: The interface evokes a modern glass cockpit — precise, data-dense, information-hierarchical. Not skeuomorphic (no fake gauges), but the *discipline* of cockpit design: every element earns its place, information is layered by priority, status is communicated instantly through colour.

**Tone**: Refined utilitarian. Like a Bloomberg Terminal designed by Jony Ive. Dense without being cluttered. Professional without being sterile.

**What makes it memorable**: The logbook table is the star. It behaves like a real pilot's logbook — rows are flights, columns map to ICAO logbook fields, and the whole thing feels like opening a high-quality piece of professional software, not a ported phone app.

---

## Typography

```
Display / Section Headers:  SF Pro Display, semibold
Body / Table data:          SF Pro Text, regular
Monospaced (times/codes):   SF Mono — IATA codes, block times, flight numbers
Labels / Captions:          SF Pro Text, 11pt, secondary colour
```

**Key rules**:
- All time values (block time, flight time, etc.) in **SF Mono** — they must column-align
- Airport codes in **SF Mono, uppercase**
- Flight numbers in **SF Mono**
- Row heights: 28pt in table (compact but not cramped)
- Column headers: 11pt, uppercase, secondary colour, no bold — like a spreadsheet header

---

## Colour Palette

Inherits the existing `AppTheme` system. macOS adds:

```swift
// macOS-specific semantic additions (extend AppColors)
static let tableRowAlternate  = Color.primary.opacity(0.03)   // zebra stripe
static let tableRowSelected   = Color.accentColor.opacity(0.12)
static let tableRowHover      = Color.primary.opacity(0.05)
static let sidebarBackground  = Color(nsColor: .windowBackgroundColor)
static let detailDivider      = Color.primary.opacity(0.08)
static let toolbarBackground  = Color(nsColor: .windowBackgroundColor).opacity(0.8)
```

**Status colours** (already in use on iOS, carry over):
- Green → compliant / positive
- Orange → warning / near limit
- Red → violation
- Blue → accent / interactive
- `.secondary` → all supporting text

**Dark mode**: Everything uses semantic colours + `.regularMaterial` / `.ultraThinMaterial` — automatic.

---

## Global Window Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│ [Traffic lights]   Block-Time                          [Window controls] │  ← Title bar (standard macOS)
├──────────┬────────────────────────────────────────────┬─────────────────┤
│          │ [Toolbar — contextual per section]          │                 │
│  S       ├────────────────────────────────────────────┤   D             │
│  I       │                                            │   E             │
│  D       │   CONTENT AREA                             │   T             │
│  E       │   (changes per sidebar selection)          │   A             │
│  B       │                                            │   I             │
│  A       │                                            │   L             │
│  R       │                                            │                 │
│          │                                            │   P             │
│  ~200pt  │   ~3/4 of remaining width                  │   A  ~1/4       │
│          │                                            │   N             │
│          │                                            │   E             │
│          │                                            │   L             │
└──────────┴────────────────────────────────────────────┴─────────────────┘
```

**SwiftUI structure**:
```swift
NavigationSplitView(
    columnVisibility: $columnVisibility,
    sidebar: { SidebarView() },
    content: { ContentAreaView(section: $selectedSection) },
    detail:  { DetailPanelView(section: $selectedSection, selection: $tableSelection) }
)
.navigationSplitViewStyle(.balanced)
```

Minimum window size: **1100 × 700pt**. Sidebar fixed width: **200pt**. Detail panel minimum: **280pt**.

---

## Column 1 — Sidebar

**Width**: 200pt fixed  
**Style**: `List` with `.sidebar` listStyle — native macOS vibrancy background

### Navigation Items

```
┌──────────────────────┐
│  ✈ Block-Time        │  ← App name / logo area, 44pt tall
├──────────────────────┤
│                      │
│  📋  Logbook         │  ← Selected state: accent fill, rounded rect
│  📊  Dashboard       │
│  🗺   Map            │
│  🛡️  FRMS            │
│  ⚙️  Settings        │
│                      │
├──────────────────────┤
│  [Sync status]       │  ← Bottom: iCloud sync indicator (●  Synced / ↻ Syncing)
│  [Total hours]       │  ← e.g. "4,823:12 total"
└──────────────────────┘
```

**Item anatomy**:
```swift
Label {
    Text(section.title)
        .font(.system(size: 13, weight: .medium))
} icon: {
    Image(systemName: section.icon)
        .foregroundStyle(isSelected ? .white : section.colour)
        .frame(width: 20)
}
.listRowBackground(
    isSelected
        ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor)
        : Color.clear
)
```

**Bottom status strip** (16pt tall, pinned to bottom):
- iCloud sync state: coloured dot + "Synced" / "Syncing…" / "Offline"
- Tap → shows last sync timestamp in tooltip
- Total logbook hours: SF Mono, 11pt, secondary

---

## Column 2 — Toolbar (contextual per section)

The toolbar sits above the content area, inside the `NavigationSplitView` content column. It uses native macOS `toolbar` modifier with `ToolbarItem(placement: .automatic)`.

### Logbook Toolbar
```
[+] Add Flight    [Filter ▾]  [Sort ▾]  [Search…]              [Export ▾]
```
- **+** button → clears detail panel, shows Add New Flight form
- **Filter** → popover: date range, aircraft type, crew position, airport
- **Sort** → popover: sort field + ascending/descending (mirrors `Table` sort)
- **Search** → inline search field, filters table rows live
- **Export** → menu: Export CSV, Export PDF Logbook, Print

### Dashboard Toolbar
```
[Date Range ▾]  [Configure Cards]                              [Export ▾]
```
- Date range: This Month / Last 3 Months / Last 12 Months / All Time / Custom…
- Configure Cards → opens sheet (same as iOS edit sheet)

### Map Toolbar
```
[Filter: All Airports ▾]  [Route Type ▾]                       [Reset View]
```

### FRMS Toolbar
```
[Position: Captain ▾]  [Fleet: A380/A330/B787 ▾]
```

### Settings Toolbar
*(empty — no toolbar)*

---

## Column 2 — Content: LOGBOOK (Hero view)

### SwiftUI `Table` — the core of the Mac app

```swift
Table(flights, selection: $selection, sortOrder: $sortOrder) {
    // Identity
    TableColumn("Date",       value: \.date)          { DateCell($0) }
    TableColumn("Flight",     value: \.flightNumber)  { MonoCell($0.flightNumber) }
    
    // Route
    TableColumn("DEP",        value: \.departureAirport) { MonoCell($0) }
    TableColumn("ARR",        value: \.arrivalAirport)   { MonoCell($0) }
    
    // Times
    TableColumn("STD",        value: \.scheduledDeparture) { TimeCell($0) }
    TableColumn("STA",        value: \.scheduledArrival)   { TimeCell($0) }
    TableColumn("Block",      value: \.blockTimeValue)     { TimeCell($0.blockTime) }
    TableColumn("Flight",     value: \.flightTimeValue)    { TimeCell($0.flightTime) }
    TableColumn("Night",      value: \.nightTimeValue)     { TimeCell($0.nightTime) }
    
    // Role
    TableColumn("P1",         value: \.p1TimeValue)        { TimeCell($0.p1Time) }
    TableColumn("P1s",        value: \.p1usTimeValue)      { TimeCell($0.p1usTime) }
    TableColumn("P2",         value: \.p2TimeValue)        { TimeCell($0.p2Time) }
    
    // Aircraft
    TableColumn("Type",       value: \.aircraftType)       { MonoCell($0) }
    TableColumn("Reg",        value: \.aircraftReg)        { MonoCell($0) }
    
    // T/O & Ldg
    TableColumn("T/O",        sortUsing: ...) { TakeoffLandingCell($0) }
    TableColumn("Ldg",        sortUsing: ...) { TakeoffLandingCell($0) }
}
.tableStyle(.inset(alternatesRowBackgrounds: true))
.onChange(of: sortOrder) { flights.sort(using: $0) }
```

**Column widths** (initial defaults, user resizable):

| Column | Width | Notes |
|--------|-------|-------|
| Date | 88pt | dd MMM yy |
| Flight | 72pt | Mono |
| DEP | 48pt | IATA Mono |
| ARR | 48pt | IATA Mono |
| STD | 56pt | HH:mm Mono |
| STA | 56pt | HH:mm Mono |
| Block | 56pt | HH:mm Mono |
| Flight | 56pt | HH:mm Mono |
| Night | 56pt | HH:mm Mono |
| P1 | 56pt | HH:mm Mono |
| P1s | 52pt | HH:mm Mono |
| P2 | 52pt | HH:mm Mono |
| Type | 72pt | Mono |
| Reg | 72pt | Mono |
| T/O | 40pt | D+N badge |
| Ldg | 40pt | D+N badge |

**Total minimum**: ~1050pt → fits in 1100pt window with sidebar + detail panel.

### Cell design

```
DateCell:          "16 Apr 26"  → Text, 13pt, SF Pro
MonoCell:          "MEL"        → Text, 13pt, SF Mono, uppercase
TimeCell:          "11:45"      → Text, 13pt, SF Mono, trailing aligned
TakeoffLandingCell: "2+1"      → "2" normal + "/1" secondary (day/night)
EmptyTimeCell:     "—"         → 13pt, tertiaryLabel colour
```

**Row states**:
- Default: alternating background (3% opacity tint)
- Hover: 5% opacity primary overlay
- Selected (single): accentColor 12% fill + accent-coloured left border (2pt)
- Selected (multi): same fill, all rows marked
- Positioning row: `.italic` modifier on flight number + route cells

### Column visibility toggle
A `Menu` button in the toolbar labeled "Columns ▾" lists all columns with checkmarks — lets pilots hide columns they don't need (e.g. hide Sp/Ins columns if not instructing).

### Footer bar (pinned below table)
```
┌─────────────────────────────────────────────────────────────┐
│ 1,247 entries  │  Selected: 0  │  Total Block: 4,823:12    │
└─────────────────────────────────────────────────────────────┘
```
11pt, SF Mono for numbers, secondary colour. Updates live with filter/selection.

---

## Column 2 — Content: DASHBOARD

Adapts existing `NewDashboardView` cards into a native macOS grid.

**Layout**: `LazyVGrid` with adaptive columns (minimum 260pt each).  
Cards use existing `appCardStyle()` — `.regularMaterial` background with 12pt corner radius and subtle stroke. These look native on macOS without modification.

**Difference from iOS**: No FRMS strip at top (FRMS is its own section). Dashboard starts directly with stat cards.

Detail panel (right 1/4): when a card is selected/clicked, shows a breakdown or expanded chart. For example:
- Click `StatCard` (block time) → detail shows month-by-month bar chart
- Click `TopRoutesCard` → detail shows full routes list with times
- Click `RecencyCard` → detail shows expiry dates per qualification

---

## Column 2 — Content: MAP

Reuse `FlightMapView` directly. MapKit works on macOS.

**macOS-specific adjustments**:
- Mouse scroll = zoom (default MapKit behaviour)
- Click airport annotation → selects it → populates detail panel
- Hover over route arc → tooltip with route + total flights

---

## Column 2 — Content: FRMS

Reuse `FRMSSplitView` logic but adapted: since we already have the 3-column `NavigationSplitView`, the FRMS sidebar (Cumulative Limits / Next Duty / Min. Turnaround / Recent Duties) lives in the **content** column, and the FRMS detail renders in the **detail** panel column.

Detail panel for FRMS: the selected FRMS section's full detail view.

---

## Column 2 — Content: SETTINGS

Standard macOS `Form` / `Settings`-style layout.  
Use `Form` with `Section` groupings — macOS renders these as proper grouped settings rows.  
No detail panel for Settings — detail column collapses or shows an informational placeholder.

---

## Column 3 — Detail Panel

**Width**: ~280–350pt. Fixed — not resizable by user (keeps table layout stable).  
**Background**: `.regularMaterial` with a 1pt left divider (`Divider()` or `Rectangle().fill(.separator).frame(width: 1)`).

### Mode 1: ADD NEW FLIGHT (default / no selection)

```
┌──────────────────────────┐
│  + New Flight            │  ← Section header, 13pt semibold
│  [Save]        [Cancel]  │  ← Button row — Save primary (accent), Cancel text
├──────────────────────────┤
│  FLIGHT DETAILS          │  ← Group label, 11pt uppercase secondary
│  Date         [16 Apr]   │
│  Flight No.   [QF123___] │
│  DEP          [MEL_____] │
│  ARR          [SYD_____] │
│  STD          [06:00___] │
│  STA          [07:30___] │
├──────────────────────────┤
│  TIMES                   │
│  Block        [01:20___] │
│  Flight       [01:15___] │
│  Night        [00:00___] │
│  P1           [01:20___] │
│  P1s          [00:00___] │
│  P2           [00:00___] │
├──────────────────────────┤
│  AIRCRAFT                │
│  Type         [B738____] │
│  Reg          [VH-XZA__] │
├──────────────────────────┤
│  TAKEOFFS / LANDINGS     │
│  Day T/O      [2_______] │
│  Night T/O    [0_______] │
│  Day Ldg      [1_______] │
│  Night Ldg    [1_______] │
├──────────────────────────┤
│  CREW                    │
│  PIC          [________] │
│  SFO          [________] │
├──────────────────────────┤
│  NOTES                   │
│  [_____________________] │
│  [_____________________] │
└──────────────────────────┘
```

**Form implementation**:
```swift
Form {
    Section("Flight Details") {
        DatePicker("Date", selection: $date, displayedComponents: .date)
        TextField("Flight No.", text: $flightNumber)
            .font(.system(.body, design: .monospaced))
            .textCase(.uppercase)
        // etc.
    }
    Section("Times") { ... }
    Section("Aircraft") { ... }
}
.formStyle(.grouped)  // native macOS grouped form
```

The macOS `Form` with `.grouped` style renders identically to System Preferences panels. Clean, native, no iOS-style cells.

**Save/Cancel**: Placed in a sticky toolbar at the TOP of the panel (not bottom, per macOS convention). Save = default button (accent, filled). Cancel = text button. Keyboard shortcut: `⌘S` Save, `Escape` Cancel.

### Mode 2: EDIT FLIGHT (single row selected)

Identical layout to Add, but pre-populated.  
Header changes to: `"Edit Flight — QF123"` with date subtitle.  
Additional: `[Delete Flight]` button at very bottom, destructive red, with confirmation alert.

**Transition**: When user clicks a row, panel animates in — existing form fields update with `.animation(.easeInOut(duration: 0.15))`. No full panel re-render.

### Mode 3: BULK EDIT (multiple rows selected)

```
┌──────────────────────────┐
│  Bulk Edit               │
│  3 flights selected      │  ← count, secondary
│  [Apply]    [Cancel]     │
├──────────────────────────┤
│  Only filled fields      │  ← explanatory caption
│  will be updated.        │
├──────────────────────────┤
│  Aircraft Type  [______] │  ← empty = "no change"
│  Aircraft Reg   [______] │
│  Crew PIC       [______] │
│  Crew SFO       [______] │
├──────────────────────────┤
│  ☐  Recalculate night    │  ← Toggle checkboxes
│  ☐  Clear notes          │
└──────────────────────────┘
```

Reuses `BulkEditViewModel` fields. macOS `Toggle` renders as a checkbox — exactly right for bulk edit.

### Mode 4: MAP — Airport flights

```
┌──────────────────────────┐
│  Melbourne (MEL)         │  ← Airport name + code
│  Tullamarine Airport     │  ← Full name, secondary
├──────────────────────────┤
│  23 departures           │
│  19 arrivals             │
│  Total: 42 flights       │
├──────────────────────────┤
│  RECENT FLIGHTS          │
│  QF93   MEL→LHR  14 Apr  │
│  QF94   LHR→MEL  10 Apr  │
│  QF93   MEL→LHR   3 Apr  │
│  ...                     │  ← Scrollable list
└──────────────────────────┘
```

Each row: tap → jumps to that flight in the Logbook table (cross-section navigation).

### Mode 5: DASHBOARD — Card detail

Panel shows an expanded version of the tapped card:
- StatCard → bar chart breakdown by month (using Swift Charts)
- TopRoutesCard → full scrollable list
- RecencyCard → list with days-remaining colour coded badges
- WorkRateHeatmapCard → full-size calendar heatmap

---

## Key Interaction Flows

### Single-click row → Edit
1. Row highlights (accent fill + left accent border)
2. Detail panel form populates with `.animation(.easeInOut(duration: 0.15))`
3. User edits any field → Save button activates (was greyed)
4. `⌘S` or [Save] → saves to Core Data → row updates in table → success: brief green checkmark in panel header

### Multi-select → Bulk Edit
1. `⌘+click` or `⇧+click` for range selection (standard macOS Table behaviour)
2. When `selection.count > 1` → detail panel switches to Bulk Edit mode
3. Only non-empty fields in bulk form apply to all selected flights
4. [Apply] → confirmation: "Update 5 flights?" → Yes → applies → clears selection

### + New Flight
1. Click [+] in toolbar OR `⌘N`
2. Table selection clears
3. Detail panel animates to Add mode with empty form
4. Fill fields → `⌘S` → new row appears in table (scrolled into view), highlighted briefly

### Online lookup
Add a [Lookup] button next to the Flight No. field in the Add/Edit panel.  
Triggers `FlightAwareService` / `AeroDataBoxService` — same as iOS.  
Result populates DEP, ARR, STD, STA, Type automatically.

---

## SwiftUI Implementation Notes

### NavigationSplitView skeleton
```swift
struct Block_TimeMacApp: App {
    var body: some Scene {
        WindowGroup {
            MacContentView()
                .environment(ThemeService.shared)
                .environmentObject(flightTimeVM)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Flight") { /* trigger add */ }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

struct MacContentView: View {
    @State private var selectedSection: MacSection = .logbook
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var tableSelection = Set<FlightSector.ID>()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MacSidebarView(selection: $selectedSection)
                .navigationSplitViewColumnWidth(200)
        } content: {
            MacContentAreaView(section: selectedSection, tableSelection: $tableSelection)
        } detail: {
            MacDetailPanelView(section: selectedSection, selection: tableSelection)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        }
    }
}
```

### Table sort
```swift
@State private var sortOrder: [KeyPathComparator<FlightSector>] = [
    .init(\.date, order: .reverse)  // most recent first
]

// In body:
.onChange(of: sortOrder) { _, newOrder in
    flights.sort(using: newOrder)
}
```

### Detail panel transitions
```swift
// Don't use `.transition()` — it causes layout jumps in split views
// Instead, animate individual field updates:
.animation(.easeInOut(duration: 0.15), value: selectedFlight?.id)
```

### Shared files (Target Membership — both targets)
- All `Models/` Swift files
- All `ViewModels/` Swift files  
- All `Services/` except: `HapticManagerService`, `PhotoSavingService`, `TextRecognitionService` (camera pipeline)
- Dashboard cards in `Views/Components/Dashboard/`
- `AppDesign.swift` (colours and card style)
- `ThemeService.swift` (with `#if os(macOS)` guard around haptic call)
- `FlightDatabaseService.swift` (with `#if os(macOS)` guard around `UIApplication` calls)
- `FlightMapView.swift`
- `FRMSView.swift` and related FRMS views

### Platform guards pattern
```swift
// In shared files with UIKit calls:
func setTheme(_ theme: AppTheme) {
    currentTheme = theme
    #if os(iOS)
    HapticManager.shared.impact(.light)
    #endif
}
```

---

## Minimum Viable Build Order

1. **Window shell** — `NavigationSplitView` with sidebar + empty content/detail panes. Sidebar navigation works.
2. **Logbook table** — `Table` view pulling from `FlightDatabaseService.shared`. Sortable. No detail panel yet.
3. **Detail panel: Edit** — single row selection populates form. Save works (Core Data).
4. **Detail panel: Add** — [+] button → empty form → save → row appears.
5. **Detail panel: Bulk Edit** — multi-select → bulk form → apply.
6. **Footer bar** — entry count, selected count, total hours.
7. **Toolbar: filter + search** — live filter on table.
8. **Dashboard section** — wire in existing cards.
9. **Map section** — wire in `FlightMapView`.
10. **FRMS section** — wire in FRMS views.
11. **Settings section** — adapt iOS settings form to macOS `Form(.grouped)`.
12. **Online lookup** — wire `FlightAwareService` into detail panel.
13. **Export** — CSV export from toolbar.
14. **Polish** — animations, keyboard shortcuts, window sizing, CloudKit sync indicator.
