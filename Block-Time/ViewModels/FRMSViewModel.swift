//
//  FRMSViewModel.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) ViewModel
//  Manages FRMS calculations and state
//

import Foundation
import Combine

@MainActor
class FRMSViewModel: ObservableObject {

    // MARK: - Properties

    @Published var configuration: FRMSConfiguration {
        didSet {
            LogManager.shared.debug("FRMSViewModel: Configuration changed - triggering refresh")
            saveConfiguration()
            refreshCalculations()
        }
    }

    @Published var cumulativeTotals: FRMSCumulativeTotals?
    @Published var maximumNextDuty: FRMSMaximumNextDuty?
    @Published var a320B737NextDutyLimits: A320B737NextDutyLimits?
    @Published var recentDuties: [FRMSDuty] = []
    @Published var recentDutiesByDay: [DailyDutySummary] = []
    @Published var lastDuty: FRMSDuty?

    @Published var isLoading = false  // Track loading state for UI

    // Limit type selection (Planning vs Operational) - applies to active fleet
    @Published var selectedLimitType: FRMSLimitType = .planning {
        didSet {
            LogManager.shared.debug("FRMSViewModel: Limit type changed to \(selectedLimitType)")
            // Recalculate limits when limit type changes
            refreshCalculations()
        }
    }

    private var calculationService: FRMSCalculationService
    private let userDefaultsKey = "FRMSConfiguration"
    private var dutiesLast365Days: [FRMSDuty] = []  // Store last 365 days of duties for FRMS calculations
    private var flightsLast365Days: [FlightSector] = []  // Store last 365 days of individual flights for flight time calculations
    private var hasLoadedData = false  // Track if we've loaded data to prevent redundant loads

    // MARK: - Initialization

    init() {
        // Load saved configuration or use defaults
        let loadedConfig: FRMSConfiguration
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedConfig = try? JSONDecoder().decode(FRMSConfiguration.self, from: savedData) {
            loadedConfig = savedConfig
        } else {
            loadedConfig = FRMSConfiguration()
        }

        self.configuration = loadedConfig
        self.calculationService = FRMSCalculationService(configuration: loadedConfig)

        // Listen for settings changes from iCloud sync
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .settingsDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleSettingsChanged(notification: Notification) {
        // Check if FRMS settings changed
        guard let changedKeys = notification.userInfo?["changedKeys"] as? [String] else { return }

        let frmsKeys = ["frmsShowFRMS", "frmsFleet", "frmsHomeBase", "frmsDefaultLimitType",
                        "frmsShowWarningsAtPercentage", "frmsSignOnMinutesBeforeSTD", "frmsSignOffMinutesAfterIN"]

        if changedKeys.contains(where: { frmsKeys.contains($0) }) {
            LogManager.shared.debug("FRMSViewModel: Settings changed notification received - keys: \(changedKeys.filter { frmsKeys.contains($0) })")
            // Reload configuration from UserDefaults (already updated by CloudKitSettingsSyncService)
            if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
               let savedConfig = try? JSONDecoder().decode(FRMSConfiguration.self, from: savedData) {
                DispatchQueue.main.async {
                    self.configuration = savedConfig
                    LogManager.shared.debug("FRMSViewModel: Configuration updated from iCloud sync")
                }
            }
        }
    }

    // MARK: - Configuration Management

    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)

