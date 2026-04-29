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
    @State private var selectedICAO: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                map

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
        .onChange(of: selectedICAO) { _, icao in
            guard let icao,
                  let pin = viewModel.airports.first(where: { $0.icao == icao }) else { return }
            viewModel.selectedAirport = pin
            selectedICAO = nil  // reset so sheet can be reopened
        }
    }

    private static let australiaPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -25.0, longitude: 133.0),
            span: MKCoordinateSpan(latitudeDelta: 60.0, longitudeDelta: 60.0)
        )
    )

    private var map: some View {
        Map(initialPosition: Self.australiaPosition, selection: $selectedICAO) {
            ForEach(viewModel.routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(.gray.opacity(0.65), lineWidth: 1.5)
            }

            ForEach(viewModel.airports) { pin in
                Marker(pin.id, systemImage: "airplane", coordinate: pin.coordinate)
                    .tint(.blue)
                    .tag(pin.icao)
            }
        }
        .mapStyle(mapStyleIsHybrid ? .hybrid : .standard)
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    FlightMapView()
}
