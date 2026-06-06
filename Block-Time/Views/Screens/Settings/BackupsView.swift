//
//  BackupsView.swift
//  Block-Time
//
//  Created by Nelson on 3/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupsView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject var backupService = AutomaticBackupService.shared
    @Environment(ThemeService.self) private var themeService

    // State
    @State private var showingResult = false
    @State private var isSuccess = false
    @State private var resultMessage = ""
    @State private var isAutomaticBackupsExpanded = false
    @State private var showingManageBackups = false
    @State private var showBackupHelp = false
    @State private var showingDeleteWarning = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
               

                // CloudKit Sync Card
                ModernCloudKitSyncCard()

                // ACARS Photo Backup Card
                ModernPhotoBackupCard(viewModel: viewModel)
                
                // Merged Backups & Restore Card
                mergedBackupsCard

                // Delete Logbook Card
                deleteLogbookCard

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("Backup & Sync")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isSuccess ? "Success" : "Error", isPresented: $showingResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resultMessage)
        }
        .alert("Delete All Logbook Data", isPresented: $showingDeleteWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllFlights()
            }
        } message: {
            Text("This will permanently delete all data.")
        }
    }

    // MARK: - Merged Backups Card
    private var mergedBackupsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("DATA BACKUP")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)

                Spacer()

                Button {
                    showBackupHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showBackupHelp) {
                DataBackupHelpSheet()
            }

            VStack(spacing: 12) {
                // Automatic Backups Toggle
                HStack(spacing: 12) {
                    Image(systemName: "power")
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatic Backup")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(backupService.settings.isEnabled ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { backupService.settings.isEnabled },
                        set: { enabled in
                            var settings = backupService.settings
                            settings.isEnabled = enabled
                            backupService.updateSettings(settings)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .scaleEffect(0.9)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // Location Picker
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    Text("Location")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Picker("", selection: Binding(
                        get: { backupService.settings.location },
                        set: { location in
                            var settings = backupService.settings
                            settings.location = location
                            backupService.updateSettings(settings)
                        }
                    )) {
                        ForEach(BackupLocation.allCases, id: \.self) { location in
                            Text(location.displayName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .tag(location)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                if backupService.settings.isEnabled {
                    // Backup Frequency
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        Text("Frequency")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        Picker("", selection: Binding(
                            get: { backupService.settings.frequency },
                            set: { frequency in
                                var settings = backupService.settings
                                settings.frequency = frequency
                                backupService.updateSettings(settings)
                            }
                        )) {
                            ForEach(BackupFrequency.allCases.filter { $0 != .disabled }, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    // Max Backups to Keep
                    HStack(spacing: 12) {
                        Image(systemName: "tray.full")
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        Text("Backups to Keep")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        Picker("", selection: Binding(
                            get: { backupService.settings.maxBackupsToKeep },
                            set: { count in
                                var settings = backupService.settings
                                settings.maxBackupsToKeep = count
                                backupService.updateSettings(settings)
                            }
                        )) {
                            ForEach([5, 10, 15, 30], id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Divider
                Divider()
                    .padding(.vertical, 4)

                // Last Backup Info
                HStack(spacing: 12) {
                    Image(systemName: backupService.lastBackupDate != nil ? "checkmark.circle.fill" : "clock")
                        .foregroundColor(backupService.lastBackupDate != nil ? .blue : .secondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Backup")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("(\(backupService.availableBackups.count) backup\(backupService.availableBackups.count == 1 ? "" : "s") saved)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if backupService.isBackupInProgress {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Saving")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if let lastBackup = backupService.lastBackupDate {
                        Text(lastBackup.formatted(.relative(presentation: .named)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // Backup Now Button — primary action, filled style
                Button(action: createManualBackup) {
                    HStack(spacing: 12) {
                        if backupService.isBackupInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        Text(backupService.isBackupInProgress ? "Backing up…" : "Backup Now")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(16)
                    .background(backupService.isBackupInProgress ? Color.blue.opacity(0.6) : Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(backupService.isBackupInProgress)

                // Manage Backups — navigation row
                ActionButton(
                    title: "Manage Backups",
                    subtitle: "View and restore saved backups",
                    icon: "arrow.counterclockwise.circle.fill",
                    color: .blue,
                    isLoading: false
                ) {
                    showingManageBackups = true
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
        .navigationDestination(isPresented: $showingManageBackups) {
            ManageBackupsView(backupService: backupService)
        }
    }

    // MARK: - Delete Logbook Card
    private var deleteLogbookCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundStyle(.red)
                    .font(.title3)

                Text("DELETE LOGBOOK")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)

                Spacer()
            }

            ActionButton(
                title: "Delete All Flight Data",
                subtitle: "This cannot be undone!",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                isLoading: false
            ) {
                showingDeleteWarning = true
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helper Functions
    private func deleteAllFlights() {
        FlightDatabaseService.shared.suspendUndoForBatchImport()
        let success = FlightDatabaseService.shared.clearAllFlights()
        FlightDatabaseService.shared.resumeUndoAfterBatchImport()
        resultMessage = success ? "All flights have been successfully deleted." : "Failed to delete flights. Please try again."
        isSuccess = success
        showingResult = true
    }

    private func createManualBackup() {
        backupService.performManualBackup { result in
            switch result {
            case .success:
                resultMessage = "Backup created successfully"
                isSuccess = true
                showingResult = true
            case .failure(let error):
                resultMessage = "Backup failed: \(error.localizedDescription)"
                isSuccess = false
                showingResult = true
            }
        }
    }
}

// MARK: - Action Button Component
private struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(color.opacity(0.7))
                }
            }
            .padding(16)
            .background(color.opacity(0.12))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct PendingDefinitions: Identifiable {
    let id = UUID()
    let definitions: [CustomCounterDefinition]
}

// MARK: - Backup Detail Sheet
private struct BackupDetailSheet: View {
    let backup: BackupFileInfo
    @ObservedObject var backupService: AutomaticBackupService
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingRestoreConfirmation = false
    @State private var isRestoring = false
    @State private var restoreStatusMessage = ""
    @State private var showingShareSheet = false
    @State private var showingResultAlert = false
    @State private var isSuccess = false
    @State private var resultMessage = ""
    @State private var selectedRestoreMode: ImportMode = .merge
    @State private var pendingBackupDefinitions: PendingDefinitions? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "externaldrive.fill.badge.checkmark")
                            .font(.system(size: 56))
                            .foregroundColor(.blue)

                        Text(backup.formattedDate)
                            .font(.title3)
                            .fontWeight(.bold)

                        if let count = backup.flightCount {
                            Text("\(count) flights · \(backup.formattedSize)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(Color(.systemGray5))
                                .cornerRadius(20)
                        } else {
                            Text(backup.formattedSize)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(Color(.systemGray5))
                                .cornerRadius(20)
                        }
                    }
                    .padding(.top, 8)

                    // Info Card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("Backup Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        VStack(spacing: 0) {
                            infoRow(icon: "calendar", label: "Date", value: backup.formattedDate)
                            Divider().padding(.leading, 32)
                            infoRow(icon: "doc.fill", label: "File Size", value: backup.formattedSize)
                            if let count = backup.flightCount {
                                Divider().padding(.leading, 32)
                                infoRow(icon: "airplane", label: "Flights", value: "\(count)")
                            }
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.07))
                        .cornerRadius(10)
                    }
                    .padding(16)
                    .background(.thinMaterial)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )

                    // Actions Card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("Actions")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        ActionButton(
                            title: "Restore from this Backup",
                            subtitle: isRestoring && !restoreStatusMessage.isEmpty ? restoreStatusMessage : "Replace or merge your current data",
                            icon: "arrow.counterclockwise.circle.fill",
                            color: .green,
                            isLoading: isRestoring
                        ) {
                            showingRestoreConfirmation = true
                        }
                        .disabled(isRestoring)

                        ActionButton(
                            title: "Share Backup File",
                            subtitle: "Export or save a copy of this backup",
                            icon: "square.and.arrow.up.fill",
                            color: .blue,
                            isLoading: false
                        ) {
                            showingShareSheet = true
                        }

                        Button(action: { showingDeleteConfirmation = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delete this Backup")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    Text("Permanently remove this backup file")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color.red.opacity(0.7))
                            }
                            .padding(16)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
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
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Backup Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingRestoreConfirmation) {
                RestoreModeSheet(
                    onMerge: {
                        selectedRestoreMode = .merge
                        showingRestoreConfirmation = false
                        performRestore()
                    },
                    onOverwrite: {
                        selectedRestoreMode = .replace
                        showingRestoreConfirmation = false
                        performRestore()
                    },
                    onCancel: {
                        showingRestoreConfirmation = false
                    }
                )
                .presentationDetents([.height(450)])
            }
            .sheet(item: $pendingBackupDefinitions) { pending in
                DefinitionConflictSheet(
                    backupDefinitions: pending.definitions,
                    deviceDefinitions: CustomCounterService.shared.definitions,
                    onKeepExisting: {
                        pendingBackupDefinitions = nil
                        executeRestore(definitionsBehavior: .skip)
                    },
                    onUseBackup: {
                        pendingBackupDefinitions = nil
                        executeRestore(definitionsBehavior: .replaceAll)
                    },
                    onCancel: {
                        pendingBackupDefinitions = nil
                    }
                )
                .presentationDetents([.height(500)])
            }
            .alert("Delete Backup", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteBackup()
                }
            } message: {
                Text("This will permanently delete this backup file.")
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [backup.url])
            }
            .alert(isSuccess ? "Success" : "Error", isPresented: $showingResultAlert) {
                Button("OK", role: .cancel) {
                    if isSuccess { dismiss() }
                }
            } message: {
                Text(resultMessage)
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 6)
    }

    private func performRestore() {
        LogManager.shared.info("performRestore called")
        LogManager.shared.info(" Backup URL: \(backup.url.path)")
        LogManager.shared.info(" Restore mode: \(selectedRestoreMode)")

        if selectedRestoreMode == .replace {
            // Replace mode: always overwrite definitions — no conflict check needed
            executeRestore(definitionsBehavior: .replaceAll)
            return
        }

        // Merge mode: check for definition conflicts before restoring
        let backupDefs = FileImportService.shared.extractBackupDefinitions(
            url: backup.url, skipSecurityScoping: true
        )

        LogManager.shared.info("extractBackupDefinitions returned \(backupDefs?.count ?? -1) definitions")
        LogManager.shared.info("Device has \(CustomCounterService.shared.definitions.count) definitions")
        if let backupDefs = backupDefs,
           !backupDefs.isEmpty,
           !CustomCounterService.shared.definitions.isEmpty,
           backupDefs != CustomCounterService.shared.definitions {
            // Conflict: backup has definitions that differ from device — ask user
            LogManager.shared.info("Definition conflict detected  showing conflict sheet")
            pendingBackupDefinitions = PendingDefinitions(definitions: backupDefs)
        } else {
            LogManager.shared.info("No conflict  proceeding with mergeIfEmpty")
            executeRestore(definitionsBehavior: .mergeIfEmpty)
        }
    }

    private func executeRestore(definitionsBehavior: DefinitionsBehavior) {
        isRestoring = true
        restoreStatusMessage = "Preparing restore..."
        LogManager.shared.info(" Calling quickRestoreFromBackup...")
        FileImportService.shared.quickRestoreFromBackup(
            url: backup.url,
            mode: selectedRestoreMode,
            skipSecurityScoping: true,
            definitionsBehavior: definitionsBehavior,
            progressHandler: { message in
                restoreStatusMessage = message
            }
        ) { result in
            isRestoring = false
            restoreStatusMessage = ""
            switch result {
            case .success(let importResult):
                LogManager.shared.info("Restore succeeded: \(importResult.successCount) flights")
                var message = "Restore Summary\n\n"
                message += "Mode: \(self.selectedRestoreMode == .merge ? "Merge" : "Overwrite")\n\n"
                message += "✓ Successfully restored: \(importResult.successCount) flights\n"
                if importResult.duplicateCount > 0 {
                    message += "⊘ Skipped \(importResult.duplicateCount) duplicated flights\n"
                }
                if importResult.failureCount > 0 {
                    message += "Failed to restore: \(importResult.failureCount) flights\n"
                }
                resultMessage = message
                isSuccess = true
                showingResultAlert = true
            case .failure(let error):
                LogManager.shared.error("Restore failed: \(error.localizedDescription)")
                if (error as? ImportError) == .notLoggerFormat {
                    resultMessage = "This file is not in Block-Time backup format. Please use 'Import with Field Mapping' to import files from other logbook apps."
                } else {
                    resultMessage = "Restore failed: \(error.localizedDescription)"
                }
                isSuccess = false
                showingResultAlert = true
            }
        }
        LogManager.shared.info(" quickRestoreFromBackup call initiated (async)")
    }

    private func deleteBackup() {
        do {
            try backupService.deleteBackup(backup)
            dismiss()
        } catch {
            LogManager.shared.error("Failed to delete backup: \(error.localizedDescription)")
        }
    }
}

// MARK: - Share Sheet
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Document Picker
private struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onDocumentPicked: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void

        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}

// MARK: - Manage Backups View
struct ManageBackupsView: View {
    @ObservedObject var backupService: AutomaticBackupService
    @Environment(ThemeService.self) private var themeService
    @Environment(\.dismiss) var dismiss
    @State private var showingBackupDetails: BackupFileInfo?
    @State private var showingFilePicker = false
    @State private var showingRestoreConfirmation = false
    @State private var selectedExternalFile: URL?
    @State private var selectedRestoreMode: ImportMode = .merge
    @State private var isRestoring = false
    @State private var showingResultAlert = false
    @State private var isSuccess = false
    @State private var resultMessage = ""
    @State private var pendingBackupDefinitions: PendingDefinitions? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Saved Backups Card
                savedBackupsCard
                
                // External File Picker Card
                externalFilePickerCard
                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("Restore")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $showingBackupDetails) { backup in
            BackupDetailSheet(backup: backup, backupService: backupService)
        }
        .refreshable {
            backupService.refreshAvailableBackups()
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker(
                allowedContentTypes: [.commaSeparatedText, .plainText],
                onDocumentPicked: { url in
                    selectedExternalFile = url
                    showingRestoreConfirmation = true
                }
            )
        }
        .sheet(isPresented: $showingRestoreConfirmation) {
            RestoreModeSheet(
                onMerge: {
                    selectedRestoreMode = .merge
                    showingRestoreConfirmation = false
                    performExternalRestore()
                },
                onOverwrite: {
                    selectedRestoreMode = .replace
                    showingRestoreConfirmation = false
                    performExternalRestore()
                },
                onCancel: {
                    showingRestoreConfirmation = false
                    selectedExternalFile?.stopAccessingSecurityScopedResource()
                    selectedExternalFile = nil
                }
            )
            .presentationDetents([.height(450)])
        }
        .sheet(item: $pendingBackupDefinitions) { pending in
            DefinitionConflictSheet(
                backupDefinitions: pending.definitions,
                deviceDefinitions: CustomCounterService.shared.definitions,
                onKeepExisting: {
                    pendingBackupDefinitions = nil
                    if let fileURL = selectedExternalFile {
                        executeExternalRestore(url: fileURL, definitionsBehavior: .skip)
                    }
                },
                onUseBackup: {
                    pendingBackupDefinitions = nil
                    if let fileURL = selectedExternalFile {
                        executeExternalRestore(url: fileURL, definitionsBehavior: .replaceAll)
                    }
                },
                onCancel: {
                    pendingBackupDefinitions = nil
                }
            )
            .presentationDetents([.height(500)])
        }
        .alert(isSuccess ? "Success" : "Error", isPresented: $showingResultAlert) {
            Button("OK", role: .cancel) {
                selectedExternalFile?.stopAccessingSecurityScopedResource()
                selectedExternalFile = nil
            }
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: - External File Picker Card
    private var externalFilePickerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "folder.badge.plus")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("External Backups")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            Button(action: {
                showingFilePicker = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.up.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose File")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Browse and select a backup file")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color.blue.opacity(0.7))
                }
                .padding(16)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
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

    // MARK: - Saved Backups Card
    private var savedBackupsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("Available Backups")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                if !backupService.availableBackups.isEmpty {
                    Text("\(backupService.availableBackups.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }

            if backupService.availableBackups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No backups available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Backups will appear here once created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    List {
                        ForEach(backupService.availableBackups) { backup in
                            Button(action: {
                                showingBackupDetails = backup
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 4) {
                                        if let count = backup.flightCount {
                                            Text("\(count) flights")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("Backup")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                        }

                                        Text(backup.formattedDate)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(backup.formattedSize)
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Color(.systemGray6).opacity(0.5))
                        }
                        .onDelete(perform: deleteBackups)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: CGFloat(min(backupService.availableBackups.count, 5) * 70))
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }

    private func performExternalRestore() {
        guard let fileURL = selectedExternalFile else { return }

        if selectedRestoreMode == .replace {
            // Replace mode: always overwrite definitions — no conflict check needed
            executeExternalRestore(url: fileURL, definitionsBehavior: .replaceAll)
            return
        }

        // Merge mode: check for definition conflicts before restoring
        let backupDefs = FileImportService.shared.extractBackupDefinitions(
            url: fileURL, skipSecurityScoping: false
        )

        if let backupDefs = backupDefs,
           !backupDefs.isEmpty,
           !CustomCounterService.shared.definitions.isEmpty,
           backupDefs != CustomCounterService.shared.definitions {
            // Conflict: backup has definitions that differ from device — ask user
            pendingBackupDefinitions = PendingDefinitions(definitions: backupDefs)
        } else {
            executeExternalRestore(url: fileURL, definitionsBehavior: .mergeIfEmpty)
        }
    }

    private func executeExternalRestore(url: URL, definitionsBehavior: DefinitionsBehavior) {
        isRestoring = true
        FileImportService.shared.quickRestoreFromBackup(
            url: url,
            mode: selectedRestoreMode,
            skipSecurityScoping: false,
            definitionsBehavior: definitionsBehavior
        ) { result in
            isRestoring = false
            switch result {
            case .success(let importResult):
                var message = "Restore Summary\n\n"
                message += "Mode: \(selectedRestoreMode == .merge ? "Merge" : "Overwrite")\n\n"
                message += "✓ Successfully restored: \(importResult.successCount) flights\n"
                if importResult.duplicateCount > 0 {
                    message += "⊘ Skipped \(importResult.duplicateCount) duplicated flights\n"
                }
                if importResult.failureCount > 0 {
                    message += "Failed to restore: \(importResult.failureCount) flights\n"
                }
                resultMessage = message
                isSuccess = true
                showingResultAlert = true
            case .failure(let error):
                if (error as? ImportError) == .notLoggerFormat {
                    resultMessage = "This file is not in Block-Time backup format. Please use 'Import with Field Mapping' to import files from other logbook apps."
                } else {
                    resultMessage = "Restore failed: \(error.localizedDescription)"
                }
                isSuccess = false
                showingResultAlert = true
            }
        }
    }

    private func deleteBackups(at offsets: IndexSet) {
        for index in offsets {
            let backup = backupService.availableBackups[index]
            try? backupService.deleteBackup(backup)
        }
    }
}

// MARK: - Restore Mode Sheet
private struct RestoreModeSheet: View {
    let onMerge: () -> Void
    let onOverwrite: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)

                Text("Choose Restore Mode")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 50)

                VStack(spacing: 16) {
                    // Merge Option
                    Button(action: onMerge) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.triangle.merge")
                                    .foregroundColor(.green)
                                Text("Merge with Existing Data")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }

                            Text("Smart merge and skip duplicates")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Overwrite Option
                    Button(action: onOverwrite) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Overwrite All Data")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }

                            Text("Replace all existing flights with backup data")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)

                Spacer()

                // Cancel Button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
    }
}

// MARK: - Definition Conflict Sheet
private struct DefinitionConflictSheet: View {
    let backupDefinitions: [CustomCounterDefinition]
    let deviceDefinitions: [CustomCounterDefinition]
    let onKeepExisting: () -> Void
    let onUseBackup: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Custom Fields Conflict")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("The backup contains custom fields that differ from your current settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 32)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("On This Device")
                        .font(.headline)
                    ForEach(deviceDefinitions) { def in
                        Text("• \(def.label)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("In Backup")
                        .font(.headline)
                    ForEach(backupDefinitions) { def in
                        Text("• \(def.label)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                Button(action: onKeepExisting) {
                    Text("Keep Existing")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: onUseBackup) {
                    Text("Use Backup Definitions")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: onCancel) {
                    Text("Cancel Restore")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - Data Backup Help Sheet
private struct DataBackupHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Accent banner
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic Backup")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("Saves a CSV of all flights on a schedule you choose.")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.blue)

                    VStack(spacing: 12) {
                        // When backups run
                        infoBlock(
                            icon: "clock.badge.checkmark",
                            title: "When backups run",
                            body: "A scheduled backup runs when the app comes to the foreground if one is due. It also runs when flight data changes, provided at least one hour has passed since the last backup."
                        )

                        // Backup locations
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Backup locations", systemImage: "folder")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            locationRow(
                                icon: "iphone",
                                title: "On My iPhone / iPad",
                                detail: "Saved to the app's local Documents folder. Accessible via the Files app under Block-Time. Not available on other devices."
                            )

                            locationRow(
                                icon: "icloud",
                                title: "iCloud",
                                detail: "Saved to iCloud Drive in a Block-Time/Backups/ folder. Accessible across all your devices via the Files app."
                            )
                        }
                        .padding(14)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                        )

                        // Restore modes
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Restoring from a backup", systemImage: "arrow.counterclockwise")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Tap Manage Backups to view saved backups and restore from one. Two modes are available:")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            restoreModeRow(
                                icon: "arrow.left.arrow.right",
                                color: .blue,
                                title: "Merge",
                                detail: "Adds backup flights to your current logbook. Duplicate flights (same date, flight number, and registration) are skipped."
                            )

                            restoreModeRow(
                                icon: "trash",
                                color: .red,
                                title: "Overwrite",
                                detail: "Deletes all existing flights first, then imports everything from the backup. Cannot be undone."
                            )
                        }
                        .padding(14)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .padding(16)

                    // Learn More
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
            .navigationTitle("Data Backup")
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

    private func infoBlock(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(body)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
    }

    private func locationRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(.blue)
                .frame(width: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func restoreModeRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(color)
                .frame(width: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
