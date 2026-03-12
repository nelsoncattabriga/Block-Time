import SwiftUI

// MARK: - Modern Toggles Section
struct ModernTogglesSection: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 18) {

                // First row: PF/PM, APP
                HStack(spacing: 64) {
                    // PF/PM Segmented Picker
                    HStack(spacing: 0) {
                        // PF Button
                        Button(action: {
                            if !viewModel.isPositioning {
                                viewModel.isPilotFlying = true
                                HapticManager.shared.impact(.medium)
                                // When PF is turned on, restore default approach type if set
                                if !viewModel.isEditingMode && viewModel.logApproaches && viewModel.defaultApproachType != nil {
                                    viewModel.updateSelectedApproachType(viewModel.defaultApproachType)
                                }
                            }
                        }) {
                            Text("PF")
                                .font(.subheadline.bold())
                                .foregroundStyle(viewModel.isPilotFlying ? .white : .secondary)
                                .frame(width: 55, height: 30)
                                .background(viewModel.isPilotFlying ? Color.green : Color.clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isPositioning)
                        .opacity(viewModel.isPositioning ? 0.5 : 1.0)

                        // PM Button
                        Button(action: {
                            if !viewModel.isPositioning {
                                viewModel.isPilotFlying = false
                                HapticManager.shared.impact(.medium)
                            }
                        }) {
                            Text("PM")
                                .font(.subheadline.bold())
                                .foregroundStyle(!viewModel.isPilotFlying ? .white : .secondary)
                                .frame(width: 55, height: 30)
                                .background(!viewModel.isPilotFlying ? Color.gray : Color.clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isPositioning)
                        .opacity(viewModel.isPositioning ? 0.5 : 1.0)
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
                            isDisabled: !viewModel.isPilotFlying
                        )
                    }

                    //Spacer()
                }

                // Second row: P1/P1US/P2 Time Credits
                HStack {
                    HStack(alignment:.center, spacing: 0) {
                    // P1 Button
                    Button(action: {
                        if !viewModel.isPositioning {
                            viewModel.selectedTimeCredit = .p1
                            HapticManager.shared.impact(.medium)
                        }
                    }) {
                        Text("P1")
                            .font(.footnote.bold())
                            .foregroundStyle(viewModel.selectedTimeCredit == .p1 ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .background(viewModel.selectedTimeCredit == .p1 ? Color.blue.opacity(0.8) : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isPositioning)
                    .opacity(viewModel.isPositioning ? 0.5 : 1.0)

                    Divider()
                        .frame(height: 24)

                    // P1US Button
                    Button(action: {
                        if !viewModel.isPositioning {
                            viewModel.selectedTimeCredit = .p1us
                            HapticManager.shared.impact(.medium)
                        }
                    }) {
                        Text("ICUS")
                            .font(.footnote.bold())
                            .foregroundStyle(viewModel.selectedTimeCredit == .p1us ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .background(viewModel.selectedTimeCredit == .p1us ? Color.blue.opacity(0.8) : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isPositioning)
                    .opacity(viewModel.isPositioning ? 0.5 : 1.0)

                    Divider()
                        .frame(height: 24)

                    // P2 Button
                    Button(action: {
                        if !viewModel.isPositioning {
                            viewModel.selectedTimeCredit = .p2
                            HapticManager.shared.impact(.medium)
                        }
                    }) {
                        Text("P2")
                            .font(.footnote.bold())
                            .foregroundStyle(viewModel.selectedTimeCredit == .p2 ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .background(viewModel.selectedTimeCredit == .p2 ? Color.blue.opacity(0.8) : Color(.secondarySystemBackground))
                            .contentShape(Rectangle())
                    }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isPositioning)
                        .opacity(viewModel.isPositioning ? 0.5 : 1.0)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                .frame(maxWidth: 300)

            }
            .frame(maxWidth: .infinity)

            .padding(12)
            .background(Color(.systemGray6).opacity(0.75))
            .clipShape(.rect(cornerRadius: 8))

            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )

            // Takeoffs and Landings section - only show when Pilot Flying is selected
            if viewModel.isPilotFlying {
                HStack {
                    Text("T/O & LDG")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ModernIntegerField(
                            label: "Day T/O",
                            value: $viewModel.dayTakeoffs,
                            icon: "airplane.departure",
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )

                        ModernIntegerField(
                            label: "Day LDG",
                            value: $viewModel.dayLandings,
                            icon: "airplane.arrival",
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
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )

                        ModernIntegerField(
                            label: "Night LDG",
                            value: $viewModel.nightLandings,
                            icon: "moon.stars.fill",
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )
                    }
                }
            }
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
                .foregroundStyle(.secondary)

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
                .foregroundStyle(.secondary)

            Button(action: {
                if !isDisabled {
                    showingPicker = true
                    HapticManager.shared.impact(.medium)
                }
            }) {
                HStack(spacing: 4) {
                    Text(displayText)
                        .font(.footnote.bold())
                        .foregroundStyle(isOn ? .white : .secondary)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(isOn ? .white : .secondary)
                }
                .frame(width: 64, height: 28)
                .background(isOn ? Color.orange.opacity(0.8) : Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
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
                    .foregroundStyle(isSelected ? color : .secondary)

            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}
