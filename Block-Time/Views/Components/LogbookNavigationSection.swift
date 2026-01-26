import SwiftUI

// MARK: - Logbook Navigation Section
struct LogbookNavigationSection: View {
    let statistics: FlightStatistics

    var body: some View {
        VStack(spacing: 16) {

            // Navigation Cards
            VStack(spacing: 16) {
                NavigationLink(destination: SectorsView()) {
                    LogbookNavigationCard(
                        title: "Flights",
                        subtitle: "\(statistics.totalSectors) Sectors",
                        icon: "airplane.ticket",
                        color: .blue
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
    }
}
