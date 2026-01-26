import SwiftUI

// MARK: - Flight Sector Row Component
struct FlightSectorRow: View, Equatable {
    let sector: FlightSector
    var useLocalTime: Bool = false
    var useIATACodes: Bool = false
    var showTimesInHoursMinutes: Bool = false
    @Environment(\.colorScheme) var colorScheme

    // Cached computed values - initialized once
    @State private var cachedAirlineLogo: String?
    @State private var cachedFromAirportCode: String = ""
    @State private var cachedToAirportCode: String = ""
    @State private var cachedCrewNames: String = ""
    @State private var cachedIsFutureFlight: Bool = false
    @State private var cachedOutTime: String = ""
    @State private var cachedInTime: String = ""
    @State private var cachedDayOfMonth: String = ""
    @State private var cachedFormattedDate: String = ""
    @State private var cachedDisplayDate: String = ""

    // Equatable conformance for better SwiftUI diffing
    // Compare key fields that affect the display to detect changes
    static func == (lhs: FlightSectorRow, rhs: FlightSectorRow) -> Bool {
        return lhs.sector.id == rhs.sector.id &&
               lhs.sector.date == rhs.sector.date &&
               lhs.sector.flightNumber == rhs.sector.flightNumber &&
               lhs.sector.fromAirport == rhs.sector.fromAirport &&
               lhs.sector.toAirport == rhs.sector.toAirport &&
               lhs.sector.aircraftReg == rhs.sector.aircraftReg &&
               lhs.sector.aircraftType == rhs.sector.aircraftType &&
               lhs.sector.outTime == rhs.sector.outTime &&
               lhs.sector.inTime == rhs.sector.inTime &&
               lhs.sector.blockTime == rhs.sector.blockTime &&
               lhs.sector.simTime == rhs.sector.simTime &&
               lhs.sector.captainName == rhs.sector.captainName &&
               lhs.sector.foName == rhs.sector.foName &&
               lhs.sector.so1Name == rhs.sector.so1Name &&
               lhs.sector.so2Name == rhs.sector.so2Name &&
               lhs.sector.isPilotFlying == rhs.sector.isPilotFlying &&
               lhs.sector.isPositioning == rhs.sector.isPositioning &&
               lhs.useLocalTime == rhs.useLocalTime &&
               lhs.useIATACodes == rhs.useIATACodes &&
               lhs.showTimesInHoursMinutes == rhs.showTimesInHoursMinutes
    }

    // Cached date formatter - shared across all instances
    private static let cachedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC timezone to match AirportService
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    // Check if this is a rostered flight (not yet flown)
    private func calculateIsFutureFlight() -> Bool {
        // A flight is considered "rostered" if:
        // 1. It has no block time AND no sim time (not yet flown)
        // 2. For positioning (PAX) flights: un-dim when Out and In times are entered
        // 3. For regular flights: only un-dim when block/sim time is added (ignore date)
        let blockTime = sector.blockTimeValue
        let simTime = sector.simTimeValue

        // First check if it has been flown (has block or sim time)
        guard blockTime == 0 && simTime == 0 else {
            return false
        }

        // For positioning flights, un-dim when Out and In times are entered
        if sector.isPositioning {
            // Check if both Out and In times are present
            let hasOutTime = !sector.outTime.isEmpty
            let hasInTime = !sector.inTime.isEmpty

            // If both times are entered, un-dim the flight
            if hasOutTime && hasInTime {
                return false
            }

            // Otherwise, check if the date is in the future
            // Create a local formatter with appropriate timezone to avoid mutating the shared static formatter
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            dateFormatter.timeZone = useLocalTime ? TimeZone.current : TimeZone(secondsFromGMT: 0)
            dateFormatter.locale = Locale(identifier: "en_AU")
            guard let flightDate = dateFormatter.date(from: cachedDisplayDate) else {
                return false
            }

            // Get current date at midnight (start of day) for comparison
            let calendar = Calendar.current
            let now = Date()
            guard let todayMidnight = calendar.startOfDay(for: now) as Date? else {
                return false
            }

            // Flight is in the future if its date is after today
            return flightDate >= todayMidnight
        }

        // For regular flights, remain dimmed until block/sim time is added
        // (regardless of date)
        return true
    }

    // Check if this is a positioning flight
    private var isPositioning: Bool {
        return sector.isPositioning
    }

