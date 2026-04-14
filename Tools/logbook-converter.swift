#!/usr/bin/env swift
//
// logbook-converter.swift
// Block-Time Tools
//
// Converts a third-party logbook CSV export (PilotLog, LogTen Pro, Safelog, or
// any CSV with recognisable headers) into a Block-Time backup CSV that can be
// restored directly from the Backups screen — no need to overwrite your own logbook.
//
// Usage:
//   swift logbook-converter.swift [--local-times] <input.csv> [output.csv]
//
// Options:
//   --local-times   OUT/IN/STD/STA are in local airport time — convert to UTC during export
//
// If output path is omitted, writes Block-Time_Backup_<timestamp>_<n>flights.csv
// next to the input file.
//
// Run from anywhere — no Xcode, no dependencies, pure Foundation.
//

import Foundation

// MARK: - Output CSV header (must match FileImportService.exportToCSV exactly)
let outputHeader = "Date,Flight Number,Aircraft Reg,Aircraft Type,From Airport,To Airport,Captain Name,F/O Name,S/O1 Name,S/O2 Name,STD,STA,OUT Time,IN Time,Block Time,Night Time,P1 Time,P1US Time,P2 Time,Instrument Time,SIM Time,Sp/Ins Time,PAX,Pilot Flying,AIII,RNP,ILS,GLS,NPA,Day Takeoffs,Day Landings,Night Takeoffs,Night Landings,Remarks,Custom Count"

// MARK: - Flight row
struct FlightRow {
    var date = ""
    var flightNumber = ""
    var aircraftReg = ""
    var aircraftType = ""
    var fromAirport = ""
    var toAirport = ""
    var captainName = ""
    var foName = ""
    var so1Name = ""
    var so2Name = ""
    var std = ""
    var sta = ""
    var outTime = ""
    var inTime = ""
    var blockTime = ""
    var nightTime = ""
    var p1Time = ""
    var p1usTime = ""
    var p2Time = ""
    var instrumentTime = ""
    var simTime = ""
    var spInsTime = ""
    var isPAX = false
    var isPilotFlying = false
    var isAIII = false
    var isRNP = false
    var isILS = false
    var isGLS = false
    var isNPA = false
    var dayTakeoffs = 0
    var dayLandings = 0
    var nightTakeoffs = 0
    var nightLandings = 0
    var remarks = ""
    var customCount = 0

    func toCSVRow() -> String {
        let fields: [String] = [
            date, flightNumber, aircraftReg, aircraftType,
            fromAirport, toAirport, captainName, foName,
            so1Name, so2Name, std, sta, outTime, inTime,
            blockTime, nightTime, p1Time, p1usTime, p2Time,
            instrumentTime, simTime, spInsTime,
            isPAX ? "1" : "",
            isPilotFlying ? "1" : "",
            isAIII ? "1" : "",
            isRNP ? "1" : "",
            isILS ? "1" : "",
            isGLS ? "1" : "",
            isNPA ? "1" : "",
            String(dayTakeoffs), String(dayLandings),
            String(nightTakeoffs), String(nightLandings),
            escapeCSV(remarks),
            customCount > 0 ? String(customCount) : ""
        ]
        return fields.joined(separator: ",")
    }
}

// MARK: - CSV helpers

func escapeCSV(_ field: String) -> String {
    if field.contains(",") || field.contains("\"") || field.contains("\n") {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    return field
}

func parseCSVRows(content: String, delimiter: Character) -> [[String]] {
    // Normalise line endings: \r\n and \r → \n before processing.
    // Swift treats \r\n as a single grapheme cluster, so character-by-character
    // iteration won't see \r or \n separately — normalise first.
    var cleaned = content
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    if cleaned.hasPrefix("\u{FEFF}") { cleaned.removeFirst() }

    var rows: [[String]] = []
    var currentField = ""
    var fields: [String] = []
    var inQuotes = false
    let chars = Array(cleaned)
    var i = 0

    func finishField() {
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        currentField = ""
    }

    while i < chars.count {
        let char = chars[i]
        if char == "\"" {
            if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                // Escaped quote "" → literal "
                currentField.append("\"")
                i += 2
                continue
            } else {
                inQuotes.toggle()
            }
        } else if char == delimiter && !inQuotes {
            finishField()
        } else if char == "\r" && !inQuotes {
            // skip bare \r; \r\n handled by skipping \r then \n finishes the row
        } else if char == "\n" && !inQuotes {
            finishField()
            if !fields.isEmpty { rows.append(fields) }
            fields = []
        } else if char != "\r" {
            currentField.append(char)
        }
        i += 1
    }
    finishField()
    if !fields.isEmpty { rows.append(fields) }

    // Drop trailing empty rows
    while rows.last?.allSatisfy({ $0.isEmpty }) == true { rows.removeLast() }
    return rows
}

