//
//  SupportView.swift
//  Block-Time
//
//  Created by Nelson on 29/11/2025.
//

import SwiftUI

struct SupportView: View {
    @Environment(ThemeService.self) private var themeService
    @AppStorage("debugModeEnabled") private var debugModeEnabled = false
    @State private var showingLogViewer = false
    @State private var devToolsExpanded = false
    @State private var versionTapCount = 0
    @State private var showingRecalculateConfirm = false
    @State private var isRecalculating = false
    @State private var recalculateResult: String?
    @State private var showingUUIDRegenerationAlert = false
    @State private var uuidRegenerationMessage = ""

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon and Name
                VStack(spacing: 16) {
                    if let uiImage = UIImage(named: "SplashIcon") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                    } else {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                    }

                    VStack(spacing: 4) {
                        Text("Block-Time")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Version \(appVersion).\(buildNumber)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                versionTapCount += 1
                                if versionTapCount >= 10 {
                                    //devToolsExpanded = true
                                    HapticManager.shared.notification(.success)
                                }
                            }

                        Spacer(minLength: 20)

                        VStack(spacing: 20){
                            Link("Online User Guide", destination: URL(string: "https://block-time.app/guide/")!)
                                .foregroundColor(.blue)
                                .font(.title3.bold())
                                
                            Link("Email Support", destination: URL(string: "mailto:support@block-time.app")!)
                                .foregroundColor(.blue)
                                .font(.title3.bold())
                        }
                    }
                }
                .padding(.top, 20)

                // Push content down
                Spacer(minLength: 40)

                // Debug Tools Requires 10 taps to unhide
                let showDebugTools = versionTapCount >= 10
                
                if showDebugTools {
                    DisclosureGroup(
                    isExpanded: $devToolsExpanded,
                    content: {
                        VStack(spacing: 8) {
                            // View Logs Button
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                showingLogViewer = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("View App Logs")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("View, filter, and share diagnostic logs")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(Color(.systemGray6).opacity(0.5))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Debug Mode Toggle
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.icloud")
                                    .foregroundColor(.orange)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("iCloud Debug")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text("Shows error simulation in iCloud Sync Status")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: $debugModeEnabled)
                                    .labelsHidden()
                                    .scaleEffect(0.8)
                            }
                            .padding(12)
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(8)

                            if debugModeEnabled {
                                Text("Error simulation buttons will appear in iCloud Sync Status")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.center)
                            }

                            // Recalculate Block Times Button
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                showingRecalculateConfirm = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: isRecalculating ? "hourglass" : "arrow.triangle.2.circlepath")
                                        .foregroundColor(.blue)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Recalculate All Block Times")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("Fix inconsistent block times from OUT/IN")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if isRecalculating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .padding(12)
                                .background(Color(.orange).opacity(0.5))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isRecalculating)

                            // Show result if available
                            if let result = recalculateResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }

                            // Regenerate UUIDs Button
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                let result = FlightDatabaseService.shared.regenerateAllFlightUUIDs()
                                var message = "Updated \(result.updatedCount) flights\nRemoved \(result.duplicatesRemoved) duplicates"
                                if !result.duplicatesList.isEmpty {
                                    message += "\n\nDuplicates removed:"
                                    for duplicate in result.duplicatesList.prefix(10) {
                                        message += "\n• \(duplicate)"
                                    }
                                    if result.duplicatesList.count > 10 {
                                        message += "\n... and \(result.duplicatesList.count - 10) more"
                                    }
                                }
                                uuidRegenerationMessage = message
                                showingUUIDRegenerationAlert = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.blue)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Regen UUIDs & Remove Duplicates")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("Fixes duplicate flights and regenerates identifiers")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(.orange).opacity(0.5))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 8)
                        .alert("UUID Regeneration Complete", isPresented: $showingUUIDRegenerationAlert) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text(uuidRegenerationMessage)
                        }
                    },
                    label: {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.orange)
                                .frame(width: 20)

                            Text("Debug Tools")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    )
                    .padding(16)
                    .background(.thinMaterial)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                    .alert("Recalculate Block Times?", isPresented: $showingRecalculateConfirm) {
                        Button("Cancel", role: .cancel) { }
                        Button("Recalculate", role: .destructive) {
                            performRecalculation()
                        }
                    } message: {
                        Text("This will recalculate block times from OUT and IN times for all regular flights. Use this to fix data imported from other sources or ensure consistency. SIM and PAX flights will be skipped. This operation cannot be undone.")
                    }
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingLogViewer) {
            LogViewerView()
        }
    }

    // MARK: - Helper Methods

    private func performRecalculation() {
        isRecalculating = true
        recalculateResult = nil
        HapticManager.shared.impact(.medium)

        // Perform recalculation in background
        DispatchQueue.global(qos: .userInitiated).async {
            let result = FlightDatabaseService.shared.recalculateAllBlockTimes()

            DispatchQueue.main.async {
                isRecalculating = false
                recalculateResult = "✅ Updated: \(result.success) | Skipped: \(result.skipped) | Errors: \(result.errors)"
                HapticManager.shared.notification(.success)

                // Clear result after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    withAnimation {
                        recalculateResult = nil
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SupportView()
    }
    .environment(ThemeService.shared)
}
