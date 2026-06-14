//
//  MacLogbookViewModel.swift
//  Block-Time-Mac
//
//  Logbook view-model for the Mac target.
//  Data layer: BlockTimeKit's FlightDatabaseService (shared with iOS).
//  Aircraft CRUD: BlockTimeKit's AircraftFleetService (shared with iOS).
//

import Foundation
import SwiftUI
import Combine
import BlockTimeKit

// MARK: - Mac Flight Row
// Lightweight display struct for the Table view. No iOS dependencies.

struct MacFlightRow: Identifiable {
    let id: UUID
    var rawDate: Date
    var date: String
    var flightNumber: String
    var fromAirport: String
    var toAirport: String
    var scheduledDeparture: String
    var scheduledArrival: String
    var outTime: String
    var inTime: String
    var blockTime: Double
    var nightTime: Double
    var instrumentTime: Double
    var captainName: String
    var foName: String
    var so1Name: String
    var so2Name: String
    var p1Time: Double
    var p1usTime: Double
    var p2Time: Double
    var simTime: Double
    var spInsTime: Double
    var aircraftType: String
    var aircraftReg: String
    var dayTakeoffs: Int
    var nightTakeoffs: Int
    var dayLandings: Int
    var nightLandings: Int
    var isPilotFlying: Bool
    var isPositioning: Bool
    var isILS: Bool
    var isGLS: Bool
    var isNPA: Bool
    var isRNP: Bool
    var isAIII: Bool
    var counter1: String
    var counter2: String
    var counter3: String
    var counter4: String
    var counter5: String
    var counter6: String
    var counter7: String
    var counter8: String
    var counter9: String
    var counter10: String
    var remarks: String

    enum RowAccent { case none, pax, sim, spIns, summary }
    var accent: RowAccent {
        if flightNumber == "SUMMARY" { return .summary }
        if spInsTime > 0 { return .spIns }
        if simTime   > 0 { return .sim }
        if isPositioning  { return .pax }
        return .none
    }

    /// UTC instant of departure — rawDate (midnight) + OUT time, falling back to STD.
    var departureDatetime: Date {
        let t = outTime.isEmpty ? scheduledDeparture : outTime
        let clean = t.replacingOccurrences(of: ":", with: "")
        guard clean.count == 4,
              let h = Int(clean.prefix(2)),
              let m = Int(clean.suffix(2)) else { return rawDate }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(bySettingHour: h, minute: m, second: 0, of: rawDate) ?? rawDate
    }

    // MARK: Formatted display helpers

