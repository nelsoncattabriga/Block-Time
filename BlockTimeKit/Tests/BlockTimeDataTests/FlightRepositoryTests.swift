import XCTest
import BlockTimeData
import BlockTimeDomain

final class FlightRepositoryTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT() -> InMemoryFlightRepository {
        InMemoryFlightRepository()
    }

    private func makeFlight(
        id: UUID = UUID(),
        date: Date = Date(),
        fromAirport: String = "YSSY",
        toAirport: String = "YMML",
        flightNumber: String = "QF400"
    ) -> Flight {
        Flight(
            id: id,
            date: date,
            fromAirport: fromAirport,
            toAirport: toAirport,
            flightNumber: flightNumber,
            aircraftType: "B738",
            aircraftReg: "VH-ABC",
            blockTime: 7200,
            simTime: 0,
            nightTime: 0,
            p1Time: 7200,
            p1usTime: 0,
            p2Time: 0,
            instrumentTime: 0,
            spInsTime: 0,
            outTimeSeconds: 32400,
            inTimeSeconds: 39600,
            dayTakeoffs: 1,
            nightTakeoffs: 0,
            dayLandings: 1,
            nightLandings: 0,
            isPilotFlying: true,
            isPositioning: false,
            isILS: false,
            isGLS: false,
            isRNP: false,
            isNPA: false,
            isAIII: false,
            captainName: "JONES",
            foName: "SMITH",
            remarks: ""
        )
    }

    // MARK: - Tests

    func test_fetchAll_freshRepo_returnsEmpty() async throws {
        let sut = makeSUT()
        let result = try await sut.fetchAll()
        XCTAssertTrue(result.isEmpty)
    }

    func test_insert_thenFetchAll_returnsFlight() async throws {
        let sut = makeSUT()
        let flight = makeFlight()
        try await sut.insert(flight)
        let result = try await sut.fetchAll()
        XCTAssertEqual(result, [flight])
    }

    func test_count_freshRepo_isZero_afterInsert_isOne_afterDeleteAll_isZero() async throws {
        let sut = makeSUT()
        XCTAssertEqual(try await sut.count(), 0)
        try await sut.insert(makeFlight())
        XCTAssertEqual(try await sut.count(), 1)
        try await sut.deleteAll()
        XCTAssertEqual(try await sut.count(), 0)
    }

    func test_update_replacesExistingFlightWithSameID() async throws {
        let sut = makeSUT()
        let id = UUID()
        let original = makeFlight(id: id, fromAirport: "YSSY")
        try await sut.insert(original)

        var updated = original
        updated = Flight(
            id: id,
            date: original.date,
            fromAirport: "YMML",  // Changed field
            toAirport: original.toAirport,
            flightNumber: original.flightNumber,
            aircraftType: original.aircraftType,
            aircraftReg: original.aircraftReg,
            blockTime: original.blockTime,
            simTime: original.simTime,
            nightTime: original.nightTime,
            p1Time: original.p1Time,
            p1usTime: original.p1usTime,
            p2Time: original.p2Time,
            instrumentTime: original.instrumentTime,
            spInsTime: original.spInsTime,
            outTimeSeconds: original.outTimeSeconds,
            inTimeSeconds: original.inTimeSeconds,
            dayTakeoffs: original.dayTakeoffs,
            nightTakeoffs: original.nightTakeoffs,
            dayLandings: original.dayLandings,
            nightLandings: original.nightLandings,
            isPilotFlying: original.isPilotFlying,
            isPositioning: original.isPositioning,
            isILS: original.isILS,
            isGLS: original.isGLS,
            isRNP: original.isRNP,
            isNPA: original.isNPA,
            isAIII: original.isAIII,
            captainName: original.captainName,
            foName: original.foName,
            remarks: original.remarks
        )
        try await sut.update(updated)

        let result = try await sut.fetchAll()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.fromAirport, "YMML")
    }

    func test_delete_removesMatchingFlight_fetchAllReturnsEmpty() async throws {
        let sut = makeSUT()
        let id = UUID()
        let flight = makeFlight(id: id)
        try await sut.insert(flight)
        try await sut.delete(id: id)
        let result = try await sut.fetchAll()
        XCTAssertTrue(result.isEmpty)
    }

    func test_fetch_fromTo_returnsOnlyFlightsInDateRange() async throws {
        let sut = makeSUT()
        let referenceDate = Date(timeIntervalSince1970: 0)  // 1970-01-01

        let inside = makeFlight(id: UUID(), date: referenceDate)
        let before = makeFlight(id: UUID(), date: referenceDate.addingTimeInterval(-86400))  // 1 day before
        let after = makeFlight(id: UUID(), date: referenceDate.addingTimeInterval(86400))   // 1 day after

        try await sut.insert(inside)
        try await sut.insert(before)
        try await sut.insert(after)

        let from = referenceDate.addingTimeInterval(-3600)  // 1 hour before reference
        let to = referenceDate.addingTimeInterval(3600)     // 1 hour after reference
        let result = try await sut.fetch(from: from, to: to)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, inside.id)
    }

    func test_fetchRecent_returnsOnlyFlightsWithinLastNDays() async throws {
        let sut = makeSUT()
        let now = Date()
        let recentDate = now.addingTimeInterval(-3 * 86400)  // 3 days ago
        let oldDate = now.addingTimeInterval(-10 * 86400)    // 10 days ago

        let recent = makeFlight(id: UUID(), date: recentDate)
        let old = makeFlight(id: UUID(), date: oldDate)

        try await sut.insert(recent)
        try await sut.insert(old)

        let result = try await sut.fetchRecent(days: 7)

        XCTAssertTrue(result.contains(where: { $0.id == recent.id }))
        XCTAssertFalse(result.contains(where: { $0.id == old.id }))
    }

    func test_search_returnsFlightsMatchingQueryCaseInsensitive() async throws {
        let sut = makeSUT()
        let matchFromAirport = makeFlight(id: UUID(), fromAirport: "YSSY", toAirport: "YMML", flightNumber: "QF001")
        let matchToAirport = makeFlight(id: UUID(), fromAirport: "YMML", toAirport: "YBBN", flightNumber: "QF002")
        let matchFlightNumber = makeFlight(id: UUID(), fromAirport: "EGLL", toAirport: "EDDF", flightNumber: "BA123")
        let noMatch = makeFlight(id: UUID(), fromAirport: "KLAX", toAirport: "KJFK", flightNumber: "AA456")

        try await sut.insert(matchFromAirport)
        try await sut.insert(matchToAirport)
        try await sut.insert(matchFlightNumber)
        try await sut.insert(noMatch)

        // Query "yssy" matches fromAirport "YSSY" case-insensitively
        let resultSydney = try await sut.search(query: "yssy")
        XCTAssertEqual(resultSydney.count, 1)
        XCTAssertEqual(resultSydney.first?.id, matchFromAirport.id)

        // Query "ba" matches flightNumber "BA123"
        let resultBA = try await sut.search(query: "ba")
        XCTAssertEqual(resultBA.count, 1)
        XCTAssertEqual(resultBA.first?.id, matchFlightNumber.id)

        // Query "YMML" matches both fromAirport and toAirport records
        let resultMelbourne = try await sut.search(query: "YMML")
        XCTAssertEqual(resultMelbourne.count, 2)
    }
}
