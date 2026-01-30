//
//  CloudKitSettingsSyncService.swift
//  Block-Time
//
//  Created by Nelson Code on 3/10/2025.
//

import Foundation
import Combine
import Network

/// Service for syncing app settings across devices using NSUbiquitousKeyValueStore
/// This is Apple's recommended approach for syncing small amounts of data like preferences
class CloudKitSettingsSyncService: ObservableObject {

    // MARK: - Singleton
    static let shared = CloudKitSettingsSyncService()

    // MARK: - Published Properties
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: Error?
    @Published var lastSyncDate: Date?
    @Published var lastChangeDate: Date?
    @Published var isNetworkAvailable: Bool = true

    // MARK: - Private Properties
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let userDefaultsService = UserDefaultsService()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var localModificationDate: Date?
    private var isPerformingLocalSync = false
    private var lastNetworkStatusLogTime: Date?
    private var hasPerformedInitialSync = false
    private var lastSyncFromCloudTime: Date?
    private let syncFromCloudMinInterval: TimeInterval = 10.0 // Minimum 10 seconds between syncs

    // UserDefaults key for tracking local modifications
    private let localModificationDateKey = "localSettingsModificationDate"

    // Keys for iCloud KVS
    private enum CloudKeys {
        static let defaultCaptainName = "cloud_defaultCaptainName"
        static let defaultCoPilotName = "cloud_defaultCoPilotName"
        static let defaultSOName = "cloud_defaultSOName"
        static let savedSONames = "cloud_savedSONames"
        static let flightTimePosition = "cloud_flightTimePosition"
        static let includeLeadingZeroInFlightNumber = "cloud_includeLeadingZeroInFlightNumber"
        static let includeAirlinePrefixInFlightNumber = "cloud_includeAirlinePrefixInFlightNumber"
        static let airlinePrefix = "cloud_airlinePrefix"
        static let showFullAircraftReg = "cloud_showFullAircraftReg"
        static let savedCaptainNames = "cloud_savedCaptainNames"
        static let savedCoPilotNames = "cloud_savedCoPilotNames"
        static let savePhotosToLibrary = "cloud_savePhotosToLibrary"
        static let showSONameFields = "cloud_showSONameFields"
        static let pfAutoInstrumentMinutes = "cloud_pfAutoInstrumentMinutes"
        static let logbookDestination = "cloud_logbookDestination"
        static let displayFlightsInLocalTime = "cloud_displayFlightsInLocalTime"
        static let useIATACodes = "cloud_useIATACodes"
        static let showTimesInHoursMinutes = "cloud_showTimesInHoursMinutes"
        static let logApproaches = "cloud_logApproaches"
        static let defaultApproachType = "cloud_defaultApproachType"
        static let recentCaptainNames = "cloud_recentCaptainNames"
        static let recentCoPilotNames = "cloud_recentCoPilotNames"
        static let recentSONames = "cloud_recentSONames"
        static let recentAircraftRegs = "cloud_recentAircraftRegs"
        static let recentAirports = "cloud_recentAirports"
        static let selectedFleetID = "cloud_selectedFleetID"
        static let lastSyncTimestamp = "cloud_lastSyncTimestamp"

        // Backup settings
        static let backupIsEnabled = "cloud_backupIsEnabled"
        static let backupFrequency = "cloud_backupFrequency"
        static let backupLocation = "cloud_backupLocation"
        static let backupMaxToKeep = "cloud_backupMaxToKeep"

        // FRMS settings
        static let frmsShowFRMS = "cloud_frmsShowFRMS"
        static let frmsFleet = "cloud_frmsFleet"
        static let frmsHomeBase = "cloud_frmsHomeBase"
        static let frmsDefaultLimitType = "cloud_frmsDefaultLimitType"
        static let frmsShowWarningsAtPercentage = "cloud_frmsShowWarningsAtPercentage"
        static let frmsSignOnMinutesBeforeSTD = "cloud_frmsSignOnMinutesBeforeSTD"
        static let frmsSignOffMinutesAfterIN = "cloud_frmsSignOffMinutesAfterIN"
    }

