import SwiftUI
import CoreData

// MARK: - Sectors View (Separate screen for flight sector rows)
struct SectorsView: View {
    private let databaseService = FlightDatabaseService.shared
    @State private var flightSectors: [FlightSector] = []
    @State private var hasLoadedFlights = false
    @State private var summaryToEdit: FlightSector?

    var body: some View {
        VStack(spacing: 0) {
            if flightSectors.isEmpty {
                EmptyLogbookView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(flightSectors, id: \.id) { sector in
                            if sector.flightNumber == "SUMMARY" {
                                // Summary entries use a tap gesture to show edit sheet
                                SummaryRow(sector: sector)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        HapticManager.shared.impact(.light)
                                        summaryToEdit = sector
                                    }
                            } else {
                                // Regular flights use NavigationLink
                                NavigationLink {
                                    FlightSectorEditScreen(
                                        sector: sector,
                                        onDelete: { sectorToDelete in
                                            deleteFlightSector(sectorToDelete)
                                        },
                                        onSave: { updated in
                                            updateFlightSector(updated)
                                        }
                                    )
                                } label: {
                                    FlightSectorRow(sector: sector)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("All Flights")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if !hasLoadedFlights {
                loadFlights()
                hasLoadedFlights = true
            }
        }
        .sheet(item: $summaryToEdit) { summary in
            AircraftSummarySheet(
                editingSector: summary,
                onSave: { updatedSummary in
                    saveSummary(updatedSummary)
                },
                onDelete: { summaryToDelete in
                    deleteSummary(summaryToDelete)
                }
            )
        }
    }

    private func loadFlights() {
        print("DEBUG: Loading flights from database in SectorsView")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.flightSectors = self.databaseService.fetchAllFlights()
            print("DEBUG: Loaded \(self.flightSectors.count) flights from database in SectorsView")
        }
    }

    private func deleteFlightSector(_ sector: FlightSector) {
        print("DEBUG: Attempting to delete sector \(sector.flightNumber) with ID \(sector.id)")

        if databaseService.deleteFlight(sector) {
            print("DEBUG: Delete successful, refreshing list")
            // Remove deleted sector immediately from the local list
            flightSectors.removeAll { $0.id == sector.id }
            loadFlights()
            hasLoadedFlights = true
        } else {
            print("DEBUG: Delete failed")
        }
    }

    private func updateFlightSector(_ updated: FlightSector) {
        if let index = flightSectors.firstIndex(where: { $0.id == updated.id }) {
            flightSectors[index] = updated
        } else {
            // Fallback: reload if the sector isn't in the current list
            loadFlights()
        }
    }

    private func saveSummary(_ summary: FlightSector) {
        // Check if this is an update or new entry
        let isUpdate = flightSectors.contains { $0.id == summary.id }

        if isUpdate {
            // Update existing summary
            if databaseService.updateFlight(summary) {
                // Update local state
                if let index = flightSectors.firstIndex(where: { $0.id == summary.id }) {
                    flightSectors[index] = summary
                }
                // Notify other views
                NotificationCenter.default.post(name: .flightDataChanged, object: nil)
            } else {
                HapticManager.shared.notification(.error)
            }
        } else {
            // Save new summary
            if databaseService.saveFlight(summary) {
                loadFlights()
                NotificationCenter.default.post(name: .flightDataChanged, object: nil)
            } else {
                HapticManager.shared.notification(.error)
            }
        }

        // Clear the editing state
        summaryToEdit = nil
    }

    private func deleteSummary(_ summary: FlightSector) {
        if databaseService.deleteFlight(summary) {
            // Remove from local state
            flightSectors.removeAll { $0.id == summary.id }
            // Notify other views
            NotificationCenter.default.post(name: .flightDataChanged, object: nil)
        } else {
            HapticManager.shared.notification(.error)
        }

        // Clear the editing state
        summaryToEdit = nil
    }
}
