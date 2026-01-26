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
            LogManager.shared.debug("FRMSViewModel: loadFlightData skipped (hasLoadedData: \(hasLoadedData), isLoading: \(isLoading))")
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
            // Fetch all flight sectors from Core Data
            let flights = await MainActor.run {
                FlightDatabaseService.shared.fetchAllFlights()
            }

            // Convert FlightSectors to FRMSDuties (on MainActor)
            // Group flights into consolidated duty periods (multiple sectors per duty)
            let duties = self.groupFlightsIntoDuties(flights: flights, crewPosition: crewPosition, calculationService: service)

            // Filter to only completed flights (past dates only, not future)
            // Use sign-off time to determine if a duty is complete
            let now = Date()
            let completedDuties = duties.filter { $0.signOff <= now }

            // Filter to last 365 days for FRMS calculations (longest lookback period)
            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -365, to: Date()) ?? Date()
            let dutiesLast365 = completedDuties.filter { $0.date >= cutoffDate }

            // Also filter flights to last 365 days for flight time calculations
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
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
                limitType: config.defaultLimitType,
                proposedCrewComplement: .twoPilot,
                proposedRestFacility: .none
            )

            // Calculate A320/B737 specific limits if applicable
            let a320Limits: A320B737NextDutyLimits?
            if config.fleet == .a320B737 {
                a320Limits = service.calculateA320B737NextDutyLimits(
                    previousDuty: lastDuty,
                    cumulativeTotals: cumulativeTotals,
                    limitType: config.defaultLimitType,
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
            LogManager.shared.debug("FRMSViewModel: loadFlightData completed")
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

        // Fetch all flight sectors from Core Data
        let flights = FlightDatabaseService.shared.fetchAllFlights()

        // Convert FlightSectors to FRMSDuties (on MainActor)
        // Group flights into consolidated duty periods (multiple sectors per duty)
        let duties = self.groupFlightsIntoDuties(flights: flights, crewPosition: crewPosition, calculationService: service)

        // Filter to only completed flights (past dates only, not future)
        // Use sign-off time to determine if a duty is complete
        let now = Date()
        let completedDuties = duties.filter { $0.signOff <= now }

        // Filter to last 365 days for FRMS calculations (longest lookback period)
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        let dutiesLast365 = completedDuties.filter { $0.date >= cutoffDate }

        // Also filter flights to last 365 days for flight time calculations
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
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
            limitType: config.defaultLimitType,
            proposedCrewComplement: .twoPilot,
            proposedRestFacility: .none
        )

        // Calculate A320/B737 specific limits if applicable
        let a320Limits: A320B737NextDutyLimits?
        if config.fleet == .a320B737 {
            a320Limits = service.calculateA320B737NextDutyLimits(
                previousDuty: lastDuty,
                cumulativeTotals: cumulativeTotals,
                limitType: config.defaultLimitType,
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
                    limitType: configuration.defaultLimitType,
                    proposedCrewComplement: .twoPilot,
                    proposedRestFacility: .none
                )

                // Recalculate A320/B737 specific limits if applicable
                if configuration.fleet == .a320B737 {
                    self.a320B737NextDutyLimits = calculationService.calculateA320B737NextDutyLimits(
                        previousDuty: lastDuty,
                        cumulativeTotals: totals,
                        limitType: configuration.defaultLimitType,
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
        // Group duties by the date component (ignoring time)
        let grouped = Dictionary(grouping: duties) { duty -> Date in
            // duty.date is already the start of day in home base timezone
            // No need to apply startOfDay again as it would use device timezone
            return duty.date
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
        // Sort flights by date and time first to establish chronological order
        let sortedFlights = flights.sorted { f1, f2 in
            // Compare by date first
            if f1.date != f2.date {
                return f1.date < f2.date
            }
            // Then by departure time (OUT or scheduled)
            let time1 = !f1.outTime.isEmpty ? f1.outTime : f1.scheduledDeparture
            let time2 = !f2.outTime.isEmpty ? f2.outTime : f2.scheduledDeparture
            return time1 < time2
        }

        // Track which date we've seen the first flight for
        var firstFlightDates = Set<String>()

        // First, convert each flight to a temporary duty structure
        var individualFlightDuties: [(flight: FlightSector, duty: FRMSDuty)] = []

        for flight in sortedFlights {
            // Determine if this is the first flight of the day
            let isFirstOfDay = !firstFlightDates.contains(flight.date)
            if isFirstOfDay {
                firstFlightDates.insert(flight.date)
            }

            if let duty = calculationService.createDuty(from: flight, crewPosition: crewPosition, isFirstFlightOfDay: isFirstOfDay) {
                individualFlightDuties.append((flight: flight, duty: duty))
            }
        }

        // Sort by sign-on time
        individualFlightDuties.sort { $0.duty.signOn < $1.duty.signOn }

        // Group flights into consolidated duties based on home base timezone
        var consolidatedDuties: [FRMSDuty] = []
        var currentDutyFlights: [(flight: FlightSector, duty: FRMSDuty)] = []

        let maxGapBetweenSectors: TimeInterval = 3 * 3600 // 3 hours max gap between sectors in same duty

        // Get home base timezone for local date calculations
        let homeTimeZone = calculationService.getHomeBaseTimeZone()
        var localCalendar = Calendar.current
        localCalendar.timeZone = homeTimeZone

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

                if gapBetweenFlights >= 0 && gapBetweenFlights <= maxGapBetweenSectors && sameDayOrEarlyNextDay {
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
