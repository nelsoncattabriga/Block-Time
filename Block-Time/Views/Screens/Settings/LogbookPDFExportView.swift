//
//  LogbookPDFExportView.swift
//  Block-Time
//

import SwiftUI
import PDFKit

// MARK: - Date Range Preset

enum PDFDateRangePreset: String, CaseIterable {
    case all          = "All"
    case last12Months = "Last 12 Months"
    case custom       = "Custom"
}

// MARK: - Content Mode

enum PDFContentMode: String, CaseIterable {
    case allFlights          = "Standard"
    case instructorHoursOnly = "Trainer Log"
}

// MARK: - Export View

struct LogbookPDFExportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isGenerating = false
    @State private var pdfURL: URL?
    @State private var errorMessage: String?
    @State private var showPreview = false
    @State private var flightCount = 0
    @State private var earliestDate: Date = Date()
    @State private var latestDate: Date = Date()

    @AppStorage("logbookPDFPilotName")    private var logbookName: String = ""
    @AppStorage("logbookPDFArn")          private var arn: String = ""
    @AppStorage("logbookPDFDatePreset")   private var datePresetRaw: String = PDFDateRangePreset.all.rawValue
    @AppStorage("logbookPDFDateFormat")   private var dateFormat: String = "dd MMM yyyy"
    @AppStorage("logbookPDFCustomFrom")   private var customFromInterval: Double = 0
    @AppStorage("logbookPDFCustomTo")     private var customToInterval: Double = 0
    @AppStorage("logbookPDFUseLocalDates") private var useLocalDates: Bool = true
    @AppStorage("logbookPDFUseHHMM")       private var useHHMM: Bool = false
    @AppStorage("logbookPDFContentMode3")  private var contentModeRaw: String = PDFContentMode.allFlights.rawValue
    @AppStorage("showSpInsSelector")       private var showSpInsSelector: Bool = false
    /// Comma-separated columnIndex ints of the custom fields selected for Training Record PDF.
    @AppStorage("logbookPDFTrainingCustomFields") private var trainingCustomFieldsRaw: String = ""

    private var datePreset: PDFDateRangePreset {
        PDFDateRangePreset(rawValue: datePresetRaw) ?? .all
    }
    private var contentMode: PDFContentMode {
        PDFContentMode(rawValue: contentModeRaw) ?? .allFlights
    }
    private var customFrom: Date {
        get { customFromInterval > 0 ? Date(timeIntervalSince1970: customFromInterval) : earliestDate }
    }
    private var customTo: Date {
        get { customToInterval > 0 ? Date(timeIntervalSince1970: customToInterval) : latestDate }
    }

    /// Resolves the raw comma-separated columnIndex string into definitions in saved order,
    /// intersected with currently-defined custom fields, capped at 7.
    private var selectedCustomFields: [CustomCounterDefinition] {
        let indices = trainingCustomFieldsRaw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let available = CustomCounterService.shared.definitions
        let resolved = indices.compactMap { idx in available.first(where: { $0.columnIndex == idx }) }
        return Array(resolved.prefix(10))
    }

    /// Whether the given custom field is selected for Training Record.
    private func isCustomFieldSelected(_ def: CustomCounterDefinition) -> Bool {
        selectedCustomFields.contains(where: { $0.columnIndex == def.columnIndex })
    }

    /// Toggles a custom field in/out of the Training Record selection.
    private func toggleCustomField(_ def: CustomCounterDefinition) {
        var indices = trainingCustomFieldsRaw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if let pos = indices.firstIndex(of: def.columnIndex) {
            indices.remove(at: pos)
        } else {
            guard indices.count < 10 else { return }
            indices.append(def.columnIndex)
        }
        trainingCustomFieldsRaw = indices.map(String.init).joined(separator: ",")
    }

    private static let dateFormats: [(label: String, format: String)] = [
        ("04 Apr 2026", "dd MMM yyyy"),
        ("4 Apr 2026",  "d MMM yyyy"),
        ("04 Apr 26",   "dd MMM yy"),
        ("4 Apr 26",    "d MMM yy"),
        ("04/04/2026",  "dd/MM/yyyy"),
        ("04/04/26",    "dd/MM/yy"),
        ("04-04-2026",  "dd-MM-yyyy"),
        ("04-04-26",    "dd-MM-yy"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        setupView
                    }
                    .padding()
                }

                if isGenerating {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    ProgressView("Generating…")
                        .progressViewStyle(.circular)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .allowsHitTesting(!isGenerating)
            .navigationTitle("Print Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Print") { Task { await generatePDF() } }
                        .disabled(flightCount == 0 || isGenerating)
                }
            }
            .alert("Export Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
            .fullScreenCover(isPresented: $showPreview) {
                if let url = pdfURL {
                    PDFPreviewView(url: url)
                }
            }
            .onAppear {
                if !showSpInsSelector { contentModeRaw = PDFContentMode.allFlights.rawValue }
                loadFlights()
            }
            .onChange(of: showSpInsSelector) { _, enabled in
                if !enabled { contentModeRaw = PDFContentMode.allFlights.rawValue }
            }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.brown)

                Text("Print Logbook")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Name + ARN
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name for cover page")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("e.g. J. Smith", text: $logbookName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("ARN")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("e.g. 123456", text: $arn)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)
                }
                .frame(width: 110)
            }

            // Content — only shown when Log Instructor Time is enabled
            if showSpInsSelector {
                Picker("Content", selection: $contentModeRaw) {
                    ForEach(PDFContentMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: contentModeRaw) { _, _ in updateFlightCount() }

                // Custom Fields picker — shown only in Training Record mode
                if contentMode == .instructorHoursOnly {
                    customFieldsPickerSection
                }
            }

            // Date Range
            VStack(alignment: .leading, spacing: 10) {
                Text("Date Range")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Date Range", selection: $datePresetRaw) {
                    ForEach(PDFDateRangePreset.allCases, id: \.rawValue) { preset in
                        Text(preset.rawValue).tag(preset.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: datePresetRaw) { _, _ in updateFlightCount() }

                if datePreset == .custom {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("From")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: Binding(
                                get: { customFrom },
                                set: { customFromInterval = $0.timeIntervalSince1970 }
                            ), in: earliestDate...latestDate, displayedComponents: .date)
                            .labelsHidden()
                            .onChange(of: customFromInterval) { _, _ in updateFlightCount() }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("To")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: Binding(
                                get: { customTo },
                                set: { customToInterval = $0.timeIntervalSince1970 }
                            ), in: earliestDate...latestDate, displayedComponents: .date)
                            .labelsHidden()
                            .onChange(of: customToInterval) { _, _ in updateFlightCount() }
                        }
                        Spacer()
                    }
                }

                Text("\(flightCount) \(flightCount == 1 ? "flight" : "flights") in range")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.brown.opacity(0.06))
            .cornerRadius(12)

            // Date Format + timezone
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text("Date Format")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $dateFormat) {
                        ForEach(Self.dateFormats, id: \.format) { option in
                            Text(option.label).tag(option.format)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.brown)
                }

                HStack(alignment: .center) {
                    Text("Flight Date")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $useLocalDates) {
                        Text("Local").tag(true)
                        Text("UTC").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }

                HStack(alignment: .center) {
                    Text("Time Format")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $useHHMM) {
                        Text("Decimal").tag(false)
                        Text("HH:MM").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }

            }
            .padding()
            .background(Color.brown.opacity(0.06))
            .cornerRadius(12)

        }
    }

    // MARK: - Custom Fields Picker

    @ViewBuilder
    private var customFieldsPickerSection: some View {
        let defs = CustomCounterService.shared.definitions

        VStack(alignment: .leading, spacing: 10) {
            Text("Custom Fields to include")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if defs.isEmpty {
                Text("No custom fields defined — add them in Settings")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(defs) { def in
                    let isSelected = isCustomFieldSelected(def)

                    Button {
                        toggleCustomField(def)
                    } label: {
                        HStack {
                            Text(def.label)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(isSelected ? "Yes" :"No")
                                .font(.subheadline)
                                .foregroundColor(.brown)
                            
//                            Image(systemName: isSelected ? "checkmark" : "xmark")
//                                .foregroundColor(isSelected ? .green : .brown)
//                                .foregroundColor(isSelected ? .brown : .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.brown.opacity(0.06))
        .cornerRadius(12)
    }

    // MARK: - Actions

    /// Base content predicate per selected content mode.
    private func matchesContentMode(_ f: FlightSector) -> Bool {
        switch contentMode {
        case .allFlights:
            return !f.isPositioning && (f.blockTimeValue > 0 || f.simTimeValue > 0)
        case .instructorHoursOnly:
            return f.spInsTimeValue > 0
        }
    }

    private static let inputDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    /// Returns the effective date string for a flight — local if enabled, UTC otherwise.
    /// Falls back to UTC if outTime is empty or airport is unknown.
    private func effectiveDateString(for flight: FlightSector) -> String {
        guard useLocalDates, !flight.outTime.isEmpty else { return flight.date }
        let local = AirportService.shared.convertToLocalDate(
            utcDateString: flight.date,
            utcTimeString: flight.outTime,
            airportICAO: flight.fromAirport
        )
        return local.isEmpty ? flight.date : local
    }

    /// Returns a Date representing the full local departure datetime for sort ordering.
    /// Combines the local date string with the local time so ordering is correct across midnight.
    private func effectiveSortDate(for flight: FlightSector) -> Date {
        let utcTime = flight.outTime.isEmpty ? flight.scheduledDeparture : flight.outTime
        guard useLocalDates, !utcTime.isEmpty else {
            // UTC: combine date string + time string directly
            let combined = "\(flight.date) \(utcTime)"
            return Self.utcDateTimeDF.date(from: combined) ?? Self.inputDF.date(from: flight.date) ?? .distantPast
        }
        let localTime = AirportService.shared.convertToLocalTime(
            utcDateString: flight.date,
            utcTimeString: utcTime,
            airportICAO: flight.fromAirport
        )
        let localDate = AirportService.shared.convertToLocalDate(
            utcDateString: flight.date,
            utcTimeString: utcTime,
            airportICAO: flight.fromAirport
        )
        let combined = "\(localDate) \(localTime)"
        return Self.localDateTimeDF.date(from: combined) ?? Self.inputDF.date(from: localDate) ?? .distantPast
    }

    private static let utcDateTimeDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HHmm"
        f.locale = Locale(identifier: "en_AU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let localDateTimeDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HHmm"
        f.locale = Locale(identifier: "en_AU")
        f.timeZone = TimeZone(secondsFromGMT: 0)  // local time already offset-adjusted, parse as flat
        return f
    }()

    private func loadFlights() {
        let all = FlightDatabaseService.shared.fetchAllFlights()
            .filter { !$0.isPositioning && ($0.blockTimeValue > 0 || $0.simTimeValue > 0) }
        let dates = all.compactMap { Self.inputDF.date(from: effectiveDateString(for: $0)) }
        earliestDate = dates.min() ?? Date()
        latestDate   = dates.max() ?? Date()
        if customFromInterval == 0 { customFromInterval = earliestDate.timeIntervalSince1970 }
        if customToInterval   == 0 { customToInterval   = latestDate.timeIntervalSince1970 }
        updateFlightCount()
    }

    private func updateFlightCount() {
        let all = FlightDatabaseService.shared.fetchAllFlights()
            .filter { matchesContentMode($0) }
        flightCount = filtered(from: all).count
    }

    private func filtered(from flights: [FlightSector]) -> [FlightSector] {
        switch datePreset {
        case .all:
            return flights
        case .last12Months:
            let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
            return flights.filter {
                (Self.inputDF.date(from: effectiveDateString(for: $0)) ?? .distantPast) >= cutoff
            }
        case .custom:
            let from = customFrom
            let to   = Calendar.current.date(byAdding: .day, value: 1, to: customTo) ?? customTo
            return flights.filter {
                guard let d = Self.inputDF.date(from: effectiveDateString(for: $0)) else { return false }
                return d >= from && d < to
            }
        }
    }

    @MainActor
    private func generatePDF() async {
        isGenerating = true
        try? await Task.sleep(nanoseconds: 32_000_000) // two frames — guarantees overlay renders before main-thread work
        let name      = logbookName.trimmingCharacters(in: .whitespacesAndNewlines)
        let arnNumber = arn.trimmingCharacters(in: .whitespacesAndNewlines)
        let format    = dateFormat
        let hhmm      = useHHMM
        let preset    = datePreset
        let from      = customFrom
        let to        = customTo
        let coverTitle = contentMode == .instructorHoursOnly ? "TRAINER LOG" : "PILOT LOGBOOK"
        // Capture custom fields on main actor before Task.detached
        let pdfCustomFields = contentMode == .instructorHoursOnly ? selectedCustomFields : []

        do {
            // Fetch on main actor (fast)
            let all = FlightDatabaseService.shared.fetchAllFlights()
                .filter { matchesContentMode($0) }

            // Filter on main actor (AirportService calls for effective dates)
            let filtered: [FlightSector]
            switch preset {
            case .all:
                filtered = all
            case .last12Months:
                let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
                filtered = all.filter { (Self.inputDF.date(from: effectiveDateString(for: $0)) ?? .distantPast) >= cutoff }
            case .custom:
                let toExclusive = Calendar.current.date(byAdding: .day, value: 1, to: to) ?? to
                filtered = all.filter {
                    guard let d = Self.inputDF.date(from: effectiveDateString(for: $0)) else { return false }
                    return d >= from && d < toExclusive
                }
            }

            // Sort + resolve dates on main actor
            let sorted = filtered.sorted { effectiveSortDate(for: $0) < effectiveSortDate(for: $1) }
            let resolvedDates = sorted.map { effectiveDateString(for: $0) }

            // Compute totals for flights before the selected range (career BF for partial exports)
            var priorTotals = PageTotals()
            if preset != .all {
                let filteredSet = Set(filtered)
                for f in all where !filteredSet.contains(f) {
                    priorTotals.accumulate(f)
                }
            }

            // Render off-thread
            let pdfData = await Task.detached(priority: .userInitiated) {
                LogbookPDFRenderer.render(
                    flights: sorted, resolvedDates: resolvedDates,
                    pilotName: name, arn: arnNumber, title: coverTitle,
                    dateFormat: format, useHHMM: hhmm,
                    priorTotals: priorTotals,
                    customFields: pdfCustomFields)
            }.value

            let timestamp = DateFormatter()
            timestamp.dateFormat = "yyyy-MM-dd_HHmm"
            let fileName = "Logbook_\(timestamp.string(from: Date())).pdf"
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let url = cacheDir.appendingPathComponent(fileName)

            try pdfData.write(to: url, options: .atomic)
            isGenerating = false
            pdfURL = url
            showPreview = true
        } catch {
            isGenerating = false
            errorMessage = "Failed to write PDF: \(error.localizedDescription)"
        }
    }
}

// MARK: - PDF Preview Screen

struct PDFPreviewView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            PDFKitView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Logbook Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    PDFShareSheet(items: [url])
                }
        }
    }
}

// MARK: - PDFKit wrapper

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.pageBreakMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Supporting views

private struct PDFInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.brown)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

private struct PDFShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // On iPad UIActivityViewController must be a popover — anchor it to the centre of the screen
        // so it appears as a full-size popover rather than a narrow guess from UIKit.
        if let popover = vc.popoverPresentationController {
            popover.permittedArrowDirections = []
            popover.sourceView = UIView()
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                popover.sourceRect = CGRect(
                    x: window.bounds.midX,
                    y: window.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.sourceView = window
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    LogbookPDFExportView()
}
