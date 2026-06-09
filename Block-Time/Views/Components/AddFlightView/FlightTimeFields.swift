import SwiftUI

// MARK: - Modern Time Field
struct ModernTimeField: View {
    let label: String
    @Binding var value: String
    let icon: String
    var isReadOnly: Bool = false
    var dateString: String = ""
    var airportCode: String = ""
    var showLocalTime: Bool = false
    var useIATACodes: Bool = false
    var isRequired: Bool = false
    /// Optional override hint shown below the field. When set, takes priority over the
    /// auto-computed local time hint. Use for "= HH:MM UTC" in local-entry mode.
    var hintText: String? = nil
    /// Optional shared keyboard toolbar state. When set, this field reports its
    /// focus to the shared toolbar instead of owning its own toolbar items.
    var keyboardToolbar: KeyboardToolbarState? = nil
    @FocusState private var timeFieldFocused: Bool
    var onSave: (() -> Void)? = nil

    private func applyFormatting(_ input: String) -> String {
        // Allow only digits and colon; auto-insert colon for 4 digits
        let filtered = input.filter { $0.isNumber || $0 == ":" }
        if filtered.count == 4 && !filtered.contains(":") {
            let hours = String(filtered.prefix(2))
            let minutes = String(filtered.suffix(2))
            return "\(hours):\(minutes)"
        }
        return String(filtered.prefix(5))
    }

    private func formatWithLeadingZeros(_ input: String) -> String {
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

    // Calculate local time for display
    private var localTimeText: String? {
        guard showLocalTime,
              !value.isEmpty,
              !dateString.isEmpty,
              !airportCode.isEmpty else {
            return nil
        }

        let localTime = AirportService.shared.convertToLocalTime(
            utcDateString: dateString,
            utcTimeString: value,
            airportICAO: airportCode
        )

        // Format as HH:MM for display with airport code
        let airportDisplay = AirportService.shared.getDisplayCode(airportCode, useIATA: useIATACodes)
        if localTime.count == 4 {
            let hours = String(localTime.prefix(2))
            let minutes = String(localTime.suffix(2))
            return "\(hours):\(minutes) \(airportDisplay)"
        }
        return "\(localTime) \(airportDisplay)"
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isReadOnly ? .gray : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(label)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    if isRequired && value.isEmpty {
                        Circle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 7, height: 7)
                    }
                }

                if isReadOnly {
                    HStack {
                        Text("")
                            .font(.subheadline.bold())
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    TextField("HH:MM", text: $value)
                        .font(.subheadline.bold())
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad)
                        .focused($timeFieldFocused)
                        .onChange(of: value) { _, newValue in
                            value = applyFormatting(newValue)
                        }
                        .onChange(of: timeFieldFocused) { _, isFocused in
                            if isFocused {
                                keyboardToolbar?.fieldDidFocus(clear: { value = "" })
                            } else {
                                // Format with leading zeros when user finishes editing
                                value = formatWithLeadingZeros(value)
                                onSave?()
                            }
                        }
                        .submitLabel(.done)
                }

                // Show hint: custom override takes priority, then auto local-time hint
                if let hint = hintText {
                    Text(hint)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let localTime = localTimeText {
                    Text(localTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(1.0))
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .opacity(isReadOnly ? 0.75 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReadOnly {
                timeFieldFocused = true
            }
        }
        // No .toolbar here — toolbar is owned by the parent scroll container.
    }
}

// MARK: - Modern Decimal Time Field
struct ModernDecimalTimeField: View {
    let label: String
    @Binding var value: String
    let icon: String
    var isReadOnly: Bool = false
    var showAsHHMM: Bool = false  // Whether to display/accept HH:MM format
    var isRequired: Bool = false
    /// Optional shared keyboard toolbar state.
    var keyboardToolbar: KeyboardToolbarState? = nil
    @FocusState private var decimalFieldFocused: Bool
    var onSave: (() -> Void)? = nil

    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @State private var editingText: String = ""

