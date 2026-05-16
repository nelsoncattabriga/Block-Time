//
//  CoreDataMigrationService.swift
//  Block-Time
//
//  One-time Core Data → SwiftData migration orchestrator (FOUND-09).
//
//  Reads v1 Core Data store (read-only, via FlightDatabaseService.shared.persistentContainer.viewContext),
//  writes to a CloudKit-disabled SwiftData ModelContainer (D-09), verifies row counts (D-08),
//  and triggers `exit(0)` to force a clean relaunch into the CloudKit-enabled production container.
//
//  Crash safety: clear-and-retry (D-06).
//  Two UserDefaults flags, set in strict order (D-07):
//    1. v2MigrationStarted — set FIRST, before any work
//    2. v2MigrationComplete — set LAST, only after row-count match
//
//  Plan 01-04 (FOUND-09, FOUND-10, FOUND-11)
//

import Foundation
import CoreData
import SwiftData
import os

/// One-time orchestrator for migrating v1 Core Data records to v2 SwiftData.
///
/// **Usage:** Call `runIfNeeded()` from `SplashScreenView.task` (or equivalent launch hook)
/// before presenting the main tab view. The method is async and idempotent.
///
/// **Test injection:** Pass a custom `Dependencies` to replace Core Data reads,
/// container creation, and the `exit(0)` hook — preventing the test runner from being killed.
@MainActor
final class CoreDataMigrationService {

    // MARK: - State Machine

    /// The current migration state, derived from UserDefaults flag values.
    enum State: Equatable {
        /// Neither flag set — migration has not been attempted.
        case notStarted
        /// `migrationStarted=true`, `migrationComplete=false` — app was killed mid-migration (D-06).
        case crashed
        /// Both flags true — migration finished successfully.
        case complete
    }

    // MARK: - Dependencies (test injection points)

    /// All external dependencies are injectable for isolation in unit tests.
    struct Dependencies {
        /// The `UserDefaults` suite to read/write migration flags.
        /// Tests must pass an isolated suite (e.g., `UserDefaults(suiteName: UUID().uuidString)!`).
        var defaults: UserDefaults = .standard

        /// URL of the SwiftData SQLite store — used only by crash recovery to delete partial files.
        var swiftDataStoreURL: URL = ModelContainerFactory.appGroupStoreURL()

        /// Factory that creates the migration `ModelContainer` (CloudKit disabled).
        var makeMigrationContainer: () throws -> ModelContainer = {
            try ModelContainerFactory.makeMigrationContainer()
        }

        /// Reads all `FlightEntity` records from v1 Core Data and converts them to snapshots.
        /// Must execute on the main thread (Core Data viewContext is main-thread-only).
        var fetchLegacySnapshots: @MainActor () throws -> [LegacyFlightSnapshot] = CoreDataMigrationService.defaultFetchSnapshots

        /// Returns the total count of `FlightEntity` records in v1 Core Data.
        var coreDataCount: @MainActor () throws -> Int = CoreDataMigrationService.defaultCoreDataCount

        /// Called after `migrationComplete=true` is set.
        /// Production value: `{ exit(0) }` — forces a clean relaunch into the CloudKit container (D-09).
        /// Test value: `{}` — no-op, prevents killing the test runner.
        var onComplete: @Sendable () -> Void = { exit(0) }
    }

    // MARK: - UserDefaults Flag Keys (D-07)

    private static let startedKey  = "v2MigrationStarted"
    private static let completeKey = "v2MigrationComplete"

    // MARK: - Properties

    private let deps: Dependencies
    private let logger = Logger(subsystem: "com.thezoolab.blocktime", category: "Migration.Service")

    // MARK: - Init

    init(dependencies: Dependencies = Dependencies()) {
        self.deps = dependencies
    }

    // MARK: - State

    /// Current migration state, computed from UserDefaults flag values.
    var state: State {
        let started  = deps.defaults.bool(forKey: Self.startedKey)
        let complete = deps.defaults.bool(forKey: Self.completeKey)
        switch (started, complete) {
        case (true, true):   return .complete
        case (true, false):  return .crashed
        case (false, _):     return .notStarted
        }
    }