    // MARK: - Initialization
    private init() {
        // Load last local modification date
        if let savedDate = UserDefaults.standard.object(forKey: localModificationDateKey) as? Date {
            localModificationDate = savedDate
        }

        setupNetworkMonitoring()
        setupCloudKitNotifications()

        // Only sync from cloud on initialization if network is available
        if isNetworkAvailable && isCloudAvailable() {
            performSmartSync()
            hasPerformedInitialSync = true
        } else {
            LogManager.shared.info("iCloud sync: Network or iCloud unavailable - skipping initial sync")
        }
    }

    // MARK: - Setup
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isNetworkAvailable = path.status == .satisfied

                // Rate limit network status logging (max once per 30 seconds)
                let now = Date()
                let shouldLog = self.lastNetworkStatusLogTime == nil ||
                    now.timeIntervalSince(self.lastNetworkStatusLogTime!) > 30.0

                if path.status == .satisfied {
                    if shouldLog {
                        LogManager.shared.debug("iCloud sync: Network connection available")
                        self.lastNetworkStatusLogTime = now
                    }
                    // Perform smart sync when network becomes available (but skip initial detection to avoid duplicate sync)
                    if self.isCloudAvailable() && self.hasPerformedInitialSync {
                        self.performSmartSync()
                    }
                    self.hasPerformedInitialSync = true
                } else {
                    if shouldLog {
                        LogManager.shared.warning("iCloud sync: Network connection unavailable")
                        self.lastNetworkStatusLogTime = now
                    }
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func setupCloudKitNotifications() {
        // Listen for changes from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudStoreChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )

        // Only synchronize if network and iCloud are available
        if isNetworkAvailable && isCloudAvailable() {
            ubiquitousStore.synchronize()
        }
    }

    // MARK: - Cloud Change Handling
    @objc private func handleCloudStoreChange(_ notification: Notification) {
        LogManager.shared.debug("iCloud sync: KVS change detected")

        // Ignore notifications triggered by our own local sync
        if isPerformingLocalSync {
            LogManager.shared.debug("iCloud sync: Ignoring change notification - performing local sync")
            return
        }

        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        DispatchQueue.main.async {
            switch changeReason {
            case NSUbiquitousKeyValueStoreServerChange:
                LogManager.shared.info("iCloud sync: Server change - syncing from cloud")
                self.syncFromCloud()

            case NSUbiquitousKeyValueStoreInitialSyncChange:
                LogManager.shared.info("iCloud sync: Initial sync - syncing from cloud")
                self.syncFromCloud()

            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                LogManager.shared.error("iCloud sync: KVS quota exceeded")
                self.lastSyncError = NSError(
                    domain: "CloudKitSettingsSyncService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "iCloud storage quota exceeded"]
                )

            case NSUbiquitousKeyValueStoreAccountChange:
                LogManager.shared.warning("iCloud sync: Account changed")
                self.syncFromCloud()

            default:
                LogManager.shared.warning("iCloud sync: Unknown change reason: \(changeReason)")
            }
        }
    }

    // MARK: - Sync Methods

    /// Intelligent sync that determines whether to upload or download based on modification dates
    private func performSmartSync() {
        guard isNetworkAvailable && isCloudAvailable() else {
            LogManager.shared.warning("iCloud sync: Cannot perform smart sync - network or iCloud unavailable")
            return
        }

        // Get cloud timestamp
        let cloudTimestamp = ubiquitousStore.object(forKey: CloudKeys.lastSyncTimestamp) as? Double

        if let localModDate = localModificationDate {
            // We have local changes
            if let cloudTime = cloudTimestamp {
                let cloudDate = Date(timeIntervalSince1970: cloudTime)

                // Compare timestamps
                if localModDate > cloudDate {
                    // Local changes are newer - upload to cloud
                    LogManager.shared.info("iCloud sync: Local changes are newer - syncing TO cloud")
                    syncToCloud()
                } else {
                    // Cloud changes are newer - download from cloud
                    LogManager.shared.info("iCloud sync: Cloud changes are newer - syncing FROM cloud")
                    syncFromCloud()
                }
            } else {
                // No cloud data - upload local settings
                LogManager.shared.info("iCloud sync: No cloud data found - syncing TO cloud")
                syncToCloud()
            }
        } else {
            // No local modifications tracked - download from cloud if available
            if cloudTimestamp != nil {
//                LogManager.shared.info("📥 No local modifications tracked - syncing FROM cloud")
                syncFromCloud()
            } else {
                LogManager.shared.debug("iCloud sync: No cloud or local data to sync")
            }
        }
    }

    /// Mark that settings have been modified locally
    func markLocalModification() {
        localModificationDate = Date()
        UserDefaults.standard.set(localModificationDate, forKey: localModificationDateKey)
//        LogManager.shared.info("📝 Local settings modification recorded at \(localModificationDate!)")
    }

    /// Upload current settings to iCloud
    func syncToCloud() {
        // Check if network and iCloud are available
        guard isNetworkAvailable else {
            LogManager.shared.warning("iCloud sync: Cannot sync - network unavailable")
            DispatchQueue.main.async {
                self.lastSyncError = NSError(
                    domain: "CloudKitSettingsSyncService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Network connection unavailable"]
                )
            }
            return
        }

        guard isCloudAvailable() else {
            LogManager.shared.warning("iCloud sync: Cannot sync - iCloud unavailable")
            DispatchQueue.main.async {
                self.lastSyncError = NSError(
                    domain: "CloudKitSettingsSyncService",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "iCloud unavailable"]
                )
            }
            return
        }

