//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//


import Foundation
import Combine


public enum InstructionEnvironment: String, CaseIterable {
    case simulator = "simulator"
    case aircraft = "aircraft"
}

public enum LogbookDestination: String, CaseIterable {
    case internalLogbook = "Block-Time"
    case logTenPro = "LogTen"
    case both = "Both"

    public var userDefaultsKey: String {
        return "logbookDestination"
    }

    public var menuLabel: String {
        switch self {
        case .internalLogbook:
            return "Block-Time"
        case .logTenPro:
            return "LogTen"
        case .both:
            return "Both"
        }
    }

    public var displayName: String {
        switch self {
        case .logTenPro:
            return "LogTen only"
        case .internalLogbook:
            return "Block-Time only"
        case .both:
            return "Block-Time & LogTen"
        }
    }
}

public enum RoundingMode: String, CaseIterable, Sendable {

    case standard = "Standard"
    case alternate = "Alternate"

    public var displayName: String {
        return self.rawValue
    }

    /// Apply rounding to a decimal value
    public func apply(to value: Double, decimalPlaces: Int = 1) -> Double {
        let multiplier = pow(10.0, Double(decimalPlaces))
        switch self {
        case .standard:
            // Standard rounding: rounds to nearest, .5 rounds up
            return (value * multiplier).rounded(.toNearestOrAwayFromZero) / multiplier
        case .alternate:
            // Alternate rounding: for 1 decimal place, rounds .x1-.x5 DOWN, .x6-.x9 UP
            // Example: 1.11-1.15 → 1.1, 1.16-1.19 → 1.2
            let scaled = value * multiplier
            let fractionalPart = scaled.truncatingRemainder(dividingBy: 1.0)

            if fractionalPart < 0.6 {
                return floor(scaled) / multiplier
            } else {
                return ceil(scaled) / multiplier
            }
        }
    }
}



// MARK: - Settings Data Model (Updated)
public struct AppSettings: Sendable {
    public var aircraftReg: String
    public var aircraftType: String
    public var captainName: String
    public var coPilotName: String
    public var defaultCaptainName: String
    public var defaultCoPilotName: String
    public var defaultSOName: String
    public var savedSONames: [String]  // Shared list for both SO 1 and SO 2
    public var savedCrewNames: [String]  // Unified crew name list across all roles
    public var flightTimePosition: FlightTimePosition
    public var foPilotFlyingCredit: TimeCreditType  // What time credit to use when F/O is PF (ICUS or P2)
    public var includeLeadingZeroInFlightNumber: Bool
    public var includeAirlinePrefixInFlightNumber: Bool
    public var airlinePrefix: String
    public var isCustomAirlinePrefix: Bool
    public var showFullAircraftReg: Bool
    public var savedCaptainNames: [String]
    public var savedCoPilotNames: [String]
    public var savePhotosToLibrary: Bool  // NEW SETTING
    public var showSONameFields: Bool  // Show/hide SO 1 and SO 2 fields
    public var showSpInsSelector: Bool // Show/hide the INS toggle for Sp/Ins time logging
    public var defaultInstructionEnvironment: InstructionEnvironment // Default environment for instruction logging
    public var pfAutoInstrumentMinutes: Int
    public var logbookDestination: LogbookDestination
    public var displayFlightsInLocalTime: Bool
    public var useIATACodes: Bool
    public var logApproaches: Bool  // Auto-log approaches toggle
    public var defaultApproachType: String?  // Default approach type when logApproaches is enabled
    public var recentCaptainNames: [String]  // Recently used captain names
    public var recentCoPilotNames: [String]  // Recently used copilot names
    public var recentSONames: [String]  // Recently used SO names
    public var recentAircraftRegs: [String]  // Recently used aircraft registrations
    public var recentAirports: [String]  // Recently used airports
    public var showTimesInHoursMinutes: Bool  // Show flight times in HH:MM format instead of decimal
    public var selectedFleetID: String  // Selected fleet for filtering
    public var decimalRoundingMode: RoundingMode  // Rounding mode for decimal times (block and night)
    public var enterTimesInLocalTime: Bool  // Enter OUT/IN/STD/STA in local airport time instead of UTC
    public var showOutInTimes: Bool  // Show OUT/IN (and STD/STA) times in the flights list
    public var countSimInTotal: Bool  // Include SIM time in Total flight time
    public var logCustomCount: Bool  // Show custom counter field in logbook entry
    public var customCountLabel: String  // User-defined label for the counter (default "PAX")


