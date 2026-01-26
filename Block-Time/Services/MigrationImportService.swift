//
//  MigrationImportService.swift
//  Block-Time
//
//  Migration service for importing complete app data
//  Imports: Flights, Aircraft, Settings, and Preferences from .blocktime file
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Migration Data Structures (Matching Export Format)

/// Complete migration package containing all app data
struct MigrationPackage: Codable {
    let version: String
    let exportDate: Date
    let appVersion: String
    let metadata: MigrationMetadata
    let flights: [MigrationFlight]
    let aircraft: [MigrationAircraft]
    let settings: MigrationSettings
    let preferences: MigrationPreferences
}

/// Metadata about the migration export
struct MigrationMetadata: Codable {
    let flightCount: Int
    let aircraftCount: Int
    let exportedBy: String // "Logger"
    let migrationFormatVersion: String // "1.0"
}

/// Flight record optimized for migration
struct MigrationFlight: Codable {
    let id: String // UUID as string
    let date: String
    let flightNumber: String
    let aircraftReg: String
    let aircraftType: String
    let fromAirport: String
    let toAirport: String
    let captainName: String
    let foName: String
    let so1Name: String?
    let so2Name: String?
    let blockTime: String
    let nightTime: String
    let p1Time: String
    let p1usTime: String
    let p2Time: String
    let instrumentTime: String
    let simTime: String
    let isPilotFlying: Bool
    let isPositioning: Bool
    let isAIII: Bool
    let isRNP: Bool
    let isILS: Bool
    let isGLS: Bool
    let isNPA: Bool
    let remarks: String
    let dayTakeoffs: Int
    let dayLandings: Int
    let nightTakeoffs: Int
    let nightLandings: Int
    let outTime: String
    let inTime: String
    let scheduledDeparture: String
    let scheduledArrival: String
    let createdAt: Date?
    let modifiedAt: Date?
}

/// Aircraft record for migration
struct MigrationAircraft: Codable {
    let id: String
    let registration: String
    let fullRegistration: String
    let type: String
    let createdAt: Date?
}

/// All iCloud synced settings
struct MigrationSettings: Codable {
    let defaultCaptainName: String?
    let defaultCoPilotName: String?
    let defaultSOName: String?
    let savedSONames: [String]?
    let flightTimePosition: String?
    let includeLeadingZeroInFlightNumber: Bool?
    let includeAirlinePrefixInFlightNumber: Bool?
    let airlinePrefix: String?
    let showFullAircraftReg: Bool?
    let savedCaptainNames: [String]?
    let savedCoPilotNames: [String]?
    let savePhotosToLibrary: Bool?
    let showSONameFields: Bool?
    let pfAutoInstrumentMinutes: Int?
    let logbookDestination: String?
    let displayFlightsInLocalTime: Bool?
    let useIATACodes: Bool?
    let showTimesInHoursMinutes: Bool?
    let logApproaches: Bool?
    let defaultApproachType: String?
    let recentCaptainNames: [String]?
    let recentCoPilotNames: [String]?
    let recentSONames: [String]?
    let recentAircraftRegs: [String]?
    let recentAirports: [String]?
    let selectedFleetID: String?

    // Backup settings
    let backupIsEnabled: Bool?
    let backupFrequency: String?
    let backupLocation: String?
    let backupMaxToKeep: Int?

    // FRMS settings
    let frmsShowFRMS: Bool?
    let frmsFleet: String?
    let frmsHomeBase: String?
    let frmsDefaultLimitType: String?
    let frmsShowWarningsAtPercentage: Int?
    let frmsSignOnMinutesBeforeSTD: Int?
    let frmsSignOffMinutesAfterIN: Int?
}

/// Local UserDefaults preferences
struct MigrationPreferences: Codable {
    let aircraftReg: String?
    let aircraftType: String?
    let captainName: String?
    let coPilotName: String?
    let decimalRoundingMode: String?
}

// MARK: - Migration Import Result

enum MigrationImportResult {
    case success(ImportSummary)
    case failure(Error)
}

struct ImportSummary {
    let flightsImported: Int
    let aircraftImported: Int
    let settingsRestored: Bool
    let preferencesRestored: Bool
    let importDate: Date
    let sourceApp: String
}