        isSyncing = true
        isPerformingLocalSync = true
        let settings = userDefaultsService.loadSettings()

        // Upload each setting to iCloud KVS
        ubiquitousStore.set(settings.defaultCaptainName, forKey: CloudKeys.defaultCaptainName)
        ubiquitousStore.set(settings.defaultCoPilotName, forKey: CloudKeys.defaultCoPilotName)
        ubiquitousStore.set(settings.defaultSOName, forKey: CloudKeys.defaultSOName)
        ubiquitousStore.set(settings.savedSONames, forKey: CloudKeys.savedSONames)
        ubiquitousStore.set(settings.flightTimePosition.rawValue, forKey: CloudKeys.flightTimePosition)
        ubiquitousStore.set(settings.includeLeadingZeroInFlightNumber, forKey: CloudKeys.includeLeadingZeroInFlightNumber)
        ubiquitousStore.set(settings.includeAirlinePrefixInFlightNumber, forKey: CloudKeys.includeAirlinePrefixInFlightNumber)
        ubiquitousStore.set(settings.airlinePrefix, forKey: CloudKeys.airlinePrefix)
        ubiquitousStore.set(settings.showFullAircraftReg, forKey: CloudKeys.showFullAircraftReg)
        ubiquitousStore.set(settings.savedCaptainNames, forKey: CloudKeys.savedCaptainNames)
        ubiquitousStore.set(settings.savedCoPilotNames, forKey: CloudKeys.savedCoPilotNames)
        ubiquitousStore.set(settings.savePhotosToLibrary, forKey: CloudKeys.savePhotosToLibrary)
        ubiquitousStore.set(settings.showSONameFields, forKey: CloudKeys.showSONameFields)
        ubiquitousStore.set(settings.pfAutoInstrumentMinutes, forKey: CloudKeys.pfAutoInstrumentMinutes)
        ubiquitousStore.set(settings.logbookDestination.rawValue, forKey: CloudKeys.logbookDestination)
        ubiquitousStore.set(settings.displayFlightsInLocalTime, forKey: CloudKeys.displayFlightsInLocalTime)
        ubiquitousStore.set(settings.useIATACodes, forKey: CloudKeys.useIATACodes)
        ubiquitousStore.set(settings.showTimesInHoursMinutes, forKey: CloudKeys.showTimesInHoursMinutes)
        ubiquitousStore.set(settings.logApproaches, forKey: CloudKeys.logApproaches)
        ubiquitousStore.set(settings.defaultApproachType, forKey: CloudKeys.defaultApproachType)
        ubiquitousStore.set(settings.recentCaptainNames, forKey: CloudKeys.recentCaptainNames)
        ubiquitousStore.set(settings.recentCoPilotNames, forKey: CloudKeys.recentCoPilotNames)
        ubiquitousStore.set(settings.recentSONames, forKey: CloudKeys.recentSONames)
        ubiquitousStore.set(settings.recentAircraftRegs, forKey: CloudKeys.recentAircraftRegs)
        ubiquitousStore.set(settings.recentAirports, forKey: CloudKeys.recentAirports)
        ubiquitousStore.set(settings.selectedFleetID, forKey: CloudKeys.selectedFleetID)

