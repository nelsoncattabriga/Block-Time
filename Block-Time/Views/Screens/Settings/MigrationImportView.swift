//
//  MigrationImportView.swift
//  Block-Time
//
//  UI for importing data migrated from Logger
//

import SwiftUI
import UIKit
import CoreData
import UniformTypeIdentifiers

struct MigrationImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userDefaultsService = UserDefaultsService()

    // Optional preselected file URL (for "Open in Block-Time" feature)
    let preselectedFileURL: URL?

    // Optional completion callback (for onboarding flow)
    var onComplete: (() -> Void)? = nil

    // Optional dismissal callback (called when view is dismissed without completing)
    var onDismiss: (() -> Void)? = nil

    // Flag to indicate if this is being shown during onboarding
    let isOnboarding: Bool

    @State private var isImporting = false
    @State private var importComplete = false
    @State private var importSummary: ImportSummary?
    @State private var importError: String?
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var importMode: ImportMode = .merge
    @State private var importProgress: MigrationProgress?

    init(preselectedFileURL: URL? = nil, onComplete: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil, isOnboarding: Bool = false) {
        self.preselectedFileURL = preselectedFileURL
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        self.isOnboarding = isOnboarding
        // When onboarding, always use replace mode
        if isOnboarding {
            _importMode = State(initialValue: .replace)
        }
    }

    enum ImportMode: String, CaseIterable {
        case merge = "Merge with existing data"
        case replace = "Replace all existing data"

        var icon: String {
            switch self {
            case .merge: return "arrow.triangle.merge"
            case .replace: return "arrow.triangle.swap"
            }
        }

        var description: String {
            switch self {
            case .merge:
                return "Keeps your existing flights and adds imported flights"
            case .replace:
                return "⚠️ Deletes all existing data and replaces with imported data"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if importComplete, let summary = importSummary {
                        // Import Success View
                        importSuccessView(summary: summary)
                    } else if isImporting {
                        // Import Progress View
                        importProgressView
                    } else {
                        // Import Setup View
                        importSetupView
                    }
                }
            }
//            .navigationTitle("Migrate from Logger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss?()
                        dismiss()
                    }
                    .disabled(isImporting)
                }
            }
            .alert("Import Error", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) {
                    importError = nil
                }
            } message: {
                if let error = importError {
                    Text(error)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "blocktime") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result: result)
            }
            .onAppear {
                // If a file was preselected (via "Open in Block-Time"), copy it to temp storage
                if let preselectedURL = preselectedFileURL {
                    handlePreselectedFile(url: preselectedURL)
                }
            }
        }
    }

    // MARK: - Import Setup View

    private var importSetupView: some View {
        VStack(spacing: 24) {
            // Header with migration icon
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Migrate from Logger")
                    .font(.title2)
                    .fontWeight(.bold)

//                Text("Migrate your complete logbook data")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Migration Info Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("What will be imported:")
                        .font(.headline)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    MigrationInfoRow(
                        icon: "airplane.departure",
                        text: "All flight records",
                        detail: "Complete logbook history"
                    )

                    MigrationInfoRow(
                        icon: "gear",
                        text: "Settings & Preferences",
                        detail: "Crew defaults, display options"
                    )

                    MigrationInfoRow(
                        icon: "icloud",
                        text: "Sync Settings",
                        detail: "Recent entries, FRMS config"
                    )

                    MigrationInfoRow(
                        icon: "airplane",
                        text: "Aircraft Registry",
                        detail: "All saved aircraft"
                    )
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            // Import Mode Selection (hidden during onboarding)
            if !isOnboarding {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.blue)
                        Text("Import Mode:")
                            .font(.headline)
                        Spacer()
                    }

                    ForEach(ImportMode.allCases, id: \.self) { mode in
                        ImportModeCard(
                            mode: mode,
                            isSelected: importMode == mode,
                            onTap: {
                                importMode = mode
                            }
                        )
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // File Selection Info
            if let fileURL = selectedFileURL {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("File Selected:")
                            .font(.headline)
                        Spacer()
                    }

                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.orange)
                        Text(fileURL.lastPathComponent)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.leading, 24)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

