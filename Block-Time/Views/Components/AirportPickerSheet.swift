//
//  AirportPickerSheet.swift
//  Block-Time
//
//  Created by Nelson on 10/10/2025.
//

import SwiftUI

struct AirportPickerSheet: View {
    let title: String
    @Binding var selectedAirport: String
    @Binding var searchText: String
    let recentAirports: [String]
    let onDismiss: () -> Void

    @State private var allAirports: [AirportInfo] = []
    @State private var isLoading = true
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredAirports: [AirportInfo] {
        if searchText.isEmpty {
            // Show all airports when no search
            return []
        } else {
            let searchUpper = searchText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let filtered = allAirports.filter { airport in
                // Exact match or starts with for codes (more precise)
                airport.icaoCode.starts(with: searchUpper) ||
                airport.iataCode?.starts(with: searchUpper) == true ||
                // Only match beginning of airport name (not anywhere in the name)
                airport.name.localizedStandardContains(searchText) &&
                airport.name.lowercased().hasPrefix(searchText.lowercased())
            }

            // Sort results: ICAO/IATA code matches first, then name matches
            return filtered.sorted { first, second in
                let firstIsCodeMatch = first.icaoCode.starts(with: searchUpper) ||
                                      first.iataCode?.starts(with: searchUpper) == true
                let secondIsCodeMatch = second.icaoCode.starts(with: searchUpper) ||
                                       second.iataCode?.starts(with: searchUpper) == true

                // If one is a code match and the other isn't, code match comes first
                if firstIsCodeMatch && !secondIsCodeMatch {
                    return true
                } else if !firstIsCodeMatch && secondIsCodeMatch {
                    return false
                }

                // Both are code matches or both are name matches - sort alphabetically by ICAO
                return first.icaoCode < second.icaoCode
            }
        }
    }

    // Recent airports based on recent codes
    private var recentAirportsList: [AirportInfo] {
        return allAirports.filter { airport in
            recentAirports.contains(airport.icaoCode)
        }.sorted { first, second in
            // Sort by the order in recentAirports
            let firstIndex = recentAirports.firstIndex(of: first.icaoCode) ?? Int.max
            let secondIndex = recentAirports.firstIndex(of: second.icaoCode) ?? Int.max
            return firstIndex < secondIndex
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search field
                VStack(spacing: 12) {
                    TextField("Search by code, city or airport name...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)

                    // Action buttons for search text
                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 12) {
                            // Use current search text button (for manual/private airports)
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
                if isLoading {
                    ProgressView("Loading airports...")
                        .padding()
                    Spacer()
                } else {
                    AirportsList(
                        filteredAirports: filteredAirports,
                        recentAirports: recentAirportsList,
                        searchText: searchText,
                        selectedAirport: selectedAirport,
                        onAirportSelected: { airport in
                            selectedAirport = airport.icaoCode
                            onDismiss()
                        }
                    )
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await loadAirports()
        }
        .onAppear {
            // Auto-focus search field when sheet appears
            //DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFieldFocused = true
            //}
        }
        .onDisappear {
            searchText = ""
        }
    }

    private func loadAirports() async {
        isLoading = true

        // Load from airports.dat.txt file
        guard let fileURL = Bundle.main.url(forResource: "airports.dat", withExtension: "txt") else {
            print("ERROR: airports.dat.txt not found in bundle")
            isLoading = false
            return
        }

        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            var airports: [AirportInfo] = []

            for line in lines {
                guard !line.isEmpty else { continue }

                // Parse CSV line properly handling quoted fields with commas
                let components = parseCSVLine(line)
                guard components.count >= 14 else { continue }

                // Extract fields
                let name = components[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let city = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let country = components[3].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let iataCode = components[4].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let icaoCode = components[5].trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                // Skip if no ICAO code
                guard !icaoCode.isEmpty, icaoCode != "\\N" else { continue }

                // Store IATA code if valid
                let validIataCode = (iataCode.isEmpty || iataCode == "\\N") ? nil : iataCode

                airports.append(AirportInfo(
                    icaoCode: icaoCode,
                    iataCode: validIataCode,
                    name: name,
                    city: city,
                    country: country
                ))
            }

            await MainActor.run {
                allAirports = airports.sorted { $0.name < $1.name }
                isLoading = false
            }
        } catch {
            print("ERROR: Failed to load airports.dat.txt: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        fields.append(currentField)

        return fields
    }
}

struct AirportInfo: Identifiable {
    let id = UUID()
    let icaoCode: String
    let iataCode: String?
    let name: String
    let city: String
    let country: String

    var displayCode: String {
        if let iata = iataCode {
            return "\(icaoCode) / \(iata)"
        }
        return icaoCode
    }

    var displayName: String {
        return "\(name), \(city)"
    }
}

struct AirportsList: View {
    let filteredAirports: [AirportInfo]
    let recentAirports: [AirportInfo]
    let searchText: String
    let selectedAirport: String
    let onAirportSelected: (AirportInfo) -> Void

    var body: some View {
        List {
            // Recent airports section (only show when not searching and there are recent airports)
            if searchText.isEmpty && !recentAirports.isEmpty {
                Section(header: Text("Recently Used")) {
                    ForEach(recentAirports) { airport in
                        Button(action: {
                            onAirportSelected(airport)
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .font(.caption)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(airport.displayCode)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(airport.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedAirport == airport.icaoCode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            if !filteredAirports.isEmpty {
                Section(
                    header: Text(searchText.isEmpty ? "All Airports" : "Matching Airports")
                ) {
                    ForEach(filteredAirports) { airport in
                        Button(action: {
                            onAirportSelected(airport)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(airport.displayCode)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(airport.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedAirport == airport.icaoCode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            } else if !searchText.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        Text("No matching airports found")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}
