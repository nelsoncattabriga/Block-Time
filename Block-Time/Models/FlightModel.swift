import Foundation
import SwiftData

/// SwiftData @Model class representing a flight sector.
/// Lives in app target (D-05 — @Model cannot live in Swift Package).
/// All properties are optional or have defaults — CloudKit requirement (FOUND-08).
/// Wrapped in SchemaV1: VersionedSchema from first build (FOUND-01).
@Model
final class FlightModel {

    // MARK: - Identity

    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var importedAt: Date?
    var importSessionID: UUID?

    // MARK: - Route

    var date: Date = Date()             // UTC midnight of the flight date (FOUND-07)
    var fromAirport: String = ""
    var toAirport: String = ""
    var flightNumber: String = ""

    // MARK: - Aircraft

    var aircraftType: String = ""
    var aircraftReg: String = ""

    // MARK: - Times (stored as seconds; converted from v1 String fields — FOUND-06)

    var blockTime: TimeInterval = 0       // v1: blockTime String?
    var simTime: TimeInterval = 0         // v1: simTime String?
    var nightTime: TimeInterval = 0       // v1: nightTime String?
    var p1Time: TimeInterval = 0          // v1: p1Time String?
    var p1usTime: TimeInterval = 0        // v1: p1usTime String?
    var p2Time: TimeInterval = 0          // v1: p2Time String?
    var instrumentTime: TimeInterval = 0  // v1: instrumentTime String?
    var spInsTime: TimeInterval = 0       // v1: spInsTime String?

    // MARK: - Gate / slot times (seconds from midnight UTC on date)
    // v1 stores these as HH:MM strings; v2 stores as seconds-from-midnight (FOUND-07)

    var outTimeSeconds: TimeInterval?         // v1: outTime String? e.g. "09:15" → 33300
    var inTimeSeconds: TimeInterval?          // v1: inTime String?
    var scheduledDepartureSeconds: TimeInterval?  // v1: scheduledDeparture String?
    var scheduledArrivalSeconds: TimeInterval?    // v1: scheduledArrival String?

    // MARK: - Movements

    var dayTakeoffs: Int = 0
    var nightTakeoffs: Int = 0
    var dayLandings: Int = 0
    var nightLandings: Int = 0
    var customCount: Int = 0

    // MARK: - Approach booleans

    var isILS: Bool = false
    var isGLS: Bool = false
    var isRNP: Bool = false
    var isNPA: Bool = false
    var isAIII: Bool = false

    // MARK: - Role / Type

    var isPilotFlying: Bool = false
    var isPositioning: Bool = false

    // MARK: - Crew

    var captainName: String = ""
    var foName: String = ""
    var so1Name: String = ""
    var so2Name: String = ""

    // MARK: - Notes

    var remarks: String = ""

    // MARK: - Relationship (optional per CloudKit constraint — FOUND-08)

    @Relationship(deleteRule: .nullify, inverse: \AircraftModel.flights)
    var aircraft: AircraftModel?

    // MARK: - Init

    init() {}
}