func detectDelimiter(_ content: String) -> Character {
    let firstLine = content.components(separatedBy: .newlines).first ?? ""
    let tabs = firstLine.filter { $0 == "\t" }.count
    let commas = firstLine.filter { $0 == "," }.count
    return tabs > commas ? "\t" : ","
}

// MARK: - Airport database (mirrors AirportService)

struct AirportInfo {
    let icaoCode: String
    let timezoneOffset: Double
    let dstCode: String
}

struct AirportDatabase {
    var airports: [String: AirportInfo] = [:]
    var iataToIcao: [String: String] = [:]
}

/// Lazily loaded airport database, built from airports.dat.txt.
/// Searched in: script directory, relative to CWD, then the known repo path.
var airportDB: AirportDatabase = {
    let candidates: [String] = [
        URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .appendingPathComponent("../Block-Time/Resources/airports.dat.txt")
            .standardized.path,
        "Block-Time/Resources/airports.dat.txt",
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/CloudStorage/OneDrive-Personal/Coding/Xcode/Block-Time/Block-Time/Resources/airports.dat.txt",
    ]

    for path in candidates {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
        var db = AirportDatabase()
        db.airports.reserveCapacity(6_000)
        db.iataToIcao.reserveCapacity(6_000)
        content.enumerateLines { line, _ in
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count >= 11 else { return }
            let icao = parts[5].trimmingCharacters(in: .init(charactersIn: "\" "))
            guard icao.count == 4, icao != "\\N" else { return }
            guard let tzOffset = Double(parts[9]) else { return }
            let dst = parts[10].trimmingCharacters(in: .init(charactersIn: "\" "))
            let iata = parts[4].trimmingCharacters(in: .init(charactersIn: "\" "))
            if iata.count == 3, iata != "\\N" {
                db.iataToIcao[iata] = icao
            }
            db.airports[icao] = AirportInfo(icaoCode: icao, timezoneOffset: tzOffset, dstCode: dst)
        }
        print("Airport DB: loaded \(db.airports.count) airports from \(path)")
        return db
    }
    fputs("Warning: airports.dat.txt not found — IATA codes will be stored as-is and local time conversion unavailable\n", stderr)
    return AirportDatabase()
}()

/// Convert a 3-letter IATA code to 4-letter ICAO. Already-ICAO or unknown codes pass through unchanged.
func convertToICAO(_ code: String) -> String {
    let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard upper.count == 3 else { return upper }
    return airportDB.iataToIcao[upper] ?? upper
}

// MARK: - DST and local→UTC conversion (mirrors AirportService)

func isDSTActive(on date: Date, dstCode: String) -> Bool {
    let calendar = Calendar.current
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)

    func lastSundayOf(month m: Int, year y: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m + 1; comps.day = 1
        guard let first = calendar.date(from: comps),
              let last = calendar.date(byAdding: .day, value: -1, to: first) else { return date }
        let wd = calendar.component(.weekday, from: last)
        return calendar.date(byAdding: .day, value: -((wd + 6) % 7), to: last) ?? date
    }
    func nthSundayOf(month m: Int, year y: Int, n: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = 1
        guard let first = calendar.date(from: comps) else { return date }
        let wd = calendar.component(.weekday, from: first)
        guard let firstSun = calendar.date(byAdding: .day, value: (8 - wd) % 7, to: first) else { return date }
        return calendar.date(byAdding: .weekOfYear, value: n - 1, to: firstSun) ?? date
    }

    switch dstCode {
    case "E":
        return date >= lastSundayOf(month: 3, year: year) && date < lastSundayOf(month: 10, year: year)
    case "A":
        return date >= nthSundayOf(month: 3, year: year, n: 2) && date < nthSundayOf(month: 11, year: year, n: 1)
    case "S":
        if month >= 10 { return date >= nthSundayOf(month: 10, year: year, n: 3) }
        if month <= 3  { return date < nthSundayOf(month: 3, year: year, n: 3) }
        return false
    case "O":
        if month >= 10 { return date >= nthSundayOf(month: 10, year: year, n: 1) }
        if month <= 4  { return date < nthSundayOf(month: 4, year: year, n: 1) }
        return false
    case "Z":
        if month >= 9 { return date >= lastSundayOf(month: 9, year: year) }
        if month <= 4 { return date < nthSundayOf(month: 4, year: year, n: 1) }
        return false
    default:
        return false
    }
}

