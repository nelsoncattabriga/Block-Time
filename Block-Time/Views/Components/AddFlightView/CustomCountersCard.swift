//
//  CustomCountersCard.swift
//  Block-Time
//
//  Add/Edit flight form section rendering one input field per user-defined counter.
//

import SwiftUI

struct CustomCountersCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var keyboardToolbar: KeyboardToolbarState? = nil

    var body: some View {
        let definitions = CustomCounterService.shared.definitions
        guard !definitions.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.indigo)
                        .font(.title3)

                    Text("Custom Counters")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()
                }

                VStack(spacing: 12) {
                    ForEach(definitions) { definition in
                        counterRow(for: definition)
                    }
                }
            }
            .padding(16)
            .background(.thinMaterial)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
            )
        )
    }

    @ViewBuilder
    private func counterRow(for definition: CustomCounterDefinition) -> some View {
        let binding = Binding<String>(
            get: { viewModel.counterValues[definition.id] ?? "" },
            set: { viewModel.counterValues[definition.id] = $0 }
        )

        switch definition.type {
        case .time:
            CounterTimeField(
                label: definition.label,
                value: binding,
                keyboardToolbar: keyboardToolbar
            )
        case .decimal:
            CounterDecimalField(
                label: definition.label,
                value: binding,
                keyboardToolbar: keyboardToolbar
            )
        case .integer:
            CounterIntegerField(
                label: definition.label,
                value: binding,
                keyboardToolbar: keyboardToolbar
            )
        }
    }
}

// MARK: - Time field (HH:MM)

private struct CounterTimeField: View {
    let label: String
    @Binding var value: String
    var keyboardToolbar: KeyboardToolbarState?
    @FocusState private var isFocused: Bool
    @State private var editingText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            TextField("0:00", text: $editingText)
                .font(.subheadline)
                .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                .focused($isFocused)
                .onChange(of: editingText) { _, newValue in
                    // Allow digits and colon only
                    let filtered = newValue.filter { $0.isNumber || $0 == ":" }
                    if filtered != newValue { editingText = filtered }
                }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        // Show HH:MM on focus, clear if zero
                        if value.isEmpty || value == "0:00" || value == "0.0" {
                            editingText = ""
                        } else if value.contains(":") {
                            editingText = value
                        } else if let d = Double(value) {
                            editingText = FlightSector.decimalToHHMM(d)
                        } else {
                            editingText = value
                        }
                        keyboardToolbar?.fieldDidFocus(clear: {
                            editingText = ""
                            value = ""
                        })
                    } else {
                        // On blur: convert to decimal for storage
                        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty || trimmed == "0:00" {
                            value = ""
                        } else if trimmed.contains(":"),
                                  let decimal = FlightSector.hhmmToDecimal(trimmed) {
                            value = String(format: "%.2f", decimal)
                        } else if let d = Double(trimmed) {
                            value = String(format: "%.2f", d)
                        } else {
                            value = trimmed
                        }
                    }
                }
                .onAppear {
                    if !value.isEmpty, !value.hasPrefix("0"), let d = Double(value) {
                        editingText = FlightSector.decimalToHHMM(d)
                    } else if value.contains(":") {
                        editingText = value
                    }
                }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
    }
}

// MARK: - Decimal field

private struct CounterDecimalField: View {
    let label: String
    @Binding var value: String
    var keyboardToolbar: KeyboardToolbarState?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.orange)
                    .frame(width: 20)
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            TextField("0.0", text: $value)
                .font(.subheadline)
                .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                .focused($isFocused)
                .onChange(of: value) { _, newValue in
                    // Keep only digits and a single decimal separator
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
        .cornerRadius(8)
    }
}

// MARK: - Integer field

private struct CounterIntegerField: View {
    let label: String
    @Binding var value: String
    var keyboardToolbar: KeyboardToolbarState?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "number.square.fill")
                    .foregroundColor(.teal)
                    .frame(width: 20)
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
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
        .cornerRadius(8)
    }
}
