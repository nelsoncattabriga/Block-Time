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
                if !CustomCounterService.shared.definitions.isEmpty && !viewModel.isPositioning {
                    Divider().padding(.horizontal, 8).padding(.vertical, 4)

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

    private func padHHMM(_ s: String) -> String {
        guard s.contains(":") else { return s }
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              h >= 0, m >= 0, m < 60 else { return s }
        return String(format: "%02d:%02d", h, m)
    }

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
            TextField(showAsHHMM ? "00:00" : "0.0", text: $editingText)
                .font(.subheadline)
                .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : (showAsHHMM ? .numberPad : .decimalPad))
                .focused($isFocused)
                .onChange(of: editingText) { _, newValue in
                    let filtered: String
                    if showAsHHMM {
                        let digitsAndColon = newValue.filter { $0.isNumber || $0 == ":" }
                        // Auto-insert colon when exactly 4 digits typed without one
                        if digitsAndColon.count == 4 && !digitsAndColon.contains(":") {
                            filtered = "\(digitsAndColon.prefix(2)):\(digitsAndColon.suffix(2))"
                        } else {
                            filtered = String(digitsAndColon.prefix(5))
                        }
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
                                editingText = padHHMM(value)
                            } else if let d = Double(value) {
                                editingText = padHHMM(FlightSector.decimalToHHMM(d))
                            } else {
                                editingText = padHHMM(value)
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
                            // Handle bare 4-digit entry (e.g. "0330" → "03:30")
                            let blurInput: String
                            if trimmed.count == 4 && !trimmed.contains(":") && trimmed.allSatisfy(\.isNumber) {
                                blurInput = "\(trimmed.prefix(2)):\(trimmed.suffix(2))"
                            } else {
                                blurInput = trimmed
                            }
                            if blurInput.contains(":"), let decimal = FlightSector.hhmmToDecimal(blurInput) {
                                value = String(format: "%.2f", decimal)
                            } else if let d = Double(blurInput) {
                                value = String(format: "%.2f", d)
                            } else {
                                value = blurInput
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
                            editingText = padHHMM(FlightSector.decimalToHHMM(d))
                        } else {
                            editingText = padHHMM(value)
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
    case .text:
        ModernRemarksField(
            label: definition.label,
            value: binding,
            icon: "text.alignleft",
            placeholder: "Add text...",
            keyboardToolbar: keyboardToolbar
        )
    }
}