    public static let `default` = AppSettings(
        aircraftReg: "",
        aircraftType: "",
        captainName: "",
        coPilotName: "",
        defaultCaptainName: "",
        defaultCoPilotName: "",
        defaultSOName: "",
        savedSONames: [],
        savedCrewNames: [],
        flightTimePosition: .captain,
        foPilotFlyingCredit: .p1us,  // Default to ICUS
        includeLeadingZeroInFlightNumber: false,
        includeAirlinePrefixInFlightNumber: true,
        airlinePrefix: "QF",
        isCustomAirlinePrefix: false,
        showFullAircraftReg: false,
        savedCaptainNames: [],
        savedCoPilotNames: [],

        savePhotosToLibrary: false,
        showSONameFields: false,
        showSpInsSelector: false,
        defaultInstructionEnvironment: .simulator,
        pfAutoInstrumentMinutes: 30,
        logbookDestination: .internalLogbook,
        displayFlightsInLocalTime: true,
        useIATACodes: true,
        logApproaches: true,
        defaultApproachType: nil,  // No default approach type
        recentCaptainNames: [],
        recentCoPilotNames: [],
        recentSONames: [],
        recentAircraftRegs: [],
        recentAirports: [],
        showTimesInHoursMinutes: false,
        selectedFleetID: "B737",
        decimalRoundingMode: .standard,  // Default to standard rounding
        enterTimesInLocalTime: false,
        showOutInTimes: true,
        countSimInTotal: true,
        logCustomCount: false,
        customCountLabel: "Passengers"
    )
}

// MARK: - UserDefaults Service (Updated)
public class UserDefaultsService: ObservableObject {
    