    private func sanitize(_ input: String) -> String {
        if showAsHHMM {
            // If the incoming value is a decimal (e.g. "1.58" stored while mode was decimal),
            // convert it to HH:MM first so the dot isn't stripped, leaving "158".
            if input.contains("."), let d = Double(input) {
                return FlightSector.decimalToHHMM(d)
            }
            // Allow digits and colon; auto-insert colon on exactly 4 digits without one
            let digitsAndColon = input.filter { $0.isNumber || $0 == ":" }
            if digitsAndColon.count == 4 && !digitsAndColon.contains(":") {
                return "\(digitsAndColon.prefix(2)):\(digitsAndColon.suffix(2))"
            }
            return String(digitsAndColon.prefix(5))
        } else {
            // Allow digits, decimal point, and comma for decimal format
            var result = ""
            var hasSeparator = false
            for ch in input {
                if ch.isNumber {
                    result.append(ch)
                } else if ch == "." || ch == "," {
                    if !hasSeparator {
                        result.append(".")
                        hasSeparator = true
                    }
                }
            }
            return result
        }
    }

    private func formatOnBlur(_ input: String) -> String {
        if showAsHHMM {
            // Normalise bare 4-digit entry (e.g. "0130" → "01:30")
            let blurInput: String
            if input.count == 4 && !input.contains(":") && input.allSatisfy(\.isNumber) {
                blurInput = "\(input.prefix(2)):\(input.suffix(2))"
            } else {
                blurInput = input
            }
            // Convert to HH:MM format
            if blurInput.contains(":") {
                // Already in HH:MM, validate and reformat
                let components = blurInput.split(separator: ":")
                if components.count == 2,
                   let hours = Int(components[0]),
                   let minutes = Int(components[1]),
                   hours >= 0, minutes >= 0, minutes < 60 {
                    return String(format: "%d:%02d", hours, minutes)
                }
            } else if let decimalValue = Double(blurInput) {
                // Convert decimal to HH:MM
                return FlightSector.decimalToHHMM(decimalValue)
            }
            return blurInput.isEmpty ? "0:00" : blurInput
        } else {
            // Format as decimal using the user's rounding mode
            let cleaned = input.replacingOccurrences(of: ",", with: ".")
            if let d = Double(cleaned) {
                let rounded = viewModel.decimalRoundingMode.apply(to: d, decimalPlaces: 1)
                return String(format: "%.1f", rounded)
            }
            return input.isEmpty ? "0.0" : input
        }
    }

    private func convertToDecimalForStorage(_ input: String) -> String {
        if showAsHHMM && input.contains(":") {
            // Convert HH:MM to decimal for storage
            if let decimal = FlightSector.hhmmToDecimal(input) {
                return String(format: "%.2f", decimal)
            }
        }
        return input
    }

    private func formattedDisplayValue() -> String {
        guard !value.isEmpty else { return showAsHHMM ? "0:00" : "0.0" }
        if showAsHHMM {
            if value.contains(":") { return value }
            guard let d = Double(value) else { return "0:00" }
            return FlightSector.decimalToHHMM(d)
        }
        guard let d = Double(value) else { return "0.0" }
        let rounded = viewModel.decimalRoundingMode.apply(to: d, decimalPlaces: 1)
        return String(format: "%.1f", rounded)
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isReadOnly ? .gray : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(label)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    if isRequired && value.isEmpty {
                        Circle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 7, height: 7)
                    }
                }

