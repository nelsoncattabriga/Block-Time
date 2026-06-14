//
//  FlightDatabaseService.swift
//  Block-Time
//
//  Created by Nelson on 9/9/2025.
//

import Foundation
import CoreData
import SwiftUI
import CloudKit
import Combine

// MARK: - Detailed Sync Error Information
public struct DetailedSyncError: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let operation: String
    public let mainError: Error
    public let individualErrors: [(recordID: String, error: Error)]
    public let rawErrorDescription: String
    public let errorDomain: String
    public let errorCode: Int
    public let errorUserInfo: [String: String]

    public var hasIndividualErrors: Bool {
        return !individualErrors.isEmpty
    }

    public var hasTechnicalDetails: Bool {
        return true
    }
}

// MARK: - Merge Proposal

/// Describes a single field change proposed by duplicate detection before it is committed.
/// The caller presents these to the user for approval; only approved proposals are applied.
public struct MergeProposal: Identifiable {
    public let id: UUID = UUID()
    public let flightDate: String
    public let route: String
    public let objectID: NSManagedObjectID
    public let fieldName: String
    public let oldValue: String
    public let newValue: String
}

// MARK: - Flight Database Service
public class FlightDatabaseService: ObservableObject, @unchecked Sendable {

    // MARK: - Singleton
    public static let shared = FlightDatabaseService()

    // MARK: - CloudKit Sync Status
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncError: Error?
    @Published public var lastSyncDate: Date?
    @Published public var detailedSyncError: DetailedSyncError?

    // MARK: - Debounce for notifications
    private var notificationDebounceTimer: Timer?
    private let notificationDebounceInterval: TimeInterval = 2.0 // 2 seconds
    private var hasCompletedInitialSetup = false
    private var initialSetupTimer: Timer?

    // MARK: - Rate limiting for remote store changes
    private var lastRemoteStoreChangeTime: Date?
    private let remoteStoreChangeMinInterval: TimeInterval = 1.0 // 1 second minimum between processing
    private var remoteChangeSyncSettleTimer: Timer?

    // MARK: - Background state tracking
    public var isAppInBackground: Bool = false
    private var pendingDataChanged: Bool = false

    private init() {
        setupCloudKitNotifications()
    } // Prevent multiple instances
    // MARK: - Date Formatter
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    // MARK: - Core Data Stack
    // The original lazy var had Thread.sleep(0.1) inside for NWPathMonitor, which created
    // a 100ms race window where a concurrent thread could also enter the initializer.
    // Fix: remove the sleep. Without it the initializer completes in microseconds and
    // there is no meaningful race window. If a concurrent access still races (extremely
    // unlikely), the "already registered" CloudKit error is handled gracefully below —
    // far better than the deadlock produced by an NSLock approach (loadPersistentStores
    // needs the main thread internally, so locking on a background thread and blocking
    // the main thread waiting for that lock causes a mutual deadlock).
    public lazy var persistentContainer: NSPersistentCloudKitContainer = Self.makePersistentContainer()