    private enum Keys {
        static let aircraftReg = "aircraftReg"
        static let aircraftType = "aircraftType"
        static let captainName = "captainName"
        static let coPilotName = "coPilotName"
        static let defaultCaptainName = "defaultCaptainName"
        static let defaultCoPilotName = "defaultCoPilotName"
        static let defaultSOName = "defaultSOName"
        static let savedSONames = "savedSONames"
        static let flightTimePosition = "flightTimePosition"
        static let foPilotFlyingCredit = "foPilotFlyingCredit"
        static let includeLeadingZeroInFlightNumber = "includeLeadingZeroInFlightNumber"
        static let includeAirlinePrefixInFlightNumber = "includeAirlinePrefixInFlightNumber"
        static let airlinePrefix = "airlinePrefix"
        static let isCustomAirlinePrefix = "isCustomAirlinePrefix"
        static let showFullAircraftReg = "showFullAircraftReg"
        static let savedCaptainNames = "savedCaptainNames"
        static let savedCoPilotNames = "savedCoPilotNames"
        static let savePhotosToLibrary = "savePhotosToLibrary"
        static let showSONameFields = "showSONameFields"
        static let showSpInsSelector = "showSpInsSelector"
        static let defaultInstructionEnvironment = "defaultInstructionEnvironment"
        static let logbookDestination = "logbookDestination"
        static let pfAutoInstrumentMinutes = "pfAutoInstrumentMinutes"
        static let displayFlightsInLocalTime = "displayFlightsInLocalTime"
        static let useIATACodes = "useIATACodes"
        static let logApproaches = "logApproaches"
        static let defaultApproachType = "defaultApproachType"
        static let recentCaptainNames = "recentCaptainNames"
        static let recentCoPilotNames = "recentCoPilotNames"
        static let recentSONames = "recentSONames"
        static let recentAircraftRegs = "recentAircraftRegs"
        static let recentAirports = "recentAirports"
        static let showTimesInHoursMinutes = "showTimesInHoursMinutes"
        static let selectedFleetID = "selectedFleetID"
        static let decimalRoundingMode = "decimalRoundingMode"
        static let enterTimesInLocalTime = "enterTimesInLocalTime"
        static let showOutInTimes = "showOutInTimes"
        static let countSimInTotal = "countSimInTotal"
        static let logCustomCount = "logCustomCount"
        static let customCountLabel = "customCountLabel"
        static let onboardingCompleted = "onboardingCompleted"
        static let savedCrewNames = "savedCrewNames"
        static let crewNamesMigrated = "crewNamesMigrated"
    }
    
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        userDefaults.register(defaults: [
            Keys.displayFlightsInLocalTime: true,
            Keys.logApproaches: true,
            Keys.includeAirlinePrefixInFlightNumber: true,
            Keys.useIATACodes: true
        ])
    }
    
    // MARK: - Load/Save All Settings
    
    /// Load all app settings from UserDefaults
    public func loadSettings() -> AppSettings {
        migrateCrewNamesIfNeeded()
        let flightTimePositionString = userDefaults.string(forKey: Keys.flightTimePosition) ?? FlightTimePosition.captain.rawValue
        let flightTimePosition = FlightTimePosition(rawValue: flightTimePositionString) ?? .captain
        let foPilotFlyingCreditString = userDefaults.string(forKey: Keys.foPilotFlyingCredit) ?? TimeCreditType.p1us.rawValue
        let foPilotFlyingCredit = TimeCreditType(rawValue: foPilotFlyingCreditString) ?? .p1us
        let logbookDestinationString = userDefaults.string(forKey: Keys.logbookDestination) ?? LogbookDestination.internalLogbook.rawValue
        let logbookDestination = LogbookDestination(rawValue: logbookDestinationString) ?? .internalLogbook
        let roundingModeString = userDefaults.string(forKey: Keys.decimalRoundingMode) ?? RoundingMode.standard.rawValue
        let roundingMode = RoundingMode(rawValue: roundingModeString) ?? .standard

        return AppSettings(
            aircraftReg: userDefaults.string(forKey: Keys.aircraftReg) ?? "",
            aircraftType: userDefaults.string(forKey: Keys.aircraftType) ?? "",
            captainName: userDefaults.string(forKey: Keys.captainName) ?? "",
            coPilotName: userDefaults.string(forKey: Keys.coPilotName) ?? "",
            defaultCaptainName: userDefaults.string(forKey: Keys.defaultCaptainName) ?? "",
            defaultCoPilotName: userDefaults.string(forKey: Keys.defaultCoPilotName) ?? "",
            defaultSOName: userDefaults.string(forKey: Keys.defaultSOName) ?? "",
            savedSONames: loadAndSortCrewNames(forKey: Keys.savedSONames),
            savedCrewNames: loadAndSortCrewNames(forKey: Keys.savedCrewNames),
            flightTimePosition: flightTimePosition,
            foPilotFlyingCredit: foPilotFlyingCredit,
            includeLeadingZeroInFlightNumber: userDefaults.bool(forKey: Keys.includeLeadingZeroInFlightNumber),
            includeAirlinePrefixInFlightNumber: userDefaults.bool(forKey: Keys.includeAirlinePrefixInFlightNumber),
            airlinePrefix: userDefaults.string(forKey: Keys.airlinePrefix) ?? "QF",
            isCustomAirlinePrefix: userDefaults.bool(forKey: Keys.isCustomAirlinePrefix),
            showFullAircraftReg: userDefaults.object(forKey: Keys.showFullAircraftReg) as? Bool ?? false,
            savedCaptainNames: loadAndSortCrewNames(forKey: Keys.savedCaptainNames),
            savedCoPilotNames: loadAndSortCrewNames(forKey: Keys.savedCoPilotNames),
            savePhotosToLibrary: userDefaults.bool(forKey: Keys.savePhotosToLibrary),
            showSONameFields: userDefaults.bool(forKey: Keys.showSONameFields),
            showSpInsSelector: userDefaults.bool(forKey: Keys.showSpInsSelector),
            defaultInstructionEnvironment: InstructionEnvironment(rawValue: userDefaults.string(forKey: Keys.defaultInstructionEnvironment) ?? "") ?? .simulator,
            pfAutoInstrumentMinutes: (userDefaults.object(forKey: Keys.pfAutoInstrumentMinutes) as? Int) ?? 30,
            logbookDestination: logbookDestination,
            displayFlightsInLocalTime: userDefaults.bool(forKey: Keys.displayFlightsInLocalTime),
            useIATACodes: userDefaults.bool(forKey: Keys.useIATACodes),
            logApproaches: userDefaults.bool(forKey: Keys.logApproaches),
            defaultApproachType: userDefaults.string(forKey: Keys.defaultApproachType),
            recentCaptainNames: userDefaults.stringArray(forKey: Keys.recentCaptainNames) ?? [],
            recentCoPilotNames: userDefaults.stringArray(forKey: Keys.recentCoPilotNames) ?? [],
            recentSONames: userDefaults.stringArray(forKey: Keys.recentSONames) ?? [],
            recentAircraftRegs: userDefaults.stringArray(forKey: Keys.recentAircraftRegs) ?? [],
            recentAirports: userDefaults.stringArray(forKey: Keys.recentAirports) ?? [],
            showTimesInHoursMinutes: userDefaults.bool(forKey: Keys.showTimesInHoursMinutes),
            selectedFleetID: userDefaults.string(forKey: Keys.selectedFleetID) ?? "B737",
            decimalRoundingMode: roundingMode,
            enterTimesInLocalTime: userDefaults.bool(forKey: Keys.enterTimesInLocalTime),
            showOutInTimes: userDefaults.object(forKey: Keys.showOutInTimes) as? Bool ?? true,
            countSimInTotal: userDefaults.object(forKey: Keys.countSimInTotal) as? Bool ?? true,
            logCustomCount: userDefaults.bool(forKey: Keys.logCustomCount),
            customCountLabel: userDefaults.string(forKey: Keys.customCountLabel) ?? "Passengers"
        )
    }

    
    /// Save all app settings to UserDefaults
    public func saveSettings(_ settings: AppSettings, syncToCloud: Bool = true) {
        userDefaults.set(settings.aircraftReg, forKey: Keys.aircraftReg)
        userDefaults.set(settings.aircraftType, forKey: Keys.aircraftType)
        userDefaults.set(settings.captainName, forKey: Keys.captainName)
        userDefaults.set(settings.coPilotName, forKey: Keys.coPilotName)
        userDefaults.set(settings.defaultCaptainName, forKey: Keys.defaultCaptainName)
        userDefaults.set(settings.defaultCoPilotName, forKey: Keys.defaultCoPilotName)
        userDefaults.set(settings.defaultSOName, forKey: Keys.defaultSOName)
        userDefaults.set(settings.savedSONames, forKey: Keys.savedSONames)
        userDefaults.set(settings.savedCrewNames, forKey: Keys.savedCrewNames)
        userDefaults.set(settings.flightTimePosition.rawValue, forKey: Keys.flightTimePosition)
        userDefaults.set(settings.includeLeadingZeroInFlightNumber, forKey: Keys.includeLeadingZeroInFlightNumber)
        userDefaults.set(settings.includeAirlinePrefixInFlightNumber, forKey: Keys.includeAirlinePrefixInFlightNumber)
        userDefaults.set(settings.airlinePrefix, forKey: Keys.airlinePrefix)
        userDefaults.set(settings.showFullAircraftReg, forKey: Keys.showFullAircraftReg)
        userDefaults.set(settings.savedCaptainNames, forKey: Keys.savedCaptainNames)
        userDefaults.set(settings.savedCoPilotNames, forKey: Keys.savedCoPilotNames)
        userDefaults.set(settings.savePhotosToLibrary, forKey: Keys.savePhotosToLibrary)
        userDefaults.set(settings.showSONameFields, forKey: Keys.showSONameFields)
        userDefaults.set(settings.showSpInsSelector, forKey: Keys.showSpInsSelector)
        userDefaults.set(settings.defaultInstructionEnvironment.rawValue, forKey: Keys.defaultInstructionEnvironment)
        userDefaults.set(settings.pfAutoInstrumentMinutes, forKey: Keys.pfAutoInstrumentMinutes)
        userDefaults.set(settings.logbookDestination.rawValue, forKey: Keys.logbookDestination)
        userDefaults.set(settings.displayFlightsInLocalTime, forKey: Keys.displayFlightsInLocalTime)
        userDefaults.set(settings.useIATACodes, forKey: Keys.useIATACodes)
        userDefaults.set(settings.logApproaches, forKey: Keys.logApproaches)
        userDefaults.set(settings.defaultApproachType, forKey: Keys.defaultApproachType)
        userDefaults.set(settings.showTimesInHoursMinutes, forKey: Keys.showTimesInHoursMinutes)
        userDefaults.set(settings.selectedFleetID, forKey: Keys.selectedFleetID)
        userDefaults.set(settings.decimalRoundingMode.rawValue, forKey: Keys.decimalRoundingMode)
        userDefaults.set(settings.enterTimesInLocalTime, forKey: Keys.enterTimesInLocalTime)
        userDefaults.set(settings.showOutInTimes, forKey: Keys.showOutInTimes)
        userDefaults.set(settings.countSimInTotal, forKey: Keys.countSimInTotal)
        userDefaults.set(settings.logCustomCount, forKey: Keys.logCustomCount)
        userDefaults.set(settings.customCountLabel, forKey: Keys.customCountLabel)
        userDefaults.set(settings.recentCaptainNames, forKey: Keys.recentCaptainNames)
        userDefaults.set(settings.recentCoPilotNames, forKey: Keys.recentCoPilotNames)
        userDefaults.set(settings.recentAircraftRegs, forKey: Keys.recentAircraftRegs)
        userDefaults.set(settings.recentAirports, forKey: Keys.recentAirports)

        // Sync to iCloud if enabled
        if syncToCloud {
            Task {
                await MainActor.run {
                    // Mark that local settings were modified
                    CloudKitSettingsSyncService.shared.markLocalModification()
                    // Sync to cloud if network is available
                    CloudKitSettingsSyncService.shared.syncToCloud()
                }
            }
        }
    }
    
    // MARK: - Individual Setting Methods

    public func setAircraftReg(_ value: String) {
        userDefaults.set(value, forKey: Keys.aircraftReg)
        syncToCloudAfterChange()
    }

    public func setAircraftType(_ value: String) {
        userDefaults.set(value, forKey: Keys.aircraftType)
        syncToCloudAfterChange()
    }

    public func setCaptainName(_ value: String) {
        userDefaults.set(value, forKey: Keys.captainName)
        syncToCloudAfterChange()
    }

    public func setCoPilotName(_ value: String) {
        userDefaults.set(value, forKey: Keys.coPilotName)
        syncToCloudAfterChange()
    }

    public func setDefaultCaptainName(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.defaultCaptainName)
        syncToCloudAfterChange()
    }

    public func setDefaultCoPilotName(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.defaultCoPilotName)
        syncToCloudAfterChange()
    }

    public func setDefaultSOName(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.defaultSOName)
        syncToCloudAfterChange()
    }

    public func setFlightTimePosition(_ value: FlightTimePosition) {
        markModificationAndSyncToCloud()
        userDefaults.set(value.rawValue, forKey: Keys.flightTimePosition)
        syncToCloudAfterChange()
    }

    public func setFOPilotFlyingCredit(_ value: TimeCreditType) {
        markModificationAndSyncToCloud()
        userDefaults.set(value.rawValue, forKey: Keys.foPilotFlyingCredit)
        syncToCloudAfterChange()
    }

    public func setIncludeLeadingZeroInFlightNumber(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.includeLeadingZeroInFlightNumber)
        syncToCloudAfterChange()
    }

    public func setIncludeAirlinePrefixInFlightNumber(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.includeAirlinePrefixInFlightNumber)
        syncToCloudAfterChange()
    }

    public func setAirlinePrefix(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.airlinePrefix)
        syncToCloudAfterChange()
    }

    public func setIsCustomAirlinePrefix(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.isCustomAirlinePrefix)
        syncToCloudAfterChange()
    }

    public func setShowFullAircraftReg(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.showFullAircraftReg)
        syncToCloudAfterChange()
    }

    public func setSavePhotosToLibrary(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.savePhotosToLibrary)
        syncToCloudAfterChange()
    }

    public func setShowSpInsSelector(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.showSpInsSelector)
        syncToCloudAfterChange()
    }

    public func setDefaultInstructionEnvironment(_ value: InstructionEnvironment) {
        markModificationAndSyncToCloud()
        userDefaults.set(value.rawValue, forKey: Keys.defaultInstructionEnvironment)
        syncToCloudAfterChange()
    }

    public func setShowSONameFields(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.showSONameFields)
        syncToCloudAfterChange()
    }

    public func setLogCustomCount(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.logCustomCount)
        syncToCloudAfterChange()
    }

    public func setCustomCountLabel(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.customCountLabel)
        syncToCloudAfterChange()
    }

    public func setLogbookDestination(_ value: LogbookDestination) {
        markModificationAndSyncToCloud()
        userDefaults.set(value.rawValue, forKey: Keys.logbookDestination)
        syncToCloudAfterChange()
    }

    public func setPFAutoInstrumentMinutes(_ value: Int) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.pfAutoInstrumentMinutes)
        syncToCloudAfterChange()
    }

    public func setDisplayFlightsInLocalTime(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.displayFlightsInLocalTime)
        syncToCloudAfterChange()
    }

    public func setUseIATACodes(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.useIATACodes)
        syncToCloudAfterChange()
    }

    public func setShowTimesInHoursMinutes(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.showTimesInHoursMinutes)
        syncToCloudAfterChange()
    }

    public func setLogApproaches(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.logApproaches)
        syncToCloudAfterChange()
    }

    public func setDefaultApproachType(_ value: String?) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.defaultApproachType)
        syncToCloudAfterChange()
    }

    public func setSelectedFleetID(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.selectedFleetID)
        syncToCloudAfterChange()
    }

    public func setDecimalRoundingMode(_ value: RoundingMode) {
        markModificationAndSyncToCloud()
        userDefaults.set(value.rawValue, forKey: Keys.decimalRoundingMode)
        syncToCloudAfterChange()
    }

    public func setEnterTimesInLocalTime(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.enterTimesInLocalTime)
        syncToCloudAfterChange()
    }

    public func setShowOutInTimes(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.showOutInTimes)
        syncToCloudAfterChange()
    }

    public func setCountSimInTotal(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.countSimInTotal)
        syncToCloudAfterChange()
    }

    public func setRecentCaptainNames(_ value: [String]) {
        userDefaults.set(value, forKey: Keys.recentCaptainNames)
        syncToCloudAfterChange()
    }

    public func setRecentCoPilotNames(_ value: [String]) {
        userDefaults.set(value, forKey: Keys.recentCoPilotNames)
        syncToCloudAfterChange()
    }

    public func setRecentSONames(_ value: [String]) {
        userDefaults.set(value, forKey: Keys.recentSONames)
        syncToCloudAfterChange()
    }

    public func setRecentAircraftRegs(_ value: [String]) {
        userDefaults.set(value, forKey: Keys.recentAircraftRegs)
        syncToCloudAfterChange()
    }

    // MARK: - Private Helper for Cloud Sync

    private func syncToCloudAfterChange() {
        Task {
            await MainActor.run {
                // Sync to cloud if network is available
                CloudKitSettingsSyncService.shared.syncToCloud()
            }
        }
    }

    private func markModificationAndSyncToCloud() {
        Task { @MainActor in
            CloudKitSettingsSyncService.shared.markLocalModification()
        }
    }
    
    // MARK: - Unified Crew Name Management

    /// One-time migration: unions the three legacy crew name lists into savedCrewNames.
    /// Guarded by the crewNamesMigrated flag — runs once per device, never again.
    private func migrateCrewNamesIfNeeded() {
        guard !userDefaults.bool(forKey: Keys.crewNamesMigrated) else { return }
        let captains = userDefaults.stringArray(forKey: Keys.savedCaptainNames) ?? []
        let coPilots = userDefaults.stringArray(forKey: Keys.savedCoPilotNames) ?? []
        let sos = userDefaults.stringArray(forKey: Keys.savedSONames) ?? []
        let unified = sortCrewNamesByFirstName(Array(Set(captains + coPilots + sos)))
        userDefaults.set(unified, forKey: Keys.savedCrewNames)
        userDefaults.set(true, forKey: Keys.crewNamesMigrated)
    }

    /// Add a name to the unified crew list. Returns the updated sorted list.
    public func addCrewName(_ name: String) -> [String] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return loadAndSortCrewNames(forKey: Keys.savedCrewNames) }
        var names = userDefaults.stringArray(forKey: Keys.savedCrewNames) ?? []
        if !names.contains(trimmedName) {
            names.append(trimmedName)
            let sorted = sortCrewNamesByFirstName(names)
            userDefaults.set(sorted, forKey: Keys.savedCrewNames)
            return sorted
        }
        return loadAndSortCrewNames(forKey: Keys.savedCrewNames)
    }

    /// Remove a name from the unified crew list. Returns the updated list.
    public func removeCrewName(_ name: String) -> [String] {
        var names = userDefaults.stringArray(forKey: Keys.savedCrewNames) ?? []
        names.removeAll { $0 == name }
        let sorted = sortCrewNamesByFirstName(names)
        userDefaults.set(sorted, forKey: Keys.savedCrewNames)
        return sorted
    }

    // MARK: - Crew Name Management (legacy delegates — keep for backward compat)

    public func addCaptainName(_ name: String) -> [String] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return loadAndSortCrewNames(forKey: Keys.savedCrewNames) }
        // Keep legacy key updated for CloudKit backward compat
        var legacy = userDefaults.stringArray(forKey: Keys.savedCaptainNames) ?? []
        if !legacy.contains(trimmedName) {
            legacy.append(trimmedName)
            userDefaults.set(sortCrewNamesByFirstName(legacy), forKey: Keys.savedCaptainNames)
        }
        return addCrewName(trimmedName)
    }

    public func addCoPilotName(_ name: String) -> [String] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return loadAndSortCrewNames(forKey: Keys.savedCrewNames) }
        // Keep legacy key updated for CloudKit backward compat
        var legacy = userDefaults.stringArray(forKey: Keys.savedCoPilotNames) ?? []
        if !legacy.contains(trimmedName) {
            legacy.append(trimmedName)
            userDefaults.set(sortCrewNamesByFirstName(legacy), forKey: Keys.savedCoPilotNames)
        }
        return addCrewName(trimmedName)
    }

    public func addSOName(_ name: String) -> [String] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return loadAndSortCrewNames(forKey: Keys.savedCrewNames) }
        // Keep legacy key updated for CloudKit backward compat
        var legacy = userDefaults.stringArray(forKey: Keys.savedSONames) ?? []
        if !legacy.contains(trimmedName) {
            legacy.append(trimmedName)
            userDefaults.set(sortCrewNamesByFirstName(legacy), forKey: Keys.savedSONames)
        }
        return addCrewName(trimmedName)
    }

    public func removeCaptainName(_ name: String) -> [String] {
        // Keep legacy key updated for CloudKit backward compat
        var legacy = userDefaults.stringArray(forKey: Keys.savedCaptainNames) ?? []
        legacy.removeAll { $0 == name }
        userDefaults.set(legacy, forKey: Keys.savedCaptainNames)
        return removeCrewName(name)
    }

    public func removeCoPilotName(_ name: String) -> [String] {
        // Keep legacy key updated for CloudKit backward compat
        var legacy = userDefaults.stringArray(forKey: Keys.savedCoPilotNames) ?? []
        legacy.removeAll { $0 == name }
        userDefaults.set(legacy, forKey: Keys.savedCoPilotNames)
        return removeCrewName(name)
    }

    public func removeSOName(_ name: String) -> [String] {
        // Keep legacy key updated for CloudKit backward compat
        var legacy = userDefaults.stringArray(forKey: Keys.savedSONames) ?? []
        legacy.removeAll { $0 == name }
        userDefaults.set(legacy, forKey: Keys.savedSONames)
        return removeCrewName(name)
    }

    public func clearAllCaptainNames() {
        userDefaults.removeObject(forKey: Keys.savedCaptainNames)
    }

    public func clearAllCoPilotNames() {
        userDefaults.removeObject(forKey: Keys.savedCoPilotNames)
    }

    // MARK: - Recent Crew Names Management

    /// Track a recently used captain name
    public func trackRecentCaptainName(_ name: String) {
        trackRecentName(name, forKey: Keys.recentCaptainNames)
    }

    /// Track a recently used copilot name
    public func trackRecentCoPilotName(_ name: String) {
        trackRecentName(name, forKey: Keys.recentCoPilotNames)
    }

    /// Track a recently used SO name
    public func trackRecentSOName(_ name: String) {
        trackRecentName(name, forKey: Keys.recentSONames)
    }

    /// Get recent captain names
    public func getRecentCaptainNames() -> [String] {
        return userDefaults.stringArray(forKey: Keys.recentCaptainNames) ?? []
    }

    /// Get recent copilot names
    public func getRecentCoPilotNames() -> [String] {
        return userDefaults.stringArray(forKey: Keys.recentCoPilotNames) ?? []
    }

    /// Get recent SO names
    public func getRecentSONames() -> [String] {
        return userDefaults.stringArray(forKey: Keys.recentSONames) ?? []
    }

    /// Track a recently used aircraft registration
    public func trackRecentAircraftReg(_ reg: String) {
        trackRecentName(reg, forKey: Keys.recentAircraftRegs)
    }

    /// Get recent aircraft registrations
    public func getRecentAircraftRegs() -> [String] {
        return userDefaults.stringArray(forKey: Keys.recentAircraftRegs) ?? []
    }

    /// Track a recently used airport
    public func trackRecentAirport(_ airport: String) {
        trackRecentName(airport, forKey: Keys.recentAirports, maxCount: 3)
    }

    /// Get recent airports
    public func getRecentAirports() -> [String] {
        return userDefaults.stringArray(forKey: Keys.recentAirports) ?? []
    }

    /// Private helper to track a recent name (maintains max recent names)
    private func trackRecentName(_ name: String, forKey key: String, maxCount: Int = 3) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var recentNames = userDefaults.stringArray(forKey: key) ?? []

        // Remove the name if it already exists (we'll add it to the front)
        recentNames.removeAll { $0 == trimmedName }

        // Add to the front
        recentNames.insert(trimmedName, at: 0)

        // Keep only the max most recent
        if recentNames.count > maxCount {
            recentNames = Array(recentNames.prefix(maxCount))
        }

        userDefaults.set(recentNames, forKey: key)

        // Sync recent names to cloud
        syncToCloudAfterChange()
    }

    // MARK: - Utility Methods
    
    public func resetAllSettings() {
        let keys = [
            Keys.aircraftReg,
            Keys.captainName,
            Keys.coPilotName,
            Keys.defaultCaptainName,
            Keys.defaultCoPilotName,
            Keys.flightTimePosition,
            Keys.includeLeadingZeroInFlightNumber,
            Keys.includeAirlinePrefixInFlightNumber,
            Keys.showFullAircraftReg,
            Keys.savedCaptainNames,
            Keys.savedCoPilotNames,
            Keys.savePhotosToLibrary  // NEW KEY IN RESET
        ]
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
        
        print("All UserDefaults settings have been reset")
    }
    
    public func exportSettings() -> [String: Any] {
        let settings = loadSettings()
        return [
            "aircraftReg": settings.aircraftReg,
            "captainName": settings.captainName,
            "coPilotName": settings.coPilotName,
            "defaultCaptainName": settings.defaultCaptainName,
            "defaultCoPilotName": settings.defaultCoPilotName,
            "flightTimePosition": settings.flightTimePosition.rawValue,
            "includeLeadingZeroInFlightNumber": settings.includeLeadingZeroInFlightNumber,
            "includeAirlinePrefixInFlightNumber": settings.includeAirlinePrefixInFlightNumber,
            "showFullAircraftReg": settings.showFullAircraftReg,
            "savedCaptainNames": settings.savedCaptainNames,
            "savedCoPilotNames": settings.savedCoPilotNames,
            "savePhotosToLibrary": settings.savePhotosToLibrary  // NEW EXPORT FIELD
        ]
    }
    
    // MARK: - Private Helper Methods
    
    private func loadAndSortCrewNames(forKey key: String) -> [String] {
        let names = userDefaults.stringArray(forKey: key) ?? []
        return sortCrewNamesByFirstName(names)
    }
    
    private func sortCrewNamesByFirstName(_ names: [String]) -> [String] {
        return names.sorted { name1, name2 in
            let firstName1 = name1.components(separatedBy: " ").first ?? name1
            let firstName2 = name2.components(separatedBy: " ").first ?? name2
            return firstName1.localizedCaseInsensitiveCompare(firstName2) == .orderedAscending
        }
    }
}

// MARK: - Convenience Extensions
extension UserDefaultsService {
    
    /// Check if this is the first app launch
    public var isFirstLaunch: Bool {
        let hasLaunchedKey = "hasLaunchedBefore"
        let hasLaunched = userDefaults.bool(forKey: hasLaunchedKey)
        
        if !hasLaunched {
            userDefaults.set(true, forKey: hasLaunchedKey)
            return true
        }
        
        return false
    }
    
    /// Get app version for migration purposes
    public func getStoredAppVersion() -> String? {
        return userDefaults.string(forKey: "appVersion")
    }
    
    public func setStoredAppVersion(_ version: String) {
        userDefaults.set(version, forKey: "appVersion")
    }

    /// Track whether the user has completed onboarding
    public var onboardingCompleted: Bool {
        get { userDefaults.bool(forKey: Keys.onboardingCompleted) }
        set { userDefaults.set(newValue, forKey: Keys.onboardingCompleted) }
    }
}

