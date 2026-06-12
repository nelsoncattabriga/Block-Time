//
//  FlightMapViewModel.swift
//  Block-Time
//

import Foundation
import MapKit
import CoreData
import BlockTimeKit

@Observable
@MainActor
final class FlightMapViewModel {

    // MARK: - Types

    struct AirportPin: Identifiable {
        let id: String                          // display code (IATA or ICAO per user pref)
        let icao: String                        // always ICAO, for coordinate lookup
        let coordinate: CLLocationCoordinate2D
    }

    struct RouteSegment: Identifiable {
        let id: String                          // e.g. "YSSY-YMML"
        let coordinates: [CLLocationCoordinate2D]
    }

    enum DateFilter: String, CaseIterable, Identifiable {
        case all       = "All Flights"
        case last90    = "Last Month"
        case last12    = "Last 12 Months"

        var id: String { rawValue }
    }

    // MARK: - Published state

    var airports: [AirportPin] = []
    var routes: [RouteSegment] = []
    var selectedAirport: AirportPin? = nil
    var dateFilter: DateFilter = .all
    var isLoading = false

    // MARK: - Private

    private var useIATACodes: Bool {
        UserDefaults.standard.bool(forKey: "useIATACodes")
    }

    // MARK: - Load

    func loadFlights() async {
        isLoading = true
        defer { isLoading = false }

        let cutoffDate = buildCutoffDate()   // Date? is Sendable
        let useIATA = useIATACodes
        let container = FlightDatabaseService.shared.persistentContainer
        let airportService = AirportService.shared   // capture instance; class is @unchecked Sendable

        let (newAirports, newRoutes) = await buildMapData(
            container: container,
            cutoffDate: cutoffDate,
            useIATA: useIATA,
            airportService: airportService
        )

        airports = newAirports
        routes = newRoutes
    }

    // Nonisolated — runs off the main actor.
    // NSPredicate is rebuilt inside bgContext.perform to avoid Sendable issues.
    // AirportService instance is passed in (captured on main actor before this call).
    private nonisolated func buildMapData(
        container: NSPersistentCloudKitContainer,
        cutoffDate: Date?,
        useIATA: Bool,
        airportService: AirportService
    ) async -> ([AirportPin], [RouteSegment]) {
        let pairs: [(from: String, to: String, blockTime: String)] = await withCheckedContinuation { continuation in
            let bgContext = container.newBackgroundContext()
            bgContext.perform {
                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                if let cutoff = cutoffDate {
                    request.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
                }
                request.propertiesToFetch = ["fromAirport", "toAirport", "blockTime"]
                let results = (try? bgContext.fetch(request)) ?? []
                let extracted = results.map { entity in
                    (
                        from:      entity.fromAirport ?? "",
                        to:        entity.toAirport   ?? "",
                        blockTime: entity.blockTime   ?? ""
                    )
                }
                continuation.resume(returning: extracted)
            }
        }

        var seenAirports: [String: AirportPin] = [:]
        var seenRoutes: Set<String> = []
        var newRoutes: [RouteSegment] = []

        for pair in pairs {
            guard !pair.from.isEmpty, !pair.to.isEmpty else { continue }

            guard let btValue = Double(pair.blockTime), btValue > 0 else { continue }

            let fromICAO = airportService.convertToICAO(pair.from)
            let toICAO   = airportService.convertToICAO(pair.to)

            guard let fromCoords = airportService.getCoordinates(for: fromICAO),
                  let toCoords   = airportService.getCoordinates(for: toICAO) else { continue }

            if seenAirports[fromICAO] == nil {
                seenAirports[fromICAO] = AirportPin(
                    id: airportService.getDisplayCode(fromICAO, useIATA: useIATA),
                    icao: fromICAO,
                    coordinate: CLLocationCoordinate2D(latitude: fromCoords.latitude, longitude: fromCoords.longitude)
                )
            }
            if seenAirports[toICAO] == nil {
                seenAirports[toICAO] = AirportPin(
                    id: airportService.getDisplayCode(toICAO, useIATA: useIATA),
                    icao: toICAO,
                    coordinate: CLLocationCoordinate2D(latitude: toCoords.latitude, longitude: toCoords.longitude)
                )
            }

            let routeKey = "\(fromICAO)-\(toICAO)"
            guard !seenRoutes.contains(routeKey) else { continue }
            seenRoutes.insert(routeKey)

            newRoutes.append(RouteSegment(
                id: routeKey,
                coordinates: [
                    CLLocationCoordinate2D(latitude: fromCoords.latitude, longitude: fromCoords.longitude),
                    CLLocationCoordinate2D(latitude: toCoords.latitude, longitude: toCoords.longitude)
                ]
            ))
        }

        return (Array(seenAirports.values), newRoutes)
    }

    // MARK: - Helpers

    private func buildCutoffDate() -> Date? {
        switch dateFilter {
        case .all:    return nil
        case .last90: return Calendar.current.date(byAdding: .month, value: -1,  to: Date())
        case .last12: return Calendar.current.date(byAdding: .month, value: -12, to: Date())
        }
    }


}
