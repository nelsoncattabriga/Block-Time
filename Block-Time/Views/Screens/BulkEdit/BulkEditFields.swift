//
//  BulkEditFields.swift
//  Block-Time
//

import SwiftUI

// MARK: - BulkEditTextField

struct BulkEditTextField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>
    var textCase: Text.Case? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    var keyboardType: UIKeyboardType = .default
    var placeholder: String? = nil
    var isTimeField: Bool = false
    var showClearButton: Bool = false

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

            HStack(spacing: 0) {
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
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
                .onChange(of: textValue) { _, newValue in
                    let formattedValue = isTimeField ? applyTimeFormatting(newValue) : newValue
                    textValue = formattedValue
                    fieldState = .value(formattedValue)
                }
                .onChange(of: isFocused) { _, focused in
                    if focused && fieldState.isMixed {
                        textValue = ""
                    } else if !focused && isTimeField && !textValue.isEmpty {
                        textValue = formatTimeWithLeadingZeros(textValue)
                        fieldState = .value(textValue)
                    }
                }
                .onAppear {
                    if case .value(let val) = fieldState {
                        textValue = val
                    }
                }

                if showClearButton && (!textValue.isEmpty || fieldState.isMixed) {
                    Button(action: {
                        textValue = ""
                        fieldState = .value("")
                        isFocused = false
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
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
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
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
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
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

// MARK: - BulkEditDateField

struct BulkEditDateField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>

    @State private var selectedDate: Date = Date()
    @State private var showingPicker: Bool = false
    @State private var hasInitialised: Bool = false

    private static let storageFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    private var buttonLabelText: String {
        if case .value(let s) = fieldState, let d = Self.storageFormatter.date(from: s) {
            return Self.displayFormatter.string(from: d)
        }
        if fieldState.isMixed { return "(Mixed)" }
        return "Select date"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button {
                showingPicker = true
                HapticManager.shared.impact(.light)
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text(buttonLabelText)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingPicker) {
            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .presentationDetents([.height(420)])
            .onChange(of: selectedDate) { _, newValue in
                let s = Self.storageFormatter.string(from: newValue)
                fieldState = .value(s)
                showingPicker = false
            }
        }
        .onAppear {
            guard !hasInitialised else { return }
            hasInitialised = true
            if case .value(let s) = fieldState, let d = Self.storageFormatter.date(from: s) {
                selectedDate = d
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
                    }
                    // When .mixed, leave textValue empty — the overlay placeholder shows "(Mixed)"
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
