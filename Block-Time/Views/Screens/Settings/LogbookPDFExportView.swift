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

    private var datePreset: PDFDateRangePreset {
        PDFDateRangePreset(rawValue: datePresetRaw) ?? .all
    }
    private var customFrom: Date {
        get { customFromInterval > 0 ? Date(timeIntervalSince1970: customFromInterval) : earliestDate }
    }
    private var customTo: Date {
        get { customToInterval > 0 ? Date(timeIntervalSince1970: customToInterval) : latestDate }
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
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    setupView
                }
                .padding()
            }
            .navigationTitle("Print Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
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
            .onAppear { loadFlights() }
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

            // Generate button
            Button { Task { await generatePDF() } } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .brown))
                    } else {
                        Image(systemName: "books.vertical.fill")
                            .foregroundColor(.brown)
                    }
                    Text(isGenerating ? "Generating…" : "Generate PDF")
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brown.opacity(0.12))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brown.opacity(0.4), lineWidth: 1))
            }
            .disabled(isGenerating || flightCount == 0)
        }
    }

    // MARK: - Actions

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
            .filter { !$0.isPositioning && ($0.blockTimeValue > 0 || $0.simTimeValue > 0) }
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
        await Task.yield()  // let SwiftUI render the spinner before blocking work begins
        let name      = logbookName.trimmingCharacters(in: .whitespacesAndNewlines)
        let arnNumber = arn.trimmingCharacters(in: .whitespacesAndNewlines)
        let format    = dateFormat
        let hhmm      = useHHMM
        let preset    = datePreset
        let from      = customFrom
        let to        = customTo

        do {
            // Fetch on main actor (fast)
            let all = FlightDatabaseService.shared.fetchAllFlights()
                .filter { !$0.isPositioning && ($0.blockTimeValue > 0 || $0.simTimeValue > 0) }

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

            // Render off-thread
            let pdfData = await Task.detached(priority: .userInitiated) {
                LogbookPDFRenderer.render(
                    flights: sorted, resolvedDates: resolvedDates,
                    pilotName: name, arn: arnNumber, dateFormat: format, useHHMM: hhmm)
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
        NavigationView {
            PDFKitView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Logbook Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
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
        .navigationViewStyle(.stack)
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