    func dateDisplay(localTime: Bool) -> String {
        let monthAbbr = ["Jan","Feb","Mar","Apr","May","Jun",
                         "Jul","Aug","Sep","Oct","Nov","Dec"]

        guard localTime else {
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
            let c = utcCal.dateComponents([.day, .month, .year], from: rawDate)
            guard let d = c.day, let m = c.month, let y = c.year,
                  m >= 1, m <= 12 else { return date }
            return String(format: "%d %@ %02d", d, monthAbbr[m - 1], y % 100)
        }

        let depTime = outTime.isEmpty ? scheduledDeparture : outTime
        let icao = AirportService.shared.convertToICAO(fromAirport)

        let refDate: Date
        if !depTime.isEmpty {
            let clean = depTime.replacingOccurrences(of: ":", with: "")
            if clean.count == 4,
               let h = Int(clean.prefix(2)), let m = Int(clean.suffix(2)) {
                var utcCal = Calendar(identifier: .gregorian)
                utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
                refDate = utcCal.date(bySettingHour: h, minute: m, second: 0, of: rawDate) ?? rawDate
            } else {
                refDate = rawDate
            }
        } else {
            refDate = rawDate
        }

        let tz = AirportService.shared.getTimeZone(for: icao, on: refDate)
                 ?? TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.day, .month, .year], from: refDate)
        guard let d = c.day, let m = c.month, let y = c.year,
              m >= 1, m <= 12 else { return date }
        return String(format: "%d %@ %02d", d, monthAbbr[m - 1], y % 100)
    }

    // MARK: - UTC HHMM → local HHMM conversion (airport timezone, DST-aware)

    func displayTime(_ hhmm: String, localTime: Bool, airportICAO: String) -> String {
        guard !hhmm.isEmpty else { return "" }
        let raw: String
        if localTime {
            let icao = AirportService.shared.convertToICAO(airportICAO)
            raw = AirportService.shared.convertToLocalTime(
                utcDateString: date,
                utcTimeString: hhmm,
                airportICAO: icao
            )
        } else {
            raw = hhmm.replacingOccurrences(of: ":", with: "")
        }
        guard raw.count == 4 else { return raw }
        return "\(raw.prefix(2)):\(raw.suffix(2))"
    }

    // MARK: - Static time formatters

    static func hhmmDisplay(_ decimal: Double) -> String {
        guard decimal > 0 else { return "" }
        let totalMinutes = Int((decimal * 60).rounded())
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    static func decimalDisplay(_ decimal: Double, rounding: String) -> String {
        guard decimal > 0 else { return "" }
        let rounded: Double
        if rounding == "alternate" {
            let scaled = decimal * 10
            let frac = scaled.truncatingRemainder(dividingBy: 1.0)
            rounded = (frac < 0.6 ? floor(scaled) : ceil(scaled)) / 10
        } else {
            rounded = (decimal * 10).rounded(.toNearestOrAwayFromZero) / 10
        }
        return String(format: "%.1f", rounded)
    }

    static func formatTime(_ decimal: Double, hhmm: Bool, rounding: String = "standard") -> String {
        guard decimal > 0 else { return "" }
        return hhmm ? hhmmDisplay(decimal) : decimalDisplay(decimal, rounding: rounding)
    }

    /// Parse a time string (decimal or HH:MM) back to a decimal Double.
    nonisolated static func parseTime(_ s: String) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  let h = Double(parts[0]),
                  let m = Double(parts[1]) else { return 0 }
            return h + m / 60.0
        }
        return Double(trimmed) ?? 0
    }

    func blockDisplay(hhmm: Bool, rounding: String)      -> String { Self.formatTime(blockTime,      hhmm: hhmm, rounding: rounding) }
    func nightDisplay(hhmm: Bool, rounding: String)      -> String { Self.formatTime(nightTime,      hhmm: hhmm, rounding: rounding) }
    func instrumentDisplay(hhmm: Bool, rounding: String) -> String { Self.formatTime(instrumentTime, hhmm: hhmm, rounding: rounding) }
    func p1Display(hhmm: Bool, rounding: String)         -> String { Self.formatTime(p1Time,         hhmm: hhmm, rounding: rounding) }
    func p1usDisplay(hhmm: Bool, rounding: String)       -> String { Self.formatTime(p1usTime,       hhmm: hhmm, rounding: rounding) }
    func p2Display(hhmm: Bool, rounding: String)         -> String { Self.formatTime(p2Time,         hhmm: hhmm, rounding: rounding) }
    func simDisplay(hhmm: Bool, rounding: String)        -> String { Self.formatTime(simTime,         hhmm: hhmm, rounding: rounding) }
    func spInsDisplay(hhmm: Bool, rounding: String)      -> String { Self.formatTime(spInsTime,       hhmm: hhmm, rounding: rounding) }

    func counterValue(_ idx: Int) -> String {
        switch idx {
        case 1:  return counter1
        case 2:  return counter2
        case 3:  return counter3
        case 4:  return counter4
        case 5:  return counter5
        case 6:  return counter6
        case 7:  return counter7
        case 8:  return counter8
        case 9:  return counter9
        case 10: return counter10
        default: return ""
        }
    }
}

// MARK: - MacFlightRow init from FlightSector

