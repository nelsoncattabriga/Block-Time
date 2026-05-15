//
//  CoreDataMigrationActor.swift
//  Block-Time
//
//  @ModelActor that writes FlightModel records to SwiftData on a background thread (FOUND-11).
//
//  CRITICAL: Must be instantiated inside `Task.detached(priority: .userInitiated)` to avoid
//  binding the executor to the main thread (RESEARCH.md §Pitfall 4).
//
//  Plan 01-04 (FOUND-10, FOUND-11)
//

import Foundation
import SwiftData

/// Background-thread SwiftData writer for the one-time Core Data → SwiftData migration.
///
/// Converts `LegacyFlightSnapshot` value types to `FlightModel` records using
/// `TimeStringConverter` for all 8 duration fields and 4 clock fields.
///
/// **Concurrency contract:** This actor MUST be initialised inside `Task.detached`.
/// Initialising it on the main actor causes its executor to bind to the main thread,
/// defeating the purpose of `@ModelActor` (RESEARCH.md §Pitfall 4).
@ModelActor
actor CoreDataMigrationActor {

    // MARK: - Test Helper

    /// Returns whether the actor's code is currently running on the main thread.
    ///
    /// Used by `MigrationBackgroundThreadTests` to verify FOUND-11.
    /// In production, this method is never called.
    func assertIsMainThread() -> Bool {
        Thread.isMainThread
    }

    // MARK: - Migration Write

    /// Converts all snapshots to `FlightModel` records, inserts them, saves the context,
    /// and returns the number of records inserted.
    ///
    /// - Parameter snapshots: Sendable value-type snapshots read from v1 Core Data on the main thread.
    /// - Returns: Number of `FlightModel` records successfully inserted and saved.
    /// - Throws: Any `ModelContext` error on save.
    func importLegacyFlights(_ snapshots: [LegacyFlightSnapshot]) throws -> Int {
        var inserted = 0

        for s in snapshots {
            let model = FlightModel()

            // Identity
            model.id = s.id ?? UUID()
            model.createdAt = s.createdAt ?? Date()
            model.modifiedAt = s.modifiedAt ?? Date()
            model.importedAt = s.importedAt
            model.importSessionID = s.importSessionID

            // Route
            model.date = s.date ?? Date()
            model.fromAirport = s.fromAirport ?? ""
            model.toAirport = s.toAirport ?? ""
            model.flightNumber = s.flightNumber ?? ""

            // Aircraft
            model.aircraftType = s.aircraftType ?? ""
            model.aircraftReg = s.aircraftReg ?? ""

            // FOUND-10: All 8 String duration fields converted via TimeStringConverter
            model.blockTime      = TimeStringConverter.toSeconds(s.blockTime)
            model.simTime        = TimeStringConverter.toSeconds(s.simTime)
            model.nightTime      = TimeStringConverter.toSeconds(s.nightTime)
            model.p1Time         = TimeStringConverter.toSeconds(s.p1Time)
            model.p1usTime       = TimeStringConverter.toSeconds(s.p1usTime)
            model.p2Time         = TimeStringConverter.toSeconds(s.p2Time)
            model.instrumentTime = TimeStringConverter.toSeconds(s.instrumentTime)
            model.spInsTime      = TimeStringConverter.toSeconds(s.spInsTime)

            // Clock strings → seconds from midnight (FOUND-07)
            model.outTimeSeconds            = TimeStringConverter.clockStringToSecondsFromMidnight(s.outTime)
            model.inTimeSeconds             = TimeStringConverter.clockStringToSecondsFromMidnight(s.inTime)
            model.scheduledDepartureSeconds = TimeStringConverter.clockStringToSecondsFromMidnight(s.scheduledDeparture)
            model.scheduledArrivalSeconds   = TimeStringConverter.clockStringToSecondsFromMidnight(s.scheduledArrival)

            // Movements
            model.dayTakeoffs   = s.dayTakeoffs
            model.nightTakeoffs = s.nightTakeoffs
            model.dayLandings   = s.dayLandings
            model.nightLandings = s.nightLandings
            model.customCount   = s.customCount

            // Approaches
            model.isILS  = s.isILS
            model.isGLS  = s.isGLS
            model.isRNP  = s.isRNP
            model.isNPA  = s.isNPA
            model.isAIII = s.isAIII

            // Role
            model.isPilotFlying  = s.isPilotFlying
            model.isPositioning  = s.isPositioning

            // Crew
            model.captainName = s.captainName ?? ""
            model.foName      = s.foName ?? ""
            model.so1Name     = s.so1Name ?? ""
            model.so2Name     = s.so2Name ?? ""

            // Notes
            model.remarks = s.remarks ?? ""

            // Per RESEARCH.md §Pitfall 6: insert BEFORE setting any relationship.
            // Aircraft relationship is left nil in Phase 1 — wired in Phase 3.
            modelContext.insert(model)
            inserted += 1
        }

        try modelContext.save()
        return inserted
    }

    // MARK: - Row Count

    /// Returns the current number of `FlightModel` records in the context.
    ///
    /// Used for row-count verification (D-08) after `importLegacyFlights(_:)`.
    func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<FlightModel>())
    }
}
