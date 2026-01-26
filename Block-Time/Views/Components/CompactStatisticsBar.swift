import SwiftUI

// MARK: - Compact Statistics Bar (Data on single row)
struct CompactStatisticsBar: View {
    let statistics: FlightStatistics

    var body: some View {
        HStack(spacing: 20) {
            CompactStatItem(
                title: "Total Hours",
                value: statistics.formattedBlockTime,
                color: .blue
            )

            Divider()
                .frame(height: 30)

            CompactStatItem(
                title: "PIC",
                value: statistics.formattedP1Time,
                color: .green
            )

            Divider()
                .frame(height: 30)

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )

    }
}