extension MacFlightRow {
    init?(sector: FlightSector) {
        guard let parsedDate = sector.parsedDate else { return nil }

        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yyyy"
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.locale = Locale(identifier: "en_US_POSIX")

        id                 = sector.id
        rawDate            = parsedDate
        date               = sector.date
        flightNumber       = sector.flightNumber
        fromAirport        = sector.fromAirport
        toAirport          = sector.toAirport
        scheduledDeparture = sector.scheduledDeparture
        scheduledArrival   = sector.scheduledArrival
        outTime            = sector.outTime
        inTime             = sector.inTime
        captainName        = sector.captainName
        foName             = sector.foName
        so1Name            = sector.so1Name ?? ""
        so2Name            = sector.so2Name ?? ""
        aircraftType       = sector.aircraftType
        aircraftReg        = sector.aircraftReg
        remarks            = sector.remarks
        dayTakeoffs        = sector.dayTakeoffs
        nightTakeoffs      = sector.nightTakeoffs
        dayLandings        = sector.dayLandings
        nightLandings      = sector.nightLandings
        isPilotFlying      = sector.isPilotFlying
        isPositioning      = sector.isPositioning
        isILS              = sector.isILS
        isGLS              = sector.isGLS
        isNPA              = sector.isNPA
        isRNP              = sector.isRNP
        isAIII             = sector.isAIII

        counter1  = sector.counterEntries[1]  ?? ""
        counter2  = sector.counterEntries[2]  ?? ""
        counter3  = sector.counterEntries[3]  ?? ""
        counter4  = sector.counterEntries[4]  ?? ""
        counter5  = sector.counterEntries[5]  ?? ""
        counter6  = sector.counterEntries[6]  ?? ""
        counter7  = sector.counterEntries[7]  ?? ""
        counter8  = sector.counterEntries[8]  ?? ""
        counter9  = sector.counterEntries[9]  ?? ""
        counter10 = sector.counterEntries[10] ?? ""

        blockTime      = Double(sector.blockTime)      ?? 0
        nightTime      = Double(sector.nightTime)      ?? 0
        instrumentTime = Double(sector.instrumentTime) ?? 0
        p1Time         = Double(sector.p1Time)         ?? 0
        p1usTime       = Double(sector.p1usTime)       ?? 0
        p2Time         = Double(sector.p2Time)         ?? 0
        simTime        = Double(sector.simTime)        ?? 0
        spInsTime      = Double(sector.spInsTime)      ?? 0
    }
}

// MARK: - Mac Logbook ViewModel

@MainActor
final class MacLogbookViewModel: ObservableObject {

    // MARK: State
    @Published var displayedFlights: [MacFlightRow] = []
    @Published var allFlights: [MacFlightRow] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var saveVersion: Int = 0
    @Published var searchText = "" {
        didSet { applySort() }
    }

    private var flights: [MacFlightRow] = []
    private var filterState: MacFilterState?
    private var cancellables = Set<AnyCancellable>()

    func totalHours(countSim: Bool) -> Double {
        displayedFlights.reduce(0) { $0 + $1.blockTime + (countSim ? $1.simTime : 0) }
    }

    func applySort() {
        applyFilters(filterState)
    }