            // Sync FRMS settings to iCloud
            CloudKitSettingsSyncService.shared.syncToCloud()
        }
    }

    // MARK: - Data Loading

    /// Load and process flight data from Core Data via FlightDatabaseService
    func loadFlightData(crewPosition: FlightTimePosition) {
        // Skip if already loaded or currently loading
        guard !hasLoadedData && !isLoading else {
//            LogManager.shared.debug("FRMSViewModel: loadFlightData skipped (hasLoadedData: \(hasLoadedData), isLoading: \(isLoading))")
            return
        }

        LogManager.shared.debug("FRMSViewModel: loadFlightData started for \(crewPosition)")

        // Set loading state (we're already on MainActor)
        isLoading = true

        // Capture values for background use
        let service = self.calculationService
        let config = self.configuration

        // Fetch data and process on MainActor
        Task {
            // Calculate 365-day date range (maximum lookback period for FRMS)
            let calendar = Calendar.current
            let today = Date()
            // Use -365 days to ensure we fetch enough data (includes boundary cases)
            let cutoffDate = calendar.date(byAdding: .day, value: -365, to: today) ?? today

            // Format dates for database query (dd/MM/yyyy)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let startDateString = dateFormatter.string(from: cutoffDate)
            let endDateString = dateFormatter.string(from: today)

            // Fetch ONLY last 365 days from Core Data (massive performance optimization)
            // This eliminates fetching thousands of old flights that FRMS doesn't need
            let flights = await MainActor.run {
                FlightDatabaseService.shared.fetchFlights(from: startDateString, to: endDateString)
            }

            // LogManager.shared.debug("FRMSViewModel: Fetched \(flights.count) flights from last 365 days")

            // Convert FlightSectors to FRMSDuties (on MainActor)
            // Group flights into consolidated duty periods (multiple sectors per duty)
            let duties = self.groupFlightsIntoDuties(flights: flights, crewPosition: crewPosition, calculationService: service)
            // LogManager.shared.debug("FRMSViewModel: Converted \(flights.count) flights to \(duties.count) duties")

            // Debug: Show last 5 duty groupings (most recent first)
            let recentDuties = duties.sorted { $0.signOn > $1.signOn }.prefix(5)
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "dd/MM HHmm"
            timeFormatter.timeZone = TimeZone.current

            for duty in recentDuties {
                LogManager.shared.debug("  Recent duty: signOn=\(timeFormatter.string(from: duty.signOn)), signOff=\(timeFormatter.string(from: duty.signOff)), sectors=\(duty.sectors), flight=\(String(format: "%.1f", duty.flightTime))h, duty=\(String(format: "%.1f", duty.dutyTime))h")
            }

            // Filter to only completed flights (past dates only, not future)
            // Use IN time (actual landing) to determine if a duty is complete for display purposes
            // This allows flights to appear immediately after landing, not after sign-off buffer
            let now = Date()
            let signOffBufferSeconds = TimeInterval(config.signOffMinutesAfterIN * 60)
            let completedDuties = duties.filter { duty in
                // Calculate effective IN time by subtracting sign-off buffer from sign-off
                let effectiveInTime = duty.signOff.addingTimeInterval(-signOffBufferSeconds)
                let isComplete = effectiveInTime <= now

                // Debug logging for recent duties
                // let formatter = DateFormatter()
                // formatter.dateFormat = "dd/MM HHmm"
                // formatter.timeZone = TimeZone.current
                // LogManager.shared.debug("FRMS Duty: signOff=\(formatter.string(from: duty.signOff)), effectiveIN=\(formatter.string(from: effectiveInTime)), now=\(formatter.string(from: now)), included=\(isComplete)")

                return isComplete
            }

            // Filter duties to last 365 days (duty dates can differ from flight dates due to timezone adjustments)
            // Note: We already fetched flights from last 365 days, but duty grouping can shift dates slightly
            let dutiesLast365 = completedDuties.filter { $0.date >= cutoffDate }

            // Also filter flights to last 365 days for flight time calculations
            // Note: This filter is mostly redundant since we fetched 365 days, but handles edge cases
            let flightsLast365 = flights.filter {
                guard let flightDate = dateFormatter.date(from: $0.date) else { return false }
                return flightDate >= cutoffDate
            }

            // Calculate cumulative totals using last 365 days of duties and individual flights
            // Pass individual flights so flight times are calculated by flight date, not duty date
            let cumulativeTotals = service.calculateCumulativeTotals(duties: dutiesLast365, flights: flightsLast365)

            // Calculate maximum next duty - get the most recent duty by sign-off time
            let lastDuty = completedDuties.max(by: { $0.signOff < $1.signOff })

            let maximumNextDuty = service.calculateMaximumNextDuty(
                previousDuty: lastDuty,
                cumulativeTotals: cumulativeTotals,
                limitType: selectedLimitType,
                proposedCrewComplement: .twoPilot,
                proposedRestFacility: .none
            )

            // Calculate A320/B737 specific limits if applicable
            let a320Limits: A320B737NextDutyLimits?
            if config.fleet == .a320B737 {
                a320Limits = service.calculateA320B737NextDutyLimits(
                    previousDuty: lastDuty,
                    cumulativeTotals: cumulativeTotals,
                    limitType: selectedLimitType,
                    duties: duties
                )
            } else {
                a320Limits = nil
            }

            // Group duties by local date (only completed)
            let recentDutiesByDay = self.groupDutiesByLocalDate(duties: Array(completedDuties.prefix(30)))

            // Update UI (already on MainActor)
            self.dutiesLast365Days = dutiesLast365
            self.flightsLast365Days = flightsLast365
            self.recentDuties = Array(completedDuties.prefix(30))
            self.lastDuty = lastDuty
            self.recentDutiesByDay = recentDutiesByDay
            self.cumulativeTotals = cumulativeTotals
            self.maximumNextDuty = maximumNextDuty
            self.a320B737NextDutyLimits = a320Limits
            self.hasLoadedData = true
            self.isLoading = false
            //LogManager.shared.debug("FRMSViewModel: loadFlightData completed")
        }
    }

    /// Refresh flight data (for pull-to-refresh)
    func refreshFlightData(crewPosition: FlightTimePosition) async {
        LogManager.shared.debug("FRMSViewModel: refreshFlightData started for \(crewPosition)")

        // Set loading state (we're already on MainActor)
        isLoading = true

        // Capture values for background use
        let service = self.calculationService
        let config = self.configuration

        // Calculate 365-day date range (maximum lookback period for FRMS)
        let calendar = Calendar.current
        let today = Date()
        // Use -365 days to ensure we fetch enough data (includes boundary cases)
        let cutoffDate = calendar.date(byAdding: .day, value: -365, to: today) ?? today

        // Format dates for database query (dd/MM/yyyy)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let startDateString = dateFormatter.string(from: cutoffDate)
        let endDateString = dateFormatter.string(from: today)

        // Fetch ONLY last 365 days from Core Data (massive performance optimization)
        let flights = FlightDatabaseService.shared.fetchFlights(from: startDateString, to: endDateString)

        // LogManager.shared.debug("FRMSViewModel: Refreshed \(flights.count) flights from last 365 days")

        // Convert FlightSectors to FRMSDuties (on MainActor)
        // Group flights into consolidated duty periods (multiple sectors per duty)
        let duties = self.groupFlightsIntoDuties(flights: flights, crewPosition: crewPosition, calculationService: service)

        // Debug: Show last 5 duty groupings (most recent first)
        let recentDuties = duties.sorted { $0.signOn > $1.signOn }.prefix(5)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "dd/MM HHmm"
        timeFormatter.timeZone = TimeZone.current

        for duty in recentDuties {
            LogManager.shared.debug("  Recent duty: signOn=\(timeFormatter.string(from: duty.signOn)), signOff=\(timeFormatter.string(from: duty.signOff)), sectors=\(duty.sectors), flight=\(String(format: "%.1f", duty.flightTime))h, duty=\(String(format: "%.1f", duty.dutyTime))h")
        }

        // Filter to only completed flights (past dates only, not future)
        // Use IN time (actual landing) to determine if a duty is complete for display purposes
        // This allows flights to appear immediately after landing, not after sign-off buffer
        let now = Date()
        let signOffBufferSeconds = TimeInterval(config.signOffMinutesAfterIN * 60)
        let completedDuties = duties.filter { duty in
            // Calculate effective IN time by subtracting sign-off buffer from sign-off
            let effectiveInTime = duty.signOff.addingTimeInterval(-signOffBufferSeconds)
            let isComplete = effectiveInTime <= now

            // Debug logging for recent duties
            // let formatter = DateFormatter()
            // formatter.dateFormat = "dd/MM HHmm"
            // formatter.timeZone = TimeZone.current
            // LogManager.shared.debug("FRMS Duty: signOff=\(formatter.string(from: duty.signOff)), effectiveIN=\(formatter.string(from: effectiveInTime)), now=\(formatter.string(from: now)), included=\(isComplete)")

            return isComplete
        }

        // Filter duties to last 365 days (duty dates can differ from flight dates due to timezone adjustments)
        // Note: We already fetched flights from last 365 days, but duty grouping can shift dates slightly
        let dutiesLast365 = completedDuties.filter { $0.date >= cutoffDate }

        // Also filter flights to last 365 days for flight time calculations
        // Note: This filter is mostly redundant since we fetched 365 days, but handles edge cases
        let flightsLast365 = flights.filter {
            guard let flightDate = dateFormatter.date(from: $0.date) else { return false }
            return flightDate >= cutoffDate
        }

        // Calculate cumulative totals using last 365 days of duties and individual flights
        // Pass individual flights so flight times are calculated by flight date, not duty date
        let cumulativeTotals = service.calculateCumulativeTotals(duties: dutiesLast365, flights: flightsLast365)

        // Calculate maximum next duty - get the most recent duty by sign-off time
        let lastDuty = completedDuties.max(by: { $0.signOff < $1.signOff })

        let maximumNextDuty = service.calculateMaximumNextDuty(
            previousDuty: lastDuty,
            cumulativeTotals: cumulativeTotals,
            limitType: selectedLimitType,
            proposedCrewComplement: .twoPilot,
            proposedRestFacility: .none
        )

        // Calculate A320/B737 specific limits if applicable
        let a320Limits: A320B737NextDutyLimits?
        if config.fleet == .a320B737 {
            a320Limits = service.calculateA320B737NextDutyLimits(
                previousDuty: lastDuty,
                cumulativeTotals: cumulativeTotals,
                limitType: selectedLimitType,
                duties: duties
            )
        } else {
            a320Limits = nil
        }

        // Group duties by local date (only completed)
        let recentDutiesByDay = self.groupDutiesByLocalDate(duties: Array(completedDuties.prefix(30)))

        // Update UI (already on MainActor)
        self.dutiesLast365Days = dutiesLast365
        self.flightsLast365Days = flightsLast365
        self.recentDuties = Array(completedDuties.prefix(30))
        self.lastDuty = lastDuty
        self.recentDutiesByDay = recentDutiesByDay
        self.cumulativeTotals = cumulativeTotals
        self.maximumNextDuty = maximumNextDuty
        self.a320B737NextDutyLimits = a320Limits
        self.hasLoadedData = true
        self.isLoading = false
        LogManager.shared.debug("FRMSViewModel: refreshFlightData completed")
    }

    /// Refresh all calculations with current data
    private func refreshCalculations() {
        LogManager.shared.debug("FRMSViewModel: refreshCalculations called")

        // Update calculation service with new configuration
        calculationService = FRMSCalculationService(configuration: configuration)

        // Recalculate with last 365 days of duties and flights if we have them
        if !dutiesLast365Days.isEmpty {
            // Recalculate cumulative totals with new configuration using last 365 days
            // Pass individual flights for flight time calculations
            self.cumulativeTotals = calculationService.calculateCumulativeTotals(duties: dutiesLast365Days, flights: flightsLast365Days)

            // Recalculate maximum next duty
            if let totals = cumulativeTotals {
                self.maximumNextDuty = calculationService.calculateMaximumNextDuty(
                    previousDuty: lastDuty,
                    cumulativeTotals: totals,
                    limitType: selectedLimitType,
                    proposedCrewComplement: .twoPilot,
                    proposedRestFacility: .none
                )

                // Recalculate A320/B737 specific limits if applicable
                if configuration.fleet == .a320B737 {
                    self.a320B737NextDutyLimits = calculationService.calculateA320B737NextDutyLimits(
                        previousDuty: lastDuty,
                        cumulativeTotals: totals,
                        limitType: selectedLimitType,
                        duties: dutiesLast365Days
                    )
                }
            }
            LogManager.shared.debug("FRMSViewModel: refreshCalculations completed")
        }
    }

    // MARK: - Maximum Next Duty Calculator

    /// Calculate what's allowed for next duty with specific parameters
    func calculateMaxNextDuty(
        crewComplement: CrewComplement,
        restFacility: RestFacilityClass,
        limitType: FRMSLimitType? = nil
    ) -> FRMSMaximumNextDuty? {
        guard let totals = cumulativeTotals else { return nil }

        return calculationService.calculateMaximumNextDuty(
            previousDuty: lastDuty,
            cumulativeTotals: totals,
            limitType: limitType ?? configuration.defaultLimitType,
            proposedCrewComplement: crewComplement,
            proposedRestFacility: restFacility
        )
    }

    // MARK: - Compliance Checking

    /// Check if a proposed duty would be compliant
    func checkProposedDuty(_ duty: FRMSDuty) -> FRMSComplianceStatus {
        guard let totals = cumulativeTotals else {
            return .warning(message: "No historical data available")
        }

        return calculationService.checkCompliance(
            proposedDuty: duty,
            previousDuty: lastDuty,
            cumulativeTotals: totals
        )
    }

    // MARK: - Helper Methods

    /// Get overall compliance status
    var overallComplianceStatus: FRMSComplianceStatus {
        guard let totals = cumulativeTotals else {
            return .compliant
        }

        // Check all status types and return worst case
        let statuses = [
            totals.status7Days,
            totals.status28Days,
            totals.status365Days,
            totals.dutyStatus7Days,
            totals.dutyStatus14Days
        ]

        // Check for violations first
        for status in statuses {
            if case .violation = status {
                return status
            }
        }

        // Then check for warnings
        for status in statuses {
            if case .warning = status {
                return status
            }
        }

        return .compliant
    }

    /// Format duty time for display
    func formatDutyTime(_ duty: FRMSDuty) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM"
        let dateStr = dateFormatter.string(from: duty.date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        let signOnStr = timeFormatter.string(from: duty.signOn)
        let signOffStr = timeFormatter.string(from: duty.signOff)

        return "\(dateStr): \(signOnStr)-\(signOffStr)"
    }

    /// Get percentage of limit used
    func percentageOfLimit(used: Double, limit: Double) -> Double {
        guard limit > 0 else { return 0 }
        return (used / limit) * 100.0
    }

    // MARK: - Duty Grouping

    /// Group duties by local date at home base
    private func groupDutiesByLocalDate(duties: [FRMSDuty]) -> [DailyDutySummary] {
        // Get home base timezone for proper local date grouping
        let homeTimeZone = calculationService.getHomeBaseTimeZone()
        var localCalendar = Calendar.current
        localCalendar.timeZone = homeTimeZone

        // Group duties by the LOCAL calendar day of their sign-on time
        // This ensures duties are grouped by the actual local date, not UTC date
        let grouped = Dictionary(grouping: duties) { duty -> Date in
            // Convert sign-on time to local calendar day (start of day in home base timezone)
            return localCalendar.startOfDay(for: duty.signOn)
        }

        // Convert to DailyDutySummary and sort by date (newest first)
        let summaries = grouped.map { date, dutiesForDay in
            DailyDutySummary(date: date, duties: dutiesForDay)
        }.sorted { $0.date > $1.date }

        return summaries
    }

    // MARK: - Flight Grouping into Duties

    /// Group individual FlightSectors into consolidated duty periods
    /// Multiple sectors that occur within the same duty period are combined into a single FRMSDuty
    private func groupFlightsIntoDuties(flights: [FlightSector], crewPosition: FlightTimePosition, calculationService: FRMSCalculationService) -> [FRMSDuty] {
        // First, convert each flight to a temporary duty structure so we have proper DateTimes
        // This allows us to sort chronologically regardless of UTC date boundaries
        var individualFlightDuties: [(flight: FlightSector, duty: FRMSDuty)] = []

        for flight in flights {
            // Create duty with isFirstOfDay = false initially (we'll fix this after sorting)
            if let duty = calculationService.createDuty(from: flight, crewPosition: crewPosition, isFirstFlightOfDay: false) {
                individualFlightDuties.append((flight: flight, duty: duty))
            }
        }

        // Sort by actual sign-on time (not UTC date string)
        individualFlightDuties.sort { $0.duty.signOn < $1.duty.signOn }

        // Now determine which duties are the first of each LOCAL day
        // Use home base timezone to determine local date
        let homeTimeZone = calculationService.getHomeBaseTimeZone()
        var localCalendar = Calendar.current
        localCalendar.timeZone = homeTimeZone

        var seenLocalDates = Set<Date>()
        var correctedDuties: [(flight: FlightSector, duty: FRMSDuty)] = []

        for flightDuty in individualFlightDuties {
            let localSignOnDay = localCalendar.startOfDay(for: flightDuty.duty.signOn)
            let isFirstOfDay = !seenLocalDates.contains(localSignOnDay)

            if isFirstOfDay {
                seenLocalDates.insert(localSignOnDay)
                // Recreate duty with correct isFirstOfDay flag
                if let correctedDuty = calculationService.createDuty(from: flightDuty.flight, crewPosition: crewPosition, isFirstFlightOfDay: true) {
                    correctedDuties.append((flight: flightDuty.flight, duty: correctedDuty))
                } else {
                    correctedDuties.append(flightDuty)
                }
            } else {
                correctedDuties.append(flightDuty)
            }
        }

        individualFlightDuties = correctedDuties

        // Group flights into consolidated duties based on home base timezone
        var consolidatedDuties: [FRMSDuty] = []
        var currentDutyFlights: [(flight: FlightSector, duty: FRMSDuty)] = []

        let maxGapBetweenSectors: TimeInterval = 3 * 3600 // 3 hours max gap between sectors in same duty

        // Note: homeTimeZone and localCalendar already declared above for isFirstOfDay logic

        for flightDuty in individualFlightDuties {
            if currentDutyFlights.isEmpty {
                // Start a new duty period
                currentDutyFlights.append(flightDuty)
            } else {
                // Check if this flight belongs to the current duty period
                let lastFlight = currentDutyFlights.last!
                let gapBetweenFlights = flightDuty.duty.signOn.timeIntervalSince(lastFlight.duty.signOff)

                // Get the local calendar day for both the first and new flight
                let firstSignOn = currentDutyFlights.first!.duty.signOn
                let firstSignOnDay = localCalendar.startOfDay(for: firstSignOn)
                let newSignOnDay = localCalendar.startOfDay(for: flightDuty.duty.signOn)

                // Flights belong to same duty if:
                // 1. Gap is less than max allowed (typically 3 hours - accounts for turnaround time)
                // 2. Sign-on times are on the same local calendar day OR
                //    new flight signs on within 6 hours after midnight of the next local day
                let nextLocalDay = localCalendar.date(byAdding: .day, value: 1, to: firstSignOnDay)!
                let sixHoursAfterNextMidnight = localCalendar.date(byAdding: .hour, value: 6, to: nextLocalDay)!

                let sameDayOrEarlyNextDay = (newSignOnDay == firstSignOnDay) ||
                                           (newSignOnDay == nextLocalDay && flightDuty.duty.signOn < sixHoursAfterNextMidnight)

                // Allow negative gaps (overlapping flights due to STD/OUT differences) or small positive gaps
                // Flights on the same day with gaps < 3 hours should be consolidated into one duty
                let shouldConsolidate = sameDayOrEarlyNextDay && (gapBetweenFlights <= maxGapBetweenSectors)

                if shouldConsolidate {
                    // Add to current duty period
                    currentDutyFlights.append(flightDuty)
                } else {
                    // Create consolidated duty from current flights and start new duty
                    if let consolidatedDuty = createConsolidatedDuty(from: currentDutyFlights, calculationService: calculationService) {
                        consolidatedDuties.append(consolidatedDuty)
                    }
                    currentDutyFlights = [flightDuty]
                }
            }
        }

        // Don't forget the last duty period
        if !currentDutyFlights.isEmpty {
            if let consolidatedDuty = createConsolidatedDuty(from: currentDutyFlights, calculationService: calculationService) {
                consolidatedDuties.append(consolidatedDuty)
            }
        }

        // Sort by date (newest first for display)
        return consolidatedDuties.sorted { $0.date > $1.date }
    }

    /// Create a single consolidated FRMSDuty from multiple flight sectors
    private func createConsolidatedDuty(from flightDuties: [(flight: FlightSector, duty: FRMSDuty)], calculationService: FRMSCalculationService) -> FRMSDuty? {
        guard !flightDuties.isEmpty else { return nil }

        // For single flight, return the duty but ensure date is based on sign-on time in home base timezone
        if flightDuties.count == 1 {
            let duty = flightDuties[0].duty

            // Use home base timezone to determine the duty date
            let homeTimeZone = calculationService.getHomeBaseTimeZone()
            var localCalendar = Calendar.current
            localCalendar.timeZone = homeTimeZone

            // Get the local calendar day of the sign-on time
            let localSignOnDay = localCalendar.startOfDay(for: duty.signOn)

            // Convert to UTC midnight for storage (matching flight date format)
            var utcCalendar = Calendar.current
            utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
            let dateComponents = localCalendar.dateComponents([.year, .month, .day], from: localSignOnDay)
            let dateFromSignOn = utcCalendar.date(from: dateComponents) ?? duty.date

            // Only recreate if the date would be different
            if duty.date != dateFromSignOn {
                return FRMSDuty(
                    date: dateFromSignOn,
                    dutyType: duty.dutyType,
                    crewComplement: duty.crewComplement,
                    restFacility: duty.restFacility,
                    signOn: duty.signOn,
                    signOff: duty.signOff,
                    flightTime: duty.flightTime,
                    nightTime: duty.nightTime,
                    sectors: duty.sectors,
                    isInternational: duty.isInternational,
                    homeBaseTimeZone: homeTimeZone
                )
            }
            return duty
        }

        // For multiple flights, consolidate them
        let firstDuty = flightDuties.first!.duty
        let lastDuty = flightDuties.last!.duty

        // Sign-on is from first flight, sign-off is from last flight
        let signOn = firstDuty.signOn
        let signOff = lastDuty.signOff

        // Sum up flight times and night times
        let totalFlightTime = flightDuties.reduce(0.0) { $0 + $1.duty.flightTime }
        let totalNightTime = flightDuties.reduce(0.0) { $0 + $1.duty.nightTime }

        // Count sectors
        let totalSectors = flightDuties.count

        // Use crew complement from first flight (assuming it's consistent)
        let crewComplement = firstDuty.crewComplement
        let restFacility = firstDuty.restFacility

        // Determine if any flight is international
        let isInternational = flightDuties.contains { $0.duty.isInternational }

        // Use the duty type from first flight (or .operating if any are operating)
        let dutyType = flightDuties.contains { $0.duty.dutyType == .operating } ? DutyType.operating : firstDuty.dutyType

        // Get home base timezone
        let homeTimeZone = calculationService.getHomeBaseTimeZone()

        // IMPORTANT: Use the sign-on time in HOME BASE TIMEZONE to determine the duty date
        // This ensures that duties are correctly attributed to the local calendar day
        var localCalendar = Calendar.current
        localCalendar.timeZone = homeTimeZone

        // Get the local calendar day of the sign-on time
        let localSignOnDay = localCalendar.startOfDay(for: signOn)

        // Convert to UTC midnight for storage (matching flight date format)
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        let dateComponents = localCalendar.dateComponents([.year, .month, .day], from: localSignOnDay)
        let date = utcCalendar.date(from: dateComponents) ?? firstDuty.date

        return FRMSDuty(
            date: date,
            dutyType: dutyType,
            crewComplement: crewComplement,
            restFacility: restFacility,
            signOn: signOn,
            signOff: signOff,
            flightTime: totalFlightTime,
            nightTime: totalNightTime,
            sectors: totalSectors,
            isInternational: isInternational,
            homeBaseTimeZone: homeTimeZone
        )
    }
}
