import XCTest
import SwiftData
import BlockTimeDomain
import BlockTimeData
@testable import Block_Time

final class SwiftDataFlightRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var repo: SwiftDataFlightRepository!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainerFactory.makeInMemoryContainer()
        repo = SwiftDataFlightRepository(container: container)
    }

    override func tearDown() async throws {
        try await repo.deleteAll()
        container = nil
        repo = nil
        try await super.tearDown()
    }

    // MARK: - Test 1: fetchAll on empty returns []

    func test_fetchAll_emptyRepo_returnsEmpty() async throws {
        let flights = try await repo.fetchAll()
        XCTAssertEqual(flights.count, 0)
    }

    // MARK: - Test 2: insert then fetchAll returns the inserted flight with all fields

    func test_insert_thenFetchAll_roundTripsAllFields() async throws {
        let flight = sampleFullFlight()
        try await repo.insert(flight)

        let fetched = try await repo.fetchAll()
        XCTAssertEqual(fetched.count, 1)

        let result = try XCTUnwrap(fetched.first)

        XCTAssertEqual(result.id, flight.id)
        XCTAssertEqual(result.date.timeIntervalSince1970, flight.date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(result.fromAirport, flight.fromAirport)
        XCTAssertEqual(result.toAirport, flight.toAirport)
        XCTAssertEqual(result.flightNumber, flight.flightNumber)
        XCTAssertEqual(result.aircraftType, flight.aircraftType)
        XCTAssertEqual(result.aircraftReg, flight.aircraftReg)
        XCTAssertEqual(result.blockTime, flight.blockTime)
        XCTAssertEqual(result.simTime, flight.simTime)
        XCTAssertEqual(result.nightTime, flight.nightTime)
        XCTAssertEqual(result.p1Time, flight.p1Time)
        XCTAssertEqual(result.p1usTime, flight.p1usTime)
        XCTAssertEqual(result.p2Time, flight.p2Time)
        XCTAssertEqual(result.instrumentTime, flight.instrumentTime)
        XCTAssertEqual(result.spInsTime, flight.spInsTime)
        XCTAssertEqual(result.outTimeSeconds, flight.outTimeSeconds)
        XCTAssertEqual(result.inTimeSeconds, flight.inTimeSeconds)
        XCTAssertEqual(result.dayTakeoffs, flight.dayTakeoffs)
        XCTAssertEqual(result.nightTakeoffs, flight.nightTakeoffs)
        XCTAssertEqual(result.dayLandings, flight.dayLandings)
        XCTAssertEqual(result.nightLandings, flight.nightLandings)
        XCTAssertEqual(result.isPilotFlying, flight.isPilotFlying)
        XCTAssertEqual(result.isPositioning, flight.isPositioning)
        XCTAssertEqual(result.isILS, flight.isILS)
        XCTAssertEqual(result.isGLS, flight.isGLS)
        XCTAssertEqual(result.isRNP, flight.isRNP)
        XCTAssertEqual(result.isNPA, flight.isNPA)
        XCTAssertEqual(result.isAIII, flight.isAIII)
        XCTAssertEqual(result.captainName, flight.captainName)
        XCTAssertEqual(result.foName, flight.foName)
        XCTAssertEqual(result.remarks, flight.remarks)
    }

    // MARK: - Test 3: count returns correct number

    func test_count_afterInserts_returnsCorrectNumber() async throws {
        XCTAssertEqual(try await repo.count(), 0)
        try await repo.insert(sampleFullFlight())
        XCTAssertEqual(try await repo.count(), 1)
        try await repo.insert(sampleFullFlight(id: UUID()))
        XCTAssertEqual(try await repo.count(), 2)
    }

    // MARK: - Test 4: update replaces an existing flight

    func test_update_replacesExistingFlight_blockTimeUpdated() async throws {
        var flight = sampleFullFlight()
        try await repo.insert(flight)

        flight.blockTime = 99999
        try await repo.update(flight)

        let fetched = try await repo.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.blockTime, 99999)
    }

    // MARK: - Test 5: delete removes the matching record

    func test_delete_removesMatchingRecord() async throws {
        let flight = sampleFullFlight()
        try await repo.insert(flight)
        XCTAssertEqual(try await repo.count(), 1)

        try await repo.delete(id: flight.id)
        XCTAssertEqual(try await repo.count(), 0)
    }

    // MARK: - Test 6: FOUND-06 — blockTime: TimeInterval round-trips unchanged

    func test_blockTime_16308_roundTrips() async throws {
        var flight = sampleFullFlight()
        flight.blockTime = 16308  // 4h 31m 48s
        try await repo.insert(flight)

        let fetched = try await repo.fetchAll()
        XCTAssertEqual(fetched.first?.blockTime, 16308, accuracy: 0.001)
    }

    // MARK: - Test 7: FOUND-07 — date (UTC) round-trips unchanged

    func test_utcDate_roundTrips_timeIntervalUnchanged() async throws {
        var flight = sampleFullFlight()
        // Use a fixed timestamp to avoid floating point issues
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        flight = Flight(
            id: flight.id,
            date: fixedDate,
            fromAirport: flight.fromAirport,
            toAirport: flight.toAirport,
            flightNumber: flight.flightNumber,
            aircraftType: flight.aircraftType,
            aircraftReg: flight.aircraftReg,
            blockTime: flight.blockTime,
            simTime: flight.simTime,
            nightTime: flight.nightTime,
            p1Time: flight.p1Time,
            p1usTime: flight.p1usTime,
            p2Time: flight.p2Time,
            instrumentTime: flight.instrumentTime,
            spInsTime: flight.spInsTime,
            outTimeSeconds: flight.outTimeSeconds,
            inTimeSeconds: flight.inTimeSeconds,
            dayTakeoffs: flight.dayTakeoffs,
            nightTakeoffs: flight.nightTakeoffs,
            dayLandings: flight.dayLandings,
            nightLandings: flight.nightLandings,
            isPilotFlying: flight.isPilotFlying,
            isPositioning: flight.isPositioning,
            isILS: flight.isILS,
            isGLS: flight.isGLS,
            isRNP: flight.isRNP,
            isNPA: flight.isNPA,
            isAIII: flight.isAIII,
            captainName: flight.captainName,
            foName: flight.foName,
            remarks: flight.remarks
        )
        try await repo.insert(flight)

        let fetched = try await repo.fetchAll()
        let roundTripped = try XCTUnwrap(fetched.first)
        XCTAssertEqual(
            roundTripped.date.timeIntervalSince1970,
            fixedDate.timeIntervalSince1970,
            accuracy: 0.001,
            "UTC Date must round-trip unchanged through SwiftData"
        )
    }

    // MARK: - Helpers

    func sampleFullFlight(id: UUID = UUID()) -> Flight {
        Flight(
            id: id,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            fromAirport: "SYD",
            toAirport: "MEL",
            flightNumber: "QF400",
            aircraftType: "B738",
            aircraftReg: "VH-VZA",
            blockTime: 16308,        // 4h 31m 48s (FOUND-06 key value)
            simTime: 0,
            nightTime: 1800,
            p1Time: 16308,
            p1usTime: 0,
            p2Time: 0,
            instrumentTime: 3600,
            spInsTime: 0,
            outTimeSeconds: 32400,   // 09:00
            inTimeSeconds: 49200,    // 13:40
            dayTakeoffs: 1,
            nightTakeoffs: 0,
            dayLandings: 1,
            nightLandings: 0,
            isPilotFlying: true,
            isPositioning: false,
            isILS: true,
            isGLS: false,
            isRNP: false,
            isNPA: false,
            isAIII: false,
            captainName: "Smith",
            foName: "Jones",
            remarks: "Smooth flight"
        )
    }
}
