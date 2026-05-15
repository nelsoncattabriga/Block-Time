//
//  TimeStringConverterTests.swift
//  Block-TimeTests
//
//  Tests for TimeStringConverter — all v1 time-string format variants.
//  Plan 01-02 (FOUND-10): RED phase — TimeStringConverter does not exist yet.
//

import XCTest
@testable import Block_Time

final class TimeStringConverterTests: XCTestCase {

    // MARK: - toSeconds: nil / empty / zero

    func test_toSeconds_nil_returnsZero() {
        XCTAssertEqual(TimeStringConverter.toSeconds(nil), 0)
    }

    func test_toSeconds_emptyString_returnsZero() {
        XCTAssertEqual(TimeStringConverter.toSeconds(""), 0)
    }

    func test_toSeconds_stringZero_returnsZero() {
        XCTAssertEqual(TimeStringConverter.toSeconds("0"), 0)
    }

    func test_toSeconds_stringZeroPointZero_returnsZero() {
        XCTAssertEqual(TimeStringConverter.toSeconds("0.0"), 0)
    }

    // MARK: - toSeconds: decimal hours

    func test_toSeconds_decimal_4_53_returns16308() {
        XCTAssertEqual(TimeStringConverter.toSeconds("4.53"), 16308, accuracy: 0.001)
    }

    func test_toSeconds_decimal_4_5_returns16200() {
        XCTAssertEqual(TimeStringConverter.toSeconds("4.5"), 16200, accuracy: 0.001)
    }

    func test_toSeconds_integer_4_returns14400() {
        XCTAssertEqual(TimeStringConverter.toSeconds("4"), 14400, accuracy: 0.001)
    }

    // MARK: - toSeconds: HH:MM

    func test_toSeconds_HHMM_4_32_returns16320() {
        XCTAssertEqual(TimeStringConverter.toSeconds("4:32"), 16320)
    }

    func test_toSeconds_HHMM_9_05_returns32700() {
        XCTAssertEqual(TimeStringConverter.toSeconds("9:05"), 32700)
    }

    func test_toSeconds_HMM_4_5_returns14700() {
        XCTAssertEqual(TimeStringConverter.toSeconds("4:5"), 14700)
    }

    // MARK: - toSeconds: malformed

    func test_toSeconds_dash_returnsZero() {
        XCTAssertEqual(TimeStringConverter.toSeconds("-"), 0)
    }

    func test_toSeconds_NA_returnsZero() {
        XCTAssertEqual(TimeStringConverter.toSeconds("N/A"), 0)
    }

    // MARK: - toSeconds: whitespace

    func test_toSeconds_whitespaceTrimmed() {
        XCTAssertEqual(TimeStringConverter.toSeconds("  4.53  "), 16308, accuracy: 0.001)
    }

    // MARK: - clockStringToSecondsFromMidnight

    func test_clock_nil_returnsNil() {
        XCTAssertNil(TimeStringConverter.clockStringToSecondsFromMidnight(nil))
    }

    func test_clock_empty_returnsNil() {
        XCTAssertNil(TimeStringConverter.clockStringToSecondsFromMidnight(""))
    }

    func test_clock_HHmm_0915_returns33300() {
        XCTAssertEqual(TimeStringConverter.clockStringToSecondsFromMidnight("09:15"), 33300)
    }

    func test_clock_midnight_returns0() {
        XCTAssertEqual(TimeStringConverter.clockStringToSecondsFromMidnight("00:00"), 0)
    }

    func test_clock_2359_returns86340() {
        XCTAssertEqual(TimeStringConverter.clockStringToSecondsFromMidnight("23:59"), 86340)
    }

    func test_clock_noColon_0915_returns33300() {
        XCTAssertEqual(TimeStringConverter.clockStringToSecondsFromMidnight("0915"), 33300)
    }

    func test_clock_outOfRange_2400_returnsNil() {
        XCTAssertNil(TimeStringConverter.clockStringToSecondsFromMidnight("24:00"))
    }

    func test_clock_malformed_returnsNil() {
        XCTAssertNil(TimeStringConverter.clockStringToSecondsFromMidnight("abc"))
    }
}
