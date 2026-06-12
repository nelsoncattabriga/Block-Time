//
//  CalendarExportView.swift
//  Block-Time
//

import SwiftUI
import BlockTimeKit

// MARK: - View Model

@Observable
@MainActor
final class CalendarExportViewModel {

    // Filter state
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    var includePositioning: Bool = true
    var includeSimulator: Bool = true
    var futureFlightsOnly: Bool = false {
        didSet { futureFlightsOnlyDidChange(oldValue: oldValue) }
    }

    // Export state
    var isLoading: Bool = false
    var flightCount: Int = 0
    var dutyDayCount: Int = 0
    var shareItem: CalendarShareItem? = nil
    var errorMessage: String? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var hasUnflownFlights: Bool {
        let todayStr = Self.dateFormatter.string(from: Date())
        let farFuture = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
        let farFutureStr = Self.dateFormatter.string(from: farFuture)
        let future = FlightDatabaseService.shared.fetchFlights(from: todayStr, to: farFutureStr)
        return future.contains { isUnflown($0) }
    }

    private func futureFlightsOnlyDidChange(oldValue: Bool) {
        guard futureFlightsOnly, !oldValue else { return }
        let todayStr = Self.dateFormatter.string(from: Date())
        let farFuture = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
        let farFutureStr = Self.dateFormatter.string(from: farFuture)
        let future = FlightDatabaseService.shared.fetchFlights(from: todayStr, to: farFutureStr)
            .filter { isUnflown($0) }
        let dates = future.compactMap { Self.dateFormatter.date(from: $0.date) }
        if let earliest = dates.min(), let latest = dates.max() {
            startDate = earliest
            endDate = latest
        }
        includeSimulator = true
        includePositioning = true
        refreshCount()
    }

    private func isUnflown(_ flight: FlightSector) -> Bool {
        let block = Double(flight.blockTime) ?? 0
        let sim   = Double(flight.simTime)   ?? 0
        return block == 0 && sim == 0
    }

    func refreshCount() {
        let flights = filteredFlights()
        flightCount = flights.count
        dutyDayCount = Set(flights.map { $0.date }).count
    }

    func export() {
        isLoading = true
        errorMessage = nil

        let flights = filteredFlights()

        guard !flights.isEmpty else {
            errorMessage = "No flights found for the selected criteria."
            isLoading = false
            return
        }

        let icsContent = CalendarExportService.shared.generateICS(from: flights, settings: CalendarExportSettings.shared)

        let fileName = "BlockTime_Flights_\(filenameDateRange()).ics"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try icsContent.write(to: tempURL, atomically: true, encoding: .utf8)
            shareItem = CalendarShareItem(url: tempURL)
        } catch {
            errorMessage = "Could not create export file: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Private

    private func filteredFlights() -> [FlightSector] {
        let startStr = Self.dateFormatter.string(from: startDate)
        let endStr   = Self.dateFormatter.string(from: endDate)

        let all = FlightDatabaseService.shared.fetchFlights(from: startStr, to: endStr)

        return all.filter { flight in
            if !includeSimulator {
                let sim = Double(flight.simTime) ?? 0
                if sim > 0 { return false }
            }
            if !includePositioning && flight.isPositioning {
                return false
            }
            return true
        }
    }

    private func filenameDateRange() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return "\(f.string(from: startDate))_\(f.string(from: endDate))"
    }
}

// MARK: - Share Item (Identifiable wrapper for sheet)

struct CalendarShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Main View

