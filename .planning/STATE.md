# Block-Time v2.0 — Project State

## Status
Phase: Not started
Current phase: —
Last updated: 2026-05-07

## Project Reference
See: .planning/PROJECT.md (updated 2026-05-07)

**Core value:** A pilot's logbook must be accurate and never lose data
**Current focus:** Phase 1 — Foundation

## Phase Progress

- ☐ Phase 1 — Foundation
- ☐ Phase 2 — Calculators & Tests
- ☐ Phase 3 — Core UI
- ☐ Phase 4 — Import Pipeline
- ☐ Phase 5 — Widgets & Extensions
- ☐ Phase 6 — Export & Settings
- ☐ Phase 7 — Mac + Pre-release

## Performance Metrics

Plans completed: 0
Plans total: TBD (populated after phase planning)
Phases completed: 0 / 7

## Accumulated Context

### Key Decisions (logged at phase transitions)
- (none yet)

### Critical Reminders
- FOUND-01 (VersionedSchema) and FOUND-02 (App Group URL) must be done before any TestFlight build — no exceptions
- Migration (FOUND-09/10/11) must be proven against a real production .sqlite file, not just in-memory tests
- CloudKit schema must be deployed to Production (CloudKit Console) before App Store submission — Phase 7 checklist item
- @Query iOS 18 refresh bug (IMP-07) requires ModelContext.didSave workaround — must be in architecture from Phase 3 onward
- @Model classes may need to stay in app targets, not Swift Package — spike this on day one of Phase 1 (research risk 8)
- CloudKit record type name must match v1 CD_FlightEntity — verify in CloudKit Console before any Production schema change

### Open Questions
- (none yet)