    func applyFilters(_ state: MacFilterState?) {
        filterState = state

        var base = flights

        if !searchText.isEmpty {
            base = base.filter { row in
                row.flightNumber.localizedCaseInsensitiveContains(searchText) ||
                row.fromAirport.localizedCaseInsensitiveContains(searchText) ||
                row.toAirport.localizedCaseInsensitiveContains(searchText) ||
                row.aircraftReg.localizedCaseInsensitiveContains(searchText) ||
                row.aircraftType.localizedCaseInsensitiveContains(searchText) ||
                row.captainName.localizedCaseInsensitiveContains(searchText) ||
                row.foName.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let f = state, f.isActive {
            let now = Date()
            let startDate: Date = {
                switch f.selectedDateRange {
                case .allFlights:      return .distantPast
                case .twelveMonths:    return Calendar.current.date(byAdding: .month, value: -12, to: now)!
                case .sixMonths:       return Calendar.current.date(byAdding: .month, value: -6,  to: now)!
                case .twentyEightDays: return Calendar.current.date(byAdding: .day,   value: -28, to: now)!
                case .custom:          return f.filterStartDate
                }
            }()
            let endDate: Date = f.selectedDateRange == .custom ? f.filterEndDate : now

            base = base.filter { row in
                if f.selectedDateRange != .allFlights {
                    guard row.rawDate >= startDate && row.rawDate <= endDate else { return false }
                }
                if !f.filterAircraftType.isEmpty {
                    guard row.aircraftType.localizedCaseInsensitiveContains(f.filterAircraftType) else { return false }
                }
                if !f.filterAircraftReg.isEmpty {
                    guard row.aircraftReg.localizedCaseInsensitiveContains(f.filterAircraftReg) else { return false }
                }
                if !f.filterCaptainName.isEmpty {
                    guard row.captainName.localizedCaseInsensitiveContains(f.filterCaptainName) else { return false }
                }
                if !f.filterFOName.isEmpty {
                    guard row.foName.localizedCaseInsensitiveContains(f.filterFOName) else { return false }
                }
                if !f.filterSOName.isEmpty {
                    guard row.so1Name.localizedCaseInsensitiveContains(f.filterSOName) ||
                          row.so2Name.localizedCaseInsensitiveContains(f.filterSOName) else { return false }
                }
                if !f.filterFromAirport.isEmpty {
                    guard row.fromAirport.localizedCaseInsensitiveContains(f.filterFromAirport) else { return false }
                }
                if !f.filterToAirport.isEmpty {
                    guard row.toAirport.localizedCaseInsensitiveContains(f.filterToAirport) else { return false }
                }
                if !f.filterFlightNumber.isEmpty {
                    guard row.flightNumber.localizedCaseInsensitiveContains(f.filterFlightNumber) else { return false }
                }
                if !f.filterKeywordSearch.isEmpty {
                    let kw = f.filterKeywordSearch
                    guard row.flightNumber.localizedCaseInsensitiveContains(kw) ||
                          row.aircraftType.localizedCaseInsensitiveContains(kw) ||
                          row.aircraftReg.localizedCaseInsensitiveContains(kw) ||
                          row.fromAirport.localizedCaseInsensitiveContains(kw) ||
                          row.toAirport.localizedCaseInsensitiveContains(kw) ||
                          row.captainName.localizedCaseInsensitiveContains(kw) ||
                          row.foName.localizedCaseInsensitiveContains(kw) ||
                          row.remarks.localizedCaseInsensitiveContains(kw) else { return false }
                }
                if f.filterPilotFlyingOnly  { guard row.isPilotFlying  else { return false } }
                if f.filterContainsRemarks  { guard !row.remarks.isEmpty else { return false } }
                if f.filterSimulator        { guard row.simTime > 0      else { return false } }
                if f.filterPositioning      { guard row.isPositioning    else { return false } }
                if f.filterSpIns            { guard row.spInsTime > 0    else { return false } }
                if f.filterTypeSummary      { guard row.flightNumber == "SUMMARY" else { return false } }
                if let approach = f.filterApproachType {
                    switch approach {
                    case "ILS":  guard row.isILS  else { return false }
                    case "GLS":  guard row.isGLS  else { return false }
                    case "NPA":  guard row.isNPA  else { return false }
                    case "RNP":  guard row.isRNP  else { return false }
                    case "AIII": guard row.isAIII else { return false }
                    default: break
                    }
                }
                if f.filterNoBlockTime    { guard row.blockTime == 0   else { return false } }
                if f.filterNoCrewNames    { guard row.captainName.isEmpty && row.foName.isEmpty else { return false } }
                if f.filterNoFlightNumber { guard row.flightNumber.isEmpty else { return false } }
                if f.filterNoAircraftType { guard row.aircraftType.isEmpty  else { return false } }
                if f.filterNoAircraftReg  { guard row.aircraftReg.isEmpty   else { return false } }

                return true
            }
        }

        let ascending = filterState?.sortOrderReversed ?? false
        displayedFlights = base.sorted {
            ascending ? $0.departureDatetime < $1.departureDatetime
                      : $0.departureDatetime > $1.departureDatetime
        }
    }

    // MARK: Load

    func load() async {
        isLoading = true
        isSyncing = true
        await reload()
        isLoading = false
        isSyncing = false

        NotificationCenter.default.addObserver(
            forName: .flightDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reload()
            }
        }

        FlightDatabaseService.shared.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncing in
                self?.isSyncing = syncing
            }
            .store(in: &cancellables)
    }

    func reload() async {
        let db = FlightDatabaseService.shared
        let sectors = db.fetchAllFlights()
        let rows = sectors.compactMap { MacFlightRow(sector: $0) }
        flights = rows
        allFlights = rows
        applySort()
        saveVersion += 1
    }

