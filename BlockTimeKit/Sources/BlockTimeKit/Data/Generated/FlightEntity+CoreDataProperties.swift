import Foundation
import CoreData

extension FlightEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FlightEntity> {
        return NSFetchRequest<FlightEntity>(entityName: "FlightEntity")
    }

    @NSManaged public var aircraftReg: String?
    @NSManaged public var aircraftType: String?
    @NSManaged public var blockTime: String?
    @NSManaged public var captainName: String?
    @NSManaged public var counter1: String?
    @NSManaged public var counter2: String?
    @NSManaged public var counter3: String?
    @NSManaged public var counter4: String?
    @NSManaged public var counter5: String?
    @NSManaged public var counter6: String?
    @NSManaged public var counter7: String?
    @NSManaged public var counter8: String?
    @NSManaged public var counter9: String?
    @NSManaged public var counter10: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var customCount: Int16
    @NSManaged public var date: Date?
    @NSManaged public var dayLandings: Int16
    @NSManaged public var dayTakeoffs: Int16
    @NSManaged public var flightNumber: String?
    @NSManaged public var foName: String?
    @NSManaged public var fromAirport: String?
    @NSManaged public var id: UUID?
    @NSManaged public var importedAt: Date?
    @NSManaged public var importSessionID: UUID?
    @NSManaged public var instrumentTime: String?
    @NSManaged public var inTime: String?
    @NSManaged public var isAIII: Bool
    @NSManaged public var isGLS: Bool
    @NSManaged public var isILS: Bool
    @NSManaged public var isNPA: Bool
    @NSManaged public var isPilotFlying: Bool
    @NSManaged public var isPositioning: Bool
    @NSManaged public var isRNP: Bool
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var nightLandings: Int16
    @NSManaged public var nightTakeoffs: Int16
    @NSManaged public var nightTime: String?
    @NSManaged public var outTime: String?
    @NSManaged public var p1Time: String?
    @NSManaged public var p1usTime: String?
    @NSManaged public var p2Time: String?
    @NSManaged public var remarks: String?
    @NSManaged public var scheduledArrival: String?
    @NSManaged public var scheduledDeparture: String?
    @NSManaged public var simTime: String?
    @NSManaged public var so1Name: String?
    @NSManaged public var so2Name: String?
    @NSManaged public var spInsTime: String?
    @NSManaged public var toAirport: String?

}

extension FlightEntity: Identifiable {}
