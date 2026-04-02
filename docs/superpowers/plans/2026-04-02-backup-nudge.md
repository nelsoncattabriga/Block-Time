# Backup Nudge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface two nudges that encourage users with logbook data to enable automatic backups — a dismissible banner in Settings and a one-time post-import sheet.

**Architecture:** Two new self-contained SwiftUI view files (`BackupNudgeBannerView`, `BackupNudgeSheet`), a new notification name constant, and small additions to three existing files (`Notifications.swift`, `SettingsView.swift`/`SettingsSplitView.swift`, `ImportExportView.swift`). All shared dismissal state lives in a single `@AppStorage` key.

**Tech Stack:** SwiftUI, `@AppStorage`, `ObservableObject` (`AutomaticBackupService`), `NotificationCenter`, `FlightDatabaseService.shared.getFlightCount()`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Block-Time/Models/Notifications.swift` | Modify | Add `.navigateToBackupSettings` constant |
| `Block-Time/Views/Components/BackupNudgeBannerView.swift` | **Create** | Self-contained banner card for Settings list |
| `Block-Time/Views/Screens/Settings/SettingsView.swift` | Modify | Insert banner + observe navigation notification (iPhone path) |
| `Block-Time/Views/Screens/Settings/SettingsSplitView.swift` | Modify | Observe navigation notification (iPad path) |
| `Block-Time/Views/Screens/Settings/BackupNudgeSheet.swift` | **Create** | Post-import prompt sheet |
| `Block-Time/Views/Screens/Settings/ImportExportView.swift` | Modify | Trigger `BackupNudgeSheet` after import review dismisses |

---

## Task 1: Add notification name constant

**Files:**
- Modify: `Block-Time/Models/Notifications.swift`

- [ ] **Step 1: Add the constant**

Open `Block-Time/Models/Notifications.swift`. The file currently ends at line 14. Replace the closing brace so the extension reads:

```swift
extension Notification.Name {
    static let flightDataChanged      = Notification.Name("flightDataChanged")
    static let scrollToTop            = Notification.Name("scrollToTop")
    static let reviewImportSession    = Notification.Name("reviewImportSession")
    static let navigateToBackupSettings = Notification.Name("navigateToBackupSettings")
}
```

- [ ] **Step 2: Build to confirm no errors**

In Xcode press ⌘B. Expected: build succeeds, no new errors.

- [ ] **Step 3: Commit**

```bash
git add Block-Time/Models/Notifications.swift
git commit -m "feat: add navigateToBackupSettings notification name"
```

---

## Task 2: Create BackupNudgeBannerView

**Files:**
- Create: `Block-Time/Views/Components/BackupNudgeBannerView.swift`

This is a self-contained banner card. It reads its own visibility conditions and hides itself when they are no longer met.

- [ ] **Step 1: Create the file**

Create `Block-Time/Views/Components/BackupNudgeBannerView.swift` with:

```swift
//
//  BackupNudgeBannerView.swift
//  Block-Time
//
//  Dismissible banner shown in Settings when the user has flights but
//  automatic backups are disabled. Tapping navigates to Backup & Sync.
//

import SwiftUI

struct BackupNudgeBannerView: View {
    @ObservedObject private var backupService = AutomaticBackupService.shared
    @AppStorage("backupNudgeDismissed") private var dismissed = false

    // Injected so the banner can trigger navigation on iPhone
    // (SettingsView passes a NavigationLink destination via this flag)
    @Binding var navigateToBackups: Bool

    private var shouldShow: Bool {
        !dismissed &&
        !backupService.settings.isEnabled &&
        FlightDatabaseService.shared.getFlightCount() > 0
    }

    var body: some View {
        if shouldShow {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Protect your logbook")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Enable automatic backups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Set Up")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue, in: Capsule())
            }
            .padding(16)
            .appCardStyle()
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation {
                        dismissed = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                navigateToBackups = true
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.2), value: dismissed)
        }
    }
}
```

- [ ] **Step 2: Build to confirm no errors**

Press ⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add "Block-Time/Views/Components/BackupNudgeBannerView.swift"
git commit -m "feat: add BackupNudgeBannerView"
```

---

## Task 3: Insert banner into SettingsView (iPhone)

**Files:**
- Modify: `Block-Time/Views/Screens/Settings/SettingsView.swift`

`SettingsView` is the iPhone/portrait-iPad path. It uses `NavigationLink` destinations for each category. We add a `@State var navigateToBackups` flag driven by the banner, a hidden `NavigationLink` for programmatic navigation, the banner itself between the trial card and category list, and an `onReceive` for the notification (for the case where `BackupNudgeSheet` triggers navigation).

- [ ] **Step 1: Add state property and notification observer**

In `SettingsView`, after the existing `@Environment(PurchaseService.self) private var purchaseService` line (line 59), add:

```swift
    @State private var navigateToBackups = false
```

- [ ] **Step 2: Insert banner and hidden NavigationLink into the VStack**

The `body` contains a `ScrollView > VStack`. Replace the existing VStack content (lines 67–113) so it reads:

