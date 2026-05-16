// CoreDataFlightRepository.swift
// Production FlightRepository backed by NSPersistentCloudKitContainer (D-15).
// All methods @MainActor, use viewContext (D-16).
// Mapping via private static toDomain / apply (D-17).

import CoreData
import Foundation
import BlockTimeDomain
import BlockTimeData

@MainActor
final class CoreDataFlightRepository: FlightRepository, @unchecked Sendable {

    private let container: NSPersistentCloudKitContainer

    init(container: NSPersistentCloudKitContainer) {
        self.container = container
    }

    private var context: NSManagedObjectContext { container.viewContext }

    // MARK: - FlightRepository

    func fetchAll() async throws -> [Flight] {
        let request = Self.fetchRequest(sortedByDateDesc: true)
        return try context.fetch(request).map(Self.toDomain)
    }

    func fetchRecent(days: Int) async throws -> [Flight] {
        let cutoff = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let request = Self.fetchRequest(sortedByDateDesc: true)
        request.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
        return try context.fetch(request).map(Self.toDomain)
    }

    func fetch(from: Date, to: Date) async throws -> [Flight] {
        let request = Self.fetchRequest(sortedByDateDesc: true)
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@",
                                        from as NSDate, to as NSDate)
        return try context.fetch(request).map(Self.toDomain)
    }

    func insert(_ flight: Flight) async throws {
        let entity = FlightEntity(context: context)
        Self.apply(flight, to: entity)
        try context.save()
    }

    func update(_ flight: Flight) async throws {
        // D-20: upsert — if UUID not found, insert as new
        let request = Self.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", flight.id as CVarArg)
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first {
            Self.apply(flight, to: existing)
            existing.modifiedAt = Date()
        } else {
            let entity = FlightEntity(context: context)
            Self.apply(flight, to: entity)
        }
        try context.save()
    }

    func delete(id: UUID) async throws {
        let request = Self.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        for entity in try context.fetch(request) {
            context.delete(entity)
        }
        try context.save()
    }

    func deleteAll() async throws {
        // D-21: per-entity delete (NOT NSBatchDeleteRequest — bypasses CloudKit history)
        let request = Self.fetchRequest()
        for entity in try context.fetch(request) {
            context.delete(entity)
        }
        try context.save()
    }

    func count() async throws -> Int {
        try context.count(for: Self.fetchRequest())
    }

    func search(query: String) async throws -> [Flight] {
        // D-18: 8-field OR predicate with CONTAINS[cd]
        let fields = ["fromAirport", "toAirport", "flightNumber",
                      "aircraftReg", "aircraftType",
                      "captainName", "foName", "remarks"]
        let predicates = fields.map {
            NSPredicate(format: "%K CONTAINS[cd] %@", $0, query)
        }
        let request = Self.fetchRequest(sortedByDateDesc: true)
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return try context.fetch(request).map(Self.toDomain)
    }

    // MARK: - Private

    private static func fetchRequest(sortedByDateDesc: Bool = false) -> NSFetchRequest<FlightEntity> {
        let request = NSFetchRequest<FlightEntity>(entityName: "FlightEntity")
        if sortedByDateDesc {
            // D-19: date desc, then createdAt desc
            request.sortDescriptors = [
                NSSortDescriptor(key: "date", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
        }
        return request
    }

    // MARK: - Mapping (D-17)

    private static func toDomain(_ e: FlightEntity) -> Flight {
        Flight(
            id: e.id ?? UUID(),
            date: e.date ?? Date(),
            fromAirport: e.fromAirport ?? "",
            toAirport: e.toAirport ?? "",
            flightNumber: e.flightNumber ?? "",
            aircraftType: e.aircraftType ?? "",
            aircraftReg: e.aircraftReg ?? "",
            blockTime: Int(e.blockTime),
            simTime: Int(e.simTime),
            nightTime: Int(e.nightTime),
            p1Time: Int(e.p1Time),
            p1usTime: Int(e.p1usTime),
            p2Time: Int(e.p2Time),
            instrumentTime: Int(e.instrumentTime),
            spInsTime: Int(e.spInsTime),
            dualTime: Int(e.dualTime),
            outTime: e.outTime,
            inTime: e.inTime,
            scheduledDeparture: e.scheduledDeparture,
            scheduledArrival: e.scheduledArrival,
            dayTakeoffs: Int(e.dayTakeoffs),
            nightTakeoffs: Int(e.nightTakeoffs),
            dayLandings: Int(e.dayLandings),
            nightLandings: Int(e.nightLandings),
            customCount: Int(e.customCount),
            isPilotFlying: e.isPilotFlying,
            isPositioning: e.isPositioning,
            isILS: e.isILS,
            isGLS: e.isGLS,
            isRNP: e.isRNP,
            isNPA: e.isNPA,
            isAIII: e.isAIII,
            captainName: e.captainName ?? "",
            foName: e.foName ?? "",
            so1Name: e.so1Name ?? "",
            so2Name: e.so2Name ?? "",
            remarks: e.remarks ?? ""
        )
    }

    private static func apply(_ f: Flight, to e: FlightEntity) {
        e.id = f.id
        e.date = f.date
        e.fromAirport = f.fromAirport
        e.toAirport = f.toAirport
        e.flightNumber = f.flightNumber
        e.aircraftType = f.aircraftType
        e.aircraftReg = f.aircraftReg
        e.blockTime = Int16(min(f.blockTime, Int(Int16.max)))
        e.simTime = Int16(min(f.simTime, Int(Int16.max)))
        e.nightTime = Int16(min(f.nightTime, Int(Int16.max)))
        e.p1Time = Int16(min(f.p1Time, Int(Int16.max)))
        e.p1usTime = Int16(min(f.p1usTime, Int(Int16.max)))
        e.p2Time = Int16(min(f.p2Time, Int(Int16.max)))
        e.instrumentTime = Int16(min(f.instrumentTime, Int(Int16.max)))
        e.spInsTime = Int16(min(f.spInsTime, Int(Int16.max)))
        e.dualTime = Int16(min(f.dualTime, Int(Int16.max)))
        e.outTime = f.outTime
        e.inTime = f.inTime
        e.scheduledDeparture = f.scheduledDeparture
        e.scheduledArrival = f.scheduledArrival
        e.dayTakeoffs = Int16(f.dayTakeoffs)
        e.nightTakeoffs = Int16(f.nightTakeoffs)
        e.dayLandings = Int16(f.dayLandings)
        e.nightLandings = Int16(f.nightLandings)
        e.customCount = Int16(f.customCount)
        e.isPilotFlying = f.isPilotFlying
        e.isPositioning = f.isPositioning
        e.isILS = f.isILS
        e.isGLS = f.isGLS
        e.isRNP = f.isRNP
        e.isNPA = f.isNPA
        e.isAIII = f.isAIII
        e.captainName = f.captainName
        e.foName = f.foName
        e.so1Name = f.so1Name
        e.so2Name = f.so2Name
        e.remarks = f.remarks
        if e.createdAt == nil { e.createdAt = Date() }
    }
}
