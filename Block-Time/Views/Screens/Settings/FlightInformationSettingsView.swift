// Views/Screens/Settings/FlightInformationSettingsView.swift
import SwiftUI
import BlockTimeKit

// MARK: - Flight Information Settings Detail View

struct FlightInformationSettingsView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Environment(ThemeService.self) private var themeService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                FleetCard(viewModel: viewModel)
                AircraftAirportsCard(viewModel: viewModel)
                TimesCard(viewModel: viewModel)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("Flight Information")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Fleet Card

struct FleetCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fleet")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            ModernFleetSelectorRow(viewModel: viewModel)
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Aircraft & Airports Card

struct AircraftAirportsCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aircraft & Airports")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ModernAirlinePrefixRow(
                    isEnabled: Binding(
                        get: { viewModel.includeAirlinePrefixInFlightNumber },
                        set: { viewModel.updateIncludeAirlinePrefixInFlightNumber($0) }
                    ),
                    prefix: Binding(
                        get: { viewModel.airlinePrefix },
                        set: { viewModel.updateAirlinePrefix($0) }
                    ),
                    isCustomSelected: Binding(
                        get: { viewModel.isCustomAirlinePrefix },
                        set: { viewModel.updateIsCustomAirlinePrefix($0) }
                    ),
                    color: .orange
                )

                ModernToggleRow(
                    title: "Full A/C Registration",
                    subtitle: "VH-ABC vs ABC",
                    isOn: Binding(
                        get: { viewModel.showFullAircraftReg },
                        set: { viewModel.updateShowFullAircraftReg($0) }
                    ),
                    color: .orange,
                    icon: "airplane"
                )

                ModernToggleRow(
                    title: "Leading Zeros in Flt No",
                    subtitle: "QF0405 vs QF405",
                    isOn: Binding(
                        get: { viewModel.includeLeadingZeroInFlightNumber },
                        set: { viewModel.updateIncludeLeadingZeroInFlightNumber($0) }
                    ),
                    color: .orange,
                    icon: "number"
                )

                HStack(spacing: 12) {
                    Image(systemName: "airplane.circle")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Airport Code")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.useIATACodes ? "IATA - BNE" : "ICAO - YBBN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.useIATACodes },
                        set: { viewModel.updateUseIATACodes($0) }
                    )) {
                        Text("ICAO").tag(false)
                        Text("IATA").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
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
    }
}

// MARK: - Times Card

