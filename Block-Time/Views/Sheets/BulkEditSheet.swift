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
    @ObservedObject private var themeService = ThemeService.shared

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
                            BulkEditTextField(
                                label: "A/C Registration",
                                fieldState: $bulkEditViewModel.aircraftReg,
                                textCase: .uppercase
                            )

                            BulkEditTextField(
                                label: "A/C Type",
                                fieldState: $bulkEditViewModel.aircraftType,
                                textCase: .uppercase
                            )
                        }
                    }

                    // Crew Card
                    SectionCard(title: "Crew", icon: "person.2.fill", color: .green) {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "Captain",
                                fieldState: $bulkEditViewModel.captainName,
                                autocapitalization: .words
                            )

                            BulkEditTextField(
                                label: "F/O",
                                fieldState: $bulkEditViewModel.foName,
                                autocapitalization: .words
                            )

                            BulkEditOptionalTextField(
                                label: "S/O1",
                                fieldState: $bulkEditViewModel.so1Name,
                                autocapitalization: .words
                            )

                            BulkEditOptionalTextField(
                                label: "S/O2",
                                fieldState: $bulkEditViewModel.so2Name,
                                autocapitalization: .words
                            )
                        }
                    }

                    // Times Card
                    SectionCard(title: "Flight Times", icon: "clock.fill", color: .purple) {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "BLOCK Time",
                                fieldState: $bulkEditViewModel.blockTime,
                                keyboardType: .decimalPad
                            )

                            BulkEditTextField(
                                label: "NIGHT Time",
                                fieldState: $bulkEditViewModel.nightTime,
                                keyboardType: .decimalPad
                            )

                            BulkEditTextField(
                                label: "P1 Time",
                                fieldState: $bulkEditViewModel.p1Time,
                                keyboardType: .decimalPad
                            )

                            BulkEditTextField(
                                label: "P1US Time",
                                fieldState: $bulkEditViewModel.p1usTime,
                                keyboardType: .decimalPad
                            )

                            BulkEditTextField(
                                label: "P2 Time",
                                fieldState: $bulkEditViewModel.p2Time,
                                keyboardType: .decimalPad
                            )

                            BulkEditTextField(
                                label: "Instrument Time",
                                fieldState: $bulkEditViewModel.instrumentTime,
                                keyboardType: .decimalPad
                            )

                            BulkEditTextField(
                                label: "SIM Time",
                                fieldState: $bulkEditViewModel.simTime,
                                keyboardType: .decimalPad
                            )
                        }
                    }

                    // Schedule Card
                    SectionCard(title: "Schedule Times", icon: "calendar.badge.clock", color: .indigo) {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "OUT",
                                fieldState: $bulkEditViewModel.outTime,
                                placeholder: "HH:MM"
                            )

                            BulkEditTextField(
                                label: "IN",
                                fieldState: $bulkEditViewModel.inTime,
                                placeholder: "HH:MM"
                            )

                            BulkEditTextField(
                                label: "STD",
                                fieldState: $bulkEditViewModel.scheduledDeparture,
                                placeholder: "HH:MM"
                            )

                            BulkEditTextField(
                                label: "STA",
                                fieldState: $bulkEditViewModel.scheduledArrival,
                                placeholder: "HH:MM"
                            )
                        }
                    }

                    // Operations Card
                    SectionCard(title: "Operations", icon: "slider.horizontal.3", color: .orange) {
                        VStack(spacing: 16) {
                            BulkEditToggle(
                                label: "PF",
                                fieldState: $bulkEditViewModel.isPilotFlying
                            )

                            BulkEditToggle(
                                label: "ICUS",
                                fieldState: $bulkEditViewModel.isICUS
                            )

                            BulkEditFlightTypeToggle(
                                isPositioning: $bulkEditViewModel.isPositioning,
                                isSimulator: $bulkEditViewModel.isSimulator
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
                                fieldState: $bulkEditViewModel.dayTakeoffs
                            )

                            BulkEditIntField(
                                label: "Day Ldg",
                                fieldState: $bulkEditViewModel.dayLandings
                            )

                            BulkEditIntField(
                                label: "Night T/O",
                                fieldState: $bulkEditViewModel.nightTakeoffs
                            )

                            BulkEditIntField(
                                label: "Night Ldg",
                                fieldState: $bulkEditViewModel.nightLandings
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

// MARK: - BulkEditTextField

struct BulkEditTextField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>
    var textCase: Text.Case? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    var keyboardType: UIKeyboardType = .default
    var placeholder: String? = nil

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextField(
                fieldState.isMixed ? "(Mixed)" : (placeholder ?? label),
                text: $textValue
            )
            .keyboardType(keyboardType)
            .textCase(textCase)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .focused($isFocused)
            .font(.body)
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .onChange(of: textValue) { _, newValue in
                fieldState = .value(newValue)
            }
            .onChange(of: isFocused) { _, focused in
                if focused && fieldState.isMixed {
                    textValue = ""
                }
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val
                }
            }
        }
    }
}

