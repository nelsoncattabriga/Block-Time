//
//  CalendarExportView.swift
//  Block-Time
//

import SwiftUI

// MARK: - View Model

@Observable
@MainActor
final class CalendarExportViewModel {

    // Filter state
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    var includePositioning: Bool = true
    var includeSimulator: Bool = true

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

    /// Finds the date range of future (unflown) flights and snaps the filter to it.
    /// Returns false if no future flights exist.
    @discardableResult
    func selectUnflownFlights() -> Bool {
        let todayStr = Self.dateFormatter.string(from: Date())
        // Fetch a wide forward window — 2 years should cover any roster
        let farFuture = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
        let farFutureStr = Self.dateFormatter.string(from: farFuture)

        let future = FlightDatabaseService.shared.fetchFlights(from: todayStr, to: farFutureStr)
            .filter { isUnflown($0) }

        guard !future.isEmpty else { return false }

        // Find earliest and latest dates among unflown flights
        let dates = future.compactMap { Self.dateFormatter.date(from: $0.date) }
        guard let earliest = dates.min(), let latest = dates.max() else { return false }

        startDate = earliest
        endDate   = latest
        
        includeSimulator = true
        includePositioning = true
        refreshCount()
        return true
    }

    var hasUnflownFlights: Bool {
        let todayStr = Self.dateFormatter.string(from: Date())
        let farFuture = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
        let farFutureStr = Self.dateFormatter.string(from: farFuture)
        let future = FlightDatabaseService.shared.fetchFlights(from: todayStr, to: farFutureStr)
        return future.contains { isUnflown($0) }
    }

    /// A flight is "unflown" if it has no actual block or sim time recorded.
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
                        CalendarExportHeaderCard()
                        CalendarExportFilterCard(viewModel: viewModel)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { showFormatSheet = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
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

// MARK: - Header Card

private struct CalendarExportHeaderCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            Text("Export Flights to Calendar")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Creates a standard .ics file that can be opened directly in Calendar, Google Calendar, Outlook, or any other calendar app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - Filter Card

private struct CalendarExportFilterCard: View {
    @Bindable var viewModel: CalendarExportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(.purple)
                    .font(.title3)
                Text("Filter")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                Spacer()
                
                if viewModel.hasUnflownFlights {
                    Button {
                        viewModel.selectUnflownFlights()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.subheadline)
                            Text("Flights Not Flown Only")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

            }

            CalendarExportDateRow(
                label: "From",
                date: $viewModel.startDate,
                maxDate: viewModel.endDate
            )

            CalendarExportDateRow(
                label: "To",
                date: $viewModel.endDate,
                minDate: viewModel.startDate
            )

            Divider()

            Toggle(isOn: $viewModel.includePositioning) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include PAX Flights")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                }
            }
            .tint(.purple)

            Toggle(isOn: $viewModel.includeSimulator) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include SIMs")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .tint(.purple)
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
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
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
                .onChange(of: date) { isPresented = false }
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

    private var subtitle: String {
        let mode = CalendarExportSettings.shared.mode
        let days = viewModel.dutyDayCount
        let sectors = viewModel.flightCount
        switch mode {
        case .allDayOnly:
            return "^[\(days) duty day](inflect: true) will be exported as all-day events"
        case .sectorsOnly:
            return "^[\(sectors) sector event](inflect: true) will be exported"
        case .both:
            return "^[\(days) duty day](inflect: true) + ^[\(sectors) sector event](inflect: true)"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane")
                .foregroundStyle(.teal)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("^[\(viewModel.flightCount) flight](inflect: true) will be exported")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(subtitle)
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
