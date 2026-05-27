//
//  MacNightCalcService.swift
//  Block-Time-Mac
//
//  Mirrors NightCalcService.swift from the iOS target. Foundation-only, no UIKit.
//  LogManager calls replaced with #if DEBUG print() — same logic, no shared dependency.
//

import Foundation

// MARK: - Main Interface

class MacNightCalcService {
    private let airportLookup = MacAirportLookup()

    func getAirportCoordinates(for icao: String) -> (latitude: Double, longitude: Double)? {
        airportLookup.getCoordinates(for: icao)
    }

    func isNight(at lat: Double, lon: Double, time: Date) -> Bool {
        macIsNightInternal(at: lat, lon: lon, time: time)
    }

    func calculateNightTime(
        from fromAirport: String,
        to toAirport: String,
        departureUTC: String,
        flightTimeHours: Double,
        flightDate: Date = Date()
    ) -> Double? {
        guard let fromCoords = airportLookup.getCoordinates(for: fromAirport.uppercased()),
              let toCoords   = airportLookup.getCoordinates(for: toAirport.uppercased()) else {
            return nil
        }
        return macNightPortion(
            fromLat: fromCoords.latitude, fromLon: fromCoords.longitude,
            toLat: toCoords.latitude,     toLon: toCoords.longitude,
            departureUTC: departureUTC,
            flightDurationHours: flightTimeHours,
            flightDate: flightDate
        )
    }
}

// MARK: - Airport Lookup

private class MacAirportLookup {
    private var airports: [String: (latitude: Double, longitude: Double)] = [:]

    init() { loadAirports() }

    private func loadAirports() {
        guard let path = Bundle.main.path(forResource: "airports.dat", ofType: "txt") else {
            #if DEBUG
            print("MacAirportLookup: Could not find airports.dat.txt in bundle")
            #endif
            return
        }
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            for line in content.components(separatedBy: .newlines) {
                let components = parseCSVLine(line)
                guard components.count >= 8,
                      let latitude  = Double(components[6]),
                      let longitude = Double(components[7]) else { continue }
                let icao = components[5].trimmingCharacters(in: .whitespaces).uppercased()
                guard !icao.isEmpty else { continue }
                airports[icao] = (latitude: latitude, longitude: longitude)
            }
        } catch {
            #if DEBUG
            print("MacAirportLookup: Error reading airports.dat.txt: \(error)")
            #endif
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        fields.append(currentField)
        return fields
    }

    func getCoordinates(for icao: String) -> (latitude: Double, longitude: Double)? {
        airports[icao.uppercased()]
    }
}

// MARK: - Supporting Functions

private func macParseUTCString(_ timeStr: String, on date: Date = Date()) -> Date? {
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

private func macNightPortion(
    fromLat: Double, fromLon: Double,
    toLat: Double,   toLon: Double,
    departureUTC: String,
    flightDurationHours: Double,
    flightDate: Date,
    segments: Int = 200
) -> Double {
    let pi = Double.pi
    func deg2rad(_ d: Double) -> Double { d * pi / 180 }

    let φ1 = deg2rad(fromLat), λ1 = deg2rad(fromLon)
    let φ2 = deg2rad(toLat),   λ2 = deg2rad(toLon)
    let distRad = acos(sin(φ1)*sin(φ2) + cos(φ1)*cos(φ2)*cos(λ1-λ2))

    guard let depDate = macParseUTCString(departureUTC, on: flightDate) else { return 0 }

    let segmentDuration = flightDurationHours * 3600 / Double(segments)
    var nightSeconds = 0.0

    for i in 0..<segments {
        let f = Double(i) / Double(segments)
        let A = sin((1-f) * distRad) / sin(distRad)
        let B = sin(f * distRad) / sin(distRad)
        let x = A*cos(φ1)*cos(λ1) + B*cos(φ2)*cos(λ2)
        let y = A*cos(φ1)*sin(λ1) + B*cos(φ2)*sin(λ2)
        let z = A*sin(φ1) + B*sin(φ2)
        let latDeg = atan2(z, sqrt(x*x + y*y)) * 180 / pi
        let lonDeg = atan2(y, x) * 180 / pi
        let pointTime = depDate.addingTimeInterval(Double(i) * segmentDuration)
        if macIsNightInternal(at: latDeg, lon: lonDeg, time: pointTime) {
            nightSeconds += segmentDuration
        }
    }
    return nightSeconds / 3600.0
}

private func macIsNightInternal(at lat: Double, lon: Double, time: Date) -> Bool {
    let rad = Double.pi / 180
    let jd  = macJulianDay(for: time)
    let T   = (jd - 2451545.0) / 36525.0

    var L0 = 280.46646 + T*(36000.76983 + 0.0003032*T)
    L0 = fmod(L0, 360.0)
    let M  = 357.52911 + T*(35999.05029 - 0.0001537*T)
    let C  = (1.914602 - T*(0.004817 + 0.000014*T))*sin(M*rad)
           + (0.019993 - 0.000101*T)*sin(2*M*rad)
           + 0.000289*sin(3*M*rad)
    let trueLong = L0 + C
    let omega    = 125.04 - 1934.136*T
    let lambda   = trueLong - 0.00569 - 0.00478*sin(omega*rad)
    let epsilon0 = 23 + (26.0 + (21.448 - T*(46.815 + T*(0.00059 - T*0.001813)))/60)/60
    let epsilon  = epsilon0 + 0.00256*cos(omega*rad)
    let delta    = asin(sin(epsilon*rad)*sin(lambda*rad))
    let gst      = macGreenwichSiderealTime(for: time.timeIntervalSince1970)
    let lst      = gst + lon*rad
    let alpha    = atan2(cos(epsilon*rad)*sin(lambda*rad), cos(lambda*rad))
    let H        = lst - alpha
    let elev     = asin(sin(lat*rad)*sin(delta) + cos(lat*rad)*cos(delta)*cos(H))
    return elev < -6 * rad
}

private func macJulianDay(for date: Date) -> Double {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    var Y = c.year!
    var M = c.month!
    let D = Double(c.day!) + (Double(c.hour!) + Double(c.minute!)/60 + Double(c.second!)/3600) / 24.0
    if M <= 2 { Y -= 1; M += 12 }
    let A = floor(Double(Y)/100.0)
    let B = 2 - A + floor(A/4)
    return floor(365.25*(Double(Y)+4716)) + floor(30.6001*(Double(M)+1)) + D + B - 1524.5
}

private func macGreenwichSiderealTime(for unixTime: TimeInterval) -> Double {
    let jd = macJulianDay(for: Date(timeIntervalSince1970: unixTime))
    let T  = (jd - 2451545.0) / 36525.0
    var theta = 280.46061837 + 360.98564736629*(jd - 2451545) + 0.000387933*T*T - T*T*T/38710000
    theta = fmod(theta, 360.0)
    if theta < 0 { theta += 360.0 }
    return theta * Double.pi / 180
}
