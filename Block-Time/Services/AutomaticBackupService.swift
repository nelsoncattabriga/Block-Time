//
//  AutomaticBackupService.swift
//  Block-Time
//
//  Created by Nelson on 13/10/2025.
//

import Foundation
import Combine
import UIKit

// MARK: - Backup Configuration
enum BackupFrequency: String, CaseIterable, Codable {
    case disabled = "Disabled"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var days: Int? {
        switch self {
        case .disabled: return nil
        case .daily: return 1
        case .weekly: return 7
        case .monthly: return 30
        }
    }
}

enum BackupLocation: String, CaseIterable, Codable {
    case appDocuments = "Local"
    case iCloudDrive = "iCloud"

    var displayName: String {
        switch self {
        case .appDocuments:
            if UIDevice.current.userInterfaceIdiom == .pad {
                return "On My iPad"
            } else if UIDevice.current.userInterfaceIdiom == .phone {
                return "My iPhone"
            } else {
                return rawValue // Fallback for other platforms
            }
        case .iCloudDrive:
            return "iCloud"
        }
    }
}

struct BackupSettings: Codable {
    var isEnabled: Bool
    var frequency: BackupFrequency
    var location: BackupLocation
    var maxBackupsToKeep: Int

    static let `default` = BackupSettings(
        isEnabled: false,
        frequency: .weekly,
        location: .appDocuments, // Default to Local
        maxBackupsToKeep: 10
    )
}

struct BackupFileInfo: Identifiable, Equatable {
    let id: String
    let url: URL
    let date: Date
    let size: Int64
    let flightCount: Int?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Automatic Backup Service
class AutomaticBackupService: ObservableObject {
    static let shared = AutomaticBackupService()

    // MARK: - Published Properties
    @Published var settings: BackupSettings
    @Published var isBackupInProgress: Bool = false
    @Published var lastBackupError: Error?
    @Published var availableBackups: [BackupFileInfo] = []

    // MARK: - Computed Properties
    /// The date of the most recent backup, derived from actual backup files
    var lastBackupDate: Date? {
        return availableBackups.first?.date
    }

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "automaticBackupSettings"
    private let fileManager = FileManager.default
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // Backup file naming
    private let backupFilePrefix = "Block-Time_Backup_"
    private let backupFileExtension = "csv"

    // MARK: - Initialization
    private init() {
        // Load saved settings
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(BackupSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }

        // Set up notification observers
        setupNotifications()

        // Load available backups (will check if backup is needed after loading)
        refreshAvailableBackups()
    }

    // MARK: - Setup
    private func setupNotifications() {
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // Listen for flight data changes (to trigger backup after significant changes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(flightDataChanged),
            name: .flightDataChanged,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        checkAndPerformBackupIfNeeded()
        refreshAvailableBackups()
    }

    @objc private func appWillResignActive() {
        // Cancel any ongoing backup when app goes to background
        if isBackupInProgress {
            endBackgroundTask()
        }
    }

    @objc private func flightDataChanged() {
        // Check if we should backup after data changes
        // (only if significant time has passed since last backup)
        if settings.isEnabled,
           let lastBackup = lastBackupDate,
           Date().timeIntervalSince(lastBackup) > 3600 { // At least 1 hour since last backup
            checkAndPerformBackupIfNeeded()
        }
    }

    // MARK: - Settings Management
    func updateSettings(_ newSettings: BackupSettings, syncToCloud: Bool = true) {
        let locationChanged = self.settings.location != newSettings.location

        self.settings = newSettings
        saveSettings()

        // Sync to cloud if requested
        if syncToCloud {
            CloudKitSettingsSyncService.shared.markLocalModification()
            CloudKitSettingsSyncService.shared.syncToCloud()
        }

        // Refresh available backups if location changed
        if locationChanged {
            refreshAvailableBackups()
        }

        // Trigger backup if enabled and needed
        if newSettings.isEnabled {
            checkAndPerformBackupIfNeeded()
        }
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }

    // MARK: - Backup Logic
    func checkAndPerformBackupIfNeeded() {
        guard settings.isEnabled else { return }
        guard !isBackupInProgress else { return }

        // Check if backup is due based on frequency
        if let lastBackup = lastBackupDate {
            let calendar = Calendar.current
            let now = Date()

            switch settings.frequency {
            case .disabled:
                return

            case .daily:
                // Check if last backup was on a different day
                if calendar.isDate(lastBackup, inSameDayAs: now) {
                    return // Already backed up today
                }

            case .weekly:
                // Check if last backup was in a different week
                let lastBackupWeek = calendar.component(.weekOfYear, from: lastBackup)
                let currentWeek = calendar.component(.weekOfYear, from: now)
                let lastBackupYear = calendar.component(.year, from: lastBackup)
                let currentYear = calendar.component(.year, from: now)

                if lastBackupYear == currentYear && lastBackupWeek == currentWeek {
                    return // Already backed up this week
                }

            case .monthly:
                // Check if last backup was in a different month
                let lastBackupMonth = calendar.component(.month, from: lastBackup)
                let currentMonth = calendar.component(.month, from: now)
                let lastBackupYear = calendar.component(.year, from: lastBackup)
                let currentYear = calendar.component(.year, from: now)

                if lastBackupYear == currentYear && lastBackupMonth == currentMonth {
                    return // Already backed up this month
                }
            }
        }

        // Perform backup
        performAutomaticBackup()
    }

    func performManualBackup(completion: ((Result<URL, Error>) -> Void)? = nil) {
        performBackup(isManual: true, completion: completion)
    }

    private func performAutomaticBackup() {
        performBackup(isManual: false)
    }

    private func performBackup(isManual: Bool, completion: ((Result<URL, Error>) -> Void)? = nil) {
        guard !isBackupInProgress else {
            completion?(.failure(BackupError.backupInProgress))
            return
        }

        // Start background task to complete backup even if app is backgrounded
        beginBackgroundTask()

        DispatchQueue.main.async {
            self.isBackupInProgress = true
            self.lastBackupError = nil
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            do {
                // Get all flights
                let flights = FlightDatabaseService.shared.fetchAllFlights()

                if flights.isEmpty {
                    throw BackupError.noDataToBackup
                }

                // Sort by date (oldest first)
                let sortedFlights = flights.sorted { flight1, flight2 in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd/MM/yyyy"
                    if let date1 = formatter.date(from: flight1.date),
                       let date2 = formatter.date(from: flight2.date) {
                        return date1 < date2
                    }
                    return flight1.date < flight2.date
                }

                // Generate CSV
                let csvString = FileImportService.shared.exportToCSV(flights: sortedFlights)

                // Create backup file
                let backupURL = try self.createBackupFile(csvString: csvString, flightCount: flights.count)

                // Clean up old backups
                try self.cleanupOldBackups()

                // Update state
                DispatchQueue.main.async {
                    self.isBackupInProgress = false
                    self.refreshAvailableBackups()

                    LogManager.shared.info("Automatic backup completed: \(backupURL.lastPathComponent)")
                    completion?(.success(backupURL))
                }

            } catch {
                DispatchQueue.main.async {
                    self.lastBackupError = error
                    self.isBackupInProgress = false
                    LogManager.shared.info("Automatic backup failed: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }

            self.endBackgroundTask()
        }
    }

    // MARK: - File Management
    private func getBackupDirectory() throws -> URL {
        let baseURL: URL

        switch settings.location {
        case .appDocuments:
            baseURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

        case .iCloudDrive:
            // Use iCloud container
            guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
                LogManager.shared.info("iCloud Drive is not available")
                throw BackupError.iCloudNotAvailable
            }
            baseURL = iCloudURL
        }

        // Create "BlockTime/Backups" subdirectory
        let loggerDir = baseURL//.appendingPathComponent("Block-Time", isDirectory: true)
        let backupDir = loggerDir.appendingPathComponent("Backups", isDirectory: true)


        if !fileManager.fileExists(atPath: backupDir.path) {
            try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
            LogManager.shared.info("Created backup directory")
        }
        // Directory exists - no need to log

        return backupDir
    }


    private func createBackupFile(csvString: String, flightCount: Int) throws -> URL {
        let backupDir = try getBackupDirectory()

        // Create filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "\(backupFilePrefix)\(timestamp)_\(flightCount)flights.\(backupFileExtension)"

        let fileURL = backupDir.appendingPathComponent(filename)

        LogManager.shared.info("💾 Writing backup file to: \(fileURL.path)")

        // Write file
        try csvString.write(to: fileURL, atomically: true, encoding: .utf8)

        LogManager.shared.info("Backup file written successfully")
        LogManager.shared.info("File size: \(csvString.count) characters")

        // Verify file exists
        if fileManager.fileExists(atPath: fileURL.path) {
            LogManager.shared.debug("File verified to exist at path")
        } else {
            LogManager.shared.debug("File does not exist after writing!")
        }

        return fileURL
    }

    func refreshAvailableBackups() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            do {
                let backupDir = try self.getBackupDirectory()
                let contents = try self.fileManager.contentsOfDirectory(
                    at: backupDir,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                    options: .skipsHiddenFiles
                )

                let backups = contents
                    .filter { $0.lastPathComponent.hasPrefix(self.backupFilePrefix) }
                    .compactMap { url -> BackupFileInfo? in
                        guard let attributes = try? self.fileManager.attributesOfItem(atPath: url.path),
                              let size = attributes[.size] as? Int64,
                              let date = attributes[.modificationDate] as? Date else {
                            return nil
                        }

                        // Extract flight count from filename if available
                        let filename = url.lastPathComponent
                        var flightCount: Int?
                        if let range = filename.range(of: "_\\d+flights", options: .regularExpression) {
                            let countString = filename[range].dropFirst().dropLast(7) // Remove "_" and "flights"
                            flightCount = Int(countString)
                        }

                        return BackupFileInfo(
                            id: url.lastPathComponent,
                            url: url,
                            date: date,
                            size: size,
                            flightCount: flightCount
                        )
                    }
                    .sorted { $0.date > $1.date } // Most recent first

                DispatchQueue.main.async {
                    self.availableBackups = backups
                    // Now that backups are loaded, check if a new backup is needed
                    self.checkAndPerformBackupIfNeeded()
                }

            } catch {
                LogManager.shared.error("Error loading backups: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.availableBackups = []
                    // Even if loading failed, check if backup is needed
                    self.checkAndPerformBackupIfNeeded()
                }
            }
        }
    }