```swift
            ScrollView {
                VStack(spacing: 16) {
                    // Hidden programmatic NavigationLink for backup navigation
                    NavigationLink(
                        destination: BackupsView(viewModel: viewModel),
                        isActive: $navigateToBackups
                    ) { EmptyView() }

                    if !purchaseService.isPro {
                        TrialStatusCard()
                    }

                    BackupNudgeBannerView(navigateToBackups: $navigateToBackups)

                    ForEach(SettingsCategory.allCases) { category in
                        NavigationLink(destination: categoryDetailView(for: category)) {
                            HStack(spacing: 16) {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                    .font(.title3)
                                    .frame(width: 32, height: 32)
                                    .background(category.color.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.rawValue)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    Text(category.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(.thinMaterial)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
```

- [ ] **Step 3: Add onReceive for the notification**

After the `.navigationBarTitleDisplayMode(.inline)` modifier (the last modifier on the `ZStack`), add:

```swift
        .onReceive(NotificationCenter.default.publisher(for: .navigateToBackupSettings)) { _ in
            navigateToBackups = true
        }
```

- [ ] **Step 4: Build and verify banner appears**

Press ⌘B. Run on iPhone simulator. Navigate to Settings — if you have flights and backups disabled, the banner should appear between the trial card area and the first category row.

- [ ] **Step 5: Commit**

```bash
git add Block-Time/Views/Screens/Settings/SettingsView.swift
git commit -m "feat: insert backup nudge banner and navigation into SettingsView"
```

---

## Task 4: Wire notification into SettingsSplitView (iPad)

**Files:**
- Modify: `Block-Time/Views/Screens/Settings/SettingsSplitView.swift`

On iPad the split view owns `selectedCategory`. When `.navigateToBackupSettings` fires, we set `selectedCategory = .backups`. The banner itself already appears in `SettingsCategoriesListContent` — we just need to add it there too.

- [ ] **Step 1: Add banner to SettingsCategoriesListContent**

In `SettingsCategoriesListContent.body`, the `List` currently has a Section for the trial card. Add a second Section for the banner, immediately after the trial card section:

```swift
            // Backup nudge banner
            Section {
                BackupNudgeBannerView(navigateToBackups: Binding(
                    get: { false },
                    set: { _ in
                        NotificationCenter.default.post(name: .navigateToBackupSettings, object: nil)
                    }
                ))
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
```

- [ ] **Step 2: Observe notification in SettingsSplitView**

In `SettingsSplitView.body`, add `.onReceive` after the existing `.navigationSplitViewStyle(.balanced)` modifier on the `NavigationSplitView`:

```swift
            .onReceive(NotificationCenter.default.publisher(for: .navigateToBackupSettings)) { _ in
                selectedCategory = .backups
            }
```

For the `else` branch (iPhone / portrait — uses `NavigationStack` wrapping `SettingsView`), the notification is already handled by `SettingsView.onReceive` added in Task 3. No additional changes needed there.

- [ ] **Step 3: Build and verify**

Press ⌘B. Run on iPad simulator. Navigate to Settings — banner should appear in the sidebar list. Tapping it should select Backup & Sync in the detail pane.

- [ ] **Step 4: Commit**

```bash
git add Block-Time/Views/Screens/Settings/SettingsSplitView.swift
git commit -m "feat: wire backup nudge banner and notification into SettingsSplitView"
```

---

## Task 5: Create BackupNudgeSheet

**Files:**
- Create: `Block-Time/Views/Screens/Settings/BackupNudgeSheet.swift`

This sheet appears after a successful import. It shows the flight count just added and gives the user a one-tap path to enable backups.

- [ ] **Step 1: Create the file**

Create `Block-Time/Views/Screens/Settings/BackupNudgeSheet.swift` with:

```swift
//
//  BackupNudgeSheet.swift
//  Block-Time
//
//  One-time post-import prompt encouraging the user to enable automatic backups.
//  Shown after ImportSessionReviewSheet dismisses when backups are disabled.
//

import SwiftUI

struct BackupNudgeSheet: View {
    /// Number of flights successfully imported in the triggering session.
    let importedFlightCount: Int

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var backupService = AutomaticBackupService.shared
    @AppStorage("backupNudgeDismissed") private var dismissed = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Your logbook is worth protecting")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("You just added \(importedFlightCount) flight\(importedFlightCount == 1 ? "" : "s"). Enable automatic backups to keep them safe.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    enableAndNavigate()
                } label: {
                    Text("Enable Automatic Backup")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }

                Button {
                    dismissed = true
                    dismiss()
                } label: {
                    Text("Not Now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func enableAndNavigate() {
        var settings = backupService.settings
        settings.isEnabled = true
        backupService.updateSettings(settings)
        dismissed = true
        dismiss()
        // Small delay so the sheet dismissal animation completes before navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NotificationCenter.default.post(name: .navigateToBackupSettings, object: nil)
        }
    }
}
```

- [ ] **Step 2: Build to confirm no errors**

