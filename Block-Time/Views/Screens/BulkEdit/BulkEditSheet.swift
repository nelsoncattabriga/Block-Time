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

    // MARK: - Properties

    let selectedFlights: [FlightSector]
    let onSave: ([UUID: FlightSector]) -> Void

    @StateObject private var bulkEditViewModel: BulkEditViewModel
    @State private var showingDiscardAlert = false

    // MARK: - Initialization

    init(selectedFlights: [FlightSector], onSave: @escaping ([UUID: FlightSector]) -> Void) {
        self.selectedFlights = selectedFlights
        self.onSave = onSave
        _bulkEditViewModel = StateObject(wrappedValue: BulkEditViewModel(selectedFlights: selectedFlights))
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // Aircraft Info Card
                        SectionCard(title: "Aircraft Information", icon: "airplane", color: .blue) {
                        VStack(spacing: 12) {
                            BulkEditAircraftRegField(
                                label: "A/C Registration",
                                fieldState: $bulkEditViewModel.aircraftReg,
                                showFullReg: viewModel.showFullAircraftReg,
                                aircraftTypeFieldState: $bulkEditViewModel.aircraftType
                            )

                            BulkEditAircraftTypeField(
                                label: "A/C Type",
                                fieldState: $bulkEditViewModel.aircraftType
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
                                icon: "person.badge.shield.checkmark"
                            )

                            BulkEditCrewField(
                                label: "F/O",
                                fieldState: $bulkEditViewModel.foName,
                                savedNames: viewModel.savedCoPilotNames,
                                recentNames: viewModel.recentCoPilotNames,
                                onNameAdded: viewModel.addCoPilotName,
                                onNameRemoved: viewModel.removeCoPilotName,
                                icon: "person.badge.clock"
                            )

                            BulkEditOptionalCrewField(
                                label: "S/O1",
                                fieldState: $bulkEditViewModel.so1Name,
                                savedNames: viewModel.savedSONames,
                                recentNames: viewModel.recentSONames,
                                onNameAdded: viewModel.addSOName,
                                onNameRemoved: viewModel.removeSOName,
                                icon: "person.badge.key"
                            )

                            BulkEditOptionalCrewField(
                                label: "S/O2",
                                fieldState: $bulkEditViewModel.so2Name,
                                savedNames: viewModel.savedSONames,
                                recentNames: viewModel.recentSONames,
                                onNameAdded: viewModel.addSOName,
                                onNameRemoved: viewModel.removeSOName,
                                icon: "person.badge.key.fill"
                            )
                        }
                    }

                    // Times Card
                    SectionCard(title: "Flight Times", icon: "clock.fill", color: .purple) {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "BLOCK Time",
                                fieldState: $bulkEditViewModel.blockTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
                            )

                            BulkEditTextField(
                                label: "NIGHT Time",
                                fieldState: $bulkEditViewModel.nightTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
                            )

                            BulkEditTextField(
                                label: "P1 Time",
                                fieldState: $bulkEditViewModel.p1Time,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
                            )

                            BulkEditTextField(
                                label: "P1US Time",
                                fieldState: $bulkEditViewModel.p1usTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
                            )

                            BulkEditTextField(
                                label: "P2 Time",
                                fieldState: $bulkEditViewModel.p2Time,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
                            )

                            BulkEditTextField(
                                label: "Instrument Time",
                                fieldState: $bulkEditViewModel.instrumentTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
                            )

                            BulkEditTextField(
                                label: "SIM Time",
                                fieldState: $bulkEditViewModel.simTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
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
                                isTimeField: true
                            )

                            BulkEditTextField(
                                label: "IN",
                                fieldState: $bulkEditViewModel.inTime,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                placeholder: "HH:MM",
                                isTimeField: true
                            )

                            BulkEditTextField(
                                label: "STD",
                                fieldState: $bulkEditViewModel.scheduledDeparture,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                placeholder: "HH:MM",
                                isTimeField: true
                            )

                            BulkEditTextField(
                                label: "STA",
                                fieldState: $bulkEditViewModel.scheduledArrival,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad,
                                placeholder: "HH:MM",
                                isTimeField: true
                            )
                        }
                    }

                    // Operations Card
                    SectionCard(title: "Operations", icon: "slider.horizontal.3", color: .orange) {
                        VStack(spacing: 16) {
                            BulkEditFlightTypeToggle(
                                isPositioning: $bulkEditViewModel.isPositioning,
                                isSimulator: $bulkEditViewModel.isSimulator
                            )

                            BulkEditPilotRoleSegmentedPicker(
                                fieldState: $bulkEditViewModel.isPilotFlying
                            )

                            BulkEditApproachPicker(
                                fieldState: $bulkEditViewModel.selectedApproachType,
                                isPilotFlying: bulkEditViewModel.isPilotFlying
                            )
                        }
                    }

                    // Takeoffs & Landings Card
                    SectionCard(title: "Takeoffs & Landings", icon: "airplane.departure", color: .teal) {
                        VStack(spacing: 12) {
                            BulkEditIntField(
                                label: "Day T/O",
                                fieldState: $bulkEditViewModel.dayTakeoffs,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad
                            )

                            BulkEditIntField(
                                label: "Day Ldg",
                                fieldState: $bulkEditViewModel.dayLandings,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad
                            )

                            BulkEditIntField(
                                label: "Night T/O",
                                fieldState: $bulkEditViewModel.nightTakeoffs,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad
                            )

                            BulkEditIntField(
                                label: "Night Ldg",
                                fieldState: $bulkEditViewModel.nightLandings,
                                keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad
                            )
                        }
                    }

                    // Remarks Card
                    SectionCard(title: "REMARKS", icon: "note.text", color: .gray) {
                        BulkEditTextEditor(
                            fieldState: $bulkEditViewModel.remarks
                        )
                    }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit \(selectedFlights.count) Flight\(selectedFlights.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.medium)
                        if bulkEditViewModel.hasModifications {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!bulkEditViewModel.hasModifications)
                    .fontWeight(bulkEditViewModel.hasModifications ? .bold : .regular)
                    .foregroundColor(bulkEditViewModel.hasModifications ? .blue : .gray)
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