// MARK: - BulkEditOptionalTextField

struct BulkEditOptionalTextField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String?>
    var textCase: Text.Case? = nil
    var autocapitalization: TextInputAutocapitalization = .never

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextField(
                fieldState.isMixed ? "(Mixed)" : label,
                text: $textValue
            )
            .textCase(textCase)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .focused($isFocused)
            .font(.body)
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .onChange(of: textValue) { _, newValue in
                fieldState = .value(newValue.isEmpty ? nil : newValue)
            }
            .onChange(of: isFocused) { _, focused in
                if focused && fieldState.isMixed {
                    textValue = ""
                }
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val ?? ""
                }
            }
        }
    }
}

// MARK: - BulkEditIntField

struct BulkEditIntField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<Int>

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextField(
                fieldState.isMixed ? "(Mixed)" : label,
                text: $textValue
            )
            .keyboardType(.numberPad)
            .focused($isFocused)
            .font(.body)
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .onChange(of: textValue) { _, newValue in
                if let intValue = Int(newValue) {
                    fieldState = .value(intValue)
                }
            }
            .onChange(of: isFocused) { _, focused in
                if focused && fieldState.isMixed {
                    textValue = ""
                }
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = String(val)
                }
            }
        }
    }
}

// MARK: - BulkEditToggle

struct BulkEditToggle: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<Bool>

    @State private var toggleValue: Bool = false
    @State private var isIndeterminate: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            if isIndeterminate {
                Button {
                    // First tap sets to true
                    isIndeterminate = false
                    toggleValue = true
                    fieldState = .value(true)
                    HapticManager.shared.impact(.light)
                } label: {
                    Text("(Mixed)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
            } else {
                Toggle("", isOn: $toggleValue)
                    .labelsHidden()
                    .tint(.blue)
                    .onChange(of: toggleValue) { _, newValue in
                        fieldState = .value(newValue)
                        HapticManager.shared.impact(.light)
                    }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if case .value(let val) = fieldState {
                toggleValue = val
                isIndeterminate = false
            } else if fieldState.isMixed {
                isIndeterminate = true
            }
        }
    }
}

// MARK: - BulkEditTextEditor