    private static func makePersistentContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "FlightDataModel", managedObjectModel: BlockTimeModel.managedObjectModel)

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        #if DEBUG
        let environment = "DEVELOPMENT"
        #else
        let environment = "PRODUCTION"
        #endif
        print("CloudKit: Environment - \(environment)")

        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        if FileManager.default.ubiquityIdentityToken != nil {
            print("CloudKit: iCloud available - enabling sync")
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.thezoolab.blocktime"
            )
        } else {
            print("CloudKit: iCloud account not available - disabling sync")
            description.cloudKitContainerOptions = nil
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data: Failed to load - \(error.localizedDescription)")
                print("Core Data: Error details - \(error.userInfo)")
                if error.domain == NSCocoaErrorDomain || error.domain == "CKErrorDomain" {
                    print("CloudKit: Sync may be unavailable - continuing with local storage")
                    DispatchQueue.main.async {
                        FlightDatabaseService.shared.lastSyncError = error
                    }
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.undoManager = UndoManager()

        #if DEBUG
        print("CloudKit Schema: Auto-initialization ENABLED (Development)")
        DispatchQueue.global(qos: .utility).async {
            do {
                try container.initializeCloudKitSchema(options: [])
                print("CloudKit Schema: Initialized in Development environment")
            } catch {
                let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: error)
                print("CloudKit Schema: \(errorInfo.message) - \(errorInfo.suggestion)")
                print("  Technical: \(error.localizedDescription)")
            }
        }
        #else
        print("CloudKit Schema: Auto-initialization DISABLED (Production)")
        print("IMPORTANT: Schema must be manually deployed to Production via CloudKit Console")
        print("   1. Open CloudKit Console: https://icloud.developer.apple.com/dashboard")
        print("   2. Select 'iCloud.com.thezoolab.blocktime' container")
        print("   3. Deploy Development schema to Production environment")
        #endif

        return container
    }

    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // MARK: - Undo / Redo

    public var canUndo: Bool { viewContext.undoManager?.canUndo ?? false }
    public var canRedo: Bool { viewContext.undoManager?.canRedo ?? false }

    public private(set) var undoableChangeCount: Int = 0

    private var undoDescriptions: [String] = []

    public var lastUndoDescription: String? { undoDescriptions.last }

    /// "d MMM" formatter used only for undo description short-date strings.
    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Returns a short "d MMM" string (e.g. "14 May") from a "dd/MM/yyyy" date string, or "" on failure.
    private func shortDay(from ddMMYYYY: String) -> String {
        guard let date = dateFormatter.date(from: ddMMYYYY) else { return "" }
        return FlightDatabaseService.shortDayFormatter.string(from: date)
    }

    /// Builds a short undo description for a single flight sector.
    private func undoDescription(verb: String, for sector: FlightSector, includeDate: Bool) -> String {
        let route = "\(sector.fromAirport)-\(sector.toAirport)"
        let fltNo = sector.flightNumber.trimmingCharacters(in: .whitespaces)
        var parts: [String] = [verb, fltNo.isEmpty ? route : fltNo]
        if includeDate {
            let day = shortDay(from: sector.date)
            if !day.isEmpty { parts.append("\(day) UTC") }
        }
        return parts.joined(separator: " · ")
    }

    @discardableResult
    public func undoLastChange() -> Bool {
        guard let undoManager = viewContext.undoManager, undoManager.canUndo else { return false }
        var ok = false
        viewContext.performAndWait {
            undoManager.undo()
            do {
                try viewContext.save()
                ok = true
            } catch {
                print("Undo save failed: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }
        if ok {
            undoableChangeCount = max(0, undoableChangeCount - 1)
            if !undoDescriptions.isEmpty { undoDescriptions.removeLast() }
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        }
        return ok
    }

    @discardableResult
    public func redoLastChange() -> Bool {
        guard let undoManager = viewContext.undoManager, undoManager.canRedo else { return false }
        var ok = false
        viewContext.performAndWait {
            undoManager.redo()
            do {
                try viewContext.save()
                ok = true
            } catch {
                print("Redo save failed: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }
        if ok {
            undoableChangeCount += 1
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        }
        return ok
    }

    public func clearUndoHistory() {
        viewContext.undoManager?.removeAllActions()
        undoableChangeCount = 0
        undoDescriptions.removeAll()
    }

    // MARK: - Undo Manager Control (batch operations)

    /// Suspend undo registration and auto-merge for bulk imports/restores.
    /// Disabling automaticallyMergesChangesFromParent prevents the viewContext from
    /// synchronously processing background-context saves mid-batch, which combined with
    /// an active NSUndoManager causes a mutual wait between the background performAndWait
    /// and the main-thread merge.
    public func suspendUndoForBatchImport() {
        viewContext.automaticallyMergesChangesFromParent = false
        viewContext.undoManager?.disableUndoRegistration()
        isBatchImporting = true
        // Release all in-memory objects so the viewContext holds no SQLite read locks
        // during the upcoming batch save. Without this, the background context's WAL
        // checkpoint blocks on the viewContext reader, causing the save to hang.
        viewContext.reset()
        print("UndoManager: registration suspended for batch import")
    }

    /// Resume undo registration and auto-merge after a bulk import/restore.
    /// Resets viewContext so it re-reads the store fresh (no merge = no undo pollution),
    /// then re-enables auto-merge and clears the undo stack.
    public func resumeUndoAfterBatchImport() {
        // Reset the viewContext so it picks up batch-saved data on the next fetch
        // without going through the undo manager's merge path.
        viewContext.reset()
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.undoManager?.enableUndoRegistration()
        viewContext.undoManager?.removeAllActions()
        undoableChangeCount = 0
        undoDescriptions.removeAll()
        isBatchImporting = false
        print("UndoManager: registration resumed and stack cleared after batch import")
        // One debounced notification after the batch completes so the UI refreshes once.
        postDebouncedFlightDataChangedNotification()
    }

    // MARK: - CloudKit Sync Control

    /// Temporarily disable CloudKit sync for bulk operations
    /// - Returns: True if CloudKit was enabled before disabling
    @discardableResult
    public func disableCloudKitSync() -> Bool {
        guard let description = persistentContainer.persistentStoreDescriptions.first else {
            return false
        }

        let wasEnabled = description.cloudKitContainerOptions != nil

        if wasEnabled {
            print("CloudKit: Disabling sync for bulk operation")
            description.cloudKitContainerOptions = nil

            // Save any pending viewContext changes before disabling CloudKit.
            // Undo registration is NOT toggled here — callers that need undo protection
            // manage it themselves (e.g. suspendUndoForBatchImport / clearAllFlights).
            if viewContext.hasChanges {
                do {
                    try viewContext.save()
                } catch {
                    print("Error saving context before disabling CloudKit: \(error)")
                }
            }
        }

        return wasEnabled
    }

    /// Re-enable CloudKit sync after bulk operations
    public func enableCloudKitSync() {
        guard let description = persistentContainer.persistentStoreDescriptions.first else {
            return
        }

        // Only re-enable if it's not already enabled
        if description.cloudKitContainerOptions == nil {
            print("CloudKit: Re-enabling sync")
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.thezoolab.blocktime"
            )

            // Save any pending viewContext changes to trigger CloudKit sync.
            // Undo registration is NOT toggled here — callers manage it themselves.
            if viewContext.hasChanges {
                do {
                    try viewContext.save()
                } catch {
                    print("Error saving context after enabling CloudKit: \(error)")
                }
            }
        }
    }

    // MARK: - CRUD Operations
    /// Save a new flight sector to the database
    public func saveFlight(_ sector: FlightSector, actionDescription: String? = nil) -> Bool {
        var success = false

        viewContext.performAndWait {
            // Check for existing flight with same ID to prevent duplicates
            let checkRequest: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            checkRequest.predicate = NSPredicate(format: "id == %@", sector.id as CVarArg)
            checkRequest.fetchLimit = 1

            do {
                let existingFlights = try viewContext.fetch(checkRequest)
                if !existingFlights.isEmpty {
                    print("Flight with ID \(sector.id) already exists - skipping duplicate save")
                    return
                }
            } catch {
                print("Error checking for duplicate flight: \(error.localizedDescription)")
                return
            }

            let flight = FlightEntity(context: viewContext)

            flight.id = sector.id

            // Parse and validate date
            guard let parsedDate = dateFormatter.date(from: sector.date) else {
                return
            }
            flight.date = parsedDate

            flight.flightNumber = sector.flightNumber
            flight.aircraftReg = sector.aircraftReg
            flight.aircraftType = sector.aircraftType
            flight.fromAirport = sector.fromAirport
            flight.toAirport = sector.toAirport
            flight.captainName = sector.captainName
            flight.foName = sector.foName
            flight.so1Name = sector.so1Name
            flight.so2Name = sector.so2Name
            flight.blockTime = sector.blockTime
            flight.nightTime = sector.nightTime
            flight.p1Time = sector.p1Time
            flight.p1usTime = sector.p1usTime
            flight.p2Time = sector.p2Time
            flight.instrumentTime = sector.instrumentTime
            flight.simTime = sector.simTime
            flight.spInsTime = sector.spInsTime.isEmpty || sector.spInsTime == "0.00" || sector.spInsTime == "0.0" ? nil : sector.spInsTime
            flight.isPilotFlying = sector.isPilotFlying
            flight.isPositioning = sector.isPositioning
            flight.isAIII = sector.isAIII
            flight.isRNP = sector.isRNP
            flight.isILS = sector.isILS
            flight.isGLS = sector.isGLS
            flight.isNPA = sector.isNPA
            flight.safeRemarks = sector.remarks
            flight.dayTakeoffs = Int16(sector.dayTakeoffs)
            flight.dayLandings = Int16(sector.dayLandings)
            flight.nightTakeoffs = Int16(sector.nightTakeoffs)
            flight.nightLandings = Int16(sector.nightLandings)
            flight.outTime = sector.outTime
            flight.inTime = sector.inTime
            flight.scheduledDeparture = sector.scheduledDeparture
            flight.scheduledArrival = sector.scheduledArrival
            flight.createdAt = Date()
            flight.modifiedAt = Date()

            // Save counter values to flat columns
            for (columnIndex, value) in sector.counterEntries where !value.isEmpty {
                flight.setCounter(columnIndex, value: value)
            }

            do {
                viewContext.undoManager?.beginUndoGrouping()
                try viewContext.save()
                viewContext.undoManager?.endUndoGrouping()
                undoableChangeCount += 1
                let saveDesc = actionDescription ?? undoDescription(verb: "Added", for: sector, includeDate: true)
                undoDescriptions.append(saveDesc)
                success = true
                print("Flight saved successfully: \(sector.flightNumberFormatted) \(sector.fromAirport)-\(sector.toAirport) on \(sector.date)")
            } catch {
                viewContext.undoManager?.endUndoGrouping()
                viewContext.rollback()
                print("Error saving flight: \(error.localizedDescription)")
            }
        }

        return success
    }

    /// Update an existing flight sector
    public func updateFlight(_ sector: FlightSector, actionDescription: String? = nil) -> Bool {
        var success = false

        viewContext.performAndWait {
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", sector.id as CVarArg)
            request.fetchLimit = 1

            do {
                let flights = try viewContext.fetch(request)
                guard let flight = flights.first else {
                    return
                }

                // Update all fields
                flight.date = dateFormatter.date(from: sector.date)
                flight.flightNumber = sector.flightNumber
                flight.aircraftReg = sector.aircraftReg
                flight.aircraftType = sector.aircraftType
                flight.fromAirport = sector.fromAirport
                flight.toAirport = sector.toAirport
                flight.captainName = sector.captainName
                flight.foName = sector.foName
                flight.so1Name = sector.so1Name
                flight.so2Name = sector.so2Name
                flight.blockTime = sector.blockTime
                flight.nightTime = sector.nightTime
                flight.p1Time = sector.p1Time
                flight.p1usTime = sector.p1usTime
                flight.p2Time = sector.p2Time
                flight.instrumentTime = sector.instrumentTime
                flight.simTime = sector.simTime
                flight.spInsTime = sector.spInsTime.isEmpty || sector.spInsTime == "0.00" || sector.spInsTime == "0.0" ? nil : sector.spInsTime
                flight.isPilotFlying = sector.isPilotFlying
                flight.isPositioning = sector.isPositioning
                flight.isAIII = sector.isAIII
                flight.isRNP = sector.isRNP
                flight.isILS = sector.isILS
                flight.isGLS = sector.isGLS
                flight.isNPA = sector.isNPA
                flight.safeRemarks = sector.remarks
                flight.dayTakeoffs = Int16(sector.dayTakeoffs)
                flight.dayLandings = Int16(sector.dayLandings)
                flight.nightTakeoffs = Int16(sector.nightTakeoffs)
                flight.nightLandings = Int16(sector.nightLandings)
                flight.outTime = sector.outTime
                flight.inTime = sector.inTime
                flight.scheduledDeparture = sector.scheduledDeparture
                flight.scheduledArrival = sector.scheduledArrival
                flight.modifiedAt = Date()

                // Clear all counter columns then write current values
                for i in 1...10 { flight.setCounter(i, value: nil) }
                for (columnIndex, value) in sector.counterEntries where !value.isEmpty {
                    flight.setCounter(columnIndex, value: value)
                }

                viewContext.undoManager?.beginUndoGrouping()
                try viewContext.save()
                viewContext.undoManager?.endUndoGrouping()
                undoableChangeCount += 1
                let updateDesc = actionDescription ?? undoDescription(verb: "Edited", for: sector, includeDate: true)
                undoDescriptions.append(updateDesc)
                success = true

            } catch {
                viewContext.undoManager?.endUndoGrouping()
                viewContext.rollback()
                print("Database: Error updating flight - \(error.localizedDescription)")
            }
        }

        return success
    }

    /// Update multiple flights on a background context to avoid blocking the UI.
    /// - Parameters:
    ///   - updates: Dictionary mapping flight UUIDs to updated FlightSector objects
    /// - Returns: True if all updates succeeded, false otherwise
    public func updateFlightsBulk(_ updates: [UUID: FlightSector]) async -> Bool {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

        do {
            try await context.perform {
                // Local formatter — DateFormatter is not thread-safe, must not share with main thread
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id IN %@", Array(updates.keys))

                let flights = try context.fetch(request)
                print("Database: Bulk updating \(flights.count) flights")

                for flight in flights {
                    guard let id = flight.id,
                          let updatedSector = updates[id] else { continue }

                    flight.date = formatter.date(from: updatedSector.date)
                    flight.flightNumber = updatedSector.flightNumber
                    flight.aircraftReg = updatedSector.aircraftReg
                    flight.aircraftType = updatedSector.aircraftType
                    flight.fromAirport = updatedSector.fromAirport
                    flight.toAirport = updatedSector.toAirport
                    flight.captainName = updatedSector.captainName
                    flight.foName = updatedSector.foName
                    flight.so1Name = updatedSector.so1Name
                    flight.so2Name = updatedSector.so2Name
                    flight.blockTime = updatedSector.blockTime
                    flight.nightTime = updatedSector.nightTime
                    flight.p1Time = updatedSector.p1Time
                    flight.p1usTime = updatedSector.p1usTime
                    flight.p2Time = updatedSector.p2Time
                    flight.instrumentTime = updatedSector.instrumentTime
                    flight.simTime = updatedSector.simTime
                    flight.spInsTime = updatedSector.spInsTime.isEmpty || updatedSector.spInsTime == "0.00" || updatedSector.spInsTime == "0.0" ? nil : updatedSector.spInsTime
                    flight.isPilotFlying = updatedSector.isPilotFlying
                    flight.isPositioning = updatedSector.isPositioning
                    flight.isAIII = updatedSector.isAIII
                    flight.isRNP = updatedSector.isRNP
                    flight.isILS = updatedSector.isILS
                    flight.isGLS = updatedSector.isGLS
                    flight.isNPA = updatedSector.isNPA
                    flight.safeRemarks = updatedSector.remarks
                    flight.dayTakeoffs = Int16(updatedSector.dayTakeoffs)
                    flight.dayLandings = Int16(updatedSector.dayLandings)
                    flight.nightTakeoffs = Int16(updatedSector.nightTakeoffs)
                    flight.nightLandings = Int16(updatedSector.nightLandings)
                    flight.outTime = updatedSector.outTime
                    flight.inTime = updatedSector.inTime
                    flight.scheduledDeparture = updatedSector.scheduledDeparture
                    flight.scheduledArrival = updatedSector.scheduledArrival
                    flight.modifiedAt = Date()

                    // Clear all counter columns then write current values
                    for i in 1...10 { flight.setCounter(i, value: nil) }
                    for (columnIndex, value) in updatedSector.counterEntries where !value.isEmpty {
                        flight.setCounter(columnIndex, value: value)
                    }
                }

                // Single transaction for all records
                try context.save()
                print("Database: Successfully bulk updated \(flights.count) flights")
            }

            // viewContext merges automatically (automaticallyMergesChangesFromParent = true)
            // Post notification on main thread so observers update correctly
            await MainActor.run {
                NotificationCenter.default.post(name: .flightDataChanged, object: nil)
            }
            return true

        } catch {
            print("Database: Bulk update failed - \(error.localizedDescription)")
            return false
        }
    }

    /// Find a scheduled flight (with zero block time) matching the given flight parameters
    /// Used to replace roster-imported scheduled flights with actual ACARS data
    /// - Parameters:
    ///   - date: UTC date string in "dd/MM/yyyy" format
    ///   - flightNumber: Flight number
    ///   - fromAirport: Departure airport (ICAO)
    ///   - toAirport: Arrival airport (ICAO)
    /// - Returns: The matching scheduled FlightEntity, or nil if not found
    public func findScheduledFlight(date: String, flightNumber: String, fromAirport: String, toAirport: String) -> FlightEntity? {
        var result: FlightEntity?

        viewContext.performAndWait {
            print("Database: Searching for scheduled flight  \(flightNumber) \(fromAirport)-\(toAirport) on \(date)")

            guard let searchDate = dateFormatter.date(from: date) else {
                print("Invalid date format for scheduled flight search: \(date)")
                return
            }

            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()

            // Strip airline prefix from search flight number to get numeric part only
            // e.g., "QF521" -> "521", "0521" -> "521"
            let numericFlightNumber = flightNumber.replacingOccurrences(of: "^[A-Z]{2}", with: "", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "0"))

            // Match on: date, route, AND flexible flight number matching
            // A scheduled/future flight is identified by empty OUT/IN times (hasn't been flown yet)
            // Flight number can match exactly OR as numeric-only (without prefix)
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "date == %@", searchDate as NSDate),
                NSPredicate(format: "flightNumber == %@ OR flightNumber == %@", flightNumber, numericFlightNumber),
                NSPredicate(format: "fromAirport == %@", fromAirport),
                NSPredicate(format: "toAirport == %@", toAirport),
                NSPredicate(format: "(outTime == nil OR outTime == %@) AND (inTime == nil OR inTime == %@)", "", "")
            ])
            request.fetchLimit = 1

            do {
                let flights = try viewContext.fetch(request)
                if let scheduledFlight = flights.first {
                    print("Found scheduled flight to replace: \(scheduledFlight.flightNumber ?? "?") -> updating to \(flightNumber)")
                    result = scheduledFlight
                } else {
                    print("No scheduled flight found: \(flightNumber) OR \(numericFlightNumber) on \(date)")
                }
            } catch {
                print("Error searching for scheduled flight: \(error.localizedDescription)")
            }
        }

        return result
    }

    /// Find a scheduled flight by date and flight number only (for B787 where airports aren't in ACARS)
    /// Returns nil if no match found, or if multiple matches found (ambiguous)
    public func findScheduledFlightByDateAndFlightNumber(date: String, flightNumber: String) -> FlightEntity? {
        var result: FlightEntity?

        viewContext.performAndWait {
            print("Database: Searching for scheduled flight by date+flight  \(flightNumber) on \(date)")

            guard let searchDate = dateFormatter.date(from: date) else {
                print("Invalid date format for scheduled flight search: \(date)")
                return
            }

            // Strip airline prefix from search flight number to get numeric part only
            let numericFlightNumber = flightNumber.replacingOccurrences(of: "^[A-Z]{2}", with: "", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "0"))

            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()

            // Match on: date, flexible flight number, and empty OUT/IN times (scheduled flight)
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "date == %@", searchDate as NSDate),
                NSPredicate(format: "flightNumber == %@ OR flightNumber == %@", flightNumber, numericFlightNumber),
                NSPredicate(format: "(outTime == nil OR outTime == %@) AND (inTime == nil OR inTime == %@)", "", "")
            ])

            do {
                let flights = try viewContext.fetch(request)
                if flights.count == 1 {
                    print(" Found unique scheduled flight match: \(flights[0].flightNumber ?? "?")")
                    result = flights[0]
                } else if flights.count > 1 {
                    print(" \(flights.count) scheduled flights match date/flight number  too ambiguous for pre-fill")
                } else {
                    print("No scheduled flight found for \(flightNumber) on \(date)")
                }
            } catch {
                print("Error searching for scheduled flight: \(error.localizedDescription)")
            }
        }

        return result
    }

    /// Update a scheduled flight with actual flight data from ACARS
    /// Preserves the original UUID and creation timestamp while updating all flight details
    /// - Parameters:
    ///   - scheduledFlight: The scheduled FlightEntity to update
    ///   - actualData: The FlightSector with actual flight data
    /// - Returns: True if update succeeded, false otherwise
    public func updateScheduledFlightWithActualData(_ scheduledFlight: FlightEntity, actualData: FlightSector, actionDescription: String? = nil) -> Bool {
        var success = false

        viewContext.performAndWait {
            // Parse and validate date
            guard let parsedDate = dateFormatter.date(from: actualData.date) else {
                print("Invalid date in actual flight data: \(actualData.date)")
                return
            }

            // Merge strategy: Only update fields if new data is non-empty, otherwise preserve existing data
            // This allows partial ACARS updates without losing manually entered data

            scheduledFlight.date = parsedDate

            // Only update if new data is non-empty, otherwise preserve existing
            if !actualData.flightNumber.isEmpty {
                scheduledFlight.flightNumber = actualData.flightNumber
            }
            if !actualData.aircraftReg.isEmpty {
                scheduledFlight.aircraftReg = actualData.aircraftReg
            }
            if !actualData.aircraftType.isEmpty {
                scheduledFlight.aircraftType = actualData.aircraftType
            }
            if !actualData.fromAirport.isEmpty {
                scheduledFlight.fromAirport = actualData.fromAirport
            }
            if !actualData.toAirport.isEmpty {
                scheduledFlight.toAirport = actualData.toAirport
            }
            if !actualData.captainName.isEmpty {
                scheduledFlight.captainName = actualData.captainName
            }
            if !actualData.foName.isEmpty {
                scheduledFlight.foName = actualData.foName
            }
            if let so1 = actualData.so1Name, !so1.isEmpty {
                scheduledFlight.so1Name = so1
            }
            if let so2 = actualData.so2Name, !so2.isEmpty {
                scheduledFlight.so2Name = so2
            }

            // Always update times and calculated fields from ACARS (these are the primary ACARS data)
            scheduledFlight.blockTime = actualData.blockTime
            scheduledFlight.nightTime = actualData.nightTime
            scheduledFlight.p1Time = actualData.p1Time
            scheduledFlight.p1usTime = actualData.p1usTime
            scheduledFlight.p2Time = actualData.p2Time
            scheduledFlight.instrumentTime = actualData.instrumentTime
            scheduledFlight.simTime = actualData.simTime
            scheduledFlight.spInsTime = actualData.spInsTime.isEmpty || actualData.spInsTime == "0.00" || actualData.spInsTime == "0.0" ? nil : actualData.spInsTime
            scheduledFlight.isPilotFlying = actualData.isPilotFlying
            scheduledFlight.isAIII = actualData.isAIII
            scheduledFlight.isRNP = actualData.isRNP
            scheduledFlight.isILS = actualData.isILS
            scheduledFlight.isGLS = actualData.isGLS
            scheduledFlight.isNPA = actualData.isNPA
            scheduledFlight.dayTakeoffs = Int16(actualData.dayTakeoffs)
            scheduledFlight.dayLandings = Int16(actualData.dayLandings)
            scheduledFlight.nightTakeoffs = Int16(actualData.nightTakeoffs)
            scheduledFlight.nightLandings = Int16(actualData.nightLandings)
            scheduledFlight.outTime = actualData.outTime
            scheduledFlight.inTime = actualData.inTime

            // Only update remarks if new data is non-empty
            if !actualData.remarks.isEmpty {
                scheduledFlight.safeRemarks = actualData.remarks
            }

            // Preserve original STD/STA if ACARS data doesn't include them (empty strings)
            // This prevents roster-imported scheduled times from being overwritten
            if !actualData.scheduledDeparture.isEmpty {
                scheduledFlight.scheduledDeparture = actualData.scheduledDeparture
            } else if let existingSTD = scheduledFlight.scheduledDeparture, !existingSTD.isEmpty {
                print(" Preserving original STD: \(existingSTD)")
            }

            if !actualData.scheduledArrival.isEmpty {
                scheduledFlight.scheduledArrival = actualData.scheduledArrival
            } else if let existingSTA = scheduledFlight.scheduledArrival, !existingSTA.isEmpty {
                print(" Preserving original STA: \(existingSTA)")
            }

            scheduledFlight.modifiedAt = Date()
            // Note: createdAt is preserved from original scheduled flight

            do {
                viewContext.undoManager?.beginUndoGrouping()
                try viewContext.save()
                viewContext.undoManager?.endUndoGrouping()
                undoableChangeCount += 1
                let scheduledDesc = actionDescription ?? undoDescription(verb: "Edited", for: actualData, includeDate: true)
                undoDescriptions.append(scheduledDesc)
                print("Successfully updated scheduled flight with actual ACARS data")
                success = true
            } catch {
                viewContext.undoManager?.endUndoGrouping()
                print("Error updating scheduled flight: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }

        return success
    }
//    /// Fetch all flights sorted by date (most recent first)
//    /// DOES NOT INCLUDE PAX SECTORS - but should!
//    func fetchAllFlights() -> [FlightSector] {
//        var sectors: [FlightSector] = []
//
//        viewContext.performAndWait {
//            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
//            // Exclude rostered flights (blockTime is "0", "0.0", or "0.00" AND simTime is also "0", "0.0", or "0.00")
//            // This allows simulator sessions (zero block time but non-zero sim time) to be included
//            // This ensures FRMS and Dashboard use the same flight set
//            request.predicate = NSPredicate(format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)", "0", "0.0", "0.00", "0", "0.0", "0.00")
//            request.sortDescriptors = [
//                NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)
//            ]
//            request.fetchBatchSize = 100 // Optimize for large datasets
//            request.returnsObjectsAsFaults = false // Eager loading
//
//            do {
//                let flights = try viewContext.fetch(request)
//                sectors = flights.compactMap { convertToFlightSector($0) }
//            } catch {
//                print("Database: Error fetching all flights - \(error.localizedDescription)")
//            }
//        }
//
//        return sectors
//    }
    /// Fetch all flights sorted by date (most recent first)
    /// Includes PAX (positioning) flights, simulator flights, operating flights, and rostered flights
    /// Excludes only empty placeholder flights with no data
    public func fetchAllFlights() -> [FlightSector] {
           var sectors: [FlightSector] = []

           viewContext.performAndWait {
               let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()

               request.predicate = NSPredicate(format: "date != nil")

               request.sortDescriptors = [
                   NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)
               ]
               request.fetchBatchSize = 100 // Optimize for large datasets
               request.returnsObjectsAsFaults = false // Eager loading


               do {
                   let flights = try viewContext.fetch(request)
                   // Secondary sort: within same date (already sorted descending by NSSortDescriptor),
                   // order by departure time descending so newest departure is at the top.
                   // outTime takes priority; fall back to scheduledDeparture; empty sorts last.
                   let raw = flights.compactMap { entity -> (FlightSector, Date)? in
                       guard let sector = convertToFlightSector(entity),
                             let date = entity.date else { return nil }
                       return (sector, date)
                   }
                   sectors = raw.sorted { a, b in
                       if a.1 != b.1 { return a.1 > b.1 }
                       let aTime = a.0.outTime.isEmpty ? a.0.scheduledDeparture : a.0.outTime
                       let bTime = b.0.outTime.isEmpty ? b.0.scheduledDeparture : b.0.outTime
                       if aTime.isEmpty && bTime.isEmpty {
                           guard let ac = a.0.createdAt, let bc = b.0.createdAt else { return false }
                           return ac > bc
                       }
                       if aTime.isEmpty { return false }
                       if bTime.isEmpty { return true }
                       return aTime > bTime
                   }.map(\.0)
               } catch {
                   print("Database: Error fetching all flights - \(error.localizedDescription)")
               }
           }

           return sectors
       }

    public func fetchAllFlightsAsync() async -> [FlightSector] {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                request.predicate = NSPredicate(format: "date != nil")
                request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)]
                request.fetchBatchSize = 100
                request.returnsObjectsAsFaults = false

                do {
                    let flights = try context.fetch(request)
                    let raw = flights.compactMap { entity -> (FlightSector, Date)? in
                        guard let sector = self.convertToFlightSector(entity),
                              let date = entity.date else { return nil }
                        return (sector, date)
                    }
                    let sectors = raw.sorted { a, b in
                        if a.1 != b.1 { return a.1 > b.1 }
                        let aTime = a.0.outTime.isEmpty ? a.0.scheduledDeparture : a.0.outTime
                        let bTime = b.0.outTime.isEmpty ? b.0.scheduledDeparture : b.0.outTime
                        if aTime.isEmpty && bTime.isEmpty {
                            guard let ac = a.0.createdAt, let bc = b.0.createdAt else { return false }
                            return ac > bc
                        }
                        if aTime.isEmpty { return false }
                        if bTime.isEmpty { return true }
                        return aTime > bTime
                    }.map(\.0)
                    continuation.resume(returning: sectors)
                } catch {
                    print("Database: Error fetching all flights async - \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    public func fetchFlightsAsync(from startDateString: String, to endDateString: String) async -> [FlightSector] {
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else { return [] }
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return await withCheckedContinuation { continuation in
            context.perform {
                let calendar = Calendar.current
                let startOfPeriod = calendar.startOfDay(for: startDate)
                let endOfPeriod = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                request.predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND flightNumber != %@", startOfPeriod as NSDate, endOfPeriod as NSDate, "SUMMARY")
                request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)]
                request.fetchBatchSize = 100
                request.returnsObjectsAsFaults = false
                do {
                    let flights = try context.fetch(request)
                    continuation.resume(returning: flights.compactMap { self.convertToFlightSector($0) })
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    public func getAllAircraftTypesAsync() async -> [String] {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                request.predicate = NSPredicate(format: "isPositioning == NO OR isPositioning == nil")
                request.returnsObjectsAsFaults = false
                do {
                    let flights = try context.fetch(request)
                    let types = flights.compactMap { flight -> String? in
                        guard let raw = flight.aircraftType else { return nil }
                        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                        return t.count >= 3 ? t : nil
                    }
                    continuation.resume(returning: Array(Set(types)).sorted())
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    public func getDetailedFlightStatisticsAsync(for aircraftType: String) async -> (totalHours: Double, totalSectors: Int, p1Time: Double, p1usTime: Double, p2Time: Double, simTime: Double) {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        let countSimInTotal = UserDefaults.standard.object(forKey: "countSimInTotal") as? Bool ?? true
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "aircraftType == %@", aircraftType),
                    NSPredicate(format: "isPositioning == NO OR isPositioning == nil"),
                    NSPredicate(format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)", "0", "0.0", "0.00", "0", "0.0", "0.00")
                ])
                request.returnsObjectsAsFaults = false
                do {
                    let flights = try context.fetch(request)
                    var totalHours: Double = 0, p1Time: Double = 0, p1usTime: Double = 0, p2Time: Double = 0, simTime: Double = 0
                    for flight in flights {
                        let blockTime = self.safeDoubleFromString(flight.blockTime)
                        let flightSimTime = self.safeDoubleFromString(flight.simTime)
                        let isSimFlight = blockTime == 0 && flightSimTime > 0
                        totalHours += blockTime > 0 ? blockTime : (countSimInTotal ? flightSimTime : 0)
                        if !isSimFlight {
                            p1Time += self.safeDoubleFromString(flight.p1Time)
                            p1usTime += self.safeDoubleFromString(flight.p1usTime)
                            p2Time += self.safeDoubleFromString(flight.p2Time)
                        }
                        simTime += flightSimTime
                    }
                    continuation.resume(returning: (totalHours, flights.count, p1Time, p1usTime, p2Time, simTime))
                } catch {
                    continuation.resume(returning: (0.0, 0, 0.0, 0.0, 0.0, 0.0))
                }
            }
        }
    }

    /// Fetch flights for a specific date
    public func fetchFlights(for dateString: String) -> [FlightSector] {
        guard let date = dateFormatter.date(from: dateString) else {
            return []
        }

        var sectors: [FlightSector] = []

        viewContext.performAndWait {
            // Create date range for the entire day
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                return
            }

            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \FlightEntity.date, ascending: true)
            ]
            request.relationshipKeyPathsForPrefetching = ["counterEntries"]

            do {
                let flights = try viewContext.fetch(request)
                sectors = flights.compactMap { convertToFlightSector($0) }
            } catch {
                print("Database: Error fetching flights for date - \(error.localizedDescription)")
            }
        }

        return sectors
    }
    /// Fetch flights within a date range
    /// Uses inclusive end date matching FRMS calculation approach
    public func fetchFlights(from startDateString: String, to endDateString: String) -> [FlightSector] {
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            return []
        }

        var sectors: [FlightSector] = []

        viewContext.performAndWait {
            let calendar = Calendar.current
            // Normalize to start of day for consistent comparison
            let startOfPeriod = calendar.startOfDay(for: startDate)
            // Use end of day (23:59:59) for the end date to include ALL flights on that day
            let endOfPeriod = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            // Use inclusive end date (<=) to match FRMS calculation approach. Exclude summaries.
            request.predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND flightNumber != %@", startOfPeriod as NSDate, endOfPeriod as NSDate, "SUMMARY")
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)
            ]
            request.relationshipKeyPathsForPrefetching = ["counterEntries"]

            do {
                let flights = try viewContext.fetch(request)
                sectors = flights.compactMap { convertToFlightSector($0) }
            } catch {
                print("Database: Error fetching flights in range - \(error.localizedDescription)")
            }
        }

        return sectors
    }
    /// Delete a flight sector
    public func deleteFlight(_ sector: FlightSector, actionDescription: String? = nil) -> Bool {
        var success = false

        viewContext.performAndWait {
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", sector.id as CVarArg)
            request.fetchLimit = 1

            do {
                let flights = try viewContext.fetch(request)
                guard let flight = flights.first else {
                    return
                }

                viewContext.delete(flight)
                viewContext.undoManager?.beginUndoGrouping()
                try viewContext.save()
                viewContext.undoManager?.endUndoGrouping()
                undoableChangeCount += 1
                let deleteDesc = actionDescription ?? undoDescription(verb: "Deleted", for: sector, includeDate: true)
                undoDescriptions.append(deleteDesc)
                success = true

            } catch {
                viewContext.undoManager?.endUndoGrouping()
                print("Database: Error deleting flight - \(error.localizedDescription)")
            }
        }

        return success
    }

    /// Delete multiple flights
    public func deleteFlights(_ sectors: [FlightSector], actionDescription: String? = nil) -> Bool {
        var success = false

        viewContext.performAndWait {
            let ids = sectors.map { $0.id }
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids)

            do {
                let flights = try viewContext.fetch(request)
                flights.forEach { viewContext.delete($0) }
                viewContext.undoManager?.beginUndoGrouping()
                try viewContext.save()
                viewContext.undoManager?.endUndoGrouping()
                undoableChangeCount += 1
                let bulkDeleteDesc = actionDescription ?? "Deleted \(sectors.count) \(sectors.count == 1 ? "flight" : "flights")"
                undoDescriptions.append(bulkDeleteDesc)
                success = true
            } catch {
                viewContext.undoManager?.endUndoGrouping()
                print("Database: Error deleting flights - \(error.localizedDescription)")
            }
        }

        return success
    }

    /// Duplicate multiple flights, assigning each a new UUID and today's createdAt
    @discardableResult
    public func duplicateFlights(_ sectors: [FlightSector]) -> Int {
        viewContext.undoManager?.beginUndoGrouping()
        var savedCount = 0
        for sector in sectors {
            let copy = FlightSector(
                id: UUID(),
                date: sector.date,
                flightNumber: sector.flightNumber,
                aircraftReg: sector.aircraftReg,
                aircraftType: sector.aircraftType,
                fromAirport: sector.fromAirport,
                toAirport: sector.toAirport,
                captainName: sector.captainName,
                foName: sector.foName,
                so1Name: sector.so1Name,
                so2Name: sector.so2Name,
                blockTime: sector.blockTime,
                nightTime: sector.nightTime,
                p1Time: sector.p1Time,
                p1usTime: sector.p1usTime,
                p2Time: sector.p2Time,
                instrumentTime: sector.instrumentTime,
                simTime: sector.simTime,
                spInsTime: sector.spInsTime,
                isPilotFlying: sector.isPilotFlying,
                isPositioning: sector.isPositioning,
                isAIII: sector.isAIII,
                isRNP: sector.isRNP,
                isILS: sector.isILS,
                isGLS: sector.isGLS,
                isNPA: sector.isNPA,
                remarks: sector.remarks,
                dayTakeoffs: sector.dayTakeoffs,
                dayLandings: sector.dayLandings,
                nightTakeoffs: sector.nightTakeoffs,
                nightLandings: sector.nightLandings,
                outTime: sector.outTime,
                inTime: sector.inTime,
                scheduledDeparture: sector.scheduledDeparture,
                scheduledArrival: sector.scheduledArrival,
                counterEntries: sector.counterEntries
            )
            if saveFlightRaw(copy) { savedCount += 1 }
        }
        viewContext.undoManager?.endUndoGrouping()
        if savedCount > 0 {
            let desc = savedCount == 1 ? "Duplicated 1 flight" : "Duplicated \(savedCount) flights"
            undoDescriptions.append(desc)
            undoableChangeCount += 1
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        } else {
            viewContext.undoManager?.undoNestedGroup()
        }
        return savedCount
    }

    /// Saves `sector` and returns a new FlightSector with fromAirport set to sector.toAirport,
    /// flight number cleared, all times/approaches zeroed, ready for the next leg.
    func createNextSector(from sector: FlightSector) -> FlightSector? {
        viewContext.undoManager?.beginUndoGrouping()
        guard saveFlightRaw(sector) else {
            viewContext.undoManager?.undoNestedGroup()
            return nil
        }
        undoDescriptions.append("Added next sector")
        undoableChangeCount += 1
        NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        viewContext.undoManager?.endUndoGrouping()

        return FlightSector(
            id: UUID(),
            date: sector.date,
            flightNumber: "",
            aircraftReg: sector.aircraftReg,
            aircraftType: sector.aircraftType,
            fromAirport: sector.toAirport,
            toAirport: "",
            captainName: sector.captainName,
            foName: sector.foName,
            so1Name: sector.so1Name,
            so2Name: sector.so2Name,
            blockTime: "0.0",
            nightTime: "0.0",
            p1Time: "0.0",
            p1usTime: "0.0",
            p2Time: "0.0",
            instrumentTime: "0.0",
            simTime: "0.0",
            spInsTime: "0.0",
            isPilotFlying: sector.isPilotFlying,
            isPositioning: sector.isPositioning,
            isAIII: false,
            isRNP: false,
            isILS: false,
            isGLS: false,
            isNPA: false,
            remarks: "",
            dayTakeoffs: 0,
            dayLandings: 0,
            nightTakeoffs: 0,
            nightLandings: 0,
            outTime: "",
            inTime: "",
            scheduledDeparture: "",
            scheduledArrival: "",
            counterEntries: [:]
        )
    }

    /// Inserts a flight into viewContext without wrapping in its own undo group or touching the description stack.
    /// Used by duplicateFlights, which manages its own single outer undo group.
    private func saveFlightRaw(_ sector: FlightSector) -> Bool {
        var success = false
        viewContext.performAndWait {
            let checkRequest: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            checkRequest.predicate = NSPredicate(format: "id == %@", sector.id as CVarArg)
            checkRequest.fetchLimit = 1
            do {
                let existing = try viewContext.fetch(checkRequest)
                guard existing.isEmpty else { return }
            } catch {
                print("Error checking for duplicate flight: \(error.localizedDescription)")
                return
            }
            let flight = FlightEntity(context: viewContext)
            flight.id = sector.id
            guard let parsedDate = dateFormatter.date(from: sector.date) else { return }
            flight.date = parsedDate
            flight.flightNumber = sector.flightNumber
            flight.aircraftReg = sector.aircraftReg
            flight.aircraftType = sector.aircraftType
            flight.fromAirport = sector.fromAirport
            flight.toAirport = sector.toAirport
            flight.captainName = sector.captainName
            flight.foName = sector.foName
            flight.so1Name = sector.so1Name
            flight.so2Name = sector.so2Name
            flight.blockTime = sector.blockTime
            flight.nightTime = sector.nightTime
            flight.p1Time = sector.p1Time
            flight.p1usTime = sector.p1usTime
            flight.p2Time = sector.p2Time
            flight.instrumentTime = sector.instrumentTime
            flight.simTime = sector.simTime
            flight.spInsTime = sector.spInsTime.isEmpty || sector.spInsTime == "0.00" || sector.spInsTime == "0.0" ? nil : sector.spInsTime
            flight.isPilotFlying = sector.isPilotFlying
            flight.isPositioning = sector.isPositioning
            flight.isAIII = sector.isAIII
            flight.isRNP = sector.isRNP
            flight.isILS = sector.isILS
            flight.isGLS = sector.isGLS
            flight.isNPA = sector.isNPA
            flight.safeRemarks = sector.remarks
            flight.dayTakeoffs = Int16(sector.dayTakeoffs)
            flight.dayLandings = Int16(sector.dayLandings)
            flight.nightTakeoffs = Int16(sector.nightTakeoffs)
            flight.nightLandings = Int16(sector.nightLandings)
            flight.outTime = sector.outTime
            flight.inTime = sector.inTime
            flight.scheduledDeparture = sector.scheduledDeparture
            flight.scheduledArrival = sector.scheduledArrival
            flight.createdAt = Date()
            flight.modifiedAt = Date()
            for (columnIndex, value) in sector.counterEntries where !value.isEmpty {
                flight.setCounter(columnIndex, value: value)
            }
            do {
                try viewContext.save()
                success = true
            } catch {
                viewContext.rollback()
                print("Error duplicating flight: \(error.localizedDescription)")
            }
        }
        return success
    }

    /// Delete all flight entries from the database.
    /// Callers that own the undo-suspension lifecycle (e.g. batch import) must call
    /// suspendUndoForBatchImport() before this and resumeUndoAfterBatchImport() after —
    /// this function does NOT touch the undo manager to avoid mismatched enable/disable calls.
    ///
    /// Uses NSBatchDeleteRequest so that no FlightEntity objects are loaded into viewContext.
    /// Loading 7000+ objects then saving them leaves the viewContext with an open SQLite read
    /// transaction, which blocks the WAL checkpoint during the subsequent saveFlightsBatch and
    /// causes an indefinite hang (NSSQLCore.m:2706). The batch delete operates at the SQL layer
    /// and bypasses the object graph entirely. viewContext.reset() is called afterward to merge
    /// the batch result into the in-memory graph and release any residual read lock.
    public func clearAllFlights() -> Bool {
        var success = false

        viewContext.performAndWait {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = FlightEntity.fetchRequest()
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeCount

            do {
                let result = try viewContext.execute(batchDelete) as? NSBatchDeleteResult
                let deletedCount = result?.result as? Int ?? 0
                print("Database: NSBatchDeleteRequest removed \(deletedCount) flights")

                // Reset the context so its in-memory object graph reflects the SQL-level deletion
                // and the SQLite read transaction is released before the caller proceeds.
                viewContext.reset()

                print("FlightDatabaseService: Posting .flightDataChanged (clearAllFlights)")
                NotificationCenter.default.post(name: .flightDataChanged, object: nil)

                success = true
            } catch {
                print("Database: Error clearing all flights - \(error.localizedDescription)")
            }
        }

        return success
    }

    /// OPTIMIZED: Save multiple flights in a single batch operation
    /// This is dramatically faster than individual saves for large imports
    public func saveFlightsBatch(_ sectors: [FlightSector], sessionID: UUID = UUID()) -> (successCount: Int, failureCount: Int, duplicateCount: Int, sessionID: UUID, mergeProposals: [MergeProposal]) {
        var successCount = 0
        var failureCount = 0
        var duplicateCount = 0
        var mergeProposals: [MergeProposal] = []

        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

        context.performAndWait {
            print("Database: Starting batch save of \(sectors.count) flights")

            // DateFormatter is not thread-safe — create a local instance for this background context
            let localDateFormatter: DateFormatter = {
                let f = DateFormatter()
                f.dateFormat = "dd/MM/yyyy"
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(secondsFromGMT: 0)
                return f
            }()

            // Steps 1 + 2: Single fetch of all existing flights to build all duplicate indexes.
            // Replaces the previous "id IN [N UUIDs]" query which hangs SQLite at large N.
            var existingByID = [UUID: FlightEntity]()
            var existingIDs = Set<UUID>()
            var contentBasedDuplicates = Set<String>()
            // Fuzzy map for WebCIS imports (no flight number): keyed on "date|from|to".
            // Reg is intentionally excluded — the user may have entered the wrong reg manually,
            // and webCIS is the authoritative source. Indexed with ±1 day offsets to absorb the
            // UTC/local midnight difference between manually-entered and WebCIS dates.
            // Maps fuzzy key → entity objectID so we can merge reg/type on match.
            var fuzzyDuplicates = [String: NSManagedObjectID]()
            // Sim-specific duplicate set: keyed on "date|simTime" with ±1 day tolerance.
            // WebCIS sim rows have no reg/route; the user may have added those manually after
            // import, so we match purely on date + sim time to avoid re-importing.
            var simDuplicates = Set<String>()
            do {
                let allFlightsRequest: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                allFlightsRequest.propertiesToFetch = ["id", "date", "flightNumber", "fromAirport", "toAirport", "aircraftReg", "aircraftType", "simTime"]
                let allFlights = try context.fetch(allFlightsRequest)

                for flight in allFlights {
                    // Build UUID duplicate index
                    if let id = flight.id {
                        existingByID[id] = flight
                        existingIDs.insert(id)
                    }

                    guard let date = flight.date,
                          let fromAirport = flight.fromAirport,
                          let toAirport = flight.toAirport
                    else { continue }
                    let aircraftReg = flight.aircraftReg ?? ""
                    let flightNumber = flight.flightNumber ?? ""
                    let aircraftType = flight.aircraftType ?? ""
                    let dateString = localDateFormatter.string(from: date)
                    let signature = "\(dateString)|\(flightNumber)|\(fromAirport)|\(toAirport)|\(aircraftReg)|\(aircraftType)"
                    contentBasedDuplicates.insert(signature)

                    // Index from+to under date-1, date, date+1 for fuzzy matching.
                    // Reg intentionally excluded — webCIS reg wins on merge.
                    // Normalise to ICAO so manually-entered ICAO codes match WebCIS IATA codes.
                    let normFrom = AirportService.shared.convertToICAO(fromAirport)
                    let normTo   = AirportService.shared.convertToICAO(toAirport)
                    for dayOffset in [-1, 0, 1] {
                        if let offsetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: date) {
                            let d = localDateFormatter.string(from: offsetDate)
                            fuzzyDuplicates["\(d)|\(normFrom)|\(normTo)"] = flight.objectID
                        }
                    }

                    // Build sim duplicate index: any entry with simTime > 0 is indexed by
                    // date ±1 day + simTime so webCIS sim rows are caught even when the
                    // stored entry has a different reg/route added by the user after import.
                    let simTime = flight.simTime ?? ""
                    if !simTime.isEmpty, simTime != "0.00", simTime != "0.0", simTime != "0" {
                        for dayOffset in [-1, 0, 1] {
                            if let offsetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: date) {
                                let d = localDateFormatter.string(from: offsetDate)
                                simDuplicates.insert("\(d)|\(simTime)")
                            }
                        }
                    }
                }
                print("Found \(existingIDs.count) existing flights by UUID, \(contentBasedDuplicates.count) content signatures, \(fuzzyDuplicates.count) fuzzy entries, \(simDuplicates.count) sim entries")
            } catch {
                print("Error building duplicate indexes: \(error.localizedDescription)")
                failureCount = sectors.count
                return
            }

            // Step 3a (fast path): If the store is empty (all duplicate indexes are empty),
            // use NSBatchInsertRequest. This operates at the SQL layer — it does NOT create
            // NSManagedObjects, does NOT trigger KVO, and does NOT grow the WAL the same way
            // per-object inserts do. In replace mode (after clearAllFlights), the duplicate
            // indexes are always empty, so this path always fires for restores. This avoids
            // the CloudKit mirroring delegate read-lock conflict that blocks WAL checkpoint
            // when per-object saves hit the ~8 MB WAL threshold.
            if existingIDs.isEmpty && contentBasedDuplicates.isEmpty {
                print("Database: Store is empty — using NSBatchInsertRequest for \(sectors.count) flights")
                let batchBaseTime = Date()
                var dictionaries: [[String: Any]] = []
                dictionaries.reserveCapacity(sectors.count)
                for (sectorIndex, sector) in sectors.enumerated() {
                    guard let parsedDate = localDateFormatter.date(from: sector.date) else {
                        failureCount += 1
                        continue
                    }
                    var dict: [String: Any] = [
                        "id":                 sector.id as NSUUID,
                        "date":               parsedDate,
                        "flightNumber":       sector.flightNumber,
                        "aircraftReg":        sector.aircraftReg,
                        "aircraftType":       sector.aircraftType,
                        "fromAirport":        sector.fromAirport,
                        "toAirport":          sector.toAirport,
                        "captainName":        sector.captainName,
                        "foName":             sector.foName,
                        "so1Name":            sector.so1Name as Any,
                        "so2Name":            sector.so2Name as Any,
                        "blockTime":          sector.blockTime,
                        "nightTime":          sector.nightTime,
                        "p1Time":             sector.p1Time,
                        "p1usTime":           sector.p1usTime,
                        "p2Time":             sector.p2Time,
                        "instrumentTime":     sector.instrumentTime,
                        "simTime":            sector.simTime,
                        "isPilotFlying":      sector.isPilotFlying,
                        "isPositioning":      sector.isPositioning,
                        "isAIII":             sector.isAIII,
                        "isRNP":              sector.isRNP,
                        "isILS":              sector.isILS,
                        "isGLS":              sector.isGLS,
                        "isNPA":              sector.isNPA,
                        "remarks":            sector.remarks,
                        "dayTakeoffs":        Int16(sector.dayTakeoffs),
                        "dayLandings":        Int16(sector.dayLandings),
                        "nightTakeoffs":      Int16(sector.nightTakeoffs),
                        "nightLandings":      Int16(sector.nightLandings),
                        "outTime":            sector.outTime,
                        "inTime":             sector.inTime,
                        "scheduledDeparture": sector.scheduledDeparture,
                        "scheduledArrival":   sector.scheduledArrival,
                        "importSessionID":    sessionID as NSUUID,
                        "importedAt":         Date(),
                        "createdAt":          batchBaseTime.addingTimeInterval(Double(sectorIndex) * 0.001),
                        "modifiedAt":         Date(),
                    ]
                    // spInsTime: only store non-zero values
                    let spIns = sector.spInsTime
                    if !spIns.isEmpty && spIns != "0.00" && spIns != "0.0" {
                        dict["spInsTime"] = spIns
                    }
                    // counter1–counter10: only store non-empty values
                    for (columnIndex, value) in sector.counterEntries where !value.isEmpty {
                        switch columnIndex {
                        case 1:  dict["counter1"]  = value
                        case 2:  dict["counter2"]  = value
                        case 3:  dict["counter3"]  = value
                        case 4:  dict["counter4"]  = value
                        case 5:  dict["counter5"]  = value
                        case 6:  dict["counter6"]  = value
                        case 7:  dict["counter7"]  = value
                        case 8:  dict["counter8"]  = value
                        case 9:  dict["counter9"]  = value
                        case 10: dict["counter10"] = value
                        default: break
                        }
                    }
                    dictionaries.append(dict)
                }

                let batchInsert = NSBatchInsertRequest(entityName: "FlightEntity", objects: dictionaries)
                batchInsert.resultType = .count
                do {
                    let result = try context.execute(batchInsert) as? NSBatchInsertResult
                    let insertedCount = result?.result as? Int ?? 0
                    print("Database: NSBatchInsertRequest inserted \(insertedCount) flights (failures: \(failureCount))")
                    successCount = insertedCount
                } catch {
                    print("Database: NSBatchInsertRequest failed — \(error.localizedDescription)")
                    failureCount = sectors.count
                    successCount = 0
                }
                print("Batch save summary:")
                print("    Success: \(successCount)")
                print("    Duplicates: \(duplicateCount)")
                print("   Failures: \(failureCount)")
                return
            }

            // Step 3: Create all flight entities, saving every 500 to keep WAL size small.
            // Core Data's PostSaveMaintenance triggers wal_checkpoint(TRUNCATE) once the WAL
            // exceeds ~8 MB. A single save of 7000+ rows blows past that threshold and the
            // checkpoint blocks on the still-open write transaction, causing a visible hang.
            // Saving in chunks keeps each WAL segment small so checkpoints complete immediately.
            let chunkSize = 500
            let batchBaseTime = Date()
            for (sectorIndex, sector) in sectors.enumerated() {
                // Check UUID-based duplicate first
                if existingIDs.contains(sector.id) {
                    // Propose any incoming value that differs from what is stored.
                    // The user reviews and approves changes before they are written.
                    if let existing = existingByID[sector.id] {
                        let incomingType = sector.aircraftType.trimmingCharacters(in: .whitespacesAndNewlines)
                        let incomingReg  = sector.aircraftReg.trimmingCharacters(in: .whitespacesAndNewlines)
                        let existingType = (existing.aircraftType ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let existingReg  = (existing.aircraftReg  ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let displayDate = sector.date
                        let displayRoute = "\(sector.fromAirport) → \(sector.toAirport)"
                        // Auto-fill blank aircraftType — no conflict, no user review needed
                        if !incomingType.isEmpty && existingType.isEmpty {
                            existing.aircraftType = incomingType
                            print(" Auto-filled blank aircraftType: \(displayDate) \(displayRoute)  \(incomingType)")
                        } else if !incomingType.isEmpty && incomingType != existingType {
                            mergeProposals.append(MergeProposal(
                                flightDate: displayDate,
                                route: displayRoute,
                                objectID: existing.objectID,
                                fieldName: "Aircraft Type",
                                oldValue: existingType,
                                newValue: incomingType
                            ))
                        }
                        if !incomingReg.isEmpty && incomingReg != existingReg {
                            mergeProposals.append(MergeProposal(
                                flightDate: displayDate,
                                route: displayRoute,
                                objectID: existing.objectID,
                                fieldName: "Aircraft Reg",
                                oldValue: existingReg,
                                newValue: incomingReg
                            ))
                        }
                    }
                    duplicateCount += 1
                    print(" Skipping duplicate (UUID match): \(sector.date) \(sector.flightNumber) \(sector.aircraftReg)")
                    continue
                }

                // Check content-based duplicate
                let signature = "\(sector.date)|\(sector.flightNumber)|\(sector.fromAirport)|\(sector.toAirport)|\(sector.aircraftReg)|\(sector.aircraftType)"
                if contentBasedDuplicates.contains(signature) {
                    duplicateCount += 1
                    print(" Skipping duplicate (content match): \(sector.date) \(sector.flightNumber) \(sector.aircraftType)-\(sector.aircraftReg)")
                    continue
                }

                // Fuzzy duplicate check for WebCIS imports (no flight number):
                // matches on date ±1 day + from + to (reg excluded — webCIS reg wins on merge).
                // The ±1 day tolerance handles the UTC/local midnight offset that occurs
                // when manually-entered flights are stored with a local-time date but
                // WebCIS imports always store midnight UTC.
                if sector.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let normFrom = AirportService.shared.convertToICAO(sector.fromAirport)
                    let normTo   = AirportService.shared.convertToICAO(sector.toAirport)
                    let fuzzyKey = "\(sector.date)|\(normFrom)|\(normTo)"
                    if let existingObjectID = fuzzyDuplicates[fuzzyKey],
                       let existing = try? context.existingObject(with: existingObjectID) as? FlightEntity {
                        let incomingReg  = sector.aircraftReg.trimmingCharacters(in: .whitespacesAndNewlines)
                        let incomingType = sector.aircraftType.trimmingCharacters(in: .whitespacesAndNewlines)
                        let existingType = (existing.aircraftType ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let existingRegValue = (existing.aircraftReg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let displayDate = sector.date
                        let displayRoute = "\(sector.fromAirport) → \(sector.toAirport)"
                        if !incomingReg.isEmpty && incomingReg != existingRegValue {
                            mergeProposals.append(MergeProposal(
                                flightDate: displayDate,
                                route: displayRoute,
                                objectID: existing.objectID,
                                fieldName: "Aircraft Reg",
                                oldValue: existingRegValue,
                                newValue: incomingReg
                            ))
                        }
                        // Auto-fill blank aircraftType — no conflict, no user review needed
                        if !incomingType.isEmpty && existingType.isEmpty {
                            existing.aircraftType = incomingType
                            print(" Auto-filled blank aircraftType (fuzzy): \(displayDate) \(displayRoute)  \(incomingType)")
                        } else if !incomingType.isEmpty && incomingType != existingType {
                            mergeProposals.append(MergeProposal(
                                flightDate: displayDate,
                                route: displayRoute,
                                objectID: existing.objectID,
                                fieldName: "Aircraft Type",
                                oldValue: existingType,
                                newValue: incomingType
                            ))
                        }
                        duplicateCount += 1
                        print(" Skipping duplicate (fuzzy match): \(sector.date) \(sector.fromAirport)\(sector.toAirport)")
                        continue
                    }
                }

                // Sim duplicate check: if this sector has sim time, check whether any existing
                // entry already has the same date + sim time — regardless of reg/route, which
                // the user may have edited after the original import.
                let incomingSimTime = sector.simTime
                if !incomingSimTime.isEmpty, incomingSimTime != "0.00", incomingSimTime != "0.0", incomingSimTime != "0" {
                    let simKey = "\(sector.date)|\(incomingSimTime)"
                    if simDuplicates.contains(simKey) {
                        duplicateCount += 1
                        print(" Skipping duplicate (sim match): \(sector.date) sim=\(incomingSimTime)")
                        continue
                    }
                }

                // Parse and validate date
                guard let parsedDate = localDateFormatter.date(from: sector.date) else {
                    failureCount += 1
                    continue
                }

                let flight = FlightEntity(context: context)
                flight.id = sector.id
                flight.date = parsedDate
                flight.flightNumber = sector.flightNumber
                flight.aircraftReg = sector.aircraftReg
                flight.aircraftType = sector.aircraftType
                flight.fromAirport = sector.fromAirport
                flight.toAirport = sector.toAirport
                flight.captainName = sector.captainName
                flight.foName = sector.foName
                flight.so1Name = sector.so1Name
                flight.so2Name = sector.so2Name
                flight.blockTime = sector.blockTime
                flight.nightTime = sector.nightTime
                flight.p1Time = sector.p1Time
                flight.p1usTime = sector.p1usTime
                flight.p2Time = sector.p2Time
                flight.instrumentTime = sector.instrumentTime
                flight.simTime = sector.simTime
                flight.spInsTime = sector.spInsTime.isEmpty || sector.spInsTime == "0.00" || sector.spInsTime == "0.0" ? nil : sector.spInsTime
                flight.isPilotFlying = sector.isPilotFlying
                flight.isPositioning = sector.isPositioning
                flight.isAIII = sector.isAIII
                flight.isRNP = sector.isRNP
                flight.isILS = sector.isILS
                flight.isGLS = sector.isGLS
                flight.isNPA = sector.isNPA
                flight.safeRemarks = sector.remarks
                flight.dayTakeoffs = Int16(sector.dayTakeoffs)
                flight.dayLandings = Int16(sector.dayLandings)
                flight.nightTakeoffs = Int16(sector.nightTakeoffs)
                flight.nightLandings = Int16(sector.nightLandings)
                flight.outTime = sector.outTime
                flight.inTime = sector.inTime
                flight.scheduledDeparture = sector.scheduledDeparture
                flight.scheduledArrival = sector.scheduledArrival
                flight.importSessionID = sessionID
                flight.importedAt = Date()
                flight.createdAt = batchBaseTime.addingTimeInterval(Double(sectorIndex) * 0.001)
                flight.modifiedAt = Date()

                for (columnIndex, value) in sector.counterEntries where !value.isEmpty {
                    flight.setCounter(columnIndex, value: value)
                }

                successCount += 1

                // Flush every chunkSize inserts to keep WAL pages small
                if successCount % chunkSize == 0, context.hasChanges {
                    do {
                        try context.save()
                    } catch {
                        context.rollback()
                        print("Database: Chunk save failed at \(successCount) - \(error.localizedDescription)")
                        failureCount = sectors.count
                        successCount = 0
                        return
                    }
                }
            }

            // Step 4: Save any remaining flights not caught by the chunk boundary
            do {
                if context.hasChanges {
                    try context.save()
                    print("Database: Successfully saved \(successCount) flights")
                } else {
                    print("Database: No changes to save")
                }

                print("Batch save summary:")
                print("    Success: \(successCount)")
                print("    Duplicates: \(duplicateCount)")
                print("   Failures: \(failureCount)")

            } catch {
                context.rollback()
                print("Database: Batch save failed - \(error.localizedDescription)")
                failureCount = sectors.count
                successCount = 0
            }
        }

        return (successCount, failureCount, duplicateCount, sessionID, mergeProposals)
    }

    /// Applies a subset of approved merge proposals to Core Data and saves.
    /// Call this after the user has reviewed and confirmed their selection.
    public func applyMergeProposals(_ proposals: [MergeProposal]) {
        guard !proposals.isEmpty else { return }
        viewContext.performAndWait {
            var appliedCount = 0
            for proposal in proposals {
                guard let entity = try? viewContext.existingObject(with: proposal.objectID) as? FlightEntity else {
                    print("applyMergeProposals: could not find entity for \(proposal.flightDate) \(proposal.route)")
                    continue
                }
                switch proposal.fieldName {
                case "Aircraft Reg":
                    entity.aircraftReg = proposal.newValue
                case "Aircraft Type":
                    entity.aircraftType = proposal.newValue
                default:
                    print("applyMergeProposals: unknown field '\(proposal.fieldName)'")
                    continue
                }
                entity.modifiedAt = Date()
                appliedCount += 1
                print(" Applied merge: \(proposal.flightDate) \(proposal.route) \(proposal.fieldName): '\(proposal.oldValue)'  '\(proposal.newValue)'")
            }
            if viewContext.hasChanges {
                do {
                    try viewContext.save()
                    print("applyMergeProposals: saved \(appliedCount) change(s)")
                } catch {
                    viewContext.rollback()
                    print("applyMergeProposals: save failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Returns the most recent import sessions (up to 5), ordered newest first.
    /// Each entry contains the session UUID, import date, and flight count.
    public func fetchRecentImportSessions() -> [(id: UUID, date: Date, count: Int)] {
        var sessions: [(id: UUID, date: Date, count: Int)] = []
        viewContext.performAndWait {
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.predicate = NSPredicate(format: "importSessionID != nil")
            request.propertiesToFetch = ["importSessionID", "importedAt"]
            guard let flights = try? viewContext.fetch(request) else { return }

            var sessionMap: [UUID: (date: Date, count: Int)] = [:]
            for flight in flights {
                guard let sid = flight.importSessionID else { continue }
                let date = flight.importedAt ?? Date.distantPast
                if let existing = sessionMap[sid] {
                    sessionMap[sid] = (date: max(existing.date, date), count: existing.count + 1)
                } else {
                    sessionMap[sid] = (date: date, count: 1)
                }
            }
            sessions = sessionMap
                .map { (id: $0.key, date: $0.value.date, count: $0.value.count) }
                .sorted { $0.date > $1.date }
                .prefix(5)
                .map { $0 }
        }
        return sessions
    }

    /// Deletes all flights belonging to a specific import session.
    /// - Returns: Number of flights deleted.
    @discardableResult
    public func deleteImportSession(_ sessionID: UUID, actionDescription: String? = nil) -> Int {
        var deletedCount = 0
        viewContext.performAndWait {
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.predicate = NSPredicate(format: "importSessionID == %@", sessionID as CVarArg)
            guard let flights = try? viewContext.fetch(request) else { return }
            deletedCount = flights.count
            viewContext.undoManager?.beginUndoGrouping()
            for flight in flights {
                viewContext.delete(flight)
            }
            try? viewContext.save()
            viewContext.undoManager?.endUndoGrouping()
        }
        if deletedCount > 0 {
            undoableChangeCount += 1
            let importDesc = actionDescription ?? "Deleted import batch"
            undoDescriptions.append(importDesc)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .flightDataChanged, object: nil)
            }
        }
        return deletedCount
    }

    /// Regenerate UUIDs for all flights using the current deterministic UUID algorithm
    /// This updates all flights to use the new UUID generation logic that includes flight number
    /// - Returns: Tuple of (updated count, duplicate count removed, list of duplicate flight descriptions)
    public func regenerateAllFlightUUIDs() -> (updatedCount: Int, duplicatesRemoved: Int, duplicatesList: [String]) {
        print("Database: Starting UUID regeneration")

        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: true)]

        do {
            let allFlights = try viewContext.fetch(request)
            print("Processing \(allFlights.count) flights...")

            var updatedCount = 0
            var duplicatesRemoved = 0
            var duplicatesList: [String] = []
            var newUUIDMap: [UUID: FlightEntity] = [:] // Track new UUIDs to detect duplicates

            for flight in allFlights {
                guard let date = flight.date,
                      let flightNumber = flight.flightNumber,
                      let aircraftType = flight.aircraftType,
                      let aircraftReg = flight.aircraftReg,
                      let fromAirport = flight.fromAirport,
                      let toAirport = flight.toAirport,
                      let blockTime = flight.blockTime else {
                    print("Skipping flight with missing data")
                    continue
                }

                // Generate new UUID using the same logic as FileImportService
                let dateString = dateFormatter.string(from: date)

                // For flights without a flight number, add OUT/IN times to ensure uniqueness
                var uniqueString: String
                if flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // No flight number - use OUT/IN times and simTime for additional uniqueness
                    // Must match FileImportService uniqueString formula exactly
                    let outTime = flight.outTime ?? ""
                    let inTime = flight.inTime ?? ""
                    let simTime = flight.simTime ?? ""
                    uniqueString = "\(dateString)-\(aircraftType)-\(aircraftReg)-\(fromAirport)-\(toAirport)-\(outTime)-\(inTime)-\(blockTime)-\(simTime)"
                } else {
                    // Normal flight with flight number
                    uniqueString = "\(dateString)-\(flightNumber)-\(aircraftType)-\(aircraftReg)-\(fromAirport)-\(toAirport)-\(blockTime)"
                }

                guard let newUUID = UUID(uuidString: uniqueString.md5UUID()) else {
                    print("Failed to generate UUID for flight: \(dateString) \(flightNumber)")
                    continue
                }

                // Check if this new UUID already exists in our map (duplicate)
                if let existingFlight = newUUIDMap[newUUID] {
                    // Build duplicate description
                    let duplicateDescription = "\(dateString) \(flightNumber) \(aircraftType)-\(aircraftReg) \(fromAirport)-\(toAirport)"
                    duplicatesList.append(duplicateDescription)

                    // Log the UUID generation details for debugging
                    print("DUPLICATE UUID COLLISION DETECTED:")
                    print("   UUID: \(newUUID)")
                    print("   Unique String: '\(uniqueString)'")
                    print("   Current Flight: \(duplicateDescription)")
                    if let existingDate = existingFlight.date,
                       let existingFlightNum = existingFlight.flightNumber,
                       let existingType = existingFlight.aircraftType,
                       let existingReg = existingFlight.aircraftReg,
                       let existingFrom = existingFlight.fromAirport,
                       let existingTo = existingFlight.toAirport {
                        let existingDateStr = dateFormatter.string(from: existingDate)
                        print("   Existing Flight: \(existingDateStr) \(existingFlightNum) \(existingType)-\(existingReg) \(existingFrom)-\(existingTo)")
                    }

                    // Duplicate found - keep the one with earlier createdAt
                    if let existingCreatedAt = existingFlight.createdAt,
                       let currentCreatedAt = flight.createdAt,
                       currentCreatedAt < existingCreatedAt {
                        // Current flight is older, delete the existing one and keep this
                        print(" Duplicate detected - keeping older flight (created: \(currentCreatedAt))")
                        print("   Flight: \(duplicateDescription)")
                        viewContext.delete(existingFlight)
                        newUUIDMap[newUUID] = flight
                        flight.id = newUUID
                        duplicatesRemoved += 1
                        updatedCount += 1
                    } else {
                        // Existing flight is older, delete current
                        print(" Duplicate detected - keeping older flight (existing)")
                        print("   Flight: \(duplicateDescription)")
                        viewContext.delete(flight)
                        duplicatesRemoved += 1
                    }
                } else {
                    // No duplicate, update UUID
                    let oldUUID = flight.id
                    flight.id = newUUID
                    newUUIDMap[newUUID] = flight
                    updatedCount += 1

                    if oldUUID != newUUID {
                        print(" Updated UUID for \(dateString) \(flightNumber)")
                    }
                }
            }

            // Save all changes
            if viewContext.hasChanges {
                try viewContext.save()
                print("Database: UUID regeneration complete:")
                print("    Updated: \(updatedCount) flights")
                print("    Removed duplicates: \(duplicatesRemoved)")

                if !duplicatesList.isEmpty {
                    print("    Duplicates removed:")
                    for duplicate in duplicatesList {
                        print("       \(duplicate)")
                    }
                }

                // Notify views to refresh
                DispatchQueue.main.async {
                    print("FlightDatabaseService: Posting .flightDataChanged (regenerateUUIDs)")
                    NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                }
            } else {
                print(" No changes needed")
            }

            return (updatedCount, duplicatesRemoved, duplicatesList)

        } catch {
            print("Database: Error regenerating UUIDs - \(error.localizedDescription)")
            return (0, 0, [])
        }
    }

    /// Migrate simulator flights to use exclusive blockTime/simTime fields
    /// Fixes bug where AddFlightView created sim flights with BOTH fields populated
    /// - Returns: Tuple of (migrated count, migration summary)
    public func migrateSimulatorFlights() -> (migratedCount: Int, summary: String) {
        print("Database: Starting simulator flight migration")

        var migratedCount = 0
        var migratedFlights: [String] = []

        viewContext.performAndWait {
            // Find flights with BOTH simTime > 0 AND blockTime > 0 (bug signature)
            // EXCLUDE Summary Rows (flightNumber = "SUMMARY") which legitimately have both fields
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "(simTime != %@ AND simTime != %@ AND simTime != %@) AND (blockTime != %@ AND blockTime != %@ AND blockTime != %@) AND (flightNumber != %@)",
                "0", "0.0", "0.00", "0", "0.0", "0.00", "SUMMARY"
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)]

            do {
                let flights = try viewContext.fetch(request)
                print("Found \(flights.count) simulator flights needing migration")

                for flight in flights {
                    guard let simTime = flight.simTime,
                          let blockTime = flight.blockTime,
                          let simValue = Double(simTime), simValue > 0,
                          let blockValue = Double(blockTime), blockValue > 0 else {
                        continue
                    }

                    // Build flight description for logging
                    let dateStr = flight.date.map { dateFormatter.string(from: $0) } ?? "unknown"
                    let flightNum = flight.flightNumber ?? "unknown"
                    let aircraftReg = flight.aircraftReg ?? "unknown"
                    let description = "\(dateStr) \(flightNum) \(aircraftReg) - block:\(blockTime) sim:\(simTime)"

                    // Verify both values are identical (expected for this bug)
                    // If different, might be a different issue - log warning and skip
                    if abs(simValue - blockValue) > 0.01 {
                        print(" Skipping flight with different block/sim times: \(description)")
                        continue
                    }

                    // Fix: Set blockTime to 0.0, keep simTime
                    print("Migrating: \(description)  block:0.0 sim:\(simTime)")
                    flight.blockTime = "0.0"
                    flight.modifiedAt = Date()

                    migratedFlights.append(description)
                    migratedCount += 1
                }

                // Save all changes in one transaction
                if viewContext.hasChanges {
                    try viewContext.save()
                    print(" Successfully migrated \(migratedCount) simulator flights")
                }

            } catch {
                print("Error during simulator flight migration: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }

        // Build summary
        let summary = """
        Simulator Flight Migration Complete
        Migrated: \(migratedCount) flights

        Details:
        \(migratedFlights.isEmpty ? "No flights needed migration" : migratedFlights.prefix(10).joined(separator: "\n"))
        \(migratedCount > 10 ? "... and \(migratedCount - 10) more" : "")
        """

        return (migratedCount, summary)
    }

    /// One-time migration: zero out p1Time/p1usTime/p2Time/nightTime/instrumentTime on SIM flights (simTime > 0).
    /// These fields were incorrectly populated before the save-logic fix.
    public func migrateSimP1Times() -> Int {
        var migratedCount = 0
        viewContext.performAndWait {
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            // Find SIM flights with a non-zero value in any field that should be zero
            request.predicate = NSPredicate(
                format: "(simTime != %@ AND simTime != %@ AND simTime != %@) AND (flightNumber != %@) AND ((p1Time != %@ AND p1Time != %@ AND p1Time != %@) OR (p1usTime != %@ AND p1usTime != %@ AND p1usTime != %@) OR (p2Time != %@ AND p2Time != %@ AND p2Time != %@) OR (nightTime != %@ AND nightTime != %@ AND nightTime != %@) OR (instrumentTime != %@ AND instrumentTime != %@ AND instrumentTime != %@))",
                "0", "0.0", "0.00", "SUMMARY",
                "0", "0.0", "0.00",
                "0", "0.0", "0.00",
                "0", "0.0", "0.00",
                "0", "0.0", "0.00",
                "0", "0.0", "0.00"
            )
            do {
                let flights = try viewContext.fetch(request)
                for flight in flights {
                    guard let simTime = flight.simTime, let sv = Double(simTime), sv > 0 else { continue }
                    flight.p1Time = "0.0"
                    flight.p1usTime = "0.0"
                    flight.p2Time = "0.0"
                    flight.nightTime = "0.0"
                    flight.instrumentTime = "0.0"
                    flight.modifiedAt = Date()
                    migratedCount += 1
                }
                if viewContext.hasChanges { try viewContext.save() }
            } catch {
                print("migrateSimP1Times error: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }
        print("migrateSimP1Times: zeroed p1/p1us/p2/night/instrument on \(migratedCount) SIM flights")
        return migratedCount
    }

    /// One-time migration: copy customCount integer into counter1 string column for all flights
    /// where customCount > 0 and counter1 is not already set.
    public func migrateLegacyCustomCounterToColumn1() -> Int {
        var migratedCount = 0
        viewContext.performAndWait {
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.predicate = NSPredicate(format: "customCount > 0")
            do {
                let flights = try viewContext.fetch(request)
                for flight in flights {
                    // Only write if counter1 is not already populated
                    guard flight.counter1 == nil || flight.counter1!.isEmpty else { continue }
                    flight.counter1 = String(flight.customCount)
                    flight.modifiedAt = Date()
                    migratedCount += 1
                }
                if viewContext.hasChanges { try viewContext.save() }
            } catch {
                print("migrateLegacyCustomCounterToColumn1 error: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }
        print("migrateLegacyCustomCounterToColumn1: copied customCount  counter1 on \(migratedCount) flights")
        return migratedCount
    }

    /// One-time migration: update aircraftType from "A321" to "A21N" for the Qantas XLR fleet.
    /// Only affects OGA–OGG registrations (with or without VH- prefix).
    public func migrateAircraftTypeA321ToA21N() -> (migratedCount: Int, summary: String) {
        let xlrRegistrations = [
            "OGA", "OGB", "OGC", "OGD", "OGE", "OGF", "OGG",
            "VH-OGA", "VH-OGB", "VH-OGC", "VH-OGD", "VH-OGE", "VH-OGF", "VH-OGG"
        ]
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "aircraftType == %@ AND aircraftReg IN %@",
            "A321", xlrRegistrations
        )

        do {
            let flights = try viewContext.fetch(request)
            guard !flights.isEmpty else { return (0, "No A321 XLR records found.") }

            for flight in flights {
                flight.aircraftType = "A21N"
                flight.modifiedAt = Date()
            }

            try viewContext.save()
            return (flights.count, "Updated \(flights.count) flight(s) from A321 → A21N.")
        } catch {
            print("A321A21N migration failed: \(error.localizedDescription)")
            return (0, "Migration failed: \(error.localizedDescription)")
        }
    }

    /// Remove duplicate flights from the database
    /// Duplicates are identified by matching: date, flightNumber, fromAirport, toAirport, aircraftReg, and aircraftType
    /// When duplicates are found, keeps the one with the earliest createdAt timestamp
    /// - Returns: Number of duplicate flights removed
    public func removeDuplicateFlights() -> Int {
        print("Database: Starting duplicate detection and removal")

        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: true)]

        do {
            let allFlights = try viewContext.fetch(request)
            print("Checking \(allFlights.count) flights for duplicates...")

            // Group flights by content signature
            var flightsBySignature: [String: [FlightEntity]] = [:]

            for flight in allFlights {
                guard let date = flight.date,
                      let flightNumber = flight.flightNumber,
                      let fromAirport = flight.fromAirport,
                      let toAirport = flight.toAirport,
                      let aircraftReg = flight.aircraftReg,
                      let aircraftType = flight.aircraftType else {
                    continue
                }

                let dateString = dateFormatter.string(from: date)
                let signature = "\(dateString)|\(flightNumber)|\(fromAirport)|\(toAirport)|\(aircraftReg)|\(aircraftType)"

                if flightsBySignature[signature] == nil {
                    flightsBySignature[signature] = []
                }
                flightsBySignature[signature]?.append(flight)
            }

            // Find and remove duplicates
            var duplicatesRemoved = 0

            for (signature, flights) in flightsBySignature where flights.count > 1 {
                print("Found \(flights.count) duplicates for: \(signature)")

                // Sort by createdAt to keep the oldest one
                let sortedFlights = flights.sorted { flight1, flight2 in
                    guard let date1 = flight1.createdAt,
                          let date2 = flight2.createdAt else {
                        return false
                    }
                    return date1 < date2
                }

                // Keep the first (oldest), delete the rest
                let toKeep = sortedFlights.first!
                let toDelete = sortedFlights.dropFirst()

                                print("    Keeping flight created at: \(toKeep.createdAt ?? Date()) (UUID: \(toKeep.id?.uuidString ?? "unknown"))")

                for duplicate in toDelete {
                                    print("   Deleting duplicate created at: \(duplicate.createdAt ?? Date()) (UUID: \(duplicate.id?.uuidString ?? "unknown"))")
                    viewContext.delete(duplicate)
                    duplicatesRemoved += 1
                }
            }

            // Save changes
            if duplicatesRemoved > 0 {
                try viewContext.save()
                print("Database: Removed \(duplicatesRemoved) duplicate flights")

                // Notify views to refresh
                DispatchQueue.main.async {
                    print("FlightDatabaseService: Posting .flightDataChanged (removeDuplicates)")
                    NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                }
            } else {
                print("Database: No duplicate flights found")
            }

            return duplicatesRemoved

        } catch {
            print("Database: Error removing duplicates - \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Debounced Notification
    /// Post a debounced notification to prevent rapid successive updates
    private func postDebouncedFlightDataChangedNotification() {
        // Cancel any existing timer
        notificationDebounceTimer?.invalidate()

        // Create new timer that will fire after the debounce interval
        notificationDebounceTimer = Timer.scheduledTimer(withTimeInterval: notificationDebounceInterval, repeats: false) { _ in
            DispatchQueue.main.async {
                if self.isAppInBackground {
                    self.pendingDataChanged = true
                    print("FlightDatabaseService: Deferred .flightDataChanged (app in background, debounced)")
                } else {
                    print("FlightDatabaseService: Posting .flightDataChanged (debounced)")
                    NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                    // Refresh widget snapshot whenever flight data changes
                    Task { @MainActor in
                        WidgetDataWriter.shared.updateWidgetSnapshot()
                    }
                }
            }
        }
    }

    /// Get comprehensive flight statistics (excludes rostered/future flights with blockTime == 0 and simTime == 0)
    public func getFlightStatistics() -> FlightStatistics {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        // Exclude rostered and positioning flights; include completed block, sim, or instructor time.
        // spInsTime check is needed so INS Sim sessions with 0 SIM (observer role) are not excluded.
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isPositioning == NO OR isPositioning == nil"),
            NSPredicate(format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@) OR (spInsTime != %@ AND spInsTime != %@ AND spInsTime != %@)", "0", "0.0", "0.00", "0", "0.0", "0.00", "0", "0.0", "0.00")
        ])

        do {
            let flights = try viewContext.fetch(request)

            var totalBlock: Double = 0
            var totalP1: Double = 0
            var totalP1US: Double = 0
            var totalP2: Double = 0
            var totalNight: Double = 0
            var totalInstrument: Double = 0
            var totalSIM: Double = 0
            var totalSpIns: Double = 0
            var totalSpInsSim: Double = 0
            var totalSpInsFlt: Double = 0
            var spInsFltCount = 0
            var spInsSimCount = 0
            let totalSectors = flights.count
            var aiiiSectors = 0
            var pfSectors = 0
            var airports = Set<String>()

            for flight in flights {
                let blockTime = safeDoubleFromString(flight.blockTime)
                let flightSimTime = safeDoubleFromString(flight.simTime)
                let isSimFlight = blockTime == 0 && flightSimTime > 0
                totalBlock += blockTime
                if !isSimFlight {
                    totalP1 += safeDoubleFromString(flight.p1Time)
                    totalP1US += safeDoubleFromString(flight.p1usTime)
                    totalP2 += safeDoubleFromString(flight.p2Time)
                }
                totalNight += safeDoubleFromString(flight.nightTime)
                totalInstrument += safeDoubleFromString(flight.instrumentTime)
                totalSIM += flightSimTime
                let spVal = safeDoubleFromString(flight.spInsTime)
                totalSpIns += spVal
                if entityIsSpInsOnly(flight) {
                    totalSpInsSim += spVal
                    if spVal > 0 { spInsSimCount += 1 }
                } else if spVal > 0 {
                    totalSpInsFlt += spVal
                    spInsFltCount += 1
                }
                if flight.isAIII { aiiiSectors += 1 }
                if flight.isPilotFlying { pfSectors += 1 }
                if let a = flight.fromAirport, !a.isEmpty { airports.insert(a) }
                if let a = flight.toAirport,   !a.isEmpty { airports.insert(a) }
            }

            return FlightStatistics(
                totalSectors: totalSectors,
                totalBlockTime: totalBlock,
                totalP1Time: totalP1,
                totalP1USTime: totalP1US,
                totalP2Time: totalP2,
                totalNightTime: totalNight,
                totalInstrumentTime: totalInstrument,
                totalSIMTime: totalSIM,
                totalSpInsTime: totalSpIns,
                totalSpInsSimTime: totalSpInsSim,
                totalSpInsFltTime: totalSpInsFlt,
                spInsFltCount: spInsFltCount,
                spInsSimCount: spInsSimCount,
                aiiiSectors: aiiiSectors,
                pfSectors: pfSectors,
                totalAirports: airports.count
            )

        } catch {
            return FlightStatistics.empty
        }
    }

    /// Background-context variant used by getInsightsData(). Caller is responsible for
    /// calling this on the correct thread for the supplied context.
    public func getFlightStatistics(context: NSManagedObjectContext) -> FlightStatistics {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isPositioning == NO OR isPositioning == nil"),
            NSPredicate(format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@) OR (spInsTime != %@ AND spInsTime != %@ AND spInsTime != %@)", "0", "0.0", "0.00", "0", "0.0", "0.00", "0", "0.0", "0.00")
        ])

        do {
            let flights = try context.fetch(request)

            var totalBlock: Double = 0
            var totalP1: Double = 0
            var totalP1US: Double = 0
            var totalP2: Double = 0
            var totalNight: Double = 0
            var totalInstrument: Double = 0
            var totalSIM: Double = 0
            var totalSpIns: Double = 0
            var totalSpInsSim: Double = 0
            var totalSpInsFlt: Double = 0
            var spInsFltCount = 0
            var spInsSimCount = 0
            let totalSectors = flights.count
            var aiiiSectors = 0
            var pfSectors = 0
            var airports = Set<String>()

            for flight in flights {
                let blockTime = safeDoubleFromString(flight.blockTime)
                let flightSimTime = safeDoubleFromString(flight.simTime)
                let isSimFlight = blockTime == 0 && flightSimTime > 0
                totalBlock      += blockTime
                if !isSimFlight {
                    totalP1     += safeDoubleFromString(flight.p1Time)
                    totalP1US   += safeDoubleFromString(flight.p1usTime)
                    totalP2     += safeDoubleFromString(flight.p2Time)
                }
                totalNight      += safeDoubleFromString(flight.nightTime)
                totalInstrument += safeDoubleFromString(flight.instrumentTime)
                totalSIM        += flightSimTime
                let spVal = safeDoubleFromString(flight.spInsTime)
                totalSpIns += spVal
                if entityIsSpInsOnly(flight) {
                    totalSpInsSim += spVal
                    if spVal > 0 { spInsSimCount += 1 }
                } else if spVal > 0 {
                    totalSpInsFlt += spVal
                    spInsFltCount += 1
                }
                if flight.isAIII { aiiiSectors += 1 }
                if flight.isPilotFlying { pfSectors += 1 }
                if let a = flight.fromAirport, !a.isEmpty { airports.insert(a) }
                if let a = flight.toAirport,   !a.isEmpty { airports.insert(a) }
            }

            return FlightStatistics(
                totalSectors: totalSectors,
                totalBlockTime: totalBlock,
                totalP1Time: totalP1,
                totalP1USTime: totalP1US,
                totalP2Time: totalP2,
                totalNightTime: totalNight,
                totalInstrumentTime: totalInstrument,
                totalSIMTime: totalSIM,
                totalSpInsTime: totalSpIns,
                totalSpInsSimTime: totalSpInsSim,
                totalSpInsFltTime: totalSpInsFlt,
                spInsFltCount: spInsFltCount,
                spInsSimCount: spInsSimCount,
                aiiiSectors: aiiiSectors,
                pfSectors: pfSectors,
                totalAirports: airports.count
            )
        } catch {
            return FlightStatistics.empty
        }
    }

    /// Get statistics for a specific date range
    public func getFlightStatistics(from startDateString: String, to endDateString: String) -> FlightStatistics {
        let flights = fetchFlights(from: startDateString, to: endDateString)

        // DEBUG: Log flights on boundary dates
        if startDateString.contains("17/11/2025") {
            let flightsOn17th = flights.filter { $0.date == "17/11/2025" }
            print("Dashboard: Found \(flightsOn17th.count) flights on 17/11/2025")
            for flight in flightsOn17th {
                print("  Flight on 17/11/2025: block=\(flight.blockTime), sim=\(flight.simTime)")
            }
        }

        var totalBlock: Double = 0
        var totalP1: Double = 0
        var totalP1US: Double = 0
        var totalP2: Double = 0
        var totalNight: Double = 0
        var totalInstrument: Double = 0
        var totalSIM: Double = 0
        var totalSpIns: Double = 0
        var totalSpInsSim: Double = 0
        var totalSpInsFlt: Double = 0
        var spInsFltCount = 0
        var spInsSimCount = 0
        let totalSectors = flights.count
        var aiiiSectors = 0
        var pfSectors = 0
        var airports = Set<String>()

        for flight in flights {
            guard !flight.isPositioning else { continue }
            let isSimFlight = flight.blockTimeValue == 0 && flight.simTimeValue > 0
            totalBlock += flight.blockTimeValue
            if !isSimFlight {
                totalP1 += flight.p1TimeValue
                totalP1US += flight.p1usTimeValue
                totalP2 += flight.p2TimeValue
            }
            totalNight += flight.nightTimeValue
            totalInstrument += flight.instrumentTimeValue
            totalSIM += flight.simTimeValue
            let spVal = flight.spInsTimeValue
            totalSpIns += spVal
            if flight.isSpInsOnly {
                totalSpInsSim += spVal
                if spVal > 0 { spInsSimCount += 1 }
            } else if spVal > 0 {
                totalSpInsFlt += spVal
                spInsFltCount += 1
            }
            if flight.isAIII { aiiiSectors += 1 }
            if flight.isPilotFlying { pfSectors += 1 }
            if !flight.fromAirport.isEmpty { airports.insert(flight.fromAirport) }
            if !flight.toAirport.isEmpty   { airports.insert(flight.toAirport) }
        }

        return FlightStatistics(
            totalSectors: totalSectors,
            totalBlockTime: totalBlock,
            totalP1Time: totalP1,
            totalP1USTime: totalP1US,
            totalP2Time: totalP2,
            totalNightTime: totalNight,
            totalInstrumentTime: totalInstrument,
            totalSIMTime: totalSIM,
            totalSpInsTime: totalSpIns,
            totalSpInsSimTime: totalSpInsSim,
            totalSpInsFltTime: totalSpInsFlt,
            spInsFltCount: spInsFltCount,
            spInsSimCount: spInsSimCount,
            aiiiSectors: aiiiSectors,
            pfSectors: pfSectors,
            totalAirports: airports.count
        )
    }
    // MARK: - Helper Methods
    /// Convert Core Data entity to FlightSector model
    private func convertToFlightSector(_ entity: FlightEntity) -> FlightSector? {
        guard let id = entity.id,
              let date = entity.date,
              let flightNumber = entity.flightNumber,
              let aircraftReg = entity.aircraftReg,
              let aircraftType = entity.aircraftType,
              let fromAirport = entity.fromAirport,
              let toAirport = entity.toAirport,
              let captainName = entity.captainName,
              let foName = entity.foName,
              let blockTime = entity.blockTime,
              let nightTime = entity.nightTime,
              let p1Time = entity.p1Time,
              let p1usTime = entity.p1usTime,
              let instrumentTime = entity.instrumentTime,
              let simTime = entity.simTime else {
            return nil
        }

        // Convert Date back to string for FlightSector
        let dateString = dateFormatter.string(from: date)

        return FlightSector(
            id: id,
            date: dateString,
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: fromAirport,
            toAirport: toAirport,
            captainName: captainName,
            foName: foName,
            so1Name: entity.so1Name,
            so2Name: entity.so2Name,
            blockTime: blockTime,
            nightTime: nightTime,
            p1Time: p1Time,
            p1usTime: p1usTime,
            p2Time: entity.p2Time ?? "0.0",
            instrumentTime: instrumentTime,
            simTime: simTime,
            spInsTime: entity.spInsTime ?? "",
            isPilotFlying: entity.isPilotFlying,
            isPositioning: entity.isPositioning,
            isAIII: entity.isAIII,
            isRNP: entity.isRNP,
            isILS: entity.isILS,
            isGLS: entity.isGLS,
            isNPA: entity.isNPA,
            remarks: entity.safeRemarks,
            dayTakeoffs: Int(entity.dayTakeoffs),
            dayLandings: Int(entity.dayLandings),
            nightTakeoffs: Int(entity.nightTakeoffs),
            nightLandings: Int(entity.nightLandings),
            outTime: entity.outTime ?? "",
            inTime: entity.inTime ?? "",
            scheduledDeparture: entity.scheduledDeparture ?? "",
            scheduledArrival: entity.scheduledArrival ?? "",
            counterEntries: counterEntriesDict(from: entity),
            createdAt: entity.createdAt
        )
    }

    private func counterEntriesDict(from entity: FlightEntity) -> [Int: String] {
        var result: [Int: String] = [:]
        for index in 1...10 {
            if let value = entity.counterValue(at: index), !value.isEmpty {
                result[index] = value
            }
        }
        return result
    }

    /// Safely convert string to double with validation
    private func entityIsSpInsOnly(_ flight: FlightEntity) -> Bool {
        safeDoubleFromString(flight.spInsTime) > 0 && safeDoubleFromString(flight.blockTime) < 0.01
    }

    private func safeDoubleFromString(_ string: String?) -> Double {
        guard let string = string,
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let value = Double(string),
              value.isFinite,
              value >= 0 else {
            return 0.0
        }
        return value
    }
    /// Check if database is empty
    public func isDatabaseEmpty() -> Bool {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: request)
            return count == 0
        } catch {
            return true
        }
    }
    /// Get total number of flights
    public func getFlightCount() -> Int {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        
        do {
            return try viewContext.count(for: request)
        } catch {
            return 0
        }
    }
    /// Get the date of the last PF sector (excludes rostered/future flights with blockTime == 0, but includes SIM flights)
    public func getLastPFDate() -> Date? {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        // Include PF flights that have either:
        // 1. Non-zero blockTime (actual flights), OR
        // 2. Non-zero simTime (simulator sessions)
        // This excludes only rostered flights (zero blockTime AND zero simTime)
        request.predicate = NSPredicate(format: "isPilotFlying == YES AND ((blockTime != %@ AND blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@ AND simTime != %@))",
            "0", "0.0", "0.00", "",  // blockTime conditions
            "0", "0.0", "0.00", "")  // simTime conditions
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)]
        request.fetchLimit = 1

        do {
            let flights = try viewContext.fetch(request)
            return flights.first?.date
        } catch {
            return nil
        }
    }

    /// Get days since last PF sector (excludes rostered/future flights with blockTime == 0)
    public func getDaysSinceLastPF() -> Int? {
        guard let lastPFDate = getLastPFDate() else {
            return nil // No PF sectors found
        }

        // Flight dates are stored as UTC midnight but represent a calendar date
        // We need to extract just the date components and compare in UTC to match storage
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date()

        // Get the date components in UTC (matching how dates are stored)
        let lastPFDateComponents = utcCalendar.dateComponents([.year, .month, .day], from: lastPFDate)
        let nowComponents = utcCalendar.dateComponents([.year, .month, .day], from: now)

        // Recreate dates at midnight UTC for clean comparison
        guard let lastPFMidnight = utcCalendar.date(from: lastPFDateComponents),
              let todayMidnight = utcCalendar.date(from: nowComponents) else {
            return nil
        }

        let components = utcCalendar.dateComponents([.day], from: lastPFMidnight, to: todayMidnight)
        return components.day ?? 0
    }
    /// Get the date of the last AIII sector (excludes rostered/future flights with blockTime == 0, but includes SIM flights)
    public func getLastAIIIDate() -> Date? {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        // Include AIII flights that have either:
        // 1. Non-zero blockTime (actual flights), OR
        // 2. Non-zero simTime (simulator sessions)
        // This excludes only rostered flights (zero blockTime AND zero simTime)
        request.predicate = NSPredicate(format: "isAIII == YES AND ((blockTime != %@ AND blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@ AND simTime != %@))",
            "0", "0.0", "0.00", "",  // blockTime conditions
            "0", "0.0", "0.00", "")  // simTime conditions
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)]
        request.fetchLimit = 1

        do {
            let flights = try viewContext.fetch(request)
            return flights.first?.date
        } catch {
            return nil
        }
    }

    /// Get days since last AIII sector (excludes rostered/future flights with blockTime == 0)
    public func getDaysSinceLastAIII() -> Int? {
        guard let lastAIIIDate = getLastAIIIDate() else {
            return nil // No AIII sectors found
        }

        // Flight dates are stored as UTC midnight but represent a calendar date
        // We need to extract just the date components and compare in UTC to match storage
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date()

        // Get the date components in UTC (matching how dates are stored)
        let lastAIIIDateComponents = utcCalendar.dateComponents([.year, .month, .day], from: lastAIIIDate)
        let nowComponents = utcCalendar.dateComponents([.year, .month, .day], from: now)

        // Recreate dates at midnight UTC for clean comparison
        guard let lastAIIIMidnight = utcCalendar.date(from: lastAIIIDateComponents),
              let todayMidnight = utcCalendar.date(from: nowComponents) else {
            return nil
        }

        let components = utcCalendar.dateComponents([.day], from: lastAIIIMidnight, to: todayMidnight)
        return components.day ?? 0
    }

    /// Get the date of the last takeoff (day or night) (excludes rostered/future flights with blockTime == 0, but includes SIM flights)
    public func getLastTakeoffDate() -> Date? {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        // Include flights with takeoffs that have either:
        // 1. Non-zero blockTime (actual flights), OR
        // 2. Non-zero simTime (simulator sessions)
        // This excludes only rostered flights (zero blockTime AND zero simTime)
        request.predicate = NSPredicate(format: "(dayTakeoffs > 0 OR nightTakeoffs > 0) AND ((blockTime != %@ AND blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@ AND simTime != %@))",
            "0", "0.0", "0.00", "",  // blockTime conditions
            "0", "0.0", "0.00", "")  // simTime conditions
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)]
        request.fetchLimit = 1

        do {
            let flights = try viewContext.fetch(request)
            return flights.first?.date
        } catch {
            return nil
        }
    }

    /// Get days since last takeoff (day or night) (excludes rostered/future flights with blockTime == 0)
    public func getDaysSinceLastTakeoff() -> Int? {
        guard let lastTakeoffDate = getLastTakeoffDate() else {
            return nil // No takeoffs found
        }

        // Flight dates are stored as UTC midnight but represent a calendar date
        // We need to extract just the date components and compare in UTC to match storage
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date()

        // Get the date components in UTC (matching how dates are stored)
        let lastTakeoffDateComponents = utcCalendar.dateComponents([.year, .month, .day], from: lastTakeoffDate)
        let nowComponents = utcCalendar.dateComponents([.year, .month, .day], from: now)

        // Recreate dates at midnight UTC for clean comparison
        guard let lastTakeoffMidnight = utcCalendar.date(from: lastTakeoffDateComponents),
              let todayMidnight = utcCalendar.date(from: nowComponents) else {
            return nil
        }

        let components = utcCalendar.dateComponents([.day], from: lastTakeoffMidnight, to: todayMidnight)
        return components.day ?? 0
    }

    /// Get the date of the last landing (day or night) (excludes rostered/future flights with blockTime == 0, but includes SIM flights)
    public func getLastLandingDate() -> Date? {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        // Include flights with landings that have either:
        // 1. Non-zero blockTime (actual flights), OR
        // 2. Non-zero simTime (simulator sessions)
        // This excludes only rostered flights (zero blockTime AND zero simTime)
        request.predicate = NSPredicate(format: "(dayLandings > 0 OR nightLandings > 0) AND ((blockTime != %@ AND blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@ AND simTime != %@))",
            "0", "0.0", "0.00", "",  // blockTime conditions
            "0", "0.0", "0.00", "")  // simTime conditions
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: false)]
        request.fetchLimit = 1

        do {
            let flights = try viewContext.fetch(request)
            return flights.first?.date
        } catch {
            return nil
        }
    }

    /// Get days since last landing (day or night) (excludes rostered/future flights with blockTime == 0)
    public func getDaysSinceLastLanding() -> Int? {
        guard let lastLandingDate = getLastLandingDate() else {
            return nil // No landings found
        }

        // Flight dates are stored as UTC midnight but represent a calendar date
        // We need to extract just the date components and compare in UTC to match storage
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date()

        // Get the date components in UTC (matching how dates are stored)
        let lastLandingDateComponents = utcCalendar.dateComponents([.year, .month, .day], from: lastLandingDate)
        let nowComponents = utcCalendar.dateComponents([.year, .month, .day], from: now)

        // Recreate dates at midnight UTC for clean comparison
        guard let lastLandingMidnight = utcCalendar.date(from: lastLandingDateComponents),
              let todayMidnight = utcCalendar.date(from: nowComponents) else {
            return nil
        }

        let components = utcCalendar.dateComponents([.day], from: lastLandingMidnight, to: todayMidnight)
        return components.day ?? 0
    }
    /// Get flight hours for rolling period (e.g., last 28 days)
    public func getFlightHoursForRollingPeriod(days: Int = 28) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current

        let now = Date()
        // Normalize to start of day for consistent comparison
        let endOfPeriod = calendar.startOfDay(for: now)
        let startOfPeriod = calendar.date(byAdding: .day, value: -days, to: endOfPeriod)!

        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startOfPeriod as NSDate, endOfPeriod as NSDate)
        
        do {
            let flights = try viewContext.fetch(request)
            let totalHours = flights.reduce(0.0) { sum, flight in
                let blockTime = safeDoubleFromString(flight.blockTime)
                let simTime = safeDoubleFromString(flight.simTime)
                return sum + (blockTime > 0 ? blockTime : simTime)
            }
            return totalHours
        } catch {
            return 0.0
        }
    }
    /// Get all unique aircraft types in the database
    public func getAllAircraftTypes() -> [String] {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        // Exclude PAX flights from the aircraft type filter list
        request.predicate = NSPredicate(format: "isPositioning == NO OR isPositioning == nil")

        do {
            let flights = try viewContext.fetch(request)
            print("getAllAircraftTypes: Fetched \(flights.count) flights from database")

            let aircraftTypes = flights.compactMap { flight -> String? in
                guard let rawType = flight.aircraftType else {
                    return nil
                }
                let aircraftType = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
                // Accept aircraft types with 3+ characters (excludes empty and very short strings)
                guard !aircraftType.isEmpty, aircraftType.count >= 3 else {
                    return nil
                }
                return aircraftType
            }
            // Remove duplicates and sort
            let uniqueTypes = Array(Set(aircraftTypes)).sorted()
            print("getAllAircraftTypes: Found \(uniqueTypes.count) unique types") //: \(uniqueTypes)")
            return uniqueTypes
        } catch {
            print("getAllAircraftTypes: Fetch error - \(error.localizedDescription)")
            return []
        }
    }

    /// Get all unique aircraft registrations in the database
    public func getAllAircraftRegistrations() -> [String] {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FlightEntity")
        request.returnsDistinctResults = true
        request.propertiesToFetch = ["aircraftReg"]
        request.resultType = .dictionaryResultType

        do {
            let results = try viewContext.fetch(request)
            let aircraftRegs = results.compactMap { result -> String? in
                guard let dict = result as? [String: Any],
                      let aircraftReg = dict["aircraftReg"] as? String,
                      !aircraftReg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return aircraftReg.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return Array(Set(aircraftRegs)).sorted()
        } catch {
            return []
        }
    }

    /// Get all unique captain names in the database
    public func getAllCaptainNames() -> [String] {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FlightEntity")
        request.returnsDistinctResults = true
        request.propertiesToFetch = ["captainName"]
        request.resultType = .dictionaryResultType

        do {
            let results = try viewContext.fetch(request)
            let names = results.compactMap { result -> String? in
                guard let dict = result as? [String: Any],
                      let name = dict["captainName"] as? String,
                      !name.isEmpty else {
                    return nil
                }
                return name
            }
            return Array(Set(names)).sorted()
        } catch {
            return []
        }
    }

    /// Get all unique first officer names in the database
    public func getAllFONames() -> [String] {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FlightEntity")
        request.returnsDistinctResults = true
        request.propertiesToFetch = ["foName"]
        request.resultType = .dictionaryResultType

        do {
            let results = try viewContext.fetch(request)
            let names = results.compactMap { result -> String? in
                guard let dict = result as? [String: Any],
                      let name = dict["foName"] as? String,
                      !name.isEmpty else {
                    return nil
                }
                return name
            }
            return Array(Set(names)).sorted()
        } catch {
            return []
        }
    }

    /// Get all unique second officer names in the database
    public func getAllSONames() -> [String] {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FlightEntity")
        request.returnsDistinctResults = true
        request.propertiesToFetch = ["so1Name", "so2Name"]
        request.resultType = .dictionaryResultType

        do {
            let results = try viewContext.fetch(request)
            var names: [String] = []

            for result in results {
                guard let dict = result as? [String: Any] else { continue }

                if let so1Name = dict["so1Name"] as? String, !so1Name.isEmpty {
                    names.append(so1Name)
                }
                if let so2Name = dict["so2Name"] as? String, !so2Name.isEmpty {
                    names.append(so2Name)
                }
            }

            return Array(Set(names)).sorted()
        } catch {
            return []
        }
    }

    /// Get all unique flight numbers in the database
    public func getAllFlightNumbers() -> [String] {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FlightEntity")
        request.returnsDistinctResults = true
        request.propertiesToFetch = ["flightNumber"]
        request.resultType = .dictionaryResultType

        do {
            let results = try viewContext.fetch(request)
            let flightNumbers = results.compactMap { result -> String? in
                guard let dict = result as? [String: Any],
                      let flightNumber = dict["flightNumber"] as? String,
                      !flightNumber.isEmpty else {
                    return nil
                }
                return flightNumber
            }
            return Array(Set(flightNumbers)).sorted()
        } catch {
            return []
        }
    }

    /// Get all unique departure airports in the database
    public func getAllFromAirports() -> [String] {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FlightEntity")
        request.returnsDistinctResults = true
        request.propertiesToFetch = ["fromAirport"]
        request.resultType = .dictionaryResultType

        do {
            let results = try viewContext.fetch(request)
            let airports = results.compactMap { result -> String? in
                guard let dict = result as? [String: Any],
                      let airport = dict["fromAirport"] as? String,
                      !airport.isEmpty else {
                    return nil
                }
                return airport
            }
            return Array(Set(airports)).sorted()
        } catch {
            return []
        }
    }

    /// Get all unique arrival airports in the database
    public func getAllToAirports() -> [String] {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FlightEntity")
        request.returnsDistinctResults = true
        request.propertiesToFetch = ["toAirport"]
        request.resultType = .dictionaryResultType

        do {
            let results = try viewContext.fetch(request)
            let airports = results.compactMap { result -> String? in
                guard let dict = result as? [String: Any],
                      let airport = dict["toAirport"] as? String,
                      !airport.isEmpty else {
                    return nil
                }
                return airport
            }
            return Array(Set(airports)).sorted()
        } catch {
            return []
        }
    }
    /// Get flight statistics for a specific aircraft type (excludes rostered/future flights with blockTime == 0 and simTime == 0)
    public func getFlightStatistics(for aircraftType: String) -> (totalHours: Double, totalSectors: Int) {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        // Exclude rostered flights (blockTime is "0", "0.0", or "0.00" AND simTime is also "0", "0.0", or "0.00")
        // This allows simulator sessions (zero block time but non-zero sim time) to be included
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "aircraftType == %@", aircraftType),
            NSPredicate(format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)", "0", "0.0", "0.00", "0", "0.0", "0.00")
        ])

        do {
            let flights = try viewContext.fetch(request)
            let totalHours = flights.reduce(0.0) { sum, flight in
                let blockTime = safeDoubleFromString(flight.blockTime)
                let simTime = safeDoubleFromString(flight.simTime)
                return sum + (blockTime > 0 ? blockTime : simTime)
            }
            return (totalHours, flights.count)
        } catch {
            return (0.0, 0)
        }
    }

    /// Get detailed flight statistics for a specific aircraft type including time breakdowns
    /// - Parameter aircraftType: The aircraft type to filter by
    /// - Returns: Tuple with totalHours, totalSectors, p1Time, p1usTime, p2Time, simTime
    public func getDetailedFlightStatistics(for aircraftType: String) -> (totalHours: Double, totalSectors: Int, p1Time: Double, p1usTime: Double, p2Time: Double, simTime: Double) {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        // Exclude rostered flights and positioning flights (PAX — FRMS only, not logbook time)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "aircraftType == %@", aircraftType),
            NSPredicate(format: "isPositioning == NO OR isPositioning == nil"),
            NSPredicate(format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)", "0", "0.0", "0.00", "0", "0.0", "0.00")
        ])

        do {
            let flights = try viewContext.fetch(request)
            var totalHours: Double = 0
            var p1Time: Double = 0
            var p1usTime: Double = 0
            var p2Time: Double = 0
            var simTime: Double = 0

            let countSimInTotal = UserDefaults.standard.object(forKey: "countSimInTotal") as? Bool ?? true
            for flight in flights {
                let blockTime = safeDoubleFromString(flight.blockTime)
                let flightSimTime = safeDoubleFromString(flight.simTime)
                let isSimFlight = blockTime == 0 && flightSimTime > 0
                totalHours += blockTime > 0 ? blockTime : (countSimInTotal ? flightSimTime : 0)
                if !isSimFlight {
                    p1Time += safeDoubleFromString(flight.p1Time)
                    p1usTime += safeDoubleFromString(flight.p1usTime)
                    p2Time += safeDoubleFromString(flight.p2Time)
                }
                simTime += flightSimTime
            }

            return (totalHours, flights.count, p1Time, p1usTime, p2Time, simTime)
        } catch {
            return (0.0, 0, 0.0, 0.0, 0.0, 0.0)
        }
    }

    /// Calculate average hours or sectors per time period for a specific aircraft type (excludes rostered/future flights with blockTime == 0 and simTime == 0)
    /// - Parameters:
    ///   - aircraftType: The aircraft type to filter by (empty string for all aircraft)
    ///   - days: The time period in days (e.g., 28, 365)
    ///   - metricType: Either "hours" or "sectors"
    ///   - comparisonPeriodDays: Optional. The comparison period in days (e.g., 90 for "last 3 months"). If nil, uses entire logbook history
    /// - Returns: The average value for the specified metric
    public func getAverageMetric(aircraftType: String, days: Int, metricType: String, comparisonPeriodDays: Int? = nil) -> Double {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current

        // Build predicate for aircraft type and optional date range
        var predicates: [NSPredicate] = []

        // Exclude rostered flights (blockTime is "0", "0.0", or "0.00" AND simTime is also "0", "0.0", or "0.00")
        // This allows simulator sessions (zero block time but non-zero sim time) to be included
        predicates.append(NSPredicate(format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)", "0", "0.0", "0.00", "0", "0.0", "0.00"))

        if !aircraftType.isEmpty {
            predicates.append(NSPredicate(format: "aircraftType == %@", aircraftType))
        }

        // If comparison period is specified, filter by date range
        if let comparisonDays = comparisonPeriodDays {
            let now = Date()
            // Normalize to start of day for consistent comparison
            let endOfPeriod = calendar.startOfDay(for: now)
            let startOfPeriod = calendar.date(byAdding: .day, value: -comparisonDays, to: endOfPeriod)!
            predicates.append(NSPredicate(format: "date >= %@ AND date <= %@", startOfPeriod as NSDate, endOfPeriod as NSDate))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: true)]

        do {
            let flights = try viewContext.fetch(request)

            guard !flights.isEmpty else {
                return 0.0
            }

            // Calculate number of periods based on whether we have a specific comparison timeframe
            let numberOfPeriods: Double

            if let comparisonDays = comparisonPeriodDays {
                // When comparison period is specified, use it as the divisor
                // This gives the actual average over the specified timeframe
                numberOfPeriods = Double(comparisonDays) / Double(days)
            } else {
                // When "All Time", use span-based calculation
                // This shows the rate over the entire flying history
                guard let firstFlightDate = flights.first?.date,
                      let lastFlightDate = flights.last?.date else {
                    return 0.0
                }

                let totalDays = calendar.dateComponents([.day], from: firstFlightDate, to: lastFlightDate).day ?? 0

                // If we don't have enough data for even one period, return 0
                guard totalDays >= days else {
                    return 0.0
                }

                numberOfPeriods = Double(totalDays) / Double(days)
            }

            if metricType == "hours" {
                let totalHours = flights.reduce(0.0) { sum, flight in
                    let blockTime = safeDoubleFromString(flight.blockTime)
                    let simTime = safeDoubleFromString(flight.simTime)
                    // Use block time if available, otherwise use sim time
                    return sum + (blockTime > 0 ? blockTime : simTime)
                }
                return totalHours / numberOfPeriods
            } else { // sectors
                return Double(flights.count) / numberOfPeriods
            }

        } catch {
            return 0.0
        }
    }

    public func getAverageMetricAsync(aircraftType: String, days: Int, metricType: String, comparisonPeriodDays: Int? = nil) async -> Double {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                var calendar = Calendar.current
                calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
                var predicates: [NSPredicate] = [
                    NSPredicate(format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)", "0", "0.0", "0.00", "0", "0.0", "0.00")
                ]
                if !aircraftType.isEmpty {
                    predicates.append(NSPredicate(format: "aircraftType == %@", aircraftType))
                }
                if let comparisonDays = comparisonPeriodDays {
                    let now = Date()
                    let endOfPeriod = calendar.startOfDay(for: now)
                    let startOfPeriod = calendar.date(byAdding: .day, value: -comparisonDays, to: endOfPeriod)!
                    predicates.append(NSPredicate(format: "date >= %@ AND date <= %@", startOfPeriod as NSDate, endOfPeriod as NSDate))
                }
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: true)]
                request.returnsObjectsAsFaults = false
                do {
                    let flights = try context.fetch(request)
                    guard !flights.isEmpty else { continuation.resume(returning: 0.0); return }
                    let numberOfPeriods: Double
                    if let comparisonDays = comparisonPeriodDays {
                        numberOfPeriods = Double(comparisonDays) / Double(days)
                    } else {
                        guard let firstDate = flights.first?.date, let lastDate = flights.last?.date else {
                            continuation.resume(returning: 0.0); return
                        }
                        let totalDays = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
                        guard totalDays >= days else { continuation.resume(returning: 0.0); return }
                        numberOfPeriods = Double(totalDays) / Double(days)
                    }
                    if metricType == "hours" {
                        let total = flights.reduce(0.0) { sum, f in
                            let b = self.safeDoubleFromString(f.blockTime)
                            let s = self.safeDoubleFromString(f.simTime)
                            return sum + (b > 0 ? b : s)
                        }
                        continuation.resume(returning: total / numberOfPeriods)
                    } else {
                        continuation.resume(returning: Double(flights.count) / numberOfPeriods)
                    }
                } catch {
                    continuation.resume(returning: 0.0)
                }
            }
        }
    }

    // MARK: - CloudKit Sync Monitoring

    // Track if we're currently importing from CloudKit
    private var isImportingFromCloudKit = false


    // Track if we're currently doing a batch import (e.g., roster import)
    // When true, contextDidSave uses debounced notifications instead of immediate
    private var isBatchImporting = false

    /// Start batch import mode - notifications will be debounced instead of immediate
    public func startBatchImport() {
        isBatchImporting = true
        print("FlightDatabaseService: Batch import started")
    }

    /// End batch import mode - returns to immediate notifications
    public func endBatchImport() {
        isBatchImporting = false
        print("FlightDatabaseService: Batch import ended")
        // Post one final notification to ensure UI is up to date
        DispatchQueue.main.async {
            self.postDebouncedFlightDataChangedNotification()
        }
    }

    /// Extract detailed error information from a CloudKit partial failure error
    private func extractPartialFailureDetails(from error: Error, operation: String) -> DetailedSyncError {
        var individualErrors: [(recordID: String, error: Error)] = []
        let nsError = error as NSError

        // Log comprehensive error information for debugging
        let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: error)
        print("CloudKit Sync Error: \(operation)")
        print("  \(errorInfo.message) - \(errorInfo.suggestion)")
        print("  Technical: \(error.localizedDescription)")
        print("  Domain: \(nsError.domain), Code: \(nsError.code)")
        print("  Error Type: \(type(of: error))")

        // Log all userInfo keys and values for debugging
        if !nsError.userInfo.isEmpty {
            print("  UserInfo Dictionary:")
            for (key, value) in nsError.userInfo {
                print("    \(key): \(value)")
            }
        }

        // Extract individual errors from partial failure
        // Try multiple approaches to handle different error formats

        // Approach 1: Standard CKError with CKPartialErrorsByItemIDKey
        if let ckError = error as? CKError,
           ckError.code == .partialFailure,
           let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {

            print("CloudKit: Found CKError partial failures - \(partialErrors.count) items")

            for (recordID, itemError) in partialErrors {
                let recordIDString = "\(recordID)"
                individualErrors.append((recordID: recordIDString, error: itemError))

                // Log each individual error
                let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: itemError)
                                print("   Record: \(recordIDString)")
                                print("      Error: \(errorInfo.message)")
                                print("      Details: \(errorInfo.suggestion)")
            }
        }
        // Approach 2: Check for NSError with partial errors in different formats
        else if let partialErrorsDict = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            print("CloudKit: Found NSError partial failures - \(partialErrorsDict.count) items")

            for (recordID, itemError) in partialErrorsDict {
                let recordIDString = "\(recordID)"
                individualErrors.append((recordID: recordIDString, error: itemError))

                let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: itemError)
                                print("   Record: \(recordIDString)")
                                print("      Error: \(errorInfo.message)")
                                print("      Details: \(errorInfo.suggestion)")
            }
        }
        // Approach 3: Check for underlying errors
        else if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            // Debug - print("No direct partial errors found, checking underlying error")
            // Recursively extract from underlying error
            let underlyingDetails = extractPartialFailureDetails(from: underlyingError, operation: "\(operation) - underlying")
            individualErrors = underlyingDetails.individualErrors
        }
        else {
            // Debug - print("ℹ️ No individual errors extracted - this may be a single error or different error format")
        }

        // Build a comprehensive userInfo string dictionary for display
        var userInfoStrings: [String: String] = [:]
        for (key, value) in nsError.userInfo {
            // Skip complex objects and just show simple values
            let keyString = "\(key)"
            // Avoid showing the partial errors dictionary again (we handle that separately)
            if keyString != CKPartialErrorsByItemIDKey {
                userInfoStrings[keyString] = "\(value)"
            }
        }

        // Debug separator
        print("CloudKit: Extraction complete - Found \(individualErrors.count) individual errors")
                        print("\n")

        return DetailedSyncError(
            timestamp: Date(),
            operation: operation,
            mainError: error,
            individualErrors: individualErrors,
            rawErrorDescription: error.localizedDescription,
            errorDomain: nsError.domain,
            errorCode: nsError.code,
            errorUserInfo: userInfoStrings
        )
    }

    /// Set up CloudKit sync event notifications
    private func setupCloudKitNotifications() {
        // Monitor CloudKit import events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitImport(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )

        // Monitor context saves to detect actual data changes during import
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )

        // Monitor remote store changes as a backup to catch syncs that happen after import finishes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteStoreChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )

        // Monitor scene lifecycle to suppress notifications while backgrounded
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIScene.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIScene.didActivateNotification,
            object: nil
        )
        #endif
    }

    @objc private func handleRemoteStoreChange(_ notification: Notification) {
        // This notification fires when CloudKit changes the persistent store.
        // Previously this was skipped during initial setup, but that caused a bug where
        // CloudKit changes made on another device before launch were never reflected in the UI
        // because contextDidSave doesn't always fire for store-level remote changes.

        // Skip during batch imports to prevent view re-renders mid-import
        if isBatchImporting {
            print("FlightDatabaseService: Remote store change skipped (batch import in progress)")
            return
        }

        // Rate limit: Skip if we've processed a notification too recently
        let now = Date()
        if let lastTime = lastRemoteStoreChangeTime,
           now.timeIntervalSince(lastTime) < remoteStoreChangeMinInterval {
            return
        }

        // Update the timestamp
        lastRemoteStoreChangeTime = now

        print("FlightDatabaseService: Remote store change detected - posting debounced notification")
        DispatchQueue.main.async {
            // Show spinner while data arrives — critical on fresh installs where the
            // 134422 CloudKit error kills import events and isSyncing is never set.
            self.isSyncing = true
            self.postDebouncedFlightDataChangedNotification()

            // Settle timer: clear spinner and record lastSyncDate once remote changes stop
            // arriving. 5 seconds gives import events (if they fire) time to complete their
            // own cleanup first; this is the sole path on fresh-install 134422 scenarios.
            self.remoteChangeSyncSettleTimer?.invalidate()
            self.remoteChangeSyncSettleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                guard let self else { return }
                if !self.isImportingFromCloudKit {
                    self.isSyncing = false
                    self.lastSyncDate = Date()
                    // Final reload after CloudKit settles — ensures fields merged in last
                    // (e.g. isPositioning) are reflected in the UI even if earlier
                    // debounced notifications fired before the merge completed.
                    NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                }
            }
        }
    }

    #if canImport(UIKit)
    @objc private func handleAppDidEnterBackground() {
        isAppInBackground = true
        viewContext.refreshAllObjects()
        print("FlightDatabaseService: App entered background  notifications suppressed")
    }

    @objc private func handleAppDidBecomeActive() {
        isAppInBackground = false
        print("FlightDatabaseService: App became active  isAppInBackground cleared")
        if pendingDataChanged {
            pendingDataChanged = false
            print("FlightDatabaseService: Posting deferred .flightDataChanged (backgroundforeground)")
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
            Task { @MainActor in
                WidgetDataWriter.shared.updateWidgetSnapshot()
            }
        }
    }
    #endif

    @objc private func contextDidSave(_ notification: Notification) {
        // Check if there were actual inserted, updated, or deleted objects
        let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

        let hasChanges = !insertedObjects.isEmpty || !updatedObjects.isEmpty || !deletedObjects.isEmpty

        // Skip if no actual changes (empty heartbeat syncs)
        guard hasChanges else { return }

        if isImportingFromCloudKit || isBatchImporting {
            // Batch operation in progress - use debounced notification to prevent UI thrashing
            let source = isImportingFromCloudKit ? "CloudKit import" : "batch import"
            print("FlightDatabaseService: Context saved during \(source): +\(insertedObjects.count) ~\(updatedObjects.count) -\(deletedObjects.count)")
            DispatchQueue.main.async {
                // Data arriving in the store is ground truth that sync is working.
                // Import events on a fresh install often carry partial errors, preventing
                // lastSyncDate from being set via handleCloudKitImport.
                if self.isImportingFromCloudKit {
                    self.lastSyncDate = Date()
                }
                self.postDebouncedFlightDataChangedNotification()
            }
        } else {
            // Local user change - post immediate notification for instant UI feedback
            print("FlightDatabaseService: Context saved (local change): +\(insertedObjects.count) ~\(updatedObjects.count) -\(deletedObjects.count)")
            DispatchQueue.main.async {
                if self.isAppInBackground {
                    self.pendingDataChanged = true
                    print("FlightDatabaseService: Deferred .flightDataChanged (app in background)")
                } else {
                    print("FlightDatabaseService: Posting .flightDataChanged (immediate)")
                    NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                }
            }
        }
    }

    @objc private func handleCloudKitImport(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        DispatchQueue.main.async {
            switch event.type {
            case .setup:
//                print("CloudKit setup event")
                if let error = event.error {
                    // Handle setup errors gracefully - likely network or account issues
                    let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: error)
                    print("CloudKit: \(errorInfo.message) - \(errorInfo.suggestion)")
                    print("  Technical: \(error.localizedDescription)")
                    self.lastSyncError = error
                    // Don't crash - allow app to continue with local-only operation
                }
            case .import:
                if event.endDate == nil {
                    // Import starting - set flag so contextDidSave knows we're importing
                    self.isImportingFromCloudKit = true
                    self.isSyncing = true
                } else {
                    // Import finished - clear importing flag
                    self.isImportingFromCloudKit = false

                    // Keep isSyncing = true until the initial bulk download settles.
                    // Without this, isSyncing toggles off between batches so the spinner
                    // disappears mid-sync on a fresh install.
                    if self.hasCompletedInitialSetup {
                        self.isSyncing = false
                    }

                    // Mark that we've completed the initial setup/import after a delay
                    // This allows for any trailing remote store change notifications to settle
                    self.initialSetupTimer?.invalidate()
                    self.initialSetupTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                        self.hasCompletedInitialSetup = true
                        self.isSyncing = false
                    }
                }

                if let error = event.error {
                    self.lastSyncError = error

                    // Extract detailed error information
                    let detailedError = self.extractPartialFailureDetails(from: error, operation: "import")
                    self.detailedSyncError = detailedError

                    let nsError = error as NSError
                    let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: error)
                    // Check if it's a network-related error
                    if nsError.domain == "NSCocoaErrorDomain" || nsError.domain == "CKErrorDomain" {
                        print("CloudKit: \(errorInfo.message) - \(errorInfo.suggestion)")
                        print("  Technical: \(error.localizedDescription)")
                    } else {
                        print("CloudKit: \(errorInfo.message) - \(errorInfo.suggestion)")
                        print("  Technical: \(error.localizedDescription)")
                    }
                } else if event.endDate != nil {
                    self.lastSyncDate = Date()
                    self.lastSyncError = nil
                    self.detailedSyncError = nil
                    //print("CloudKit import completed successfully")

                    // NOTE: We no longer notify here - contextDidSave will handle it
                    // if there were actual data changes during the import

                    // After every CloudKit import, check for and remove any duplicate
                    // FlightEntity rows that may have been inserted during a sync reset
                    // (change token expiry causes a full re-import that bypasses app-level
                    // duplicate checks). The dedup is cheap when there are no duplicates.
                    DispatchQueue.global(qos: .utility).async {
                        self.deduplicateFlightsByUUID()
                    }
                }
            case .export:
                // Only log export events if there's an error or if changes were actually synced
                // This reduces console noise from periodic heartbeat syncs

                if event.endDate == nil {
                    // Export starting - only log if verbose debugging needed
                    // print("CloudKit export event - syncing: true")
                }

                self.isSyncing = event.endDate == nil
                if let error = event.error {
                    self.lastSyncError = error

                    // Extract detailed error information
                    let detailedError = self.extractPartialFailureDetails(from: error, operation: "export")
                    self.detailedSyncError = detailedError

                    let nsError = error as NSError
                    let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: error)
                    // Check if it's a network-related error
                    if nsError.domain == "NSCocoaErrorDomain" || nsError.domain == "CKErrorDomain" {
                        print("CloudKit: \(errorInfo.message) - \(errorInfo.suggestion)")
                        print("  Technical: \(error.localizedDescription)")
                    } else {
                        print("CloudKit: \(errorInfo.message) - \(errorInfo.suggestion)")
                        print("  Technical: \(error.localizedDescription)")
                    }
                } else if event.endDate != nil {
                    self.lastSyncDate = Date()
                    self.lastSyncError = nil
                    self.detailedSyncError = nil
                    // Only log successful exports in verbose mode (these are often empty heartbeat syncs)
                    // Uncomment the line below if you want to see all export completions:
                    // print("CloudKit export completed successfully")
                }
            @unknown default:
                print("CloudKit: Unknown event")
            }
        }
    }

    /// Remove duplicate FlightEntity rows that share the same `id` UUID.
    /// Keeps the record with the earliest `createdAt`; deletes the rest.
    /// Safe to call on a background thread — uses a private context.
    ///
    /// Safety: aborts without saving if the number of records to delete exceeds 10% of
    /// the total record count. A genuine change-token re-import creates at most one extra
    /// copy of each record; deleting the majority of the database means something else has
    /// gone wrong (e.g. first-launch sync on a new peer) and we must not propagate that.
    private func deduplicateFlightsByUUID() {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.performAndWait {
            let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.createdAt, ascending: true)]
            guard let allFlights = try? context.fetch(request) else { return }

            let totalCount = allFlights.count

            // Build a frequency map first so we only delete records that are
            // genuinely duplicated — not just "seen before" due to sort instability.
            var uuidCounts: [UUID: Int] = [:]
            for flight in allFlights {
                guard let uuid = flight.id else { continue }
                uuidCounts[uuid, default: 0] += 1
            }

            let duplicatedUUIDs = Set(uuidCounts.filter { $0.value > 1 }.keys)

            guard !duplicatedUUIDs.isEmpty else {
                print("CloudKit dedup: No duplicate flights found")
                return
            }

            // For each duplicated UUID keep the earliest-createdAt record, delete the rest.
            var seen: [UUID: FlightEntity] = [:]
            var toDelete: [FlightEntity] = []
            for flight in allFlights {
                guard let uuid = flight.id, duplicatedUUIDs.contains(uuid) else { continue }
                if seen[uuid] != nil {
                    toDelete.append(flight)
                } else {
                    seen[uuid] = flight
                }
            }

            let deletedCount = toDelete.count

            // Safety threshold: if we're about to delete more than 10% of the database,
            // something is catastrophically wrong (e.g. initial sync on empty store).
            // Abort — do NOT save — so deletions never propagate to CloudKit.
            let threshold = max(10, totalCount / 10)
            guard deletedCount <= threshold else {
                print("CloudKit dedup: ABORTED — would delete \(deletedCount) of \(totalCount) records (exceeds 10% safety threshold). This looks like a first-launch sync, not a real dedup event.")
                return
            }

            for flight in toDelete {
                context.delete(flight)
            }

            do {
                try context.save()
                print("CloudKit dedup: Removed \(deletedCount) duplicate flight(s) after sync reset")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                }
            } catch {
                print("CloudKit dedup: Failed to save \(error.localizedDescription)")
            }
        }
    }

    /// Check CloudKit account status
    public func checkCloudKitAccountStatus(completion: @escaping (Bool, Error?) -> Void) {
        guard let description = persistentContainer.persistentStoreDescriptions.first,
              let _ = description.cloudKitContainerOptions?.containerIdentifier else {
            completion(false, NSError(domain: "FlightDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit not configured"]))
            return
        }

        // Note: For a more comprehensive check, you can use CKContainer directly
        // For now, we'll rely on NSPersistentCloudKitContainer's built-in handling
        completion(true, nil)
    }

    // MARK: - Debug Testing Methods

    /// Simulate a partial sync failure for testing the error UI
    /// Note: Only accessible when Debug Mode is enabled in Settings
    public func simulatePartialSyncFailure() {
        // LogManager: Test simulation - print("🧪 Simulating partial sync failure for testing")

        // Create mock individual errors
        let recordID1 = CKRecord.ID(recordName: "CD_FlightEntity.ABC123DEF456")
        let recordID2 = CKRecord.ID(recordName: "CD_FlightEntity.789GHI012JKL")
        let recordID3 = CKRecord.ID(recordName: "CD_FlightEntity.345MNO678PQR")

        let error1 = CKError(.serverRecordChanged)
        let error2 = CKError(.networkFailure)
        let error3 = CKError(.quotaExceeded)

        // Create partial errors dictionary
        let partialErrors: [CKRecord.ID: Error] = [
            recordID1: error1,
            recordID2: error2,
            recordID3: error3
        ]

        // Create the main partial failure error
        let partialFailureError = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: partialErrors]
        )

        // Extract and store the detailed error
        DispatchQueue.main.async {
            self.lastSyncError = partialFailureError
            self.detailedSyncError = self.extractPartialFailureDetails(
                from: partialFailureError,
                operation: "import (simulated)"
            )
            self.lastSyncDate = nil // Clear last successful sync
        }

        // LogManager: Test simulation - print("Simulated error set - check CloudKit Sync Status view")
    }

    /// Simulate a simple network error
    public func simulateNetworkError() {
        // LogManager: Test simulation - print("🧪 Simulating network error for testing")

        let networkError = CKError(.networkUnavailable)

        DispatchQueue.main.async {
            self.lastSyncError = networkError
            self.detailedSyncError = self.extractPartialFailureDetails(
                from: networkError,
                operation: "export (simulated)"
            )
            self.lastSyncDate = nil
        }

        // LogManager: Test simulation - print("Simulated network error set")
    }

    /// Clear simulated errors and restore normal state
    public func clearSimulatedErrors() {
                        print(" Clearing simulated errors")

        DispatchQueue.main.async {
            self.lastSyncError = nil
            self.detailedSyncError = nil
            self.lastSyncDate = Date()
        }

        // LogManager: Test simulation - print("Errors cleared")
    }

    /// Recalculate all block times from OUT and IN times (stores raw 2-decimal precision)
    /// This recalculates the precise block time from OUT/IN. Rounding is applied at display time only.
    /// Skips simulator flights (simTime > 0) and positioning flights (isPositioning = true)
    /// - Returns: Tuple of (successCount, skippedCount, errorCount)
    public func recalculateAllBlockTimes() -> (success: Int, skipped: Int, errors: Int) {
        print(" Starting recalculation of all block times")

        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()

        // Only fetch flights that:
        // - Have both OUT and IN times
        // - Are NOT simulator flights (simTime == 0 or nil)
        // - Are NOT positioning flights (isPositioning == false or nil)
        fetchRequest.predicate = NSPredicate(
            format: "outTime != nil AND outTime != %@ AND inTime != nil AND inTime != %@ AND (simTime == nil OR simTime == %@ OR simTime == %@) AND (isPositioning == nil OR isPositioning == NO)",
            "", "", "0", "0.0"
        )

        var successCount = 0
        var skippedCount = 0
        var errorCount = 0

        do {
            let flights = try context.fetch(fetchRequest)
            print(" Found \(flights.count) regular flights with OUT/IN times to recalculate (excluding SIM and PAX)")

            let timeCalculationManager = TimeCalculationManager()

            for flight in flights {
                guard let outTime = flight.outTime,
                      let inTime = flight.inTime,
                      !outTime.isEmpty,
                      !inTime.isEmpty else {
                    skippedCount += 1
                    continue
                }

                // Calculate block time with 2 decimal precision (e.g., "4.53")
                // Rounding is NOT applied here - it's applied at display time based on user preference
                let newBlockTime = timeCalculationManager.calculateFlightTime(
                    outTime: outTime,
                    inTime: inTime
                )

                // Only update if the calculation was successful
                if newBlockTime != "0.0" {
                    let oldBlockTime = flight.blockTime ?? "0.0"
                    flight.blockTime = newBlockTime

                    // Log if value changed
                    if oldBlockTime != newBlockTime {
                        print(" Updated flight \(flight.flightNumber ?? "?"): \(oldBlockTime)  \(newBlockTime)")
                    }

                    successCount += 1
                } else {
                    print(" Failed to calculate block time for flight \(flight.flightNumber ?? "?")")
                    errorCount += 1
                }
            }

            // Save all changes
            if context.hasChanges {
                try context.save()
                print(" Block time recalculation complete: \(successCount) updated, \(skippedCount) skipped, \(errorCount) errors")
            } else {
                print(" No changes needed - all block times already correct")
            }

        } catch {
            print(" Failed to recalculate block times: \(error.localizedDescription)")
            errorCount += 1
        }

        return (success: successCount, skipped: skippedCount, errors: errorCount)
    }

    public func normaliseAirportCodes() -> (fixed: Int, total: Int) {
        print("Starting airport code normalisation")

        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "fromAirport != nil AND fromAirport != %@ AND toAirport != nil AND toAirport != %@",
            "", ""
        )

        var fixedCount = 0
        var totalCount = 0

        do {
            let flights = try context.fetch(fetchRequest)
            totalCount = flights.count

            for flight in flights {
                var changed = false

                if let from = flight.fromAirport, !from.isEmpty {
                    let icao = AirportService.shared.convertToICAO(from)
                    if icao != from {
                        flight.fromAirport = icao
                        changed = true
                    }
                }

                if let to = flight.toAirport, !to.isEmpty {
                    let icao = AirportService.shared.convertToICAO(to)
                    if icao != to {
                        flight.toAirport = icao
                        changed = true
                    }
                }

                if changed { fixedCount += 1 }
            }

            if context.hasChanges {
                try context.save()
                print("Airport normalisation complete: \(fixedCount) of \(totalCount) flights updated")
            } else {
                print("Airport normalisation complete: no changes needed")
            }
        } catch {
            print("Airport normalisation failed: \(error.localizedDescription)")
        }

        return (fixed: fixedCount, total: totalCount)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}

