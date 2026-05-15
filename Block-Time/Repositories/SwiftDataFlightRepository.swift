import Foundation
import SwiftData
import BlockTimeDomain
import BlockTimeData

/// Production FlightRepository implementation backed by SwiftData (FOUND-05).
/// Maps between BlockTimeDomain.Flight (value type) and FlightModel (@Model class).
/// Lives in app target per D-05 (@Model cannot live in Swift Package).
final class SwiftDataFlightRepository: FlightRepository, @unchecked Sendable {

    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    @MainActor
    private var context: ModelContext { container.mainContext }

    // MARK: - FlightRepository

    @MainActor
    func fetchAll() async throws -> [Flight] {
        let descriptor = FetchDescriptor<FlightModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor).map(Self.toDomain)
    }

    @MainActor
    func fetchRecent(days: Int) async throws -> [Flight] {
        let cutoff = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let descriptor = FetchDescriptor<FlightModel>(
            predicate: #Predicate { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor).map(Self.toDomain)
    }

    @MainActor
    func fetch(from: Date, to: Date) async throws -> [Flight] {
        let descriptor = FetchDescriptor<FlightModel>(
            predicate: #Predicate { $0.date >= from && $0.date <= to },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor).map(Self.toDomain)
    }

    @MainActor
    func insert(_ flight: Flight) async throws {
        let model = FlightModel()
        Self.apply(flight, to: model)
        context.insert(model)
        try context.save()
    }

    @MainActor
    func update(_ flight: Flight) async throws {
        let id = flight.id
        let descriptor = FetchDescriptor<FlightModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            Self.apply(flight, to: existing)
            existing.modifiedAt = Date()
        } else {
            let model = FlightModel()
            Self.apply(flight, to: model)
            context.insert(model)
        }
        try context.save()
    }

    @MainActor
    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<FlightModel>(
            predicate: #Predicate { $0.id == id }
        )
        for model in try context.fetch(descriptor) {
            context.delete(model)
        }
        try context.save()
    }

    @MainActor
    func deleteAll() async throws {
        try context.delete(model: FlightModel.self)
        try context.save()
    }

    @MainActor
    func count() async throws -> Int {
        try context.fetchCount(FetchDescriptor<FlightModel>())
    }

    @MainActor
    func search(query: String) async throws -> [Flight] {
        let q = query.lowercased()
        let descriptor = FetchDescriptor<FlightModel>()
        return try context.fetch(descriptor)
            .filter {
                $0.fromAirport.lowercased().contains(q) ||
                $0.toAirport.lowercased().contains(q) ||
                $0.flightNumber.lowercased().contains(q)
            }
            .map(Self.toDomain)
    }

    // MARK: - Mapping (Flight ↔ FlightModel)

    private static func toDomain(_ m: FlightModel) -> Flight {
        Flight(
            id: m.id,
            date: m.date,
            fromAirport: m.fromAirport,
            toAirport: m.toAirport,
            flightNumber: m.flightNumber,
            aircraftType: m.aircraftType,
            aircraftReg: m.aircraftReg,
            blockTime: m.blockTime,
            simTime: m.simTime,
            nightTime: m.nightTime,
            p1Time: m.p1Time,
            p1usTime: m.p1usTime,
            p2Time: m.p2Time,
            instrumentTime: m.instrumentTime,
            spInsTime: m.spInsTime,
            outTimeSeconds: m.outTimeSeconds,
            inTimeSeconds: m.inTimeSeconds,
            dayTakeoffs: m.dayTakeoffs,
            nightTakeoffs: m.nightTakeoffs,
            dayLandings: m.dayLandings,
            nightLandings: m.nightLandings,
            isPilotFlying: m.isPilotFlying,
            isPositioning: m.isPositioning,
            isILS: m.isILS,
            isGLS: m.isGLS,
            isRNP: m.isRNP,
            isNPA: m.isNPA,
            isAIII: m.isAIII,
            captainName: m.captainName,
            foName: m.foName,
            remarks: m.remarks
        )
    }

    private static func apply(_ f: Flight, to m: FlightModel) {
        m.id = f.id
        m.date = f.date
        m.fromAirport = f.fromAirport
        m.toAirport = f.toAirport
        m.flightNumber = f.flightNumber
        m.aircraftType = f.aircraftType
        m.aircraftReg = f.aircraftReg
        m.blockTime = f.blockTime
        m.simTime = f.simTime
        m.nightTime = f.nightTime
        m.p1Time = f.p1Time
        m.p1usTime = f.p1usTime
        m.p2Time = f.p2Time
        m.instrumentTime = f.instrumentTime
        m.spInsTime = f.spInsTime
        m.outTimeSeconds = f.outTimeSeconds
        m.inTimeSeconds = f.inTimeSeconds
        m.dayTakeoffs = f.dayTakeoffs
        m.nightTakeoffs = f.nightTakeoffs
        m.dayLandings = f.dayLandings
        m.nightLandings = f.nightLandings
        m.isPilotFlying = f.isPilotFlying
        m.isPositioning = f.isPositioning
        m.isILS = f.isILS
        m.isGLS = f.isGLS
        m.isRNP = f.isRNP
        m.isNPA = f.isNPA
        m.isAIII = f.isAIII
        m.captainName = f.captainName
        m.foName = f.foName
        m.remarks = f.remarks
    }
}
