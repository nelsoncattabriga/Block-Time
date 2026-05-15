import XCTest
import SwiftData
@testable import Block_Time

final class SchemaVersionTests: XCTestCase {

    func test_SchemaV1_versionIdentifier_isOneZeroZero() {
        XCTAssertEqual(SchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
    }

    func test_SchemaV1_models_containsFlightAndAircraft() throws {
        XCTAssertEqual(SchemaV1.models.count, 2)
        let names = SchemaV1.models.map { String(describing: $0) }
        XCTAssertTrue(names.contains("FlightModel"))
        XCTAssertTrue(names.contains("AircraftModel"))
    }

    func test_ModelContainer_createsFromSchemaV1_succeeds() throws {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        XCTAssertNoThrow(try ModelContainer(for: schema, configurations: [config]))
    }
}
