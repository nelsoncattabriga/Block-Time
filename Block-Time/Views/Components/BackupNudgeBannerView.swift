//
//  BackupNudgeBannerView.swift
//  Block-Time
//
//  Dismissible banner shown in Settings when the user has flights but
//  automatic backups are disabled. Tapping navigates to Backup & Sync.
//

import SwiftUI

struct BackupNudgeBannerView: View {
    @StateObject private var backupService = AutomaticBackupService.shared
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
                // Tappable card area
                Button {
                    navigateToBackups = true
                } label: {
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
                }
                .buttonStyle(.plain)

                // Dismiss button — separate from card tap area
                Button {
                    withAnimation {
                        dismissed = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .appCardStyle()
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
