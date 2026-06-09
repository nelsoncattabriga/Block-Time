//
//  SupportView.swift
//  Block-Time
//
//  Created by Nelson on 29/11/2025.
//

import SwiftUI
import CoreData

struct SupportView: View {
    @Environment(ThemeService.self) private var themeService
    @Environment(PurchaseService.self) private var purchaseService
    @State private var showingLogViewer = false
    @State private var showingRawDatabase = false
    @State private var devToolsExpanded = false
    @State private var showingDebugHelp = false

    @State private var showingRecalculateConfirm = false
    @State private var isRecalculating = false
    @State private var recalculateResult: String?
    @State private var showingResetCrewNamesConfirm = false
    @State private var resetCrewNamesMessage: String?
    @State private var showingNormaliseAirportsConfirm = false
    @State private var isNormalisingAirports = false
    @State private var normaliseAirportsResult: String?

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

                        if !purchaseService.isPro {
                            Text("TRIAL")
                                .font(.caption)
                                .fontWeight(.heavy)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.75), in: Capsule())
                        }

                        Text("Version \(appVersion).\(buildNumber)")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer(minLength: 20)

                        VStack(spacing: 20){
                            Link("Email Support", destination: URL(string: "mailto:support@block-time.app")!)
                                .foregroundColor(.blue)
                                .font(.title3.bold())
                        }
                    }
                }
                .padding(.top, 20)

                // Push content down
                Spacer(minLength: 40)

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

                            // Raw Database Viewer
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                showingRawDatabase = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "tablecells")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("View Raw Database Entries")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("Browse and delete raw Core Data records")
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

                            // Reset Crew Names
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                showingResetCrewNamesConfirm = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.2.slash")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Reset Crew Names")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("Clear saved names and rebuild from logbook")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(.systemGray6).opacity(0.5))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Recalculate Block Times Button
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                showingRecalculateConfirm = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: isRecalculating ? "hourglass" : "arrow.triangle.2.circlepath")
                                        .foregroundColor(.orange)
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
                                .background(Color(.systemGray6).opacity(0.5))
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

                            // Normalise Airport Codes Button
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                showingNormaliseAirportsConfirm = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: isNormalisingAirports ? "hourglass" : "mappin.and.ellipse")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Normalise Airport Codes")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("Convert any IATA codes stored in your logbook to ICAO")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if isNormalisingAirports {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .padding(12)
                                .background(Color(.systemGray6).opacity(0.5))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isNormalisingAirports)

                            if let result = normaliseAirportsResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }

                        }
                        .padding(.top, 8)
                    },
                    label: {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.orange)
                                .frame(width: 20)

                            Text("Advanced Tools")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Spacer()

                            Button {
                                showingDebugHelp = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
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
                .sheet(isPresented: $showingDebugHelp) {
                    DebugToolsHelpSheet()
                }
                .alert("Recalculate Block Times?", isPresented: $showingRecalculateConfirm) {
                    Button("Cancel", role: .cancel) { }
                    Button("Recalculate", role: .destructive) {
                        performRecalculation()
                    }
                } message: {
                    Text("This will recalculate block times from OUT and IN times for all regular flights. Use this to fix data imported from other sources or ensure consistency. SIM and PAX flights will be skipped. Run a Backup first to save your current data.")
                }
                .alert("Reset Crew Names?", isPresented: $showingResetCrewNamesConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        resetCrewNamesFromLogbook()
                    }
                } message: {
                    Text("This will clear all saved crew names and rebuild the list from your logbook. Any manually added names not linked to a flight will be removed.")
                }
                .alert("Crew Names Reset", isPresented: Binding(get: { resetCrewNamesMessage != nil }, set: { if !$0 { resetCrewNamesMessage = nil } })) {
                    Button("OK", role: .cancel) { resetCrewNamesMessage = nil }
                } message: {
                    Text(resetCrewNamesMessage ?? "")
                }
                .alert("Normalise Airport Codes?", isPresented: $showingNormaliseAirportsConfirm) {
                    Button("Cancel", role: .cancel) { }
                    Button("Normalise", role: .destructive) {
                        performAirportNormalisation()
                    }
                } message: {
                    Text("This will convert any IATA airport codes (e.g. SYD) stored in your logbook to their ICAO equivalents (e.g. YSSY). Airports not found in the database will be left unchanged. Run a Backup first.")
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
        .navigationDestination(isPresented: $showingRawDatabase) {
            RawDatabaseView()
                .environment(\.managedObjectContext, FlightDatabaseService.shared.persistentContainer.viewContext)
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
    private func performAirportNormalisation() {
        isNormalisingAirports = true
        normaliseAirportsResult = nil
        HapticManager.shared.impact(.medium)

        DispatchQueue.global(qos: .userInitiated).async {
            let result = FlightDatabaseService.shared.normaliseAirportCodes()

            DispatchQueue.main.async {
                isNormalisingAirports = false
                normaliseAirportsResult = "Updated \(result.fixed) of \(result.total) flights"
                HapticManager.shared.notification(.success)

                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    withAnimation { normaliseAirportsResult = nil }
                }
            }
        }
    }

    private func resetCrewNamesFromLogbook() {
        let db = FlightDatabaseService.shared
        let uds = UserDefaultsService()

        let captains = db.getAllCaptainNames()
        let fos = db.getAllFONames()
        let sos = db.getAllSONames()
        let rebuilt = Array(Set(captains + fos + sos)).sorted()

        var settings = uds.loadSettings()
        settings.savedCrewNames = rebuilt
        uds.saveSettings(settings)

        resetCrewNamesMessage = "Rebuilt \(rebuilt.count) crew name\(rebuilt.count == 1 ? "" : "s") from your logbook."
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Advanced Tools Help Sheet

private struct DebugToolsHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.title2)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Advanced Tools")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("Recovery and diagnostic tools for your logbook.")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.orange)

                    VStack(spacing: 12) {
                        infoBlock(
                            icon: "doc.text.magnifyingglass",
                            title: "View App Logs",
                            body: "Shows a live log of app activity. Use this if support asks for a diagnostic log by sharing the file directly from this screen."
                        )

                        infoBlock(
                            icon: "tablecells",
                            title: "View Raw Database",
                            body: "Displays every flight record stored in the database. Useful for troubleshooting databse corruption. Individual records can be deleted from here."
                        )

                        infoBlock(
                            icon: "person.2.slash",
                            title: "Reset Crew Names",
                            body: "Clears the saved crew name suggestions and rebuilds them from the names recorded in your logbook. Use this if autocomplete is showing names that are no longer relevant or if the list has become cluttered after a data import."
                        )

                        infoBlock(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Recalculate All Block Times",
                            body: "Recalculates block time from OUT and IN times for every regular flight. Use this if block times look wrong after a CSV import or a data migration. SIM and PAX flights are skipped. This cannot be undone."
                        )

                        infoBlock(
                            icon: "mappin.and.ellipse",
                            title: "Normalise Airport Codes",
                            body: "Scans every flight in your logbook and converts any IATA airport codes (e.g. SYD) to their ICAO equivalents (e.g. YSSY). Airports not found in the database are left unchanged. Safe to run multiple times."
                        )
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Advanced Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func infoBlock(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.orange)
                .frame(width: 20, alignment: .top)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(body)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        SupportView()
    }
    .environment(ThemeService.shared)
}
