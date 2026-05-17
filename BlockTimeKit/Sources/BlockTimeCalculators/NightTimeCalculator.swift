// NightTimeCalculator.swift
// Pure solar night-time calculation extracted from NightCalcService.swift (Plan 03-03).
// Algorithm is verbatim from NightCalcService.nightPortion — no behavior change (D-09).
// Changes from the original:
//   1. LogManager calls removed (not available in BlockTimeKit — RESEARCH.md Pitfall 1)
//   2. parseUTCString block removed — caller provides departure Date directly (D-06)
//   3. Same-airport guard added before sin(distRad) division — RESEARCH.md "Division-by-Zero Risk"
//   4. Public entry point converts Double hours → Int minutes (D-07 + RESEARCH.md Pitfall 5)
//   5. All functions declared as private static inside the enum namespace

import Foundation

/// Pure solar night-time calculator.
/// No airport lookup, no file I/O, no logging.
/// All inputs are pre-resolved by the caller (D-08).
public enum NightTimeCalculator {

    // MARK: - Public API

    /// Calculate the night-time portion of a flight as integer minutes.
    ///
    /// Uses civil twilight (-6° solar elevation) as the night threshold (D-09).
    ///
    /// - Parameters:
    ///   - fromLat: Departure latitude in degrees
    ///   - fromLon: Departure longitude in degrees
    ///   - toLat: Arrival latitude in degrees
    ///   - toLon: Arrival longitude in degrees
    ///   - departure: Departure date/time in UTC
    ///   - flightDurationMinutes: Total flight duration in integer minutes
    /// - Returns: Night portion in integer minutes, clamped to `[0, flightDurationMinutes]`.
    ///   Returns `0` for same-airport degenerate case (distRad ≈ 0).
    ///   Returns `nil` only if the algorithm produces a non-finite intermediate result (defensive).
    public static func calculateNightTime(
        fromLat: Double, fromLon: Double,
        toLat: Double, toLon: Double,
        departure: Date,
        flightDurationMinutes: Int
    ) -> Int? {
        guard flightDurationMinutes > 0 else { return 0 }
        let flightDurationHours = Double(flightDurationMinutes) / 60.0
        let nightHours = nightPortionHours(
            fromLat: fromLat, fromLon: fromLon,
            toLat: toLat, toLon: toLon,
            departure: departure,
            flightDurationHours: flightDurationHours
        )
        guard nightHours.isFinite, nightHours >= 0 else { return nil }
        let nightMinutes = Int((nightHours * 60).rounded())
        // Clamp to [0, flightDurationMinutes] — 200-segment quantisation can push slightly outside
        return max(0, min(flightDurationMinutes, nightMinutes))
    }

    // MARK: - Private (extracted verbatim from NightCalcService.swift)

    /// Inner computation: returns night hours as Double.
    /// Body is verbatim from NightCalcService.nightPortion with:
    ///   - LogManager calls removed
    ///   - parseUTCString block removed (departure Date is pre-resolved by caller)
    ///   - Same-airport guard added before sin(distRad) division
    private static func nightPortionHours(
        fromLat: Double, fromLon: Double,
        toLat: Double, toLon: Double,
        departure: Date,
        flightDurationHours: Double,
        segments: Int = 200
    ) -> Double {
        let pi = Double.pi

        func deg2rad(_ deg: Double) -> Double { deg * pi / 180 }
        func rad2deg(_ rad: Double) -> Double { rad * 180 / pi }

        let φ1 = deg2rad(fromLat), λ1 = deg2rad(fromLon)
        let φ2 = deg2rad(toLat), λ2 = deg2rad(toLon)

        let distRad = acos(
            max(-1.0, min(1.0, sin(φ1) * sin(φ2) + cos(φ1) * cos(φ2) * cos(λ1 - λ2)))
        )

        // Same-airport guard: sin(0) = 0 would cause division by zero further down (RESEARCH.md)
        if distRad < 1e-10 { return 0 }

        let segmentDuration = flightDurationHours * 3600 / Double(segments)
        var nightSeconds = 0.0

        for i in 0..<segments {
            let f = Double(i) / Double(segments)
            let A = sin((1 - f) * distRad) / sin(distRad)
            let B = sin(f * distRad) / sin(distRad)

            let x = A * cos(φ1) * cos(λ1) + B * cos(φ2) * cos(λ2)
            let y = A * cos(φ1) * sin(λ1) + B * cos(φ2) * sin(λ2)
            let z = A * sin(φ1) + B * sin(φ2)

            let φi = atan2(z, sqrt(x * x + y * y))
            let λi = atan2(y, x)

            let latDeg = rad2deg(φi)
            let lonDeg = rad2deg(λi)

            let pointTime = departure.addingTimeInterval(Double(i) * segmentDuration)

            if isNightInternal(at: latDeg, lon: lonDeg, time: pointTime) {
                nightSeconds += segmentDuration
            }
        }

        return nightSeconds / 3600.0
    }

