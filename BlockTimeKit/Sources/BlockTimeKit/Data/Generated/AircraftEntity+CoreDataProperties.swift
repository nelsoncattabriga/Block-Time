import Foundation
import CoreData

extension AircraftEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AircraftEntity> {
        return NSFetchRequest<AircraftEntity>(entityName: "AircraftEntity")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var fullRegistration: String?
    @NSManaged public var id: String?
    @NSManaged public var registration: String?
    @NSManaged public var type: String?

}

extension AircraftEntity: Identifiable {}
