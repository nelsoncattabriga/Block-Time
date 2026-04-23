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

    // MARK: Formatted display helpers

    var dateDisplay: String {
        // dd/MM/yyyy → "16 Apr 26"
        let parts = date.split(separator: "/")
        guard parts.count == 3,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let year = Int(parts[2]) else { return date }
        let monthAbbr = ["Jan","Feb","Mar","Apr","May","Jun",
                         "Jul","Aug","Sep","Oct","Nov","Dec"]
        guard month >= 1, month <= 12 else { return date }
        let yy = year % 100
        return String(format: "%d %@ %02d", day, monthAbbr[month - 1], yy)
    }

    static func hhmmDisplay(_ decimal: Double) -> String {
        guard decimal > 0 else { return "" }
        let totalMinutes = Int((decimal * 60).rounded())
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    var blockDisplay:      String { Self.hhmmDisplay(blockTime) }
    var nightDisplay:      String { Self.hhmmDisplay(nightTime) }
    var instrumentDisplay: String { Self.hhmmDisplay(instrumentTime) }
    var p1Display:         String { Self.hhmmDisplay(p1Time) }
    var p1usDisplay:       String { Self.hhmmDisplay(p1usTime) }
    var p2Display:         String { Self.hhmmDisplay(p2Time) }
    var simDisplay:        String { Self.hhmmDisplay(simTime) }
    var spInsDisplay:      String { Self.hhmmDisplay(spInsTime) }
}

// MARK: - Mac Logbook ViewModel

@MainActor
final class MacLogbookViewModel: ObservableObject {

    // MARK: State
    @Published var displayedFlights: [MacFlightRow] = []
    @Published var allFlights: [MacFlightRow] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var searchText = "" {
        didSet { applySort() }
    }

    private var flights: [MacFlightRow] = []
    private var filterState: MacFilterState?

    var totalBlockHours: Double {
        displayedFlights.reduce(0) { $0 + $1.blockTime }
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
        displayedFlights = base.sorted { ascending ? $0.rawDate < $1.rawDate : $0.rawDate > $1.rawDate }
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

        if FileManager.default.ubiquityIdentityToken != nil {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.thezoolab.blocktime"
            )
        } else {
            description.cloudKitContainerOptions = nil
        }

