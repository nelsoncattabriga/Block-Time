import SwiftUI

// MARK: - FlightAware Helper
extension String {
    /// Converts airline code to FlightAware format (e.g., QF -> QFA)
    static func toFlightAwareAirlineCode(_ code: String) -> String {
        let airlineMappings: [String: String] = [
            "QF": "QFA",
            "QFA": "QFA",  // Already in FlightAware format
            "VA": "VOZ",
            "VOZ": "VOZ",
            "JQ": "JST",
            "JST": "JST",
            "NZ": "ANZ",
            "ANZ": "ANZ",
            "SQ": "SIA",
            "SIA": "SIA",
            "BA": "BAW",
            "BAW": "BAW",
            "QR": "QTR",
            "QTR": "QTR",
            "EK": "UAE",
            "UAE": "UAE",
            "TG": "THA",
            "THA": "THA",
            // Add more mappings as needed
        ]

        return airlineMappings[code.uppercased()] ?? code.uppercased()
    }

    /// Converts a flight number to FlightAware URL format
    /// Handles various formats:
    /// - "QF933" or "QFA933" -> "QFA933"
    /// - "933" (with userAirlinePrefix "QF") -> "QFA933"
    /// - "0933" (with userAirlinePrefix "QF") -> "QFA933"
    func toFlightAwareFormat(userAirlinePrefix: String? = nil) -> String? {
        let cleaned = self.trimmingCharacters(in: .whitespaces).uppercased()

        // Pattern 1: Airline code (2-3 letters) followed by flight number
        let patternWithAirline = "^([A-Z]{2,3})(0?\\d+)$"
        if let regex = try? NSRegularExpression(pattern: patternWithAirline),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let airlineRange = Range(match.range(at: 1), in: cleaned),
           let numberRange = Range(match.range(at: 2), in: cleaned) {

            let airlineCode = String(cleaned[airlineRange])
            var flightNumber = String(cleaned[numberRange])

            // Remove leading zero if present
            if flightNumber.hasPrefix("0") {
                flightNumber = String(flightNumber.dropFirst())
            }

            return String.toFlightAwareAirlineCode(airlineCode) + flightNumber
        }

        // Pattern 2: Just numbers (e.g., "933" or "0933")
        let patternNumberOnly = "^(0?\\d+)$"
        if let regex = try? NSRegularExpression(pattern: patternNumberOnly),
           regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) != nil,
           let userPrefix = userAirlinePrefix, !userPrefix.isEmpty {

            var flightNumber = cleaned

            // Remove leading zero if present
            if flightNumber.hasPrefix("0") {
                flightNumber = String(flightNumber.dropFirst())
            }

            return String.toFlightAwareAirlineCode(userPrefix) + flightNumber
        }

        return nil
    }
}

