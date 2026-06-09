//
//  UnifiedRosterImportView.swift
//  Block-Time
//
//  Created by Nelson on 03/11/2025.
//

import SwiftUI
import CoreData
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
        case staleReview(staleFlights: [FlightEntity], importResult: PlannedFlightService.ImportResult, rosterBase: String)
        case result(importResult: PlannedFlightService.ImportResult, staleRemoved: Int = 0)

        var id: String {
            switch self {
            case .preview: return "preview"
            case .staleReview: return "staleReview"
            case .result: return "result"
            }
        }
    }

    var body: some View {
        NavigationStack {
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

                }
                .padding(.top)

                // webCIS notice banner
                ImportNoticeBanner()
                    .padding(.horizontal)

                // Method cards
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose an Import Method")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    ImportMethodCard(
                        icon: "square.and.arrow.up",
                        iconColor: .purple,
                        title: "Share from Mail",
                        steps: [
                            "In webCIS, tap Send My Roster",
                            "Open the email in Mail, then long-press the attached file / tap to open",
                            "Tap Share and select Block-Time from the app row",
                            "You may need to scroll to the right to find it",
                            "Tap 'More' to edit the list"
                        ]
                    ) { EmptyView() }
                    .padding(.horizontal)
                    
                    
                    ImportMethodCard(
                        icon: "folder.badge.plus",
                        iconColor: .blue,
                        title: "Saved Roster File",
                        steps: [
                            "In webCIS, tap Send My Roster",
                            "Open the email and save the attached file",
                            "Tap the button below and choose the saved file"
                        ],
                    ) {
                        Divider()
                        Button {
                            showingFilePicker = true
                        } label: {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                } else {
                                    Image(systemName: "square.and.arrow.down.fill")
                                }
                                Text(isProcessing ? "Processing..." : "Select Roster File")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.blue)
                        }
                        .disabled(isProcessing)
                    }
                    .padding(.horizontal)

                    

                    ImportMethodCard(
                        icon: "doc.on.clipboard",
                        iconColor: .teal,
                        title: "Copy & Paste",
                        steps: [
                            "In webCIS, tap Send My Roster",
                            "Open the email in Mail and tap the attached file to preview it",
                            "Tap Select All, then Copy",
                            "Paste into the field below",
                            "Tap 'Process'"
                        ]
                    ) {
                        Divider()
                        PasteOnlyTextView(text: $pastedRoster)
                            .frame(minHeight: 130)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        HStack(spacing: 10) {
                            Button {
                                processPastedRoster()
                            } label: {
                                HStack {
                                    if isProcessing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .teal))
                                    } else {
                                        Image(systemName: "doc.text.magnifyingglass")
                                    }
                                    Text(isProcessing ? "Processing..." : "Process")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundColor(.teal)
                            }
                            .disabled(isProcessing || pastedRoster.isEmpty)

                            Button {
                                pastedRoster = ""
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Clear")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundColor(.red)
                            }
                            .disabled(pastedRoster.isEmpty)
                        }
                    }
                    .padding(.horizontal)
                }
                }

            }
            .navigationTitle("Import Roster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                            importSelectedFlights(selectedFlights, parseResult: parseResult)
                        }
                    )
                case .staleReview(let staleFlights, let importResult, let rosterBase):
                    StaleFlightReviewView(
                        staleFlights: staleFlights,
                        rosterBase: rosterBase,
                        onContinue: { toDelete in
                            currentSheet = nil
                            Task {
                                try? await Task.sleep(for: .seconds(0.6))
                                let removed = await plannedFlightService.deleteStaleFlights(toDelete)
                                await MainActor.run {
                                    currentSheet = .result(importResult: importResult, staleRemoved: removed)
                                }
                            }
                        },
                        onSkip: {
                            currentSheet = .result(importResult: importResult)
                        }
                    )
                case .result(let importResult, let staleRemoved):
                    UnifiedRosterImportResultView(result: importResult, staleRemoved: staleRemoved) {
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

    private func importSelectedFlights(_ flights: [UnifiedParsedFlight], parseResult: UnifiedParseResult) {
        Task {
            // Wait for preview sheet to finish dismissing first
            try? await Task.sleep(for: .seconds(0.6))

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

                // Stale detection: find unflown logbook flights in the bid period that are absent from new roster.
                // Key set is built from the FULL roster (parseResult.flights), not just the user's selected subset,
                // so deselected-but-still-rostered flights are not incorrectly flagged as stale.
                if let periodStart = parseResult.periodStartDate,
                   let periodEnd = parseResult.periodEndDate {
                    let allRosterFlights = parseResult.flights.map { flight -> RosterParserService.ParsedFlight in
                        RosterParserService.ParsedFlight(
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
                    let stale = await plannedFlightService.findStaleFlights(
                        periodStart: periodStart,
                        periodEnd: periodEnd,
                        rosterFlights: allRosterFlights
                    )
                    await MainActor.run {
                        if stale.isEmpty {
                            currentSheet = .result(importResult: result)
                        } else {
                            currentSheet = .staleReview(staleFlights: stale, importResult: result, rosterBase: parseResult.base)
                        }
                    }
                } else {
                    await MainActor.run {
                        currentSheet = .result(importResult: result)
                    }
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

// MARK: - Import Notice Banner

private struct ImportNoticeBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.subheadline)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("webCIS Roster File Required")
                    .font(.subheadline)
                    .fontWeight(.bold)

                Text("Import will only work with the file **EMAILED** from webCIS via **SEND MY ROSTER**")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
        )
    }
}

// MARK: - Import Method Card

private struct ImportMethodCard<Action: View>: View {
    //let method: Int
    let icon: String
    let iconColor: Color
    let title: String
    //let badge: String?
    //let badgeColor: Color
    let steps: [String]
    //var isRecommended: Bool = false
    let action: Action

    init(
        icon: String,
        iconColor: Color,
        title: String,
        steps: [String],
        @ViewBuilder action: () -> Action
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.steps = steps
        self.action = action()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                Spacer()

            }

            // Steps
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                            .frame(width: 20, height: 20)
                            .background(iconColor.opacity(0.12))
                            .clipShape(Circle())

                        Text(step)
                            .font(.subheadline)
                            //.fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
            }

            // Inline action (file picker button or paste area)
            action
        }
        .padding()
        .background(Color(.secondarySystemBackground).overlay(iconColor.opacity(0.05)))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    Color(.separator).opacity(0.4),
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Import Result View

private struct UnifiedRosterImportResultView: View {
    let result: PlannedFlightService.ImportResult
    let staleRemoved: Int
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Success/Warning Icon
                    if result.errors == 0 {
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

                        if staleRemoved > 0 {
                            ImportStatCard(
                                icon: "minus.circle.fill",
                                color: .red,
                                value: "\(staleRemoved)",
                                label: staleRemoved == 1 ? "Flight Removed" : "Flights Removed"
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
                ToolbarItem(placement: .topBarTrailing) {
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

// MARK: - Stale Flight Review View

private struct StaleFlightReviewView: View {
    let staleFlights: [FlightEntity]
    let rosterBase: String
    let onContinue: (_ toDelete: [FlightEntity]) -> Void
    let onSkip: () -> Void

    @State private var selectedIDs: Set<UUID> = []

    init(staleFlights: [FlightEntity], rosterBase: String, onContinue: @escaping (_ toDelete: [FlightEntity]) -> Void, onSkip: @escaping () -> Void) {
        self.staleFlights = staleFlights
        self.rosterBase = rosterBase
        self.onContinue = onContinue
        self.onSkip = onSkip
        let ids = Set(staleFlights.compactMap(\.id))
        self._selectedIDs = State(initialValue: ids)
    }

    private static let baseTimezones: [String: String] = [
        "BNE": "Australia/Brisbane",
        "SYD": "Australia/Sydney",
        "MEL": "Australia/Melbourne",
        "PER": "Australia/Perth",
        "ADL": "Australia/Adelaide",
        "CBR": "Australia/Sydney",
        "CNS": "Australia/Brisbane",
        "OOL": "Australia/Brisbane",
    ]

    private var baseTimezone: TimeZone {
        if let id = Self.baseTimezones[rosterBase.uppercased()],
           let tz = TimeZone(identifier: id) { return tz }
        return TimeZone(secondsFromGMT: 0)!
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stale flight list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Explanation header
                        VStack(spacing: 4) {
                            Text("\(staleFlights.count) Existing \(staleFlights.count == 1 ? "Flight" : "Flights") Not in Revised Roster")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)

                            Text("These Flights Will Be Removed From Your Logbook")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)

                        ForEach(staleFlights, id: \.id) { flight in
                            staleFlight(flight)
                        }
                    }
                    .padding()
                }

                // Bottom action bar
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        let toDelete = staleFlights.filter { selectedIDs.contains($0.id ?? UUID()) }
                        Button {
                            onContinue(toDelete)
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text(toDelete.isEmpty ? "Continue" : "Remove \(toDelete.count)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(toDelete.isEmpty ? Color.blue : Color.red)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Review Removals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        onSkip()
                    }
                }
            }
        }
    }

    private func staleFlight(_ flight: FlightEntity) -> some View {
        let flightID = flight.id ?? UUID()
        let isSelected = selectedIDs.contains(flightID)
        return Button {
            if isSelected {
                selectedIDs.remove(flightID)
            } else {
                selectedIDs.insert(flightID)
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .red : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(flight.flightNumber ?? "—")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        if let date = flight.date {
                            Text(staleFlightDate(date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(flight.fromAirport ?? "—")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(flight.toAirport ?? "—")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(isSelected ? Color.red.opacity(0.06) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func staleFlightDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd MMM y"
        formatter.timeZone = baseTimezone
        return formatter.string(from: date)
    }
}

#Preview {
    UnifiedRosterImportView()
}
