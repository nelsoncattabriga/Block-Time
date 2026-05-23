//
//  BulkEditSheet.swift
//  Block-Time
//
//  Created by Nelson on 16/01/2026.
//

import SwiftUI

struct BulkEditSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @Environment(ThemeService.self) private var themeService

    // CustomCounterService is @Observable — accessed via .shared since it is not injected
    // via @Environment at the presentation sites (FlightsView / FlightsSplitView).
    private var customCounterService: CustomCounterService { CustomCounterService.shared }

    // MARK: - Properties

    let selectedFlights: [FlightSector]
    let onSave: ([UUID: FlightSector]) -> Void

    @StateObject private var bulkEditViewModel: BulkEditViewModel
    @State private var showingDiscardAlert = false
    @State private var keyboardToolbar = KeyboardToolbarState()

    // MARK: - Initialization

    init(selectedFlights: [FlightSector], onSave: @escaping ([UUID: FlightSector]) -> Void) {
        self.selectedFlights = selectedFlights
        self.onSave = onSave
        _bulkEditViewModel = StateObject(wrappedValue: BulkEditViewModel(selectedFlights: selectedFlights))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // Flight Date Card
                        SectionCard(title: "Flight Date", icon: "calendar", color: .blue) {
                            BulkEditDateField(
                                label: "Date",
                                fieldState: $bulkEditViewModel.flightDate
                            )
                        }

                        // Aircraft Info Card
                        SectionCard(title: "Aircraft Information", icon: "airplane", color: .blue) {
                        VStack(spacing: 12) {
                            BulkEditAircraftRegField(
                                label: "A/C Registration",
                                fieldState: $bulkEditViewModel.aircraftReg,
                                showFullReg: viewModel.showFullAircraftReg,
                                aircraftTypeFieldState: $bulkEditViewModel.aircraftType
                            )

                            BulkEditTextField(
                                label: "A/C Type",
                                fieldState: $bulkEditViewModel.aircraftType,
                                textCase: .uppercase,
                                autocapitalization: .characters,
                                placeholder: "e.g. B738",
                                showClearButton: true
                            )

                            BulkEditPrefixManager(
                                operationState: $bulkEditViewModel.prefixOperation,
                                prefixState: $bulkEditViewModel.prefixValue
                            )

                            BulkEditPrefixManager(
                                title: "Rego Prefix",
                                operationState: $bulkEditViewModel.regoPrefixOperation,
                                prefixState: $bulkEditViewModel.regoPrefixValue
                            )
                        }
                    }

                    // Route Card
                    SectionCard(title: "Route", icon: "map", color: .cyan) {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: viewModel.useIATACodes ? "From (IATA)" : "From (ICAO)",
                                fieldState: $bulkEditViewModel.fromAirport,
                                keyboardType: .asciiCapable,
                                placeholder: viewModel.useIATACodes ? "e.g. SYD" : "e.g. YSSY"
                            )

                            BulkEditTextField(
                                label: viewModel.useIATACodes ? "To (IATA)" : "To (ICAO)",
                                fieldState: $bulkEditViewModel.toAirport,
                                keyboardType: .asciiCapable,
                                placeholder: viewModel.useIATACodes ? "e.g. MEL" : "e.g. YMML"
                            )
                        }
                    }

                    // Crew Card
                    SectionCard(title: "Crew", icon: "person.2.fill", color: .green) {
                        VStack(spacing: 12) {
                            BulkEditCrewField(
                                label: "Captain",
                                fieldState: $bulkEditViewModel.captainName,
                                savedNames: viewModel.savedCaptainNames,
                                recentNames: viewModel.recentCaptainNames,
                                onNameAdded: viewModel.addCaptainName,
                                onNameRemoved: viewModel.removeCaptainName,
                                icon: "person"
                            )

                            BulkEditCrewField(
                                label: "F/O",
                                fieldState: $bulkEditViewModel.foName,
                                savedNames: viewModel.savedCoPilotNames,
                                recentNames: viewModel.recentCoPilotNames,
                                onNameAdded: viewModel.addCoPilotName,
                                onNameRemoved: viewModel.removeCoPilotName,
                                icon: "person"
                            )

                            BulkEditOptionalCrewField(
                                label: "S/O1",
                                fieldState: $bulkEditViewModel.so1Name,
                                savedNames: viewModel.savedSONames,
                                recentNames: viewModel.recentSONames,
                                onNameAdded: viewModel.addSOName,
                                onNameRemoved: viewModel.removeSOName,
                                icon: "person"
                            )

                            BulkEditOptionalCrewField(
                                label: "S/O2",
                                fieldState: $bulkEditViewModel.so2Name,
                                savedNames: viewModel.savedSONames,
                                recentNames: viewModel.recentSONames,
                                onNameAdded: viewModel.addSOName,
                                onNameRemoved: viewModel.removeSOName,
                                icon: "person"
                            )
                        }
                    }

                    // Times Card
                    SectionCard(title: "Flight Times", icon: "clock.fill", color: .purple) {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "BLOCK Time",
                                fieldState: $bulkEditViewModel.blockTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "NIGHT Time",
                                fieldState: $bulkEditViewModel.nightTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "P1 Time",
                                fieldState: $bulkEditViewModel.p1Time,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "ICUS Time",
                                fieldState: $bulkEditViewModel.p1usTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "P2 Time",
                                fieldState: $bulkEditViewModel.p2Time,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "Instrument Time",
                                fieldState: $bulkEditViewModel.instrumentTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "SIM Time",
                                fieldState: $bulkEditViewModel.simTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "SP/INS Time",
                                fieldState: $bulkEditViewModel.spInsTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad,
                                keyboardToolbar: keyboardToolbar
                            )
                        }
                    }

                    // Schedule Card
                    SectionCard(title: "Schedule Times", icon: "calendar.badge.clock", color: .indigo) {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "OUT",
                                fieldState: $bulkEditViewModel.outTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                placeholder: "HH:MM",
                                isTimeField: true,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "IN",
                                fieldState: $bulkEditViewModel.inTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                placeholder: "HH:MM",
                                isTimeField: true,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "STD",
                                fieldState: $bulkEditViewModel.scheduledDeparture,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                placeholder: "HH:MM",
                                isTimeField: true,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditTextField(
                                label: "STA",
                                fieldState: $bulkEditViewModel.scheduledArrival,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                placeholder: "HH:MM",
                                isTimeField: true,
                                keyboardToolbar: keyboardToolbar
                            )
                        }
                    }

                    // Operations Card
                    SectionCard(title: "Operations", icon: "slider.horizontal.3", color: .orange) {
                        VStack(spacing: 16) {
                            // TODO: Flight Type toggle (FLT/PAX/SIM/INS) hidden — Save button
                            // modification tracking has a Combine ordering bug with sequential
                            // property writes. Revisit before shipping.
//                            BulkEditFlightTypeToggle(
//                                isPositioning: $bulkEditViewModel.isPositioning,
//                                isSimulator: $bulkEditViewModel.isSimulator,
//                                isSpIns: $bulkEditViewModel.isSpIns
//                            )

                            BulkEditPilotRoleSegmentedPicker(
                                fieldState: $bulkEditViewModel.isPilotFlying
                            )

                            BulkEditApproachPicker(
                                fieldState: $bulkEditViewModel.selectedApproachType,
                                isPilotFlying: bulkEditViewModel.isPilotFlying
                            )

                            BulkEditBlockTimeRolePicker(
                                fieldState: $bulkEditViewModel.blockTimeRole
                            )
                        }
                    }

                    // Takeoffs & Landings Card
                    SectionCard(title: "Takeoffs & Landings", icon: "airplane.departure", color: .teal) {
                        VStack(spacing: 12) {
                            BulkEditIntField(
                                label: "Day T/O",
                                fieldState: $bulkEditViewModel.dayTakeoffs,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditIntField(
                                label: "Day Ldg",
                                fieldState: $bulkEditViewModel.dayLandings,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditIntField(
                                label: "Night T/O",
                                fieldState: $bulkEditViewModel.nightTakeoffs,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                keyboardToolbar: keyboardToolbar
                            )

                            BulkEditIntField(
                                label: "Night Ldg",
                                fieldState: $bulkEditViewModel.nightLandings,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                keyboardToolbar: keyboardToolbar
                            )
                        }
                    }

                    // Remarks Card
                    SectionCard(title: "REMARKS", icon: "note.text", color: .gray) {
                        BulkEditTextEditor(
                            fieldState: $bulkEditViewModel.remarks
                        )
                    }

                    // Custom Fields Card (hidden when no definitions are configured)
                    if !customCounterService.definitions.isEmpty {
                        SectionCard(title: "Custom Fields", icon: "slider.horizontal.below.square.filled.and.square", color: .mint) {
                            VStack(spacing: 12) {
                                ForEach(customCounterService.definitions) { def in
                                    BulkEditTextField(
                                        label: def.label,
                                        fieldState: Binding(
                                            get: { bulkEditViewModel.customCounterStates[def.columnIndex] ?? .notEdited },
                                            set: { bulkEditViewModel.customCounterStates[def.columnIndex] = $0 }
                                        ),
                                        keyboardType: customFieldKeyboardType(for: def.type),
                                        isTimeField: isTimeField(for: def.type),
                                        keyboardToolbar: def.type != .text ? keyboardToolbar : nil
                                    )
                                }
                            }
                        }
                    }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit \(selectedFlights.count) Flight\(selectedFlights.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.medium)
                        if bulkEditViewModel.hasModifications {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!bulkEditViewModel.hasModifications)
                    .fontWeight(bulkEditViewModel.hasModifications ? .bold : .regular)
                    .foregroundColor(bulkEditViewModel.hasModifications ? .blue : .gray)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if keyboardToolbar.isAnyFieldFocused {
                        Button("Clear") {
                            keyboardToolbar.onClear?()
                        }
                        .foregroundStyle(.red)
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                            keyboardToolbar.isAnyFieldFocused = false
                        }
                        .font(.subheadline.bold())
                    }
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        }
    }

    // MARK: - Helpers

    private func keyboardType(for type: CounterType) -> UIKeyboardType {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        switch type {
        case .time:    return isPad ? .numbersAndPunctuation : .numberPad
        case .decimal: return isPad ? .numbersAndPunctuation : .decimalPad
        case .integer: return isPad ? .numbersAndPunctuation : .decimalPad
        case .text:    return .default
        }
    }

    private func isTimeField(for type: CounterType) -> Bool {
        type == .time && viewModel.showTimesInHoursMinutes
    }

    private func customFieldKeyboardType(for type: CounterType) -> UIKeyboardType {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        switch type {
        case .time:
            // hrs:min mode → numberPad (digits only, colon inserted by formatter)
            // decimal mode → decimalPad (needs decimal point)
            if viewModel.showTimesInHoursMinutes {
                return isPad ? .numbersAndPunctuation : .numberPad
            } else {
                return isPad ? .numbersAndPunctuation : .decimalPad
            }
        case .decimal: return isPad ? .numbersAndPunctuation : .decimalPad
        case .integer: return isPad ? .numbersAndPunctuation : .decimalPad
        case .text:    return .default
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        let updates = bulkEditViewModel.applyChanges(to: selectedFlights)
        onSave(updates)
        HapticManager.shared.notification(.success)
        dismiss()
    }
}

