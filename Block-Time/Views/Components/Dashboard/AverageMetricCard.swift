import SwiftUI

// MARK: - Average Metric Card
struct AverageMetricCard: View {
    let statistics: FlightStatistics
    var isEditMode: Bool = false
    @State private var selectedAircraftType: String = ""
    @State private var selectedTimePeriod: String = "28"
    @State private var selectedComparisonPeriod: String = ""
    @State private var availableAircraftTypes: [String] = []
    @State private var averageHours: Double = 0.0
    @State private var averageSectors: Double = 0.0
    @State private var showingConfig = false
    private let settings = LogbookSettings.shared
    private let databaseService = FlightDatabaseService.shared
    @State private var showTimesInHoursMinutes: Bool = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Time period options (for the average calculation)
    let timePeriodOptions = [
        "7": "7 Days",
        "1": "1 Day",
        "28": "28 Days",
        "90": "90 Days",
        "180": "180 Days",
        "365": "365 Days",
    ]

    // Comparison period options (over what timeframe to calculate)
    let comparisonPeriodOptions = [
        "": "All Time",
        "7": "Last 7 Days",
        "28": "Last 28 Days",
        "90": "Last 3 Months",
        "180": "Last 6 Months",
        "365": "Last Year",
    ]

    var body: some View {
        cardContent
        .sheet(isPresented: $showingConfig) {
            AverageMetricConfigSheet(
                selectedAircraftType: $selectedAircraftType,
                selectedTimePeriod: $selectedTimePeriod,
                selectedComparisonPeriod: $selectedComparisonPeriod,
                availableAircraftTypes: availableAircraftTypes,
                timePeriodOptions: timePeriodOptions,
                comparisonPeriodOptions: comparisonPeriodOptions,
                onSave: {
                    settings.averageMetricConfig = [
                        "aircraftType": selectedAircraftType,
                        "timePeriod": selectedTimePeriod,
                        "comparisonPeriod": selectedComparisonPeriod
                    ]
                    settings.saveSettings()
                    Task { await calculateAverage() }
                }
            )
        }
        .task {
            loadSettings()
            await loadAvailableAircraftTypes()
            await calculateAverage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            Task {
                await loadAvailableAircraftTypes()
                await calculateAverage()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            showTimesInHoursMinutes = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
        }
    }

    private var displayTitle: String {
        let period = timePeriodOptions[selectedTimePeriod] ?? "\(selectedTimePeriod) Days"
        return "\(period) Average"
    }

    // Determine if we should stack hours and sectors vertically (iPhone 2-column view)
    private var shouldStackVertically: Bool {
        return horizontalSizeClass == .compact && !settings.isCompactView
    }

    private var formattedValue: String {
        if shouldStackVertically {
            let sectorsText = String(format: "%.0f Flights", averageSectors)
            let hoursText = showTimesInHoursMinutes ? FlightSector.decimalToHHMM(averageHours) : String(format: "%.1f hrs", averageHours)
            return "\(hoursText) | \(sectorsText)"
        } else {
            let sectorsText = String(format: "%.0f flights", averageSectors)
            let hoursText = showTimesInHoursMinutes ? FlightSector.decimalToHHMM(averageHours) : String(format: "%.1f hrs", averageHours)
            return "\(hoursText) | \(sectorsText)"
        }
    }

    private var displaySubtitle: String {
        let aircraft = selectedAircraftType.isEmpty ? "all aircraft" : "the \(selectedAircraftType)"
        let timeframe = comparisonPeriodOptions[selectedComparisonPeriod] ?? "All Time"

        if selectedComparisonPeriod.isEmpty {
            return selectedAircraftType.isEmpty ? "All aircraft" : selectedAircraftType
        } else {
            return "Over the \(timeframe.lowercased()) on \(aircraft)"
        }
    }

    private func loadSettings() {
        selectedAircraftType = settings.averageMetricConfig["aircraftType"] ?? ""
        selectedTimePeriod = settings.averageMetricConfig["timePeriod"] ?? "28"
        selectedComparisonPeriod = settings.averageMetricConfig["comparisonPeriod"] ?? ""
    }

    @MainActor
    private func loadAvailableAircraftTypes() async {
        availableAircraftTypes = await databaseService.getAllAircraftTypesAsync()
    }

    @MainActor
    private func calculateAverage() async {
        guard let days = Int(selectedTimePeriod) else {
            averageHours = 0.0
            averageSectors = 0.0
            return
        }
        let comparisonDays = selectedComparisonPeriod.isEmpty ? nil : Int(selectedComparisonPeriod)
        async let hours = databaseService.getAverageMetricAsync(
            aircraftType: selectedAircraftType,
            days: days,
            metricType: "hours",
            comparisonPeriodDays: comparisonDays
        )
        async let sectors = databaseService.getAverageMetricAsync(
            aircraftType: selectedAircraftType,
            days: days,
            metricType: "sectors",
            comparisonPeriodDays: comparisonDays
        )
        (averageHours, averageSectors) = await (hours, sectors)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: displayTitle, icon: "chart.line.uptrend.xyaxis") {
                if !isEditMode {
                    Button {
                        showingConfig = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .imageScale(.small)
                            .foregroundStyle(.purple.opacity(0.7))
                            .padding(6)
                            .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedValue)
                    .iPadScaledFont(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if !shouldStackVertically || selectedComparisonPeriod.isEmpty {
                    Spacer()
                        .frame(height: 6)
                }

                Text(displaySubtitle)
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .appCardStyle()
    }
}
