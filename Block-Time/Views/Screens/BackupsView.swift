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
    @ObservedObject private var themeService = ThemeService.shared

    // State
    @State private var showingResult = false
    @State private var resultMessage = ""
    @State private var isAutomaticBackupsExpanded = false
    @State private var showingManageBackups = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
               

                // CloudKit Sync Card
                ModernCloudKitSyncCard()

                // ACARS Photo Backup Card
                ModernPhotoBackupCard(viewModel: viewModel)
                
                // Merged Backups & Restore Card
                mergedBackupsCard

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
        .alert(resultMessage.contains("successfully") || resultMessage.contains("success") ? "Success" : "Error", isPresented: $showingResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: - Merged Backups Card
    private var mergedBackupsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("Data Backup")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
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

                // Backup Now Button
                ActionButton(
                    title: "Backup Now",
                    subtitle: "Backup all flights",
                    icon: "square.and.arrow.down.fill",
                    color: .blue,
                    isLoading: backupService.isBackupInProgress
                ) {
                    createManualBackup()
                }
                .disabled(backupService.isBackupInProgress)

                // Restore from Backup Button
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

    // MARK: - Helper Functions
    private func createManualBackup() {
        backupService.performManualBackup { result in
            switch result {
            case .success:
                resultMessage = "Backup created successfully"
                showingResult = true
            case .failure(let error):
                resultMessage = "Backup failed: \(error.localizedDescription)"
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
                    .foregroundColor(.white)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(16)
            .background(color.opacity(0.85))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Backup Detail Sheet
private struct BackupDetailSheet: View {
    let backup: BackupFileInfo
    @ObservedObject var backupService: AutomaticBackupService
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingRestoreConfirmation = false
    @State private var isRestoring = false
    @State private var showingShareSheet = false
    @State private var showingResultAlert = false
    @State private var resultMessage = ""
    @State private var selectedRestoreMode: ImportMode = .merge

    var body: some View {
        NavigationView {
            List {
                Section("Backup Information") {
                    LabeledContent("Date", value: backup.formattedDate)
                    LabeledContent("Size", value: backup.formattedSize)
                    if let count = backup.flightCount {
                        LabeledContent("Flights", value: "\(count)")
                    }
                }

                Section("Actions") {
                    Button(action: {
                        showingRestoreConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .foregroundColor(.green)
                            Text("Restore from this Backup")
                                .foregroundColor(.primary)
                        }
                    }
                    .disabled(isRestoring)

                    Button(action: {
                        showingShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("Share Backup File")
                                .foregroundColor(.primary)
                        }
                    }

                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete this Backup")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Backup Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            .alert(resultMessage.contains("successfully") || resultMessage.contains("success") || resultMessage.contains("Restored") || resultMessage.contains("Summary") ? "Success" : "Error", isPresented: $showingResultAlert) {
                Button("OK", role: .cancel) {
                    if resultMessage.contains("successfully") || resultMessage.contains("success") || resultMessage.contains("Restored") || resultMessage.contains("Summary") {
                        dismiss()
                    }
                }
            } message: {
                Text(resultMessage)
            }
        }
    }

    private func performRestore() {
        LogManager.shared.info("performRestore called")
        LogManager.shared.info("📁 Backup URL: \(backup.url.path)")
        LogManager.shared.info("🔀 Restore mode: \(selectedRestoreMode)")

        isRestoring = true

        LogManager.shared.info("📖 Calling quickRestoreFromBackup...")
        // skipSecurityScoping=true because this file is from our app's backup directory
        FileImportService.shared.quickRestoreFromBackup(url: backup.url, mode: selectedRestoreMode, skipSecurityScoping: true) { result in
            print("📥 quickRestoreFromBackup completion handler called")
            isRestoring = false

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
                showingResultAlert = true
                // Database service observers will automatically post debounced .flightDataChanged notification

            case .failure(let error):
                LogManager.shared.error("Restore failed: \(error.localizedDescription)")
                if (error as? ImportError) == .notLoggerFormat {
                    resultMessage = "This file is not in Block-Time backup format. Please use 'Import with Field Mapping' to import files from other logbook apps."
                } else {
                    resultMessage = "Restore failed: \(error.localizedDescription)"
                }
                showingResultAlert = true
            }
        }
        LogManager.shared.info("📤 quickRestoreFromBackup call initiated (async)")
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
    @ObservedObject private var themeService = ThemeService.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.editMode) var editMode
    @State private var showingDeleteAllConfirmation = false
    @State private var showingBackupDetails: BackupFileInfo?
    @State private var showingFilePicker = false
    @State private var showingRestoreConfirmation = false
    @State private var selectedExternalFile: URL?
    @State private var selectedRestoreMode: ImportMode = .merge
    @State private var isRestoring = false
    @State private var showingResultAlert = false
    @State private var resultMessage = ""

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !backupService.availableBackups.isEmpty {
                    Button(editMode?.wrappedValue == .active ? "Done" : "Edit") {
                        withAnimation {
                            editMode?.wrappedValue = editMode?.wrappedValue == .active ? .inactive : .active
                        }
                    }
                }
            }
        }
        .sheet(item: $showingBackupDetails) { backup in
            BackupDetailSheet(backup: backup, backupService: backupService)
        }
        .refreshable {
            backupService.refreshAvailableBackups()
        }
        .alert("Delete All Backups", isPresented: $showingDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllBackups()
            }
        } message: {
            Text("This will permanently delete all \(backupService.availableBackups.count) backup file(s). This action cannot be undone.")
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
        .alert(resultMessage.contains("successfully") || resultMessage.contains("success") || resultMessage.contains("Restored") || resultMessage.contains("Summary") ? "Success" : "Error", isPresented: $showingResultAlert) {
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
                        .foregroundColor(.white)
                        .font(.title3)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose File")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Text("Browse and select a backup file")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(16)
                .background(Color.blue.opacity(0.85))
                .cornerRadius(10)
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
                VStack(spacing: 12) {
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

                                    if editMode?.wrappedValue != .active {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(editMode?.wrappedValue == .active)
                        .deleteDisabled(editMode?.wrappedValue != .active)
                    }
                    .onDelete(perform: deleteBackups)

                    // Delete All Button
                    if editMode?.wrappedValue != .active {
                        Divider()
                            .padding(.vertical, 4)

                        Button(role: .destructive, action: {
                            showingDeleteAllConfirmation = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "trash")
                                    .font(.title3)
                                    .frame(width: 24)
                                Text("Delete All Backups")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
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
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }

    private func performExternalRestore() {
        guard let fileURL = selectedExternalFile else { return }

        isRestoring = true

        // skipSecurityScoping=false because this is an external file selected by the user
        FileImportService.shared.quickRestoreFromBackup(url: fileURL, mode: selectedRestoreMode, skipSecurityScoping: false) { result in
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
                showingResultAlert = true

            case .failure(let error):
                if (error as? ImportError) == .notLoggerFormat {
                    resultMessage = "This file is not in Block-Time backup format. Please use 'Import with Field Mapping' to import files from other logbook apps."
                } else {
                    resultMessage = "Restore failed: \(error.localizedDescription)"
                }
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

    private func deleteAllBackups() {
        try? backupService.deleteAllBackups()
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
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
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
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)

                Spacer()

                // Cancel Button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
    }
}

#Preview {
    NavigationStack {
        BackupsView(viewModel: FlightTimeExtractorViewModel())
    }
}
