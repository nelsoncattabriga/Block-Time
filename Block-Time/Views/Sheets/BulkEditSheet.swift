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
    var isTimeField: Bool = false

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private func applyTimeFormatting(_ input: String) -> String {
        // Allow only digits and colon; auto-insert colon for 4 digits
        let filtered = input.filter { $0.isNumber || $0 == ":" }
        if filtered.count == 4 && !filtered.contains(":") {
            let hours = String(filtered.prefix(2))
            let minutes = String(filtered.suffix(2))
            return "\(hours):\(minutes)"
        }
        return String(filtered.prefix(5))
    }

    private func formatTimeWithLeadingZeros(_ input: String) -> String {
        // Parse and reformat to ensure HH:MM format with leading zeros
        if input.contains(":") {
            let components = input.split(separator: ":")
            if components.count == 2,
               let hours = Int(components[0]),
               let minutes = Int(components[1]),
               hours < 24, minutes < 60 {
                return String(format: "%02d:%02d", hours, minutes)
            }
        }
        // If already valid or can't parse, return as-is
        return input
    }

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
                let formattedValue = isTimeField ? applyTimeFormatting(newValue) : newValue
                textValue = formattedValue
                fieldState = .value(formattedValue)
            }
            .onChange(of: isFocused) { _, focused in
                if focused && fieldState.isMixed {
                    textValue = ""
                } else if !focused && isTimeField && !textValue.isEmpty {
                    // Format with leading zeros when user finishes editing
                    textValue = formatTimeWithLeadingZeros(textValue)
                    fieldState = .value(textValue)
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
    var keyboardType: UIKeyboardType = .numberPad

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
            .keyboardType(keyboardType)
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

            //Spacer()

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
                            .frame(width: 55, height: 28)
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
                            .frame(width: 55, height: 28)
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
                            .frame(width: 55, height: 28)
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

// MARK: - BulkEditPilotRoleSegmentedPicker

struct BulkEditPilotRoleSegmentedPicker: View {
    @Binding var fieldState: BulkEditViewModel.FieldState<Bool>

    @State private var isPilotFlying: Bool = true
    @State private var isIndeterminate: Bool = false

    var body: some View {
        HStack {
            Text("Role")
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            if isIndeterminate {
                Button {
                    // First tap on mixed sets to PF
                    isIndeterminate = false
                    isPilotFlying = true
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
                HStack(spacing: 0) {
                    // PF Button
                    Button(action: {
                        isPilotFlying = true
                        fieldState = .value(true)
                        HapticManager.shared.impact(.light)
                    }) {
                        Text("PF")
                            .font(.subheadline.bold())
                            .foregroundColor(isPilotFlying ? .white : .secondary)
                            .frame(width: 55, height: 28)
                            .background(isPilotFlying ? Color.green : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()
                        .frame(height: 20)

                    // PM Button
                    Button(action: {
                        isPilotFlying = false
                        fieldState = .value(false)
                        HapticManager.shared.impact(.light)
                    }) {
                        Text("PM")
                            .font(.subheadline.bold())
                            .foregroundColor(!isPilotFlying ? .white : .secondary)
                            .frame(width: 55, height: 28)
                            .background(!isPilotFlying ? Color.gray : Color(.secondarySystemBackground))
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
        .onAppear {
            if case .value(let pf) = fieldState {
                isPilotFlying = pf
                isIndeterminate = false
            } else if fieldState.isMixed {
                isIndeterminate = true
            }
        }
    }
}

// MARK: - BulkEditTimeCreditRadioButton

struct BulkEditTimeCreditRadioButton: View {
    @Binding var fieldState: BulkEditViewModel.FieldState<TimeCreditType>
    let isDisabled: BulkEditViewModel.FieldState<Bool>

    @State private var selectedCredit: TimeCreditType = .p1
    @State private var isIndeterminate: Bool = false

    private var isActuallyDisabled: Bool {
        if case .value(let disabled) = isDisabled {
            return disabled
        }
        return false
    }

    var body: some View {
        Group {
            if isIndeterminate {
                Button {
                    // First tap on mixed sets to P1
                    isIndeterminate = false
                    selectedCredit = .p1
                    fieldState = .value(.p1)
                    HapticManager.shared.impact(.light)
                } label: {
                    Text("(Mixed)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
            } else {
                HStack(spacing: 0) {
                    // P1 Button
                    Button(action: {
                        if !isActuallyDisabled {
                            selectedCredit = .p1
                            fieldState = .value(.p1)
                            HapticManager.shared.impact(.light)
                        }
                    }) {
                        Text("P1")
                            .font(.subheadline.bold())
                            .foregroundColor(selectedCredit == .p1 ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(selectedCredit == .p1 ? Color.blue : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isActuallyDisabled)
                    .opacity(isActuallyDisabled ? 0.5 : 1.0)

                    Divider()
                        .frame(height: 20)

                    // P1US Button
                    Button(action: {
                        if !isActuallyDisabled {
                            selectedCredit = .p1us
                            fieldState = .value(.p1us)
                            HapticManager.shared.impact(.light)
                        }
                    }) {
                        Text("P1US")
                            .font(.subheadline.bold())
                            .foregroundColor(selectedCredit == .p1us ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(selectedCredit == .p1us ? Color.blue : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isActuallyDisabled)
                    .opacity(isActuallyDisabled ? 0.5 : 1.0)

                    Divider()
                        .frame(height: 20)

                    // P2 Button
                    Button(action: {
                        if !isActuallyDisabled {
                            selectedCredit = .p2
                            fieldState = .value(.p2)
                            HapticManager.shared.impact(.light)
                        }
                    }) {
                        Text("P2")
                            .font(.subheadline.bold())
                            .foregroundColor(selectedCredit == .p2 ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(selectedCredit == .p2 ? Color.blue : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isActuallyDisabled)
                    .opacity(isActuallyDisabled ? 0.5 : 1.0)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .onAppear {
            if case .value(let credit) = fieldState {
                selectedCredit = credit
                isIndeterminate = false
            } else if fieldState.isMixed {
                isIndeterminate = true
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
                .fontWeight(.medium)

            Spacer()

            Button(action: {
                if !isDisabled {
                    showingPicker = true
                    HapticManager.shared.impact(.light)
                }
            }) {
                HStack(spacing: 4) {
                    Text(displayText)
                        .font(.subheadline.bold())
                        .foregroundColor(isOn ? .white : .secondary)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(isOn ? .white : .secondary)
                }
                .frame(height: 28)
                .padding(.horizontal, 12)
                .background(isOn ? Color.orange : Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
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

// MARK: - BulkEditCrewField

struct BulkEditCrewField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>
    let savedNames: [String]
    var recentNames: [String] = []
    let onNameAdded: (String) -> Void
    let onNameRemoved: ((String) -> Void)?
    let icon: String

    @State private var textValue: String = ""
    @State private var showingPicker = false
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: icon)
                    .foregroundColor(.green)
                    .frame(width: 20)

                Button(action: {
                    searchText = textValue
                    showingPicker = true
                }) {
                    HStack {
                        Text(fieldState.isMixed ? "(Mixed)" : (textValue.isEmpty ? "Select crew..." : textValue))
                            .font(.body)
                            .foregroundColor(fieldState.isMixed ? .secondary : (textValue.isEmpty ? .secondary : .primary))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .sheet(isPresented: $showingPicker) {
                CrewNamePickerSheet(
                    title: label,
                    selectedName: $textValue,
                    searchText: $searchText,
                    savedNames: savedNames,
                    recentNames: recentNames,
                    onNameAdded: onNameAdded,
                    onNameRemoved: onNameRemoved,
                    onDismiss: {
                        showingPicker = false
                        searchText = ""
                        fieldState = .value(textValue)
                    }
                )
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val
                }
            }
        }
    }
}

// MARK: - BulkEditOptionalCrewField

struct BulkEditOptionalCrewField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String?>
    let savedNames: [String]
    var recentNames: [String] = []
    let onNameAdded: (String) -> Void
    let onNameRemoved: ((String) -> Void)?
    let icon: String

    @State private var textValue: String = ""
    @State private var showingPicker = false
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: icon)
                    .foregroundColor(.green)
                    .frame(width: 20)

                Button(action: {
                    searchText = textValue
                    showingPicker = true
                }) {
                    HStack {
                        Text(fieldState.isMixed ? "(Mixed)" : (textValue.isEmpty ? "Select crew..." : textValue))
                            .font(.body)
                            .foregroundColor(fieldState.isMixed ? .secondary : (textValue.isEmpty ? .secondary : .primary))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .sheet(isPresented: $showingPicker) {
                CrewNamePickerSheet(
                    title: label,
                    selectedName: $textValue,
                    searchText: $searchText,
                    savedNames: savedNames,
                    recentNames: recentNames,
                    onNameAdded: onNameAdded,
                    onNameRemoved: onNameRemoved,
                    onDismiss: {
                        showingPicker = false
                        searchText = ""
                        fieldState = .value(textValue.isEmpty ? nil : textValue)
                    }
                )
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val ?? ""
                }
            }
        }
    }
}

// MARK: - BulkEditAircraftRegField

struct BulkEditAircraftRegField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>
    let showFullReg: Bool
    @Binding var aircraftTypeFieldState: BulkEditViewModel.FieldState<String>

    @State private var textValue: String = ""
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button(action: {
                showingPicker = true
            }) {
                HStack {
                    Text(fieldState.isMixed ? "(Mixed)" : (textValue.isEmpty ? "Select aircraft..." : textValue))
                        .font(.body)
                        .foregroundColor(fieldState.isMixed ? .secondary : (textValue.isEmpty ? .secondary : .primary))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .sheet(isPresented: $showingPicker) {
                BulkEditAircraftPickerSheet(
                    selectedReg: $textValue,
                    selectedType: Binding(
                        get: {
                            if case .value(let type) = aircraftTypeFieldState {
                                return type
                            }
                            return ""
                        },
                        set: { newType in
                            if !newType.isEmpty {
                                aircraftTypeFieldState = .value(newType)
                            }
                        }
                    ),
                    showFullReg: showFullReg,
                    onDismiss: {
                        showingPicker = false
                        fieldState = .value(textValue)
                    }
                )
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val
                }
            }
        }
    }
}

// MARK: - BulkEditAircraftPickerSheet

struct BulkEditAircraftPickerSheet: View {
    @Binding var selectedReg: String
    @Binding var selectedType: String
    let showFullReg: Bool
    let onDismiss: () -> Void

    @StateObject private var fleetService = AircraftFleetService.shared
    @State private var availableFleets: [Fleet] = []
    @State private var selectedFleet: Fleet?
    @State private var otherFleets: [Fleet] = []
    @AppStorage("selectedFleetID") private var selectedFleetID: String = "B737"
    @State private var searchText = ""
    @State private var filteredAircraftByFleet: [(fleet: Fleet, aircraft: [Aircraft])] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var showingAddAircraftSheet = false

    private func loadFleets() {
        availableFleets = fleetService.getAvailableFleetsWithCustom()
        selectedFleet = availableFleets.first(where: { $0.id == selectedFleetID }) ?? availableFleets.first
        otherFleets = availableFleets.filter { fleet in fleet.id != selectedFleetID }
        updateFilteredAircraft()
    }

    private func updateFilteredAircraft() {
        var fleetAircraftPairs: [(fleet: Fleet, aircraft: [Aircraft])] = []

        if searchText.isEmpty {
            if let selectedFleet = selectedFleet {
                fleetAircraftPairs.append((fleet: selectedFleet, aircraft: selectedFleet.aircraft))
            }
            for fleet in otherFleets {
                fleetAircraftPairs.append((fleet: fleet, aircraft: fleet.aircraft))
            }
        } else {
            let lowercaseSearch = searchText.lowercased()
            if let selectedFleet = selectedFleet {
                let filtered = selectedFleet.aircraft.filter {
                    $0.registration.lowercased().contains(lowercaseSearch) ||
                    $0.type.lowercased().contains(lowercaseSearch)
                }
                if !filtered.isEmpty {
                    fleetAircraftPairs.append((fleet: selectedFleet, aircraft: filtered))
                }
            }
            for fleet in otherFleets {
                let filtered = fleet.aircraft.filter {
                    $0.registration.lowercased().contains(lowercaseSearch) ||
                    $0.type.lowercased().contains(lowercaseSearch)
                }
                if !filtered.isEmpty {
                    fleetAircraftPairs.append((fleet: fleet, aircraft: filtered))
                }
            }
        }
        filteredAircraftByFleet = fleetAircraftPairs
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    updateFilteredAircraft()
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar and Add Button Section
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Search aircraft...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .onChange(of: searchText) {
                                if searchText.isEmpty {
                                    updateFilteredAircraft()
                                } else {
                                    debounceSearch()
                                }
                            }

                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                                updateFilteredAircraft()
                            }
                            .foregroundColor(.blue)
                        }
                    }

                    // Add New Aircraft Button
                    Button(action: {
                        showingAddAircraftSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add New Aircraft")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color(.systemGroupedBackground))

                // Aircraft List
                List {
                    ForEach(filteredAircraftByFleet, id: \.fleet.id) { fleetPair in
                        Section(header: Text(fleetPair.fleet.name)) {
                            ForEach(fleetPair.aircraft) { aircraft in
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    selectedReg = aircraft.registration
                                    selectedType = aircraft.type
                                    onDismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(aircraft.displayRegistration(showFullReg: showFullReg))
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(aircraft.type)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedReg == aircraft.registration {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    if filteredAircraftByFleet.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: searchText.isEmpty ? "airplane" : "magnifyingglass")
                                    .foregroundColor(.gray)
                                Text(searchText.isEmpty ? "No aircraft in fleet" : "No matching aircraft found")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Select Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !selectedReg.isEmpty {
                        Button("Clear") {
                            HapticManager.shared.impact(.light)
                            selectedReg = ""
                            selectedType = ""
                            onDismiss()
                        }
                        .foregroundColor(.red)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingAddAircraftSheet) {
            BulkEditAddAircraftSheet(
                selectedReg: $selectedReg,
                selectedType: $selectedType,
                fleetService: fleetService,
                onDismiss: {
                    showingAddAircraftSheet = false
                    loadFleets()
                    onDismiss()
                }
            )
        }
        .onAppear {
            loadFleets()
        }
        .onDisappear {
            searchText = ""
        }
    }
}

// MARK: - BulkEditAddAircraftSheet

struct BulkEditAddAircraftSheet: View {
    @Binding var selectedReg: String
    @Binding var selectedType: String
    @ObservedObject var fleetService: AircraftFleetService
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var newAircraftReg: String = ""
    @State private var newAircraftType: String = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case registration, type
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Aircraft Details")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Registration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., VH-ABC", text: $newAircraftReg)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .registration)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .type
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aircraft Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., B738", text: $newAircraftType)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .type)
                            .submitLabel(.done)
                            .onSubmit {
                                saveAircraft()
                            }
                    }
                }

                Section {
                    Button(action: saveAircraft) {
                        HStack {
                            Spacer()
                            Text("Add Aircraft")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(newAircraftReg.isEmpty || newAircraftType.isEmpty)
                }
            }
            .navigationTitle("Add New Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                focusedField = .registration
            }
        }
    }

    private func saveAircraft() {
        guard !newAircraftReg.isEmpty && !newAircraftType.isEmpty else { return }

        let trimmedReg = newAircraftReg.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedType = newAircraftType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Create new aircraft
        let aircraft = Aircraft(registration: trimmedReg, type: trimmedType)

        // Save to fleet service
        let success = fleetService.saveAircraft(aircraft)

        if success {
            // Update the selected values
            selectedReg = trimmedReg
            selectedType = trimmedType

            HapticManager.shared.impact(.medium)
        }

        onDismiss()
    }
}

// MARK: - BulkEditAircraftTypeField

struct BulkEditAircraftTypeField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>

    @State private var textValue: String = ""
    @State private var showingPicker = false
    @State private var searchText = ""
    @State private var availableTypes: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button(action: {
                // Load existing aircraft types from database
                loadAircraftTypes()
                searchText = textValue
                showingPicker = true
            }) {
                HStack {
                    Text(fieldState.isMixed ? "(Mixed)" : (textValue.isEmpty ? "Select type..." : textValue))
                        .font(.body)
                        .foregroundColor(fieldState.isMixed ? .secondary : (textValue.isEmpty ? .secondary : .primary))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .sheet(isPresented: $showingPicker) {
                AircraftTypePickerSheet(
                    title: label,
                    selectedType: $textValue,
                    searchText: $searchText,
                    availableTypes: availableTypes,
                    onDismiss: {
                        showingPicker = false
                        searchText = ""
                        fieldState = .value(textValue)
                    }
                )
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val
                }
            }
        }
    }

    private func loadAircraftTypes() {
        // Get all flights from database
        let flights = FlightDatabaseService.shared.fetchAllFlights()

        // Extract unique aircraft types and sort them
        let uniqueTypes = Set(flights.map { $0.aircraftType.uppercased() }.filter { !$0.isEmpty })
        availableTypes = Array(uniqueTypes).sorted()
    }
}

// MARK: - AircraftTypePickerSheet

struct AircraftTypePickerSheet: View {
    let title: String
    @Binding var selectedType: String
    @Binding var searchText: String
    let availableTypes: [String]
    let onDismiss: () -> Void

    private var filteredTypes: [String] {
        if searchText.isEmpty {
            return availableTypes
        } else {
            return availableTypes.filter { type in
                type.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search field and actions
                VStack(spacing: 12) {
                    TextField("Search or enter new type...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .padding(.horizontal)

                    // Action buttons for search text
                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 12) {
                            // Use current search text button
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                let trimmedType = searchText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                selectedType = trimmedType
                                onDismiss()
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Use \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())\"")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(20)
                            }

                            Spacer()

                            // Clear search button
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGroupedBackground))

                // Results list
                List {
                    if !filteredTypes.isEmpty {
                        Section(
                            header: Text(searchText.isEmpty ? "All Aircraft Types" : "Matching Types")
                        ) {
                            ForEach(filteredTypes, id: \.self) { type in
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    selectedType = type
                                    onDismiss()
                                }) {
                                    HStack {
                                        Text(type)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedType.uppercased() == type.uppercased() {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    } else if !searchText.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                Text("No matching types found")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    } else if availableTypes.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: "airplane")
                                    .foregroundColor(.gray)
                                Text("No aircraft types in database yet")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !selectedType.isEmpty {
                        Button("Clear Type") {
                            HapticManager.shared.impact(.light)
                            selectedType = ""
                            onDismiss()
                        }
                        .foregroundColor(.red)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            searchText = ""
        }
    }
}

// MARK: - BulkEditPrefixManager

struct BulkEditPrefixManager: View {
    @Binding var operationState: BulkEditViewModel.FieldState<BulkEditViewModel.PrefixOperation>
    @Binding var prefixState: BulkEditViewModel.FieldState<String>

    @State private var selectedOperation: BulkEditViewModel.PrefixOperation = .noChange
    @State private var prefixValue: String = ""
    @State private var isIndeterminate: Bool = false
    @FocusState private var isPrefixFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Flight Number Prefix")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                // Operation Selector
                if isIndeterminate {
                    Button {
                        // First tap on mixed sets to No Change
                        isIndeterminate = false
                        selectedOperation = .noChange
                        operationState = .value(.noChange)
                        HapticManager.shared.impact(.light)
                    } label: {
                        Text("(Mixed)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                } else {
                    HStack(spacing: 0) {
                        // No Change Button
                        Button(action: {
                            selectedOperation = .noChange
                            operationState = .value(.noChange)
                            isPrefixFieldFocused = false
                            HapticManager.shared.impact(.light)
                        }) {
                            Text("No Change")
                                .font(.subheadline.bold())
                                .foregroundColor(selectedOperation == .noChange ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                                .background(selectedOperation == .noChange ? Color.gray : Color(.secondarySystemBackground))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                            .frame(height: 20)

                        // Add Button
                        Button(action: {
                            selectedOperation = .add
                            operationState = .value(.add)
                            HapticManager.shared.impact(.light)
                        }) {
                            Text("Add")
                                .font(.subheadline.bold())
                                .foregroundColor(selectedOperation == .add ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                                .background(selectedOperation == .add ? Color.green : Color(.secondarySystemBackground))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                            .frame(height: 20)

                        // Remove Button
                        Button(action: {
                            selectedOperation = .remove
                            operationState = .value(.remove)
                            HapticManager.shared.impact(.light)
                        }) {
                            Text("Remove")
                                .font(.subheadline.bold())
                                .foregroundColor(selectedOperation == .remove ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                                .background(selectedOperation == .remove ? Color.red : Color(.secondarySystemBackground))
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

                // Prefix Text Field (only show when Add or Remove is selected)
                if selectedOperation != .noChange && !isIndeterminate {
                    TextField(
                        selectedOperation == .add ? "Prefix to add (e.g., QF)" : "Prefix to remove (e.g., QF)",
                        text: $prefixValue
                    )
                    .textCase(.uppercase)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isPrefixFieldFocused)
                    .font(.body)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isPrefixFieldFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
                    .onChange(of: prefixValue) { _, newValue in
                        let uppercased = newValue.uppercased()
                        prefixValue = uppercased
                        prefixState = .value(uppercased)
                    }
                }
            }
        }
        .onAppear {
            if case .value(let operation) = operationState {
                selectedOperation = operation
                isIndeterminate = false
            } else if operationState.isMixed {
                isIndeterminate = true
            }

            if case .value(let prefix) = prefixState {
                prefixValue = prefix
            }
        }
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