/// Convert a local "HH:MM" time string to UTC "HH:MM", given a date string ("dd/MM/yyyy") and ICAO code.
/// Returns the original string if the airport is unknown or input is empty.
func convertLocalToUTCTime(dateString: String, timeString: String, icao: String) -> String {
    guard !timeString.isEmpty else { return timeString }
    guard let info = airportDB.airports[icao.uppercased()] else { return timeString }

    let clean = timeString.replacingOccurrences(of: ":", with: "")
    let hours: Int
    let minutes: Int
    if clean.count == 4 {
        hours = Int(clean.prefix(2)) ?? 0; minutes = Int(clean.suffix(2)) ?? 0
    } else if clean.count == 3 {
        hours = Int(clean.prefix(1)) ?? 0; minutes = Int(clean.suffix(2)) ?? 0
    } else {
        return timeString
    }

    let parts = dateString.split(separator: "/")
    guard parts.count == 3,
          let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else {
        return timeString
    }

    var comps = DateComponents()
    comps.year = year; comps.month = month; comps.day = day
    comps.hour = hours; comps.minute = minutes; comps.second = 0

    let roughCalendar = Calendar.current
    guard let roughDate = roughCalendar.date(from: comps) else { return timeString }

    var totalOffset = info.timezoneOffset
    if isDSTActive(on: roughDate, dstCode: info.dstCode) { totalOffset += 1.0 }

    guard let localTZ = TimeZone(secondsFromGMT: Int(totalOffset * 3600)) else { return timeString }
    var localCal = Calendar.current
    localCal.timeZone = localTZ
    guard let localDateTime = localCal.date(from: comps) else { return timeString }

    var utcCal = Calendar.current
    utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
    let utcHour = utcCal.component(.hour, from: localDateTime)
    let utcMinute = utcCal.component(.minute, from: localDateTime)
    return String(format: "%02d:%02d", utcHour, utcMinute)
}

// MARK: - Normalisation (mirrors ImportMappingView.normalize)

func normalize(_ s: String) -> String {
    s.lowercased().filter { $0.isLetter || $0.isNumber }
}

// MARK: - Known App Profiles (mirrors ImportMappingView.appProfiles)