struct BulkEditTextEditor: View {
    @Binding var fieldState: BulkEditViewModel.FieldState<String>

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $textValue)
                .frame(minHeight: 100)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                )
                .focused($isFocused)
                .onChange(of: textValue) { _, newValue in
                    fieldState = .value(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    if focused && fieldState.isMixed {
                        textValue = ""
                    }
                }
                .onAppear {
                    if case .value(let val) = fieldState {
                        textValue = val
                    } else if fieldState.isMixed {
                        textValue = "(Mixed)"
                    }
                }

            if textValue.isEmpty || textValue == "(Mixed)" {
                Text(fieldState.isMixed ? "(Mixed)" : "Enter remarks...")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - BulkEditFlightTypeToggle

struct BulkEditFlightTypeToggle: View {
    @Binding var isPositioning: BulkEditViewModel.FieldState<Bool>
    @Binding var isSimulator: BulkEditViewModel.FieldState<Bool>

    enum FlightType {
        case flight
        case positioning
        case simulator
        case mixed
    }

    private var currentType: FlightType {
        // Determine the current flight type based on field states
        let posValue = isPositioning.displayValue
        let simValue = isSimulator.displayValue

        // If either field is mixed, the whole thing is mixed
        if isPositioning.isMixed || isSimulator.isMixed {
            return .mixed
        }

        // Determine concrete type
        if let sim = simValue, sim == true {
            return .simulator
        } else if let pos = posValue, pos == true {
            return .positioning
        } else {
            return .flight
        }
    }

    var body: some View {
        HStack {
            Text("Flight Type")
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            if currentType == .mixed {
                Button {
                    // First tap on mixed sets to FLT
                    isPositioning = .value(false)
                    isSimulator = .value(false)
                    HapticManager.shared.impact(.light)
                } label: {
                    Text("(Mixed)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
            } else {
                HStack(spacing: 0) {
                    // FLT Button
                    Button(action: {
                        isPositioning = .value(false)
                        isSimulator = .value(false)
                        HapticManager.shared.impact(.light)
                    }) {
                        Text("FLT")
                            .font(.subheadline.bold())
                            .foregroundColor(currentType == .flight ? .white : .secondary)
                            .frame(width: 55, height: 32)
                            .background(currentType == .flight ? Color.blue : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()
                        .frame(height: 20)

                    // PAX Button
                    Button(action: {
                        isPositioning = .value(true)
                        isSimulator = .value(false)
                        HapticManager.shared.impact(.light)
                    }) {
                        Text("PAX")
                            .font(.subheadline.bold())
                            .foregroundColor(currentType == .positioning ? .white : .secondary)
                            .frame(width: 55, height: 32)
                            .background(currentType == .positioning ? Color.orange : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()
                        .frame(height: 20)

                    // SIM Button
                    Button(action: {
                        isPositioning = .value(false)
                        isSimulator = .value(true)
                        HapticManager.shared.impact(.light)
                    }) {
                        Text("SIM")
                            .font(.subheadline.bold())
                            .foregroundColor(currentType == .simulator ? .white : .secondary)
                            .frame(width: 55, height: 32)
                            .background(currentType == .simulator ? Color.purple : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - BulkEditApproachPicker

struct BulkEditApproachPicker: View {
    @Binding var fieldState: BulkEditViewModel.FieldState<String?>
    let isPilotFlying: BulkEditViewModel.FieldState<Bool>

    @State private var showingPicker = false

    private var isDisabled: Bool {
        // Disable if pilot flying is explicitly false
        if case .value(let pf) = isPilotFlying {
            return !pf
        }
        return false
    }

    private var displayText: String {
        if fieldState.isMixed {
            return "(Mixed)"
        }
        if case .value(let approachType) = fieldState {
            return approachType ?? "Nil"
        }
        return "Nil"
    }

    private var isOn: Bool {
        if case .value(let approachType) = fieldState {
            return approachType != nil
        }
        return false
    }

    var body: some View {
        HStack {
            Text("Approach")
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            Button(action: {
                if !isDisabled {
                    showingPicker = true
                    HapticManager.shared.impact(.light)
                }
            }) {
                HStack(spacing: 6) {
                    Text(displayText)
                        .font(.subheadline.bold())
                        .foregroundColor(isOn ? .white : .orange)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(isOn ? .white : .orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isOn ? Color.orange : Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(isOn ? 0 : 0.5), lineWidth: 1.5)
                )
            }
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
            .confirmationDialog("Select Approach Type", isPresented: $showingPicker, titleVisibility: .visible) {
                Button("Nil") {
                    fieldState = .value(nil)
                }
                Button("ILS") {
                    fieldState = .value("ILS")
                }
                Button("GLS") {
                    fieldState = .value("GLS")
                }
                Button("RNP") {
                    fieldState = .value("RNP")
                }
                Button("AIII") {
                    fieldState = .value("AIII")
                }
                Button("NPA") {
                    fieldState = .value("NPA")
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(.vertical, 4)
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