struct TimesCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Times")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Times Entered In")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.enterTimesInLocalTime ? "Enter times in LOCAL time" : "Enter times in UTC")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.enterTimesInLocalTime },
                        set: { viewModel.updateEnterTimesInLocalTime($0) }
                    )) {
                        Text("UTC").tag(false)
                        Text("Local").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Times Shown In")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.displayFlightsInLocalTime ? "Date & Times in Local Time" : "Date & Times in UTC")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.displayFlightsInLocalTime },
                        set: { viewModel.updateDisplayFlightsInLocalTime($0) }
                    )) {
                        Text("UTC").tag(false)
                        Text("Local").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                ModernToggleRow(
                    title: "Count SIM in Total",
                    subtitle: "Include SIM time in Total Time",
                    isOn: Binding(
                        get: { viewModel.countSimInTotal },
                        set: { viewModel.updateCountSimInTotal($0) }
                    ),
                    color: .orange,
                    icon: "desktopcomputer"
                )

                ModernToggleRow(
                    title: "Show OUT/IN Times",
                    subtitle: "Shows times in Logbook view",
                    isOn: Binding(
                        get: { viewModel.showOutInTimes },
                        set: { viewModel.updateShowOutInTimes($0) }
                    ),
                    color: .orange,
                    icon: "clock"
                )

                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block Times In")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.showTimesInHoursMinutes },
                        set: { viewModel.updateShowTimesInHoursMinutes($0) }
                    )) {
                        Text("Decimal").tag(false)
                        Text("Hrs:Min").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                if !viewModel.showTimesInHoursMinutes {
                    HStack(spacing: 12) {
                        Image(systemName: "number")
                            .foregroundColor(.orange)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Decimal Rounding")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text(roundingExampleText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("", selection: Binding(
                            get: { viewModel.decimalRoundingMode },
                            set: { viewModel.updateDecimalRoundingMode($0) }
                        )) {
                            ForEach(RoundingMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
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
    }

    private var roundingExampleText: String {
        switch viewModel.decimalRoundingMode {
        case .standard:
            return "03:57 Displays as 4.0"
        case .alternate:
            return "03:57 Displays as 3.9"
        }
    }
}

// MARK: - Airline Picker Sheet

struct AirlinePickerSheet: View {
    @Binding var selectedPrefix: String
    @Binding var isCustomSelected: Bool
    @Binding var customPrefix: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Select Airline")) {
                    ForEach(Airline.airlines) { airline in
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            if airline.id == "CUSTOM" {
                                isCustomSelected = true
                                // Keep existing custom prefix if available
                                if customPrefix.isEmpty && !selectedPrefix.isEmpty {
                                    customPrefix = selectedPrefix
                                }
                            } else {
                                isCustomSelected = false
                                selectedPrefix = airline.prefix
                                customPrefix = ""
                            }
                            onDismiss()
                            dismiss()
                        }) {
                            HStack {
                                if !airline.iconName.isEmpty {
                                    Image(airline.iconName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 20)
                                } else {
                                    Image(systemName: "pencil.circle")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                        .frame(width: 20, height: 20)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(airline.name)
                                        .font(.body)
                                        .foregroundColor(.primary)

                                    if !airline.prefix.isEmpty {
                                        Text("Prefix: \(airline.prefix)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Enter your own prefix")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if airline.id == "CUSTOM" && isCustomSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                } else if selectedPrefix == airline.prefix && !isCustomSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Select Airline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Airline Prefix Row

struct ModernAirlinePrefixRow: View {
    @Binding var isEnabled: Bool
    @Binding var prefix: String
    @Binding var isCustomSelected: Bool
    let color: Color
    @State private var showingAirlinePicker = false
    @State private var customPrefix: String = ""

    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                if isEnabled {
                    showingAirlinePicker = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "tag")
                        .foregroundColor(color)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Airline Prefix")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(isEnabled ? "\(prefix)405 vs 405" : "QF405 vs 405")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isEnabled {
                        HStack(spacing: 8) {
                            // Show airline icon if available and not custom
                            if let airline = Airline.getAirline(byPrefix: prefix), !isCustomSelected {
                                Image(airline.iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 16)
                            }

                            Text(isCustomSelected ? "Custom" : prefix)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: color))
                        .scaleEffect(0.9)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            // Show custom text field if custom is selected
            if isEnabled && isCustomSelected {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .foregroundColor(color)
                        .frame(width: 20)

                    TextField("Enter custom prefix", text: $customPrefix)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .onChange(of: customPrefix) { _, newValue in
                            prefix = newValue.uppercased()
                        }
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingAirlinePicker) {
            AirlinePickerSheet(
                selectedPrefix: $prefix,
                isCustomSelected: $isCustomSelected,
                customPrefix: $customPrefix,
                onDismiss: { showingAirlinePicker = false }
            )
        }
        .onAppear {
            // Initialize customPrefix if custom is selected
            if isCustomSelected && customPrefix.isEmpty {
                customPrefix = prefix
            }
        }
    }
}

// MARK: - Fleet Selector Row

struct ModernFleetSelectorRow: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @State private var availableFleets: [Fleet] = []
    @State private var selectedFleet: Fleet?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane.departure")
                .foregroundColor(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fleet Selection")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            Spacer()

            Picker("", selection: Binding(
                get: { viewModel.selectedFleetID },
                set: { newFleetID in
                    viewModel.updateSelectedFleetID(newFleetID)
                    selectedFleet = availableFleets.first(where: { $0.id == newFleetID })
                    HapticManager.shared.impact(.light)
                }
            )) {
                ForEach(availableFleets.sorted { $0.name < $1.name }, id: \.id) { fleet in
                    Text(fleet.name).tag(fleet.id)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
        .onAppear {
            loadFleets()
        }
    }

    private func loadFleets() {
        availableFleets = AircraftFleetService.availableFleets.filter { !$0.aircraft.isEmpty }
        if selectedFleet == nil {
            if let match = availableFleets.first(where: { $0.id == viewModel.selectedFleetID }) {
                selectedFleet = match
            } else {
                selectedFleet = availableFleets.first
                if let fallback = availableFleets.first {
                    viewModel.updateSelectedFleetID(fallback.id)
                }
            }
        }
    }
}