let appProfiles: [String: [String: String]] = [
    "LogTen Pro": [
        "date":           "flight_flightDate",
        "flightnumber":   "flight_flightNumber",
        "aircraftreg":    "aircraft_aircraftID",
        "aircrafttype":   "aircraftType_type",
        "fromairport":    "flight_from",
        "toairport":      "flight_to",
        "captainname":    "flight_selectedCrewPIC",
        "f/oname":        "flight_selectedCrewSIC",
        "s/o1name":       "flight_selectedCrewRelief",
        "s/o2name":       "flight_selectedCrewRelief2",
        "std":            "flight_scheduledDepartureTime",
        "sta":            "flight_scheduledArrivalTime",
        "outtime":        "flight_actualDepartureTime",
        "intime":         "flight_actualArrivalTime",
        "blocktime":      "flight_totalTime",
        "nighttime":      "flight_night",
        "p1time":         "flight_pic",
        "p1ustime":       "flight_p1us",
        "p2time":         "flight_sic",
        "instrumenttime": "flight_actualInstrument",
        "simtime":        "flight_simulator",
        "pilotflying":    "flight_pilotFlyingCapacity",
        "daytakeoffs":    "flight_dayTakeoffs",
        "daylandings":    "flight_dayLandings",
        "nighttakeoffs":  "flight_nightTakeoffs",
        "nightlandings":  "flight_nightLandings",
        "customcount":    "flight_paxCount",
        "remarks":        "flight_remarks",
    ],
    "PilotLog": [
        "date":           "pilotlog_date",
        "flightnumber":   "flightnumber",
        "aircraftreg":    "ac_reg",
        "aircrafttype":   "ac_model",
        "fromairport":    "af_dep",
        "toairport":      "af_arr",
        "captainname":    "pilot1_name",
        "f/oname":        "pilot2_name",
        "s/o1name":       "pilot3_name",
        "s/o2name":       "pilot4_name",
        "std":            "time_depsch",
        "sta":            "time_arrsch",
        "outtime":        "time_dep",
        "intime":         "time_arr",
        "blocktime":      "time_total",
        "nighttime":      "time_night",
        "p1time":         "time_pic",
        "p1ustime":       "time_picus",
        "p2time":         "time_sic",
        "instrumenttime": "time_actual",
        "simtime":        "sim_time",
        "pilotflying":    "pf",
        "daytakeoffs":    "to_day",
        "daylandings":    "ldg_day",
        "nighttakeoffs":  "to_night",
        "nightlandings":  "ldg_night",
        "remarks":        "remarks",
    ],
    "Safelog": [
        "date":           "DATE",
        "flightnumber":   "FLT_NUM",
        "aircraftreg":    "AC_REG",
        "aircrafttype":   "AC_TYP",
        "fromairport":    "FROM",
        "toairport":      "TO",
        "captainname":    "CAPTAIN",
        "f/oname":        "FIRST_OFFICER",
        "blocktime":      "TOTAL",
        "p1time":         "PIC",
        "p2time":         "SIC",
        "nighttime":      "NIGHT",
        "instrumenttime": "IFR",
        "simtime":        "SIM_TIME",
        "daytakeoffs":    "DAY_TO",
        "nighttakeoffs":  "NIGHT_TO",
        "daylandings":    "DAY_LDG",
        "nightlandings":  "NIGHT_LDG",
        "remarks":        "REMARKS",
    ],
]

func detectAppProfile(headers: [String]) -> (name: String, map: [String: String])? {
    let normalizedHeaders = Set(headers.map { normalize($0) })
    var bestName: String? = nil
    var bestMap: [String: String]? = nil
    var bestScore = 0

    for (name, mapping) in appProfiles {
        let score = mapping.values.filter { normalizedHeaders.contains(normalize($0)) }.count
        if score > bestScore && score >= 8 {
            bestScore = score
            bestName = name
            bestMap = Dictionary(uniqueKeysWithValues: mapping.map { (normalize($0.key), $0.value) })
        }
    }
    guard let name = bestName, let map = bestMap else { return nil }
    return (name: name, map: map)
}

// MARK: - Synonym fallback (mirrors ImportMappingView.synonyms)

let synonyms: [String: [String]] = [
    "date":           ["flightdate", "flightday", "date"],
    "flightnumber":   ["flightnumber", "flightno", "fltno", "flt"],
    "aircraftreg":    ["aircraftreg", "registration", "tailnumber", "tail", "reg", "rego", "regno"],
    "aircrafttype":   ["aircrafttype", "aircraftmodel", "makemodel", "actype", "type", "model", "make"],
    "fromairport":    ["fromairport", "departureplace", "depairport", "departure", "origin", "from", "dep"],
    "toairport":      ["toairport", "arrivalplace", "arrairport", "destination", "arrival", "dest", "arr"],
    "captainname":    ["captainname", "crewpic", "p1crew", "picname", "captain", "cpt", "pic"],
    "f/oname":        ["f/oname", "crewsic", "p2crew", "sicname", "firstofficer", "copilot", "fo"],
    "s/o1name":       ["relief1", "crewrelief", "secondofficer1", "so1", "relief", "cruise", "p3"],
    "s/o2name":       ["relief2", "crewrelief2", "secondofficer2", "so2", "p4"],
    "std":            ["scheduleddeparturetime", "scheduleddeparture", "scheduleddep", "scheddep", "std", "etd"],
    "sta":            ["scheduledarrivaltime", "scheduledarrival", "scheduledarr", "schedarr", "sta", "eta"],
    "outtime":        ["actualdeparturetime", "blockout", "outtime", "out"],
    "intime":         ["actualarrivaltime", "blockin", "intime"],
    "blocktime":      ["totaltime", "totalduration", "blocktime", "total", "block", "tot"],
    "nighttime":      ["nighttime", "picnight", "p1night", "sicnight", "p2night", "fonight", "captainnight", "night"],
    "p1time":         ["pictime", "p1time", "pic"],
    "p1ustime":       ["p1ustime", "icustime", "p1supervisedtime", "spte", "p1us", "icus"],
    "p2time":         ["sictime", "p2time", "siccopilot", "copilottime", "sic", "p2"],
    "instrumenttime": ["actualinstrument", "actualimc", "instrumenttime", "instrument", "actualifr", "ifrtime", "ifr", "inst"],
    "simtime":        ["simulatortime", "simtime", "simulator", "synthetic", "simimc", "sim"],
    "spinstime":      ["spinstructortime", "spinstime", "spinstructor", "spins", "spinstr", "inspilot"],
    "pilotflying":    ["pilotflyingcapacity", "pilotflying", "flying", "pf"],
    "pax":            ["positioning", "deadhead", "passengerflight", "dh", "pax"],
    "customcount":    ["customcount", "paxcount", "passengercount", "soulsonboard", "sob", "passengers"],
    "daytakeoffs":    ["daytakeoffs", "takeoffsday", "today", "tday", "dayt/o", "dto"],
    "daylandings":    ["daylanding", "daylandings", "landingsday", "ldgday", "dayldg"],
    "nighttakeoffs":  ["nighttakeoffs", "takeoffsnight", "tonight", "nightt/o", "nto"],
    "nightlandings":  ["nightlanding", "nightlandings", "landingsnight", "ldgnight", "nightldg"],
    "rnp":            ["rnpapproach", "rnpar", "rnav", "rnp"],
    "ils":            ["ilsapproach", "catii", "cati", "cat2", "cat1", "ils"],
    "gls":            ["glsapproach", "gls"],
    "npa":            ["npaapproach", "npa"],
    "aiii":           ["aiiiapproach", "catiii", "cat3", "aiii"],
    "remarks":        ["remarks", "endorsements", "comments", "notes"],
]

