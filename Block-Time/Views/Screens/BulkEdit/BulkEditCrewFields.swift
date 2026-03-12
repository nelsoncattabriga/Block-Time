//
//  BulkEditCrewFields.swift
//  Block-Time
//

import SwiftUI

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
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.green)
                    .frame(width: 20)

                Button(action: {
                    searchText = textValue
                    showingPicker = true
                }) {
                    HStack {
                        Text(fieldState.isMixed ? "(Mixed)" : (textValue.isEmpty ? "Select crew..." : textValue))
                            .font(.body)
                            .foregroundStyle(fieldState.isMixed ? .secondary : (textValue.isEmpty ? .secondary : .primary))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 8))
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
            .onChange(of: textValue) { _, newValue in
                fieldState = .value(newValue)
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
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.green)
                    .frame(width: 20)

                Button(action: {
                    searchText = textValue
                    showingPicker = true
                }) {
                    HStack {
                        Text(fieldState.isMixed ? "(Mixed)" : (textValue.isEmpty ? "Select crew..." : textValue))
                            .font(.body)
                            .foregroundStyle(fieldState.isMixed ? .secondary : (textValue.isEmpty ? .secondary : .primary))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 8))
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
            .onChange(of: textValue) { _, newValue in
                fieldState = .value(newValue.isEmpty ? nil : newValue)
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val ?? ""
                }
            }
        }
    }
}
