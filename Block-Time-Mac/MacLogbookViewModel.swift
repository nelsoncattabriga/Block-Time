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
    var rawDate: Date         // actual Date for sorting
    var date: String          // dd/MM/yyyy for display
    var flightNumber: String
    var fromAirport: String
    var toAirport: String
    var outTime: String       // HH:MM or ""
    var inTime: String        // HH:MM or ""
    var blockTime: Double     // decimal hours
    var nightTime: Double
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
    var captainName: String
    var foName: String
    var isPositioning: Bool
    var remarks: String

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

    var blockDisplay:  String { Self.hhmmDisplay(blockTime) }
    var nightDisplay:  String { Self.hhmmDisplay(nightTime) }
    var p1Display:     String { Self.hhmmDisplay(p1Time) }
    var p1usDisplay:   String { Self.hhmmDisplay(p1usTime) }
    var p2Display:     String { Self.hhmmDisplay(p2Time) }
    var simDisplay:    String { Self.hhmmDisplay(simTime) }
}

// MARK: - Mac Logbook ViewModel

@Observable
@MainActor
final class MacLogbookViewModel {

    // MARK: State
    var flights: [MacFlightRow] = []
    var isLoading = false
    var searchText = ""
    var sortOrder: [KeyPathComparator<MacFlightRow>] = [
        KeyPathComparator(\.rawDate, order: .reverse)
    ]

    // MARK: Computed

    var filteredFlights: [MacFlightRow] {
        let base = searchText.isEmpty ? flights : flights.filter { row in
            row.flightNumber.localizedCaseInsensitiveContains(searchText) ||
            row.fromAirport.localizedCaseInsensitiveContains(searchText) ||
            row.toAirport.localizedCaseInsensitiveContains(searchText) ||
            row.aircraftReg.localizedCaseInsensitiveContains(searchText) ||
            row.aircraftType.localizedCaseInsensitiveContains(searchText) ||
            row.captainName.localizedCaseInsensitiveContains(searchText) ||
            row.foName.localizedCaseInsensitiveContains(searchText)
        }
        return base.sorted(using: sortOrder)
    }

    var totalBlockHours: Double {
        flights.reduce(0) { $0 + $1.blockTime }
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
    }

    // MARK: Fetch (background)

    private nonisolated static func fetchRows(from container: NSPersistentCloudKitContainer) -> [MacFlightRow] {
        var rows: [MacFlightRow] = []
        let ctx = container.newBackgroundContext()
        ctx.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "FlightEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.predicate = NSPredicate(
                format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR " +
                        "(simTime != %@ AND simTime != %@ AND simTime != %@) OR " +
                        "isPositioning == YES",
                "0", "0.0", "0.00",
                "0", "0.0", "0.00"
            )
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

        self.id            = id
        self.rawDate       = date
        self.date          = fmt.string(from: date)
        self.flightNumber  = entity.value(forKey: "flightNumber") as? String ?? ""
        self.fromAirport   = entity.value(forKey: "fromAirport") as? String ?? ""
        self.toAirport     = entity.value(forKey: "toAirport") as? String ?? ""
        self.outTime       = entity.value(forKey: "outTime") as? String ?? ""
        self.inTime        = entity.value(forKey: "inTime") as? String ?? ""
        self.aircraftType  = entity.value(forKey: "aircraftType") as? String ?? ""
        self.aircraftReg   = entity.value(forKey: "aircraftReg") as? String ?? ""
        self.captainName   = entity.value(forKey: "captainName") as? String ?? ""
        self.foName        = entity.value(forKey: "foName") as? String ?? ""
        self.isPositioning = entity.value(forKey: "isPositioning") as? Bool ?? false
        self.remarks       = entity.value(forKey: "remarks") as? String ?? ""

        self.dayTakeoffs   = Int(entity.value(forKey: "dayTakeoffs") as? Int16 ?? 0)
        self.nightTakeoffs = Int(entity.value(forKey: "nightTakeoffs") as? Int16 ?? 0)
        self.dayLandings   = Int(entity.value(forKey: "dayLandings") as? Int16 ?? 0)
        self.nightLandings = Int(entity.value(forKey: "nightLandings") as? Int16 ?? 0)

        func parseTime(_ key: String) -> Double {
            let raw = entity.value(forKey: key) as? String ?? "0"
            return Double(raw) ?? 0
        }

        self.blockTime  = parseTime("blockTime")
        self.nightTime  = parseTime("nightTime")
        self.p1Time     = parseTime("p1Time")
        self.p1usTime   = parseTime("p1usTime")
        self.p2Time     = parseTime("p2Time")
        self.simTime    = parseTime("simTime")
        self.spInsTime  = parseTime("spInsTime")
    }
}
