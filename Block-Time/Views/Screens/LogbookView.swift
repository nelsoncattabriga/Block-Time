import SwiftUI

// MARK: - Logbook View
struct LogbookView: View {
    private let databaseService = FlightDatabaseService.shared
    @State private var flightStatistics = FlightStatistics.empty
    @State private var isLoading = true
    @State private var showingSettings = false
    @State private var isEditMode = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading statistics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            FlightStatisticsSection(statistics: flightStatistics, isEditMode: .constant(false))
                            LogbookNavigationSection(statistics: flightStatistics)
                            Spacer(minLength: 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            LogbookSettingsView()
        }
        .onAppear {
            loadStatistics()
        }
    }

    private func loadStatistics() {
        isLoading = true
        //print("DEBUG: Loading statistics from database")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.flightStatistics = self.databaseService.getFlightStatistics()
          //  print("DEBUG: Loaded statistics from database")
            self.isLoading = false
        }
    }

    /// Public method to add new flight from ACARS capture
    func addFlightFromACARSCapture(
        date: String,
        flightNumber: String,
        aircraftReg: String,
        fromAirport: String,
        toAirport: String,
        captainName: String,
        foName: String,
        blockTime: String,
        p1Time: String,
        p1usTime: String,
        isPilotFlying: Bool,
        isAIII: Bool
    ) {
        let newSector = FlightSector.fromACARSCapture(
            date: date,
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            fromAirport: fromAirport,
            toAirport: toAirport,
            captainName: captainName,
            foName: foName,
            blockTime: blockTime,
            p1Time: p1Time,
            p1usTime: p1usTime,
            isPilotFlying: isPilotFlying,
            isAIII: isAIII
        )

        if databaseService.saveFlight(newSector) {
            loadStatistics()
        }
    }
}