### Blockers
- (none yet)

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260508-lvr | Add AddFlightWidget to the BlockTimeWidget extension | 2026-05-08 | f1aef95 | [260508-lvr-add-addflightwidget-to-the-blocktimewidg](./quick/260508-lvr-add-addflightwidget-to-the-blocktimewidg/) |
| 260517-ins | Variable SIM time field for INS Simulator flights | 2026-05-17 | e05a73a | [260517-ins-sim-variable-time](./quick/260517-ins-sim-variable-time/) |
| 260517-dim | Fix INS Sim 0-SIM flights showing dimmed as future flights | 2026-05-17 | eb2f9b3 | — |
| 260517-u0w | Multi-counter system (definition + Core Data + dashboard + form + Settings) | 2026-05-18 | 2150c02 | [260517-u0w-implement-multi-counter-system-for-block](./quick/260517-u0w-implement-multi-counter-system-for-block/) |
| 260519-g0g | Rename Counter/Counters to Field/Fields (UI strings + Swift identifiers) | 2026-05-19 | 9bec18a | [260519-g0g-rename-counter-counters-to-field-fields-](./quick/260519-g0g-rename-counter-counters-to-field-fields-/) |
| 260519-gta | Fix iPad split view flight list stale row after Save alert | 2026-05-19 | 9b3501f | [260519-gta-fix-ipad-split-view-flight-list-stale-ro](./quick/260519-gta-fix-ipad-split-view-flight-list-stale-ro/) |
| 260519-i2o | Fix stale Custom Count column in FrozenColumnSpreadsheetView | 2026-05-19 | 72875fb | [260519-i2o-fix-stale-custom-count-column-in-frozenc](./quick/260519-i2o-fix-stale-custom-count-column-in-frozenc/) |
| 260519-ir7 | Convert InlineCustomFieldsView to List with drag-reorder and swipe-delete | 2026-05-19 | 36c8453 | [260519-ir7-convert-inlinecustomfieldsview-to-list-w](./quick/260519-ir7-convert-inlinecustomfieldsview-to-list-w/) |
| 260519-j10 | Suppress swipe-to-delete circles in InlineCustomFieldsView | 2026-05-19 | 960bc66 | [260519-j10-suppress-swipe-to-delete-circles-in-inli](./quick/260519-j10-suppress-swipe-to-delete-circles-in-inli/) |
| 260519-jer | Restructure InlineCustomFieldsView: Add Field at top, natural list height, no nested bg | 2026-05-19 | 279a16a | [260519-jer-restructure-inlinecustomfieldsview-add-f](./quick/260519-jer-restructure-inlinecustomfieldsview-add-f/) |
| 260519-ka3 | Add CloudKit KVS sync for CustomCounterDefinition array | 2026-05-19 | d834545 | [260519-ka3-add-cloudkit-kvs-sync-for-customcounterd](./quick/260519-ka3-add-cloudkit-kvs-sync-for-customcounterd/) |
| 260519-ctr | Round-trip custom counter definitions + values in backup/restore | 2026-05-19 | 3b07bef | [260519-ctr-backup-restore-custom-counters](./quick/260519-ctr-backup-restore-custom-counters/) |
| 260519-pds | Fix blank DefinitionConflictSheet — switch to sheet(item:) with PendingDefinitions | 2026-05-19 | 7c45530 | — |
| 260520-sqy | Add useLabelsAsHeaders param to exportToCSV; ExportLogbookView passes true | 2026-05-20 | 7bf55b6 | [260520-sqy-add-uselabelsasheaders-param-to-exportto](./quick/260520-sqy-add-uselabelsasheaders-param-to-exportto/) |
| 260520-t6j | Add custom fields section to ImportMappingView | 2026-05-20 | 0370e6d | [260520-t6j-add-custom-fields-section-to-importmappi](./quick/260520-t6j-add-custom-fields-section-to-importmappi/) |
| 260522-ke8 | Retire legacy customCount field across app (UI, import/export, FlightSector, DB writes) | 2026-05-22 | 6c557d2 | [260522-ke8-retire-legacy-customcount-field-across-a](./quick/260522-ke8-retire-legacy-customcount-field-across-a/) |
| 260522-lvy | Fix duplicate Counter1-10 rows in ImportMappingView generic Field Mapping section | 2026-05-22 | ddb7982 | [260522-lvy-fix-duplicate-counter1-10-rows-in-import](./quick/260522-lvy-fix-duplicate-counter1-10-rows-in-import/) |
| 260522-m4f | Move InlineCustomFieldsView into its own card in Crew & Ops Data settings | 2026-05-22 | 2a795ac | [260522-m4f-move-inlinecustomfieldsview-into-its-own](./quick/260522-m4f-move-inlinecustomfieldsview-into-its-own/) |
| 260522-tsl | Add Text type to custom fields (CounterType.text, placeholder, no totalling) | 2026-05-22 | 8fbf502 | [260522-tsl-add-text-type-to-custom-fields-counterty](./quick/260522-tsl-add-text-type-to-custom-fields-counterty/) |
| 260522-u9i | Revamp FieldEditSheet to card-based layout in Settings | 2026-05-22 | 92ee3f7 | [260522-u9i-revamp-fieldeditsheet-to-card-based-layo](./quick/260522-u9i-revamp-fieldeditsheet-to-card-based-layo/) |
| 260523-ps8 | Fix Clear button in keyboard toolbar for ModernRemarksField | 2026-05-23 | 34d3255 | [260523-ps8-fix-clear-button-in-keyboard-toolbar-for](./quick/260523-ps8-fix-clear-button-in-keyboard-toolbar-for/) |
| 260523-qbo | Add missing fields to BulkEditSheet (flight date, INS toggle, custom fields) | 2026-05-23 | 58efd94 | [260523-qbo-add-missing-fields-to-bulkeditsheet-flig](./quick/260523-qbo-add-missing-fields-to-bulkeditsheet-flig/) |
| 260523-qsz | Fix Save button not illuminating when INS toggle tapped in BulkEditSheet | 2026-05-23 | 269942e | [260523-qsz-fix-save-button-not-illuminating-when-in](./quick/260523-qsz-fix-save-button-not-illuminating-when-in/) |
| 260523-r6m | Fix updateFlightsBulk missing counter column writes | 2026-05-23 | 0282eee | [260523-r6m-fix-updateflightsbulk-missing-counter-co](./quick/260523-r6m-fix-updateflightsbulk-missing-counter-co/) |
| 260523-req | Fix Save button not enabling for new custom fields in BulkEditSheet | 2026-05-23 | 9330e6d | [260523-req-fix-save-button-not-enabling-for-new-cus](./quick/260523-req-fix-save-button-not-enabling-for-new-cus/) |
| 260523-rt0 | Fix customCounterStates willSet ordering — pass newStates via sink closure | 2026-05-23 | 3f1741d | [260523-rt0-fix-customcounterstates-willset-ordering](./quick/260523-rt0-fix-customcounterstates-willset-ordering/) |
| 260523-sv8 | Add BulkEditTimeField for dual-mode decimal/HH:MM custom Time fields in BulkEditSheet | 2026-05-23 | 9a2ae39 | [260523-sv8-add-bulkedittimefield-replicating-fieldt](./quick/260523-sv8-add-bulkedittimefield-replicating-fieldt/) |
| 260523-tux | Fix HH:MM mode input in FieldTimeField and BulkEditTimeField (numberPad, 00:00 placeholder, leading-zero display) | 2026-05-23 | b4cc346 | [260523-tux-fix-hh-mm-mode-input-in-fieldtimefield-a](./quick/260523-tux-fix-hh-mm-mode-input-in-fieldtimefield-a/) |
| 260523-urt | Show custom counter fields by user-defined label in ImportMappingView | 2026-05-23 | 2e82238 | [260523-urt-show-custom-counter-fields-by-user-defin](./quick/260523-urt-show-custom-counter-fields-by-user-defin/) |
| 260524-do7 | Fix INS|Sim simInsTime fallback and flight dimming bugs | 2026-05-24 | 6e08dbf | [260524-do7-fix-ins-simulator-save-and-dimming-bugs](./quick/260524-do7-fix-ins-simulator-save-and-dimming-bugs/) |

## Session Continuity

Last activity: 2026-05-24 - Fix INS|Sim simInsTime fallback and dimming guard (260524-do7)
Next action: Continue custom fields integration — PDF/print integration
