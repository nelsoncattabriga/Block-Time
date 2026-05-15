import XCTest
import SwiftData
@testable import Block_Time

final class ModelContainerFactoryTests: XCTestCase {

    func test_appGroupID_isCorrect() {
        XCTAssertEqual(ModelContainerFactory.appGroupID, "group.com.thezoolab.blocktime")
    }

    func test_iCloudContainerID_isCorrect() {
        XCTAssertEqual(ModelContainerFactory.iCloudContainerID, "iCloud.com.thezoolab.blocktime")
    }

    func test_appGroupStoreURL_containsGroupIDAndSqliteFilename() {
        let url = ModelContainerFactory.appGroupStoreURL()
        XCTAssertTrue(url.path.contains("group.com.thezoolab.blocktime"),
                      "URL path should contain App Group identifier, got: \(url.path)")
        XCTAssertEqual(url.lastPathComponent, "blocktime.sqlite",
                       "URL last component should be blocktime.sqlite, got: \(url.lastPathComponent)")
    }

    func test_makeInMemoryContainer_succeeds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        XCTAssertNotNil(container)
    }

    func test_makeMigrationContainer_succeedsWithCloudKitNone() throws {
        // Migration container must be creatable without iCloud entitlements (cloudKitDatabase: .none)
        // If CloudKit were enabled this would fail in a test environment without iCloud provisioning
        let container = try ModelContainerFactory.makeMigrationContainer()
        XCTAssertNotNil(container)
    }
}
