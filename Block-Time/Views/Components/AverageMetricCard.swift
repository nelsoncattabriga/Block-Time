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

    // Time period options (for the average calculation)
    let timePeriodOptions = [
        "7": "7 Days",
        "1": "1 Day",
        "28": "28 Days",
        "90": "90 Days",
        "180": "180 Days",
        "365": "1 Year",
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
        Group {
            if isEditMode {
                cardContent
            } else {
                Button {
                    showingConfig = true
                } label: {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
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
                    calculateAverage()
                }
            )
        }
        .onAppear {
            loadSettings()
            loadAvailableAircraftTypes()
            calculateAverage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            loadAvailableAircraftTypes()
            calculateAverage()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            showTimesInHoursMinutes = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
        }
    }

    private var displayTitle: String {
        let period = timePeriodOptions[selectedTimePeriod] ?? "\(selectedTimePeriod) Days"
        return "Avg per \(period)"
    }

    private var formattedValue: String {
        let sectorsText = String(format: "%.0f sectors", averageSectors)
        let hoursText = showTimesInHoursMinutes ? FlightSector.decimalToHHMM(averageHours) : String(format: "%.1f hrs", averageHours)
        return "\(hoursText)  |  \(sectorsText)"
    }

    private var displaySubtitle: String {
        let aircraft = selectedAircraftType.isEmpty ? "all aircraft" : "the \(selectedAircraftType)"
        let timeframe = comparisonPeriodOptions[selectedComparisonPeriod] ?? "All Time"

        if selectedComparisonPeriod.isEmpty {
            // All Time - just show aircraft
            return selectedAircraftType.isEmpty ? "All aircraft" : selectedAircraftType
        } else {
            // Last X Days/Months - show "Over the last..."
            return "Over the \(timeframe.lowercased()) on \(aircraft)"
        }
    }

    private func loadSettings() {
        selectedAircraftType = settings.averageMetricConfig["aircraftType"] ?? ""
        selectedTimePeriod = settings.averageMetricConfig["timePeriod"] ?? "28"
        selectedComparisonPeriod = settings.averageMetricConfig["comparisonPeriod"] ?? ""
    }

    private func loadAvailableAircraftTypes() {
        availableAircraftTypes = databaseService.getAllAircraftTypes()
    }

    private func calculateAverage() {
        guard let days = Int(selectedTimePeriod) else {
            averageHours = 0.0
            averageSectors = 0.0
            return
        }

        let comparisonDays = selectedComparisonPeriod.isEmpty ? nil : Int(selectedComparisonPeriod)

        averageHours = databaseService.getAverageMetric(
            aircraftType: selectedAircraftType,
            days: days,
            metricType: "hours",
            comparisonPeriodDays: comparisonDays
        )

        averageSectors = databaseService.getAverageMetric(
            aircraftType: selectedAircraftType,
            days: days,
            metricType: "sectors",
            comparisonPeriodDays: comparisonDays
        )
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(displayTitle)
                    .iPadScaledFont(.callout)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                    .iPadScaledFont(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedValue)
                    .iPadScaledFont(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                // Spacer to match progress bar height in other cards
                Spacer()
                    .frame(height: 6)

                Text(displaySubtitle)
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
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}
