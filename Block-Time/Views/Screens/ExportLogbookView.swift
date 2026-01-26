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
    @State private var exportComplete = false
    @State private var exportedFileURL: URL?
    @State private var exportError: String?
    @State private var flightCount: Int = 0
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if exportComplete {
                        // Export Success View
                        exportSuccessView
                    } else {
                        // Export Setup View
                        exportSetupView
                    }
                }
            }
            .navigationTitle("Export Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Export Error", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) {
                    exportError = nil
                }
            } message: {
                if let error = exportError {
                    Text(error)
                }
            }
            .onAppear {
                loadFlightCount()
            }
            .sheet(isPresented: $showShareSheet) {
                if let fileURL = exportedFileURL {
                    ExportShareSheet(items: [fileURL])
                }
            }
        }
    }

    // MARK: - Export Setup View

    private var exportSetupView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.indigo)

                Text("Export Logbook")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.top)

            // Flight Count Info
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

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(
                    icon: "doc.text.fill",
                    text: "Export format: CSV File"
                )

                InstructionRow(
                    icon: "calendar",
                    text: "All flights sorted by date (oldest first)"
                )

                InstructionRow(
                    icon: "checkmark.circle.fill",
                    text: "Compatible with other logbooks"
                )
            }
            .padding()
            .background(Color.indigo.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            // Export Button
            Button(action: {
                performExport()
            }) {
                HStack {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "square.and.arrow.up.fill")
                    }
                    Text(isExporting ? "Exporting..." : "Export Logbook")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isExporting || flightCount == 0 ? Color.gray : Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isExporting || flightCount == 0)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Export Success View

    private var exportSuccessView: some View {
        VStack(spacing: 24) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding(.top)

            // Summary
            VStack(spacing: 8) {
                Text("Export Complete")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Successfully exported \(flightCount) flight\(flightCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Export Info Card
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundColor(.indigo)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(flightCount)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text(flightCount == 1 ? "Flight Exported" : "Flights Exported")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.indigo.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()

            // Share Button
            if exportedFileURL != nil {
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Export File")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                Button(action: {
                    dismiss()
                }) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    // MARK: - Helper Functions

    private func loadFlightCount() {
        let flights = FlightDatabaseService.shared.fetchAllFlights()
        flightCount = flights.count
    }

    private func performExport() {
        isExporting = true

        Task {
            do {
                // Add minimum delay to show spinner for user feedback
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

                let flights = FlightDatabaseService.shared.fetchAllFlights()

                if flights.isEmpty {
                    await MainActor.run {
                        isExporting = false
                        exportError = "No flights to export. Your logbook is empty."
                    }
                    return
                }

                // Sort flights by date (oldest first)
                let sortedFlights = flights.sorted { flight1, flight2 in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd/MM/yyyy"
                    if let date1 = formatter.date(from: flight1.date),
                       let date2 = formatter.date(from: flight2.date) {
                        return date1 < date2
                    }
                    return flight1.date < flight2.date
                }

                // Generate CSV
                let csvString = FileImportService.shared.exportToCSV(flights: sortedFlights)

                // Create filename with timestamp
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
                let timestamp = dateFormatter.string(from: Date())
                let fileName = "Logbook_Export_\(timestamp).csv"

                // Save to temporary directory
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent(fileName)

                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    isExporting = false
                    exportedFileURL = fileURL
                    exportComplete = true
                    // Automatically show share sheet after export completes
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
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportLogbookView()
}