struct CalendarExportView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeService.self) private var themeService
    @State private var viewModel = CalendarExportViewModel()
    @State private var showFormatSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeService.getGradient().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Text("Create an .ics file to import into any Calendar app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                        CalendarExportFilterCard(viewModel: viewModel, showFormatSheet: $showFormatSheet)
                        CalendarExportFlightCountCard(viewModel: viewModel)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Export to Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: viewModel.export) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Export")
                        }
                    }
                    .disabled(viewModel.flightCount == 0 || viewModel.isLoading)
                }
            }
            .sheet(item: $viewModel.shareItem) { item in
                ShareSheet(url: item.url)
            }
            .sheet(isPresented: $showFormatSheet, onDismiss: viewModel.refreshCount) {
                CalendarFormatSheet(settings: CalendarExportSettings.shared)
                    .environment(themeService)
            }
            .alert("Export Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear(perform: viewModel.refreshCount)
            .onChange(of: viewModel.startDate)          { _, _ in viewModel.refreshCount() }
            .onChange(of: viewModel.endDate)            { _, _ in viewModel.refreshCount() }
            .onChange(of: viewModel.includePositioning) { _, _ in viewModel.refreshCount() }
            .onChange(of: viewModel.includeSimulator)   { _, _ in viewModel.refreshCount() }
        }
    }
}

// MARK: - Filter Card

private struct CalendarExportFilterCard: View {
    @Bindable var viewModel: CalendarExportViewModel
    @Binding var showFormatSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(.purple)
                    .font(.title3)
                Text("Filter")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if viewModel.hasUnflownFlights {
                Toggle(isOn: $viewModel.futureFlightsOnly) {
                    Label("Unflown flights only", systemImage: "calendar.badge.clock")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .tint(.blue)
            }

            CalendarExportDateRow(
                label: "From",
                date: $viewModel.startDate,
                maxDate: viewModel.endDate,
                disabled: viewModel.futureFlightsOnly
            )

            CalendarExportDateRow(
                label: "To",
                date: $viewModel.endDate,
                minDate: viewModel.startDate,
                disabled: viewModel.futureFlightsOnly
            )

            Divider()

            Toggle(isOn: $viewModel.includePositioning) {
                Text("Include PAX Flights")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .tint(.purple)

            Toggle(isOn: $viewModel.includeSimulator) {
                Text("Include SIMs")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .tint(.purple)

            Divider()

            Button {
                showFormatSheet = true
            } label: {
                HStack {
                    Text("Event Format")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - Date Row

private struct CalendarExportDateRow: View {
    let label: String
    @Binding var date: Date
    var minDate: Date? = nil
    var maxDate: Date? = nil
    var disabled: Bool = false

    @State private var showingPicker = false

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Spacer()

            Button {
                showingPicker = true
            } label: {
                Text(Self.displayFormatter.string(from: date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(disabled ? .secondary : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(disabled)
        }
        .sheet(isPresented: $showingPicker) {
            CalendarDatePickerSheet(
                date: $date,
                title: label,
                minDate: minDate,
                maxDate: maxDate,
                isPresented: $showingPicker
            )
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Date Picker Sheet

private struct CalendarDatePickerSheet: View {
    @Binding var date: Date
    let title: String
    let minDate: Date?
    let maxDate: Date?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            datePicker
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isPresented = false }
                    }
                }
        }
    }

    @ViewBuilder
    private var datePicker: some View {
        if let min = minDate, let max = maxDate {
            DatePicker(title, selection: $date, in: min...max, displayedComponents: .date)
        } else if let min = minDate {
            DatePicker(title, selection: $date, in: min..., displayedComponents: .date)
        } else if let max = maxDate {
            DatePicker(title, selection: $date, in: ...max, displayedComponents: .date)
        } else {
            DatePicker(title, selection: $date, displayedComponents: .date)
        }
    }
}

// MARK: - Flight Count Card

private struct CalendarExportFlightCountCard: View {
    let viewModel: CalendarExportViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane")
                .foregroundStyle(.teal)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("^[\(viewModel.flightCount) flight](inflect: true) will be exported")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                subtitleText
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.teal.opacity(0.3), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var subtitleText: some View {
        let mode = CalendarExportSettings.shared.mode
        let days = viewModel.dutyDayCount
        let sectors = viewModel.flightCount
        switch mode {
        case .allDayOnly:
            Text("^[\(days) duty day](inflect: true) will be exported as all-day events")
        case .sectorsOnly:
            Text("^[\(sectors) sector event](inflect: true) will be exported")
        case .both:
            Text("^[\(days) duty day](inflect: true) + ^[\(sectors) sector event](inflect: true)")
        }
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    CalendarExportView()
        .environment(ThemeService.shared)
}
