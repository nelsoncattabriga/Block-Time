// FlightMigrationConversionTests.swift
// Verifies the migration conversion algorithms used by FlightEntityMigrationPolicy (Plan 02-02).
// D-01 forbids extracting a shared helper, so the algorithm is copied verbatim here.
// Any change to the policy's inline functions MUST be mirrored here and vice-versa.

import XCTest
@testable import BlockTimeDomain

final class FlightMigrationConversionTests: XCTestCase {

    // MARK: - stringToMinutes

    func testStringToMinutes_decimalHour_oneAndHalf_returns90() {
        XCTAssertEqual(Self.stringToMinutes("1.5"), 90)
    }

    func testStringToMinutes_decimalHour_quarter_returns15() {
        XCTAssertEqual(Self.stringToMinutes("0.25"), 15)
    }

    func testStringToMinutes_hhmm_oneThirty_returns90() {
        XCTAssertEqual(Self.stringToMinutes("01:30"), 90)
    }

    func testStringToMinutes_hhmm_zero_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes("00:00"), 0)
    }

    func testStringToMinutes_hhmm_tenFortyFive_returns645() {
        XCTAssertEqual(Self.stringToMinutes("10:45"), 645)
    }

    func testStringToMinutes_nil_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes(nil), 0)
    }

    func testStringToMinutes_emptyString_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes(""), 0)
    }

    func testStringToMinutes_literalZero_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes("0"), 0)
    }

    func testStringToMinutes_literalZeroPointZero_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes("0.0"), 0)
    }

    func testStringToMinutes_whitespaceOnly_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes("   "), 0)
    }

    func testStringToMinutes_malformedString_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes("abc"), 0)
    }

    func testStringToMinutes_malformedHHMM_minutesOverflow_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes("1:99"), 0)
    }

    func testStringToMinutes_malformedHHMM_nonNumeric_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes("ab:cd"), 0)
    }

    func testStringToMinutes_negativeDecimal_returnsZero() {
        XCTAssertEqual(Self.stringToMinutes("-1.5"), 0)
    }

    func testStringToMinutes_infiniteString_returnsZero() {
        // "inf" parses as Double.infinity which fails .isFinite — must return 0.
        XCTAssertEqual(Self.stringToMinutes("inf"), 0)
    }

    func testStringToMinutes_overflow_clampsToInt16Max() {
        // 10000 hours = 600000 minutes — must clamp to Int16.max (32767).
        XCTAssertEqual(Self.stringToMinutes("10000.0"), Int(Int16.max))
    }

    // MARK: - stringToDate

    private static let utcMidnight: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: 2024, month: 1, day: 15))!
    }()

    func testStringToDate_validHHMM_returnsCorrectDate() {
        let result = Self.stringToDate("09:30", on: Self.utcMidnight)
        let expected = Self.utcMidnight.addingTimeInterval(9 * 3600 + 30 * 60)
        XCTAssertEqual(result, expected)
    }

    func testStringToDate_validHHMMnoColon_returnsCorrectDate() {
        let result = Self.stringToDate("1430", on: Self.utcMidnight)
        let expected = Self.utcMidnight.addingTimeInterval(14 * 3600 + 30 * 60)
        XCTAssertEqual(result, expected)
    }

    func testStringToDate_nil_returnsNil() {
        XCTAssertNil(Self.stringToDate(nil, on: Self.utcMidnight))
    }

    func testStringToDate_emptyString_returnsNil() {
        XCTAssertNil(Self.stringToDate("", on: Self.utcMidnight))
    }

    func testStringToDate_malformedShortLength_returnsNil() {
        XCTAssertNil(Self.stringToDate("9:3", on: Self.utcMidnight))
    }

    func testStringToDate_outOfRangeHour_returnsNil() {
        XCTAssertNil(Self.stringToDate("24:00", on: Self.utcMidnight))
    }

    func testStringToDate_outOfRangeMinute_returnsNil() {
        XCTAssertNil(Self.stringToDate("12:60", on: Self.utcMidnight))
    }

    func testStringToDate_nonNumeric_returnsNil() {
        XCTAssertNil(Self.stringToDate("ab:cd", on: Self.utcMidnight))
    }

    func testStringToDate_whitespaceTrimmed_returnsCorrectDate() {
        let result = Self.stringToDate(" 09:30 ", on: Self.utcMidnight)
        let expected = Self.utcMidnight.addingTimeInterval(9 * 3600 + 30 * 60)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Algorithm copies (IDENTICAL to FlightEntityMigrationPolicy.swift in Plan 02-02)
    // D-01: NOT extracted to a shared helper. Any divergence between this copy and the
    //       production copy in FlightEntityMigrationPolicy.swift is a bug.

    /// Decimal-hour or "HH:MM" string → Int minutes. Nil/malformed → 0.
    private static func stringToMinutes(_ raw: String?) -> Int {
        guard let raw else { return 0 }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s != "0", s != "0.0" else { return 0 }
        if s.contains(":") {
            let parts = s.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let h = Int(parts[0]), let m = Int(parts[1]),
                  h >= 0, m >= 0, m < 60 else { return 0 }
            return min(h * 60 + m, Int(Int16.max))
        } else {
            guard let hours = Double(s), hours.isFinite, hours >= 0 else { return 0 }
            return min(Int(hours * 60), Int(Int16.max))
        }
    }

    /// "HH:MM" or "HHMM" UTC string + UTC-midnight Date → UTC Date?. Nil/malformed → nil.
    private static func stringToDate(_ raw: String?, on utcMidnight: Date) -> Date? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = s.replacingOccurrences(of: ":", with: "")
        guard clean.count == 4,
              let hours = Int(clean.prefix(2)),
              let minutes = Int(clean.suffix(2)),
              hours >= 0, hours < 24,
              minutes >= 0, minutes < 60 else { return nil }
        return utcMidnight.addingTimeInterval(TimeInterval(hours * 3600 + minutes * 60))
    }
}
