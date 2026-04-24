//
//  LogbookPDFExportView.swift
//  Block-Time
//

import SwiftUI
import PDFKit

struct LogbookPDFExportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isGenerating = false
    @State private var pdfURL: URL?
    @State private var errorMessage: String?
    @State private var showPreview = false
    @State private var flightCount = 0

    private var pilotName: String {
        UserDefaults.standard.string(forKey: "defaultCaptainName") ?? ""
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
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
            .onAppear { loadFlightCount() }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.brown)

                Text("Print Logbook")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Generates a formatted PDF in the style of a paper logbook.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            VStack(spacing: 8) {
                Text("\(flightCount)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.brown)

                Text(flightCount == 1 ? "flight to include" : "flights to include")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Positioning and future flights are excluded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.brown.opacity(0.1))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 12) {
                PDFInfoRow(icon: "person.fill",       text: "Pilot: \(pilotName.isEmpty ? "Not set" : pilotName)")
                PDFInfoRow(icon: "doc.text",           text: "A4 landscape, 20 rows per page")
                PDFInfoRow(icon: "tablecells",         text: "Block, Night, P1, P1US, P2, Instr, Sim, Sp·Ins")
                PDFInfoRow(icon: "airplane.departure", text: "T/O & landings, approach types")
            }
            .padding()
            .background(Color.brown.opacity(0.08))
            .cornerRadius(12)

            Button(action: generatePDF) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .brown))
                    } else {
                        Image(systemName: "doc.richtext.fill")
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

    private func loadFlightCount() {
        let flights = FlightDatabaseService.shared.fetchAllFlights()
        flightCount = flights.filter { !$0.isPositioning && ($0.blockTimeValue > 0 || $0.simTimeValue > 0) }.count
    }

    private func generatePDF() {
        isGenerating = true

        // Fetch and filter on the main actor (required by FlightDatabaseService / FlightSector)
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        df.locale = Locale(identifier: "en_AU")

        let sorted = FlightDatabaseService.shared.fetchAllFlights()
            .filter { !$0.isPositioning && ($0.blockTimeValue > 0 || $0.simTimeValue > 0) }
            .sorted {
                guard let d1 = df.date(from: $0.date), let d2 = df.date(from: $1.date) else {
                    return $0.date < $1.date
                }
                return d1 < d2
            }

        let name = UserDefaults.standard.string(forKey: "defaultCaptainName") ?? ""

        // Hand value-type array to background for CPU-heavy rendering
        Task.detached(priority: .userInitiated) {
            let pdfData = LogbookPDFRenderer.render(flights: sorted, pilotName: name)

            let timestamp = DateFormatter()
            timestamp.dateFormat = "yyyy-MM-dd_HHmm"
            let fileName = "Logbook_\(timestamp.string(from: Date())).pdf"
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let url = cacheDir.appendingPathComponent(fileName)

            do {
                try pdfData.write(to: url, options: .atomic)
                await MainActor.run {
                    self.isGenerating = false
                    self.pdfURL = url
                    self.showPreview = true
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.errorMessage = "Failed to write PDF: \(error.localizedDescription)"
                }
            }
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
