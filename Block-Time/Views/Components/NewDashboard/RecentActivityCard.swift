import SwiftUI

// MARK: - Recent Activity Card (configurable days)
struct RecentActivityCard: View {
    let statistics: FlightStatistics
    let days: Int
    let cardKey: String
    @State private var recentHours: Double = 0.0
    @State private var recentSectors: Int = 0
    @State private var showingConfig = false
    @State private var inputMaxHours: String = ""
    @State private var settings = LogbookSettings.shared
    @State private var showTimesInHoursMinutes: Bool = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")

    // Convenience initializer with default 7 days for backward compatibility
    init(statistics: FlightStatistics, days: Int = 7, maxHours: Double? = nil) {
        self.statistics = statistics
        self.days = days
        self.cardKey = "recentActivity\(days)"
    }

    private var maxHours: Double? {
        let configured = settings.maxHoursConfig[cardKey] ?? 0
        return configured > 0 ? configured : nil
    }

    private var hoursProgress: Double {
        guard let max = maxHours, max > 0 else { return 0 }
        return min(recentHours / max, 1.0)
    }

    private var progressColor: Color {
        guard let _ = maxHours else { return .orange }
        if hoursProgress >= 0.90 {
            return .red
        } else if hoursProgress >= 0.80 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "\(days) Day\(days == 1 ? "" : "s")", icon: "calendar", iconColor: progressColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {

                    // Format hours based on user preference
                    Text(showTimesInHoursMinutes ? FlightSector.decimalToHHMM(recentHours) : String(format: "%.1f hrs", recentHours))
                        .iPadScaledFont(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)


                    if let max = maxHours {
                        Text(" / \(String(format: "%.0f", max))")
                            .iPadScaledFont(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "pencil")
                        .iPadScaledFont(.caption)
                        .foregroundColor(.secondary)
                }

                if maxHours != nil {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)

                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * hoursProgress, height: 6)
                        }
                    }
                    .frame(height: 6)
                } else {
                    // Spacer to match progress bar height
                    Spacer()
                        .frame(height: 6)
                }

                Text("\(recentSectors) sector\(recentSectors == 1 ? "" : "s")")
                    .iPadScaledFont(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .appCardStyle()
        .onTapGesture {
            let currentMax = settings.maxHoursConfig[cardKey] ?? 0
            inputMaxHours = currentMax > 0 ? String(Int(currentMax)) : ""
            showingConfig = true
        }
        .alert("Maximum Hours", isPresented: $showingConfig) {
            TextField("Max Hours (0 = No Limit)", text: $inputMaxHours)
                .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad)

            Button("Save") {
                if let value = Double(inputMaxHours) {
                    settings.setMaxHours(for: cardKey, value: value)
                } else {
                    settings.setMaxHours(for: cardKey, value: 0)
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Set max hours for \(days) days.").multilineTextAlignment(.center)
        }
        .onAppear {
            loadRecentActivity()
        }
        .onChange(of: days) {
            loadRecentActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            showTimesInHoursMinutes = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
        }
    }

    private func loadRecentActivity() {
        // Use device local timezone for user-facing date ranges
        let calendar = Calendar.current  // Device timezone (local)
        let now = Date()

        // Calculate range: all of today back to (today - days + 1) days ago
        // e.g., Last 28 Days = today (Dec 19) back to Nov 21 (28 days total including today)
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
        let startOfPeriod = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now))!

        // Format dates for database query using local timezone to match Logbook filter
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone.current  // Use local timezone to match filter behavior

        let startDate = formatter.string(from: startOfPeriod)
        let endDate = formatter.string(from: endOfToday)

        // DEBUG: Log the date range
        //LogManager.shared.info("Dashboard \(days)-day period: \(startDate) to \(endDate) (local TZ)")

        let recentStats = FlightDatabaseService.shared.getFlightStatistics(from: startDate, to: endDate)

        //LogManager.shared.info("Dashboard \(days)-day flight time: \(recentStats.totalFlightTime) hrs, sectors: \(recentStats.totalSectors)")

        self.recentHours = recentStats.totalFlightTime
        self.recentSectors = recentStats.totalSectors
    }
}
