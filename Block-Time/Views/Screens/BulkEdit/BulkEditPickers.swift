//
//  BulkEditPickers.swift
//  Block-Time
//

import SwiftUI

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

// MARK: - BulkEditPrefixManager

struct BulkEditPrefixManager: View {
    var title: String = "Flight Number Prefix"
    @Binding var operationState: BulkEditViewModel.FieldState<BulkEditViewModel.PrefixOperation>
    @Binding var prefixState: BulkEditViewModel.FieldState<String>

    @State private var selectedOperation: BulkEditViewModel.PrefixOperation = .noChange
    @State private var prefixValue: String = ""
    @State private var isIndeterminate: Bool = false
    @FocusState private var isPrefixFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
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
                        selectedOperation == .add ? "Prefix to add" : "Prefix to remove",
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
