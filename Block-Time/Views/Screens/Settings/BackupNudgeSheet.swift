//
//  BackupNudgeSheet.swift
//  Block-Time
//
//  One-time post-import prompt encouraging the user to enable automatic backups.
//  Shown after ImportSessionReviewSheet dismisses when backups are disabled.
//

import SwiftUI
import BlockTimeKit

struct BackupNudgeSheet: View {
    /// Number of flights successfully imported in the triggering session.
    let importedFlightCount: Int

    @Environment(\.dismiss) private var dismiss
    @StateObject private var backupService = AutomaticBackupService.shared
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