func tokenMatches(_ header: String, synonym: String) -> Bool {
    guard !synonym.isEmpty else { return false }
    if header == synonym { return true }
    let parts = header.components(separatedBy: synonym)
    guard parts.count >= 2 else { return false }
    let before = parts.first ?? ""
    let after = parts.dropFirst().joined(separator: synonym)
    let beforeOK = before.isEmpty || (!before.last!.isLetter && !before.last!.isNumber)
    let afterOK = after.isEmpty || (!after.first!.isLetter && !after.first!.isNumber)
    return beforeOK && afterOK
}

func detectColumn(for logbookField: String, in headers: [String], profileMap: [String: String]?) -> String? {
    let fieldKey = normalize(logbookField)
    let normalizedHeaders = headers.map { (original: $0, norm: normalize($0)) }

    // Tier 1: exact match
    if let exact = normalizedHeaders.first(where: { $0.norm == fieldKey }) {
        return exact.original
    }

    // Tier 2: known profile
    if let profileMap = profileMap, let profileHeader = profileMap[fieldKey] {
        let profileNorm = normalize(profileHeader)
        if let match = normalizedHeaders.first(where: { $0.norm == profileNorm }) {
            return match.original
        }
    }

    // Tier 3: synonym
    guard let fieldSynonyms = synonyms[fieldKey] else { return nil }
    for synonym in fieldSynonyms {
        if let match = normalizedHeaders.first(where: { tokenMatches($0.norm, synonym: synonym) }) {
            return match.original
        }
    }
    return nil
}

// MARK: - Pre-processing (mirrors FileImportService.preprocess)

func preprocess(headers: [String], rows: [[String]]) -> ([String], [[String]]) {
    // PilotLog: move time_total → sim_time for rows where ac_issim contains "sim"
    if let isSimIdx = headers.firstIndex(of: "ac_issim"),
       let totalIdx = headers.firstIndex(of: "time_total") {

        var outHeaders = headers
        let simTimeCol = "sim_time"
        let simTimeIdx: Int
        if let existing = headers.firstIndex(of: simTimeCol) {
            simTimeIdx = existing
        } else {
            outHeaders.append(simTimeCol)
            simTimeIdx = outHeaders.count - 1
        }

        var simCount = 0
        let outRows: [[String]] = rows.map { row in
            guard isSimIdx < row.count else { return row }
            let isSim = row[isSimIdx].lowercased().contains("sim")
            guard isSim else {
                if simTimeIdx >= row.count { return row + [""] }
                return row
            }
            simCount += 1
            var mutable = row
            while mutable.count <= simTimeIdx { mutable.append("") }
            let totalValue = totalIdx < row.count ? row[totalIdx] : ""
            mutable[simTimeIdx] = totalValue
            mutable[totalIdx] = "00:00"
            return mutable
        }

        if simCount > 0 {
            print("  ⚙️  Pre-processed \(simCount) simulator row(s): time_total → sim_time")
        }
        return (outHeaders, outRows)
    }
    return (headers, rows)
}

