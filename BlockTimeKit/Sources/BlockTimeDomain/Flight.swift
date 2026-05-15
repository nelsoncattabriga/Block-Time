import Foundation

/// Value-type domain struct representing a single flight sector.
/// Zero persistence coupling — no SwiftData or Core Data annotations.
/// Maps 1:1 with v1 FlightEntity fields (FOUND-04).
public struct Flight: Sendable, Identifiable, Hashable {

    // MARK: - Identity

    public var id: UUID
    public var date: Date  // UTC midnight of the flight date

    // MARK: - Route

    public var fromAirport: String
    public var toAirport: String
    public var flightNumber: String

    // MARK: - Aircraft

    public var aircraftType: String
    public var aircraftReg: String

    // MARK: - Times (stored as seconds; converted from v1 String fields)

    public var blockTime: TimeInterval      // v1: blockTime String?
    public var simTime: TimeInterval        // v1: simTime String?
    public var nightTime: TimeInterval      // v1: nightTime String?
    public var p1Time: TimeInterval         // v1: p1Time String?
    public var p1usTime: TimeInterval       // v1: p1usTime String?
    public var p2Time: TimeInterval         // v1: p2Time String?
    public var instrumentTime: TimeInterval // v1: instrumentTime String?
    public var spInsTime: TimeInterval      // v1: spInsTime String?

    // MARK: - Gate / slot times (seconds from midnight UTC on date)

    public var outTimeSeconds: TimeInterval?  // v1: outTime String? e.g. "09:15" → 33300
    public var inTimeSeconds: TimeInterval?   // v1: inTime String?

    // MARK: - Movements

    public var dayTakeoffs: Int
    public var nightTakeoffs: Int
    public var dayLandings: Int
    public var nightLandings: Int

    // MARK: - Role

    public var isPilotFlying: Bool
    public var isPositioning: Bool

    // MARK: - Approaches

    public var isILS: Bool
    public var isGLS: Bool
    public var isRNP: Bool
    public var isNPA: Bool
    public var isAIII: Bool

    // MARK: - Crew

    public var captainName: String
    public var foName: String
    public var remarks: String

    // MARK: - Init

    public init(
        id: UUID,
        date: Date,
        fromAirport: String,
        toAirport: String,
        flightNumber: String,
        aircraftType: String,
        aircraftReg: String,
        blockTime: TimeInterval,
        simTime: TimeInterval,
        nightTime: TimeInterval,
        p1Time: TimeInterval,
        p1usTime: TimeInterval,
        p2Time: TimeInterval,
        instrumentTime: TimeInterval,
        spInsTime: TimeInterval,
        outTimeSeconds: TimeInterval?,
        inTimeSeconds: TimeInterval?,
        dayTakeoffs: Int,
        nightTakeoffs: Int,
        dayLandings: Int,
        nightLandings: Int,
        isPilotFlying: Bool,
        isPositioning: Bool,
        isILS: Bool,
        isGLS: Bool,
        isRNP: Bool,
        isNPA: Bool,
        isAIII: Bool,
        captainName: String,
        foName: String,
        remarks: String
    ) {
        self.id = id
        self.date = date
        self.fromAirport = fromAirport
        self.toAirport = toAirport
        self.flightNumber = flightNumber
        self.aircraftType = aircraftType
        self.aircraftReg = aircraftReg
        self.blockTime = blockTime
        self.simTime = simTime
        self.nightTime = nightTime
        self.p1Time = p1Time
        self.p1usTime = p1usTime
        self.p2Time = p2Time
        self.instrumentTime = instrumentTime
        self.spInsTime = spInsTime
        self.outTimeSeconds = outTimeSeconds
        self.inTimeSeconds = inTimeSeconds
        self.dayTakeoffs = dayTakeoffs
        self.nightTakeoffs = nightTakeoffs
        self.dayLandings = dayLandings
        self.nightLandings = nightLandings
        self.isPilotFlying = isPilotFlying
        self.isPositioning = isPositioning
        self.isILS = isILS
        self.isGLS = isGLS
        self.isRNP = isRNP
        self.isNPA = isNPA
        self.isAIII = isAIII
        self.captainName = captainName
        self.foName = foName
        self.remarks = remarks
    }
}
