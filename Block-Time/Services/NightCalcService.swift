import Foundation

// MARK: - Main Interface
class NightCalcService {
    private let airportLookup = AirportLookup()

    /// Get airport coordinates by ICAO code
    func getAirportCoordinates(for icao: String) -> (latitude: Double, longitude: Double)? {
        return airportLookup.getCoordinates(for: icao)
    }

    /// Parse a UTC time string (HH:MM or HHMM) to a Date
    func parseUTCTime(_ timeStr: String) -> Date? {
        return parseUTCString(timeStr)
    }

    /// Check if it's night at a specific location and time
    func isNight(at lat: Double, lon: Double, time: Date) -> Bool {
        return isNightInternal(at: lat, lon: lon, time: time)
    }

    /// Calculate night time portion for a flight between airports
    /// - Parameters:
    ///   - fromAirport: ICAO code for departure airport (e.g., "KJFK")
    ///   - toAirport: ICAO code for arrival airport (e.g., "EGLL")
    ///   - departureUTC: Departure time in UTC format "HHMM" (e.g., "1430")
    ///   - flightTimeHours: Flight duration in hours (e.g., 8.5)
    ///   - flightDate: The actual date of the flight (defaults to today if not provided)
    /// - Returns: Night time in hours, or nil if airports not found
    func calculateNightTime(
        from fromAirport: String,
        to toAirport: String,
        departureUTC: String,
        flightTimeHours: Double,
        flightDate: Date = Date()
    ) -> Double? {
        guard let fromCoords = airportLookup.getCoordinates(for: fromAirport.uppercased()),
              let toCoords = airportLookup.getCoordinates(for: toAirport.uppercased()) else {
            LogManager.shared.debug("Error: Could not find coordinates for airports \(fromAirport) or \(toAirport)")
            return nil
        }

        return nightPortion(
            fromLat: fromCoords.latitude,
            fromLon: fromCoords.longitude,
            toLat: toCoords.latitude,
            toLon: toCoords.longitude,
            departureUTC: departureUTC,
            flightDurationHours: flightTimeHours,
            flightDate: flightDate
        )
    }
}

// MARK: - Airport Lookup
private class AirportLookup {
    private var airports: [String: (latitude: Double, longitude: Double)] = [:]
    
    init() {
        loadAirports()
    }
    
    private func loadAirports() {
        guard let path = Bundle.main.path(forResource: "airports.dat", ofType: "txt") else {
            LogManager.shared.debug("Could not find airports.dat.txt in bundle")
            return
        }

        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for line in lines {
                let components = parseCSVLine(line)
                guard components.count >= 8,
                      let latitude = Double(components[6]),
                      let longitude = Double(components[7]) else {
                    continue
                }

                let icao = components[5].trimmingCharacters(in: .whitespaces).uppercased()
                guard !icao.isEmpty else { continue }
                airports[icao] = (latitude: latitude, longitude: longitude)
            }
        } catch {
            LogManager.shared.debug("Error reading airports.dat.txt: \(error)")
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
        return airports[icao.uppercased()]
    }
}

// MARK: - Supporting Functions
private func parseUTCString(_ timeStr: String, on date: Date = Date()) -> Date? {
    let clean = timeStr.replacingOccurrences(of: ":", with: "")

    // Handle both 3-digit (e.g., "710" for 07:10) and 4-digit (e.g., "0710") formats
    let hour: Int
    let minute: Int

    if clean.count == 3 {
        guard let h = Int(clean.prefix(1)),
              let m = Int(clean.suffix(2)) else {
            return nil
        }
        hour = h
        minute = m
    } else if clean.count == 4 {
        guard let h = Int(clean.prefix(2)),
              let m = Int(clean.suffix(2)) else {
            return nil
        }
        hour = h
        minute = m
    } else {
        return nil
    }

    guard hour < 24, minute < 60 else {
        return nil
    }

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!

    var comps = cal.dateComponents([.year, .month, .day], from: date)
    comps.hour = hour
    comps.minute = minute
    comps.second = 0

    guard let result = cal.date(from: comps) else { return nil }

    // Handle next day rollover if time has passed today
    if result < date {
        return cal.date(byAdding: .day, value: 1, to: result)
    }
    return result
}

private func nightPortion(
    fromLat: Double, fromLon: Double,
    toLat: Double, toLon: Double,
    departureUTC: String,
    flightDurationHours: Double,
    flightDate: Date,
    segments: Int = 200
) -> Double {
    let pi = Double.pi

    func deg2rad(_ deg: Double) -> Double { deg * pi / 180 }
    func rad2deg(_ rad: Double) -> Double { rad * 180 / pi }

    let φ1 = deg2rad(fromLat), λ1 = deg2rad(fromLon)
    let φ2 = deg2rad(toLat), λ2 = deg2rad(toLon)

    let distRad = acos(sin(φ1)*sin(φ2) + cos(φ1)*cos(φ2)*cos(λ1-λ2))

    guard let depDate = parseUTCString(departureUTC, on: flightDate) else {
        LogManager.shared.error("Invalid departure time format: '\(departureUTC)'")
        return 0
    }

    LogManager.shared.debug("nightPortion: departureUTC='\(departureUTC)', flightDate=\(flightDate), depDate=\(depDate), flightDurationHours=\(flightDurationHours), segments=\(segments)")

    let segmentDuration = flightDurationHours * 3600 / Double(segments)
    var nightSeconds = 0.0
    var nightSegmentCount = 0

    for i in 0..<segments {
        let f = Double(i) / Double(segments)
        let A = sin((1-f) * distRad) / sin(distRad)
        let B = sin(f * distRad) / sin(distRad)

        let x = A*cos(φ1)*cos(λ1) + B*cos(φ2)*cos(λ2)
        let y = A*cos(φ1)*sin(λ1) + B*cos(φ2)*sin(λ2)
        let z = A*sin(φ1) + B*sin(φ2)

        let φi = atan2(z, sqrt(x*x + y*y))
        let λi = atan2(y, x)

        let latDeg = rad2deg(φi)
        let lonDeg = rad2deg(λi)

        let pointTime = depDate.addingTimeInterval(Double(i) * segmentDuration)

        if isNightInternal(at: latDeg, lon: lonDeg, time: pointTime) {
            nightSeconds += segmentDuration
            nightSegmentCount += 1
        }
    }

    let nightHours = nightSeconds / 3600.0
    LogManager.shared.debug("nightPortion result: \(nightSegmentCount) night segments out of \(segments) total = \(nightHours) hours")
    return nightHours
}

