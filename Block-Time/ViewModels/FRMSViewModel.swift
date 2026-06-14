//
//  FRMSViewModel.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) ViewModel
//  Manages FRMS calculations and state
//

import Foundation
import BlockTimeKit

@Observable @MainActor
class FRMSViewModel {

    // MARK: - Properties

    var configuration: FRMSConfiguration {
        didSet {
            LogManager.shared.debug("FRMSViewModel: Configuration changed - triggering refresh")
            saveConfiguration()
            refreshCalculations()
        }
    }

    var cumulativeTotals: FRMSCumulativeTotals?
    var maximumNextDuty: FRMSMaximumNextDuty?
    var a320B737NextDutyLimits: A320B737NextDutyLimits?
    var recentDuties: [FRMSDuty] = []
    var recentDutiesByDay: [DailyDutySummary] = []
    var lastDuty: FRMSDuty?

    var isLoading = false  // Track loading state for UI

    // Limit type selection (Planning vs Operational) - applies to active fleet
    var selectedLimitType: FRMSLimitType = .planning {
        didSet {
            LogManager.shared.debug("FRMSViewModel: Limit type changed to \(selectedLimitType)")
            // Recalculate limits when limit type changes
            refreshCalculations()
        }
    }

    private var calculationService: FRMSCalculationService
    private let userDefaultsKey = "FRMSConfiguration"
    var dutiesLast365Days: [FRMSDuty] = []  // Store last 365 days of duties for FRMS calculations
    private var flightsLast365Days: [FlightSector] = []  // Store last 365 days of individual flights for flight time calculations
    private var hasLoadedData = false  // Track if we've loaded data to prevent redundant loads
    private var lastRefreshDate: Date?  // Cooldown — prevents redundant recalculations from rapid CloudKit events
    private let refreshCooldown: TimeInterval = 10  // seconds

    // Cached UTC date formatter — reused across load/refresh calls (fixed timezone, safe to share)
    private static let utcDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // Cached debug time formatter — only used for log output
    private static let debugTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HHmm"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

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

        // Listen for flight data changes directly so FRMS updates even when its tab
        // has never been opened (SwiftUI TabView is lazy — the view's .onReceive won't
        // fire until the tab is first visited).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFlightDataChanged),
            name: .flightDataChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleFlightDataChanged() {
        guard !FlightDatabaseService.shared.isAppInBackground else { return }
        let positionRaw = UserDefaults.standard.string(forKey: "flightTimePosition") ?? FlightTimePosition.captain.rawValue
        let crewPosition = FlightTimePosition(rawValue: positionRaw) ?? .captain
        Task {
            await refreshFlightData(crewPosition: crewPosition)
        }
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

    /// Load and process flight data from Core Data via FlightDatabaseService.
    /// Skips if data has already been loaded; use refreshFlightData for a forced reload.
    func loadFlightData(crewPosition: FlightTimePosition) {
        guard !hasLoadedData && !isLoading else { return }
        LogManager.shared.debug("FRMSViewModel: loadFlightData started for \(crewPosition)")
        isLoading = true
        Task {
            // fetchFlights requires MainActor; we are already on it inside the Task
            let flights = await MainActor.run {
                Self.fetchFlights365Days()
            }
            await applyFlightData(flights: flights, crewPosition: crewPosition, label: "loadFlightData")
        }
    }

    /// Refresh flight data (for pull-to-refresh or data change notifications).
    /// Skips if a refresh completed within the last `refreshCooldown` seconds — prevents
    /// redundant recalculations from rapid successive CloudKit sync events on launch.
    func refreshFlightData(crewPosition: FlightTimePosition, ignoresCooldown: Bool = false) async {
        if !ignoresCooldown, let last = lastRefreshDate, Date().timeIntervalSince(last) < refreshCooldown {
            LogManager.shared.debug("FRMSViewModel: refreshFlightData skipped (cooldown)")
            return
        }
        LogManager.shared.debug("FRMSViewModel: refreshFlightData started for \(crewPosition)")
        isLoading = true
        let flights = Self.fetchFlights365Days()
        await applyFlightData(flights: flights, crewPosition: crewPosition, label: "refreshFlightData")
    }

    /// Fetch the last 365 days of flights using the shared UTC formatter.
    private static func fetchFlights365Days() -> [FlightSector] {
        let today = Date()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -365, to: today) ?? today
        let startDateString = utcDateFormatter.string(from: cutoffDate)
        let endDateString = utcDateFormatter.string(from: today)
        return FlightDatabaseService.shared.fetchFlights(from: startDateString, to: endDateString)
    }

    /// Shared core logic: process fetched flights, calculate all FRMS outputs, and publish to @Observable properties.
    private func applyFlightData(flights: [FlightSector], crewPosition: FlightTimePosition, label: String) async {
        let service = self.calculationService
        let config = self.configuration
        let today = Date()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -365, to: today) ?? today

        let duties = self.groupFlightsIntoDuties(flights: flights, crewPosition: crewPosition, calculationService: service)

//        // Debug: last 5 duties (most recent first)
//        for duty in duties.sorted(by: { $0.signOn > $1.signOn }).prefix(1) {
//            LogManager.shared.debug("Last Recent duty: signOn=\(Self.debugTimeFormatter.string(from: duty.signOn)), signOff=\(Self.debugTimeFormatter.string(from: duty.signOff)), sectors=\(duty.sectors), flight=\(String(format: "%.1f", duty.flightTime))h, duty=\(String(format: "%.1f", duty.dutyTime))h")
//        }

