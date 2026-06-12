import Foundation
import CoreData

extension CrewContactEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CrewContactEntity> {
        return NSFetchRequest<CrewContactEntity>(entityName: "CrewContactEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?

}

extension CrewContactEntity: Identifiable {}
