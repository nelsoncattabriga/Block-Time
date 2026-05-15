import Foundation
import BlockTimeDomain

/// Repository abstraction for flight data access.
/// Lives in BlockTimeData per D-02.
/// All implementations (SwiftData production, InMemory for tests/previews) conform to this protocol.
/// No SwiftData import — protocol is persistence-agnostic.
public protocol FlightRepository: Sendable {
    func fetchAll() async throws -> [Flight]
    func fetchRecent(days: Int) async throws -> [Flight]
    func fetch(from: Date, to: Date) async throws -> [Flight]
    func insert(_ flight: Flight) async throws
    func update(_ flight: Flight) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
    func count() async throws -> Int
    func search(query: String) async throws -> [Flight]
}
