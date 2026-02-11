//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//


import Foundation
import Combine


enum LogbookDestination: String, CaseIterable {
    case internalLogbook = "Block-Time"
    case logTenPro = "LogTen"
    case both = "Both"

    var userDefaultsKey: String {
        return "logbookDestination"
    }

    var menuLabel: String {
        switch self {
        case .internalLogbook:
            return "Block-Time"
        case .logTenPro:
            return "LogTen"
        case .both:
            return "Both"
        }
    }

    var displayName: String {
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

enum RoundingMode: String, CaseIterable {
    case roundDown = "Round Down"
    case roundUp = "Round Up"
    case standard = "Standard"

    var displayName: String {
        return self.rawValue
    }

    /// Apply rounding to a decimal value
    func apply(to value: Double, decimalPlaces: Int = 1) -> Double {
        let multiplier = pow(10.0, Double(decimalPlaces))
        switch self {
        case .roundDown:
            return floor(value * multiplier) / multiplier
        case .roundUp:
            return ceil(value * multiplier) / multiplier
        case .standard:
            return (value * multiplier).rounded(.toNearestOrAwayFromZero) / multiplier
        }
    }
}



// MARK: - Settings Data Model (Updated)
struct AppSettings {
    var aircraftReg: String
    var aircraftType: String
    var captainName: String
    var coPilotName: String
    var defaultCaptainName: String
    var defaultCoPilotName: String
    var defaultSOName: String
    var savedSONames: [String]  // Shared list for both SO 1 and SO 2
    var flightTimePosition: FlightTimePosition
    var includeLeadingZeroInFlightNumber: Bool
    var includeAirlinePrefixInFlightNumber: Bool
    var airlinePrefix: String
    var isCustomAirlinePrefix: Bool
    var showFullAircraftReg: Bool
    var savedCaptainNames: [String]
    var savedCoPilotNames: [String]
    var savePhotosToLibrary: Bool  // NEW SETTING
    var showSONameFields: Bool  // Show/hide SO 1 and SO 2 fields
    var pfAutoInstrumentMinutes: Int
    var logbookDestination: LogbookDestination
    var displayFlightsInLocalTime: Bool
    var useIATACodes: Bool
    var logApproaches: Bool  // Auto-log approaches toggle
    var defaultApproachType: String?  // Default approach type when logApproaches is enabled
    var recentCaptainNames: [String]  // Recently used captain names
    var recentCoPilotNames: [String]  // Recently used copilot names
    var recentSONames: [String]  // Recently used SO names
    var recentAircraftRegs: [String]  // Recently used aircraft registrations
    var recentAirports: [String]  // Recently used airports
    var showTimesInHoursMinutes: Bool  // Show flight times in HH:MM format instead of decimal
    var selectedFleetID: String  // Selected fleet for filtering
    var decimalRoundingMode: RoundingMode  // Rounding mode for decimal times (block and night)


    static let `default` = AppSettings(
        aircraftReg: "",
        aircraftType: "",
        captainName: "",
        coPilotName: "",
        defaultCaptainName: "",
        defaultCoPilotName: "",
        defaultSOName: "",
        savedSONames: [],
        flightTimePosition: .captain,
        includeLeadingZeroInFlightNumber: false,
        includeAirlinePrefixInFlightNumber: true,
        airlinePrefix: "QF",
        isCustomAirlinePrefix: false,
        showFullAircraftReg: false,
        savedCaptainNames: [],
        savedCoPilotNames: [],

        savePhotosToLibrary: false,
        showSONameFields: false,
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
        decimalRoundingMode: .standard  // Default to standard rounding
    )
}

// MARK: - UserDefaults Service (Updated)
class UserDefaultsService: ObservableObject {
    
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
        static let includeLeadingZeroInFlightNumber = "includeLeadingZeroInFlightNumber"
        static let includeAirlinePrefixInFlightNumber = "includeAirlinePrefixInFlightNumber"
        static let airlinePrefix = "airlinePrefix"
        static let isCustomAirlinePrefix = "isCustomAirlinePrefix"
        static let showFullAircraftReg = "showFullAircraftReg"
        static let savedCaptainNames = "savedCaptainNames"
        static let savedCoPilotNames = "savedCoPilotNames"
        static let savePhotosToLibrary = "savePhotosToLibrary"
        static let showSONameFields = "showSONameFields"
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
        static let onboardingCompleted = "onboardingCompleted"
    }
    
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Load/Save All Settings
    
    /// Load all app settings from UserDefaults
    func loadSettings() -> AppSettings {
        let flightTimePositionString = userDefaults.string(forKey: Keys.flightTimePosition) ?? FlightTimePosition.captain.rawValue
        let flightTimePosition = FlightTimePosition(rawValue: flightTimePositionString) ?? .captain
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
            flightTimePosition: flightTimePosition,
            includeLeadingZeroInFlightNumber: userDefaults.bool(forKey: Keys.includeLeadingZeroInFlightNumber),
            includeAirlinePrefixInFlightNumber: userDefaults.bool(forKey: Keys.includeAirlinePrefixInFlightNumber),
            airlinePrefix: userDefaults.string(forKey: Keys.airlinePrefix) ?? "QF",
            isCustomAirlinePrefix: userDefaults.bool(forKey: Keys.isCustomAirlinePrefix),
            showFullAircraftReg: userDefaults.object(forKey: Keys.showFullAircraftReg) as? Bool ?? false,
            savedCaptainNames: loadAndSortCrewNames(forKey: Keys.savedCaptainNames),
            savedCoPilotNames: loadAndSortCrewNames(forKey: Keys.savedCoPilotNames),
            savePhotosToLibrary: userDefaults.bool(forKey: Keys.savePhotosToLibrary),
            showSONameFields: userDefaults.bool(forKey: Keys.showSONameFields),
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
            decimalRoundingMode: roundingMode
        )
    }

    
    /// Save all app settings to UserDefaults
    func saveSettings(_ settings: AppSettings, syncToCloud: Bool = true) {
        userDefaults.set(settings.aircraftReg, forKey: Keys.aircraftReg)
        userDefaults.set(settings.aircraftType, forKey: Keys.aircraftType)
        userDefaults.set(settings.captainName, forKey: Keys.captainName)
        userDefaults.set(settings.coPilotName, forKey: Keys.coPilotName)
        userDefaults.set(settings.defaultCaptainName, forKey: Keys.defaultCaptainName)
        userDefaults.set(settings.defaultCoPilotName, forKey: Keys.defaultCoPilotName)
        userDefaults.set(settings.defaultSOName, forKey: Keys.defaultSOName)
        userDefaults.set(settings.savedSONames, forKey: Keys.savedSONames)
        userDefaults.set(settings.flightTimePosition.rawValue, forKey: Keys.flightTimePosition)
        userDefaults.set(settings.includeLeadingZeroInFlightNumber, forKey: Keys.includeLeadingZeroInFlightNumber)
        userDefaults.set(settings.includeAirlinePrefixInFlightNumber, forKey: Keys.includeAirlinePrefixInFlightNumber)
        userDefaults.set(settings.airlinePrefix, forKey: Keys.airlinePrefix)
        userDefaults.set(settings.showFullAircraftReg, forKey: Keys.showFullAircraftReg)
        userDefaults.set(settings.savedCaptainNames, forKey: Keys.savedCaptainNames)
        userDefaults.set(settings.savedCoPilotNames, forKey: Keys.savedCoPilotNames)
        userDefaults.set(settings.savePhotosToLibrary, forKey: Keys.savePhotosToLibrary)
        userDefaults.set(settings.showSONameFields, forKey: Keys.showSONameFields)
        userDefaults.set(settings.pfAutoInstrumentMinutes, forKey: Keys.pfAutoInstrumentMinutes)
        userDefaults.set(settings.logbookDestination.rawValue, forKey: Keys.logbookDestination)
        userDefaults.set(settings.displayFlightsInLocalTime, forKey: Keys.displayFlightsInLocalTime)
        userDefaults.set(settings.useIATACodes, forKey: Keys.useIATACodes)
        userDefaults.set(settings.logApproaches, forKey: Keys.logApproaches)
        userDefaults.set(settings.defaultApproachType, forKey: Keys.defaultApproachType)
        userDefaults.set(settings.showTimesInHoursMinutes, forKey: Keys.showTimesInHoursMinutes)
        userDefaults.set(settings.selectedFleetID, forKey: Keys.selectedFleetID)
        userDefaults.set(settings.decimalRoundingMode.rawValue, forKey: Keys.decimalRoundingMode)

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

    func setAircraftReg(_ value: String) {
        userDefaults.set(value, forKey: Keys.aircraftReg)
        syncToCloudAfterChange()
    }

    func setAircraftType(_ value: String) {
        userDefaults.set(value, forKey: Keys.aircraftType)
        syncToCloudAfterChange()
    }

    func setCaptainName(_ value: String) {
        userDefaults.set(value, forKey: Keys.captainName)
        syncToCloudAfterChange()
    }

    func setCoPilotName(_ value: String) {
        userDefaults.set(value, forKey: Keys.coPilotName)
        syncToCloudAfterChange()
    }

    func setDefaultCaptainName(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.defaultCaptainName)
        syncToCloudAfterChange()
    }