// MARK: - Enhanced Statistics Model
public struct FlightStatistics: Sendable {
    public let totalSectors: Int
    public let totalBlockTime: Double
    public let totalP1Time: Double
    public let totalP1USTime: Double
    public let totalP2Time: Double
    public let totalNightTime: Double
    public let totalInstrumentTime: Double
    public let totalSIMTime: Double
    public let totalSpInsTime: Double
    public let totalSpInsSimTime: Double
    public let totalSpInsFltTime: Double
    public let spInsFltCount: Int
    public let spInsSimCount: Int
    public let aiiiSectors: Int
    public let pfSectors: Int
    public let totalAirports: Int

    public static let empty = FlightStatistics(
        totalSectors: 0,
        totalBlockTime: 0,
        totalP1Time: 0,
        totalP1USTime: 0,
        totalP2Time: 0,
        totalNightTime: 0,
        totalInstrumentTime: 0,
        totalSIMTime: 0,
        totalSpInsTime: 0,
        totalSpInsSimTime: 0,
        totalSpInsFltTime: 0,
        spInsFltCount: 0,
        spInsSimCount: 0,
        aiiiSectors: 0,
        pfSectors: 0,
        totalAirports: 0
    )

    // MARK: - Formatted Properties
    public var formattedBlockTime: String {
        return String(format: "%.1f hrs", totalBlockTime)
    }
    public var formattedP1Time: String {
        return String(format: "%.1f hrs", totalP1Time)
    }
    public var formattedP1USTime: String {
        return String(format: "%.1f hrs", totalP1USTime)
    }
    public var formattedP2Time: String {
        return String(format: "%.1f hrs", totalP2Time)
    }
    public var formattedNightTime: String {
        return String(format: "%.1f hrs", totalNightTime)
    }
    public var formattedInstrumentTime: String {
        return String(format: "%.1f hrs", totalInstrumentTime)
    }
    public var formattedSIMTime: String {
        return String(format: "%.1f hrs", totalSIMTime)
    }

