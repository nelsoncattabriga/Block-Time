//
//  CrewNamePickerField.swift
//  Block-Time
//
//  Created by Nelson on 3/9/2025.
//

import SwiftUI

struct CrewNamePickerField: View {
    let label: String
    @Binding var nameString: String
    let savedNames: [String]
    var recentNames: [String] = []
    let onNameAdded: (String) -> Void
    @State private var showingNamePicker = false
    @State private var searchText = ""

    private var filteredNames: [String] {
        if searchText.isEmpty {
            return savedNames
        } else {
            return savedNames.filter { name in
                name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            Button(action: {
                searchText = nameString // Pre-populate search with current name
                showingNamePicker = true
            }) {
                HStack {
                    Text(nameString.isEmpty ? "Select crew..." : nameString)
                        .foregroundColor(nameString.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "person.2")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.systemGray6).opacity(0.75))
                .autocapitalization(.words)
                .disableAutocorrection(true)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingNamePicker) {
            CrewNamePickerSheet(
                title: label.replacingOccurrences(of: ":", with: "") + " Selection",
                selectedName: $nameString,
                searchText: $searchText,
                savedNames: savedNames,
                recentNames: recentNames,
                onNameAdded: onNameAdded,
                onNameRemoved: nil,  // No remove functionality in this legacy component
                onDismiss: {
                    showingNamePicker = false
                    searchText = ""
                }
            )
        }
    }
}

// MARK: - Supporting Views
struct CrewNamePickerSheet: View {
    let title: String
    @Binding var selectedName: String
    @Binding var searchText: String
    let savedNames: [String]
    var recentNames: [String] = []
    let onNameAdded: (String) -> Void
    let onNameRemoved: ((String) -> Void)?
    let onDismiss: () -> Void

    private var filteredNames: [String] {
        if searchText.isEmpty {
            return savedNames
        } else {
            return savedNames.filter { name in
                name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var filteredRecentNames: [String] {
        if searchText.isEmpty {
            return recentNames
        } else {
            return recentNames.filter { name in
                name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search field and actions
                VStack(spacing: 12) {
                    TextField("Search or enter new name...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    // Action buttons for search text
                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 12) {
                            // Use current search text button
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                let trimmedName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                selectedName = trimmedName
                                onNameAdded(trimmedName)
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
                CrewNamesList(
                    filteredNames: filteredNames,
                    filteredRecentNames: filteredRecentNames,
                    searchText: searchText,
                    savedNames: savedNames,
                    selectedName: selectedName,
                    onNameSelected: { name in
                        selectedName = name
                        onDismiss()
                    },
                    onNameRemoved: onNameRemoved
                )
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !selectedName.isEmpty {
                        Button("Clear Name") {
                            HapticManager.shared.impact(.light)
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
        .onDisappear {
            searchText = ""
        }
    }
}

struct CrewNamesList: View {
    let filteredNames: [String]
    var filteredRecentNames: [String] = []
    let searchText: String
    let savedNames: [String]
    let selectedName: String
    let onNameSelected: (String) -> Void
    let onNameRemoved: ((String) -> Void)?

    var body: some View {
        List {
            // Recent names section (only show when not searching and there are recent names)
            if searchText.isEmpty && !filteredRecentNames.isEmpty {
                Section(header: Text("Recently Used")) {
                    ForEach(filteredRecentNames, id: \.self) { name in
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            onNameSelected(name)
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(name)
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

            // All names section
            if !filteredNames.isEmpty {
                Section(
                    header: Text(searchText.isEmpty ? "All Names" : "Matching Names")
                ) {
                    ForEach(filteredNames, id: \.self) { name in
                        HStack(spacing: 0) {
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                onNameSelected(name)
                            }) {
                                HStack {
                                    Text(name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedName == name {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            if let onNameRemoved = onNameRemoved {
                                Button(action: {
                                    onNameRemoved(name)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.subheadline)
                                        .padding(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            } else if !searchText.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        Text("No matching names found")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            } else if savedNames.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.gray)
                        Text("No saved names yet")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}
