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

    enum RowAccent { case none, pax, sim, spIns }
    var accent: RowAccent {
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
    @Published var isLoading = false
    @Published var searchText = "" {
        didSet { applySort() }
    }

    private var flights: [MacFlightRow] = []

    var totalBlockHours: Double {
        flights.reduce(0) { $0 + $1.blockTime }
    }

    func applySort() {
        let base = searchText.isEmpty ? flights : flights.filter { row in
            row.flightNumber.localizedCaseInsensitiveContains(searchText) ||
            row.fromAirport.localizedCaseInsensitiveContains(searchText) ||
            row.toAirport.localizedCaseInsensitiveContains(searchText) ||
            row.aircraftReg.localizedCaseInsensitiveContains(searchText) ||
            row.aircraftType.localizedCaseInsensitiveContains(searchText) ||
            row.captainName.localizedCaseInsensitiveContains(searchText) ||
            row.foName.localizedCaseInsensitiveContains(searchText)
        }
        displayedFlights = base.sorted { $0.rawDate > $1.rawDate }
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
    }

    func reload() async {
        let container = persistentContainer
        let rows = await Task.detached(priority: .userInitiated) {
            Self.fetchRows(from: container)
        }.value
        flights = rows
        applySort()
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
