import Foundation
import SwiftData

/// Three-way ModelContainer factory. All three configurations PIN the storage URL to the
/// shared App Group container (FOUND-02) so the widget extension can read the same store.
enum ModelContainerFactory {

    /// App Group identifier — must match the value in Block-Time.entitlements and WidgetFlightEntry.appGroupID.
    static let appGroupID = "group.com.thezoolab.blocktime"

    /// iCloud container identifier — must match the value in Block-Time.entitlements.
    static let iCloudContainerID = "iCloud.com.thezoolab.blocktime"

    /// Production container: CloudKit private database, URL pinned to App Group.
    /// Does NOT pass `migrationPlan:` — Apple bug with CloudKit (RESEARCH.md §Pitfall 3).
    static func makeProductionContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let storeURL = appGroupStoreURL()
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(iCloudContainerID)
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Migration-time container: CloudKit DISABLED (D-09). URL pinned to App Group.
    /// Used by CoreDataMigrationService during the one-time v1 → v2 migration only.
    static func makeMigrationContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let storeURL = appGroupStoreURL()
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// In-memory container: for unit tests and SwiftUI previews (FOUND-12).
    /// CloudKit MUST be `.none` — `.automatic` on in-memory crashes (RESEARCH.md §Pitfall 3).
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Resolves the App Group container path and appends `blocktime.sqlite`.
    /// Crashes with a clear message if the App Group is not provisioned in entitlements.
    static func appGroupStoreURL() -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("App Group '\(appGroupID)' is not provisioned. Check Block-Time.entitlements.")
        }
        return container.appendingPathComponent("blocktime.sqlite")
    }
}
