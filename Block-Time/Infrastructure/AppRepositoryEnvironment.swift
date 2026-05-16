//
//  AppRepositoryEnvironment.swift
//  Block-Time
//
//  SwiftUI EnvironmentKey for injecting a FlightRepository (FOUND-12).
//  Default value is an empty InMemoryFlightRepository so previews don't need any setup.
//  Production sets this to a SwiftDataFlightRepository in Phase 3 when the UI is wired.
//
//  Plan 01-05
//

import SwiftUI
import BlockTimeData

private struct FlightRepositoryKey: EnvironmentKey {
    static let defaultValue: any FlightRepository = InMemoryFlightRepository()
}

extension EnvironmentValues {
    var flightRepository: any FlightRepository {
        get { self[FlightRepositoryKey.self] }
        set { self[FlightRepositoryKey.self] = newValue }
    }
}

extension View {
    /// Injects a FlightRepository into the SwiftUI environment.
    /// Production: `.flightRepository(SwiftDataFlightRepository(container: ...))` (Phase 3)
    /// Previews:   `.flightRepository(InMemoryFlightRepository(seed: [...]))`
    func flightRepository(_ repo: any FlightRepository) -> some View {
        environment(\.flightRepository, repo)
    }
}
