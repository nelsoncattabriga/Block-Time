//
//  FilterCrewPickerSheet.swift
//  Block-Time
//
//  Created by Nelson on 11/10/2025.
//

import SwiftUI

struct FilterCrewPickerSheet: View {
    let title: String
    @Binding var selectedName: String
    let availableNames: [String]
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredNames: [String] {
        if searchText.isEmpty {
            return availableNames
        } else {
            return availableNames.filter { name in
                name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search field
                VStack(spacing: 12) {
                    TextField("Search name...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .autocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)

                    // Action buttons
                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 12) {
                            // Use current search text button
                            Button(action: {
                                let trimmedName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                selectedName = trimmedName
                                onDismiss()
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Use \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(20)
                            }

                            Spacer()

                            // Clear search button
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGroupedBackground))

                // Results list
                List {
                    if filteredNames.isEmpty && !searchText.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                Text("No matching names found")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        Section(header: searchText.isEmpty ? Text("All Names") : Text("Matching Names")) {
                            ForEach(filteredNames, id: \.self) { name in
                                Button(action: {
                                    selectedName = name
                                    onDismiss()
                                }) {
                                    HStack {
                                        Text(name)
                                            .font(.body)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if selectedName == name {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if !selectedName.isEmpty {
                        Button("Clear") {
                            selectedName = ""
                            onDismiss()
                        }
                        .foregroundColor(.red)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Pre-populate search with current selection
            searchText = selectedName
            // Auto-focus search field when sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFieldFocused = true
            }
        }
        .onDisappear {
            searchText = ""
        }
    }
}