enum MigrationImportError: LocalizedError {
    case invalidFileFormat
    case fileAccessDenied
    case jsonDecodingFailed(Error)
    case coreDataError(Error)
    case incompatibleVersion
    case noData
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidFileFormat:
            return "Invalid migration file format. Please ensure you're importing a .blocktime file exported from Logger."
        case .fileAccessDenied:
            return "Unable to access the migration file. Please check file permissions."
        case .jsonDecodingFailed(let error):
            return "Failed to read migration data: \(error.localizedDescription)"
        case .coreDataError(let error):
            return "Database error: \(error.localizedDescription)"
        case .incompatibleVersion:
            return "This migration file format is not compatible with this version of Block-Time."
        case .noData:
            return "The migration file contains no data to import."
        case .unknown(let error):
            return "Migration import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Migration Import Progress

struct MigrationProgress {
    let phase: MigrationPhase
    let currentItem: Int
    let totalItems: Int
    let message: String

    var percentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(currentItem) / Double(totalItems)
    }
}

enum MigrationPhase: String {
    case reading = "Reading migration file"
    case validating = "Validating data"
    case importingFlights = "Importing flights"
    case importingAircraft = "Importing aircraft"
    case restoringSettings = "Restoring settings"
    case restoringPreferences = "Restoring preferences"
    case finalizing = "Finalizing migration"
    case complete = "Migration complete"
}

// MARK: - Migration Import Service

class MigrationImportService {

    static let shared = MigrationImportService()

    private init() {}

    // Progress callback (closure-based, works with SwiftUI structs)
    var progressCallback: ((MigrationProgress) -> Void)?

    private let databaseService = FlightDatabaseService.shared
    private let cloudSettingsService = CloudKitSettingsSyncService.shared

    // MARK: - Date Formatter
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // MARK: - Main Import Function

    /// Imports all app data from a .blocktime migration file
    func importFromMigration(fileURL: URL, replaceExisting: Bool = false, completion: @escaping (MigrationImportResult) -> Void) {
        Task {
            do {
                // PHASE 1: Read file
                updateProgress(.reading, current: 0, total: 1, message: "Opening migration file...")

                let migrationPackage = try await readMigrationFile(url: fileURL)

                // PHASE 2: Validate
                updateProgress(.validating, current: 0, total: 1, message: "Validating migration data...")

                try validateMigrationPackage(migrationPackage)

                // PHASE 3: Clear existing data if requested
                if replaceExisting {
                    updateProgress(.validating, current: 0, total: 1, message: "Clearing existing data...")
                    try await clearExistingData()
                }

                // PHASE 4: Import Flights
                updateProgress(.importingFlights, current: 0, total: migrationPackage.flights.count, message: "Preparing to import flights...")

                let flightsImported = try await importFlights(migrationPackage.flights)

                // PHASE 5: Import Aircraft
                updateProgress(.importingAircraft, current: 0, total: migrationPackage.aircraft.count, message: "Preparing to import aircraft...")

                let aircraftImported = try await importAircraft(migrationPackage.aircraft)

                // PHASE 6: Restore Settings
                updateProgress(.restoringSettings, current: 0, total: 1, message: "Restoring your settings...")

                let settingsRestored = await restoreSettings(migrationPackage.settings)

                // PHASE 7: Restore Preferences
                updateProgress(.restoringPreferences, current: 0, total: 1, message: "Restoring preferences...")

                let preferencesRestored = restorePreferences(migrationPackage.preferences)

                // PHASE 8: Finalize
                updateProgress(.finalizing, current: 0, total: 1, message: "Finalizing migration...")

                try await finalizeMigration()

                // PHASE 9: Complete
                updateProgress(.complete, current: 1, total: 1, message: "Migration complete!")

                let summary = ImportSummary(
                    flightsImported: flightsImported,
                    aircraftImported: aircraftImported,
                    settingsRestored: settingsRestored,
                    preferencesRestored: preferencesRestored,
                    importDate: Date(),
                    sourceApp: migrationPackage.metadata.exportedBy
                )

                await MainActor.run {
                    completion(.success(summary))
                }

                LogManager.shared.info("✅ Migration completed successfully: \(flightsImported) flights, \(aircraftImported) aircraft")

            } catch {
                LogManager.shared.error("❌ Migration failed: \(error.localizedDescription)")
                await MainActor.run {
                    if let migrationError = error as? MigrationImportError {
                        completion(.failure(migrationError))
                    } else {
                        completion(.failure(MigrationImportError.unknown(error)))
                    }
                }
            }
        }
    }