// MARK: - SectionCard

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    let sampleFlights = [
        FlightSector(
            date: "29/01/2026",
            flightNumber: "VA123",
            aircraftReg: "VH-XYZ",
            aircraftType: "B738",
            fromAirport: "YSSY",
            toAirport: "YMML",
            captainName: "John Smith",
            foName: "Jane Doe",
            blockTime: "1.5",
            nightTime: "0.0",
            p1Time: "1.5",
            p1usTime: "0.0",
            instrumentTime: "0.5",
            simTime: "0.0",
            isPilotFlying: true,
            isILS: true,
            dayTakeoffs: 1,
            dayLandings: 1
        ),
        FlightSector(
            date: "29/01/2026",
            flightNumber: "VA456",
            aircraftReg: "VH-XYZ",
            aircraftType: "B738",
            fromAirport: "YMML",
            toAirport: "YBBN",
            captainName: "John Smith",
            foName: "Jane Doe",
            blockTime: "2.0",
            nightTime: "0.5",
            p1Time: "2.0",
            p1usTime: "0.0",
            instrumentTime: "0.3",
            simTime: "0.0",
            isPilotFlying: false,
            isRNP: true,
            dayTakeoffs: 1,
            dayLandings: 1
        )
    ]

    BulkEditSheet(
        selectedFlights: sampleFlights,
        onSave: { _ in }
    )
    .environmentObject(FlightTimeExtractorViewModel())
}