        // Backup settings
        let backupSettings = AutomaticBackupService.shared.settings
        ubiquitousStore.set(backupSettings.isEnabled, forKey: CloudKeys.backupIsEnabled)
        ubiquitousStore.set(backupSettings.frequency.rawValue, forKey: CloudKeys.backupFrequency)
        ubiquitousStore.set(backupSettings.location.rawValue, forKey: CloudKeys.backupLocation)
        ubiquitousStore.set(backupSettings.maxBackupsToKeep, forKey: CloudKeys.backupMaxToKeep)

        // FRMS settings
        if let frmsConfigData = UserDefaults.standard.data(forKey: "FRMSConfiguration"),
           let frmsConfig = try? JSONDecoder().decode(FRMSConfiguration.self, from: frmsConfigData) {
            ubiquitousStore.set(frmsConfig.showFRMS, forKey: CloudKeys.frmsShowFRMS)
            ubiquitousStore.set(frmsConfig.fleet.rawValue, forKey: CloudKeys.frmsFleet)
            ubiquitousStore.set(frmsConfig.homeBase, forKey: CloudKeys.frmsHomeBase)
            ubiquitousStore.set(frmsConfig.defaultLimitType.rawValue, forKey: CloudKeys.frmsDefaultLimitType)
            ubiquitousStore.set(frmsConfig.showWarningsAtPercentage, forKey: CloudKeys.frmsShowWarningsAtPercentage)
            ubiquitousStore.set(frmsConfig.signOnMinutesBeforeSTD, forKey: CloudKeys.frmsSignOnMinutesBeforeSTD)
            ubiquitousStore.set(frmsConfig.signOffMinutesAfterIN, forKey: CloudKeys.frmsSignOffMinutesAfterIN)
        }

        ubiquitousStore.set(Date().timeIntervalSince1970, forKey: CloudKeys.lastSyncTimestamp)

        // Force synchronization
        let success = ubiquitousStore.synchronize()

        DispatchQueue.main.async {
            self.isSyncing = false
            if success {
                let now = Date()
                self.lastSyncDate = now
                self.lastChangeDate = now
                self.lastSyncError = nil

                // Clear local modification timestamp since we successfully synced to cloud
                self.localModificationDate = nil
                UserDefaults.standard.removeObject(forKey: self.localModificationDateKey)

                LogManager.shared.info("iCloud sync: Settings synced TO cloud successfully")
            } else {
                self.lastSyncError = NSError(
                    domain: "CloudKitSettingsSyncService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to sync settings to iCloud"]
                )
                LogManager.shared.error("iCloud sync: Failed to sync settings TO cloud")
            }

