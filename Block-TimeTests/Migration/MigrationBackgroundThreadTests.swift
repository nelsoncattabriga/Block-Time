//
//  MigrationBackgroundThreadTests.swift
//  Block-TimeTests
//
//  Verifies that CoreDataMigrationActor runs on a background thread (FOUND-11).
//  The actor MUST NOT bind to the main thread — see RESEARCH.md §Pitfall 4.
//

import XCTest
import SwiftData
@testable import Block_Time

final class MigrationBackgroundThreadTests: XCTestCase {

    func test_migrationActor_runsOnBackgroundThread() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = await Task.detached(priority: .userInitiated) {
            CoreDataMigrationActor(modelContainer: container)
        }.value
        let isMain = await actor.assertIsMainThread()
        XCTAssertFalse(isMain,
            "Migration actor MUST run off the main thread (FOUND-11). Did caller forget Task.detached?")
    }
}