    private func cleanupOldBackups() throws {
        let backupDir = try getBackupDirectory()
        let contents = try fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        let backups = contents
            .filter { $0.lastPathComponent.hasPrefix(backupFilePrefix) }
            .compactMap { url -> (url: URL, date: Date)? in
                guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                      let date = attributes[.modificationDate] as? Date else {
                    return nil
                }
                return (url, date)
            }
            .sorted { $0.date > $1.date } // Most recent first

        // Delete backups beyond the retention limit
        if backups.count > settings.maxBackupsToKeep {
            let backupsToDelete = backups.dropFirst(settings.maxBackupsToKeep)
            for backup in backupsToDelete {
                try fileManager.removeItem(at: backup.url)
                LogManager.shared.info("🗑️ Deleted old backup: \(backup.url.lastPathComponent)")
            }
        }
    }

    func deleteBackup(_ backup: BackupFileInfo) throws {
        try fileManager.removeItem(at: backup.url)
        refreshAvailableBackups()
    }

    func deleteAllBackups() throws {
        let backupDir = try getBackupDirectory()
        let contents = try fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        for url in contents where url.lastPathComponent.hasPrefix(backupFilePrefix) {
            try fileManager.removeItem(at: url)
        }

        refreshAvailableBackups()
    }


    // MARK: - Background Task Management
    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }


    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Backup Errors
enum BackupError: LocalizedError {
    case backupInProgress
    case noDataToBackup
    case iCloudNotAvailable
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .backupInProgress:
            return "A backup is already in progress"
        case .noDataToBackup:
            return "No flights to backup"
        case .iCloudNotAvailable:
            return "iCloud Drive is not available. Please ensure iCloud Drive is enabled in Settings."
        case .fileWriteFailed:
            return "Failed to write backup file"
        }
    }
}
