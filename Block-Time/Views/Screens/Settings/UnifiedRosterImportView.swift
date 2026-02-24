//
//  UnifiedRosterImportView.swift
//  Block-Time
//
//  Created by Nelson on 03/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

/// Unified view for importing rosters - automatically detects SH or LH roster type
struct UnifiedRosterImportView: View {
    @Environment(\.dismiss) private var dismiss

    // Optional preselected file URL (for sharing from other apps)
    let preselectedFileURL: URL?

    // State
    @State private var showingFilePicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var currentSheet: SheetType?
    @State private var pastedRoster: String = ""

    private let plannedFlightService = PlannedFlightService()

    // Default initializer for normal use
    init(preselectedFileURL: URL? = nil) {
        self.preselectedFileURL = preselectedFileURL
    }

    enum SheetType: Identifiable {
        case preview(parseResult: UnifiedParseResult, futureFlights: [UnifiedParsedFlight])
        case result(importResult: PlannedFlightService.ImportResult)

        var id: String {
            switch self {
            case .preview: return "preview"
            case .result: return "result"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Import Roster")
                        .font(.title2)
                        .fontWeight(.bold)

//                    Text("Supports both Short Haul and Long Haul rosters")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Instructions
                VStack(alignment: .leading, spacing: 12) {

                    InstructionRow(
                        icon: "1.circle.fill",
                        text: "Select the downloaded roster file; OR"
                    )

                    InstructionRow(
                        icon: "2.circle.fill",
                        text: "Copy & Paste Roster Below; OR"
                    )

                    InstructionRow(
                        icon: "3.circle.fill",
                        text: "Share to Block-Time via Share Sheet"
                    )
                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)

                // Import Button
                Button(action: {
                    showingFilePicker = true
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        Text(isProcessing ? "Processing..." : "Select Roster File")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
                .padding(.horizontal)
                .padding(.bottom)

                Divider()

                VStack(alignment: .leading) {
                    HStack{
                        Text("Paste Roster Below")
                            .font(.headline)
                    }

                    PasteOnlyTextView(text: $pastedRoster)
                        .frame(minHeight: 150)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    // Process and Clear Buttons
                    HStack(spacing: 12) {
                        // Process Button
                        Button(action: {
                            processPastedRoster()
                        }) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "doc.text.magnifyingglass")
                                }
                                Text(isProcessing ? "Processing..." : "Process")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isProcessing || pastedRoster.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing || pastedRoster.isEmpty)

                        // Clear Button
                        Button(action: {
                            pastedRoster = ""
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(pastedRoster.isEmpty ? Color.gray : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(pastedRoster.isEmpty)
                    }
                }
                .padding()
                }
            }
            .navigationTitle("Import Roster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .sheet(item: $currentSheet) { sheetType in
                switch sheetType {
                case .preview(let parseResult, let futureFlights):
                    UnifiedRosterPreviewView(
                        parsedFlights: futureFlights,
                        pilotInfo: parseResult,
                        onImport: { selectedFlights in
                            currentSheet = nil
                            importSelectedFlights(selectedFlights)
                        }
                    )
                case .result(let importResult):
                    UnifiedRosterImportResultView(result: importResult) {
                        dismiss()
                    }
                }
            }
            .alert("Import Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }

        }
        .onAppear {
            // If a preselected file was provided, import it automatically
            if let fileURL = preselectedFileURL {
                importRoster(from: fileURL)
            }
        }
    }

    // MARK: - Helper Functions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            importRoster(from: fileURL)

        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }

    private func importRoster(from url: URL) {
        isProcessing = true

        Task {
            do {
                // Request access to security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "UnifiedRosterImportView", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "Unable to access the file. Please try again."])
                }

                // Ensure we stop accessing the resource when done
                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                // Parse the roster file using unified service (auto-detects type)
                let parseResult = try UnifiedRosterService.parseRoster(from: url)

                // Use all flights from the roster (duplicate detection happens during import)
                let flightsToImport = parseResult.flights

                await MainActor.run {
                    isProcessing = false

                    if flightsToImport.isEmpty {
                        errorMessage = "No flights found in roster."
                    } else {
                        // Show preview screen with data
                        print("Parsed \(parseResult.rosterType.displayName) roster with \(flightsToImport.count) flights")
                        currentSheet = .preview(parseResult: parseResult, futureFlights: flightsToImport)
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to parse roster: \(error.localizedDescription)"
                }
            }
        }
    }

