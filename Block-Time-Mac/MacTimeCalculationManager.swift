//
//  MacTimeCalculationManager.swift
//  Block-Time-Mac
//
//  Mirrors TimeCalculationManager.swift from the iOS target. Foundation-only, no UIKit.
//  LogManager calls replaced with #if DEBUG print() — same logic, no shared dependency.
//

import Foundation

struct MacFlightCalculationContext {
    let fromAirport: String
    let toAirport: String
    let fromCoordinates: (latitude: Double, longitude: Double)
    let toCoordinates: (latitude: Double, longitude: Double)
    let flightDate: Date
    let departureTime: Date
    let arrivalTime: Date
    let blockTimeHours: Double
}

class MacTimeCalculationManager {

    private let nightCalcService: MacNightCalcService

    init(nightCalcService: MacNightCalcService = MacNightCalcService()) {
        self.nightCalcService = nightCalcService
    }

    // MARK: - Context Building

    func buildCalculationContext(
        fromAirport: String,
        toAirport: String,
        outTime: String,
        blockTime: String,
        flightDate: String
    ) -> MacFlightCalculationContext? {
        guard !fromAirport.isEmpty, !toAirport.isEmpty,
              !outTime.isEmpty, !blockTime.isEmpty, !flightDate.isEmpty else { return nil }

        guard let fromCoords = nightCalcService.getAirportCoordinates(for: fromAirport),
              let toCoords   = nightCalcService.getAirportCoordinates(for: toAirport) else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let parsedFlightDate = dateFormatter.date(from: flightDate) else { return nil }

        guard let departureTime = parseUTCTimeOnDate(outTime, on: parsedFlightDate) else { return nil }
        guard let blockTimeHours = timeStringToHours(blockTime), blockTimeHours > 0 else { return nil }

        let arrivalTime = departureTime.addingTimeInterval(blockTimeHours * 3600)
        return MacFlightCalculationContext(
            fromAirport: fromAirport,
            toAirport: toAirport,
            fromCoordinates: fromCoords,
            toCoordinates: toCoords,
            flightDate: parsedFlightDate,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            blockTimeHours: blockTimeHours
        )
    }

    // MARK: - Time Parsing

    func parseUTCTimeOnDate(_ timeStr: String, on date: Date) -> Date? {
        let clean = timeStr.replacingOccurrences(of: ":", with: "")
        let hour: Int
        let minute: Int
        if clean.count == 3 {
            guard let h = Int(clean.prefix(1)), let m = Int(clean.suffix(2)) else { return nil }
            hour = h; minute = m
        } else if clean.count == 4 {
            guard let h = Int(clean.prefix(2)), let m = Int(clean.suffix(2)) else { return nil }
            hour = h; minute = m
        } else {
            return nil
        }
        guard hour < 24, minute < 60 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour; comps.minute = minute; comps.second = 0
        guard let result = cal.date(from: comps) else { return nil }
        if result < date { return cal.date(byAdding: .day, value: 1, to: result) }
        return result
    }

    // MARK: - Block Time

    func calculateFlightTime(outTime: String, inTime: String) -> String {
        guard !outTime.isEmpty, !inTime.isEmpty else { return "0.0" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let outDate = formatter.date(from: outTime),
              let inDate  = formatter.date(from: inTime) else { return "0.0" }
        var duration = inDate.timeIntervalSince(outDate)
        if duration < 0 { duration += 24 * 3600 }
        let totalSeconds = Int(duration)
        let hours   = totalSeconds / 3600
        let minutes = (totalSeconds - hours * 3600) / 60
        return String(format: "%.2f", Double(hours) + Double(minutes) / 60.0)
    }

    // MARK: - Validation

    func isValidTimeHHmm(_ timeString: String) -> Bool {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return false }
        return true
    }

    // MARK: - Night Time

    func calculateNightTime(using context: MacFlightCalculationContext) -> String {
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let hour   = utcCalendar.component(.hour,   from: context.departureTime)
        let minute = utcCalendar.component(.minute, from: context.departureTime)
        let departureUTC = String(format: "%02d%02d", hour, minute)
        if let nightHours = nightCalcService.calculateNightTime(
            from: context.fromAirport,
            to: context.toAirport,
            departureUTC: departureUTC,
            flightTimeHours: context.blockTimeHours,
            flightDate: context.flightDate
        ) {
            return String(format: "%.2f", min(nightHours, context.blockTimeHours))
        }
        return ""
    }

    // MARK: - Combined Recalculation

    func recalculateBlockTime(outTime: String, inTime: String) -> (blockTime: String, isValid: Bool) {
        let out = outTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let inT = inTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !out.isEmpty, !inT.isEmpty, isValidTimeHHmm(out), isValidTimeHHmm(inT) else {
            return ("", false)
        }
        return (calculateFlightTime(outTime: out, inTime: inT), true)
    }

    func recalculateTimes(
        outTime: String,
        inTime: String,
        fromAirport: String,
        toAirport: String,
        flightDate: String,
        isEditingMode: Bool = false,
        existingNightTime: String = ""
    ) -> (blockTime: String, nightTime: String) {
        let out = outTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let inT = inTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !out.isEmpty, !inT.isEmpty, isValidTimeHHmm(out), isValidTimeHHmm(inT) else {
            return ("", isEditingMode ? existingNightTime : "")
        }
        let blockTime = calculateFlightTime(outTime: out, inTime: inT)
        if let context = buildCalculationContext(
            fromAirport: fromAirport, toAirport: toAirport,
            outTime: out, blockTime: blockTime, flightDate: flightDate
        ) {
            return (blockTime, calculateNightTime(using: context))
        }
        return (blockTime, "")
    }

    // MARK: - T/O & Ldg calculation

    /// Returns (dayTakeoffs, nightTakeoffs, dayLandings, nightLandings) based on departure/arrival day/night.
    func calculateTakeoffsLandings(using context: MacFlightCalculationContext) -> (Int, Int, Int, Int) {
        let checkInterval: TimeInterval = 180
        let arrivalCheckTime = context.departureTime.addingTimeInterval(
            max(0, context.blockTimeHours * 3600 - checkInterval)
        )
        let isDepartureNight = nightCalcService.isNight(
            at: context.fromCoordinates.latitude, lon: context.fromCoordinates.longitude,
            time: context.departureTime
        )
        let isArrivalNight = nightCalcService.isNight(
            at: context.toCoordinates.latitude, lon: context.toCoordinates.longitude,
            time: arrivalCheckTime
        )
        let dayTO    = isDepartureNight ? 0 : 1
        let nightTO  = isDepartureNight ? 1 : 0
        let dayLdg   = isArrivalNight   ? 0 : 1
        let nightLdg = isArrivalNight   ? 1 : 0
        return (dayTO, nightTO, dayLdg, nightLdg)
    }

    // MARK: - Private

    private func timeStringToHours(_ timeString: String) -> Double? {
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":")
            guard parts.count == 2,
                  let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            return Double(h) + Double(m) / 60.0
        } else {
            guard let value = Double(trimmed), value.isFinite, value >= 0 else { return nil }
            return value
        }
    }
}
