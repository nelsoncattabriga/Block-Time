//
//  FilterTextPickerSheet.swift
//  Block-Time
//
//  Created by Nelson on 11/10/2025.
//

import SwiftUI

struct FilterTextPickerSheet: View {
    let title: String
    @Binding var selectedValue: String
    let availableValues: [String]
    let placeholder: String
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredValues: [String] {
        if searchText.isEmpty {
            return availableValues
        } else {
            return availableValues.filter { value in
                value.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                VStack(spacing: 12) {
                    TextField(placeholder, text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)

                    // Action buttons
                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 12) {
                            // Use current search text button
                            Button(action: {
                                let trimmedValue = searchText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                selectedValue = trimmedValue
                                onDismiss()
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Use \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())\"")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .clipShape(.rect(cornerRadius: 20))
                            }

                            Spacer()

                            // Clear search button
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGroupedBackground))

                // Results list
                List {
                    if filteredValues.isEmpty && !searchText.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.gray)
                                Text("No matching \(title.lowercased()) found")
                                    .foregroundStyle(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        Section(header: searchText.isEmpty ? Text("All \(title)") : Text("Matching \(title)")) {
                            ForEach(filteredValues, id: \.self) { value in
                                Button(action: {
                                    selectedValue = value
                                    onDismiss()
                                }) {
                                    HStack {
                                        Text(value)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if selectedValue == value {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !selectedValue.isEmpty {
                        Button("Clear") {
                            selectedValue = ""
                            onDismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.medium)
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Pre-populate search with current selection
            searchText = selectedValue
            // Auto-focus search field when sheet appears
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                isSearchFieldFocused = true
            }
        }
        .onDisappear {
            searchText = ""
        }
    }
}
