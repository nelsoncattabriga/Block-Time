import Foundation
import BlockTimeDomain
import Observation

/// In-memory implementation of FlightRepository.
/// For use in SwiftUI previews and XCTest unit tests only.
/// Not for production use — data is not persisted to disk.
///
/// Note on @unchecked Sendable:
/// @Observable introduces non-Sendable storage tracking internals, but FlightRepository
/// requires Sendable conformance so the protocol can be stored in @Environment and
/// passed across actor boundaries. This in-memory implementation accesses storage
/// only from callers that manage their own concurrency (tests run serially; previews
/// are single-actor). @unchecked Sendable is the documented workaround for this pattern.
/// Do not promote to production code without adding actor isolation.
@Observable
public final class InMemoryFlightRepository: FlightRepository, @unchecked Sendable {

    private var storage: [UUID: Flight] = [:]

    public init(seed: [Flight] = []) {
        for flight in seed {
            storage[flight.id] = flight
        }
    }

    // MARK: - FlightRepository

    public func fetchAll() async throws -> [Flight] {
        Array(storage.values).sorted { $0.date > $1.date }
    }

    public func fetchRecent(days: Int) async throws -> [Flight] {
        let cutoff = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return Array(storage.values)
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
    }

    public func fetch(from: Date, to: Date) async throws -> [Flight] {
        Array(storage.values)
            .filter { $0.date >= from && $0.date <= to }
            .sorted { $0.date > $1.date }
    }

    public func insert(_ flight: Flight) async throws {
        storage[flight.id] = flight
    }

    public func update(_ flight: Flight) async throws {
        storage[flight.id] = flight
    }

    public func delete(id: UUID) async throws {
        storage.removeValue(forKey: id)
    }

    public func deleteAll() async throws {
        storage.removeAll()
    }

    public func count() async throws -> Int {
        storage.count
    }

    public func search(query: String) async throws -> [Flight] {
        let q = query.lowercased()
        return Array(storage.values)
            .filter {
                $0.fromAirport.lowercased().contains(q) ||
                $0.toAirport.lowercased().contains(q) ||
                $0.flightNumber.lowercased().contains(q)
            }
            .sorted { $0.date > $1.date }
    }
}