    // Combined flight time (block + SIM)
    public var totalFlightTime: Double {
        return totalBlockTime + totalSIMTime
    }

    public func totalFlightTime(includeSim: Bool) -> Double {
        return includeSim ? totalBlockTime + totalSIMTime : totalBlockTime
    }

    public var formattedTotalFlightTime: String {
        return String(format: "%.1f hrs", totalFlightTime)
    }

    // MARK: - Formatted Properties with Time Format Support

    /// Format time value based on user preference (decimal or HH:MM)
    private func formatTime(_ value: Double, asHoursMinutes: Bool) -> String {
        guard value > 0 else {
            return asHoursMinutes ? "0:00" : "0.0 hrs"
        }

        if asHoursMinutes {
            return FlightSector.decimalToHHMM(value)
        } else {
            return String(format: "%.1f hrs", value)
        }
    }

    public func formattedTotalFlightTime(asHoursMinutes: Bool) -> String {
        return formatTime(totalFlightTime, asHoursMinutes: asHoursMinutes)
    }

    public func formattedTotalFlightTime(includeSim: Bool, asHoursMinutes: Bool) -> String {
        return formatTime(totalFlightTime(includeSim: includeSim), asHoursMinutes: asHoursMinutes)
    }

    public func formattedP1Time(asHoursMinutes: Bool) -> String {
        return formatTime(totalP1Time, asHoursMinutes: asHoursMinutes)
    }

