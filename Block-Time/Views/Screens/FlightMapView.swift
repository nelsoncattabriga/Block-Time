//
//  FlightMapView.swift
//  Block-Time
//

import SwiftUI
import MapKit

struct FlightMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = FlightMapViewModel()
    @AppStorage("flightMap_isHybrid") private var mapStyleIsHybrid = true

    var body: some View {
        NavigationStack {
            ZStack {
                MKMapRepresentable(
                    airports: viewModel.airports,
                    routes: viewModel.routes,
                    isHybrid: mapStyleIsHybrid,
                    onAirportTapped: { pin in
                        viewModel.selectedAirport = pin
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                if viewModel.isLoading {
                    ProgressView()
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(FlightMapViewModel.DateFilter.allCases) { filter in
                            Button {
                                viewModel.dateFilter = filter
                            } label: {
                                if viewModel.dateFilter == filter {
                                    Label(filter.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(filter.rawValue)
                                }
                            }
                        }
                    } label: {
                        Text(viewModel.dateFilter.rawValue)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mapStyleIsHybrid.toggle()
                    } label: {
                        Image(systemName: mapStyleIsHybrid ? "map" : "globe.americas.fill")
                    }
                }
            }
            .sheet(item: $viewModel.selectedAirport) { pin in
                MapSectorSheet(airport: pin)
            }
        }
        .task {
            await viewModel.loadFlights()
        }
        .onChange(of: viewModel.dateFilter) {
            Task { await viewModel.loadFlights() }
        }
    }
}

// MARK: - MKMapView Representable

private struct MKMapRepresentable: UIViewRepresentable {
    let airports: [FlightMapViewModel.AirportPin]
    let routes: [FlightMapViewModel.RouteSegment]
    let isHybrid: Bool
    let onAirportTapped: (FlightMapViewModel.AirportPin) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAirportTapped: onAirportTapped)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsCompass = true
        map.showsScale = true

        // Initial region: Australia + surrounds
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -25.0, longitude: 133.0),
            span: MKCoordinateSpan(latitudeDelta: 60.0, longitudeDelta: 60.0)
        )
        map.setRegion(region, animated: false)
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.mapType = isHybrid ? .hybrid : .standard

        // Update overlays if routes changed
        let currentRouteIDs = Set(context.coordinator.routeIndex.keys)
        let newRouteIDs = Set(routes.map(\.id))
        if currentRouteIDs != newRouteIDs {
            map.removeOverlays(map.overlays)
            context.coordinator.routeIndex = [:]
            for route in routes {
                let polyline = MKGeodesicPolyline(coordinates: route.coordinates, count: route.coordinates.count)
                context.coordinator.routeIndex[route.id] = polyline
                map.addOverlay(polyline, level: .aboveRoads)
            }
        }

        // Update annotations if airports changed
        let currentICAOs = Set(map.annotations.compactMap { ($0 as? AirportAnnotation)?.icao })
        let newICAOs = Set(airports.map(\.icao))
        if currentICAOs != newICAOs {
            map.removeAnnotations(map.annotations.filter { $0 is AirportAnnotation })
            let annotations = airports.map { pin -> AirportAnnotation in
                let a = AirportAnnotation()
                a.coordinate = pin.coordinate
                a.title = pin.id
                a.icao = pin.icao
                return a
            }
            map.addAnnotations(annotations)
        }

        context.coordinator.onAirportTapped = onAirportTapped
        context.coordinator.airports = airports
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onAirportTapped: (FlightMapViewModel.AirportPin) -> Void
        var airports: [FlightMapViewModel.AirportPin] = []
        var routeIndex: [String: MKGeodesicPolyline] = [:]

        init(onAirportTapped: @escaping (FlightMapViewModel.AirportPin) -> Void) {
            self.onAirportTapped = onAirportTapped
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: cluster) as! MKMarkerAnnotationView
                view.markerTintColor = .systemBlue
                view.glyphImage = UIImage(systemName: "airplane")
                return view
            }
            guard annotation is AirportAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier, for: annotation) as! MKMarkerAnnotationView
            view.markerTintColor = .systemBlue
            view.glyphImage = UIImage(systemName: "airplane")
            view.clusteringIdentifier = "airport"
            view.canShowCallout = false
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemGray.withAlphaComponent(0.65)
                renderer.lineWidth = 1.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)
            if let airport = annotation as? AirportAnnotation,
               let pin = airports.first(where: { $0.icao == airport.icao }) {
                onAirportTapped(pin)
            }
        }
    }
}

// MARK: - Annotation / Overlay subclasses

private final class AirportAnnotation: MKPointAnnotation {
    var icao: String = ""
}

#Preview {
    FlightMapView()
}
