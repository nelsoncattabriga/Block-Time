// Views/Screens/Settings/CloudKitSyncCard.swift
import SwiftUI

// MARK: - CloudKit Sync Card

struct ModernCloudKitSyncCard: View {
    @ObservedObject var databaseService = FlightDatabaseService.shared
    @Environment(CloudKitSettingsSyncService.self) var settingsService
    @AppStorage("debugModeEnabled") private var debugModeEnabled = false
    @State private var showSyncHelp = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("iCloud Sync Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    showSyncHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                // Debug mode indicator
                if debugModeEnabled {
                    Text("DEBUG")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .sheet(isPresented: $showSyncHelp) {
                ICloudSyncHelpSheet()
            }

            if !settingsService.isCloudAvailable() {
                // iCloud not available message
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("iCloud Not Available")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Sign in to iCloud in Settings to sync your data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    // Database sync status
                    syncDetailRow(
                        title: "Flight Database",
                        icon: "airplane",
                        isSyncing: databaseService.isSyncing,
                        lastSync: databaseService.lastSyncDate,
                        lastChange: nil,
                        error: databaseService.lastSyncError
                    )

                    // Settings sync status
                    syncDetailRow(
                        title: "Settings",
                        icon: "gearshape",
                        isSyncing: settingsService.isSyncing,
                        lastSync: settingsService.lastSyncDate,
                        lastChange: settingsService.lastChangeDate,
                        error: settingsService.lastSyncError
                    )

//                    Divider()
//                        .padding(.horizontal, -4)
//
//                    // Info
//                    Text("Data will sync via iCloud automatically.")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.center)
//                        .padding(.top, 4)

                    // Debug buttons (only visible when Debug Mode is enabled)
                    if debugModeEnabled {
                        Divider()
                            .padding(.horizontal, -4)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug: Error Simulation")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)

                            HStack(spacing: 8) {
                                Button(action: {
                                    databaseService.simulatePartialSyncFailure()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                        Text("Partial")
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)

                                Button(action: {
                                    databaseService.simulateNetworkError()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "wifi.slash")
                                            .font(.caption)
                                        Text("Network")
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)

                                Button(action: {
                                    databaseService.clearSimulatedErrors()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                        Text("Clear")
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)
                            }
                        }
                        .padding(.top, 4)

                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func syncDetailRow(title: String, icon: String, isSyncing: Bool, lastSync: Date?, lastChange: Date? = nil, error: Error?) -> some View {
        SyncDetailRowView(title: title, icon: icon, isSyncing: isSyncing, lastSync: lastSync, lastChange: lastChange, error: error, detailedSyncError: databaseService.detailedSyncError)
    }
}

// MARK: - Sync Detail Row with Expandable Error Details

struct SyncDetailRowView: View {
    let title: String
    let icon: String
    let isSyncing: Bool
    let lastSync: Date?
    let lastChange: Date?
    let error: Error?
    let detailedSyncError: DetailedSyncError?

    @State private var showErrorDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let error = error {
                let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: error)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: errorInfo.isRetryable ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(errorInfo.isRetryable ? .orange : .red)
                            .font(.caption)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(errorInfo.message)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(errorInfo.isRetryable ? .orange : .red)

                            Text(errorInfo.suggestion)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Always show technical details button if we have detailed error information
                    if let detailedError = detailedSyncError {
                        Button(action: {
                            withAnimation {
                                showErrorDetails.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(showErrorDetails ? "Hide Technical Details" : "Show Technical Details")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                Image(systemName: showErrorDetails ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 2)

                        // Expandable error details
                        if showErrorDetails {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider()
                                    .padding(.vertical, 2)

                                // Show individual errors if available
                                if detailedError.hasIndividualErrors {
                                    Text("Failed Items (\(detailedError.individualErrors.count))")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)

                                    ForEach(Array(detailedError.individualErrors.enumerated()), id: \.offset) { index, errorItem in
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Record: \(errorItem.recordID)")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)

                                            let itemErrorInfo = CloudKitErrorHelper.userFriendlyMessage(for: errorItem.error)
                                        Text(itemErrorInfo.message)
                                            .font(.caption2)
                                            .foregroundColor(itemErrorInfo.isRetryable ? .orange : .red)

                                        Text(itemErrorInfo.suggestion)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.vertical, 3)

                                    if index < detailedError.individualErrors.count - 1 {
                                        Divider()
                                    }
                                }

                                    Divider()
                                        .padding(.vertical, 4)
                                }

                                // Always show technical error details
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Technical Details")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)

                                    Group {
                                        HStack(alignment: .top) {
                                            Text("Error Domain:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text(detailedError.errorDomain)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }

                                        HStack(alignment: .top) {
                                            Text("Error Code:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text("\(detailedError.errorCode)")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }

                                        HStack(alignment: .top) {
                                            Text("Operation:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text(detailedError.operation)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }

                                        HStack(alignment: .top) {
                                            Text("Timestamp:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text(detailedError.timestamp.formatted(date: .numeric, time: .standard))
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }

                                        HStack(alignment: .top) {
                                            Text("Description:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text(errorInfo.suggestion)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Spacer()
                                        }

                                        // Show userInfo if available
                                        if !detailedError.errorUserInfo.isEmpty {
                                            Divider()
                                                .padding(.vertical, 2)

                                            Text("Additional Info:")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)

                                            ForEach(Array(detailedError.errorUserInfo.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                                HStack(alignment: .top) {
                                                    Text("\(key):")
                                                        .font(.caption2)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 100, alignment: .leading)
                                                    Text(value)
                                                        .font(.system(.caption2, design: .monospaced))
                                                        .foregroundColor(.primary)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(6)
                .background(errorInfo.isRetryable ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(4)
            } else if let date = lastSync {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.footnote)
                        Text("Last synced \(date.formatted(.relative(presentation: .named)))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    if let changeDate = lastChange, changeDate != date {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .font(.footnote)
                            Text("Last changed \(changeDate.formatted(.relative(presentation: .named)))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    Text("Not yet synced")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(6)
    }
}

// MARK: - iCloud Sync Help Sheet

struct ICloudSyncHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private struct Requirement: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let detail: String
    }

    private let requirements: [Requirement] = [
        Requirement(id: 1, icon: "person.crop.circle.badge.checkmark", title: "Same Apple ID", detail: "All devices must be signed in with the same Apple ID."),
        Requirement(id: 2, icon: "externaldrive.connected.to.line.below", title: "iCloud Drive enabled", detail: "Go to Settings → [your name] → iCloud → iCloud Drive and make sure it is on."),
        Requirement(id: 3, icon: "arrow.clockwise.icloud", title: "Block-Time allowed", detail: "In the Saved to iCloud app list, make sure Block-Time is toggled on."),
        Requirement(id: 4, icon: "internaldrive", title: "iCloud storage not full", detail: "Check your storage at Settings → [your name] → iCloud → Storage."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Blue accent banner
                    HStack(spacing: 12) {
                        Image(systemName: "icloud.fill")
                            .font(.title2)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("For sync to work across devices")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("all of the following must be true:")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.blue)

                    // First sync note
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "clock")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 1)
                        Text("The first sync can take a few minutes and may happen in stages — this is normal.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Requirements list
                    VStack(spacing: 0) {
                        ForEach(requirements) { req in
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: req.icon)
                                        .font(.footnote)
                                        .foregroundColor(.blue)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(req.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text(req.detail)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            if req.id < requirements.count {
                                Divider().padding(.leading, 66)
                            }
                        }
                    }
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                    )
                    .padding(16)

                    // Learn More link row
                    Button {
                        if let url = URL(string: "https://block-time.app/guide/backup-and-sync.html") {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "safari")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text("Learn more in the User Guide")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundColor(.blue.opacity(0.7))
                        }
                        .padding(14)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("iCloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
