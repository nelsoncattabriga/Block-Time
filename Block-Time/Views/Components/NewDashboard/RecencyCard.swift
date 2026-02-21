import SwiftUI

// MARK: - Enhanced Recency Card (supports both PF and AIII)
struct RecencyCard: View {
    let statistics: FlightStatistics
    let recencyType: RecencyType
    let recencyDays: Int
    let title: String?

    @State private var recencyStatus: (daysRemaining: Int, color: Color, expiryDate: Date?) = (0, .primary, nil)
    @State private var currentStatistics: FlightStatistics

    enum RecencyType {
        case pf
        case aiii
        case takeoff
        case landing
    }

    init(statistics: FlightStatistics, recencyType: RecencyType, recencyDays: Int? = nil, title: String? = nil) {
        self.statistics = statistics
        self.recencyType = recencyType
        self.title = title
        self._currentStatistics = State(initialValue: statistics)

        // Set default recency days based on type
        switch recencyType {
        case .pf:
            self.recencyDays = recencyDays ?? 45
        case .aiii:
            self.recencyDays = recencyDays ?? 90
        case .takeoff:
            self.recencyDays = recencyDays ?? 45
        case .landing:
            self.recencyDays = recencyDays ?? 45
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: displayTitle, icon: "calendar.badge.clock") {
                Image(systemName: statusIcon)
                    .foregroundStyle(recencyStatus.color)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(recencyStatus.daysRemaining) day\(recencyStatus.daysRemaining == 1 ? "" : "s")")
                    .iPadScaledFont(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    //.foregroundColor(recencyStatus.color)

                // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .frame(height: 6)
                                .opacity(0.3)
                                .foregroundColor(recencyStatus.color)

                            RoundedRectangle(cornerRadius: 4)
                                .frame(width: min(CGFloat(recencyStatus.daysRemaining) / CGFloat(recencyDays) * geometry.size.width, geometry.size.width), height: 4)
                                .foregroundColor(recencyStatus.color)
                        }
                        .cornerRadius(2)
                    }
                    .frame(height: 6)

                Text(expirationDate)
                    .iPadScaledFont(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .appCardStyle()
        .onAppear {
            updateRecencyStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
            // Refresh statistics from database
            currentStatistics = FlightDatabaseService.shared.getFlightStatistics()
            updateRecencyStatus()
        }
    }

    private var displayTitle: String {
        if let title = title {
            return title
        }
        switch recencyType {
        case .pf:
            return "PF Recency"
        case .aiii:
            return "AIII Recency"
        case .takeoff:
            return "T/O Recency"
        case .landing:
            return "LDG Recency"
        }
    }

    private var expirationDate: String {
        if let expiryDate = recencyStatus.expiryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "Expires: \(formatter.string(from: expiryDate))"
        }
        return "Expires: N/A"
    }

    private var statusIcon: String {
        switch recencyStatus.daysRemaining {
        case 0...3:
            return "xmark.circle.badge.airplane.fill"
        case 4...7:
            return "xmark.circle.badge.airplane"
        default:
            return "checkmark.circle.badge.airplane"
        }
    }

    private func updateRecencyStatus() {
        switch recencyType {
        case .pf:
            recencyStatus = currentStatistics.pfRecencyStatus(recencyDays: recencyDays)
        case .aiii:
            recencyStatus = currentStatistics.aiiiRecencyStatus(recencyDays: recencyDays)
        case .takeoff:
            recencyStatus = currentStatistics.takeoffRecencyStatus(recencyDays: recencyDays)
        case .landing:
            recencyStatus = currentStatistics.landingRecencyStatus(recencyDays: recencyDays)
        }
    }
}

