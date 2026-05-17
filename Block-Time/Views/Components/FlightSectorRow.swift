import SwiftUI

// MARK: - Flight Sector Row Component
struct FlightSectorRow: View, Equatable {
    let sector: FlightSector
    var useLocalTime: Bool = false
    var useIATACodes: Bool = false
    var showTimesInHoursMinutes: Bool = false
    var roundingMode: RoundingMode = .standard
    @AppStorage("showOutInTimes") private var showOutInTimes: Bool = true
    @AppStorage("includeAirlinePrefixInFlightNumber") private var includeAirlinePrefixInFlightNumber: Bool = true
    @AppStorage("isCustomAirlinePrefix") private var isCustomAirlinePrefix: Bool = false
    @Environment(\.colorScheme) var colorScheme

    // Display values computed once at init
    private let cachedFromAirportCode: String
    private let cachedToAirportCode: String
    private let cachedCrewNames: String
    private let cachedIsFutureFlight: Bool
    private let cachedOutTime: String
    private let cachedInTime: String
    private let cachedDayOfMonth: String
    private let cachedFormattedDate: String
    private let cachedDisplayDate: String

    init(
        sector: FlightSector,
        useLocalTime: Bool = false,
        useIATACodes: Bool = false,
        showTimesInHoursMinutes: Bool = false,
        roundingMode: RoundingMode = .standard
    ) {
        self.sector = sector
        self.useLocalTime = useLocalTime
        self.useIATACodes = useIATACodes
        self.showTimesInHoursMinutes = showTimesInHoursMinutes
        self.roundingMode = roundingMode

        // Compute display values once — avoids onAppear two-render flash
        let displayDate = sector.getDisplayDate(useLocalTime: useLocalTime)
        cachedOutTime = sector.getOutTime(useLocalTime: useLocalTime)
        cachedInTime = sector.getInTime(useLocalTime: useLocalTime)
        cachedDisplayDate = displayDate
        cachedFormattedDate = sector.getFormattedDate(useLocalTime: useLocalTime)
        cachedDayOfMonth = sector.getDayOfMonth(useLocalTime: useLocalTime)
        cachedFromAirportCode = AirportService.shared.getDisplayCode(sector.fromAirport, useIATA: useIATACodes)
        cachedToAirportCode = AirportService.shared.getDisplayCode(sector.toAirport, useIATA: useIATACodes)

        // Crew names
        var crew: [String] = []
        if !sector.captainName.isEmpty { crew.append(sector.captainName) }
        if !sector.foName.isEmpty { crew.append(sector.foName) }
        if let so1 = sector.so1Name, !so1.isEmpty { crew.append(so1) }
        if let so2 = sector.so2Name, !so2.isEmpty { crew.append(so2) }
        cachedCrewNames = crew.isEmpty ? "Self" : crew.joined(separator: ", ")

        // Future flight flag (depends on displayDate computed above)
        let blockTime = sector.blockTimeValue
        let simTime = sector.simTimeValue
        if blockTime != 0 || simTime != 0 || sector.spInsTimeValue != 0 {
            cachedIsFutureFlight = false
        } else if sector.isPositioning {
            let hasOutTime = !sector.outTime.isEmpty
            let hasInTime = !sector.inTime.isEmpty
            if hasOutTime && hasInTime {
                cachedIsFutureFlight = false
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                dateFormatter.timeZone = useLocalTime ? TimeZone.current : TimeZone(secondsFromGMT: 0)
                dateFormatter.locale = Locale(identifier: "en_AU")
                if let flightDate = dateFormatter.date(from: displayDate) {
                    let todayMidnight = Calendar.current.startOfDay(for: Date())
                    cachedIsFutureFlight = flightDate >= todayMidnight
                } else {
                    cachedIsFutureFlight = false
                }
            }
        } else {
            cachedIsFutureFlight = true
        }
    }

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
               lhs.sector.spInsTime == rhs.sector.spInsTime &&
               lhs.useLocalTime == rhs.useLocalTime &&
               lhs.useIATACodes == rhs.useIATACodes &&
               lhs.showTimesInHoursMinutes == rhs.showTimesInHoursMinutes &&
               lhs.roundingMode == rhs.roundingMode
    }

    // Check if this is a positioning flight
    private var isPositioning: Bool {
        return sector.isPositioning
    }

    // Computed logo based on @AppStorage properties — reacts to setting changes
    private var airlineLogo: String? {
        guard includeAirlinePrefixInFlightNumber && !isCustomAirlinePrefix else { return nil }
        let uppercased = sector.flightNumberFormatted.uppercased()
        return Airline.airlines.first(where: {
            !$0.iconName.isEmpty && uppercased.hasPrefix($0.prefix)
        })?.iconName
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
                    if let logo = airlineLogo {
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

                    // PAX / INS badge
                    if isPositioning {
                        Text("PAX")
                            .font(.subheadline.monospaced())
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                    } else if !cachedIsFutureFlight && (sector.isSpInsOnly || sector.isAircraftInstruction) {
                        Text("INS")
                            .font(.subheadline.monospaced())
                            .foregroundColor(AppColors.insColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AppColors.insColor, lineWidth: 1)
                            )
                    }

                    Spacer()

                    // Route Details
                    Text(cachedFromAirportCode)
                        .font(.headline)
                        .foregroundColor(cachedIsFutureFlight ? .secondary : .blue.opacity(0.7))

                    // Only show airplane icon if not a SIM flight, or if SIM flight has airports
                    if sector.simTimeValue == 0 || (!sector.fromAirport.isEmpty && !sector.toAirport.isEmpty) {
                        Image(systemName: "airplane")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

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

                    Spacer()

                    // OUT & IN Times
                    if showOutInTimes {
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
                        // For Sp/Ins flights show spInsTime in pink, sim in purple, block in orange
                        if sector.isSpInsOnly {
                            Text(sector.getFormattedSpInsTime(asHoursMinutes: showTimesInHoursMinutes))
                                .font(.headline.bold())
                                .foregroundColor(AppColors.insColor.opacity(0.8))
                        } else if sector.simTimeValue > 0 {
                            Text("\(sector.getFormattedSimTime(asHoursMinutes: showTimesInHoursMinutes))")
                                .font(.headline.bold())
                                .foregroundColor(.purple.opacity(0.8))
                        } else {
                            Text("\(sector.getFormattedBlockTime(asHoursMinutes: showTimesInHoursMinutes, roundingMode: roundingMode))")
                                .font(.headline.bold())
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }

                    // PF / PM badge (invisible spacer for INS/SIM to keep time column aligned)
                    if !cachedIsFutureFlight && !isPositioning {
                        if sector.isSpInsOnly || sector.simTimeValue > 0 {
                            Text("PF")
                                .font(.subheadline.monospaced())
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.clear, lineWidth: 1)
                                )
                                .opacity(0)
                        } else if sector.isPilotFlying {
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
