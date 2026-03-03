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
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                if isReadOnly {
                    HStack {
                        Text(value.isEmpty ? "--:--" : value)
                            .font(.subheadline.bold())
                            .foregroundColor(value.isEmpty ? .secondary : .primary)
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
                            if !isFocused {
                                // Format with leading zeros when user finishes editing
                                value = formatWithLeadingZeros(value)
                                onSave?()
                            }
                        }
                        .submitLabel(.done)
                }

                // Show local time if available
                if let localTime = localTimeText {
                    Text(localTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(1.0))
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReadOnly {
                timeFieldFocused = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if timeFieldFocused {
                    Button("Clear") {
                        value = ""
                        timeFieldFocused = false
                    }
                    .foregroundColor(.red)
                    Spacer()
                    Button("Done") {
                        timeFieldFocused = false
                    }
                    .font(.subheadline.bold())
                }
            }
        }
    }
}

// MARK: - Modern Decimal Time Field
struct ModernDecimalTimeField: View {
    let label: String
    @Binding var value: String
    let icon: String
    var isReadOnly: Bool = false
    var showAsHHMM: Bool = false  // Whether to display/accept HH:MM format
    @FocusState private var decimalFieldFocused: Bool
    var onSave: (() -> Void)? = nil

    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel

    private func sanitize(_ input: String) -> String {
        if showAsHHMM {
            // Allow digits and colon for HH:MM format
            return input.filter { $0.isNumber || $0 == ":" }
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
            // Convert to HH:MM format
            if input.contains(":") {
                // Already in HH:MM, validate and reformat
                let components = input.split(separator: ":")
                if components.count == 2,
                   let hours = Int(components[0]),
                   let minutes = Int(components[1]),
                   hours >= 0, minutes >= 0, minutes < 60 {
                    return String(format: "%d:%02d", hours, minutes)
                }
            } else if let decimalValue = Double(input) {
                // Convert decimal to HH:MM
                return FlightSector.decimalToHHMM(decimalValue)
            }
            return input.isEmpty ? "0:00" : input
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

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isReadOnly ? .gray : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                if isReadOnly {
                    HStack {
                        Text(displayValue)
                            .font(.subheadline.bold())
                            .foregroundColor(value.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    TextField(showAsHHMM ? "0:00" : "0.0", text: Binding(
                        get: {
                            // When field is focused or empty, show raw value
                            // When not focused, show formatted value
                            if decimalFieldFocused || value.isEmpty {
                                return value
                            } else {
                                return displayValue
                            }
                        },
                        set: { newValue in
                            value = sanitize(newValue)
                        }
                    ))
                        .font(.subheadline.bold())
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                        .focused($decimalFieldFocused)
                        .onChange(of: decimalFieldFocused) { _, isFocused in
                            if !isFocused {
                                // Convert to decimal for storage, then format for display
                                let decimalValue = convertToDecimalForStorage(value)
                                value = decimalValue
                                onSave?()
                            }
                        }
                        .submitLabel(.done)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReadOnly {
                decimalFieldFocused = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if decimalFieldFocused {
                    Button("Clear") {
                        value = ""
                        decimalFieldFocused = false
                    }
                    .foregroundColor(.red)
                    Spacer()
                    Button("Done") {
                        decimalFieldFocused = false
                    }
                    .font(.subheadline.bold())
                }
            }
        }
    }

    private var displayValue: String {
        guard !value.isEmpty, let decimalValue = Double(value) else {
            return showAsHHMM ? "0:00" : "0.0"
        }

        if showAsHHMM {
            return FlightSector.decimalToHHMM(decimalValue)
        } else {
            // Apply the user's rounding mode for consistent display
            let rounded = viewModel.decimalRoundingMode.apply(to: decimalValue, decimalPlaces: 1)
            return String(format: "%.1f", rounded)
        }
    }
}

// MARK: - Modern Integer Field
struct ModernIntegerField: View {
    let label: String
    @Binding var value: Int
    let icon: String
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if integerFieldFocused {
                    Spacer()
                    Button("Done"){
                        integerFieldFocused = false
                    }
                    .font(.subheadline.bold())
                }
            }
        }
    }
}

// MARK: - Modern Remarks Field
struct ModernRemarksField: View {
    let label: String
    @Binding var value: String
    let icon: String
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if value.isEmpty {
                    Text("Add remarks...")
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if editorFocused {
                    Spacer()
                    Button("Done"){
                        editorFocused = false
                    }
                    .font(.subheadline.bold())
                }
            }
        }
    }
}
