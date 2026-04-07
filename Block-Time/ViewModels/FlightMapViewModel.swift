//
//  FlightMapViewModel.swift
//  Block-Time
//

import Foundation
import MapKit
import CoreData

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
        case all       = "All Time"
        case last90    = "Last 90 Days"
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

    private let context = FlightDatabaseService.shared.viewContext
    private var useIATACodes: Bool {
        UserDefaults.standard.bool(forKey: "useIATACodes")
    }

    // MARK: - Load

    func loadFlights() async {
        isLoading = true
        defer { isLoading = false }

        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.predicate = buildPredicate()

        guard let results = try? context.fetch(request) else { return }
        let flights = results.compactMap { FlightSector.from(entity: $0) }.filter { $0.blockTimeValue > 0 }

        var seenAirports: [String: AirportPin] = [:]   // keyed by ICAO
        var seenRoutes: Set<String> = []
        var newRoutes: [RouteSegment] = []

        for flight in flights {
            let fromCode = flight.fromAirport
            let toCode   = flight.toAirport
            guard !fromCode.isEmpty, !toCode.isEmpty else { continue }

            let fromICAO = AirportService.shared.convertToICAO(fromCode)
            let toICAO   = AirportService.shared.convertToICAO(toCode)

            guard let fromCoords = AirportService.shared.getCoordinates(for: fromICAO),
                  let toCoords   = AirportService.shared.getCoordinates(for: toICAO) else { continue }

            // Airport pins
            if seenAirports[fromICAO] == nil {
                seenAirports[fromICAO] = AirportPin(
                    id: AirportService.shared.getDisplayCode(fromICAO, useIATA: useIATACodes),
                    icao: fromICAO,
                    coordinate: CLLocationCoordinate2D(latitude: fromCoords.latitude, longitude: fromCoords.longitude)
                )
            }
            if seenAirports[toICAO] == nil {
                seenAirports[toICAO] = AirportPin(
                    id: AirportService.shared.getDisplayCode(toICAO, useIATA: useIATACodes),
                    icao: toICAO,
                    coordinate: CLLocationCoordinate2D(latitude: toCoords.latitude, longitude: toCoords.longitude)
                )
            }

            // Deduplicated route — treat A→B and B→A as different routes
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

        airports = Array(seenAirports.values)
        routes = newRoutes
    }

    // MARK: - Helpers

    private func buildPredicate() -> NSPredicate? {
        switch dateFilter {
        case .all:
            return nil
        case .last90:
            let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            return NSPredicate(format: "date >= %@", cutoff as NSDate)
        case .last12:
            let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
            return NSPredicate(format: "date >= %@", cutoff as NSDate)
        }
    }


}
