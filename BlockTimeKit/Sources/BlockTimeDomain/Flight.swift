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

    // MARK: - Times (stored as Int minutes; converted from v1 String fields at migration)

    public var blockTime: Int       // v1: blockTime String?
    public var simTime: Int         // v1: simTime String?
    public var nightTime: Int       // v1: nightTime String?
    public var p1Time: Int          // v1: p1Time String?
    public var p1usTime: Int        // v1: p1usTime String?
    public var p2Time: Int          // v1: p2Time String?
    public var instrumentTime: Int  // v1: instrumentTime String?
    public var spInsTime: Int       // v1: spInsTime String?

    // MARK: - Additional time fields (D-13)

    public var dualTime: Int        // Sub-classification of P2 time

    // MARK: - Gate / slot times (UTC Date; converted from v1 "HH:MM" String fields)

    public var outTime: Date?       // v1: outTime String? e.g. "09:15"
    public var inTime: Date?        // v1: inTime String?
    public var scheduledDeparture: Date?  // v1: std String? (D-12)
    public var scheduledArrival: Date?    // v1: sta String?  (D-12)

    // MARK: - Movements

    public var dayTakeoffs: Int
    public var nightTakeoffs: Int
    public var dayLandings: Int
    public var nightLandings: Int
    public var customCount: Int     // NEW D-13

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
    public var so1Name: String      // NEW D-13
    public var so2Name: String      // NEW D-13
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
        blockTime: Int,
        simTime: Int,
        nightTime: Int,
        p1Time: Int,
        p1usTime: Int,
        p2Time: Int,
        instrumentTime: Int,
        spInsTime: Int,
        dualTime: Int,
        outTime: Date?,
        inTime: Date?,
        scheduledDeparture: Date?,
        scheduledArrival: Date?,
        dayTakeoffs: Int,
        nightTakeoffs: Int,
        dayLandings: Int,
        nightLandings: Int,
        customCount: Int,
        isPilotFlying: Bool,
        isPositioning: Bool,
        isILS: Bool,
        isGLS: Bool,
        isRNP: Bool,
        isNPA: Bool,
        isAIII: Bool,
        captainName: String,
        foName: String,
        so1Name: String,
        so2Name: String,
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
        self.dualTime = dualTime
        self.outTime = outTime
        self.inTime = inTime
        self.scheduledDeparture = scheduledDeparture
        self.scheduledArrival = scheduledArrival
        self.dayTakeoffs = dayTakeoffs
        self.nightTakeoffs = nightTakeoffs
        self.dayLandings = dayLandings
        self.nightLandings = nightLandings
        self.customCount = customCount
        self.isPilotFlying = isPilotFlying
        self.isPositioning = isPositioning
        self.isILS = isILS
        self.isGLS = isGLS
        self.isRNP = isRNP
        self.isNPA = isNPA
        self.isAIII = isAIII
        self.captainName = captainName
        self.foName = foName
        self.so1Name = so1Name
        self.so2Name = so2Name
        self.remarks = remarks
    }
}
