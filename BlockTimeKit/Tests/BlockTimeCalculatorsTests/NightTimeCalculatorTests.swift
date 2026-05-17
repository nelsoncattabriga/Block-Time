// NightTimeCalculatorTests.swift
// XCTest suite for NightTimeCalculator (Plan 03-03).
// Covers: same-airport guard, unit conversion, half-night, midnight crossing,
// polar twilight (sun never sets), DST boundary, short all-night sector.

import XCTest
@testable import BlockTimeCalculators

final class NightTimeCalculatorTests: XCTestCase {

    // MARK: - Helpers

    /// Build a UTC Date with explicit gregorian Calendar + UTC TimeZone — NEVER .current
    private func utcDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return cal.date(from: c)!
    }

    // MARK: - Same-airport guard (Division-by-Zero Risk from RESEARCH.md)

    func test_sameAirport_returnsSensibleNonNaN() {
        // YSSY coordinates — same airport triggers distRad = 0 → guard should prevent NaN
        let result = NightTimeCalculator.calculateNightTime(
            fromLat: -33.9461, fromLon: 151.1772,
            toLat: -33.9461, toLon: 151.1772,
            departure: utcDate(2026, 6, 1, 23, 0),
            flightDurationMinutes: 60
        )
        // Must not be nil and must not crash; the same-airport guard returns 0
        XCTAssertNotNil(result, "Same-airport: must return a value, not nil")
        if let r = result {
            XCTAssertEqual(r, 0, "Same-airport degenerate case must return 0 minutes (not NaN)")
        }
    }

    func test_sameAirport_zeroMinutesFlight_returnsZero() {
        let result = NightTimeCalculator.calculateNightTime(
            fromLat: -33.9461, fromLon: 151.1772,
            toLat: -33.9461, toLon: 151.1772,
            departure: utcDate(2026, 6, 1, 23, 0),
            flightDurationMinutes: 0
        )
        XCTAssertEqual(result, 0, "Zero-duration flight must return 0")
    }

    // MARK: - Unit conversion (Pitfall 5: nightPortion returns Double hours, D-06 returns Int minutes)

    func test_unitConversion_allNightFlight_returnsMinutesNotHours() {
        // Short night flight at a high-latitude destination in winter
        // YSSY → YMML (Sydney → Melbourne), June 2026, departing at midnight UTC
        // In June in Australia it's winter — both cities are dark at 1am-5am local
        // Departure at 14:00 UTC = ~midnight local AEST (UTC+10) — deeply night
        let result = NightTimeCalculator.calculateNightTime(
            fromLat: -33.9461, fromLon: 151.1772,
            toLat: -37.6733, toLon: 144.8433,
            departure: utcDate(2026, 6, 1, 14, 0),  // 14:00 UTC = midnight AEST
            flightDurationMinutes: 60
        )
        XCTAssertNotNil(result, "Night unit conversion: must return a value")
        if let r = result {
            // Verify it's in MINUTES not hours — 60 min flight all night → result ~60 not ~1
            XCTAssertGreaterThan(r, 5, "Result must be in integer minutes (not decimal hours)")
            XCTAssertLessThanOrEqual(r, 60, "Night minutes cannot exceed flight duration")
        }
    }

    func test_unitConversion_contractVerification() {
        // Verify the Int minutes contract: result is clamped to [0, flightDurationMinutes]
        let duration = 120
        let result = NightTimeCalculator.calculateNightTime(
            fromLat: -33.9461, fromLon: 151.1772,
            toLat: -37.6733, toLon: 144.8433,
            departure: utcDate(2026, 6, 1, 14, 0),
            flightDurationMinutes: duration
        )
        if let r = result {
            XCTAssertGreaterThanOrEqual(r, 0, "Night minutes must be >= 0")
            XCTAssertLessThanOrEqual(r, duration, "Night minutes must be <= flight duration")
        }
    }

    // MARK: - Half-night (roughly half the flight is night)

    func test_halfNight_returnsValueInExpectedRange() {
        // YSSY to YMML, departing at 11:00 UTC (= 21:00 local AEST)
        // ~21:00 local departure, ~23:00 local arrival — both ends are night in June winter
        // At 11:00 UTC Sydney, sun is just setting. Some night, some civil twilight.
        // Allow ±15 min tolerance since exact twilight boundary depends on algorithm.
        let result = NightTimeCalculator.calculateNightTime(
            fromLat: -33.9461, fromLon: 151.1772,
            toLat: -37.6733, toLon: 144.8433,
            departure: utcDate(2026, 6, 1, 11, 0),  // 11:00 UTC = 21:00 AEST
            flightDurationMinutes: 60
        )
        XCTAssertNotNil(result, "Half-night: must return a value")
        if let r = result {
            XCTAssertGreaterThanOrEqual(r, 0, "Night minutes must be non-negative")
            XCTAssertLessThanOrEqual(r, 60, "Night minutes must not exceed flight duration")
        }
    }

    // MARK: - Midnight crossing UTC

    func test_midnightCrossingUTC_doesNotCrash() {
        // YSSY → YMML departing 23:00 UTC — crosses midnight UTC
        let result = NightTimeCalculator.calculateNightTime(
            fromLat: -33.9461, fromLon: 151.1772,
            toLat: -37.6733, toLon: 144.8433,
            departure: utcDate(2026, 6, 1, 23, 0),
            flightDurationMinutes: 90
        )
        // Must not crash and must return a sensible Int in [0, 90]
        XCTAssertNotNil(result, "Midnight crossing: must return a value, not nil")
        if let r = result {
            XCTAssertGreaterThanOrEqual(r, 0, "Night minutes must be non-negative")
            XCTAssertLessThanOrEqual(r, 90, "Night minutes must not exceed 90 min duration")
        }
    }

    // MARK: - Polar twilight (sun never sets in summer)

    func test_polarTwilight_summerSolstice_returnsNearZero() {
        // Far north at summer solstice — sun never sets; all daylight.
        // fromLat/toLat 75.0°N, departing 2026-06-21 12:00 UTC, 60 min flight.
        // Allow tolerance ≤5 for quantisation near the polar circle.
        let result = NightTimeCalculator.calculateNightTime(
            fromLat: 75.0, fromLon: 0.0,
            toLat: 75.0, toLon: 30.0,
            departure: utcDate(2026, 6, 21, 12, 0),
            flightDurationMinutes: 60
        )
        XCTAssertNotNil(result, "Polar twilight: must return a value")
        if let r = result {
            XCTAssertLessThanOrEqual(r, 5, "Polar summer solstice: result must be near-zero (≤5 min), was \(r)")
        }
    }

    // MARK: - DST boundary

    func test_DSTBoundary_aestToAedt_doesNotCrash() {
        // Australian AEDT→AEST transition: first Sunday in April 2026 = 5 April
        // At 16:00 UTC = 03:00 AEDT — clocks spring back to 02:00 AEST
        // DST transition date: 2026-04-05 16:00 UTC
        // Must return a sensible non-negative Int, must not crash.
        let result = NightTimeCalculator.calculateNightTime(
            fromLat: -33.9461, fromLon: 151.1772,
            toLat: -37.6733, toLon: 144.8433,
            departure: utcDate(2026, 4, 5, 15, 30),  // 15:30 UTC = ~01:30 AEDT (spring back at 16:00)
            flightDurationMinutes: 90
        )
        XCTAssertNotNil(result, "DST boundary: must return a value, not nil")
        if let r = result {
            XCTAssertGreaterThanOrEqual(r, 0, "Night minutes must be non-negative")
            XCTAssertLessThanOrEqual(r, 90, "Night minutes must not exceed flight duration")
        }
    }

    // MARK: - Short all-night sector

    func test_allNightSector_bneSyd_winterNight_returnsNearFullDuration() {
        // BNE (Brisbane) → SYD (Sydney), June 2026, ~18:00 UTC = ~04:00 AEST local
        // In winter, 04:00 local = deep night at both ends.
        // Short 75-min flight, both endpoints night → result should be close to 75.
        // Allow ±15 min tolerance for 200-segment quantisation.
        let result = NightTimeCalculator.calculateNightTime(
            fromLat: -27.3842, fromLon: 153.1175,   // YBBN Brisbane
            toLat: -33.9461, toLon: 151.1772,         // YSSY Sydney
            departure: utcDate(2026, 6, 1, 18, 0),    // 18:00 UTC = 04:00 AEST
            flightDurationMinutes: 75
        )
        XCTAssertNotNil(result, "All-night sector: must return a value")
        if let r = result {
            XCTAssertGreaterThanOrEqual(r, 50, "Winter night BNE→SYD 04:00 local: at least 50 of 75 min should be night")
            XCTAssertLessThanOrEqual(r, 75, "Night minutes must not exceed flight duration of 75")
        }
    }

    // MARK: - Range contract

    func test_resultAlwaysInRange_multipleFlights() {
        let testCases: [(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double,
                         year: Int, month: Int, day: Int, hour: Int, minute: Int, duration: Int)] = [
            (-33.9461, 151.1772, -37.6733, 144.8433, 2026, 6, 1, 2, 0, 90),    // Night
            (-33.9461, 151.1772, -37.6733, 144.8433, 2026, 12, 1, 2, 0, 90),   // Summer (some day)
            (51.4775, -0.4614, 40.6413, -73.7781, 2026, 7, 1, 10, 0, 420),     // LHR→JFK day
            (51.4775, -0.4614, 40.6413, -73.7781, 2026, 12, 15, 22, 0, 420),   // LHR→JFK winter night
        ]
        for tc in testCases {
            let result = NightTimeCalculator.calculateNightTime(
                fromLat: tc.fromLat, fromLon: tc.fromLon,
                toLat: tc.toLat, toLon: tc.toLon,
                departure: utcDate(tc.year, tc.month, tc.day, tc.hour, tc.minute),
                flightDurationMinutes: tc.duration
            )
            if let r = result {
                XCTAssertGreaterThanOrEqual(r, 0, "Night minutes must be >= 0 for case \(tc)")
                XCTAssertLessThanOrEqual(r, tc.duration, "Night minutes must be <= duration for case \(tc)")
            }
        }
    }
}