    private func importSelectedFlights(_ flights: [UnifiedParsedFlight]) {
        Task {
            // Wait for preview sheet to finish dismissing first
            try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

            do {
                // Convert unified flights to RosterParserService.ParsedFlight format
                // PlannedFlightService expects the SH format
                let convertedFlights = flights.map { flight -> RosterParserService.ParsedFlight in
                    return RosterParserService.ParsedFlight(
                        date: flight.date,
                        flightNumber: flight.flightNumber,
                        departureAirport: flight.departureAirport,
                        arrivalAirport: flight.arrivalAirport,
                        departureTime: flight.departureTime,
                        arrivalTime: flight.arrivalTime,
                        aircraftType: flight.aircraftType,
                        role: flight.role,
                        isPositioning: flight.isPositioning,
                        bidPeriod: flight.bidPeriod,
                        dutyCode: flight.dutyCode
                    )
                }

                let result = try await plannedFlightService.importFlights(convertedFlights)

                await MainActor.run {
                    // Database service observers will automatically post debounced .flightDataChanged notification

                    // Show the result sheet with data embedded
                    currentSheet = .result(importResult: result)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func processPastedRoster() {
        guard !pastedRoster.isEmpty else { return }

        isProcessing = true

        Task {
            do {
                // Parse the pasted roster text using unified service (auto-detects type)
                let parseResult = try UnifiedRosterService.parseRoster(from: pastedRoster)

                // Use all flights from the roster (duplicate detection happens during import)
                let flightsToImport = parseResult.flights

                await MainActor.run {
                    isProcessing = false

                    if flightsToImport.isEmpty {
                        errorMessage = "No flights found in pasted roster. Ensure copy is from a file and not from the webCIS screen."
                    } else {
                        // Show preview screen with data
                        print("Parsed \(parseResult.rosterType.displayName) roster with \(flightsToImport.count) flights")
                        currentSheet = .preview(parseResult: parseResult, futureFlights: flightsToImport)
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to parse roster: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Instruction Row

private struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

// MARK: - Import Result View

private struct UnifiedRosterImportResultView: View {
    let result: PlannedFlightService.ImportResult
    let onDone: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Success/Warning Icon
                    if result.imported > 0 && result.errors == 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                    } else if result.imported > 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                    }

                    // Summary
                    VStack(spacing: 8) {
                        Text("Import Summary")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(summaryText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Stats Cards
                    VStack(spacing: 12) {
                        if result.imported > 0 {
                            ImportStatCard(
                                icon: "checkmark.circle.fill",
                                color: .green,
                                value: "\(result.imported)",
                                label: result.imported == 1 ? "Flight Imported" : "Flights Imported"
                            )
                        }

                        if result.duplicates > 0 {
                            ImportStatCard(
                                icon: "doc.on.doc.fill",
                                color: .orange,
                                value: "\(result.duplicates)",
                                label: result.duplicates == 1 ? "Duplicate Skipped" : "Duplicates Skipped"
                            )
                        }

                        if result.errors > 0 {
                            ImportStatCard(
                                icon: "exclamationmark.circle.fill",
                                color: .red,
                                value: "\(result.errors)",
                                label: result.errors == 1 ? "Error" : "Errors"
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Flight Details (if any imported)
                    if !result.flights.filter({ !$0.isDuplicate && $0.error == nil }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Imported Flights")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(Array(result.flights.filter({ !$0.isDuplicate && $0.error == nil }).enumerated()), id: \.offset) { index, importedFlight in
                                FlightSummaryRow(flight: importedFlight.flight)
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationTitle("Import Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }

    private var summaryText: String {
        if result.imported == 0 {
            if result.duplicates > 0 {
                return "All flights were already in your logbook"
            } else {
                return "No flights found in roster"
            }
        } else {
            return "Successfully imported \(result.imported) flight\(result.imported == 1 ? "" : "s")"
        }
    }
}

// MARK: - Import Stat Card

private struct ImportStatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Flight Summary Row

private struct FlightSummaryRow: View {
    let flight: RosterParserService.ParsedFlight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("QF\(flight.flightNumber)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(formatDate(flight.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Text(flight.departureAirport)
                    .font(.caption)
                    .fontWeight(.medium)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(flight.arrivalAirport)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text(flight.aircraftType)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)

                if flight.isPositioning {
                    Text("P")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd MMM yyyy"
        return formatter.string(from: date)
    }
}

// PasteOnlyTextView and NoKeyboardTextView are now in PasteOnlyTextView.swift

#Preview {
    UnifiedRosterImportView()
}
