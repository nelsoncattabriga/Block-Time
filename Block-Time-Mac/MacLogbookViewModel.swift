//
//  MacLogbookViewModel.swift
//  Block-Time-Mac
//
//  Self-contained Core Data + CloudKit stack for the Mac target.
//  Shares the same iCloud container as the iOS app so data syncs automatically.
//

import Foundation
import CoreData
import SwiftUI
import Combine

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
    var customCount: Int
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
            // UTC: rawDate is stored as midnight UTC so just decompose it
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
            let c = utcCal.dateComponents([.day, .month, .year], from: rawDate)
            guard let d = c.day, let m = c.month, let y = c.year,
                  m >= 1, m <= 12 else { return date }
            return String(format: "%d %@ %02d", d, monthAbbr[m - 1], y % 100)
        }

        // Local: combine rawDate with departure time (OUT preferred, fall back to STD)
        // to get the true UTC instant, then read the date in the airport's local timezone.
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

    func totalHours(countSim: Bool) -> Double {
        displayedFlights.reduce(0) { $0 + $1.blockTime + (countSim ? $1.simTime : 0) }
    }

    func applySort() {
        applyFilters(filterState)
    }

    func applyFilters(_ state: MacFilterState?) {
        filterState = state

        var base = flights

        // Search text
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
                case .allFlights:     return .distantPast
                case .twelveMonths:   return Calendar.current.date(byAdding: .month, value: -12, to: now)!
                case .sixMonths:      return Calendar.current.date(byAdding: .month, value: -6,  to: now)!
                case .twentyEightDays:return Calendar.current.date(byAdding: .day,   value: -28, to: now)!
                case .custom:         return f.filterStartDate
                }
            }()
            let endDate: Date = f.selectedDateRange == .custom ? f.filterEndDate : now

            base = base.filter { row in
                // Date range
                if f.selectedDateRange != .allFlights {
                    guard row.rawDate >= startDate && row.rawDate <= endDate else { return false }
                }
                // Aircraft
                if !f.filterAircraftType.isEmpty {
                    guard row.aircraftType.localizedCaseInsensitiveContains(f.filterAircraftType) else { return false }
                }
                if !f.filterAircraftReg.isEmpty {
                    guard row.aircraftReg.localizedCaseInsensitiveContains(f.filterAircraftReg) else { return false }
                }
                // Crew
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
                // Airports & flight number
                if !f.filterFromAirport.isEmpty {
                    guard row.fromAirport.localizedCaseInsensitiveContains(f.filterFromAirport) else { return false }
                }
                if !f.filterToAirport.isEmpty {
                    guard row.toAirport.localizedCaseInsensitiveContains(f.filterToAirport) else { return false }
                }
                if !f.filterFlightNumber.isEmpty {
                    guard row.flightNumber.localizedCaseInsensitiveContains(f.filterFlightNumber) else { return false }
                }
                // Keyword
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
                // Operation toggles
                if f.filterPilotFlyingOnly  { guard row.isPilotFlying  else { return false } }
                if f.filterContainsRemarks  { guard !row.remarks.isEmpty else { return false } }
                if f.filterSimulator        { guard row.simTime > 0      else { return false } }
                if f.filterPositioning      { guard row.isPositioning    else { return false } }
                if f.filterSpIns            { guard row.spInsTime > 0    else { return false } }
                if f.filterTypeSummary      { guard row.flightNumber == "SUMMARY" else { return false } }
                // Approach type
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
                // Missing data
                if f.filterNoBlockTime      { guard row.blockTime == 0   else { return false } }
                if f.filterNoCrewNames      { guard row.captainName.isEmpty && row.foName.isEmpty else { return false } }
                if f.filterNoFlightNumber   { guard row.flightNumber.isEmpty else { return false } }
                if f.filterNoAircraftType   { guard row.aircraftType.isEmpty  else { return false } }
                if f.filterNoAircraftReg    { guard row.aircraftReg.isEmpty   else { return false } }

                return true
            }
        }

        let ascending = filterState?.sortOrderReversed ?? false
        displayedFlights = base.sorted {
            ascending ? $0.departureDatetime < $1.departureDatetime
                      : $0.departureDatetime > $1.departureDatetime
        }
    }

    // MARK: Core Data

    private let persistentContainer: NSPersistentCloudKitContainer

    private var context: NSManagedObjectContext { persistentContainer.viewContext }

    init() {
        let container = NSPersistentCloudKitContainer(name: "FlightDataModel")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found.")
        }

        description.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber,
                              forKey: NSPersistentHistoryTrackingKey)

        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.thezoolab.blocktime"
        )

        container.loadPersistentStores { desc, error in
            if let error {
                print("[MacCoreData] Store load error: \(error)")
            } else {
                print("[MacCoreData] Store URL: \(desc.url?.absoluteString ?? "nil")")
                print("[MacCoreData] CloudKit container: \(desc.cloudKitContainerOptions?.containerIdentifier ?? "none")")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.persistentContainer = container
    }

    // MARK: Load

    func load() async {
        isLoading = true
        await reload()
        isLoading = false

        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reload()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            Task { @MainActor [weak self] in
                self?.handleCloudKitEvent(event)
            }
        }
    }

    private var syncSettleTask: Task<Void, Never>?

    @MainActor
    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        guard event.type == .import || event.type == .export else { return }
        let typeStr = event.type == .import ? "import" : "export"
        let phase   = event.endDate == nil ? "started" : "finished (error: \(event.error?.localizedDescription ?? "none"))"
        print("[MacCoreData] CloudKit \(typeStr) \(phase)")
        if event.endDate == nil {
            syncSettleTask?.cancel()
            isSyncing = true
        } else {
            syncSettleTask?.cancel()
            syncSettleTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await reload()
                isSyncing = false
            }
        }
    }

    func reload() async {
        let ctx = persistentContainer.viewContext
        // viewContext is main-queue — fetch directly since we're @MainActor
        let request = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        let rows = ((try? ctx.fetch(request)) ?? []).compactMap { MacFlightRow(entity: $0) }
        flights = rows
        allFlights = rows
        applySort()
        saveVersion += 1
    }

    // MARK: Save / Update / Delete

    func saveFlight(_ sector: MacEditableFlight) async -> Bool {
        let ctx = persistentContainer.viewContext
        let checkReq = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
        checkReq.predicate = NSPredicate(format: "id == %@", sector.id as CVarArg)
        checkReq.fetchLimit = 1
        guard (try? ctx.fetch(checkReq))?.isEmpty == true else { return false }

        let entity = NSEntityDescription.insertNewObject(forEntityName: "FlightEntity", into: ctx)
        applyFields(sector, to: entity, ctx: ctx, isNew: true)
        do {
            try ctx.save()
            print("[MacCoreData] Save succeeded for flight \(sector.id)")
            await reload()
            return true
        } catch {
            print("[MacCoreData] Save failed: \(error)")
            ctx.rollback()
            return false
        }
    }

    func updateFlight(_ sector: MacEditableFlight) async -> Bool {
        let ctx = persistentContainer.viewContext
        let req = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
        req.predicate = NSPredicate(format: "id == %@", sector.id as CVarArg)
        req.fetchLimit = 1
        guard let entity = (try? ctx.fetch(req))?.first else { return false }
        applyFields(sector, to: entity, ctx: ctx, isNew: false)
        do {
            try ctx.save()
            await reload()
            return true
        } catch {
            ctx.rollback()
            return false
        }
    }

    func deleteFlight(id: UUID) async -> Bool {
        let ctx = persistentContainer.viewContext
        let req = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        guard let entity = (try? ctx.fetch(req))?.first else { return false }
        ctx.delete(entity)
        do {
            try ctx.save()
            await reload()
            return true
        } catch {
            ctx.rollback()
            return false
        }
    }

    private nonisolated func applyFields(_ s: MacEditableFlight, to entity: NSManagedObject, ctx: NSManagedObjectContext, isNew: Bool) {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yyyy"
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.locale = Locale(identifier: "en_US_POSIX")

        if isNew {
            entity.setValue(s.id, forKey: "id")
            entity.setValue(Date(), forKey: "createdAt")
            print("[MacCoreData] Inserting new flight id=\(s.id) date=\(s.date) flt=\(s.flightNumber) \(s.fromAirport)-\(s.toAirport) block=\(s.blockTime)")
        } else {
            print("[MacCoreData] Updating flight id=\(s.id) date=\(s.date) flt=\(s.flightNumber)")
        }
        entity.setValue(fmt.date(from: s.date) ?? Date(), forKey: "date")
        entity.setValue(s.flightNumber,        forKey: "flightNumber")
        entity.setValue(s.fromAirport,         forKey: "fromAirport")
        entity.setValue(s.toAirport,           forKey: "toAirport")
        entity.setValue(s.scheduledDeparture,  forKey: "scheduledDeparture")
        entity.setValue(s.scheduledArrival,    forKey: "scheduledArrival")
        entity.setValue(s.outTime,             forKey: "outTime")
        entity.setValue(s.inTime,              forKey: "inTime")
        func decStr(_ raw: String) -> String? {
            let v = MacFlightRow.parseTime(raw)
            return v > 0 ? String(format: "%.2f", v) : nil
        }
        entity.setValue(decStr(s.blockTime),      forKey: "blockTime")
        entity.setValue(decStr(s.nightTime),      forKey: "nightTime")
        entity.setValue(decStr(s.instrumentTime), forKey: "instrumentTime")
        entity.setValue(decStr(s.p1Time),         forKey: "p1Time")
        entity.setValue(decStr(s.p1usTime),       forKey: "p1usTime")
        entity.setValue(decStr(s.p2Time),         forKey: "p2Time")
        entity.setValue(decStr(s.simTime),        forKey: "simTime")
        entity.setValue(decStr(s.spInsTime),      forKey: "spInsTime")
        entity.setValue(s.aircraftType,        forKey: "aircraftType")
        entity.setValue(s.aircraftReg,         forKey: "aircraftReg")
        entity.setValue(s.captainName,         forKey: "captainName")
        entity.setValue(s.foName,              forKey: "foName")
        entity.setValue(s.so1Name,             forKey: "so1Name")
        entity.setValue(s.so2Name,             forKey: "so2Name")
        entity.setValue(s.remarks,             forKey: "remarks")
        entity.setValue(Int16(s.dayTakeoffs),  forKey: "dayTakeoffs")
        entity.setValue(Int16(s.nightTakeoffs),forKey: "nightTakeoffs")
        entity.setValue(Int16(s.dayLandings),  forKey: "dayLandings")
        entity.setValue(Int16(s.nightLandings),forKey: "nightLandings")
        entity.setValue(s.isPilotFlying,       forKey: "isPilotFlying")
        entity.setValue(s.isPositioning,       forKey: "isPositioning")
        entity.setValue(s.isILS,               forKey: "isILS")
        entity.setValue(s.isGLS,               forKey: "isGLS")
        entity.setValue(s.isNPA,               forKey: "isNPA")
        entity.setValue(s.isRNP,               forKey: "isRNP")
        entity.setValue(s.isAIII,              forKey: "isAIII")
        entity.setValue(Int16(s.customCount),  forKey: "customCount")
        entity.setValue(Date(),                forKey: "modifiedAt")
    }

}

