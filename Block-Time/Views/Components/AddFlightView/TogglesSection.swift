import SwiftUI
import BlockTimeKit

// MARK: - Modern Toggles Section
struct ModernTogglesSection: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var keyboardToolbar: KeyboardToolbarState? = nil
    private var isDisabled: Bool {
        // Time credit is disabled for positioning, sim, and sim-instruction.
        // Aircraft instruction counts as P1 so credit controls remain enabled.
        viewModel.isPositioning || (viewModel.isSpIns && !viewModel.isInstructingInAircraft)
    }

    private var timeCreditLabel: String {
        switch viewModel.selectedTimeCredit {
        case .p1: return "P1"
        case .p1us: return "ICUS"
        case .p2: return "P2"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card: PF/PM + APP row only
            VStack(spacing: 18) {
                // First row: PF/PM, APP
                HStack(spacing: 64) {
                    // PF/PM Segmented Picker
                    HStack(spacing: 0) {
                        // PF Button
                        Button(action: {
                            if !isDisabled {
                                viewModel.isPilotFlying = true
                                HapticManager.shared.impact(.medium)
                                if !viewModel.isEditingMode && viewModel.logApproaches && viewModel.defaultApproachType != nil {
                                    viewModel.updateSelectedApproachType(viewModel.defaultApproachType)
                                }
                            }
                        }) {
                            Text("PF")
                                .font(.subheadline.bold())
                                .foregroundColor(viewModel.isPilotFlying ? .white : .secondary)
                                .frame(width: 55, height: 30)
                                .background(viewModel.isPilotFlying ? Color.green : Color.clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isDisabled)
                        .opacity(isDisabled ? 0.5 : 1.0)

                        // PM Button
                        Button(action: {
                            if !isDisabled {
                                viewModel.isPilotFlying = false
                                HapticManager.shared.impact(.medium)
                            }
                        }) {
                            Text("PM")
                                .font(.subheadline.bold())
                                .foregroundColor(!viewModel.isPilotFlying ? .white : .secondary)
                                .frame(width: 55, height: 30)
                                .background(!viewModel.isPilotFlying ? Color.gray : Color.clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isDisabled)
                        .opacity(isDisabled ? 0.5 : 1.0)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.isPilotFlying ? Color.green : Color.gray, lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Approach Picker
                    if viewModel.logApproaches {
                        ModernApproachToggle(
                            selectedApproachType: Binding(
                                get: { viewModel.selectedApproachType },
                                set: { newValue in
                                    viewModel.updateSelectedApproachType(newValue)
                                }
                            ),
                            isDisabled: (!viewModel.isPilotFlying && !viewModel.isSimulator) || (viewModel.isSpIns && !viewModel.isInstructingInAircraft)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.systemGray6).opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )

            // Time credit footer note
            if !isDisabled {
                timeCreditFooter
            }

            // Takeoffs and Landings section - only show when Pilot Flying is selected
            if viewModel.isPilotFlying {
                HStack {
                    Text("T/O & LDG")
                        .font(.footnote.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 10)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ModernIntegerField(
                            label: "Day T/O",
                            value: $viewModel.dayTakeoffs,
                            icon: "airplane.departure",
                            keyboardToolbar: keyboardToolbar,
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )

                        ModernIntegerField(
                            label: "Day LDG",
                            value: $viewModel.dayLandings,
                            icon: "airplane.arrival",
                            keyboardToolbar: keyboardToolbar,
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )
                    }

                    HStack(spacing: 8) {
                        ModernIntegerField(
                            label: "Night T/O",
                            value: $viewModel.nightTakeoffs,
                            icon: "moon.fill",
                            keyboardToolbar: keyboardToolbar,
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )

                        ModernIntegerField(
                            label: "Night LDG",
                            value: $viewModel.nightLandings,
                            icon: "moon.stars.fill",
                            keyboardToolbar: keyboardToolbar,
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var timeCreditFooter: some View {
        if !isDisabled {
            HStack(spacing: 6) {
                Spacer()
                Text("Time logged as")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Menu {
                    ForEach([TimeCreditType.p1, .p1us, .p2], id: \.self) { credit in
                        let label: String = credit == .p1us ? "ICUS" : credit.rawValue
                        Button {
                            viewModel.setTimeCreditWithOverride(credit)
                        } label: {
                            if viewModel.selectedTimeCredit == credit {
                                Label(label, systemImage: "checkmark")
                            } else {
                                Text(label)
                            }
                        }
                    }
                    if viewModel.isTimeCreditManualOverride {
                        Divider()
                        Button(role: .destructive) {
                            viewModel.resetTimeCreditOverride()
                        } label: {
                            Label("Reset", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(timeCreditLabel)
                            .font(.footnote.bold())
                            .foregroundColor(viewModel.isTimeCreditManualOverride ? .white : .blue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(viewModel.isTimeCreditManualOverride ? .white.opacity(0.8) : .blue.opacity(0.7))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        viewModel.isTimeCreditManualOverride
                            ? Color.orange.opacity(0.85)
                            : Color.blue.opacity(0.1)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                viewModel.isTimeCreditManualOverride
                                    ? Color.orange
                                    : Color.blue.opacity(0.3),
                                lineWidth: 0.5
                            )
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
    }
}

// MARK: - Modern Toggle
struct ModernToggle: View {
    let title: String
    @Binding var isOn: Bool
    let color: Color
    var isDisabled: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: color))
                .scaleEffect(0.8)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.5 : 1.0)
                .onChange(of: isOn) {
                    HapticManager.shared.impact(.medium) // Light haptic for toggle
                }
        }
    }
}

// MARK: - Modern Approach Toggle
struct ModernApproachToggle: View {
    @Binding var selectedApproachType: String?
    var isDisabled: Bool = false
    @State private var showingPicker = false

    private var isOn: Bool {
        selectedApproachType != nil
    }

    private var displayText: String {
        selectedApproachType ?? "NIL"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("APP")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            Button(action: {
                if !isDisabled {
                    showingPicker = true
                    HapticManager.shared.impact(.medium)
                }
            }) {
                HStack(spacing: 4) {
                    Text(displayText)
                        .font(.footnote.bold())
                        .foregroundColor(isOn ? .white : .secondary)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(isOn ? .white : .secondary)
                }
                .frame(width: 64, height: 28)
                .background(isOn ? Color.orange.opacity(0.8) : Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isOn ? Color.clear : (isDisabled ? Color.secondary.opacity(0.2) : Color.purple.opacity(0.6)), lineWidth: 1)
                )
            }
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
            .confirmationDialog("Select Approach Type", isPresented: $showingPicker, titleVisibility: .visible) {
                Button("NIL") {
                    selectedApproachType = nil
                }
                Button("ILS") {
                    selectedApproachType = "ILS"
                }
                Button("GLS") {
                    selectedApproachType = "GLS"
                }
                Button("RNP") {
                    selectedApproachType = "RNP"
                }
                Button("AIII") {
                    selectedApproachType = "AIII"
                }
                Button("NPA") {
                    selectedApproachType = "NPA"
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

// MARK: - Time Credit Radio Button
struct TimeCreditRadioButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            VStack(spacing: 3) {
                // Radio circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? color : Color.secondary.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 15, height: 15)

                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                    }
                }

                // Title
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? color : .secondary)

            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}