    /// Determine whether the sun is below civil twilight (-6°) at the given location and time.
    /// Verbatim from NightCalcService.isNightInternal — no behavior change (D-09).
    private static func isNightInternal(at lat: Double, lon: Double, time: Date) -> Bool {
        let rad = Double.pi / 180

        let jd = julianDay(for: time)
        let T = (jd - 2451545.0) / 36525.0

        // Mean longitude of the sun
        var L0 = 280.46646 + T * (36000.76983 + 0.0003032 * T)
        L0 = fmod(L0, 360.0)

        // Mean anomaly
        let M = 357.52911 + T * (35999.05029 - 0.0001537 * T)

        // Sun equation of the centre
        let C = (1.914602 - T * (0.004817 + 0.000014 * T)) * sin(M * rad)
              + (0.019993 - 0.000101 * T) * sin(2 * M * rad)
              + 0.000289 * sin(3 * M * rad)

        // True longitude
        let trueLong = L0 + C

        // Apparent longitude
        let omega = 125.04 - 1934.136 * T
        let lambda = trueLong - 0.00569 - 0.00478 * sin(omega * rad)

        // Mean obliquity
        let epsilon0 = 23 + (26.0 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60
        let epsilon = epsilon0 + 0.00256 * cos(omega * rad)

        // Declination of the Sun
        let delta = asin(sin(epsilon * rad) * sin(lambda * rad))

        // Greenwich Sidereal Time and Local Sidereal Time
        let timeUTC = time.timeIntervalSince1970
        let gst = greenwichSiderealTime(for: timeUTC)
        let lst = gst + lon * rad

        // Hour angle of the sun
        let alpha = atan2(cos(epsilon * rad) * sin(lambda * rad), cos(lambda * rad))
        let H = lst - alpha

        // Elevation angle
        let elev = asin(sin(lat * rad) * sin(delta) + cos(lat * rad) * cos(delta) * cos(H))

        // Civil twilight threshold at -6° (D-09 — preserved verbatim from NightCalcService)
        return elev < -6 * rad
    }

    /// Julian Day Number for a given Date.
    /// Verbatim from NightCalcService.julianDay(for:).
    private static func julianDay(for date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        var Y = comps.year!
        var M = comps.month!
        let D = Double(comps.day!)
            + (Double(comps.hour!) +
               Double(comps.minute!) / 60 +
               Double(comps.second!) / 3600) / 24.0

        if M <= 2 {
            Y -= 1
            M += 12
        }

        let A = floor(Double(Y) / 100.0)
        let B = 2 - A + floor(A / 4)

        return floor(365.25 * (Double(Y) + 4716))
             + floor(30.6001 * (Double(M) + 1))
             + D + B - 1524.5
    }

    /// Greenwich Sidereal Time in radians for a given Unix timestamp.
    /// Verbatim from NightCalcService.greenwichSiderealTime(for:).
    private static func greenwichSiderealTime(for unixTime: TimeInterval) -> Double {
        let jd = julianDay(for: Date(timeIntervalSince1970: unixTime))
        let T = (jd - 2451545.0) / 36525.0
        var theta = 280.46061837
                  + 360.98564736629 * (jd - 2451545)
                  + 0.000387933 * T * T
                  - T * T * T / 38710000
        theta = fmod(theta, 360.0)
        if theta < 0 { theta += 360.0 }
        return theta * Double.pi / 180
    }
}