    // Cache expensive time conversions - computed once per render cycle
    private var outTime: String {
        return sector.getOutTime(useLocalTime: useLocalTime)
    }

    private var inTime: String {
        return sector.getInTime(useLocalTime: useLocalTime)
    }

    private var displayDate: String {
        return sector.getDisplayDate(useLocalTime: useLocalTime)
    }

    private var formattedDate: String {
        return sector.getFormattedDate(useLocalTime: useLocalTime)
    }

    private var dayOfMonth: String {
        return sector.getDayOfMonth(useLocalTime: useLocalTime)
    }

    // Calculate airline logo lookup
    private func calculateAirlineLogo() -> String? {
        let uppercased = sector.flightNumberFormatted.uppercased()
        for airline in Airline.airlines {
            if uppercased.hasPrefix(airline.prefix) && !airline.iconName.isEmpty {
                return airline.iconName
            }
        }
        return nil
    }

    // Calculate crew names formatting
    private func calculateCrewNames() -> String {
        var crew: [String] = []

        if !sector.captainName.isEmpty {
            crew.append(sector.captainName)
        }
        if !sector.foName.isEmpty {
            crew.append(sector.foName)
        }
        if let so1 = sector.so1Name, !so1.isEmpty {
            crew.append(so1)
        }
        if let so2 = sector.so2Name, !so2.isEmpty {
            crew.append(so2)
        }

        return crew.isEmpty ? "Self" : crew.joined(separator: ", ")
    }

    var body: some View {

        HStack(spacing: 0) {
            // Day and Date Column - CENTERED
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    Text(cachedDayOfMonth)
                        .font(.title.bold())
                        .foregroundColor(cachedIsFutureFlight ? .secondary : .blue.opacity(0.8))

                    Text(cachedFormattedDate)
                        .font(.subheadline.bold())
                        .foregroundColor(cachedIsFutureFlight ? .secondary : .primary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 50)
            .padding(.leading, 10)

            // Vertical divider
            Rectangle()
                .fill(cachedIsFutureFlight ? Color.secondary.opacity(0.5) : Color.blue.opacity(0.8))
                .frame(width: 2)
                .padding(.vertical, 8)
                .padding(.leading, 8)

            // Flight Details Column
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Airline logo if applicable
                    if let logo = cachedAirlineLogo {
                        Image(logo)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 15)
                            .opacity(cachedIsFutureFlight ? 0.5 : 1.0)
                    } else {
                        // Show "Sim" for simulator flights, "Flt" for regular flights
                        Text(sector.simTimeValue > 0 ? "Sim" : "Flt")
                            .font(.headline)
                            .foregroundColor(cachedIsFutureFlight ? .secondary : .primary)
                    }

                    //Flight Number
                    Text("\(sector.flightNumberFormatted)")
                        .font(.headline)
                        .foregroundColor(cachedIsFutureFlight ? .secondary : .primary)

                    Spacer()

                    // Route Details
                    Text(cachedFromAirportCode)
                        .font(.headline)
                        .foregroundColor(cachedIsFutureFlight ? .secondary : .blue.opacity(0.7))

                    Image(systemName: "airplane")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(cachedToAirportCode)
                        .font(.headline)
                        .foregroundColor(cachedIsFutureFlight ? .secondary : .blue.opacity(0.7))
                }

