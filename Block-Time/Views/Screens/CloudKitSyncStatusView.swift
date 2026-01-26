////
////  CloudKitSyncStatusView.swift
////  Logger
////
////  Created by Nelson Code on 3/10/2025.
////UNUSED CODE
//
//import SwiftUI
//
///// View to display CloudKit sync status for both database and settings
//struct CloudKitSyncStatusView: View {
//    @ObservedObject var databaseService = FlightDatabaseService.shared
//    @ObservedObject var settingsService = CloudKitSettingsSyncService.shared
//    @AppStorage("debugModeEnabled") private var debugModeEnabled = false
//
//    var body: some View {
//        VStack(spacing: 20) {
//            // Debug indicator (always visible to verify the toggle is working)
//            Text("Debug Mode: \(debugModeEnabled ? "ON" : "OFF")")
//                .font(.caption2)
//                .foregroundColor(debugModeEnabled ? .green : .secondary)
//                .padding(4)
//
//            // Cloud availability status
//            if !settingsService.isCloudAvailable() {
//                HStack {
//                    Image(systemName: "exclamationmark.icloud")
//                        .foregroundColor(.orange)
//                    Text("iCloud not available. Please sign in to iCloud in Settings.")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//                .padding()
//                .background(Color.orange.opacity(0.1))
//                .cornerRadius(8)
//            }
//
//            // Database sync status
//            SyncSection(
//                title: "Flight Database Sync",
//                isSyncing: databaseService.isSyncing,
//                lastSyncDate: databaseService.lastSyncDate,
//                lastChangeDate: nil,
//                lastSyncError: databaseService.lastSyncError,
//                detailedSyncError: databaseService.detailedSyncError,
//                icon: "airplane"
//            )
//
//            // Settings sync status
//            SyncSection(
//                title: "Settings Sync",
//                isSyncing: settingsService.isSyncing,
//                lastSyncDate: settingsService.lastSyncDate,
//                lastChangeDate: settingsService.lastChangeDate,
//                lastSyncError: settingsService.lastSyncError,
//                detailedSyncError: nil, // Settings service doesn't have detailed errors yet
//                icon: "gearshape"
//            )
//
//            // Manual sync buttons
//            VStack(spacing: 12) {
//                Button(action: {
//                    settingsService.syncToCloud()
//                }) {
//                    HStack {
//                        Image(systemName: "icloud.and.arrow.up")
//                        Text("Upload Settings to iCloud")
//                    }
//                    .frame(maxWidth: .infinity)
//                }
//                .buttonStyle(.bordered)
//
//                Button(action: {
//                    settingsService.syncFromCloud()
//                }) {
//                    HStack {
//                        Image(systemName: "icloud.and.arrow.down")
//                        Text("Download Settings from iCloud")
//                    }
//                    .frame(maxWidth: .infinity)
//                }
//                .buttonStyle(.bordered)
//            }
//            .padding(.top)
//
//            // Info section
//            VStack(alignment: .leading, spacing: 8) {
//                Text("About CloudKit Sync")
//                    .font(.headline)
//
//                Text("• Flight data syncs automatically across all your devices")
//                Text("• Settings sync via iCloud Key-Value Store")
//                Text("• Conflicts are resolved using most recent changes")
//                Text("• Requires iCloud account and internet connection")
//            }
//            .font(.caption)
//            .foregroundColor(.secondary)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .padding()
//            .background(Color(.systemGray6).opacity(0.75))
//            .cornerRadius(8)
//
//            // Debug testing section (only visible when Debug Mode is enabled in Settings)
//            if debugModeEnabled {
//                VStack(alignment: .leading, spacing: 12) {
//                    Text("Debug: Error Simulation")
//                        .font(.headline)
//                        .foregroundColor(.orange)
//
//                    Text("Test the error UI by simulating sync failures")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//
//                    HStack(spacing: 12) {
//                        Button(action: {
//                            databaseService.simulatePartialSyncFailure()
//                        }) {
//                            VStack {
//                                Image(systemName: "exclamationmark.triangle.fill")
//                                Text("Partial Failure")
//                                    .font(.caption2)
//                            }
//                            .frame(maxWidth: .infinity)
//                        }
//                        .buttonStyle(.bordered)
//                        .tint(.orange)
//
//                        Button(action: {
//                            databaseService.simulateNetworkError()
//                        }) {
//                            VStack {
//                                Image(systemName: "wifi.slash")
//                                Text("Network Error")
//                                    .font(.caption2)
//                            }
//                            .frame(maxWidth: .infinity)
//                        }
//                        .buttonStyle(.bordered)
//                        .tint(.orange)
//
//                        Button(action: {
//                            databaseService.clearSimulatedErrors()
//                        }) {
//                            VStack {
//                                Image(systemName: "checkmark.circle.fill")
//                                Text("Clear Errors")
//                                    .font(.caption2)
//                            }
//                            .frame(maxWidth: .infinity)
//                        }
//                        .buttonStyle(.bordered)
//                        .tint(.green)
//                    }
//                }
//                .padding()
//                .background(Color.orange.opacity(0.1))
//                .cornerRadius(8)
//            }
//        }
//        .padding()
//    }
//}
//
///// Reusable section for displaying sync status
//struct SyncSection: View {
//    let title: String
//    let isSyncing: Bool
//    let lastSyncDate: Date?
//    let lastChangeDate: Date?
//    let lastSyncError: Error?
//    let detailedSyncError: DetailedSyncError?
//    let icon: String
//
//    @State private var showErrorDetails = false
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Image(systemName: icon)
//                    .foregroundColor(.blue)
//                Text(title)
//                    .font(.headline)
//                Spacer()
//                if isSyncing {
//                    ProgressView()
//                        .scaleEffect(0.8)
//                }
//            }
//
//            if let error = lastSyncError {
//                let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: error)
//
//                VStack(alignment: .leading, spacing: 6) {
//                    HStack(alignment: .top, spacing: 8) {
//                        Image(systemName: errorInfo.isRetryable ? "exclamationmark.triangle" : "exclamationmark.circle")
//                            .foregroundColor(errorInfo.isRetryable ? .orange : .red)
//                            .font(.subheadline)
//
//                        VStack(alignment: .leading, spacing: 3) {
//                            Text(errorInfo.message)
//                                .font(.subheadline)
//                                .fontWeight(.medium)
//                                .foregroundColor(errorInfo.isRetryable ? .orange : .red)
//
//                            Text(errorInfo.suggestion)
//                                .font(.caption)
//                                .foregroundColor(.secondary)
//                                .fixedSize(horizontal: false, vertical: true)
//                        }
//                    }
//
//                    // Show retry indicator if applicable
//                    if errorInfo.isRetryable {
//                        HStack(spacing: 4) {
//                            Image(systemName: "arrow.clockwise")
//                                .font(.caption2)
//                            Text("Will retry automatically")
//                                .font(.caption2)
//                        }
//                        .foregroundColor(.secondary)
//                        .padding(.top, 2)
//                    }
//
//                    // Always show technical details button if we have detailed error information
//                    if let detailedError = detailedSyncError {
//                        Button(action: {
//                            withAnimation {
//                                showErrorDetails.toggle()
//                            }
//                        }) {
//                            HStack(spacing: 4) {
//                                Text(showErrorDetails ? "Hide Technical Details" : "Show Technical Details")
//                                    .font(.caption)
//                                    .fontWeight(.medium)
//                                Image(systemName: showErrorDetails ? "chevron.up" : "chevron.down")
//                                    .font(.caption2)
//                            }
//                            .foregroundColor(.blue)
//                        }
//                        .padding(.top, 4)
//
//                        // Expandable error details
//                        if showErrorDetails {
//                            VStack(alignment: .leading, spacing: 8) {
//                                Divider()
//                                    .padding(.vertical, 4)
//
//                                // Show individual errors if available
//                                if detailedError.hasIndividualErrors {
//                                    Text("Failed Items (\(detailedError.individualErrors.count))")
//                                        .font(.caption)
//                                        .fontWeight(.semibold)
//                                        .foregroundColor(.secondary)
//
//                                    ForEach(Array(detailedError.individualErrors.enumerated()), id: \.offset) { index, errorItem in
//                                        VStack(alignment: .leading, spacing: 4) {
//                                            Text("Record: \(errorItem.recordID)")
//                                                .font(.caption2)
//                                                .fontWeight(.medium)
//                                                .foregroundColor(.primary)
//                                                .fixedSize(horizontal: false, vertical: true)
//
//                                            let itemErrorInfo = CloudKitErrorHelper.userFriendlyMessage(for: errorItem.error)
//                                            Text(itemErrorInfo.message)
//                                                .font(.caption2)
//                                                .foregroundColor(itemErrorInfo.isRetryable ? .orange : .red)
//
//                                            Text(itemErrorInfo.suggestion)
//                                                .font(.caption2)
//                                                .foregroundColor(.secondary)
//                                                .fixedSize(horizontal: false, vertical: true)
//                                        }
//                                        .padding(.vertical, 4)
//
//                                        if index < detailedError.individualErrors.count - 1 {
//                                            Divider()
//                                        }
//                                    }
//
//                                    Divider()
//                                        .padding(.vertical, 4)
//                                }
//
//                                // Always show technical error details
//                                VStack(alignment: .leading, spacing: 6) {
//                                    Text("Technical Details")
//                                        .font(.caption)
//                                        .fontWeight(.semibold)
//                                        .foregroundColor(.secondary)
//
//                                    Group {
//                                        HStack(alignment: .top) {
//                                            Text("Error Domain:")
//                                                .font(.caption2)
//                                                .fontWeight(.medium)
//                                                .foregroundColor(.secondary)
//                                                .frame(width: 110, alignment: .leading)
//                                            Text(detailedError.errorDomain)
//                                                .font(.system(.caption2, design: .monospaced))
//                                                .foregroundColor(.primary)
//                                            Spacer()
//                                        }
//
//                                        HStack(alignment: .top) {
//                                            Text("Error Code:")
//                                                .font(.caption2)
//                                                .fontWeight(.medium)
//                                                .foregroundColor(.secondary)
//                                                .frame(width: 110, alignment: .leading)
//                                            Text("\(detailedError.errorCode)")
//                                                .font(.system(.caption2, design: .monospaced))
//                                                .foregroundColor(.primary)
//                                            Spacer()
//                                        }
//
//                                        HStack(alignment: .top) {
//                                            Text("Operation:")
//                                                .font(.caption2)
//                                                .fontWeight(.medium)
//                                                .foregroundColor(.secondary)
//                                                .frame(width: 110, alignment: .leading)
//                                            Text(detailedError.operation)
//                                                .font(.system(.caption2, design: .monospaced))
//                                                .foregroundColor(.primary)
//                                            Spacer()
//                                        }
//
//                                        HStack(alignment: .top) {
//                                            Text("Timestamp:")
//                                                .font(.caption2)
//                                                .fontWeight(.medium)
//                                                .foregroundColor(.secondary)
//                                                .frame(width: 110, alignment: .leading)
//                                            Text(detailedError.timestamp.formatted(date: .numeric, time: .standard))
//                                                .font(.system(.caption2, design: .monospaced))
//                                                .foregroundColor(.primary)
//                                            Spacer()
//                                        }
//
//                                        HStack(alignment: .top) {
//                                            Text("Description:")
//                                                .font(.caption2)
//                                                .fontWeight(.medium)
//                                                .foregroundColor(.secondary)
//                                                .frame(width: 110, alignment: .leading)
//                                            Text(detailedError.rawErrorDescription)
//                                                .font(.system(.caption2, design: .monospaced))
//                                                .foregroundColor(.primary)
//                                                .fixedSize(horizontal: false, vertical: true)
//                                            Spacer()
//                                        }
//
//                                        // Show userInfo if available
//                                        if !detailedError.errorUserInfo.isEmpty {
//                                            Divider()
//                                                .padding(.vertical, 2)
//
//                                            Text("Additional Info:")
//                                                .font(.caption)
//                                                .fontWeight(.semibold)
//                                                .foregroundColor(.secondary)
//
//                                            ForEach(Array(detailedError.errorUserInfo.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
//                                                HStack(alignment: .top) {
//                                                    Text("\(key):")
//                                                        .font(.caption2)
//                                                        .fontWeight(.medium)
//                                                        .foregroundColor(.secondary)
//                                                        .frame(width: 110, alignment: .leading)
//                                                    Text(value)
//                                                        .font(.system(.caption2, design: .monospaced))
//                                                        .foregroundColor(.primary)
//                                                        .fixedSize(horizontal: false, vertical: true)
//                                                    Spacer()
//                                                }
//                                            }
//                                        }
//                                    }
//                                }
//                            }
//                            .padding(.top, 8)
//                        }
//                    }
//                }
//                .padding(8)
//                .background(errorInfo.isRetryable ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
//                .cornerRadius(6)
//            } else if let syncDate = lastSyncDate {
//                VStack(alignment: .leading, spacing: 4) {
//                    HStack {
//                        Image(systemName: "checkmark.icloud")
//                            .foregroundColor(.green)
//                        Text("Last synced: \(syncDate.formatted(.relative(presentation: .named)))")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//
//                    if let changeDate = lastChangeDate, changeDate != syncDate {
//                        HStack {
//                            Image(systemName: "pencil.circle")
//                                .foregroundColor(.blue)
//                            Text("Last changed: \(changeDate.formatted(.relative(presentation: .named)))")
//                                .font(.caption)
//                                .foregroundColor(.secondary)
//                        }
//                    }
//                }
//            } else {
//                HStack {
//                    Image(systemName: "icloud")
//                        .foregroundColor(.gray)
//                    Text("Not yet synced")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//            }
//        }
//        .padding()
//        .background(Color(.systemGray6).opacity(0.75))
//        .cornerRadius(8)
//    }
//}
//
//#Preview {
//    CloudKitSyncStatusView()
//}