    public func formattedP1USTime(asHoursMinutes: Bool) -> String {
        return formatTime(totalP1USTime, asHoursMinutes: asHoursMinutes)
    }

    public func formattedNightTime(asHoursMinutes: Bool) -> String {
        return formatTime(totalNightTime, asHoursMinutes: asHoursMinutes)
    }

    public func formattedInstrumentTime(asHoursMinutes: Bool) -> String {
        return formatTime(totalInstrumentTime, asHoursMinutes: asHoursMinutes)
    }

    public func formattedSIMTime(asHoursMinutes: Bool) -> String {
        return formatTime(totalSIMTime, asHoursMinutes: asHoursMinutes)
    }

    public func formattedSpInsTime(asHoursMinutes: Bool) -> String {
        return formatTime(totalSpInsTime, asHoursMinutes: asHoursMinutes)
    }

    public func formattedSpInsSimTime(asHoursMinutes: Bool) -> String {
        return formatTime(totalSpInsSimTime, asHoursMinutes: asHoursMinutes)
    }

    public func formattedSpInsFltTime(asHoursMinutes: Bool) -> String {
        return formatTime(totalSpInsFltTime, asHoursMinutes: asHoursMinutes)
    }

    public var pfPercentage: Double {
        guard totalSectors > 0 else { return 0 }
        return (Double(pfSectors) / Double(totalSectors)) * 100
    }

