//
//  FilterAirportPickerSheet.swift
//  Block-Time
//
//  Created by Nelson on 11/10/2025.
//

import SwiftUI

struct FilterAirportPickerSheet: View {
    let title: String
    @Binding var selectedAirport: String
    let availableAirports: [String]
    let useIATACodes: Bool
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    // Filter and sort airports based on user preference
    private var filteredAirports: [String] {
        let filtered: [String]

        if searchText.isEmpty {
            filtered = availableAirports
        } else {
            let searchUpper = searchText.uppercased()
            filtered = availableAirports.filter { airport in
                // Search by ICAO code directly
                if airport.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                // Search by IATA code
                if let iataCode = AirportService.shared.convertToIATA(airport) {
                    return iataCode.localizedCaseInsensitiveContains(searchUpper)
                }

                return false
            }
        }

        // Sort based on display preference
        if useIATACodes {
            // Sort by IATA code
            return filtered.sorted { airport1, airport2 in
                let iata1 = AirportService.shared.convertToIATA(airport1) ?? airport1
                let iata2 = AirportService.shared.convertToIATA(airport2) ?? airport2
                return iata1 < iata2
            }
        } else {
            // Sort by ICAO code (already sorted from database)
            return filtered.sorted()
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search field
                VStack(spacing: 12) {
                    TextField("Search airport code or name...", text: $searchText)
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
                                let trimmedCode = searchText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                selectedAirport = trimmedCode
                                onDismiss()
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Use \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())\"")
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
                    if filteredAirports.isEmpty && !searchText.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                Text("No matching airports found")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        Section(header: searchText.isEmpty ? Text("Airports in Logbook") : Text("Matching Airports")) {
                            ForEach(filteredAirports, id: \.self) { airport in
                                Button(action: {
                                    selectedAirport = airport
                                    onDismiss()
                                }) {
                                    HStack {
                                        if useIATACodes {
                                            // Display as IATA (ICAO)
                                            if let iataCode = AirportService.shared.convertToIATA(airport) {
                                                Text(iataCode)
                                                    .font(.body)
                                                    .foregroundColor(.primary)

                                                Text("/ \(airport)")
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                            } else {
                                                // No IATA code available, show ICAO only
                                                Text(airport)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                            }
                                        } else {
                                            // Display as ICAO (IATA)
                                            Text(airport)
                                                .font(.body)
                                                .foregroundColor(.primary)

                                            if let iataCode = AirportService.shared.convertToIATA(airport) {
                                                Text("/ \(iataCode)")
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        if selectedAirport == airport {
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
                    if !selectedAirport.isEmpty {
                        Button("Clear") {
                            selectedAirport = ""
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Pre-populate search with current selection
            searchText = selectedAirport
//           //  Auto-focus search field when sheet appears
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                isSearchFieldFocused = true
//            }
        }
        .onDisappear {
            searchText = ""
        }
    }
}
