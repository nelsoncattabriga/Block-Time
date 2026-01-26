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
            ScrollView {
                VStack(spacing: 20) {

                    // Aircraft Info Card
                    EditableCard(title: "Aircraft Information") {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "Aircraft Registration",
                                fieldState: $bulkEditViewModel.aircraftReg,
                                textCase: .uppercase
                            )

                            BulkEditTextField(
                                label: "Aircraft Type",
                                fieldState: $bulkEditViewModel.aircraftType,
                                textCase: .uppercase
                            )
                        }
                    }

                    // Crew Card
                    EditableCard(title: "Crew") {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "Captain Name",
                                fieldState: $bulkEditViewModel.captainName,
                                autocapitalization: .words
                            )

                            BulkEditTextField(
                                label: "F/O Name",
                                fieldState: $bulkEditViewModel.foName,
                                autocapitalization: .words
                            )

                            BulkEditOptionalTextField(
                                label: "S/O1 Name",
                                fieldState: $bulkEditViewModel.so1Name,
                                autocapitalization: .words
                            )

                            BulkEditOptionalTextField(
                                label: "S/O2 Name",
                                fieldState: $bulkEditViewModel.so2Name,
                                autocapitalization: .words
                            )
                        }
                    }

                    // Times Card
                    EditableCard(title: "Flight Times") {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "Block Time",
                                fieldState: $bulkEditViewModel.blockTime,
                                keyboardType: .decimalPad
                            )

                            BulkEditTextField(
                                label: "Night Time",
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
                    EditableCard(title: "Schedule Times") {
                        VStack(spacing: 12) {
                            BulkEditTextField(
                                label: "OUT Time",
                                fieldState: $bulkEditViewModel.outTime,
                                placeholder: "HH:MM"
                            )

                            BulkEditTextField(
                                label: "IN Time",
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
                    EditableCard(title: "Operations") {
                        VStack(spacing: 12) {
                            BulkEditToggle(
                                label: "Pilot Flying",
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
                    EditableCard(title: "Takeoffs & Landings") {
                        VStack(spacing: 12) {
                            BulkEditIntField(
                                label: "Day Takeoffs",
                                fieldState: $bulkEditViewModel.dayTakeoffs
                            )

                            BulkEditIntField(
                                label: "Day Landings",
                                fieldState: $bulkEditViewModel.dayLandings
                            )

                            BulkEditIntField(
                                label: "Night Takeoffs",
                                fieldState: $bulkEditViewModel.nightTakeoffs
                            )

                            BulkEditIntField(
                                label: "Night Landings",
                                fieldState: $bulkEditViewModel.nightLandings
                            )
                        }
                    }

                    // Remarks Card
                    EditableCard(title: "Remarks") {
                        BulkEditTextEditor(
                            fieldState: $bulkEditViewModel.remarks
                        )
                    }
                }
                .padding()
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
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
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
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            TextField(
                fieldState.isMixed ? "(Mixed)" : (placeholder ?? label),
                text: $textValue
            )
            .textFieldStyle(.roundedBorder)
            .keyboardType(keyboardType)
            .textCase(textCase)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
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
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            TextField(
                fieldState.isMixed ? "(Mixed)" : label,
                text: $textValue
            )
            .textFieldStyle(.roundedBorder)
            .textCase(textCase)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .focused($isFocused)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            TextField(
                fieldState.isMixed ? "(Mixed)" : label,
                text: $textValue
            )
            .textFieldStyle(.roundedBorder)
            .keyboardType(.numberPad)
            .focused($isFocused)
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
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
            } else {
                Toggle("", isOn: $toggleValue)
                    .labelsHidden()
                    .onChange(of: toggleValue) { _, newValue in
                        fieldState = .value(newValue)
                        HapticManager.shared.impact(.light)
                    }
            }
        }
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
        TextEditor(text: $textValue)
            .frame(minHeight: 100)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
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
            .overlay(alignment: .topLeading) {
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

            Spacer()

            if currentType == .mixed {
                Button {
                    // First tap on mixed sets to FLT
                    isPositioning = .value(false)
                    isSimulator = .value(false)
                    HapticManager.shared.impact(.light)
                } label: {
                    Text("(Mixed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
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
                            .frame(width: 50, height: 30)
                            .background(currentType == .flight ? Color.blue : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    // PAX Button
                    Button(action: {
                        isPositioning = .value(true)
                        isSimulator = .value(false)
                        HapticManager.shared.impact(.light)
                    }) {
                        Text("PAX")
                            .font(.subheadline.bold())
                            .foregroundColor(currentType == .positioning ? .white : .secondary)
                            .frame(width: 50, height: 30)
                            .background(currentType == .positioning ? Color.orange : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    // SIM Button
                    Button(action: {
                        isPositioning = .value(false)
                        isSimulator = .value(true)
                        HapticManager.shared.impact(.light)
                    }) {
                        Text("SIM")
                            .font(.subheadline.bold())
                            .foregroundColor(currentType == .simulator ? .white : .secondary)
                            .frame(width: 50, height: 30)
                            .background(currentType == .simulator ? Color.blue : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(6)
            }
        }
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

            Spacer()

            Button(action: {
                if !isDisabled {
                    showingPicker = true
                    HapticManager.shared.impact(.light)
                }
            }) {
                Text(displayText)
                    .font(.caption.bold())
                    .foregroundColor(isOn ? .white : .orange)
                    .frame(width: 60, height: 28)
                    .background(isOn ? Color.orange : Color.clear)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange, lineWidth: 2)
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
    }
}