    public var aiiiPercentage: Double {
        guard totalSectors > 0 else { return 0 }
        return (Double(aiiiSectors) / Double(totalSectors)) * 100
    }

    public func pfRecencyStatus(recencyDays: Int = 45) -> (daysRemaining: Int, color: Color, expiryDate: Date?) {
        guard let lastPFDate = FlightDatabaseService.shared.getLastPFDate(),
              let daysSinceLastPF = FlightDatabaseService.shared.getDaysSinceLastPF() else {
            return (0, .red, nil) // No PF sectors found - critical
        }

        let daysRemaining = max(0, recencyDays - daysSinceLastPF)

        let color: Color = {
            if daysRemaining <= 3 {
                return .red
            } else if daysRemaining <= 7 {
                return .orange
            } else {
                return .green
            }
        }()

        // Calculate expiry date from the last PF flight date
        let calendar = Calendar.current
        let expiryDate = calendar.date(byAdding: .day, value: recencyDays, to: lastPFDate)

        return (daysRemaining, color, expiryDate)
    }

    public func aiiiRecencyStatus(recencyDays: Int = 90) -> (daysRemaining: Int, color: Color, expiryDate: Date?) {
        guard let lastAIIIDate = FlightDatabaseService.shared.getLastAIIIDate(),
              let daysSinceLastAIII = FlightDatabaseService.shared.getDaysSinceLastAIII() else {
            return (0, .red, nil) // No AIII sectors found - critical
        }

        let daysRemaining = max(0, recencyDays - daysSinceLastAIII)

        let color: Color = {
            if daysRemaining <= 7 {
                return .red
            } else if daysRemaining <= 30 {
                return .orange
            } else {
                return .green
            }
        }()

        // Calculate expiry date from the last AIII flight date
        let calendar = Calendar.current
        let expiryDate = calendar.date(byAdding: .day, value: recencyDays, to: lastAIIIDate)

        return (daysRemaining, color, expiryDate)
    }

