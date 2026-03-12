//
//  FlightSectorTests.swift
//  Block-TimeTests
//
//  Tests for FlightSector model: time string validation, numeric accessors,
//  decimal↔HH:MM conversion, and hhmmToDecimal parsing.
//

import Testing
@testable import Block_Time

struct FlightSectorTests {

    // MARK: - Helpers

    private func makeFlight(
        blockTime: String = "0.0",
        nightTime: String = "0.0",
        p1Time: String = "0.0",
        p1usTime: String = "0.0",
        p2Time: String = "0.0",
        simTime: String = "0.0"
    ) -> FlightSector {
        FlightSector(
            date: "01/01/2026",
            flightNumber: "QF001",
            aircraftReg: "VH-OQA",
            aircraftType: "B789",
            fromAirport: "YSSY",
            toAirport: "YMML",
            captainName: "Smith",
            foName: "Jones",
            blockTime: blockTime,
            nightTime: nightTime,
            p1Time: p1Time,
            p1usTime: p1usTime,
            p2Time: p2Time,
            instrumentTime: "0.0",
            simTime: simTime,
            isPilotFlying: true
        )
    }

    // MARK: - blockTimeValue

    @Test func blockTimeValue_validDecimal() {
        let f = makeFlight(blockTime: "2.5")
        #expect(f.blockTimeValue == 2.5)
    }

    @Test func blockTimeValue_zero() {
        let f = makeFlight(blockTime: "0.0")
        #expect(f.blockTimeValue == 0.0)
    }

    @Test func blockTimeValue_invalidString_returnsZero() {
        let f = makeFlight(blockTime: "abc")
        #expect(f.blockTimeValue == 0.0)
    }

    @Test func blockTimeValue_emptyString_returnsZero() {
        let f = makeFlight(blockTime: "")
        #expect(f.blockTimeValue == 0.0)
    }

    @Test func blockTimeValue_negative_returnsZero() {
        let f = makeFlight(blockTime: "-1.5")
        #expect(f.blockTimeValue == 0.0)
    }

    // MARK: - decimalToHHMM

    @Test func decimalToHHMM_wholeHours() {
        #expect(FlightSector.decimalToHHMM(2.0) == "2:00")
    }

    @Test func decimalToHHMM_halfHour() {
        #expect(FlightSector.decimalToHHMM(2.5) == "2:30")
    }

    @Test func decimalToHHMM_thirtyMinutes() {
        #expect(FlightSector.decimalToHHMM(13.67) == "13:40")
    }

    @Test func decimalToHHMM_zero() {
        #expect(FlightSector.decimalToHHMM(0.0) == "0:00")
    }

    @Test func decimalToHHMM_negative() {
        #expect(FlightSector.decimalToHHMM(-1.0) == "0:00")
    }

    @Test func decimalToHHMM_roundsMinutesCorrectly() {
        // 1 hour 1 minute = 1.01667 hours
        #expect(FlightSector.decimalToHHMM(1.0167) == "1:01")
    }

    @Test func decimalToHHMM_longFlight() {
        // 14 hours 30 min
        #expect(FlightSector.decimalToHHMM(14.5) == "14:30")
    }

    // MARK: - hhmmToDecimal

    @Test func hhmmToDecimal_basic() {
        let result = FlightSector.hhmmToDecimal("2:30")
        #expect(result == 2.5)
    }

    @Test func hhmmToDecimal_wholeHour() {
        let result = FlightSector.hhmmToDecimal("3:00")
        #expect(result == 3.0)
    }

    @Test func hhmmToDecimal_thirtyMinutes() {
        // 13:40 = 820 minutes / 60 = 13.6666...
        let result = FlightSector.hhmmToDecimal("13:40")
        #expect(result != nil)
        #expect(abs(result! - 13.6667) < 0.001)
    }

    @Test func hhmmToDecimal_invalidFormat_returnsNil() {
        #expect(FlightSector.hhmmToDecimal("abc") == nil)
        #expect(FlightSector.hhmmToDecimal("2.5") == nil)
        #expect(FlightSector.hhmmToDecimal("") == nil)
    }

    @Test func hhmmToDecimal_invalidMinutes_returnsNil() {
        // 60 minutes is not valid
        #expect(FlightSector.hhmmToDecimal("2:60") == nil)
    }

    // MARK: - Round-trip: decimal → HHMM → decimal

    @Test func roundTrip_decimalToHHMMToDecimal() {
        let original = 8.5
        let hhmm = FlightSector.decimalToHHMM(original)
        let back = FlightSector.hhmmToDecimal(hhmm)
        #expect(back != nil)
        #expect(abs(back! - original) < 0.01)
    }

    // MARK: - dayOfMonth

    @Test func dayOfMonth_extractsCorrectly() {
        let f = makeFlight()
        // date is "01/01/2026"
        #expect(f.dayOfMonth == "01")
    }
}