    // MARK: - Entry Point

    /// Runs migration if necessary. Idempotent — safe to call on every launch.
    ///
    /// - If `.complete`: returns immediately (no-op).
    /// - If `.crashed`: deletes the partial SwiftData store, resets the started flag, then migrates (D-06).
    /// - If `.notStarted`: migrates.
    ///
    /// After a successful migration, calls `deps.onComplete()` (production: `exit(0)`).
    func runIfNeeded() async throws {
        switch state {
        case .complete:
            logger.info("Migration already complete — skipping.")
            return

        case .crashed:
            logger.warning("Detected crashed migration. Deleting partial SwiftData store and retrying (D-06).")
            deletePartialStore()
            // Reset started flag so we enter .notStarted and set it again cleanly (D-07).
            deps.defaults.set(false, forKey: Self.startedKey)
            try await performMigration()

        case .notStarted:
            try await performMigration()
        }
    }

    // MARK: - Private: Migration Execution

    private func performMigration() async throws {
        // D-07: Set started FIRST, before any write (crash safety).
        deps.defaults.set(true, forKey: Self.startedKey)

        logger.info("Migration starting. Reading Core Data records…")

        // Read Core Data on main thread — NSManagedObject is not Sendable.
        let snapshots: [LegacyFlightSnapshot]
        do {
            snapshots = try deps.fetchLegacySnapshots()
        } catch {
            throw MigrationError.coreDataReadFailed(underlying: error)
        }

        let sourceCount: Int
        do {
            sourceCount = try deps.coreDataCount()
        } catch {
            throw MigrationError.coreDataReadFailed(underlying: error)
        }

        logger.info("Migration: read \(snapshots.count, privacy: .public) snapshots (source count: \(sourceCount, privacy: .public)).")

        // Build migration container with cloudKitDatabase: .none (D-09).
        let container: ModelContainer
        do {
            container = try deps.makeMigrationContainer()
        } catch {
            throw MigrationError.containerCreationFailed(underlying: error)
        }

        // Write via @ModelActor on a background thread (FOUND-11, RESEARCH.md §Pitfall 4).
        // Actor MUST be created inside Task.detached — not inside @MainActor code — to avoid
        // binding the executor to the main thread.
        let writtenCount: Int = try await Task.detached(priority: .userInitiated) {
            let actor = CoreDataMigrationActor(modelContainer: container)
            do {
                return try await actor.importLegacyFlights(snapshots)
            } catch {
                throw MigrationError.swiftDataWriteFailed(underlying: error)
            }
        }.value

        // D-08: Verify destination count BEFORE setting complete.
        let destCount: Int = try await Task.detached(priority: .userInitiated) {
            let actor = CoreDataMigrationActor(modelContainer: container)
            return try await actor.count()
        }.value

        guard writtenCount == sourceCount, destCount == sourceCount else {
            logger.error(
                "Row count mismatch: expected \(sourceCount, privacy: .public), " +
                "wrote \(writtenCount, privacy: .public), verified \(destCount, privacy: .public). " +
                "NOT setting migrationComplete (D-08)."
            )
            throw MigrationError.rowCountMismatch(expected: sourceCount, actual: destCount)
        }

        // D-07: Set complete LAST, only after verified row-count match.
        deps.defaults.set(true, forKey: Self.completeKey)
        logger.info("Migration complete: \(destCount, privacy: .public) records migrated. Triggering relaunch (D-09).")

        // D-09: Force relaunch so the next launch creates the CloudKit-enabled container.
        deps.onComplete()
    }

    // MARK: - Private: Crash Recovery

