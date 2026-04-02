# Backup Nudge Design
**Date:** 2026-04-02
**Status:** Approved

## Goal

Encourage users who have logbook data but haven't enabled automatic backups to do so, without being intrusive. Two surfaces: a persistent-but-dismissible banner in Settings, and a one-time post-import prompt.

---

## Shared State

A single `@AppStorage("backupNudgeDismissed") var backupNudgeDismissed: Bool = false` key controls both nudges. Setting it `true` from either surface suppresses both permanently. The banner also self-hides when `backupService.settings.isEnabled == true`.

---

## Feature 1: Settings Banner

### Visibility
Show `BackupNudgeBannerView` in `SettingsView` (between the Trial card and the category list) when ALL of:
- `AutomaticBackupService.shared.settings.isEnabled == false`
- `FlightDatabaseService.shared.getFlightCount() > 0`
- `backupNudgeDismissed == false`

### Layout
- Styled consistently with `TrialStatusCard` — card with `.thinMaterial` background, blue accent border
- Left: shield/cloud SF Symbol (blue), headline "Protect your logbook", caption "Enable automatic backups"
- Right: "Set Up →" label (blue)
- Top-trailing: small ✕ dismiss button
- Entire card (except ✕) is tappable — navigates to Backup & Sync via `NavigationLink` or programmatic navigation

### Behaviour
- Tapping card body → navigate to `BackupsView`
- Tapping ✕ → sets `backupNudgeDismissed = true`, banner disappears with animation
- Card disappears automatically once `isEnabled` becomes `true`

### Component
`BackupNudgeBannerView` — self-contained, reads its own visibility state. `SettingsView` just inserts it; it manages its own AppStorage and ObservedObject references internally.

---

## Feature 2: Post-Import Prompt

### Visibility
Show `BackupNudgeSheet` after `ImportSessionReviewSheet` dismisses when ALL of:
- `importResult.successCount > 0`
- `AutomaticBackupService.shared.settings.isEnabled == false`
- `backupNudgeDismissed == false`

### Trigger Mechanism
`ImportExportView` already drives `ImportSessionReviewSheet` via `.sheet(item: $lastImportResult)`. Add `.onChange(of: lastImportResult)` — when it transitions from non-nil to nil (sheet dismissed), check the conditions above and set `showBackupNudge = true`.

### Layout
- `.presentationDetents([.height(320)])`, `.presentationDragIndicator(.visible)`
- `shield.fill` icon (blue, large)
- Headline: "Your logbook is worth protecting"
- Subtext: "You just added X flights. Enable automatic backups to keep them safe."
- Primary button: "Enable Automatic Backup" (blue filled) — enables backup and navigates to Backup & Sync
- Secondary button: "Not Now" (plain, secondary colour) — sets `backupNudgeDismissed = true`

### "Enable" Action
1. Call `AutomaticBackupService.shared.updateSettings(settings)` with `isEnabled = true`
2. Dismiss the sheet
3. Post `Notification.Name("navigateToBackupSettings")` so `SettingsSplitView`/`SettingsView` can navigate to `BackupsView` (user lands there to review location/frequency)

### Navigation from Notification
`SettingsView` (or `SettingsSplitView`) observes `navigateToBackupSettings` and sets the selected category to `.backups`. This mirrors how `.reviewImportSession` notification drives logbook tab navigation.

---

## Files Affected

| File | Change |
|---|---|
| `SettingsView.swift` | Insert `BackupNudgeBannerView` between trial card and category list; observe `navigateToBackupSettings` notification |
| `SettingsSplitView.swift` | Observe `navigateToBackupSettings` notification, set selected detail to `.backups` |
| `ImportExportView.swift` | Add `showBackupNudge` state, `.onChange(of: lastImportResult)` trigger, `.sheet(isPresented: $showBackupNudge)` |
| `BackupNudgeBannerView.swift` (new) | Self-contained banner card |
| `BackupNudgeSheet.swift` (new) | Post-import sheet |

---

## Out of Scope
- TipKit integration
- Local notifications
- Showing the nudge for manually added flights (only post-import for now)
- Re-showing the nudge after the user disables backups again