// MARK: - Parsing helpers (mirrors FileImportService)

func parseDurationTime(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty { return "" }
    let lower = t.lowercased()
    let boolLike = ["true","false","yes","no","sim","y","n"]
    if boolLike.contains(lower) { return "0.0" }

    if t.contains(":") {
        let parts = t.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 2 {
            let h = parts[0].trimmingCharacters(in: .whitespaces)
            let m = parts[1].trimmingCharacters(in: .whitespaces)
            if h.isEmpty, let mins = Double(m) {
                return String(format: "%.2f", mins / 60.0)
            }
            if let hours = Double(h), let mins = Double(m) {
                return String(format: "%.2f", hours + mins / 60.0)
            }
        }
    }
    if let d = Double(t) { return String(format: "%.2f", d) }
    return t
}

func parseTime(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return "" }
    if t.contains(":") {
        let parts = t.split(separator: ":")
        if parts.count == 2,
           let h = Int(parts[0]), let m = Int(parts[1]),
           h < 24, m < 60 {
            return String(format: "%02d:%02d", h, m)
        }
        return t
    }
    if t.count == 4, Int(t) != nil {
        return "\(t.prefix(2)):\(t.suffix(2))"
    }
    if t.count == 3, Int(t) != nil {
        return String(format: "%02d:", Int(String(t.prefix(1))) ?? 0) + t.suffix(2)
    }
    return t
}

func parseBool(_ s: String) -> Bool {
    let n = s.lowercased().trimmingCharacters(in: .whitespaces)
    if n.isEmpty { return false }
    if ["false","no","0","n"].contains(n) { return false }
    return true
}

func parseDate(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return "" }

    let formats = [
        "dd/MM/yy", "d/M/yy", "MM/dd/yy", "yy-MM-dd",
        "ddMMMyy", "dMMMyy", "dd-MMM-yy", "d-MMM-yy",
        "dd MMM yy", "d MMM yy",
        "dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "d-M-yyyy",
        "yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy",
        "dd.MM.yyyy", "d.M.yyyy", "yyyyMMdd",
        "dd MMM yyyy", "d MMM yyyy", "dd MMMM yyyy",
        "MMM dd, yyyy", "MMMM dd, yyyy", "yyyy/MM/dd",
    ]

    let referenceDate = Calendar.current.date(from: DateComponents(year: 1950, month: 1, day: 1))!
    let output = DateFormatter()
    output.dateFormat = "dd/MM/yyyy"
    output.locale = Locale(identifier: "en_US_POSIX")
    output.timeZone = TimeZone(secondsFromGMT: 0)

    for format in formats {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        if format.contains("yy") && !format.contains("yyyy") {
            f.twoDigitStartDate = referenceDate
        }
        if let date = f.date(from: t) {
            return output.string(from: date)
        }
    }
    return t
}

// MARK: - Crew name normalisation

// LogTen Pro exports crew as "Lastname, Firstname" — reformat to "Firstname Lastname".
// Also trims extra whitespace from split fields.
func parseCrewName(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespaces)
    guard !t.isEmpty else { return "" }
    // "Lastname, Firstname" → "Firstname Lastname"
    if t.contains(",") {
        let parts = t.components(separatedBy: ",")
        if parts.count == 2 {
            let last = parts[0].trimmingCharacters(in: .whitespaces)
            let first = parts[1].trimmingCharacters(in: .whitespaces)
            if !first.isEmpty && !last.isEmpty {
                return "\(first) \(last)"
            }
        }
    }
    return t
}

// MARK: - Column lookup helper

func makeGetter(row: [String], headers: [String]) -> (String) -> String {
    let indexMap = Dictionary(uniqueKeysWithValues: headers.enumerated().map { ($1, $0) })
    return { field in
        guard let idx = indexMap[field], idx < row.count else { return "" }
        return row[idx]
    }
}

// MARK: - Main conversion