Press ⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add "Block-Time/Views/Screens/Settings/BackupNudgeSheet.swift"
git commit -m "feat: add BackupNudgeSheet post-import prompt"
```

---

## Task 6: Trigger BackupNudgeSheet from ImportExportView

**Files:**
- Modify: `Block-Time/Views/Screens/Settings/ImportExportView.swift`

`ImportExportView` already has `@State private var lastImportResult: ImportSessionResult?` (line 70) and `.sheet(item: $lastImportResult)` (line 182) presenting `ImportSessionReviewSheet`. We need to:
1. Track the last successful import count so we can pass it to the sheet.
2. Watch for `lastImportResult` becoming nil (sheet dismissed) and show `BackupNudgeSheet` if conditions are met.

- [ ] **Step 1: Make ImportSessionResult Equatable**

`onChange(of:)` requires `Equatable`. In `ImportExportView.swift` around line 638, change:

```swift
struct ImportSessionResult: Identifiable {
```

to:

```swift
struct ImportSessionResult: Identifiable, Equatable {
    static func == (lhs: ImportSessionResult, rhs: ImportSessionResult) -> Bool {
        lhs.id == rhs.id
    }
```

- [ ] **Step 2: Add new state properties**

After `@State private var lastImportResult: ImportSessionResult? = nil` (line 70), add:

```swift
    @State private var showBackupNudge = false
    @State private var lastImportSuccessCount = 0
    @AppStorage("backupNudgeDismissed") private var backupNudgeDismissed = false
```

- [ ] **Step 3: Capture the success count when setting lastImportResult**

In `performImport` (around line 452), the existing line that sets `lastImportResult` is:

```swift
                    lastImportResult = ImportSessionResult(
                        sessionID: importResult.sessionID ?? UUID(),
                        successCount: importResult.successCount,
                        duplicateCount: importResult.duplicateCount,
                        mergedCount: 0
                    )
```

Add `lastImportSuccessCount = importResult.successCount` immediately before that assignment. Do the same in `performWebCISImportWithMappings` (around line 570) where `lastImportResult` is set:

```swift
                lastImportSuccessCount = importResult.successCount
                lastImportResult = ImportSessionResult(
                    sessionID: importResult.sessionID ?? UUID(),
                    successCount: importResult.successCount,
                    duplicateCount: importResult.duplicateCount,
                    mergedCount: 0
                )
```

- [ ] **Step 4: Add onChange to detect review sheet dismissal**

After the existing `.sheet(item: $lastImportResult)` modifier (line 182–184), add:

```swift
        .onChange(of: lastImportResult) { oldValue, newValue in
            // Review sheet was dismissed (non-nil → nil)
            guard oldValue != nil, newValue == nil else { return }
            guard lastImportSuccessCount > 0 else { return }
            guard !AutomaticBackupService.shared.settings.isEnabled else { return }
            guard !backupNudgeDismissed else { return }
            showBackupNudge = true
        }
        .sheet(isPresented: $showBackupNudge) {
            BackupNudgeSheet(importedFlightCount: lastImportSuccessCount)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
        }
```

- [ ] **Step 5: Build and verify**

Press ⌘B. Run on simulator. Perform a file import with at least one new flight. After tapping "Review Imported Flights" in the review sheet and returning, the `BackupNudgeSheet` should appear. "Not Now" should dismiss it and never show it again. "Enable Automatic Backup" should enable backups, dismiss, and navigate to Backup & Sync.

- [ ] **Step 6: Commit**

```bash
git add Block-Time/Views/Screens/Settings/ImportExportView.swift
git commit -m "feat: trigger BackupNudgeSheet after import review sheet dismisses"
```

---

## Task 7: Manual smoke test

No automated UI tests exist in this project. Verify the following manually:

- [ ] **Banner — happy path:** Fresh install state (or reset `backupNudgeDismissed` and disable backups in Settings). Add a flight manually. Go to Settings → banner appears below any trial card. Tap "Set Up" → navigates to Backup & Sync.

- [ ] **Banner — dismiss:** Tap ✕ on the banner. Banner disappears with animation. Return to Settings → banner does not reappear.

- [ ] **Banner — auto-hide:** Enable automatic backup in Backup & Sync. Return to Settings → banner is gone.

- [ ] **Post-import — happy path:** Reset `backupNudgeDismissed` to false and disable backups. Perform a file import with new flights. Dismiss the ImportSessionReviewSheet. `BackupNudgeSheet` appears showing the correct flight count.

- [ ] **Post-import — Enable tapped:** Tap "Enable Automatic Backup". Sheet dismisses. App navigates to Backup & Sync. `AutomaticBackupService.shared.settings.isEnabled` is now `true`. Returning to Settings shows no banner.

- [ ] **Post-import — Not Now tapped:** Tap "Not Now". Sheet dismisses. Perform another import. `BackupNudgeSheet` does NOT appear again.

- [ ] **iPad split view:** On iPad simulator in landscape, Settings sidebar shows the banner. Tapping selects Backup & Sync in the detail pane.

- [ ] **Commit final**

```bash
git add .
git commit -m "feat: backup nudge — settings banner and post-import prompt complete"
```
