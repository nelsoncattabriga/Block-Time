import XCTest
@testable import BlockTimeDomain

final class FlightTests: XCTestCase {

    func test_Flight_isSendableIdentifiableHashable() {
        // Compile-time conformance check.
        let _: any Sendable & Identifiable & Hashable = Self.sample()
    }

    func test_Flight_equality_sameIDAndFields_areEqual() {
        let id = UUID()
        let a = Self.sample(id: id)
        let b = Self.sample(id: id)
        XCTAssertEqual(a, b)
    }

    func test_Flight_equality_differentID_areNotEqual() {
        let a = Self.sample(id: UUID())
        let b = Self.sample(id: UUID())
        XCTAssertNotEqual(a, b)
    }

    func test_Flight_fieldRoundTrip() {
        let f = Self.sample()
        XCTAssertEqual(f.fromAirport, "YSSY")
        XCTAssertEqual(f.toAirport, "YMML")
        XCTAssertEqual(f.blockTime, 7200)
        XCTAssertEqual(f.isPilotFlying, true)
    }

    private static func sample(id: UUID = UUID()) -> Flight {
        Flight(
            id: id,
            date: Date(timeIntervalSince1970: 0),
            fromAirport: "YSSY",
            toAirport: "YMML",
            flightNumber: "QF400",
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
            isILS: true,
            isGLS: false,
            isRNP: false,
            isNPA: false,
            isAIII: false,
            captainName: "JONES",
            foName: "SMITH",
            remarks: ""
        )
    }
}
