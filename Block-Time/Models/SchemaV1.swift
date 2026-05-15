import Foundation
import SwiftData

/// VersionedSchema wrapper for v2 SwiftData models. MUST exist from first build (FOUND-01).
/// Shipping unversioned then adding VersionedSchema later crashes existing users on update.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [FlightModel.self, AircraftModel.self]
    }
}

/// Migration plan placeholder. NOT passed to the production CloudKit container — Apple bug
/// (RESEARCH.md §Pitfall 3) causes fatal error. Used only by test/in-memory containers.
enum FlightMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