    // MARK: - File Reading

    private func readMigrationFile(url: URL) async throws -> MigrationPackage {
        // Check if file needs security-scoped access
        let needsSecurityScopedAccess = !isInAppContainer(url)

        if needsSecurityScopedAccess {
            guard url.startAccessingSecurityScopedResource() else {
                throw MigrationImportError.fileAccessDenied
            }
        }

        defer {
            if needsSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Read file data
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw MigrationImportError.fileAccessDenied
        }

        // Decode JSON with ISO8601 date strategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let package = try decoder.decode(MigrationPackage.self, from: data)
            return package
        } catch {
            LogManager.shared.error("JSON decoding error: \(error)")
            throw MigrationImportError.jsonDecodingFailed(error)
        }
    }

    /// Check if a file URL is in the app's own container
    private func isInAppContainer(_ url: URL) -> Bool {
        let path = url.path

        // Check if in app's temporary directory
        let tempDir = FileManager.default.temporaryDirectory.path
        if path.hasPrefix(tempDir) {
            return true
        }

        // Check if in app's local Documents directory
        if let appDocuments = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            if path.hasPrefix(appDocuments.path) {
                return true
            }
        }

        // Check if in app's iCloud container
        if path.contains("iCloud~com~thezoolab~blocktime") {
            return true
        }

        return false
    }

    // MARK: - Validation

    private func validateMigrationPackage(_ package: MigrationPackage) throws {
        // Check version compatibility
        guard package.metadata.migrationFormatVersion == "1.0" else {
            throw MigrationImportError.incompatibleVersion
        }

        // Check that we have at least some data
        if package.flights.isEmpty && package.aircraft.isEmpty {
            throw MigrationImportError.noData
        }

        // Validate metadata matches actual data (warnings only, not fatal)
        if package.flights.count != package.metadata.flightCount {
            LogManager.shared.warning("⚠️ Flight count mismatch: metadata says \(package.metadata.flightCount), found \(package.flights.count)")
        }

        if package.aircraft.count != package.metadata.aircraftCount {
            LogManager.shared.warning("⚠️ Aircraft count mismatch: metadata says \(package.metadata.aircraftCount), found \(package.aircraft.count)")
        }
    }

    // MARK: - Clear Existing Data

    private func clearExistingData() async throws {
        LogManager.shared.info("🗑️ Clearing existing data...")

        // Clear all flights
        _ = databaseService.clearAllFlights()

        // Clear custom aircraft (Core Data)
        let customAircraft = await MainActor.run {
            AircraftFleetService.shared.fetchCustomAircraft()
        }

        for aircraft in customAircraft {
            await MainActor.run {
                _ = AircraftFleetService.shared.deleteAircraft(aircraft)
            }
        }

        LogManager.shared.info("✅ Existing data cleared")
    }

    // MARK: - Import Flights

    private func importFlights(_ flights: [MigrationFlight]) async throws -> Int {
        guard !flights.isEmpty else { return 0 }

        LogManager.shared.info("📥 Importing \(flights.count) flights...")

        // Convert MigrationFlight objects to FlightSector objects
        let flightSectors: [FlightSector] = flights.enumerated().map { index, migrationFlight in
            // Update progress every 100 flights
            if index % 100 == 0 {
                updateProgress(.importingFlights, current: index, total: flights.count, message: "Processing flight \(index + 1) of \(flights.count)...")
            }

            // Create FlightSector with the preserved UUID
            let uuid = UUID(uuidString: migrationFlight.id) ?? UUID()

            return FlightSector(
                id: uuid,
                date: migrationFlight.date,
                flightNumber: migrationFlight.flightNumber,
                aircraftReg: migrationFlight.aircraftReg,
                aircraftType: migrationFlight.aircraftType,
                fromAirport: migrationFlight.fromAirport,
                toAirport: migrationFlight.toAirport,
                captainName: migrationFlight.captainName,
                foName: migrationFlight.foName,
                so1Name: migrationFlight.so1Name,
                so2Name: migrationFlight.so2Name,
                blockTime: migrationFlight.blockTime,
                nightTime: migrationFlight.nightTime,
                p1Time: migrationFlight.p1Time,
                p1usTime: migrationFlight.p1usTime,
                p2Time: migrationFlight.p2Time,
                instrumentTime: migrationFlight.instrumentTime,
                simTime: migrationFlight.simTime,
                isPilotFlying: migrationFlight.isPilotFlying,
                isPositioning: migrationFlight.isPositioning,
                isAIII: migrationFlight.isAIII,
                isRNP: migrationFlight.isRNP,
                isILS: migrationFlight.isILS,
                isGLS: migrationFlight.isGLS,
                isNPA: migrationFlight.isNPA,
                remarks: migrationFlight.remarks,
                dayTakeoffs: migrationFlight.dayTakeoffs,
                dayLandings: migrationFlight.dayLandings,
                nightTakeoffs: migrationFlight.nightTakeoffs,
                nightLandings: migrationFlight.nightLandings,
                outTime: migrationFlight.outTime,
                inTime: migrationFlight.inTime,
                scheduledDeparture: migrationFlight.scheduledDeparture,
                scheduledArrival: migrationFlight.scheduledArrival
            )
        }

        // Use the database service's batch save with duplicate detection
        let result = await MainActor.run {
            updateProgress(.importingFlights, current: flights.count, total: flights.count, message: "Saving flights to database...")
            return databaseService.saveFlightsBatch(flightSectors)
        }

        LogManager.shared.info("✅ Import complete: \(result.successCount) saved, \(result.duplicateCount) duplicates skipped, \(result.failureCount) failed")

        // Return successful count (not including duplicates)
        return result.successCount
    }

    // MARK: - Import Aircraft

    private func importAircraft(_ aircraft: [MigrationAircraft]) async throws -> Int {
        guard !aircraft.isEmpty else { return 0 }

        LogManager.shared.info("📥 Importing \(aircraft.count) aircraft...")

        let importedCount = await MainActor.run { () -> Int in
            var count = 0

            for (index, migrationAircraft) in aircraft.enumerated() {
                updateProgress(.importingAircraft, current: index, total: aircraft.count, message: "Importing aircraft \(index + 1) of \(aircraft.count)...")

                // Create Aircraft object from migration data
                let aircraftToSave = Aircraft(
                    registration: migrationAircraft.registration,
                    type: migrationAircraft.type
                )

                // Save to Core Data
                if AircraftFleetService.shared.saveAircraft(aircraftToSave) {
                    count += 1
                } else {
                    LogManager.shared.warning("⚠️ Failed to import aircraft: \(migrationAircraft.registration)")
                }
            }

            return count
        }

        LogManager.shared.info("✅ Imported \(importedCount) aircraft")
        return importedCount
    }

    // MARK: - Restore Settings

    private func restoreSettings(_ settings: MigrationSettings) async -> Bool {
        LogManager.shared.info("⚙️ Restoring settings to iCloud...")

        let ubiquitousStore = NSUbiquitousKeyValueStore.default

        // Restore all settings with "cloud_" prefix
        if let defaultCaptainName = settings.defaultCaptainName {
            ubiquitousStore.set(defaultCaptainName, forKey: "cloud_defaultCaptainName")
        }
        if let defaultCoPilotName = settings.defaultCoPilotName {
            ubiquitousStore.set(defaultCoPilotName, forKey: "cloud_defaultCoPilotName")
        }
        if let defaultSOName = settings.defaultSOName {
            ubiquitousStore.set(defaultSOName, forKey: "cloud_defaultSOName")
        }
        if let savedSONames = settings.savedSONames {
            ubiquitousStore.set(savedSONames, forKey: "cloud_savedSONames")
        }
        if let flightTimePosition = settings.flightTimePosition {
            ubiquitousStore.set(flightTimePosition, forKey: "cloud_flightTimePosition")
        }
        if let includeLeadingZero = settings.includeLeadingZeroInFlightNumber {
            ubiquitousStore.set(includeLeadingZero, forKey: "cloud_includeLeadingZeroInFlightNumber")
        }
        if let includeAirlinePrefix = settings.includeAirlinePrefixInFlightNumber {
            ubiquitousStore.set(includeAirlinePrefix, forKey: "cloud_includeAirlinePrefixInFlightNumber")
        }
        if let airlinePrefix = settings.airlinePrefix {
            ubiquitousStore.set(airlinePrefix, forKey: "cloud_airlinePrefix")
        }
        if let showFullReg = settings.showFullAircraftReg {
            ubiquitousStore.set(showFullReg, forKey: "cloud_showFullAircraftReg")
        }
        if let savedCaptainNames = settings.savedCaptainNames {
            ubiquitousStore.set(savedCaptainNames, forKey: "cloud_savedCaptainNames")
        }
        if let savedCoPilotNames = settings.savedCoPilotNames {
            ubiquitousStore.set(savedCoPilotNames, forKey: "cloud_savedCoPilotNames")
        }
        if let savePhotosToLibrary = settings.savePhotosToLibrary {
            ubiquitousStore.set(savePhotosToLibrary, forKey: "cloud_savePhotosToLibrary")
        }
        if let showSONameFields = settings.showSONameFields {
            ubiquitousStore.set(showSONameFields, forKey: "cloud_showSONameFields")
        }
        if let pfAutoInstrumentMinutes = settings.pfAutoInstrumentMinutes {
            ubiquitousStore.set(pfAutoInstrumentMinutes, forKey: "cloud_pfAutoInstrumentMinutes")
        }
        if let logbookDestination = settings.logbookDestination {
            ubiquitousStore.set(logbookDestination, forKey: "cloud_logbookDestination")
        }
        if let displayFlightsInLocalTime = settings.displayFlightsInLocalTime {
            ubiquitousStore.set(displayFlightsInLocalTime, forKey: "cloud_displayFlightsInLocalTime")
        }
        if let useIATACodes = settings.useIATACodes {
            ubiquitousStore.set(useIATACodes, forKey: "cloud_useIATACodes")
        }
        if let showTimesInHoursMinutes = settings.showTimesInHoursMinutes {
            ubiquitousStore.set(showTimesInHoursMinutes, forKey: "cloud_showTimesInHoursMinutes")
        }
        if let logApproaches = settings.logApproaches {
            ubiquitousStore.set(logApproaches, forKey: "cloud_logApproaches")
        }
        if let defaultApproachType = settings.defaultApproachType {
            ubiquitousStore.set(defaultApproachType, forKey: "cloud_defaultApproachType")
        }
        if let recentCaptainNames = settings.recentCaptainNames {
            ubiquitousStore.set(recentCaptainNames, forKey: "cloud_recentCaptainNames")
        }
        if let recentCoPilotNames = settings.recentCoPilotNames {
            ubiquitousStore.set(recentCoPilotNames, forKey: "cloud_recentCoPilotNames")
        }
        if let recentSONames = settings.recentSONames {
            ubiquitousStore.set(recentSONames, forKey: "cloud_recentSONames")
        }
        if let recentAircraftRegs = settings.recentAircraftRegs {
            ubiquitousStore.set(recentAircraftRegs, forKey: "cloud_recentAircraftRegs")
        }
        if let recentAirports = settings.recentAirports {
            ubiquitousStore.set(recentAirports, forKey: "cloud_recentAirports")
        }
        if let selectedFleetID = settings.selectedFleetID {
            ubiquitousStore.set(selectedFleetID, forKey: "cloud_selectedFleetID")
        }

        // Backup settings
        if let backupIsEnabled = settings.backupIsEnabled {
            ubiquitousStore.set(backupIsEnabled, forKey: "cloud_backupIsEnabled")
        }
        if let backupFrequency = settings.backupFrequency {
            ubiquitousStore.set(backupFrequency, forKey: "cloud_backupFrequency")
        }
        if let backupLocation = settings.backupLocation {
            ubiquitousStore.set(backupLocation, forKey: "cloud_backupLocation")
        }
        if let backupMaxToKeep = settings.backupMaxToKeep {
            ubiquitousStore.set(backupMaxToKeep, forKey: "cloud_backupMaxToKeep")
        }

        // FRMS settings
        if let frmsShowFRMS = settings.frmsShowFRMS {
            ubiquitousStore.set(frmsShowFRMS, forKey: "cloud_frmsShowFRMS")
        }
        if let frmsFleet = settings.frmsFleet {
            ubiquitousStore.set(frmsFleet, forKey: "cloud_frmsFleet")
        }
        if let frmsHomeBase = settings.frmsHomeBase {
            ubiquitousStore.set(frmsHomeBase, forKey: "cloud_frmsHomeBase")
        }
        if let frmsDefaultLimitType = settings.frmsDefaultLimitType {
            ubiquitousStore.set(frmsDefaultLimitType, forKey: "cloud_frmsDefaultLimitType")
        }
        if let frmsShowWarningsAtPercentage = settings.frmsShowWarningsAtPercentage {
            ubiquitousStore.set(frmsShowWarningsAtPercentage, forKey: "cloud_frmsShowWarningsAtPercentage")
        }
        if let frmsSignOnMinutesBeforeSTD = settings.frmsSignOnMinutesBeforeSTD {
            ubiquitousStore.set(frmsSignOnMinutesBeforeSTD, forKey: "cloud_frmsSignOnMinutesBeforeSTD")
        }
        if let frmsSignOffMinutesAfterIN = settings.frmsSignOffMinutesAfterIN {
            ubiquitousStore.set(frmsSignOffMinutesAfterIN, forKey: "cloud_frmsSignOffMinutesAfterIN")
        }

        // Add sync timestamp so CloudKitSettingsSyncService knows there's data
        ubiquitousStore.set(Date().timeIntervalSince1970, forKey: "cloud_lastSyncTimestamp")

        // Synchronize to iCloud
        let synced = ubiquitousStore.synchronize()

        if synced {
            LogManager.shared.info("✅ Settings synced to iCloud")
        } else {
            LogManager.shared.warning("⚠️ iCloud sync may have failed, settings saved locally")
        }

        return true
    }

    // MARK: - Restore Preferences

    private func restorePreferences(_ preferences: MigrationPreferences) -> Bool {
        LogManager.shared.info("⚙️ Restoring UserDefaults preferences...")

        let defaults = UserDefaults.standard

        if let aircraftReg = preferences.aircraftReg {
            defaults.set(aircraftReg, forKey: "aircraftReg")
        }
        if let aircraftType = preferences.aircraftType {
            defaults.set(aircraftType, forKey: "aircraftType")
        }
        if let captainName = preferences.captainName {
            defaults.set(captainName, forKey: "captainName")
        }
        if let coPilotName = preferences.coPilotName {
            defaults.set(coPilotName, forKey: "coPilotName")
        }
        if let decimalRoundingMode = preferences.decimalRoundingMode {
            defaults.set(decimalRoundingMode, forKey: "decimalRoundingMode")
        }

        LogManager.shared.info("✅ UserDefaults preferences restored")

        return true
    }

    // MARK: - Finalize Migration

    private func finalizeMigration() async throws {
        // Post notification that data has changed
        await MainActor.run {
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        }

        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: "loggerMigrationCompleted")
        UserDefaults.standard.set(Date(), forKey: "loggerMigrationDate")

        LogManager.shared.info("✅ Migration finalized")
        LogManager.shared.info("ℹ️  Settings are in iCloud and will sync when Settings screens are accessed")
    }

    // MARK: - Helper Functions

    /// Update progress and call callback
    private func updateProgress(_ phase: MigrationPhase, current: Int, total: Int, message: String) {
        let progress = MigrationProgress(
            phase: phase,
            currentItem: current,
            totalItems: total,
            message: message
        )

        DispatchQueue.main.async { [weak self] in
            self?.progressCallback?(progress)
        }
    }
}
