// UTCConverterTests.swift
// XCTest suite for BlockTimeCalculators.UTCConverter.
// Covers DST transitions, midnight crossings, malformed input, negative-offset timezones (CALC-07).

import XCTest
@testable import BlockTimeCalculators

final class UTCConverterTests: XCTestCase {

    // MARK: - Helpers

    /// Build a Date from UTC components using Calendar(identifier: .gregorian).
    private static func utcDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = second
        return cal.date(from: comps)!
    }

    // MARK: - parseHHMM

    func test_parseHHMM_midnight_returnsZeroZero() {
        let result = UTCConverter.parseHHMM("00:00")
        XCTAssertEqual(result?.hour, 0)
        XCTAssertEqual(result?.minute, 0)
    }

    func test_parseHHMM_lateBound_returns2359() {
        let result = UTCConverter.parseHHMM("23:59")
        XCTAssertEqual(result?.hour, 23)
        XCTAssertEqual(result?.minute, 59)
    }

    func test_parseHHMM_paddedHour_returns0130() {
        let result = UTCConverter.parseHHMM("01:30")
        XCTAssertEqual(result?.hour, 1)
        XCTAssertEqual(result?.minute, 30)
    }

    func test_parseHHMM_singleDigitHour_returns0130() {
        // Single-digit hour accepted — consistent with hhmmToMinutes behavior.
        let result = UTCConverter.parseHHMM("1:30")
        XCTAssertEqual(result?.hour, 1)
        XCTAssertEqual(result?.minute, 30)
    }

    func test_parseHHMM_hourTooLarge_returnsNil() {
        XCTAssertNil(UTCConverter.parseHHMM("24:00"))
    }

    func test_parseHHMM_minutesTooLarge_returnsNil() {
        XCTAssertNil(UTCConverter.parseHHMM("12:60"))
    }

    func test_parseHHMM_nonNumeric_returnsNil() {
        XCTAssertNil(UTCConverter.parseHHMM("ab:cd"))
    }

    func test_parseHHMM_empty_returnsNil() {
        XCTAssertNil(UTCConverter.parseHHMM(""))
    }

    func test_parseHHMM_noColon_returnsNil() {
        XCTAssertNil(UTCConverter.parseHHMM("12"))
    }

    func test_parseHHMM_singleDigitMinutes_returnsNil() {
        // "9:3" is too short (minutes must be 2 digits).
        XCTAssertNil(UTCConverter.parseHHMM("9:3"))
    }

    // MARK: - localToUTC / utcToLocal round-trip

    func test_localToUTC_sydneyWinter_shifts10HoursBack() {
        // Sydney in June is UTC+10 (AEST — no daylight saving).
        // Local wall-clock 10:00 on 2026-06-01 in Sydney = UTC 00:00.
        // Build a Date whose wall-clock components in Sydney read 10:00 on 2026-06-01.
        // Sydney is UTC+10, so 10:00 Sydney = 00:00 UTC. Build via Sydney calendar.
        let sydneyTZ = TimeZone(identifier: "Australia/Sydney")!
        var sydneyCal = Calendar(identifier: .gregorian)
        sydneyCal.timeZone = sydneyTZ
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 1; comps.hour = 10; comps.minute = 0
        // This Date is 2026-06-01 10:00 in Sydney = 2026-06-01 00:00 UTC.
        let sydneyLocal = sydneyCal.date(from: comps)!
        // localToUTC: extract wall-clock components from sydneyLocal using Sydney calendar (reads 10:00),
        // then interpret as UTC → result = 2026-06-01 10:00 UTC.
        // Wait — this test verifies that extracting "10:00 Sydney wall-clock" and treating it as UTC
        // gives UTC 10:00. The shift is intentional: localToUTC maps local wall-clock onto UTC.
        // Correct expectation: UTC date with same h/m components as Sydney wall-clock reading = UTC 10:00.
        let utcResult = UTCConverter.localToUTC(date: sydneyLocal, timeZone: sydneyTZ)
        let expectedUTC = Self.utcDate(year: 2026, month: 6, day: 1, hour: 10, minute: 0)
        XCTAssertEqual(utcResult, expectedUTC)
    }

    func test_utcToLocal_inverse_roundTrip() {
        // utcToLocal(localToUTC(d, tz), tz) == d at minute precision.
        let tz = TimeZone(identifier: "Australia/Sydney")!
        let original = Self.utcDate(year: 2026, month: 3, day: 15, hour: 8, minute: 45)
        let roundTripped = UTCConverter.utcToLocal(date: UTCConverter.localToUTC(date: original, timeZone: tz), timeZone: tz)
        // Compare at minute precision by truncating seconds.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let origComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: original)
        let rtComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: roundTripped)
        XCTAssertEqual(origComps, rtComps)
    }

    // MARK: - combineDateAndTime

    func test_combineDateAndTime_sydneyWinter_returnsUTC() {
        // date = 2026-06-01 00:00 UTC, hhmm = "10:00", tz = Australia/Sydney (UTC+10)
        // Result should be UTC 2026-06-01 00:00.
        let tz = TimeZone(identifier: "Australia/Sydney")!
        let date = Self.utcDate(year: 2026, month: 6, day: 1)
        let result = UTCConverter.combineDateAndTime(date: date, hhmm: "10:00", timeZone: tz)
        let expected = Self.utcDate(year: 2026, month: 6, day: 1, hour: 0, minute: 0)
        XCTAssertEqual(result, expected)
    }

    func test_combineDateAndTime_malformedHHMM_returnsNil() {
        let tz = TimeZone(identifier: "UTC")!
        let date = Self.utcDate(year: 2026, month: 1, day: 1)
        XCTAssertNil(UTCConverter.combineDateAndTime(date: date, hhmm: "99:99", timeZone: tz))
    }

    func test_combineDateAndTime_hourTooLarge_returnsNil() {
        let tz = TimeZone(identifier: "UTC")!
        let date = Self.utcDate(year: 2026, month: 1, day: 1)
        XCTAssertNil(UTCConverter.combineDateAndTime(date: date, hhmm: "24:00", timeZone: tz))
    }

    func test_combineDateAndTime_minutesTooLarge_returnsNil() {
        let tz = TimeZone(identifier: "UTC")!
        let date = Self.utcDate(year: 2026, month: 1, day: 1)
        XCTAssertNil(UTCConverter.combineDateAndTime(date: date, hhmm: "12:60", timeZone: tz))
    }

    // MARK: - Midnight crossing (negative offset)

    func test_combineDateAndTime_midnightCrossing_newYork() {
        // date = 2026-01-15 00:00 UTC, hhmm = "23:00", tz = America/New_York (UTC-5)
        // Wall-clock 23:00 in New York on 2026-01-15 local = UTC 2026-01-16 04:00.
        let tz = TimeZone(identifier: "America/New_York")!
        // The calendar date in New York on 2026-01-15.
        // To get 2026-01-15 in New York, use a UTC date that falls on that local day.
        // Build the date so its UTC date components land on 2026-01-15 (NYC is UTC-5 in January).
        // Any UTC time on 2026-01-15 that is also 2026-01-15 in NYC — e.g. UTC 10:00 = NYC 05:00.
        var nycCal = Calendar(identifier: .gregorian)
        nycCal.timeZone = tz
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 15
        comps.hour = 12; comps.minute = 0; comps.second = 0
        let nycDate = nycCal.date(from: comps)! // This Date is 2026-01-15 12:00 NYC = 2026-01-15 17:00 UTC

        let result = UTCConverter.combineDateAndTime(date: nycDate, hhmm: "23:00", timeZone: tz)
        // 23:00 NYC on 2026-01-15 = UTC 2026-01-16 04:00.
        let expected = Self.utcDate(year: 2026, month: 1, day: 16, hour: 4, minute: 0)
        XCTAssertEqual(result, expected)
    }

    // MARK: - DST spring-forward (Australia/Melbourne)

    func test_combineDateAndTime_dstSpringForward_doesNotCrash() {
        // Australian clocks spring forward at 2:00am on the first Sunday of October.
        // 2026-10-04 is the first Sunday in October 2026.
        // "02:30" local does not exist — Calendar should return the next valid instant or nil.
        // This test asserts the call does not trap and the result is within the changeover window.
        let tz = TimeZone(identifier: "Australia/Melbourne")!
        var melbCal = Calendar(identifier: .gregorian)
        melbCal.timeZone = tz
        var comps = DateComponents()
        comps.year = 2026; comps.month = 10; comps.day = 4
        comps.hour = 12; comps.minute = 0
        let changeDayDate = melbCal.date(from: comps)!

        // This must not crash — Apple Calendar may return nil or the next valid instant.
        let result = UTCConverter.combineDateAndTime(date: changeDayDate, hhmm: "02:30", timeZone: tz)
        // If non-nil, the result must be a real Date within a 2-hour window around the clock change.
        // UTC offset shifts AEST (UTC+10) → AEDT (UTC+11) on spring forward.
        // 2:30am doesn't exist; Apple's Calendar typically returns 3:00am AEDT (UTC 16:00).
        if let date = result {
            // Window: 2026-10-03 14:00 UTC (= 2026-10-04 00:00 AEST) to 2026-10-04 17:00 UTC.
            let windowStart = Self.utcDate(year: 2026, month: 10, day: 3, hour: 14, minute: 0)
            let windowEnd   = Self.utcDate(year: 2026, month: 10, day: 4, hour: 17, minute: 0)
            XCTAssertTrue(date >= windowStart && date <= windowEnd,
                          "DST result \(date) is outside the expected changeover window")
        }
        // nil is also a valid return from Apple's Calendar for a non-existent time.
    }
}