// MARK: - MacFlightRow init from NSManagedObject

private extension MacFlightRow {
    init?(entity: NSManagedObject) {
        guard let id   = entity.value(forKey: "id") as? UUID,
              let date = entity.value(forKey: "date") as? Date else { return nil }

        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yyyy"
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.locale = Locale(identifier: "en_US_POSIX")

        func str(_ key: String) -> String {
            entity.value(forKey: key) as? String ?? ""
        }
        func flag(_ key: String) -> Bool {
            entity.value(forKey: key) as? Bool ?? false
        }
        func parseTime(_ key: String) -> Double {
            Double(entity.value(forKey: key) as? String ?? "0") ?? 0
        }

        self.id                 = id
        self.rawDate            = date
        self.date               = fmt.string(from: date)
        self.flightNumber       = str("flightNumber")
        self.fromAirport        = str("fromAirport")
        self.toAirport          = str("toAirport")
        self.scheduledDeparture = str("scheduledDeparture")
        self.scheduledArrival   = str("scheduledArrival")
        self.outTime            = str("outTime")
        self.inTime             = str("inTime")
        self.captainName        = str("captainName")
        self.foName             = str("foName")
        self.so1Name            = str("so1Name")
        self.so2Name            = str("so2Name")
        self.aircraftType       = str("aircraftType")
        self.aircraftReg        = str("aircraftReg")
        self.remarks            = str("remarks")

        self.dayTakeoffs        = Int(entity.value(forKey: "dayTakeoffs") as? Int16 ?? 0)
        self.nightTakeoffs      = Int(entity.value(forKey: "nightTakeoffs") as? Int16 ?? 0)
        self.dayLandings        = Int(entity.value(forKey: "dayLandings") as? Int16 ?? 0)
        self.nightLandings      = Int(entity.value(forKey: "nightLandings") as? Int16 ?? 0)
        self.customCount        = Int(entity.value(forKey: "customCount") as? Int16 ?? 0)

        self.isPilotFlying      = flag("isPilotFlying")
        self.isPositioning      = flag("isPositioning")
        self.isILS              = flag("isILS")
        self.isGLS              = flag("isGLS")
        self.isNPA              = flag("isNPA")
        self.isRNP              = flag("isRNP")
        self.isAIII             = flag("isAIII")

        self.blockTime          = parseTime("blockTime")
        self.nightTime          = parseTime("nightTime")
        self.instrumentTime     = parseTime("instrumentTime")
        self.p1Time             = parseTime("p1Time")
        self.p1usTime           = parseTime("p1usTime")
        self.p2Time             = parseTime("p2Time")
        self.simTime            = parseTime("simTime")
        self.spInsTime          = parseTime("spInsTime")
    }
}

// MARK: - MacEditableFlight
// Mutable form model used by the Add / Edit panel. Mirrors FlightSector fields but is
// Mac-only and has no iOS dependencies.

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
    var customCount: Int = 0

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
        customCount        = row.customCount
    }

    private init() {}
}