func convert(inputPath: String, outputPath: String?, timesAreLocal: Bool) {
    // Read input
    guard let content = try? String(contentsOfFile: inputPath, encoding: .utf8) else {
        fputs("Error: cannot read file at \(inputPath)\n", stderr)
        exit(1)
    }

    let delimChar = detectDelimiter(content)
    let allRows = parseCSVRows(content: content, delimiter: delimChar)

    guard allRows.count > 1 else {
        fputs("Error: file appears empty or has no data rows\n", stderr)
        exit(1)
    }

    let rawHeaders = allRows[0]
    let rawRows = Array(allRows.dropFirst())

    // Pre-process
    let (headers, rows) = preprocess(headers: rawHeaders, rows: rawRows)

    // Detect profile
    let detected = detectAppProfile(headers: headers)
    let profileMap = detected.map { $0.map }

    print("Input:   \(inputPath)")
    print("Rows:    \(rows.count) data rows, \(headers.count) columns")
    if let p = detected {
        print("Profile: \(p.name) detected ✓")
    } else {
        print("Profile: none detected — using synonym matching")
    }
    if timesAreLocal {
        print("Times:   local airport time → UTC conversion enabled")
    }

    // Build column→header map for each Block-Time field
    let fields: [(key: String, label: String)] = [
        ("Date", "Date"), ("Flight Number", "Flight Number"),
        ("Aircraft Reg", "Aircraft Reg"), ("Aircraft Type", "Aircraft Type"),
        ("From Airport", "From Airport"), ("To Airport", "To Airport"),
        ("Captain Name", "Captain Name"), ("F/O Name", "F/O Name"),
        ("S/O1 Name", "S/O1 Name"), ("S/O2 Name", "S/O2 Name"),
        ("STD", "STD"), ("STA", "STA"),
        ("OUT Time", "OUT Time"), ("IN Time", "IN Time"),
        ("Block Time", "Block Time"), ("Night Time", "Night Time"),
        ("P1 Time", "P1 Time"), ("P1US Time", "P1US Time"),
        ("P2 Time", "P2 Time"), ("Instrument Time", "Instrument Time"),
        ("SIM Time", "SIM Time"), ("Sp/Ins Time", "Sp/Ins Time"),
        ("Pilot Flying", "Pilot Flying"), ("PAX", "PAX"),
        ("AIII", "AIII"), ("RNP", "RNP"), ("ILS", "ILS"),
        ("GLS", "GLS"), ("NPA", "NPA"),
        ("Day Takeoffs", "Day Takeoffs"), ("Day Landings", "Day Landings"),
        ("Night Takeoffs", "Night Takeoffs"), ("Night Landings", "Night Landings"),
        ("Remarks", "Remarks"),
        ("Custom Count", "Custom Count"),
    ]

    var columnMap: [String: String] = [:]
    var mappedCount = 0
    for field in fields {
        if let col = detectColumn(for: field.key, in: headers, profileMap: profileMap) {
            columnMap[field.key] = col
            mappedCount += 1
        }
    }
    print("Mapped:  \(mappedCount)/\(fields.count) fields")

    guard columnMap["Date"] != nil else {
        fputs("Error: could not detect a Date column — cannot proceed\n", stderr)
        exit(1)
    }

    // Print mapping summary
    print("\nField mapping:")
    for field in fields {
        if let col = columnMap[field.key] {
            print("  \(field.label.padding(toLength: 18, withPad: " ", startingAt: 0)) ← \(col)")
        } else {
            print("  \(field.label.padding(toLength: 18, withPad: " ", startingAt: 0))   (not mapped)")
        }
    }
    print("")

    // Convert rows
    var outputRows: [String] = []
    var skipped = 0

    for row in rows {
        let get = makeGetter(row: row, headers: headers)
        func field(_ f: String) -> String { get(columnMap[f] ?? "") }

        let date = parseDate(field("Date"))
        if date.isEmpty { skipped += 1; continue }

        var flight = FlightRow()
        flight.date = date
        flight.flightNumber = field("Flight Number")
        flight.aircraftReg = field("Aircraft Reg")
        flight.aircraftType = field("Aircraft Type")
        flight.fromAirport = convertToICAO(field("From Airport"))
        flight.toAirport = convertToICAO(field("To Airport"))
        flight.captainName = parseCrewName(field("Captain Name"))
        flight.foName = parseCrewName(field("F/O Name"))
        flight.so1Name = parseCrewName(field("S/O1 Name"))
        flight.so2Name = parseCrewName(field("S/O2 Name"))
        flight.std = parseTime(field("STD"))
        flight.sta = parseTime(field("STA"))
        flight.outTime = parseTime(field("OUT Time"))
        flight.inTime = parseTime(field("IN Time"))

        if timesAreLocal {
            flight.outTime = convertLocalToUTCTime(dateString: date, timeString: flight.outTime, icao: flight.fromAirport)
            flight.std     = convertLocalToUTCTime(dateString: date, timeString: flight.std,     icao: flight.fromAirport)
            flight.inTime  = convertLocalToUTCTime(dateString: date, timeString: flight.inTime,  icao: flight.toAirport)
            flight.sta     = convertLocalToUTCTime(dateString: date, timeString: flight.sta,     icao: flight.toAirport)
        }
        flight.blockTime = parseDurationTime(field("Block Time"))
        flight.nightTime = parseDurationTime(field("Night Time"))
        flight.p1Time = parseDurationTime(field("P1 Time"))
        flight.p1usTime = parseDurationTime(field("P1US Time"))
        flight.p2Time = parseDurationTime(field("P2 Time"))
        flight.instrumentTime = parseDurationTime(field("Instrument Time"))
        flight.simTime = parseDurationTime(field("SIM Time"))
        flight.spInsTime = parseDurationTime(field("Sp/Ins Time"))
        flight.isPAX = parseBool(field("PAX"))
        flight.isAIII = parseBool(field("AIII"))
        flight.isRNP = parseBool(field("RNP"))
        flight.isILS = parseBool(field("ILS"))
        flight.isGLS = parseBool(field("GLS"))
        flight.isNPA = parseBool(field("NPA"))
        flight.dayTakeoffs = Int(field("Day Takeoffs")) ?? 0
        flight.dayLandings = Int(field("Day Landings")) ?? 0
        flight.nightTakeoffs = Int(field("Night Takeoffs")) ?? 0
        flight.nightLandings = Int(field("Night Landings")) ?? 0
        flight.remarks = field("Remarks")
        flight.customCount = flight.isPAX ? 0 : (Int(field("Custom Count").trimmingCharacters(in: .whitespaces)) ?? 0)

        // Pilot flying: explicit column, or infer from instrument time > 0
        flight.isPilotFlying = parseBool(field("Pilot Flying"))
        if !flight.isPilotFlying,
           let inst = Double(flight.instrumentTime), inst > 0 {
            flight.isPilotFlying = true
        }

        outputRows.append(flight.toCSVRow())
    }

    // Build output
    let csv = ([outputHeader] + outputRows).joined(separator: "\n") + "\n"

    // Determine output path
    let resolvedOutput: String
    if let out = outputPath {
        resolvedOutput = out
    } else {
        let inputURL = URL(fileURLWithPath: inputPath)
        let dir = inputURL.deletingLastPathComponent().path
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "Block-Time_Backup_\(timestamp)_\(outputRows.count)flights.csv"
        resolvedOutput = "\(dir)/\(filename)"
    }

    do {
        try csv.write(toFile: resolvedOutput, atomically: true, encoding: .utf8)
        print("✅ Written \(outputRows.count) flights to:")
        print("   \(resolvedOutput)")
        if skipped > 0 {
            print("⚠️  Skipped \(skipped) row(s) with unparseable dates")
        }
    } catch {
        fputs("Error writing output: \(error)\n", stderr)
        exit(1)
    }
}

// MARK: - Entry point

let args = CommandLine.arguments
let flags = Set(args.dropFirst().filter { $0.hasPrefix("--") })
let positional = args.dropFirst().filter { !$0.hasPrefix("--") }

guard positional.count >= 1 else {
    print("Usage: swift logbook-converter.swift [--local-times] <input.csv> [output.csv]")
    print("")
    print("Converts a PilotLog, LogTen Pro, Safelog, or generic logbook CSV")
    print("into a Block-Time backup file that can be restored directly from")
    print("the app's Backups screen.")
    print("")
    print("Options:")
    print("  --local-times   OUT/IN/STD/STA are in local airport time — convert to UTC")
    exit(0)
}

let timesAreLocal = flags.contains("--local-times")
convert(inputPath: positional[0], outputPath: positional.count >= 2 ? positional[1] : nil, timesAreLocal: timesAreLocal)