    // MARK: Save / Update / Delete

    func saveFlight(_ sector: MacEditableFlight) async -> Bool {
        let flightSector = sector.toFlightSector()
        let ok = FlightDatabaseService.shared.saveFlight(flightSector)
        if ok { await reload() }
        return ok
    }

    func updateFlight(_ sector: MacEditableFlight) async -> Bool {
        let flightSector = sector.toFlightSector()
        let ok = FlightDatabaseService.shared.updateFlight(flightSector)
        if ok { await reload() }
        return ok
    }

    func deleteFlight(id: UUID, undoManager: UndoManager? = nil) async -> Bool {
        guard let row = flights.first(where: { $0.id == id }) else { return false }
        let sector = MacEditableFlight(from: row).toFlightSector()
        let ok = FlightDatabaseService.shared.deleteFlight(sector)
        if ok {
            await reload()
            undoManager?.registerUndo(withTarget: self) { vm in
                Task { @MainActor in
                    _ = await vm.reinsertFlight(MacEditableFlight(from: row))
                }
            }
            undoManager?.setActionName("Delete Flight")
        }
        return ok
    }

    func reinsertFlight(_ sector: MacEditableFlight) async -> Bool {
        let flightSector = sector.toFlightSector()
        let ok = FlightDatabaseService.shared.saveFlight(flightSector)
        if ok { await reload() }
        return ok
    }

    // MARK: Aircraft CRUD

    func saveAircraft(_ aircraft: Aircraft) -> Bool {
        let ok = AircraftFleetService.shared.saveAircraft(aircraft)
        return ok
    }

    func deleteAircraft(_ aircraft: Aircraft) -> Bool {
        let ok = AircraftFleetService.shared.deleteAircraft(aircraft)
        return ok
    }

    func isCustomAircraft(_ aircraft: Aircraft) -> Bool {
        AircraftFleetService.shared.isCustomAircraft(aircraft)
    }

    // MARK: - Online Flight Search

    func searchFlight(flightNumber: String, date: String, airlinePrefix: String, includePrefix: Bool) async -> MacFlightSearchResult {
        guard !flightNumber.isEmpty else { return .error("Enter a flight number first") }
        guard !date.isEmpty else { return .error("Enter a flight date first") }

        guard let faCode = flightNumber.toFlightAwareFormat(userAirlinePrefix: includePrefix ? nil : airlinePrefix) else {
            return .error("Invalid flight number format")
        }

        let iataNumber = includePrefix ? flightNumber : airlinePrefix + flightNumber

        let faResults = await fetchFromFlightAware(code: faCode, date: date)

        let adbLocalDate: String
        if let first = faResults.first {
            adbLocalDate = AirportService.shared.convertToLocalDate(
                utcDateString: first.flightDate,
                utcTimeString: first.departureTime,
                airportICAO: first.origin
            )
        } else {
            adbLocalDate = date
        }

        let adbResults = await fetchFromAeroDataBox(flightNumber: iataNumber, localDate: adbLocalDate)
        let merged = mergeFlightResults(flightAware: faResults, aeroDataBox: adbResults)

        if merged.isEmpty { return .error("No flights found for this date") }
        if merged.count == 1 { return .single(merged[0]) }
        return .multiple(merged)
    }

