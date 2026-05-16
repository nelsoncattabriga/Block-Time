//
//  PreviewInMemoryEnvironmentTests.swift
//  Block-TimeTests
//
//  Tests for the FlightRepository SwiftUI environment (FOUND-12).
//  Verifies that EnvironmentValues exposes a default InMemoryFlightRepository
//  so SwiftUI previews work without a CloudKit connection.
//
//  Plan 01-05
//

import XCTest
import SwiftUI
import BlockTimeData
import BlockTimeDomain
@testable import Block_Time

final class PreviewInMemoryEnvironmentTests: XCTestCase {

    /// FOUND-12: EnvironmentValues exposes a default InMemoryFlightRepository
    /// so SwiftUI previews work without a CloudKit connection.
    func test_environmentDefault_isInMemoryFlightRepository() {
        let env = EnvironmentValues()
        let repo = env.flightRepository
        XCTAssertTrue(repo is InMemoryFlightRepository, "Default environment must be InMemoryFlightRepository for preview support (FOUND-12).")
    }

    /// Setter replaces the default with a seeded in-memory repo.
    func test_environmentSetter_acceptsSeededRepo() async throws {
        let seed = [Flight.sampleForTesting()]
        var env = EnvironmentValues()
        env.flightRepository = InMemoryFlightRepository(seed: seed)
        let count = try await env.flightRepository.count()
        XCTAssertEqual(count, 1)
    }
}

// Test-only convenience constructor for Flight (kept here so production code stays unchanged).
private extension Flight {
    static func sampleForTesting() -> Flight {
        Flight(
            id: UUID(), date: Date(),
            fromAirport: "YSSY", toAirport: "YMML",
            flightNumber: "TEST", aircraftType: "B738", aircraftReg: "VH-TST",
            blockTime: 7200, simTime: 0, nightTime: 0,
            p1Time: 7200, p1usTime: 0, p2Time: 0,
            instrumentTime: 0, spInsTime: 0,
            outTimeSeconds: nil, inTimeSeconds: nil,
            dayTakeoffs: 1, nightTakeoffs: 0,
            dayLandings: 1, nightLandings: 0,
            isPilotFlying: true, isPositioning: false,
            isILS: false, isGLS: false, isRNP: false, isNPA: false, isAIII: false,
            captainName: "", foName: "", remarks: ""
        )
    }
}