// MARK: - Modern Captured Data Card
struct ModernCapturedDataCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Environment(CloudKitSettingsSyncService.self) private var cloudKitService

    // MARK: - Local Time Entry Bindings
    // The ViewModel always stores times as UTC. When enterTimesInLocalTime is ON,
    // these bindings convert UTC→local for display and local→UTC on set.
    // ACARS capture (which writes UTC directly to the ViewModel) works transparently.

    private func localTimeBinding(utcTime: Binding<String>, airportCode: String) -> Binding<String> {
        Binding(
            get: {
                // Only convert complete "HH:MM" values — pass partial input straight through
                // to avoid AirportService mis-parsing e.g. "023" as 0h 23m.
                let stored = utcTime.wrappedValue
                guard viewModel.enterTimesInLocalTime,
                      !airportCode.isEmpty,
                      stored.count == 5, stored.contains(":") else {
                    return stored
                }
                let icao = AirportService.shared.convertToICAO(airportCode)
                let local = AirportService.shared.convertToLocalTime(
                    utcDateString: viewModel.flightDate,
                    utcTimeString: stored,
                    airportICAO: icao
                )
                guard local.count == 4 else { return stored }
                return "\(local.prefix(2)):\(local.suffix(2))"
            },
            set: { newValue in
                guard viewModel.enterTimesInLocalTime,
                      !airportCode.isEmpty,
                      !viewModel.flightDate.isEmpty,
                      newValue.count == 5, newValue.contains(":") else {
                    // Partial input or no airport — store as-is without conversion
                    utcTime.wrappedValue = newValue
                    return
                }
                let icao = AirportService.shared.convertToICAO(airportCode)
                utcTime.wrappedValue = AirportService.shared.convertFromLocalToUTCTime(
                    localDateString: viewModel.flightDate,
                    localTimeString: newValue,
                    airportICAO: icao
                )
            }
        )
    }

    private func timeFieldLabel(_ base: String, tzLabel: String) -> String {
        base
    }

    private func utcHintText(utcTime: String, tzLabel: String) -> String? {
        guard viewModel.enterTimesInLocalTime,
              !tzLabel.isEmpty,
              utcTime.count == 5, utcTime.contains(":") else { return nil }
        return "\(utcTime.replacingOccurrences(of: ":", with: "")) UTC"
    }

    private var flightNumberPlaceholder: String {
        let baseNumber = "123"
        let leadingZeroNumber = "0123"

        if viewModel.includeAirlinePrefixInFlightNumber {
            if viewModel.includeLeadingZeroInFlightNumber {
                return "\(viewModel.airlinePrefix)\(leadingZeroNumber)"
            } else {
                return "\(viewModel.airlinePrefix)\(baseNumber)"
            }
        } else {
            if viewModel.includeLeadingZeroInFlightNumber {
                return leadingZeroNumber
            } else {
                return baseNumber
            }
        }
    }

    private var flightAwareURL: URL? {
        guard !viewModel.flightNumber.isEmpty,
              let flightAwareCode = viewModel.flightNumber.toFlightAwareFormat(
                userAirlinePrefix: viewModel.includeAirlinePrefixInFlightNumber ? viewModel.airlinePrefix : nil
              ) else {
            return nil
        }
        return URL(string: "https://www.flightaware.com/live/flight/\(flightAwareCode)/history")
    }

    private var canSearchFlight: Bool {
        return flightAwareURL != nil && cloudKitService.isNetworkAvailable && !viewModel.flightDate.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.orange)
                    .font(.title3)

                Text("Flight Info")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 0) {
                    Button(action: {
                        if viewModel.isSimulator || viewModel.isPositioning {
                            viewModel.isSimulator = false
                            viewModel.isPositioning = false
                            HapticManager.shared.impact(.light)
                        }
                    }) {
                        Text("FLT")
                            .font(.subheadline.bold())
                            .foregroundColor(!viewModel.isSimulator && !viewModel.isPositioning ? .white : .secondary)
                            .frame(width: 50, height: 30)
                            .background(!viewModel.isSimulator && !viewModel.isPositioning ? Color.blue : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if !viewModel.isPositioning {
                            viewModel.isPositioning = true
                            viewModel.isSimulator = false
                            viewModel.blockTime = ""  // Clear block time for positioning flights
                            viewModel.nightTime = ""  // Clear night time for positioning flights
                            viewModel.aircraftReg = ""  // Clear aircraft reg for positioning flights
                            viewModel.aircraftType = ""  // Clear aircraft type for positioning flights
                            viewModel.captainName = ""  // Clear captain name for positioning flights
                            viewModel.coPilotName = ""  // Clear F/O name for positioning flights
                            viewModel.so1Name = ""  // Clear SO1 name for positioning flights
                            viewModel.so2Name = ""  // Clear SO2 name for positioning flights
                            viewModel.isPilotFlying = false  // Clear PF for positioning flights
                            HapticManager.shared.impact(.light)
                        }
                    }) {
                        Text("PAX")
                            .font(.subheadline.bold())
                            .foregroundColor(viewModel.isPositioning ? .white : .secondary)
                            .frame(width: 50, height: 30)
                            .background(viewModel.isPositioning ? Color.orange : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if !viewModel.isSimulator {
                            viewModel.isSimulator = true
                            viewModel.isPositioning = false
                            HapticManager.shared.impact(.light)
                        }
                    }) {
                        Text("SIM")
                            .font(.subheadline.bold())
                            .foregroundColor(viewModel.isSimulator ? .white : .secondary)
                            .frame(width: 50, height: 30)
                            .background(viewModel.isSimulator ? Color.purple : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.isPositioning ? Color.orange : (viewModel.isSimulator ? Color.purple : Color.blue), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(spacing: 12) {

                VStack(spacing: 8) {

                    // FROM / TO airports
                    HStack(spacing: 8) {
                        ModernAirportField(
                            label: "FROM",
                            value: Binding(
                                get: { viewModel.fromAirport },
                                set: { viewModel.fromAirport = $0 }
                            ),
                            icon: "airplane.departure",
                            useIATACodes: viewModel.useIATACodes,
                            recentAirports: viewModel.recentAirports,
                            onAirportSelected: { airport in
                                viewModel.trackAirportUsage(airport)
                            }
                        )

                        ModernAirportField(
                            label: "TO",
                            value: Binding(
                                get: { viewModel.toAirport },
                                set: { viewModel.toAirport = $0 }
                            ),
                            icon: "airplane.arrival",
                            useIATACodes: viewModel.useIATACodes,
                            recentAirports: viewModel.recentAirports,
                            onAirportSelected: { airport in
                                viewModel.trackAirportUsage(airport)
                            }
                        )
                    }

                    // Date picker
                    ModernDatePickerField(
                        label: viewModel.enterTimesInLocalTime ? "LOCAL DATE" : "UTC DATE",
                        dateString: $viewModel.flightDate,
                        icon: "calendar",
                        airportCode: viewModel.fromAirport,
                        timeString: viewModel.outTime,
                        showLocalDate: viewModel.displayFlightsInLocalTime && !viewModel.enterTimesInLocalTime,
                        useIATACodes: viewModel.useIATACodes
                    )

                    // Flight Number field with search button
                    ModernFlightNumberField(
                        label: viewModel.isSimulator ? "SIM #" : "FLIGHT #",
                        value: Binding(
                            get: { viewModel.flightNumber },
                            set: { viewModel.updateFlightNumber($0) }
                        ),
                        placeholder: flightNumberPlaceholder,
                        icon: "airplane.ticket",
                        isUppercase: true,
                        keyboardType: (UIDevice.current.userInterfaceIdiom == .pad || viewModel.isSimulator) ? .numbersAndPunctuation : .numbersAndPunctuation,
                        canSearch: canSearchFlight,
                        onSearch: {
                            viewModel.fetchFlightAwareData()
                        },
                        onFocus: {
                            // Auto-insert airline prefix when field is tapped if empty
                            // But not for simulator flights (allows custom sim flight numbers like SIM06B)
                            if viewModel.flightNumber.isEmpty &&
                               viewModel.includeAirlinePrefixInFlightNumber &&
                               !viewModel.isSimulator {
                                viewModel.updateFlightNumber(viewModel.airlinePrefix)
                            }
                        }
                    )
                }

                // Flight Times section
                HStack {
                    Text(viewModel.enterTimesInLocalTime ? "Flight Times (Local)" : "Flight Times (UTC)")
                        .font(.footnote.bold())
                        .foregroundColor(.primary.opacity(0.8))
                    Spacer()
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ModernTimeField(
                            label: timeFieldLabel("STD", tzLabel: viewModel.outTimezoneLabel),
                            value: localTimeBinding(
                                utcTime: Binding(
                                    get: { viewModel.scheduledDeparture },
                                    set: { viewModel.scheduledDeparture = $0 }
                                ),
                                airportCode: viewModel.fromAirport
                            ),
                            icon: "calendar.badge.clock",
                            isReadOnly: false,
                            dateString: viewModel.flightDate,
                            airportCode: viewModel.fromAirport,
                            showLocalTime: viewModel.displayFlightsInLocalTime && !viewModel.enterTimesInLocalTime,
                            useIATACodes: viewModel.useIATACodes,
                            hintText: utcHintText(utcTime: viewModel.scheduledDeparture, tzLabel: viewModel.outTimezoneLabel),
                            onSave: {}
                        )

                        ModernTimeField(
                            label: timeFieldLabel("STA", tzLabel: viewModel.inTimezoneLabel),
                            value: localTimeBinding(
                                utcTime: Binding(
                                    get: { viewModel.scheduledArrival },
                                    set: { viewModel.scheduledArrival = $0 }
                                ),
                                airportCode: viewModel.toAirport
                            ),
                            icon: "calendar.badge.clock",
                            isReadOnly: false,
                            dateString: viewModel.flightDate,
                            airportCode: viewModel.toAirport,
                            showLocalTime: viewModel.displayFlightsInLocalTime && !viewModel.enterTimesInLocalTime,
                            useIATACodes: viewModel.useIATACodes,
                            hintText: utcHintText(utcTime: viewModel.scheduledArrival, tzLabel: viewModel.inTimezoneLabel),
                            onSave: {}
                        )
                    }

                    HStack(spacing: 8) {
                        ModernTimeField(
                            label: timeFieldLabel("OUT", tzLabel: viewModel.outTimezoneLabel),
                            value: localTimeBinding(
                                utcTime: Binding(
                                    get: { viewModel.outTime },
                                    set: { viewModel.outTime = $0 }
                                ),
                                airportCode: viewModel.fromAirport
                            ),
                            icon: "clock",
                            isReadOnly: false,
                            dateString: viewModel.flightDate,
                            airportCode: viewModel.fromAirport,
                            showLocalTime: viewModel.displayFlightsInLocalTime && !viewModel.enterTimesInLocalTime,
                            useIATACodes: viewModel.useIATACodes,
                            hintText: utcHintText(utcTime: viewModel.outTime, tzLabel: viewModel.outTimezoneLabel),
                            onSave: { viewModel.recalculateTimesAfterManualEdit() }
                        )

                        ModernTimeField(
                            label: timeFieldLabel("IN", tzLabel: viewModel.inTimezoneLabel),
                            value: localTimeBinding(
                                utcTime: Binding(
                                    get: { viewModel.inTime },
                                    set: { viewModel.inTime = $0 }
                                ),
                                airportCode: viewModel.toAirport
                            ),
                            icon: "clock",
                            isReadOnly: false,
                            dateString: viewModel.flightDate,
                            airportCode: viewModel.toAirport,
                            showLocalTime: viewModel.displayFlightsInLocalTime && !viewModel.enterTimesInLocalTime,
                            useIATACodes: viewModel.useIATACodes,
                            hintText: utcHintText(utcTime: viewModel.inTime, tzLabel: viewModel.inTimezoneLabel),
                            onSave: { viewModel.recalculateTimesAfterManualEdit() }
                        )
                    }

                    HStack{
                        ModernDecimalTimeField(
                            label: viewModel.isSimulator ? "SIM Time" : "BLOCK Time",
                            value: $viewModel.blockTime,
                            icon: viewModel.isSimulator ? "desktopcomputer" : "timer",
                            isReadOnly: viewModel.isPositioning,
                            showAsHHMM: viewModel.showTimesInHoursMinutes
                        )

                        ModernDecimalTimeField(
                            label: "NIGHT Time",
                            value: $viewModel.nightTime,
                            icon: "moon.stars",
                            isReadOnly: viewModel.isPositioning,
                            showAsHHMM: viewModel.showTimesInHoursMinutes
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            //viewModel.updateNightTime()
        }
        .onChange(of: viewModel.outTime) {
            // Only recalculate if not in editing mode and not a PAX flight
            if !viewModel.isEditingMode && !viewModel.isPositioning {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.inTime) {
            // Only recalculate if not in editing mode and not a PAX flight
            if !viewModel.isEditingMode && !viewModel.isPositioning {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.blockTime) {
            // Only recalculate if not in editing mode and not a PAX flight
            if !viewModel.isEditingMode && !viewModel.isPositioning {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.fromAirport) {
            // Recalculate night time when FROM airport changes (important for B787 ACARS)
            if !viewModel.isEditingMode && !viewModel.isPositioning && !viewModel.fromAirport.isEmpty && !viewModel.toAirport.isEmpty {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.toAirport) {
            // Recalculate night time when TO airport changes (important for B787 ACARS)
            if !viewModel.isEditingMode && !viewModel.isPositioning && !viewModel.fromAirport.isEmpty && !viewModel.toAirport.isEmpty {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.isPilotFlying) { viewModel.updateTakeoffsLandings() }
    }
}
