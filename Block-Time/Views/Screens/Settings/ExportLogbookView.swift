//
//  ExportLogbookView.swift
//  Block-Time
//
//  Created by Nelson on 20/10/2025.
//

import SwiftUI

struct ExportLogbookView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var exportError: String?
    @State private var flightCount: Int = 0
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        exportSetupView
                    }
                }

                if isExporting {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    ProgressView("Exporting…")
                        .progressViewStyle(.circular)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Export Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Export", action: performExport)
                        .disabled(isExporting || flightCount == 0)
                }
            }
            .alert("Export Error", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: {
                if let error = exportError { Text(error) }
            }
            .onAppear { loadFlightCount() }
            .sheet(isPresented: $showShareSheet, onDismiss: { dismiss() }) {
                if let fileURL = exportedFileURL {
                    ExportShareSheet(items: [fileURL])
                }
            }
            .allowsHitTesting(!isExporting)
        }
    }

    // MARK: - Export Setup View

    private var exportSetupView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.indigo)

                Text("Export Logbook")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.top)

            VStack(spacing: 8) {
                Text("\(flightCount)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.indigo)

                Text(flightCount == 1 ? "flight to export" : "flights to export")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.indigo.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(icon: "doc.text.fill", text: "Export format: CSV File")
                InstructionRow(icon: "calendar", text: "All flights sorted by date (oldest first)")
                InstructionRow(icon: "checkmark.circle.fill", text: "Compatible with other logbooks")
            }
            .padding()
            .background(Color.indigo.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Helper Functions

    private func loadFlightCount() {
        flightCount = FlightDatabaseService.shared.fetchAllFlights().count
    }

    private func performExport() {
        isExporting = true

        Task {
            do {
                let flights = FlightDatabaseService.shared.fetchAllFlights()

                guard !flights.isEmpty else {
                    await MainActor.run {
                        isExporting = false
                        exportError = "No flights to export. Your logbook is empty."
                    }
                    return
                }

                let flightSortFormatter = DateFormatter()
                flightSortFormatter.dateFormat = "dd/MM/yyyy"
                let sortedFlights = flights.sorted { f1, f2 in
                    if let d1 = flightSortFormatter.date(from: f1.date), let d2 = flightSortFormatter.date(from: f2.date) {
                        return d1 < d2
                    }
                    return f1.date < f2.date
                }

                let definitions = CustomCounterService.shared.definitions
                let csvString = FileImportService.shared.exportToCSV(
                    flights: sortedFlights,
                    definitions: definitions,
                    useLabelsAsHeaders: true,
                    writeDefinitionsHeader: false
                )

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
                let fileName = "Logbook_Export_\(dateFormatter.string(from: Date())).csv"
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    isExporting = false
                    exportedFileURL = fileURL
                    showShareSheet = true
                }

            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = "Export failed: \(error.localizedDescription)"
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
                .foregroundColor(.indigo)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - Export Share Sheet

private struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportLogbookView()
}