    /// Deletes the SwiftData store file and its sidecars (-shm, -wal) at `deps.swiftDataStoreURL`.
    /// Called on `.crashed` state (D-06) before retrying migration.
    private func deletePartialStore() {
        let fm = FileManager.default
        let base = deps.swiftDataStoreURL
        let candidates = [
            base,
            base.appendingPathExtension("shm"),
            base.appendingPathExtension("wal"),
        ]
        for candidate in candidates {
            guard fm.fileExists(atPath: candidate.path) else { continue }
            do {
                try fm.removeItem(at: candidate)
                logger.info("Crash recovery: deleted \(candidate.lastPathComponent, privacy: .public)")
            } catch {
                logger.error(
                    "Crash recovery: failed to delete \(candidate.lastPathComponent, privacy: .public): " +
                    "\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    // MARK: - Default Core Data Accessors

    /// Default implementation: fetches all `FlightEntity` records from v1 Core Data via
    /// `FlightDatabaseService.shared.persistentContainer.viewContext`.
    ///
    /// Read-only — never mutates the Core Data store.
    @MainActor
    private static func defaultFetchSnapshots() throws -> [LegacyFlightSnapshot] {
        let ctx = FlightDatabaseService.shared.persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
        let results = try ctx.fetch(request)
        return results.map { mo in
            LegacyFlightSnapshot(
                id: mo.value(forKey: "id") as? UUID,
                createdAt: mo.value(forKey: "createdAt") as? Date,
                modifiedAt: mo.value(forKey: "modifiedAt") as? Date,
                importedAt: mo.value(forKey: "importedAt") as? Date,
                importSessionID: mo.value(forKey: "importSessionID") as? UUID,
                date: mo.value(forKey: "date") as? Date,
                fromAirport: mo.value(forKey: "fromAirport") as? String,
                toAirport: mo.value(forKey: "toAirport") as? String,
                flightNumber: mo.value(forKey: "flightNumber") as? String,
                aircraftType: mo.value(forKey: "aircraftType") as? String,
                aircraftReg: mo.value(forKey: "aircraftReg") as? String,
                blockTime: mo.value(forKey: "blockTime") as? String,
                simTime: mo.value(forKey: "simTime") as? String,
                nightTime: mo.value(forKey: "nightTime") as? String,
                p1Time: mo.value(forKey: "p1Time") as? String,
                p1usTime: mo.value(forKey: "p1usTime") as? String,
                p2Time: mo.value(forKey: "p2Time") as? String,
                instrumentTime: mo.value(forKey: "instrumentTime") as? String,
                spInsTime: mo.value(forKey: "spInsTime") as? String,
                outTime: mo.value(forKey: "outTime") as? String,
                inTime: mo.value(forKey: "inTime") as? String,
                scheduledDeparture: mo.value(forKey: "scheduledDeparture") as? String,
                scheduledArrival: mo.value(forKey: "scheduledArrival") as? String,
                dayTakeoffs: Int((mo.value(forKey: "dayTakeoffs") as? Int16) ?? 0),
                nightTakeoffs: Int((mo.value(forKey: "nightTakeoffs") as? Int16) ?? 0),
                dayLandings: Int((mo.value(forKey: "dayLandings") as? Int16) ?? 0),
                nightLandings: Int((mo.value(forKey: "nightLandings") as? Int16) ?? 0),
                customCount: Int((mo.value(forKey: "customCount") as? Int16) ?? 0),
                isILS: (mo.value(forKey: "isILS") as? Bool) ?? false,
                isGLS: (mo.value(forKey: "isGLS") as? Bool) ?? false,
                isRNP: (mo.value(forKey: "isRNP") as? Bool) ?? false,
                isNPA: (mo.value(forKey: "isNPA") as? Bool) ?? false,
                isAIII: (mo.value(forKey: "isAIII") as? Bool) ?? false,
                isPilotFlying: (mo.value(forKey: "isPilotFlying") as? Bool) ?? false,
                isPositioning: (mo.value(forKey: "isPositioning") as? Bool) ?? false,
                captainName: mo.value(forKey: "captainName") as? String,
                foName: mo.value(forKey: "foName") as? String,
                so1Name: mo.value(forKey: "so1Name") as? String,
                so2Name: mo.value(forKey: "so2Name") as? String,
                remarks: mo.value(forKey: "remarks") as? String
            )
        }
    }

    /// Default implementation: counts `FlightEntity` records in v1 Core Data.
    @MainActor
    private static func defaultCoreDataCount() throws -> Int {
        let ctx = FlightDatabaseService.shared.persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
        return try ctx.count(for: request)
    }
}