            // Reset the flag after a short delay to ensure any notifications are processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isPerformingLocalSync = false
            }
        }
    }

    /// Download settings from iCloud
    func syncFromCloud() {
        // Rate limit: Skip if we've synced too recently (prevents excessive syncing)
        let now = Date()
        if let lastTime = lastSyncFromCloudTime,
           now.timeIntervalSince(lastTime) < syncFromCloudMinInterval {
            // Skip silently - synced too recently
            return
        }

        // Check if network and iCloud are available
        guard isNetworkAvailable else {
            LogManager.shared.warning("iCloud sync: Cannot sync FROM cloud - network unavailable")
            return
        }

        guard isCloudAvailable() else {
            LogManager.shared.warning("iCloud sync: Cannot sync FROM cloud - iCloud unavailable")
            return
        }

        // Update last sync time
        lastSyncFromCloudTime = now
        isSyncing = true

        // Check if cloud has data
        guard let cloudTimestamp = ubiquitousStore.object(forKey: CloudKeys.lastSyncTimestamp) as? Double else {
            LogManager.shared.debug("iCloud sync: No cloud settings found - using local settings")
            isSyncing = false
            return
        }

        // Load current local settings
        let localSettings = userDefaultsService.loadSettings()
        var settings = localSettings

        // Track which settings actually changed
        var changedKeys = Set<String>()

        // Update settings from cloud and track changes
        if let defaultCaptainName = ubiquitousStore.string(forKey: CloudKeys.defaultCaptainName),
           defaultCaptainName != localSettings.defaultCaptainName {
            settings.defaultCaptainName = defaultCaptainName
            changedKeys.insert("defaultCaptainName")
        }
        if let defaultCoPilotName = ubiquitousStore.string(forKey: CloudKeys.defaultCoPilotName),
           defaultCoPilotName != localSettings.defaultCoPilotName {
            settings.defaultCoPilotName = defaultCoPilotName
            changedKeys.insert("defaultCoPilotName")
        }
        if let defaultSOName = ubiquitousStore.string(forKey: CloudKeys.defaultSOName),
           defaultSOName != localSettings.defaultSOName {
            settings.defaultSOName = defaultSOName
            changedKeys.insert("defaultSOName")
        }
        if let savedSONames = ubiquitousStore.array(forKey: CloudKeys.savedSONames) as? [String],
           savedSONames != localSettings.savedSONames {
            settings.savedSONames = savedSONames
            changedKeys.insert("savedSONames")
        }
        if let flightTimePositionRaw = ubiquitousStore.string(forKey: CloudKeys.flightTimePosition),
           let flightTimePosition = FlightTimePosition(rawValue: flightTimePositionRaw),
           flightTimePosition != localSettings.flightTimePosition {
            settings.flightTimePosition = flightTimePosition
            changedKeys.insert("flightTimePosition")
        }
        if let includeLeadingZero = ubiquitousStore.object(forKey: CloudKeys.includeLeadingZeroInFlightNumber) as? Bool,
           includeLeadingZero != localSettings.includeLeadingZeroInFlightNumber {
            settings.includeLeadingZeroInFlightNumber = includeLeadingZero
            changedKeys.insert("includeLeadingZeroInFlightNumber")
        }
        if let includeAirlinePrefix = ubiquitousStore.object(forKey: CloudKeys.includeAirlinePrefixInFlightNumber) as? Bool,
           includeAirlinePrefix != localSettings.includeAirlinePrefixInFlightNumber {
            settings.includeAirlinePrefixInFlightNumber = includeAirlinePrefix
            changedKeys.insert("includeAirlinePrefixInFlightNumber")
        }
        if let airlinePrefix = ubiquitousStore.string(forKey: CloudKeys.airlinePrefix),
           airlinePrefix != localSettings.airlinePrefix {
            settings.airlinePrefix = airlinePrefix
            changedKeys.insert("airlinePrefix")
        }
        if let showFullReg = ubiquitousStore.object(forKey: CloudKeys.showFullAircraftReg) as? Bool,
           showFullReg != localSettings.showFullAircraftReg {
            settings.showFullAircraftReg = showFullReg
            changedKeys.insert("showFullAircraftReg")
        }
        if let savedCaptainNames = ubiquitousStore.array(forKey: CloudKeys.savedCaptainNames) as? [String],
           savedCaptainNames != localSettings.savedCaptainNames {
            settings.savedCaptainNames = savedCaptainNames
            changedKeys.insert("savedCaptainNames")
        }
        if let savedCoPilotNames = ubiquitousStore.array(forKey: CloudKeys.savedCoPilotNames) as? [String],
           savedCoPilotNames != localSettings.savedCoPilotNames {
            settings.savedCoPilotNames = savedCoPilotNames
            changedKeys.insert("savedCoPilotNames")
        }
        if let savePhotos = ubiquitousStore.object(forKey: CloudKeys.savePhotosToLibrary) as? Bool,
           savePhotos != localSettings.savePhotosToLibrary {
            settings.savePhotosToLibrary = savePhotos
            changedKeys.insert("savePhotosToLibrary")
        }
        if let showSOFields = ubiquitousStore.object(forKey: CloudKeys.showSONameFields) as? Bool,
           showSOFields != localSettings.showSONameFields {
            settings.showSONameFields = showSOFields
            changedKeys.insert("showSONameFields")
        }
        if let pfAutoInstrument = ubiquitousStore.object(forKey: CloudKeys.pfAutoInstrumentMinutes) as? Int,
           pfAutoInstrument != localSettings.pfAutoInstrumentMinutes {
            settings.pfAutoInstrumentMinutes = pfAutoInstrument
            changedKeys.insert("pfAutoInstrumentMinutes")
        }
        if let logbookDestRaw = ubiquitousStore.string(forKey: CloudKeys.logbookDestination),
           let logbookDest = LogbookDestination(rawValue: logbookDestRaw),
           logbookDest != localSettings.logbookDestination {
            settings.logbookDestination = logbookDest
            changedKeys.insert("logbookDestination")
        }
        if let displayLocalTime = ubiquitousStore.object(forKey: CloudKeys.displayFlightsInLocalTime) as? Bool,
           displayLocalTime != localSettings.displayFlightsInLocalTime {
            settings.displayFlightsInLocalTime = displayLocalTime
            changedKeys.insert("displayFlightsInLocalTime")
        }
        if let useIATA = ubiquitousStore.object(forKey: CloudKeys.useIATACodes) as? Bool,
           useIATA != localSettings.useIATACodes {
            settings.useIATACodes = useIATA
            changedKeys.insert("useIATACodes")
        }
        if let showHHMM = ubiquitousStore.object(forKey: CloudKeys.showTimesInHoursMinutes) as? Bool,
           showHHMM != localSettings.showTimesInHoursMinutes {
            settings.showTimesInHoursMinutes = showHHMM
            changedKeys.insert("showTimesInHoursMinutes")
        }
        if let logApproaches = ubiquitousStore.object(forKey: CloudKeys.logApproaches) as? Bool,
           logApproaches != localSettings.logApproaches {
            settings.logApproaches = logApproaches
            changedKeys.insert("logApproaches")
        }
        if let defaultApproach = ubiquitousStore.string(forKey: CloudKeys.defaultApproachType),
           defaultApproach != (localSettings.defaultApproachType ?? "") {
            settings.defaultApproachType = defaultApproach
            changedKeys.insert("defaultApproachType")
        }
        if let recentCaptains = ubiquitousStore.array(forKey: CloudKeys.recentCaptainNames) as? [String],
           recentCaptains != localSettings.recentCaptainNames {
            settings.recentCaptainNames = recentCaptains
            changedKeys.insert("recentCaptainNames")
        }
        if let recentCoPilots = ubiquitousStore.array(forKey: CloudKeys.recentCoPilotNames) as? [String],
           recentCoPilots != localSettings.recentCoPilotNames {
            settings.recentCoPilotNames = recentCoPilots
            changedKeys.insert("recentCoPilotNames")
        }
        if let recentSOs = ubiquitousStore.array(forKey: CloudKeys.recentSONames) as? [String],
           recentSOs != localSettings.recentSONames {
            settings.recentSONames = recentSOs
            changedKeys.insert("recentSONames")
        }
        if let recentRegs = ubiquitousStore.array(forKey: CloudKeys.recentAircraftRegs) as? [String],
           recentRegs != localSettings.recentAircraftRegs {
            settings.recentAircraftRegs = recentRegs
            changedKeys.insert("recentAircraftRegs")
        }
        if let recentAirports = ubiquitousStore.array(forKey: CloudKeys.recentAirports) as? [String],
           recentAirports != localSettings.recentAirports {
            settings.recentAirports = recentAirports
            changedKeys.insert("recentAirports")
        }
        if let selectedFleetID = ubiquitousStore.string(forKey: CloudKeys.selectedFleetID),
           selectedFleetID != localSettings.selectedFleetID {
            settings.selectedFleetID = selectedFleetID
            changedKeys.insert("selectedFleetID")
        }

        // Backup settings
        let localBackupSettings = AutomaticBackupService.shared.settings
        var backupSettingsChanged = false
        var updatedBackupSettings = localBackupSettings

        if let backupEnabled = ubiquitousStore.object(forKey: CloudKeys.backupIsEnabled) as? Bool,
           backupEnabled != localBackupSettings.isEnabled {
            updatedBackupSettings.isEnabled = backupEnabled
            backupSettingsChanged = true
            changedKeys.insert("backupIsEnabled")
        }
        if let backupFrequencyRaw = ubiquitousStore.string(forKey: CloudKeys.backupFrequency),
           let backupFrequency = BackupFrequency(rawValue: backupFrequencyRaw),
           backupFrequency != localBackupSettings.frequency {
            updatedBackupSettings.frequency = backupFrequency
            backupSettingsChanged = true
            changedKeys.insert("backupFrequency")
        }
        if let backupLocationRaw = ubiquitousStore.string(forKey: CloudKeys.backupLocation),
           let backupLocation = BackupLocation(rawValue: backupLocationRaw),
           backupLocation != localBackupSettings.location {
            updatedBackupSettings.location = backupLocation
            backupSettingsChanged = true
            changedKeys.insert("backupLocation")
        }
        if let backupMaxToKeep = ubiquitousStore.object(forKey: CloudKeys.backupMaxToKeep) as? Int,
           backupMaxToKeep != localBackupSettings.maxBackupsToKeep {
            updatedBackupSettings.maxBackupsToKeep = backupMaxToKeep
            backupSettingsChanged = true
            changedKeys.insert("backupMaxToKeep")
        }

        // Update backup settings if they changed
        if backupSettingsChanged {
            AutomaticBackupService.shared.updateSettings(updatedBackupSettings, syncToCloud: false)
        }

        // FRMS settings
        var frmsSettingsChanged = false
        if let frmsConfigData = UserDefaults.standard.data(forKey: "FRMSConfiguration"),
           var frmsConfig = try? JSONDecoder().decode(FRMSConfiguration.self, from: frmsConfigData) {

            if let showFRMS = ubiquitousStore.object(forKey: CloudKeys.frmsShowFRMS) as? Bool,
               showFRMS != frmsConfig.showFRMS {
                frmsConfig.showFRMS = showFRMS
                frmsSettingsChanged = true
                changedKeys.insert("frmsShowFRMS")
            }
            if let fleetRaw = ubiquitousStore.string(forKey: CloudKeys.frmsFleet),
               let fleet = FRMSFleet(rawValue: fleetRaw),
               fleet != frmsConfig.fleet {
                frmsConfig.fleet = fleet
                frmsSettingsChanged = true
                changedKeys.insert("frmsFleet")
            }
            if let homeBase = ubiquitousStore.string(forKey: CloudKeys.frmsHomeBase),
               homeBase != frmsConfig.homeBase {
                frmsConfig.homeBase = homeBase
                frmsSettingsChanged = true
                changedKeys.insert("frmsHomeBase")
            }
            if let limitTypeRaw = ubiquitousStore.string(forKey: CloudKeys.frmsDefaultLimitType),
               let limitType = FRMSLimitType(rawValue: limitTypeRaw),
               limitType != frmsConfig.defaultLimitType {
                frmsConfig.defaultLimitType = limitType
                frmsSettingsChanged = true
                changedKeys.insert("frmsDefaultLimitType")
            }
            if let warningPct = ubiquitousStore.object(forKey: CloudKeys.frmsShowWarningsAtPercentage) as? Double,
               warningPct != frmsConfig.showWarningsAtPercentage {
                frmsConfig.showWarningsAtPercentage = warningPct
                frmsSettingsChanged = true
                changedKeys.insert("frmsShowWarningsAtPercentage")
            }
            if let signOnMins = ubiquitousStore.object(forKey: CloudKeys.frmsSignOnMinutesBeforeSTD) as? Int,
               signOnMins != frmsConfig.signOnMinutesBeforeSTD {
                frmsConfig.signOnMinutesBeforeSTD = signOnMins
                frmsSettingsChanged = true
                changedKeys.insert("frmsSignOnMinutesBeforeSTD")
            }
            if let signOffMins = ubiquitousStore.object(forKey: CloudKeys.frmsSignOffMinutesAfterIN) as? Int,
               signOffMins != frmsConfig.signOffMinutesAfterIN {
                frmsConfig.signOffMinutesAfterIN = signOffMins
                frmsSettingsChanged = true
                changedKeys.insert("frmsSignOffMinutesAfterIN")
            }

            // Save FRMS config if it changed
            if frmsSettingsChanged {
                if let encoded = try? JSONEncoder().encode(frmsConfig) {
                    UserDefaults.standard.set(encoded, forKey: "FRMSConfiguration")
                }
            }
        }

        // Only save and notify if something actually changed
        guard !changedKeys.isEmpty else {
            // No changes - exit silently (no need to log every time nothing changes)
            DispatchQueue.main.async {
                self.isSyncing = false
                self.lastSyncDate = Date()
                if let timestamp = self.ubiquitousStore.object(forKey: CloudKeys.lastSyncTimestamp) as? Double {
                    self.lastChangeDate = Date(timeIntervalSince1970: timestamp)
                }
            }
            return
        }

        // Save to UserDefaults without triggering cloud sync (to avoid loop)
        userDefaultsService.saveSettings(settings, syncToCloud: false)

        DispatchQueue.main.async {
            self.isSyncing = false
            self.lastSyncDate = Date()
            self.lastChangeDate = Date(timeIntervalSince1970: cloudTimestamp)
            self.lastSyncError = nil

            // Clear local modification timestamp since we just synced from cloud
            self.localModificationDate = nil
            UserDefaults.standard.removeObject(forKey: self.localModificationDateKey)

            LogManager.shared.debug("iCloud sync: Settings synced FROM cloud - \(changedKeys.count) setting(s) changed: \(changedKeys.sorted().joined(separator: ", "))")

            // Notify the app that settings have changed - include which keys changed
            NotificationCenter.default.post(
                name: .settingsDidChange,
                object: nil,
                userInfo: ["changedKeys": Array(changedKeys)]
            )
        }
    }

    /// Check if iCloud is available
    func isCloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        networkMonitor.cancel()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}