                // Rego
                HStack {
                    Text(sector.aircraftReg.isEmpty ? "" : "\(sector.aircraftReg)")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                        .italic(sector.aircraftReg.isEmpty)

                    // PAX Badge if Posiitoning Flight
                    if isPositioning {
                        HStack{
                        Text("PAX")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    
                    Spacer()

                    // OUT & IN Times
                    Text(cachedOutTime)
                        .font(.subheadline)
                        .foregroundColor(cachedIsFutureFlight ? .secondary : .primary)

                    // Show arrow if we have both times (actual or scheduled)
                    let hasOutTime = !sector.outTime.isEmpty || !sector.scheduledDeparture.isEmpty
                    let hasInTime = !sector.inTime.isEmpty || !sector.scheduledArrival.isEmpty
                    if hasOutTime && hasInTime {
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(cachedInTime)
                        .font(.subheadline)
                        .foregroundColor(cachedIsFutureFlight ? .secondary : .primary)
                }

                // Aircraft Type
                HStack{
                    if !isPositioning {
                        Text("\(sector.aircraftType)")
                            .font(.footnote.bold())
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Block Time - show blank for future flights instead of block time
                    if cachedIsFutureFlight {
                        Text("")
                            .font(.subheadline.italic())
                            .foregroundColor(.secondary)
                    } else if !isPositioning {
                        // Don't show flight hours or PF/PM badges for positioning flights
                        // For simulator flights, show sim time instead of block time
                        if sector.simTimeValue > 0 {
                            Text("\(sector.getFormattedSimTime(asHoursMinutes: showTimesInHoursMinutes))")
                                    .font(.headline.bold())
                                    .foregroundColor(.purple.opacity(0.8))
                        } else {
                            Text("\(sector.getFormattedBlockTime(asHoursMinutes: showTimesInHoursMinutes))")
                                    .font(.headline.bold())
                                    .foregroundColor(.orange.opacity(0.8))
                        }

                        // PF and PM Badges
                        if sector.isPilotFlying {
                            Text("PF")
                                .font(.subheadline.monospaced())
                                .foregroundColor(.green)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.green, lineWidth: 1)
                                )
                        } else {
                            Text("PM")
                                .font(.subheadline.monospaced())
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }

                
                // Crew Information
                if !isPositioning {
                    HStack {
                        Text(cachedCrewNames)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            //.foregroundColor(cachedIsFutureFlight ? .secondary : .primary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cachedIsFutureFlight ? .ultraThinMaterial : .regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    cachedIsFutureFlight
                        ? Color.primary.opacity(0.1)
                        : Color.primary.opacity(0.2),
                    lineWidth: 1
                )
        )
        .opacity(cachedIsFutureFlight ? 0.65 : 1.0)
        .onAppear {
            updateCachedValues()
        }
        .onChange(of: sector) { _, _ in
            updateCachedValues()
        }
    }

    // Helper function to update all cached values
    private func updateCachedValues() {
        cachedOutTime = sector.getOutTime(useLocalTime: useLocalTime)
        cachedInTime = sector.getInTime(useLocalTime: useLocalTime)
        cachedDisplayDate = sector.getDisplayDate(useLocalTime: useLocalTime)
        cachedFormattedDate = sector.getFormattedDate(useLocalTime: useLocalTime)
        cachedDayOfMonth = sector.getDayOfMonth(useLocalTime: useLocalTime)
        cachedAirlineLogo = calculateAirlineLogo()
        cachedFromAirportCode = AirportService.shared.getDisplayCode(sector.fromAirport, useIATA: useIATACodes)
        cachedToAirportCode = AirportService.shared.getDisplayCode(sector.toAirport, useIATA: useIATACodes)
        cachedCrewNames = calculateCrewNames()
        cachedIsFutureFlight = calculateIsFutureFlight()
    }
}

#Preview("FlightSectorRow") {
    VStack(spacing: 16) {
        // Standard flight
        FlightSectorRow(
            sector: FlightSector(
                date: "08/12/2025",
                flightNumber: "QF123",
                aircraftReg: "VH-ABC",
                aircraftType: "B738",
                fromAirport: "YSSY",
                toAirport: "YMML",
                captainName: "Smith",
                foName: "Jones",
                blockTime: "2.0",
                nightTime: "0.0",
                p1Time: "2.0",
                p1usTime: "0.0",
                instrumentTime: "0.0",
                simTime: "0.0",
                isPilotFlying: true,
                isPositioning: false,
                outTime: "0830",
                inTime: "1030"
            ),
            useLocalTime: false,
            useIATACodes: false,
            showTimesInHoursMinutes: false
        )
        .padding(.horizontal)

        // Positioning flight
        FlightSectorRow(
            sector: FlightSector(
                date: "09/12/2025",
                flightNumber: "QF456",
                aircraftReg: "",
                aircraftType: "B738",
                fromAirport: "YMML",
                toAirport: "YBBN",
                captainName: "",
                foName: "",
                blockTime: "0.0",
                nightTime: "0.0",
                p1Time: "0.0",
                p1usTime: "0.0",
                instrumentTime: "0.0",
                simTime: "0.0",
                isPilotFlying: false,
                isPositioning: true,
                outTime: "1400",
                inTime: "1545"
            ),
            useLocalTime: false,
            useIATACodes: false,
            showTimesInHoursMinutes: false
        )
        .padding(.horizontal)
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