//            Spacer()
//                .frame(maxHeight: 20)

            // Action Buttons
            VStack(spacing: 12) {

                // Import Button
                Button(action: {
                    performMigrationImport()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Import Data")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedFileURL == nil ? Color.gray : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedFileURL == nil)
                .padding(.horizontal)

                // Select File Button
                Button(action: {
                    showFilePicker = true
                }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text(selectedFileURL == nil ? "Select Migration File" : "Choose Different File")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }

    // MARK: - Import Progress View

    private var importProgressView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated Icon
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 70))
                .foregroundColor(.orange)
                .symbolEffect(.rotate, options: .repeating, value: isImporting)

            // Progress Information
            VStack(spacing: 16) {
                Text("Importing Your Data")
                    .font(.title2)
                    .fontWeight(.bold)

                if let progress = importProgress {
                    VStack(spacing: 12) {
                        // Progress Bar
                        ProgressView(value: progress.percentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                            .scaleEffect(y: 2)
                            .padding(.horizontal, 40)

                        // Phase and Message
                        VStack(spacing: 4) {
                            Text(progress.phase.rawValue)
                                .font(.headline)
                                .foregroundColor(.orange)

                            Text(progress.message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Item Count
                        if progress.totalItems > 0 {
                            Text("\(progress.currentItem) of \(progress.totalItems)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()

            // Warning message
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Please wait - do not close the app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Import Success View

    private func importSuccessView(summary: ImportSummary) -> some View {
        VStack(spacing: 24) {
            // Success Icon with animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.green)
                .padding(.top)
                .symbolEffect(.bounce, value: importComplete)

            // Summary
            VStack(spacing: 8) {
                Text("Migration Complete!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Your data has been successfully imported")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Detailed Import Statistics Card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Import Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))

                Divider()

                // Statistics
                VStack(spacing: 0) {
                    MigrationStatRow(
                        icon: "airplane.departure",
                        label: "Flights Imported",
                        value: "\(summary.flightsImported)",
                        color: .blue
                    )

                    Divider()
                        .padding(.leading, 56)

                    MigrationStatRow(
                        icon: "airplane",
                        label: "Aircraft Imported",
                        value: "\(summary.aircraftImported)",
                        color: .purple
                    )

                    Divider()
                        .padding(.leading, 56)

                    MigrationStatRow(
                        icon: "gearshape.2.fill",
                        label: "Settings",
                        value: summary.settingsRestored ? "✓ Restored" : "✗ Not restored",
                        color: summary.settingsRestored ? .green : .orange
                    )

                    Divider()
                        .padding(.leading, 56)

                    MigrationStatRow(
                        icon: "slider.horizontal.3",
                        label: "Preferences",
                        value: summary.preferencesRestored ? "✓ Restored" : "✗ Not restored",
                        color: summary.preferencesRestored ? .green : .orange
                    )

                    Divider()
                        .padding(.leading, 56)

                    MigrationStatRow(
                        icon: "app.badge.checkmark.fill",
                        label: "Source",
                        value: summary.sourceApp,
                        color: .indigo
                    )
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
            )
            .padding(.horizontal)

            // Next Steps Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.blue)
                    Text("Next Steps:")
                        .font(.headline)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    NextStepRow(number: 1, text: "Review your imported flights in the Logbook")
                    NextStepRow(number: 2, text: "Check your settings are correct")
                    
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            // Done Button
            Button(action: {
                // Call completion callback if provided (for onboarding flow)
                onComplete?()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Done")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Actions

    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Unable to access the selected file"
                LogManager.shared.error("Failed to access security-scoped resource")
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            // Copy file to temp directory so we have persistent access
            // Use NSFileCoordinator for File Provider support (iCloud, OneDrive, etc.)
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?

            coordinator.coordinate(readingItemAt: url, options: .forUploading, error: &coordinatorError) { sourceURL in
                do {
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)

                    // Remove existing temp file if it exists
                    if FileManager.default.fileExists(atPath: tempFile.path) {
                        try FileManager.default.removeItem(at: tempFile)
                    }

                    // Copy the file (sourceURL is guaranteed to exist after coordination)
                    try FileManager.default.copyItem(at: sourceURL, to: tempFile)

                    // Store the temp file URL (we own this, no security scoping needed)
                    DispatchQueue.main.async {
                        self.selectedFileURL = tempFile
                        LogManager.shared.info("📁 Selected migration file: \(url.lastPathComponent)")
                        LogManager.shared.debug("📁 Copied to temp: \(tempFile.path)")
                    }

                } catch {
                    DispatchQueue.main.async {
                        self.importError = "Failed to copy migration file: \(error.localizedDescription)"
                        LogManager.shared.error("File copy error: \(error)")
                    }
                }
            }

            // Check for coordinator error
            if let error = coordinatorError {
                importError = "Failed to access file: \(error.localizedDescription)"
                LogManager.shared.error("File coordinator error: \(error)")
            }

        case .failure(let error):
            importError = "Failed to select file: \(error.localizedDescription)"
            LogManager.shared.error("File selection error: \(error)")
        }
    }

    // Handle preselected file URL (from "Open in Block-Time" share sheet)
    private func handlePreselectedFile(url: URL) {
        LogManager.shared.info("📁 Handling preselected migration file: \(url.lastPathComponent)")
        LogManager.shared.debug("📁 File URL path: \(url.path)")

        // Try to start accessing security-scoped resource
        // Note: This may return false if the file doesn't need scoping (e.g., already in app container)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        LogManager.shared.debug("Security scoped access: \(didStartAccessing)")

        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Copy file to temp directory so we have persistent access
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)

            // Remove existing temp file if it exists
            if FileManager.default.fileExists(atPath: tempFile.path) {
                try FileManager.default.removeItem(at: tempFile)
            }

            // Copy the file
            try FileManager.default.copyItem(at: url, to: tempFile)

            // Store the temp file URL (we own this, no security scoping needed)
            selectedFileURL = tempFile
            LogManager.shared.info("✅ Preselected file copied to temp: \(tempFile.path)")

        } catch {
            importError = "Failed to prepare migration file: \(error.localizedDescription)"
            LogManager.shared.error("File copy error: \(error)")
        }
    }

    private func performMigrationImport() {
        guard let fileURL = selectedFileURL else {
            importError = "Please select a migration file first"
            return
        }

        isImporting = true
        importError = nil

        // Set progress callback
        MigrationImportService.shared.progressCallback = { progress in
            // Progress updates already happen on main thread in the service
            importProgress = progress
        }

        // Perform import
        let replaceExisting = (importMode == .replace)

        MigrationImportService.shared.importFromMigration(
            fileURL: fileURL,
            replaceExisting: replaceExisting
        ) { result in
            DispatchQueue.main.async {
                isImporting = false

                // Clean up temp file
                self.cleanupTempFile(fileURL)

                switch result {
                case .success(let summary):
                    importSummary = summary
                    importComplete = true
                    LogManager.shared.info("✅ Migration import completed successfully")

                case .failure(let error):
                    importError = error.localizedDescription
                    LogManager.shared.error("❌ Migration import failed: \(error)")
                }
            }
        }
    }

    private func cleanupTempFile(_ url: URL) {
        // Only delete if it's in temp directory
        let tempDir = FileManager.default.temporaryDirectory.path
        if url.path.hasPrefix(tempDir) {
            do {
                try FileManager.default.removeItem(at: url)
                LogManager.shared.debug("🗑️ Cleaned up temp file: \(url.lastPathComponent)")
            } catch {
                LogManager.shared.warning("⚠️ Failed to cleanup temp file: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct MigrationInfoRow: View {
    let icon: String
    let text: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct MigrationStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding()
    }
}

struct ImportModeCard: View {
    let mode: MigrationImportView.ImportMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)

                // Mode icon
                Image(systemName: mode.icon)
                    .foregroundColor(mode == .replace ? .red : .blue)
                    .frame(width: 24)

                // Mode text
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(mode == .replace ? .red : .secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NextStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}
