import SwiftUI
import BlockTimeKit

// MARK: - Aircraft Type Time Card
// Pick your type card


struct AircraftTypeTimeCard: View {
    let statistics: FlightStatistics
    var isEditMode: Bool = false
    @State private var selectedAircraftType: String = ""
    @State private var availableAircraftTypes: [String] = []
    @State private var aircraftStats: (totalHours: Double, totalSectors: Int, p1Time: Double, p1usTime: Double, p2Time: Double, simTime: Double) = (0.0, 0, 0.0, 0.0, 0.0, 0.0)
    private let settings = LogbookSettings.shared
    @State private var showTimesInHoursMinutes: Bool = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
    @AppStorage("aircraftTypeCard_groupByFamily") private var groupByFamily: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isLandscape: Bool = UIDevice.current.orientation.isLandscape

    private var isIPad: Bool { horizontalSizeClass == .regular }

    // Distinct family names for types the user has actually flown
    private var availableFamilies: [String] {
        let families = availableAircraftTypes.compactMap { AircraftFleetService.familyName(for: $0) }
        return Array(Set(families)).sorted()
    }

    // Types belonging to the currently selected family
    private var typesForSelectedFamily: [String] {
        guard let fleet = AircraftFleetService.availableFleets.first(where: { $0.name == selectedAircraftType }) else { return [] }
        return availableAircraftTypes.filter { fleet.typeMatches($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header — only this row is the Menu label so the Family button below is not blocked
            HStack(spacing: 8) {
                if isEditMode {
                    headerLabel
                } else {
                    Menu {
                        let menuItems = groupByFamily ? availableFamilies : availableAircraftTypes
                        ForEach(menuItems, id: \.self) { item in
                            Button {
                                selectedAircraftType = item
                                settings.selectedAircraftType = item
                                settings.saveSettings()
                                Task { await loadAircraftStats() }
                            } label: {
                                HStack {
                                    Text(item)
                                    if item == selectedAircraftType {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        headerLabel
                    }
                    .buttonStyle(.plain)
                }
            }

            // Stats body — outside the Menu, receives taps normally
            VStack(alignment: .leading, spacing: 4) {
                if !timeEntries.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) {
                            ForEach(timeEntries, id: \.label) { entry in
                                HStack(spacing: 0) {
                                    Text("\(entry.label): ")
                                        .iPadScaledFont(.caption, phoneFont: .footnote)
                                        .foregroundStyle(.secondary)
                                    Text(formatTime(entry.value))
                                        .iPadScaledFont(.caption, phoneFont: .footnote)
                                        .bold()
                                        .foregroundStyle(.primary)
                                }
                            }
                            Spacer()
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(timeEntries, id: \.label) { entry in
                                HStack(spacing: 0) {
                                    Text("\(entry.label): ")
                                        .iPadScaledFont(.caption, phoneFont: .subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(formatTime(entry.value))
                                        .iPadScaledFont(.caption, phoneFont: .subheadline)
                                        .bold()
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                Spacer().frame(height: 6)

                HStack {
                    Text("\(aircraftStats.totalSectors) sector\(aircraftStats.totalSectors == 1 ? "" : "s")")
                        .iPadScaledFont(.caption, phoneFont: .subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("Type") {
                            guard groupByFamily else { return }
                            let current = selectedAircraftType
                            groupByFamily = false
                            let fleet = AircraftFleetService.availableFleets.first { $0.name == current }
                            selectedAircraftType = availableAircraftTypes.first { fleet?.types.contains($0) ?? false } ?? availableAircraftTypes.first ?? ""
                            settings.selectedAircraftType = selectedAircraftType
                            settings.saveSettings()
                            Task { await loadAircraftStats() }
                        }
                        Button("Family") {
                            guard !groupByFamily else { return }
                            let current = selectedAircraftType
                            groupByFamily = true
                            selectedAircraftType = AircraftFleetService.familyName(for: current) ?? availableFamilies.first ?? ""
                            settings.selectedAircraftType = selectedAircraftType
                            settings.saveSettings()
                            Task { await loadAircraftStats() }
                        }
                    } label: {
                        CardFilterChip(title: groupByFamily ? "Family" : "Type")
                    }
                    .tint(.primary)
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .task {
            selectedAircraftType = settings.selectedAircraftType
            await loadAvailableAircraftTypes()
            await loadAircraftStats()
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updateOrientation()
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            Task {
                await loadAvailableAircraftTypes()
                await loadAircraftStats()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            showTimesInHoursMinutes = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
            Task { await loadAircraftStats() }
        }
    }

    // The header row used as the Menu label
    private var headerLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.headline)
                .foregroundStyle(.mint)
            Text(selectedAircraftType.isEmpty ? "Select Type" : selectedAircraftType)
                .font(.headline)
                .bold()
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .imageScale(.small)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func loadAvailableAircraftTypes() async {
        availableAircraftTypes = await FlightDatabaseService.shared.getAllAircraftTypesAsync()
        let validItems = groupByFamily ? availableFamilies : availableAircraftTypes
        if selectedAircraftType.isEmpty && !validItems.isEmpty {
            selectedAircraftType = validItems[0]
            settings.selectedAircraftType = selectedAircraftType
            settings.saveSettings()
            await loadAircraftStats()
        } else if !selectedAircraftType.isEmpty && !validItems.contains(selectedAircraftType) {
            if !validItems.isEmpty {
                selectedAircraftType = validItems[0]
                settings.selectedAircraftType = selectedAircraftType
                settings.saveSettings()
                await loadAircraftStats()
            }
        }
    }

    @MainActor
    private func loadAircraftStats() async {
        guard !selectedAircraftType.isEmpty else {
            aircraftStats = (0.0, 0, 0.0, 0.0, 0.0, 0.0)
            return
        }
        if groupByFamily {
            let types = typesForSelectedFamily
            guard !types.isEmpty else {
                aircraftStats = (0.0, 0, 0.0, 0.0, 0.0, 0.0)
                return
            }
            var merged = (totalHours: 0.0, totalSectors: 0, p1Time: 0.0, p1usTime: 0.0, p2Time: 0.0, simTime: 0.0)
            for type in types {
                let r = await FlightDatabaseService.shared.getDetailedFlightStatisticsAsync(for: type)
                merged = (merged.0 + r.totalHours, merged.1 + r.totalSectors, merged.2 + r.p1Time,
                          merged.3 + r.p1usTime, merged.4 + r.p2Time, merged.5 + r.simTime)
            }
            aircraftStats = merged
        } else {
            aircraftStats = await FlightDatabaseService.shared.getDetailedFlightStatisticsAsync(for: selectedAircraftType)
        }
    }

    private func updateOrientation() {
        let orientation = UIDevice.current.orientation
        if orientation.isLandscape { isLandscape = true }
        else if orientation.isPortrait { isLandscape = false }
    }

    private var timeEntries: [(label: String, value: Double)] {
        var entries: [(String, Double)] = []
        if aircraftStats.totalHours > 0  { entries.append(("Total", aircraftStats.totalHours)) }
        if aircraftStats.p1Time > 0      { entries.append(("P1",    aircraftStats.p1Time)) }
        if aircraftStats.p1usTime > 0    { entries.append(("ICUS",  aircraftStats.p1usTime)) }
        if aircraftStats.p2Time > 0      { entries.append(("P2",    aircraftStats.p2Time)) }
        if aircraftStats.simTime > 0     { entries.append(("SIM",   aircraftStats.simTime)) }
        return entries
    }

    private func formatTime(_ value: Double) -> String {
        showTimesInHoursMinutes ? FlightSector.decimalToHHMM(value) : String(format: "%.1f hrs", value)
    }
}