    func setDefaultCoPilotName(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.defaultCoPilotName)
        syncToCloudAfterChange()
    }

    func setDefaultSOName(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.defaultSOName)
        syncToCloudAfterChange()
    }

    func setFlightTimePosition(_ value: FlightTimePosition) {
        markModificationAndSyncToCloud()
        userDefaults.set(value.rawValue, forKey: Keys.flightTimePosition)
        syncToCloudAfterChange()
    }

    func setIncludeLeadingZeroInFlightNumber(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.includeLeadingZeroInFlightNumber)
        syncToCloudAfterChange()
    }

    func setIncludeAirlinePrefixInFlightNumber(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.includeAirlinePrefixInFlightNumber)
        syncToCloudAfterChange()
    }

    func setAirlinePrefix(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.airlinePrefix)
        syncToCloudAfterChange()
    }

    func setIsCustomAirlinePrefix(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.isCustomAirlinePrefix)
        syncToCloudAfterChange()
    }

    func setShowFullAircraftReg(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.showFullAircraftReg)
        syncToCloudAfterChange()
    }

    func setSavePhotosToLibrary(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.savePhotosToLibrary)
        syncToCloudAfterChange()
    }

    func setShowSONameFields(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.showSONameFields)
        syncToCloudAfterChange()
    }

    func setLogbookDestination(_ value: LogbookDestination) {
        markModificationAndSyncToCloud()
        userDefaults.set(value.rawValue, forKey: Keys.logbookDestination)
        syncToCloudAfterChange()
    }

    func setPFAutoInstrumentMinutes(_ value: Int) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.pfAutoInstrumentMinutes)
        syncToCloudAfterChange()
    }

    func setDisplayFlightsInLocalTime(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.displayFlightsInLocalTime)
        syncToCloudAfterChange()
    }

    func setUseIATACodes(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.useIATACodes)
        syncToCloudAfterChange()
    }

    func setShowTimesInHoursMinutes(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.showTimesInHoursMinutes)
        syncToCloudAfterChange()
    }

    func setLogApproaches(_ value: Bool) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.logApproaches)
        syncToCloudAfterChange()
    }

    func setDefaultApproachType(_ value: String?) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.defaultApproachType)
        syncToCloudAfterChange()
    }

    func setSelectedFleetID(_ value: String) {
        markModificationAndSyncToCloud()
        userDefaults.set(value, forKey: Keys.selectedFleetID)
        syncToCloudAfterChange()
    }

    func setDecimalRoundingMode(_ value: RoundingMode) {
        markModificationAndSyncToCloud()
        userDefaults.set(value.rawValue, forKey: Keys.decimalRoundingMode)
        syncToCloudAfterChange()
    }

    func setRecentCaptainNames(_ value: [String]) {
        userDefaults.set(value, forKey: Keys.recentCaptainNames)
        syncToCloudAfterChange()
    }

    func setRecentCoPilotNames(_ value: [String]) {
        userDefaults.set(value, forKey: Keys.recentCoPilotNames)
        syncToCloudAfterChange()
    }

    func setRecentSONames(_ value: [String]) {
        userDefaults.set(value, forKey: Keys.recentSONames)
        syncToCloudAfterChange()
    }

    func setRecentAircraftRegs(_ value: [String]) {
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
        // Mark modification BEFORE any writes to ensure proper timestamp ordering
        CloudKitSettingsSyncService.shared.markLocalModification()
    }
    
    // MARK: - Crew Name Management (unchanged)
    
    func addCaptainName(_ name: String) -> [String] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return loadAndSortCrewNames(forKey: Keys.savedCaptainNames) }
        
        var names = userDefaults.stringArray(forKey: Keys.savedCaptainNames) ?? []
        
        if !names.contains(trimmedName) {
            names.append(trimmedName)
            let sortedNames = sortCrewNamesByFirstName(names)
            userDefaults.set(sortedNames, forKey: Keys.savedCaptainNames)
            return sortedNames
        }
        
        return loadAndSortCrewNames(forKey: Keys.savedCaptainNames)
    }
    
    func addCoPilotName(_ name: String) -> [String] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return loadAndSortCrewNames(forKey: Keys.savedCoPilotNames) }
        
        var names = userDefaults.stringArray(forKey: Keys.savedCoPilotNames) ?? []
        
        if !names.contains(trimmedName) {
            names.append(trimmedName)
            let sortedNames = sortCrewNamesByFirstName(names)
            userDefaults.set(sortedNames, forKey: Keys.savedCoPilotNames)
            return sortedNames
        }
        
        return loadAndSortCrewNames(forKey: Keys.savedCoPilotNames)
    }
    
    func removeCaptainName(_ name: String) -> [String] {
        var names = userDefaults.stringArray(forKey: Keys.savedCaptainNames) ?? []
        names.removeAll { $0 == name }
        userDefaults.set(names, forKey: Keys.savedCaptainNames)
        return names
    }
    
    func removeCoPilotName(_ name: String) -> [String] {
        var names = userDefaults.stringArray(forKey: Keys.savedCoPilotNames) ?? []
        names.removeAll { $0 == name }
        userDefaults.set(names, forKey: Keys.savedCoPilotNames)
        return names
    }

    func removeSOName(_ name: String) -> [String] {
        var names = userDefaults.stringArray(forKey: Keys.savedSONames) ?? []
        names.removeAll { $0 == name }
        userDefaults.set(names, forKey: Keys.savedSONames)
        return names
    }

    func clearAllCaptainNames() {
        userDefaults.removeObject(forKey: Keys.savedCaptainNames)
    }
    
    func clearAllCoPilotNames() {
        userDefaults.removeObject(forKey: Keys.savedCoPilotNames)
    }
    

    func addSOName(_ name: String) -> [String] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return loadAndSortCrewNames(forKey: Keys.savedSONames) }

        var names = userDefaults.stringArray(forKey: Keys.savedSONames) ?? []

        if !names.contains(trimmedName) {
            names.append(trimmedName)
            let sortedNames = sortCrewNamesByFirstName(names)
            userDefaults.set(sortedNames, forKey: Keys.savedSONames)
            return sortedNames
        }

        return loadAndSortCrewNames(forKey: Keys.savedSONames)
    }

    // MARK: - Recent Crew Names Management

    /// Track a recently used captain name
    func trackRecentCaptainName(_ name: String) {
        trackRecentName(name, forKey: Keys.recentCaptainNames)
    }

    /// Track a recently used copilot name
    func trackRecentCoPilotName(_ name: String) {
        trackRecentName(name, forKey: Keys.recentCoPilotNames)
    }

    /// Track a recently used SO name
    func trackRecentSOName(_ name: String) {
        trackRecentName(name, forKey: Keys.recentSONames)
    }

    /// Get recent captain names
    func getRecentCaptainNames() -> [String] {
        return userDefaults.stringArray(forKey: Keys.recentCaptainNames) ?? []
    }

    /// Get recent copilot names
    func getRecentCoPilotNames() -> [String] {
        return userDefaults.stringArray(forKey: Keys.recentCoPilotNames) ?? []
    }

    /// Get recent SO names
    func getRecentSONames() -> [String] {
        return userDefaults.stringArray(forKey: Keys.recentSONames) ?? []
    }

    /// Track a recently used aircraft registration
    func trackRecentAircraftReg(_ reg: String) {
        trackRecentName(reg, forKey: Keys.recentAircraftRegs)
    }

    /// Get recent aircraft registrations
    func getRecentAircraftRegs() -> [String] {
        return userDefaults.stringArray(forKey: Keys.recentAircraftRegs) ?? []
    }

    /// Track a recently used airport
    func trackRecentAirport(_ airport: String) {
        trackRecentName(airport, forKey: Keys.recentAirports, maxCount: 3)
    }

    /// Get recent airports
    func getRecentAirports() -> [String] {
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
    
    func resetAllSettings() {
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
        
        LogManager.shared.debug("All UserDefaults settings have been reset")
    }
    
    func exportSettings() -> [String: Any] {
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
    var isFirstLaunch: Bool {
        let hasLaunchedKey = "hasLaunchedBefore"
        let hasLaunched = userDefaults.bool(forKey: hasLaunchedKey)
        
        if !hasLaunched {
            userDefaults.set(true, forKey: hasLaunchedKey)
            return true
        }
        
        return false
    }
    
    /// Get app version for migration purposes
    func getStoredAppVersion() -> String? {
        return userDefaults.string(forKey: "appVersion")
    }
    
    func setStoredAppVersion(_ version: String) {
        userDefaults.set(version, forKey: "appVersion")
    }

    /// Track whether the user has completed onboarding
    var onboardingCompleted: Bool {
        get { userDefaults.bool(forKey: Keys.onboardingCompleted) }
        set { userDefaults.set(newValue, forKey: Keys.onboardingCompleted) }
    }
}

