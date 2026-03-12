//
//  TimeExtensionTests.swift
//  Block-TimeTests
//
//  Tests for TimeInterval and Double extensions used throughout the app.
//

import Foundation
import Testing
@testable import Block_Time

struct TimeExtensionTests {

    // MARK: - TimeInterval.toDecimalHours

    @Test func toDecimalHours_oneHour() {
        let interval: TimeInterval = 3600
        #expect(interval.toDecimalHours == 1.0)
    }

    @Test func toDecimalHours_ninetyMinutes() {
        let interval: TimeInterval = 5400
        #expect(interval.toDecimalHours == 1.5)
    }

    @Test func toDecimalHours_roundsToTwoDecimalPlaces() {
        // 8 hours 20 minutes = 30000 seconds = 8.3333... hours → rounds to 8.33
        let interval: TimeInterval = 30000
        #expect(interval.toDecimalHours == 8.33)
    }

    // MARK: - TimeInterval.toDecimalHoursString

    @Test func toDecimalHoursString_format() {
        let interval: TimeInterval = 3600
        #expect(interval.toDecimalHoursString == "1.00")
    }

    @Test func toDecimalHoursString_twoDecimals() {
        let interval: TimeInterval = 5400
        #expect(interval.toDecimalHoursString == "1.50")
    }

    // MARK: - Double.toHoursAndMinutes

    @Test func toHoursAndMinutes_wholeHour() {
        let (hours, minutes) = 2.0.toHoursAndMinutes
        #expect(hours == 2)
        #expect(minutes == 0)
    }

    @Test func toHoursAndMinutes_halfHour() {
        let (hours, minutes) = 2.5.toHoursAndMinutes
        #expect(hours == 2)
        #expect(minutes == 30)
    }

    @Test func toHoursAndMinutes_thirtyMinutes() {
        // 1 hour 45 minutes
        let (hours, minutes) = 1.75.toHoursAndMinutes
        #expect(hours == 1)
        #expect(minutes == 45)
    }

    // MARK: - Double.toHoursMinutesString

    @Test func toHoursMinutesString_format() {
        #expect(2.0.toHoursMinutesString == "2:00")
        #expect(2.5.toHoursMinutesString == "2:30")
        #expect(1.75.toHoursMinutesString == "1:45")
    }

    @Test func toHoursMinutesString_minutesPaddedWithZero() {
        // 1 hour 5 minutes = 1.0833...
        #expect(1.0833.toHoursMinutesString == "1:05")
    }

    // MARK: - Double.roundedToTwoDecimals

    @Test func roundedToTwoDecimals_noChange() {
        #expect(1.25.roundedToTwoDecimals == 1.25)
    }

    @Test func roundedToTwoDecimals_roundsUp() {
        #expect(1.235.roundedToTwoDecimals == 1.24)
    }

    @Test func roundedToTwoDecimals_roundsDown() {
        #expect(1.234.roundedToTwoDecimals == 1.23)
    }
}
