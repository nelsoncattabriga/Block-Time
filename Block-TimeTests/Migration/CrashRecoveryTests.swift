//
//  CrashRecoveryTests.swift
//  Block-TimeTests
//
//  Verifies crash-recovery behaviour (D-06): when migrationStarted=true and
//  migrationComplete=false on launch, the partial SwiftData store is deleted
//  and migration retries successfully.
//

import XCTest
import SwiftData
@testable import Block_Time

@MainActor
final class CrashRecoveryTests: XCTestCase {

    // MARK: - Helper

    private func makeSnapshot(id: UUID = UUID()) -> LegacyFlightSnapshot {
        LegacyFlightSnapshot(
            id: id,
            createdAt: Date(),
            modifiedAt: Date(),
            importedAt: nil,
            importSessionID: nil,
            date: Date(),
            fromAirport: "SYD",
            toAirport: "BNE",
            flightNumber: "QF520",
            aircraftType: "A380",
            aircraftReg: "VH-OQA",
            blockTime: "1:30",
            simTime: nil,
            nightTime: nil,
            p1Time: "1:30",
            p1usTime: nil,
            p2Time: nil,
            instrumentTime: nil,
            spInsTime: nil,
            outTime: "08:00",
            inTime: "09:30",
            scheduledDeparture: "08:00",
            scheduledArrival: "09:30",
            dayTakeoffs: 1,
            nightTakeoffs: 0,
            dayLandings: 1,
            nightLandings: 0,
            customCount: 0,
            isILS: true,
            isGLS: false,
            isRNP: false,
            isNPA: false,
            isAIII: false,
            isPilotFlying: true,
            isPositioning: false,
            captainName: "Anderson",
            foName: "Brown",
            so1Name: "",
            so2Name: "",
            remarks: "Smooth flight"
        )
    }

    // MARK: - Test 1: Partial store file is replaced after crash recovery

    func test_crashRecovery_partialStoreIsReplaced() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!

        // Simulate a crashed state: started=true, complete=false
        defaults.set(true, forKey: "v2MigrationStarted")
        defaults.set(false, forKey: "v2MigrationComplete")

        // Create a dummy "partial" store file at the configured URL
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("crash-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let partialStoreURL = tmpDir.appendingPathComponent("partial.sqlite")
        let dummyData = Data("DUMMY_PARTIAL_STORE".utf8)
        try dummyData.write(to: partialStoreURL)

        let originalMtime = try FileManager.default.attributesOfItem(
            atPath: partialStoreURL.path
        )[.modificationDate] as? Date

        let container = try ModelContainerFactory.makeInMemoryContainer()
        let snapshots = [makeSnapshot(), makeSnapshot()]

        let deps = CoreDataMigrationService.Dependencies(
            defaults: defaults,
            swiftDataStoreURL: partialStoreURL,
            makeMigrationContainer: { container },
            fetchLegacySnapshots: { snapshots },
            coreDataCount: { snapshots.count },
            onComplete: {}
        )

        let service = CoreDataMigrationService(dependencies: deps)
        XCTAssertEqual(service.state, .crashed,
            "Pre-condition: state must be .crashed (started=true, complete=false)")

        try await service.runIfNeeded()

        // The partial store file must be gone (deleted by crash recovery)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: partialStoreURL.path),
            "Crash recovery must delete the partial store file at the configured URL (D-06)"
        )

        // Clean up
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: - Test 2: After crash recovery, migrationComplete=true and count matches

    func test_crashRecovery_completesSuccessfully() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!

        // Simulate a crashed state
        defaults.set(true, forKey: "v2MigrationStarted")
        defaults.set(false, forKey: "v2MigrationComplete")

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("crash-complete-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let storeURL = tmpDir.appendingPathComponent("blocktime.sqlite")

        // Write dummy bytes to simulate a partial store
        try Data("PARTIAL".utf8).write(to: storeURL)

        let container = try ModelContainerFactory.makeInMemoryContainer()
        let snapshots = (0..<4).map { _ in makeSnapshot() }

        let deps = CoreDataMigrationService.Dependencies(
            defaults: defaults,
            swiftDataStoreURL: storeURL,
            makeMigrationContainer: { container },
            fetchLegacySnapshots: { snapshots },
            coreDataCount: { snapshots.count },
            onComplete: {}
        )

        let service = CoreDataMigrationService(dependencies: deps)
        try await service.runIfNeeded()

        XCTAssertTrue(defaults.bool(forKey: "v2MigrationComplete"),
            "migrationComplete must be true after successful crash-recovery migration (D-06)")

        // Verify record count in SwiftData
        let ctx = ModelContext(container)
        let count = try ctx.fetchCount(FetchDescriptor<FlightModel>())
        XCTAssertEqual(count, 4,
            "SwiftData store must contain 4 records matching the 4 snapshots provided")

        // Clean up
        try? FileManager.default.removeItem(at: tmpDir)
    }
}
