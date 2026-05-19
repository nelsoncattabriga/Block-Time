import SwiftUI

// MARK: - Custom Counter Input Field

struct CustomCountField: View {
    let label: String
    @Binding var count: Int
    var keyboardToolbar: KeyboardToolbarState? = nil

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "person.2.badge.plus")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            TextField("0", text: $text)
                .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad)
                .font(.subheadline)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        text = filtered
                    }
                    if let parsed = Int(filtered), parsed >= 0 {
                        count = min(parsed, 9999)
                        if parsed > 9999 { text = "9999" }
                    } else if filtered.isEmpty {
                        count = 0
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        keyboardToolbar?.fieldDidFocus(clear: {
                            text = ""
                            count = 0
                        })
                    }
                }
                .onAppear {
                    text = count > 0 ? "\(count)" : ""
                }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
    }
}

// MARK: - Modern Manual Entry Data Card
struct ModernManualEntryDataCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var keyboardToolbar: KeyboardToolbarState? = nil

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                    .font(.title3)

                Text("Crew & Ops Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {

                // Aircraft registration field - disabled for positioning flights
                ModernAircraftRegField(viewModel: viewModel, isDisabled: viewModel.isPositioning)

                // All crew fields on separate lines - disabled for positioning flights
                VStack(spacing: 8) {
                    ModernCrewField(
                        label: "CAPTAIN",
                        value: Binding(
                            get: { viewModel.captainName },
                            set: { viewModel.updateCaptainName($0) }
                        ),
                        savedNames: viewModel.savedCaptainNames,
                        recentNames: viewModel.recentCaptainNames,
                        onNameAdded: viewModel.addCaptainName,
                        onNameRemoved: viewModel.removeCaptainName,
                        icon: "person",
                        isDisabled: viewModel.isPositioning
                    )

                    ModernCrewField(
                        label: "F/O",
                        value: Binding(
                            get: { viewModel.coPilotName },
                            set: { viewModel.updateCoPilotName($0) }
                        ),
                        savedNames: viewModel.savedCoPilotNames,
                        recentNames: viewModel.recentCoPilotNames,
                        onNameAdded: viewModel.addCoPilotName,
                        onNameRemoved: viewModel.removeCoPilotName,
                        icon: "person",
                        isDisabled: viewModel.isPositioning
                    )

                    // Conditionally show SO fields
                    if viewModel.showSONameFields {
                        ModernCrewField(
                            label: "S/O 1",
                            value: Binding(
                                get: { viewModel.so1Name },
                                set: { viewModel.updateSO1Name($0) }
                            ),
                            savedNames: viewModel.savedSONames,
                            recentNames: viewModel.recentSONames,
                            onNameAdded: viewModel.addSOName,
                            onNameRemoved: viewModel.removeSOName,
                            icon: "person",
                            isDisabled: viewModel.isPositioning
                        )

                        ModernCrewField(
                            label: "S/O 2",
                            value: Binding(
                                get: { viewModel.so2Name },
                                set: { viewModel.updateSO2Name($0) }
                            ),
                            savedNames: viewModel.savedSONames,
                            recentNames: viewModel.recentSONames,
                            onNameAdded: viewModel.addSOName,
                            onNameRemoved: viewModel.removeSOName,
                            icon: "person",
                            isDisabled: viewModel.isPositioning
                        )
                    }
                }
                // Toggles section
                ModernTogglesSection(viewModel: viewModel, keyboardToolbar: keyboardToolbar)

                // Custom counters
                if viewModel.logCustomCount && !viewModel.isPositioning {
                    Divider().padding(.horizontal, 8).padding(.vertical, 4)

                    let migrated = UserDefaults.standard.bool(forKey: "legacyCounterMigratedToColumn1")

                    // Legacy single counter — hidden once migrated to counter1
                    if !migrated {
                        FieldIntegerField(
                            label: viewModel.customCountLabel,
                            value: Binding(
                                get: { viewModel.customCount > 0 ? "\(viewModel.customCount)" : "" },
                                set: { viewModel.customCount = Int($0) ?? 0 }
                            ),
                            keyboardToolbar: keyboardToolbar
                        )
                    }

                    // Multi-counters
                    ForEach(CustomCounterService.shared.definitions) { definition in
                        fieldRow(for: definition, viewModel: viewModel, keyboardToolbar: keyboardToolbar)
                    }
                }
                
                // Remarks section
                ModernRemarksField(
                    label: "REMARKS",
                    value: Binding(
                        get: { viewModel.remarks },
                        set: { viewModel.remarks = $0 }
                    ),
                    icon: "note.text",
                    keyboardToolbar: keyboardToolbar
                )
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Field types (shared by CrewOpsCard)

struct FieldTimeField: View {
    let label: String
    @Binding var value: String
    var keyboardToolbar: KeyboardToolbarState?
    @FocusState private var isFocused: Bool
    @State private var editingText: String = ""
    @AppStorage("showTimesInHoursMinutes") private var showAsHHMM: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            TextField(showAsHHMM ? "0:00" : "0.0", text: $editingText)
                .font(.subheadline)
                .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                .focused($isFocused)
                .onChange(of: editingText) { _, newValue in
                    let filtered: String
                    if showAsHHMM {
                        filtered = newValue.filter { $0.isNumber || $0 == ":" }
                    } else {
                        var result = ""
                        var hasDot = false
                        for ch in newValue {
                            if ch.isNumber { result.append(ch) }
                            else if (ch == "." || ch == ",") && !hasDot { result.append("."); hasDot = true }
                        }
                        filtered = result
                    }
                    if filtered != newValue { editingText = filtered }
                }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        if value.isEmpty || value == "0:00" || value == "0.0" {
                            editingText = ""
                        } else if showAsHHMM {
                            if value.contains(":") {
                                editingText = value
                            } else if let d = Double(value) {
                                editingText = FlightSector.decimalToHHMM(d)
                            } else {
                                editingText = value
                            }
                        } else {
                            // decimal mode: value is stored as decimal string
                            editingText = value.contains(":") ? (FlightSector.hhmmToDecimal(value).map { String(format: "%.1f", $0) } ?? value) : value
                        }
                        keyboardToolbar?.fieldDidFocus(clear: {
                            editingText = ""
                            value = ""
                        })
                    } else {
                        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            value = ""
                        } else if showAsHHMM {
                            if trimmed.contains(":"), let decimal = FlightSector.hhmmToDecimal(trimmed) {
                                value = String(format: "%.1f", decimal)
                            } else if let d = Double(trimmed) {
                                value = String(format: "%.1f", d)
                            } else {
                                value = trimmed
                            }
                        } else {
                            if let d = Double(trimmed) {
                                value = String(format: "%.1f", d)
                            } else {
                                value = trimmed
                            }
                        }
                    }
                }
                .onAppear {
                    if value.isEmpty || value == "0.0" || value == "0:00" {
                        editingText = ""
                    } else if showAsHHMM {
                        if let d = Double(value) {
                            editingText = FlightSector.decimalToHHMM(d)
                        } else {
                            editingText = value
                        }
                    } else {
                        editingText = value.contains(":") ? (FlightSector.hhmmToDecimal(value).map { String(format: "%.1f", $0) } ?? value) : value
                    }
                }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FieldDecimalField: View {
    let label: String
    @Binding var value: String
    var keyboardToolbar: KeyboardToolbarState?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "number.circle.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 20)
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            TextField("0.0", text: $value)
                .font(.subheadline)
                .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                .focused($isFocused)
                .onChange(of: value) { _, newValue in
                    var result = ""
                    var hasDot = false
                    for ch in newValue {
                        if ch.isNumber {
                            result.append(ch)
                        } else if (ch == "." || ch == ",") && !hasDot {
                            result.append(".")
                            hasDot = true
                        }
                    }
                    if result != newValue { value = result }
                }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        if value == "0.0" || value == "0" { value = "" }
                        keyboardToolbar?.fieldDidFocus(clear: { value = "" })
                    }
                }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FieldIntegerField: View {
    let label: String
    @Binding var value: String
    var keyboardToolbar: KeyboardToolbarState?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "number.square.fill")
                    .foregroundStyle(.teal)
                    .frame(width: 20)
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            TextField("0", text: $value)
                .font(.subheadline)
                .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad)
                .focused($isFocused)
                .onChange(of: value) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue { value = filtered }
                }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        if value == "0" { value = "" }
                        keyboardToolbar?.fieldDidFocus(clear: { value = "" })
                    }
                }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Field row dispatcher

@ViewBuilder
private func fieldRow(for definition: CustomCounterDefinition, viewModel: FlightTimeExtractorViewModel, keyboardToolbar: KeyboardToolbarState?) -> some View {
    let binding = Binding<String>(
        get: { viewModel.counterValues[definition.columnIndex] ?? "" },
        set: { viewModel.counterValues[definition.columnIndex] = $0 }
    )
    switch definition.type {
    case .time:
        FieldTimeField(label: definition.label, value: binding, keyboardToolbar: keyboardToolbar)
    case .decimal:
        FieldDecimalField(label: definition.label, value: binding, keyboardToolbar: keyboardToolbar)
    case .integer:
        FieldIntegerField(label: definition.label, value: binding, keyboardToolbar: keyboardToolbar)
    }
}