        container.loadPersistentStores { _, error in
            if let error {
                print("Mac Core Data load error: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        self.persistentContainer = container
    }

    // MARK: Load

    func load() async {
        isLoading = true
        let container = persistentContainer
        let rows = await Task.detached(priority: .userInitiated) {
            Self.fetchRows(from: container)
        }.value
        flights = rows
        allFlights = rows
        applySort()
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
        if event.endDate == nil {
            syncSettleTask?.cancel()
            isSyncing = true
        } else {
            syncSettleTask?.cancel()
            syncSettleTask = Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                isSyncing = false
            }
        }
    }

    func reload() async {
        let container = persistentContainer
        let rows = await Task.detached(priority: .userInitiated) {
            Self.fetchRows(from: container)
        }.value
        flights = rows
        allFlights = rows
        applySort()
    }

    // MARK: Save / Update / Delete

    func saveFlight(_ sector: MacEditableFlight) -> Bool {
        var success = false
        let ctx = persistentContainer.viewContext
        ctx.performAndWait {
            let checkReq = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
            checkReq.predicate = NSPredicate(format: "id == %@", sector.id as CVarArg)
            checkReq.fetchLimit = 1
            guard (try? ctx.fetch(checkReq))?.isEmpty == true else { return }

            let entity = NSEntityDescription.insertNewObject(forEntityName: "FlightEntity", into: ctx)
            applyFields(sector, to: entity, ctx: ctx, isNew: true)
            do {
                try ctx.save()
                success = true
            } catch {
                ctx.rollback()
            }
        }
        if success { Task { await reload() } }
        return success
    }

    func updateFlight(_ sector: MacEditableFlight) -> Bool {
        var success = false
        let ctx = persistentContainer.viewContext
        ctx.performAndWait {
            let req = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
            req.predicate = NSPredicate(format: "id == %@", sector.id as CVarArg)
            req.fetchLimit = 1
            guard let entity = (try? ctx.fetch(req))?.first else { return }
            applyFields(sector, to: entity, ctx: ctx, isNew: false)
            do {
                try ctx.save()
                success = true
            } catch {
                ctx.rollback()
            }
        }
        if success { Task { await reload() } }
        return success
    }

    func deleteFlight(id: UUID) -> Bool {
        var success = false
        let ctx = persistentContainer.viewContext
        ctx.performAndWait {
            let req = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            guard let entity = (try? ctx.fetch(req))?.first else { return }
            ctx.delete(entity)
            do {
                try ctx.save()
                success = true
            } catch {
                ctx.rollback()
            }
        }
        if success { Task { await reload() } }
        return success
    }

    private func applyFields(_ s: MacEditableFlight, to entity: NSManagedObject, ctx: NSManagedObjectContext, isNew: Bool) {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yyyy"
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.locale = Locale(identifier: "en_US_POSIX")

        if isNew {
            entity.setValue(s.id, forKey: "id")
            entity.setValue(Date(), forKey: "createdAt")
        }
        entity.setValue(fmt.date(from: s.date) ?? Date(), forKey: "date")
        entity.setValue(s.flightNumber,        forKey: "flightNumber")
        entity.setValue(s.fromAirport,         forKey: "fromAirport")
        entity.setValue(s.toAirport,           forKey: "toAirport")
        entity.setValue(s.scheduledDeparture,  forKey: "scheduledDeparture")
        entity.setValue(s.scheduledArrival,    forKey: "scheduledArrival")
        entity.setValue(s.outTime,             forKey: "outTime")
        entity.setValue(s.inTime,              forKey: "inTime")
        entity.setValue(s.blockTime,           forKey: "blockTime")
        entity.setValue(s.nightTime,           forKey: "nightTime")
        entity.setValue(s.instrumentTime,      forKey: "instrumentTime")
        entity.setValue(s.p1Time,              forKey: "p1Time")
        entity.setValue(s.p1usTime,            forKey: "p1usTime")
        entity.setValue(s.p2Time,              forKey: "p2Time")
        entity.setValue(s.simTime,             forKey: "simTime")
        let spIns = s.spInsTime.isEmpty || s.spInsTime == "0.00" ? nil : s.spInsTime
        entity.setValue(spIns,                 forKey: "spInsTime")
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

    // MARK: Fetch (background)

    private nonisolated static func fetchRows(from container: NSPersistentCloudKitContainer) -> [MacFlightRow] {
        var rows: [MacFlightRow] = []
        let ctx = container.newBackgroundContext()
        ctx.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            guard let entities = try? ctx.fetch(request) else { return }
            rows = entities.compactMap { MacFlightRow(entity: $0) }
        }
        return rows
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

struct MacEditableFlight {
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

    init(from row: MacFlightRow) {
        id                 = row.id
        date               = row.date
        flightNumber       = row.flightNumber
        fromAirport        = row.fromAirport
        toAirport          = row.toAirport
        scheduledDeparture = row.scheduledDeparture
        scheduledArrival   = row.scheduledArrival
        outTime            = row.outTime
        inTime             = row.inTime
        blockTime          = row.blockTime > 0 ? String(format: "%.2f", row.blockTime) : ""
        nightTime          = row.nightTime > 0 ? String(format: "%.2f", row.nightTime) : ""
        instrumentTime     = row.instrumentTime > 0 ? String(format: "%.2f", row.instrumentTime) : ""
        p1Time             = row.p1Time > 0 ? String(format: "%.2f", row.p1Time) : ""
        p1usTime           = row.p1usTime > 0 ? String(format: "%.2f", row.p1usTime) : ""
        p2Time             = row.p2Time > 0 ? String(format: "%.2f", row.p2Time) : ""
        simTime            = row.simTime > 0 ? String(format: "%.2f", row.simTime) : ""
        spInsTime          = row.spInsTime > 0 ? String(format: "%.2f", row.spInsTime) : ""
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