    private func fetchFromFlightAware(code: String, date: String) async -> [FlightAwareData] {
        do {
            return try await FlightAwareService.shared.fetchFlightData(flightNumber: code, date: date)
        } catch {
            print("[MacSearch] FlightAware fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchFromAeroDataBox(flightNumber: String, localDate: String) async -> [FlightAwareData] {
        return await AeroDataBoxService.shared.fetchFlightData(flightNumber: flightNumber, localDepartureDate: localDate)
    }

    private func mergeFlightResults(flightAware: [FlightAwareData], aeroDataBox: [FlightAwareData]) -> [FlightAwareData] {
        if flightAware.isEmpty && aeroDataBox.isEmpty { return [] }
        if flightAware.isEmpty { return aeroDataBox }
        if aeroDataBox.isEmpty { return flightAware }

        var merged: [FlightAwareData] = []
        var matchedADB = Set<Int>()

        for fa in flightAware {
            if let adbIdx = aeroDataBox.firstIndex(where: { $0.origin == fa.origin && $0.destination == fa.destination }),
               !matchedADB.contains(adbIdx) {
                matchedADB.insert(adbIdx)
                merged.append(hybridMerge(flightAware: fa, aeroDataBox: aeroDataBox[adbIdx]))
            } else {
                merged.append(fa)
            }
        }
        for (idx, adb) in aeroDataBox.enumerated() where !matchedADB.contains(idx) {
            merged.append(adb)
        }
        return merged
    }

    private func hybridMerge(flightAware fa: FlightAwareData, aeroDataBox adb: FlightAwareData) -> FlightAwareData {
        var result = fa
        if adb.departureIsActual && !fa.departureIsActual {
            result.departureTime = adb.departureTime
            result.departureIsActual = true
        } else if adb.departureIsActual && fa.departureIsActual {
            result.departureTime = adb.departureTime
        }
        if adb.arrivalIsActual && !fa.arrivalIsActual {
            result.arrivalTime = adb.arrivalTime
            result.arrivalIsActual = true
        } else if adb.arrivalIsActual && fa.arrivalIsActual {
            result.arrivalTime = adb.arrivalTime
        }
        if result.scheduledDepartureTime == nil, let std = adb.scheduledDepartureTime { result.scheduledDepartureTime = std }
        if result.scheduledArrivalTime == nil, let sta = adb.scheduledArrivalTime { result.scheduledArrivalTime = sta }
        if result.aircraftRegistration == nil, let reg = adb.aircraftRegistration { result.aircraftRegistration = reg }
        return result
    }
}

// MARK: - MacEditableFlight
// Mutable form model used by the Add / Edit panel.

struct MacEditableFlight: Equatable {
    var id: UUID = UUID()
    var date: String = ""
    var flightNumber: String = ""
    var fromAirport: String = ""
    var toAirport: String = ""
    var scheduledDeparture: String = ""
    var scheduledArrival: String = ""
    var outTime: String = ""
    var inTime: String = ""
    var blockTime: String = ""
    var nightTime: String = ""
    var instrumentTime: String = ""
    var p1Time: String = ""
    var p1usTime: String = ""
    var p2Time: String = ""
    var simTime: String = ""
    var spInsTime: String = ""
    var aircraftType: String = ""
    var aircraftReg: String = ""
    var captainName: String = ""
    var foName: String = ""
    var so1Name: String = ""
    var so2Name: String = ""
    var remarks: String = ""
    var dayTakeoffs: Int = 0
    var nightTakeoffs: Int = 0
    var dayLandings: Int = 0
    var nightLandings: Int = 0
    var isPilotFlying: Bool = false
    var isPositioning: Bool = false
    var isILS: Bool = false
    var isGLS: Bool = false
    var isNPA: Bool = false
    var isRNP: Bool = false
    var isAIII: Bool = false
    var counter1: String = ""
    var counter2: String = ""
    var counter3: String = ""
    var counter4: String = ""
    var counter5: String = ""
    var counter6: String = ""
    var counter7: String = ""
    var counter8: String = ""
    var counter9: String = ""
    var counter10: String = ""

    func counterValue(_ idx: Int) -> String {
        switch idx {
        case 1:  return counter1
        case 2:  return counter2
        case 3:  return counter3
        case 4:  return counter4
        case 5:  return counter5
        case 6:  return counter6
        case 7:  return counter7
        case 8:  return counter8
        case 9:  return counter9
        case 10: return counter10
        default: return ""
        }
    }

    mutating func setCounter(_ idx: Int, value: String) {
        switch idx {
        case 1:  counter1  = value
        case 2:  counter2  = value
        case 3:  counter3  = value
        case 4:  counter4  = value
        case 5:  counter5  = value
        case 6:  counter6  = value
        case 7:  counter7  = value
        case 8:  counter8  = value
        case 9:  counter9  = value
        case 10: counter10 = value
        default: break
        }
    }

    static func empty() -> MacEditableFlight {
        var f = MacEditableFlight()
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yyyy"
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        f.date = fmt.string(from: Date())
        return f
    }

    init(from row: MacFlightRow, hhmm: Bool = false, rounding: String = "standard") {
        id                 = row.id
        date               = row.date
        flightNumber       = row.flightNumber
        fromAirport        = row.fromAirport
        toAirport          = row.toAirport
        scheduledDeparture = row.scheduledDeparture
        scheduledArrival   = row.scheduledArrival
        outTime            = row.outTime
        inTime             = row.inTime
        blockTime          = MacFlightRow.formatTime(row.blockTime,      hhmm: hhmm, rounding: rounding)
        nightTime          = MacFlightRow.formatTime(row.nightTime,      hhmm: hhmm, rounding: rounding)
        instrumentTime     = MacFlightRow.formatTime(row.instrumentTime, hhmm: hhmm, rounding: rounding)
        p1Time             = MacFlightRow.formatTime(row.p1Time,         hhmm: hhmm, rounding: rounding)
        p1usTime           = MacFlightRow.formatTime(row.p1usTime,       hhmm: hhmm, rounding: rounding)
        p2Time             = MacFlightRow.formatTime(row.p2Time,         hhmm: hhmm, rounding: rounding)
        simTime            = MacFlightRow.formatTime(row.simTime,        hhmm: hhmm, rounding: rounding)
        spInsTime          = MacFlightRow.formatTime(row.spInsTime,      hhmm: hhmm, rounding: rounding)
        aircraftType       = row.aircraftType
        aircraftReg        = row.aircraftReg
        captainName        = row.captainName
        foName             = row.foName
        so1Name            = row.so1Name
        so2Name            = row.so2Name
        remarks            = row.remarks
        dayTakeoffs        = row.dayTakeoffs
        nightTakeoffs      = row.nightTakeoffs
        dayLandings        = row.dayLandings
        nightLandings      = row.nightLandings
        isPilotFlying      = row.isPilotFlying
        isPositioning      = row.isPositioning
        isILS              = row.isILS
        isGLS              = row.isGLS
        isNPA              = row.isNPA
        isRNP              = row.isRNP
        isAIII             = row.isAIII
        counter1           = row.counter1
        counter2           = row.counter2
        counter3           = row.counter3
        counter4           = row.counter4
        counter5           = row.counter5
        counter6           = row.counter6
        counter7           = row.counter7
        counter8           = row.counter8
        counter9           = row.counter9
        counter10          = row.counter10
    }

    func toFlightSector() -> FlightSector {
        var counterEntries: [Int: String] = [:]
        for i in 1...10 {
            let v = counterValue(i)
            if !v.isEmpty { counterEntries[i] = v }
        }
        let decStr: (String) -> String = { raw in
            let v = MacFlightRow.parseTime(raw)
            return v > 0 ? String(format: "%.2f", v) : "0.00"
        }
        return FlightSector(
            id: id,
            date: date,
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: fromAirport,
            toAirport: toAirport,
            captainName: captainName,
            foName: foName,
            so1Name: so1Name.isEmpty ? nil : so1Name,
            so2Name: so2Name.isEmpty ? nil : so2Name,
            blockTime: decStr(blockTime),
            nightTime: decStr(nightTime),
            p1Time: decStr(p1Time),
            p1usTime: decStr(p1usTime),
            p2Time: decStr(p2Time),
            instrumentTime: decStr(instrumentTime),
            simTime: decStr(simTime),
            spInsTime: decStr(spInsTime),
            isPilotFlying: isPilotFlying,
            isPositioning: isPositioning,
            isAIII: isAIII,
            isRNP: isRNP,
            isILS: isILS,
            isGLS: isGLS,
            isNPA: isNPA,
            remarks: remarks,
            dayTakeoffs: dayTakeoffs,
            dayLandings: dayLandings,
            nightTakeoffs: nightTakeoffs,
            nightLandings: nightLandings,
            outTime: outTime,
            inTime: inTime,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival,
            counterEntries: counterEntries
        )
    }

    private init() {}
}

// MARK: - MacFlightSearchResult

enum MacFlightSearchResult {
    case single(FlightAwareData)
    case multiple([FlightAwareData])
    case error(String)
}