private func isNightInternal(at lat: Double, lon: Double, time: Date) -> Bool {
    let rad = Double.pi / 180

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!

    let jd = julianDay(for: time)
    let T = (jd - 2451545.0) / 36525.0

    // Mean longitude of the sun
    var L0 = 280.46646 + T*(36000.76983 + 0.0003032*T)
    L0 = fmod(L0, 360.0)

    // Mean anomaly
    let M = 357.52911 + T*(35999.05029 - 0.0001537*T)

    // Sun equation of the center
    let C = (1.914602 - T*(0.004817 + 0.000014*T))*sin(M*rad)
          + (0.019993 - 0.000101*T)*sin(2*M*rad)
          + 0.000289*sin(3*M*rad)

    // True longitude
    let trueLong = L0 + C

    // Apparent longitude
    let omega = 125.04 - 1934.136*T
    let lambda = trueLong - 0.00569 - 0.00478*sin(omega*rad)

    // Mean obliquity
    let epsilon0 = 23 + (26.0 + (21.448 - T*(46.815 + T*(0.00059 - T*0.001813)))/60)/60
    let epsilon = epsilon0 + 0.00256*cos(omega*rad)

    // Declination of the Sun
    let delta = asin(sin(epsilon*rad)*sin(lambda*rad))

    // Greenwich Sidereal Time and Local Sidereal Time
    let timeUTC = time.timeIntervalSince1970
    let gst = greenwichSiderealTime(for: timeUTC)
    let lst = gst + lon*rad

    // Hour angle of the sun
    let alpha = atan2(cos(epsilon*rad)*sin(lambda*rad), cos(lambda*rad))
    let H = lst - alpha

    // Elevation angle
    let elev = asin(sin(lat*rad)*sin(delta) + cos(lat*rad)*cos(delta)*cos(H))

    // Add atmospheric refraction (CONSIDER REMOVING?)
    let elevWithRefraction = elev //+ (0.833 * rad)
    
   // Check if elevation is less than 6 degrees and if it is - it's night.
    let isNight = elevWithRefraction < -6 * rad

    
//    //Debug PRINT
//    let dateFormatter = DateFormatter()
//    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
//    let elevDegrees = elev * 180 / Double.pi
//    let elevWithRefractionDegrees = elevWithRefraction * 180 / Double.pi
//    LogManager.shared.debug("isNight: time=\(dateFormatter.string(from: time)), lat=\(lat), lon=\(lon), sunElev=\(String(format: "%.2f", elevDegrees))°, elevWithRefr=\(String(format: "%.2f", elevWithRefractionDegrees))°, isNight=\(isNight)")

    
    return isNight
    //return elev < -6 * rad // Sun below horizon at -6 degrees

}

private func julianDay(for date: Date) -> Double {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

    var Y = comps.year!
    var M = comps.month!
    let D = Double(comps.day!)
        + (Double(comps.hour!) +
           Double(comps.minute!)/60 +
           Double(comps.second!)/3600) / 24.0

    if M <= 2 {
        Y -= 1
        M += 12
    }

    let A = floor(Double(Y)/100.0)
    let B = 2 - A + floor(A/4)

    return floor(365.25*(Double(Y)+4716)) +
           floor(30.6001*(Double(M)+1)) +
           D + B - 1524.5
}

private func greenwichSiderealTime(for unixTime: TimeInterval) -> Double {
    let jd = julianDay(for: Date(timeIntervalSince1970: unixTime))
    let T = (jd - 2451545.0) / 36525.0
    var theta = 280.46061837
             + 360.98564736629 * (jd - 2451545)
             + 0.000387933 * T*T
             - T*T*T/38710000
    theta = fmod(theta, 360.0)
    if theta < 0 { theta += 360.0 }
    return theta * Double.pi / 180
}

// MARK: - Usage Example
/*
let nightCalc = NightCalcService()

// Calculate night time for PER to MEL flight
if let nightHours = nightCalc.calculateNightTime(
    from: "YPPH",           // Perth
    to: "YMML",             // Melbourne
    departureUTC: "1019",   // 10:19 UTC
    flightTimeHours: 3.4    // 3.4 hours flight time
) {
    let formatted = String(format: "%.1f", nightHours)
    print("Night time: \(formatted) hours")
} else {
    print("Could not calculate night time - check airport codes")
}
*/

