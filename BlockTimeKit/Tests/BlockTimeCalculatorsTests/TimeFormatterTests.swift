// TimeFormatterTests.swift
// XCTest suite for BlockTimeCalculators.TimeFormatter.
// Covers all four pure functions plus round-trip (CALC-08).

import XCTest
@testable import BlockTimeCalculators

final class TimeFormatterTests: XCTestCase {

    // MARK: - minutesToHHMM

    func test_minutesToHHMM_zero_returnsZeroColonZero() {
        XCTAssertEqual(TimeFormatter.minutesToHHMM(0), "0:00")
    }

    func test_minutesToHHMM_90_returnsOneColon30() {
        XCTAssertEqual(TimeFormatter.minutesToHHMM(90), "1:30")
    }

    func test_minutesToHHMM_645_returns10Colon45() {
        XCTAssertEqual(TimeFormatter.minutesToHHMM(645), "10:45")
    }

    func test_minutesToHHMM_negative_returnsZeroColonZero() {
        XCTAssertEqual(TimeFormatter.minutesToHHMM(-5), "0:00")
    }

    // MARK: - minutesToDecimalHours

    func test_minutesToDecimalHours_zero_returnsZeroDotZero() {
        XCTAssertEqual(TimeFormatter.minutesToDecimalHours(0), "0.00")
    }

    func test_minutesToDecimalHours_90_returnsOneDotFifty() {
        XCTAssertEqual(TimeFormatter.minutesToDecimalHours(90), "1.50")
    }

    func test_minutesToDecimalHours_645_returns10Dot75() {
        XCTAssertEqual(TimeFormatter.minutesToDecimalHours(645), "10.75")
    }

    // MARK: - hhmmToMinutes

    func test_hhmmToMinutes_zeroColon00_returnsZero() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes("0:00"), 0)
    }

    func test_hhmmToMinutes_oneColon30_returns90() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes("1:30"), 90)
    }

    func test_hhmmToMinutes_leadingZero_returns90() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes("01:30"), 90)
    }

    func test_hhmmToMinutes_tenColon45_returns645() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes("10:45"), 645)
    }

    func test_hhmmToMinutes_minutesOver59_returnsNil() {
        XCTAssertNil(TimeFormatter.hhmmToMinutes("1:99"))
    }

    func test_hhmmToMinutes_nonNumeric_returnsNil() {
        XCTAssertNil(TimeFormatter.hhmmToMinutes("abc"))
    }

    func test_hhmmToMinutes_emptyString_returnsNil() {
        XCTAssertNil(TimeFormatter.hhmmToMinutes(""))
    }

    func test_hhmmToMinutes_missingMinutes_returnsNil() {
        XCTAssertNil(TimeFormatter.hhmmToMinutes("1:"))
    }

    func test_hhmmToMinutes_missingHours_returnsNil() {
        XCTAssertNil(TimeFormatter.hhmmToMinutes(":30"))
    }

    // MARK: - decimalHoursStringToMinutes

    func test_decimalHoursStringToMinutes_onePointFive_returns90() {
        XCTAssertEqual(TimeFormatter.decimalHoursStringToMinutes("1.5"), 90)
    }

    func test_decimalHoursStringToMinutes_zeroDotZero_returnsZero() {
        XCTAssertEqual(TimeFormatter.decimalHoursStringToMinutes("0.0"), 0)
    }

    func test_decimalHoursStringToMinutes_tenDot75_returns645() {
        XCTAssertEqual(TimeFormatter.decimalHoursStringToMinutes("10.75"), 645)
    }

    func test_decimalHoursStringToMinutes_hhmmFormat_returns90() {
        // Delegates to hhmmToMinutes when ":" present.
        XCTAssertEqual(TimeFormatter.decimalHoursStringToMinutes("1:30"), 90)
    }

    func test_decimalHoursStringToMinutes_nonNumeric_returnsNil() {
        XCTAssertNil(TimeFormatter.decimalHoursStringToMinutes("abc"))
    }

    func test_decimalHoursStringToMinutes_emptyString_returnsNil() {
        XCTAssertNil(TimeFormatter.decimalHoursStringToMinutes(""))
    }

    func test_decimalHoursStringToMinutes_negative_returnsNil() {
        XCTAssertNil(TimeFormatter.decimalHoursStringToMinutes("-1.5"))
    }

    // MARK: - Round-trip: hhmmToMinutes(minutesToHHMM(n)) == n

    func test_roundTrip_zero() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes(TimeFormatter.minutesToHHMM(0)), 0)
    }

    func test_roundTrip_30() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes(TimeFormatter.minutesToHHMM(30)), 30)
    }

    func test_roundTrip_60() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes(TimeFormatter.minutesToHHMM(60)), 60)
    }

    func test_roundTrip_90() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes(TimeFormatter.minutesToHHMM(90)), 90)
    }

    func test_roundTrip_645() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes(TimeFormatter.minutesToHHMM(645)), 645)
    }

    func test_roundTrip_1440() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes(TimeFormatter.minutesToHHMM(1440)), 1440)
    }

    func test_roundTrip_9999() {
        XCTAssertEqual(TimeFormatter.hhmmToMinutes(TimeFormatter.minutesToHHMM(9999)), 9999)
    }
}