                if isReadOnly {
                    HStack {
                        Text("")
                            .font(.subheadline.bold())
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    TextField(showAsHHMM ? "00:00" : "0.0", text: $editingText)
                        .font(.subheadline.bold())
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : (showAsHHMM ? .numberPad : .decimalPad))
                        .focused($decimalFieldFocused)
                        .onChange(of: editingText) { _, newValue in
                            editingText = sanitize(newValue)
                        }
                        .onChange(of: decimalFieldFocused) { _, isFocused in
                            if isFocused {
                                // Seed from current value on focus — picks up any auto-calculated result
                                // that arrived before the user starts typing (e.g. block time after tabbing from IN).
                                let numericValue = Double(value) ?? 0
                                editingText = numericValue == 0 ? "" : formattedDisplayValue()
                                keyboardToolbar?.fieldDidFocus(clear: {
                                    value = ""
                                    editingText = ""
                                })
                            } else {
                                // Format, convert to storage format, write back on blur
                                let formatted = formatOnBlur(editingText)
                                let stored = convertToDecimalForStorage(formatted)
                                value = stored
                                editingText = formatted
                                onSave?()
                            }
                        }
                        .onChange(of: value) { _, _ in
                            // Sync external writes (e.g. auto-calculated block time) into editingText,
                            // but skip if the user has started typing partial input. The field is
                            // considered "dirty" when editingText doesn't round-trip back to value —
                            // i.e. the user has typed something that hasn't been committed yet.
                            guard decimalFieldFocused else {
                                editingText = formattedDisplayValue()
                                return
                            }
                            let isDirty: Bool
                            if showAsHHMM {
                                isDirty = !editingText.isEmpty && editingText != formattedDisplayValue()
                            } else {
                                let parsedEditing = Double(editingText) ?? 0
                                let parsedValue = Double(value) ?? 0
                                isDirty = !editingText.isEmpty && parsedEditing != parsedValue
                            }
                            if !isDirty {
                                editingText = formattedDisplayValue()
                            }
                        }
                        .onAppear {
                            editingText = formattedDisplayValue()
                        }
                        .submitLabel(.done)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .opacity(isReadOnly ? 0.75 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReadOnly {
                decimalFieldFocused = true
            }
        }
        // No .toolbar here — toolbar is owned by the parent scroll container.
    }
}

// MARK: - Modern Integer Field
struct ModernIntegerField: View {
    let label: String
    @Binding var value: Int
    let icon: String
    var keyboardToolbar: KeyboardToolbarState? = nil
    var onValueChanged: (() -> Void)? = nil
    @State private var editingText: String = ""
    @FocusState private var integerFieldFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                TextField("0", text: $editingText)
                    .font(.subheadline.bold())
                    .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad)
                    .focused($integerFieldFocused)
                    .onChange(of: editingText) { _, newValue in
                        // Only allow digits
                        let filtered = newValue.filter { $0.isNumber }
                        editingText = filtered
                    }
                    .onChange(of: integerFieldFocused) { _, isFocused in
                        if isFocused {
                            editingText = value == 0 ? "" : "\(value)"
                            keyboardToolbar?.fieldDidFocus(clear: {
                                editingText = ""
                                value = 0
                            })
                        } else {
                            let oldValue = value
                            if let intValue = Int(editingText) {
                                value = max(0, intValue)
                            } else {
                                value = 0
                            }
                            // Trigger callback if value changed
                            if oldValue != value {
                                onValueChanged?()
                            }
                        }
                    }
                    .submitLabel(.done)
                    .onAppear {
                        editingText = value == 0 ? "" : "\(value)"
                    }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            integerFieldFocused = true
        }
        // No .toolbar here — toolbar is owned by the parent scroll container.
    }
}

// MARK: - Modern Remarks Field
struct ModernRemarksField: View {
    let label: String
    @Binding var value: String
    let icon: String
    var placeholder: String = "Add remarks..."
    var keyboardToolbar: KeyboardToolbarState? = nil
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if value.isEmpty {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $value)
                    .font(.subheadline)
                    .frame(minHeight: 40)
                    .focused($editorFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            editorFocused = true
        }
        .onChange(of: editorFocused) { _, isFocused in
            if isFocused {
                keyboardToolbar?.fieldDidFocus(clear: { value = "" })
            }
        }
        // No .toolbar here — toolbar is owned by the parent scroll container.
    }
}