    /// Calculate Takeoff recency status (days remaining out of total recency period)
    public func takeoffRecencyStatus(recencyDays: Int = 45) -> (daysRemaining: Int, color: Color, expiryDate: Date?) {
        guard let lastTakeoffDate = FlightDatabaseService.shared.getLastTakeoffDate(),
              let daysSinceLastTakeoff = FlightDatabaseService.shared.getDaysSinceLastTakeoff() else {
            return (0, .red, nil) // No takeoffs found - critical
        }

        let daysRemaining = max(0, recencyDays - daysSinceLastTakeoff)

        let color: Color = {
            if daysRemaining <= 3 {
                return .red
            } else if daysRemaining <= 7 {
                return .orange
            } else {
                return .green
            }
        }()

        // Calculate expiry date from the last takeoff date
        let calendar = Calendar.current
        let expiryDate = calendar.date(byAdding: .day, value: recencyDays, to: lastTakeoffDate)

        return (daysRemaining, color, expiryDate)
    }

    /// Calculate Landing recency status (days remaining out of total recency period)
    public func landingRecencyStatus(recencyDays: Int = 45) -> (daysRemaining: Int, color: Color, expiryDate: Date?) {
        guard let lastLandingDate = FlightDatabaseService.shared.getLastLandingDate(),
              let daysSinceLastLanding = FlightDatabaseService.shared.getDaysSinceLastLanding() else {
            return (0, .red, nil) // No landings found - critical
        }

        let daysRemaining = max(0, recencyDays - daysSinceLastLanding)

        let color: Color = {
            if daysRemaining <= 3 {
                return .red
            } else if daysRemaining <= 7 {
                return .orange
            } else {
                return .green
            }
        }()

        // Calculate expiry date from the last landing date
        let calendar = Calendar.current
        let expiryDate = calendar.date(byAdding: .day, value: recencyDays, to: lastLandingDate)

        return (daysRemaining, color, expiryDate)
    }
    /// Calculate rolling hour limit status
    public func rollingHourLimitStatus(limitHours: Double = 100, rollingDays: Int = 28) -> (hoursRemaining: Double, color: Color) {
        let currentHours = FlightDatabaseService.shared.getFlightHoursForRollingPeriod(days: rollingDays)
        let hoursRemaining = max(0, limitHours - currentHours)
        
        let percentageUsed = currentHours / limitHours
        
        let color: Color = {
            if percentageUsed >= 0.95 { // 95% or more used
                return .red
            } else if percentageUsed >= 0.80 { // 80% or more used
                return .orange
            } else {
                return .green
            }
        }()
        
        return (hoursRemaining, color)
    }
}
