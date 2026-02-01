//
//  AboutView.swift
//  Block-Time
//
//  Created by Nelson on 29/11/2025.
//

import SwiftUI

struct AboutView: View {
    @ObservedObject private var themeService = ThemeService.shared
    @AppStorage("debugModeEnabled") private var debugModeEnabled = false
    @State private var showingLogViewer = false
    @State private var devToolsExpanded = false
    @State private var versionTapCount = 0

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
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                versionTapCount += 1
                                if versionTapCount >= 10 {
                                    devToolsExpanded = true
                                    HapticManager.shared.notification(.success)
                                }
                            }

                        Spacer(minLength: 20)

                        VStack(spacing: 8){
                            Text("support@block-time.app")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("www.block-time.app")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 20)

                // Push content down
                Spacer(minLength: 40)

                // Developer Tools Card - Collapsible (Hidden in production, unlocked with secret tap)
//                #if DEBUG
//                let showDebugTools = true
//                #else
                let showDebugTools = versionTapCount >= 10
//                #endif

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
                                    Text("iCloud & DB Debug")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text("Don't Use Unless Directed")
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
                                Text("Debug buttons will appear in iCloud Sync Status")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 8)
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
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingLogViewer) {
            LogViewerView()
        }
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}