        // Debug: show last recent duty
        if let duty = duties.max(by: { $0.signOn < $1.signOn }) {
              LogManager.shared.debug("Last recent duty: signOn=\(Self.debugTimeFormatter.string(from: duty.signOn)), signOff=\(Self.debugTimeFormatter.string(from: duty.signOff)),sectors=\(duty.sectors), flight=\(String(format: "%.1f",duty.flightTime))h, duty=\(String(format: "%.1f", duty.dutyTime))h")
          }
        
        
        
        // Filter to only completed duties (last flight has an actual IN time)
        let completedDuties = duties.filter { $0.hasActualINTime }

        // Duty grouping can shift dates slightly across timezone boundaries; re-clip to 365 days
        let dutiesLast365 = completedDuties.filter { $0.date >= cutoffDate }

        // Filter flights to 365 days — parse each date once using the shared UTC formatter
        let flightsLast365 = flights.filter {
            guard let flightDate = Self.utcDateFormatter.date(from: $0.date) else { return false }
            return flightDate >= cutoffDate
        }

        let cumulativeTotals = service.calculateCumulativeTotals(duties: dutiesLast365, flights: flightsLast365)

        let lastDuty = completedDuties.max(by: { $0.signOff < $1.signOff })

        let maximumNextDuty = service.calculateMaximumNextDuty(
            previousDuty: lastDuty,
            cumulativeTotals: cumulativeTotals,
            limitType: selectedLimitType,
            proposedCrewComplement: .twoPilot,
            proposedRestFacility: .none
        )

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

        let recentDutiesByDay = self.groupDutiesByLocalDate(duties: Array(completedDuties.prefix(30)))

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
        self.lastRefreshDate = Date()
        LogManager.shared.debug("FRMSViewModel: \(label) completed")
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

            // Recalculate A320/B737 specific limits if applicable
            if let totals = cumulativeTotals {
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

    func calculateMBTT(daysAway: Int, creditedFlightHours: Double, hadPlannedDutyOver18Hours: Bool) -> FRMSMinimumBaseTurnaroundTime? {
        return calculationService.calculateMBTT(
            daysAway: daysAway,
            creditedFlightHours: creditedFlightHours,
            hadPlannedDutyOver18Hours: hadPlannedDutyOver18Hours
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

    private static let dutyDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f
    }()

    private static let dutyTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HHmm"
        return f
    }()

    /// Format duty time for display
    func formatDutyTime(_ duty: FRMSDuty) -> String {
        let dateStr = Self.dutyDateFormatter.string(from: duty.date)
        let signOnStr = Self.dutyTimeFormatter.string(from: duty.signOn)
        let signOffStr = Self.dutyTimeFormatter.string(from: duty.signOff)
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

        let maxGapBetweenSectors: TimeInterval = 8 * 3600 // 8 hours — below minimum rest, captures delayed sectors

        for flightDuty in individualFlightDuties {
            if currentDutyFlights.isEmpty {
                // Start a new duty period
                currentDutyFlights.append(flightDuty)
            } else {
                // Check if this flight belongs to the current duty period
                let lastFlight = currentDutyFlights.last!
                let gapBetweenFlights = flightDuty.duty.signOn.timeIntervalSince(lastFlight.duty.signOff)

                // Consolidate if gap is within the max (negative gaps = overlapping STD/OUT times)
                let shouldConsolidate = gapBetweenFlights <= maxGapBetweenSectors

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
                    hasActualINTime: duty.hasActualINTime,
                    toAirport: duty.toAirport,
                    homeBaseTimeZone: homeTimeZone
                )
            }
            return duty
        }

        // For multiple flights, consolidate them
        // Use min/max over all duties rather than first/last because flights with the same STD
        // (e.g. a rejected takeoff followed by the actual departure) produce identical sign-on times
        // and their order after sorting is undefined, which can put an earlier sign-off last.
        let signOn = flightDuties.min(by: { $0.duty.signOn < $1.duty.signOn })!.duty.signOn
        let signOff = flightDuties.max(by: { $0.duty.signOff < $1.duty.signOff })!.duty.signOff
        let firstDuty = flightDuties.min(by: { $0.duty.signOn < $1.duty.signOn })!.duty
        let lastDuty = flightDuties.max(by: { $0.duty.signOff < $1.duty.signOff })!.duty

        // Sum up flight times, sim session times, and night times
        let totalFlightTime = flightDuties.reduce(0.0) { $0 + $1.duty.flightTime }
        let totalSimSessionTime = flightDuties.reduce(0.0) { $0 + $1.duty.simSessionTime }
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
            simSessionTime: totalSimSessionTime,
            nightTime: totalNightTime,
            sectors: totalSectors,
            isInternational: isInternational,
            hasActualINTime: lastDuty.hasActualINTime,
            toAirport: lastDuty.toAirport,
            homeBaseTimeZone: homeTimeZone
        )
    }
}
