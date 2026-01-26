import SwiftUI

// MARK: - Aircraft Type Time Card
struct AircraftTypeTimeCard: View {
    let statistics: FlightStatistics
    var isEditMode: Bool = false
    @State private var selectedAircraftType: String = ""
    @State private var availableAircraftTypes: [String] = []
    @State private var aircraftStats: (totalHours: Double, totalSectors: Int, p1Time: Double, p1usTime: Double, p2Time: Double, simTime: Double) = (0.0, 0, 0.0, 0.0, 0.0, 0.0)
    private let settings = LogbookSettings.shared
    @State private var showTimesInHoursMinutes: Bool = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if isEditMode {
                cardContent
            } else {
                Menu {
                    ForEach(availableAircraftTypes, id: \.self) { aircraftType in
                        Button {
                            selectedAircraftType = aircraftType
                            settings.selectedAircraftType = aircraftType
                            settings.saveSettings()
                            loadAircraftStats()
                        } label: {
                            HStack {
                                Text(aircraftType)
                                if aircraftType == selectedAircraftType {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    cardContent
                }
            }
        }
        .onAppear {
            // Load saved selection first, before loading available types
            selectedAircraftType = settings.selectedAircraftType
            loadAvailableAircraftTypes()
            loadAircraftStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            loadAvailableAircraftTypes()
            loadAircraftStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            showTimesInHoursMinutes = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
        }
    }

    private func loadAvailableAircraftTypes() {
        availableAircraftTypes = FlightDatabaseService.shared.getAllAircraftTypes()

        // If no aircraft type is selected and types are available, select the first one
        if selectedAircraftType.isEmpty && !availableAircraftTypes.isEmpty {
            selectedAircraftType = availableAircraftTypes[0]
            settings.selectedAircraftType = selectedAircraftType
            settings.saveSettings()
            loadAircraftStats()
        } else if !selectedAircraftType.isEmpty && !availableAircraftTypes.contains(selectedAircraftType) {
            // If the saved type no longer exists (e.g., after deleting all flights), select first available
            if !availableAircraftTypes.isEmpty {
                selectedAircraftType = availableAircraftTypes[0]
                settings.selectedAircraftType = selectedAircraftType
                settings.saveSettings()
                loadAircraftStats()
            }
        }
    }

    private func loadAircraftStats() {
        guard !selectedAircraftType.isEmpty else {
            aircraftStats = (0.0, 0, 0.0, 0.0, 0.0, 0.0)
            return
        }

        aircraftStats = FlightDatabaseService.shared.getDetailedFlightStatistics(for: selectedAircraftType)
    }

    // Get time entries that have values (similar to SummaryRow)
    // On iPad or iPhone single-column mode: show all time breakdowns
    // On iPhone 2-column grid mode: show only Total
    private var timeEntries: [(label: String, value: Double)] {
        var entries: [(String, Double)] = []

        if aircraftStats.totalHours > 0 {
            entries.append(("Total", aircraftStats.totalHours))
        }

        // Show detailed breakdowns on iPad or in iPhone single-column mode
        if isIPad || settings.isCompactView {
            if aircraftStats.p1Time > 0 {
                entries.append(("P1", aircraftStats.p1Time))
            }
            if aircraftStats.p1usTime > 0 {
                entries.append(("P1US", aircraftStats.p1usTime))
            }
            if aircraftStats.p2Time > 0 {
                entries.append(("P2", aircraftStats.p2Time))
            }
            if aircraftStats.simTime > 0 {
                entries.append(("SIM", aircraftStats.simTime))
            }
        }

        return entries
    }

    // Format time value
    private func formatTime(_ value: Double) -> String {
        if showTimesInHoursMinutes {
            return FlightSector.decimalToHHMM(value)
        } else {
            return String(format: "%.1f hrs", value)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedAircraftType.isEmpty ? "Select Type" : selectedAircraftType)
                    .iPadScaledFont(.headline)
                    .foregroundColor(.secondary)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "airplane")
                    .foregroundColor(.mint)
                    .iPadScaledFont(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                if isIPad {
                    // iPad: show time entries in a single row to maintain card height
                    if !timeEntries.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(timeEntries, id: \.label) { entry in
                                HStack(spacing: 0) {
                                    Text("\(entry.label): ")
                                        .iPadScaledFont(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatTime(entry.value))
                                        .iPadScaledFont(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                } else if settings.isCompactView {
                    // iPhone single-column mode: show all time entries in 2-column grid
                    if !timeEntries.isEmpty {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 6) {
                            ForEach(timeEntries, id: \.label) { entry in
                                HStack(spacing: 0) {
                                    Text("\(entry.label): ")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatTime(entry.value))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else {
                    // iPhone 2-column grid mode: show just total hours
                    Text(formatTime(aircraftStats.totalHours))
                        .iPadScaledFont(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                // Spacer to match progress bar height in other cards
                Spacer()
                    .frame(height: 6)

                Text("\(aircraftStats.totalSectors) sector\(aircraftStats.totalSectors == 1 ? "" : "s")")
                    .iPadScaledFont(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.mint.opacity(0.3), lineWidth: 1)
        )
    }
}
