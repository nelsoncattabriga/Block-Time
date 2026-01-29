//
//  ImportExportView.swift
//  Block-Time
//
//  Created by Nelson on 3/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject private var themeService = ThemeService.shared
    @Environment(\.scenePhase) private var scenePhase

    // Import/Export state
    @State private var importData: ImportData?
    @State private var isImporting = false
    @State private var showingExportView = false

    // Backup import data to preserve across app backgrounding
    @State private var backupImportData: ImportData?

    // Track which file picker mode is active
    @State private var activeFilePickerMode: FilePickerMode?

    enum FilePickerMode {
        case importWithMapping
        case webCIS
    }

    // webCIS import state
    @State private var isImportingWebCIS = false
    @State private var webCISImportData: ImportData?
    @State private var showingWebCISMappingSheet = false

    // Roster import state
    @State private var showingRosterImport = false

    // Migration import state
    @State private var showingMigrationImport = false

    // Aircraft Summary state
    @State private var showingAircraftSummary = false

    // Results
    @State private var showingResult = false
    @State private var resultMessage = ""

    // Delete state
    @State private var showingDeleteWarning = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Import / Export Card
                importExportCard

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
        .navigationTitle("Import & Export")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: Binding(
                get: {
                    let isPresented = activeFilePickerMode != nil
                    print("📁 fileImporter isPresented getter called, returning: \(isPresented), activeFilePickerMode: \(String(describing: activeFilePickerMode))")
                    return isPresented
                },
                set: { isPresented in
                    print("📁 fileImporter isPresented setter called with: \(isPresented), current activeFilePickerMode: \(String(describing: activeFilePickerMode))")
                    if !isPresented {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("📁 Delayed clear of activeFilePickerMode in setter")
                            if activeFilePickerMode != nil {
                                print("📁 Result handler didn't clear it, so clearing now")
                                activeFilePickerMode = nil
                            }
                        }
                    }
                }
            ),
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            print("📁 File importer result handler called")
            print("📁 Result: \(result)")
            print("📁 activeFilePickerMode before handling: \(String(describing: activeFilePickerMode))")

            guard let mode = activeFilePickerMode else {
                print("📁 No active mode!")
                return
            }

            switch mode {
            case .importWithMapping:
                print("📁 Handling as import with mapping")
                handleImportFileSelection(result)
            case .webCIS:
                print("📁 Handling as webCIS import")
                handleWebCISFileSelection(result)
            }

            print("📁 Clearing activeFilePickerMode after handling")
            activeFilePickerMode = nil
        }
        .sheet(item: $importData) { data in
            ImportMappingView(importData: data) { mappings, mode, regMappings in
                performImport(data: data, mappings: mappings, mode: mode, registrationMappings: regMappings)
            }
        }
        .sheet(isPresented: $showingWebCISMappingSheet) {
            if let data = webCISImportData {
                WebCISMappingView(importData: data) { regMappings in
                    performWebCISImportWithMappings(data: data, registrationMappings: regMappings)
                }
            }
        }
        .alert(resultMessage.contains("successfully") || resultMessage.contains("success") || resultMessage.contains("Summary") ? "Success" : "Error", isPresented: $showingResult) {
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
        .sheet(isPresented: $showingRosterImport) {
            UnifiedRosterImportView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingExportView) {
            ExportLogbookView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAircraftSummary) {
            AircraftSummarySheet { summary in
                saveAircraftSummary(summary)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingMigrationImport) {
            MigrationImportView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Import / Export Card
    private var importExportCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundColor(.indigo)
                    .font(.title3)

                Text("Import & Export")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {

                if isImporting {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Importing…")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.75))
                    .cornerRadius(8)
                }

                // Import roster (unified for both SH and LH)
                ActionButton(
                    title: "Roster Import",
                    subtitle: "Add rostered flights",
                    icon: "calendar.badge.plus",
                    color: .blue,
                    isLoading: false
                ) {
                    showingRosterImport = true
                }

                Divider()
                // Add Aircraft Summary
                ActionButton(
                    title: "Add Aircraft Summary",
                    subtitle: "Add previous hours by type",
                    icon: "clock.badge.checkmark.fill",
                    color: .green.opacity(0.7),
                    isLoading: false
                ) {
                    showingAircraftSummary = true
                }

                Divider()

                // webCIS Import Button
                if isImportingWebCIS {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Importing webCIS data…")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.75))
                    .cornerRadius(8)
                }

                // Import from webCIS data file
                ActionButton(
                    title: "Import webCIS Data",
                    subtitle: "RCIS Flying Experience Report",
                    icon: "doc.text.fill",
                    color: .orange.opacity(0.8),
                    isLoading: false
                ) {
                    print("🔘 Import webCIS button tapped")
                    activeFilePickerMode = .webCIS
                    print("🔘 activeFilePickerMode set to: \(String(describing: activeFilePickerMode))")
                }
                .disabled(isImportingWebCIS)

                // Generic data import
                ActionButton(
                    title: "CSV Data Import",
                    subtitle: "CSV or Tab-Delimited file",
                    icon: "square.and.arrow.down.on.square.fill",
                    color: .indigo.opacity(0.6),
                    isLoading: false
                ) {
                    print("🔘 Import Logbook button tapped")
                    activeFilePickerMode = .importWithMapping
                    print("🔘 activeFilePickerMode set to: \(String(describing: activeFilePickerMode))")
                }
                .disabled(isImporting)

                //Divider()

                // Export Data
                ActionButton(
                    title: "Export This Logbook",
                    subtitle: "Save as a CSV file",
                    icon: "square.and.arrow.up.fill",
                    color: .indigo.opacity(0.6),
                    isLoading: false
                ) {
                    showingExportView = true
                }

                Divider()

                // Migration Import from Logger
                ActionButton(
                    title: "Import from Logger",
                    subtitle: "Complete app migration import",
                    icon: "square.and.arrow.down.fill",
                    color: .orange,
                    isLoading: false
                ) {
                    showingMigrationImport = true
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Delete Logbook Card
    private var deleteLogbookCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                    .font(.title3)

                Text("Delete Logbook")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)

                Spacer()
            }

            ActionButton(
                title: "Delete All Flight Data",
                subtitle: "This cannot be undone",
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
    private func handleImportFileSelection(_ result: Result<[URL], Error>) {
        print("📁 handleImportFileSelection called")
        switch result {
        case .success(let files):
            print("📁 Files selected: \(files)")
            if let fileURL = files.first {
                print("📁 Parsing file: \(fileURL)")
                parseImportFile(fileURL)
            } else {
                print("📁 No file URL found")
            }
        case .failure(let error):
            print("📁 File selection error: \(error)")
            resultMessage = "Error selecting file: \(error.localizedDescription)"
            showingResult = true
        }
    }

    private func parseImportFile(_ url: URL) {
        print("📁 parseImportFile called with: \(url)")
        do {
            let parsedData = try FileImportService.shared.parseFile(url: url)
            print("📁 Successfully parsed file, setting importData")
            importData = parsedData
            print("📁 importData set: \(importData != nil)")
        } catch {
            print("📁 Parse error: \(error)")
            resultMessage = "Error parsing file: \(error.localizedDescription)"
            showingResult = true
        }
    }

    private func performImport(data: ImportData, mappings: [FieldMapping], mode: ImportMode, registrationMappings: [RegistrationTypeMapping]) {
        isImporting = true

        FileImportService.shared.importFlights(from: data, mapping: mappings, mode: mode, registrationMappings: registrationMappings) { result in
            isImporting = false

            switch result {
            case .success(let importResult):
                var message = "Import Summary\n\n"
                message += "✓ Successfully imported: \(importResult.successCount) flights\n"

                if importResult.duplicateCount > 0 {
                    message += "⊘ Skipped (already exists): \(importResult.duplicateCount) flights\n"
                }

                if importResult.failureCount > 0 {
                    message += "Failed to import: \(importResult.failureCount) flights\n\n"
                    message += "Failure Details:\n\n"

                    for (reason, count) in importResult.failureReasons.sorted(by: { $0.value > $1.value }) {
                        message += "• \(reason): \(count) occurrence(s)\n"
                    }

                    if !importResult.sampleFailures.isEmpty {
                        message += "\nSample Failures (first 5):\n"
                        for (row, reason) in importResult.sampleFailures.prefix(5) {
                            message += "  Row \(row): \(reason)\n"
                        }
                    }
                } else if importResult.duplicateCount == 0 {
                    message += "\n✓ All flights imported successfully with no errors!"
                }

                resultMessage = message
                // Database service observers will automatically post debounced .flightDataChanged notification
                viewModel.reloadSavedCrewNames()

            case .failure(let error):
                resultMessage = "Import failed: \(error.localizedDescription)"
            }

            showingResult = true
        }
    }

    private func deleteAllFlights() {
        let success = FlightDatabaseService.shared.clearAllFlights()
        if success {
            resultMessage = "All flights have been successfully deleted."
        } else {
            resultMessage = "Failed to delete flights. Please try again."
        }
        showingResult = true
    }

    private func saveAircraftSummary(_ summary: FlightSector) {
        let success = FlightDatabaseService.shared.saveFlight(summary)
        if success {
            resultMessage = "Aircraft summary for \(summary.aircraftType) added successfully."
            // Notify other views of the data change
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        } else {
            resultMessage = "Failed to save aircraft summary. Please try again."
        }
        showingResult = true
    }

    private func handleWebCISFileSelection(_ result: Result<[URL], Error>) {
        print("📁 handleWebCISFileSelection called")
        switch result {
        case .success(let files):
            print("📁 webCIS files selected: \(files)")
            if let fileURL = files.first {
                print("📁 Parsing webCIS file: \(fileURL)")
                parseWebCISFile(fileURL)
            } else {
                print("📁 No file URL found")
            }
        case .failure(let error):
            print("📁 webCIS file selection error: \(error)")
            resultMessage = "Error selecting file: \(error.localizedDescription)"
            showingResult = true
        }
    }

    private func parseWebCISFile(_ url: URL) {
        print("📁 parseWebCISFile called with: \(url)")
        do {
            let parsedData = try FileImportService.shared.parseWebCISFile(url: url)
            print("📁 Successfully parsed webCIS file, showing mapping sheet")
            webCISImportData = parsedData
            showingWebCISMappingSheet = true
        } catch {
            print("📁 webCIS parse error: \(error)")
            resultMessage = "Error parsing webCIS file: \(error.localizedDescription)"
            showingResult = true
        }
    }

    private func performWebCISImportWithMappings(data: ImportData, registrationMappings: [RegistrationTypeMapping]) {
        isImportingWebCIS = true

        FileImportService.shared.importWebCISData(
            importData: data,
            mode: .merge,
            registrationMappings: registrationMappings
        ) { result in
            isImportingWebCIS = false

            switch result {
            case .success(let importResult):
                var message = "webCIS Import Summary\n\n"
                message += "✓ Successfully imported: \(importResult.successCount) flights\n"

                if importResult.duplicateCount > 0 {
                    message += "⊘ Skipped (already exists): \(importResult.duplicateCount) flights\n"
                }

                if importResult.failureCount > 0 {
                    message += "Failed to import: \(importResult.failureCount) flights\n\n"
                    message += "Failure Details:\n\n"

                    for (reason, count) in importResult.failureReasons.sorted(by: { $0.value > $1.value }) {
                        message += "• \(reason): \(count) occurrence(s)\n"
                    }

                    if !importResult.sampleFailures.isEmpty {
                        message += "\nSample Failures (first 5):\n"
                        for (row, reason) in importResult.sampleFailures.prefix(5) {
                            message += "  Row \(row): \(reason)\n"
                        }
                    }
                } else if importResult.duplicateCount == 0 {
                    message += "\n✓ All flights imported successfully with no errors!"
                }

                resultMessage = message
                // Database service observers will automatically post debounced .flightDataChanged notification
                viewModel.reloadSavedCrewNames()

            case .failure(let error):
                resultMessage = "webCIS import failed: \(error.localizedDescription)"
            }

            showingResult = true
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

// MARK: - webCIS Mapping View
struct WebCISMappingView: View {
    let importData: ImportData
    let onImport: ([RegistrationTypeMapping]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var registrationMappings: [RegistrationTypeMapping] = []
    @State private var showingRegistrationMapping = false

    // Detect patterns on appear
    private func detectWebCISRegistrationPatterns() -> [RegistrationTypeMapping] {
        // webCIS always has registration in column 1 (REG)
        guard let regColumnIndex = importData.headers.firstIndex(of: "REG") else {
            return []
        }

        // Extract all unique registrations
        var registrations = Set<String>()
        for row in importData.rows {
            guard regColumnIndex < row.count else { continue }
            let reg = row[regColumnIndex].trimmingCharacters(in: .whitespaces)
            if !reg.isEmpty {
                registrations.insert(reg)
            }
        }

        // Group registrations by pattern (first 2 characters)
        var patternGroups: [String: [String]] = [:]
        for reg in registrations {
            let pattern = String(reg.prefix(2)) // Use first 2 chars as pattern
            patternGroups[pattern, default: []].append(reg)
        }

        // Create mappings for each pattern
        var mappings: [RegistrationTypeMapping] = []
        for (pattern, regs) in patternGroups.sorted(by: { $0.key < $1.key }) {
            // Try to detect type from AircraftFleetService
            let detectedType = AircraftFleetService.getAircraftType(byRegistration: regs.first ?? "")

            mappings.append(RegistrationTypeMapping(
                pattern: pattern + "*",
                aircraftType: detectedType,
                sampleRegistrations: Array(regs.prefix(3).sorted())
            ))
        }

        return mappings
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("webCIS Import")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Configure aircraft type mapping")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Registration Mappings Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Aircraft Type Mapping")
                            .font(.headline)
                        Spacer()
                        if !registrationMappings.isEmpty {
                            Text("\(registrationMappings.count) mapping(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Map aircraft registration patterns to types (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        // Detect patterns if not already detected
                        if registrationMappings.isEmpty {
                            registrationMappings = detectWebCISRegistrationPatterns()
                        }
                        showingRegistrationMapping = true
                    }) {
                        HStack {
                            Image(systemName: "airplane")
                            Text(registrationMappings.isEmpty ? "Setup Aircraft Types" : "Edit Aircraft Types")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Import Button
                Button(action: {
                    dismiss()
                    onImport(registrationMappings)
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Import webCIS Data")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("webCIS Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingRegistrationMapping) {
                // Create empty field mappings for webCIS (we don't need them for registration mapping)
                let fieldMappings = FileImportService.shared.createWebCISFieldMappingPublic(headers: importData.headers)
                RegistrationTypeMappingView(
                    mappings: $registrationMappings,
                    importData: importData,
                    fieldMappings: fieldMappings
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        ImportExportView(viewModel: FlightTimeExtractorViewModel())
    }
}
