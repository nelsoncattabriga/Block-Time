//
//  LegacyFlightSnapshot.swift
//  Block-Time
//
//  Sendable DTO carrying a single v1 FlightEntity across the actor boundary (FOUND-11).
//  Core Data NSManagedObjects are NOT Sendable — they must be read on the source context's
//  thread and converted to this value type before being passed to the migration actor.
//
//  Plan 01-04 (FOUND-09, FOUND-10, FOUND-11)
//

import Foundation

/// Sendable value type snapshot of a v1 `FlightEntity` Core Data record.
///
/// All fields are captured in their raw v1 storage format:
/// - Time fields (`blockTime`, `simTime`, etc.) are `String?` as stored in Core Data.
/// - Clock strings (`outTime`, `inTime`, etc.) are `String?` as stored ("HH:mm").
/// - Integer movement fields (`dayTakeoffs`, etc.) are `Int` (converted from `Int16`).
/// - Boolean fields are `Bool`.
///
/// `CoreDataMigrationActor.importLegacyFlights(_:)` converts these to v2 types via
/// `TimeStringConverter`.
struct LegacyFlightSnapshot: Sendable {

    // MARK: - Identity

    let id: UUID?
    let createdAt: Date?
    let modifiedAt: Date?
    let importedAt: Date?
    let importSessionID: UUID?

    // MARK: - Route

    let date: Date?
    let fromAirport: String?
    let toAirport: String?
    let flightNumber: String?

    // MARK: - Aircraft

    let aircraftType: String?
    let aircraftReg: String?

    // MARK: - Times (v1 stored as String?)

    let blockTime: String?
    let simTime: String?
    let nightTime: String?
    let p1Time: String?
    let p1usTime: String?
    let p2Time: String?
    let instrumentTime: String?
    let spInsTime: String?

    // MARK: - Clock strings ("HH:mm")

    let outTime: String?
    let inTime: String?
    let scheduledDeparture: String?
    let scheduledArrival: String?

    // MARK: - Movements (v1 Int16 — converted to Int at snapshot time)

    let dayTakeoffs: Int
    let nightTakeoffs: Int
    let dayLandings: Int
    let nightLandings: Int
    let customCount: Int

    // MARK: - Approaches

    let isILS: Bool
    let isGLS: Bool
    let isRNP: Bool
    let isNPA: Bool
    let isAIII: Bool

    // MARK: - Role

    let isPilotFlying: Bool
    let isPositioning: Bool

    // MARK: - Crew

    let captainName: String?
    let foName: String?
    let so1Name: String?
    let so2Name: String?

    // MARK: - Notes

    let remarks: String?
}
