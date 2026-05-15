import Foundation
import SwiftData

/// SwiftData @Model class representing an aircraft in the roster.
/// Lives in app target (D-05 — @Model cannot live in Swift Package).
/// All properties are optional or have defaults — CloudKit requirement (FOUND-08).
@Model
final class AircraftModel {
    var id: String = ""
    var type: String = ""
    var registration: String = ""
    var fullRegistration: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var flights: [FlightModel]?

    init(
        id: String = "",
        type: String = "",
        registration: String = "",
        fullRegistration: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.registration = registration
        self.fullRegistration = fullRegistration
        self.createdAt = createdAt
    }
}
