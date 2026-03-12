//
//  BulkEditAircraftFields.swift
//  Block-Time
//

import SwiftUI

// MARK: - BulkEditAircraftRegField

struct BulkEditAircraftRegField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>
    let showFullReg: Bool
    @Binding var aircraftTypeFieldState: BulkEditViewModel.FieldState<String>

    @State private var textValue: String = ""
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button(action: {
                showingPicker = true
            }) {
                HStack {
                    Text(fieldState.isMixed ? "(Mixed)" : (textValue.isEmpty ? "Select aircraft..." : textValue))
                        .font(.body)
                        .foregroundColor(fieldState.isMixed ? .secondary : (textValue.isEmpty ? .secondary : .primary))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .sheet(isPresented: $showingPicker) {
                BulkEditAircraftPickerSheet(
                    selectedReg: Binding(
                        get: { textValue },
                        set: { newValue in
                            textValue = newValue
                            if !newValue.isEmpty {
                                fieldState = .value(newValue)
                            }
                        }
                    ),
                    selectedType: Binding(
                        get: {
                            if case .value(let type) = aircraftTypeFieldState {
                                return type
                            }
                            return ""
                        },
                        set: { newType in
                            if !newType.isEmpty {
                                aircraftTypeFieldState = .value(newType)
                            }
                        }
                    ),
                    showFullReg: showFullReg,
                    onDismiss: {
                        showingPicker = false
                    }
                )
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val
                }
            }
        }
    }
}

// MARK: - BulkEditAircraftPickerSheet

struct BulkEditAircraftPickerSheet: View {
    @Binding var selectedReg: String
    @Binding var selectedType: String
    let showFullReg: Bool
    let onDismiss: () -> Void

    private let fleetService = AircraftFleetService.shared
    @State private var availableFleets: [Fleet] = []
    @State private var selectedFleet: Fleet?
    @State private var otherFleets: [Fleet] = []
    @AppStorage("selectedFleetID") private var selectedFleetID: String = "B737"
    @State private var searchText = ""
    @State private var filteredAircraftByFleet: [(fleet: Fleet, aircraft: [Aircraft])] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var showingAddAircraftSheet = false

    private func loadFleets() {
        availableFleets = fleetService.getAvailableFleetsWithCustom()
        selectedFleet = availableFleets.first(where: { $0.id == selectedFleetID }) ?? availableFleets.first
        otherFleets = availableFleets.filter { fleet in fleet.id != selectedFleetID }
        updateFilteredAircraft()
    }

    private func updateFilteredAircraft() {
        var fleetAircraftPairs: [(fleet: Fleet, aircraft: [Aircraft])] = []

        if searchText.isEmpty {
            if let selectedFleet = selectedFleet {
                fleetAircraftPairs.append((fleet: selectedFleet, aircraft: selectedFleet.aircraft))
            }
            for fleet in otherFleets {
                fleetAircraftPairs.append((fleet: fleet, aircraft: fleet.aircraft))
            }
        } else {
            let lowercaseSearch = searchText.lowercased()
            if let selectedFleet = selectedFleet {
                let filtered = selectedFleet.aircraft.filter {
                    $0.registration.lowercased().contains(lowercaseSearch) ||
                    $0.type.lowercased().contains(lowercaseSearch)
                }
                if !filtered.isEmpty {
                    fleetAircraftPairs.append((fleet: selectedFleet, aircraft: filtered))
                }
            }
            for fleet in otherFleets {
                let filtered = fleet.aircraft.filter {
                    $0.registration.lowercased().contains(lowercaseSearch) ||
                    $0.type.lowercased().contains(lowercaseSearch)
                }
                if !filtered.isEmpty {
                    fleetAircraftPairs.append((fleet: fleet, aircraft: filtered))
                }
            }
        }
        filteredAircraftByFleet = fleetAircraftPairs
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    updateFilteredAircraft()
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar and Add Button Section
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Search aircraft...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .onChange(of: searchText) {
                                if searchText.isEmpty {
                                    updateFilteredAircraft()
                                } else {
                                    debounceSearch()
                                }
                            }

                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                                updateFilteredAircraft()
                            }
                            .foregroundColor(.blue)
                        }
                    }

                    // Add New Aircraft Button
                    Button(action: {
                        showingAddAircraftSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add New Aircraft")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color(.systemGroupedBackground))

                // Aircraft List
                List {
                    ForEach(filteredAircraftByFleet, id: \.fleet.id) { fleetPair in
                        Section(header: Text(fleetPair.fleet.name)) {
                            ForEach(fleetPair.aircraft) { aircraft in
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    selectedReg = aircraft.registration
                                    selectedType = aircraft.type
                                    onDismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(aircraft.displayRegistration(showFullReg: showFullReg))
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(aircraft.type)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedReg == aircraft.registration {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    if filteredAircraftByFleet.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: searchText.isEmpty ? "airplane" : "magnifyingglass")
                                    .foregroundColor(.gray)
                                Text(searchText.isEmpty ? "No aircraft in fleet" : "No matching aircraft found")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Select Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !selectedReg.isEmpty {
                        Button("Clear") {
                            HapticManager.shared.impact(.light)
                            selectedReg = ""
                            selectedType = ""
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
        .sheet(isPresented: $showingAddAircraftSheet) {
            BulkEditAddAircraftSheet(
                selectedReg: $selectedReg,
                selectedType: $selectedType,
                fleetService: fleetService,
                onDismiss: {
                    showingAddAircraftSheet = false
                    loadFleets()
                    onDismiss()
                }
            )
        }
        .onAppear {
            loadFleets()
        }
        .onDisappear {
            searchText = ""
        }
    }
}

// MARK: - BulkEditAddAircraftSheet

struct BulkEditAddAircraftSheet: View {
    @Binding var selectedReg: String
    @Binding var selectedType: String
    var fleetService: AircraftFleetService
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var newAircraftReg: String = ""
    @State private var newAircraftType: String = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case registration, type
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Aircraft Details")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Registration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., VH-ABC", text: $newAircraftReg)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .registration)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .type
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aircraft Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., B738", text: $newAircraftType)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .type)
                            .submitLabel(.done)
                            .onSubmit {
                                saveAircraft()
                            }
                    }
                }

                Section {
                    Button(action: saveAircraft) {
                        HStack {
                            Spacer()
                            Text("Add Aircraft")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(newAircraftReg.isEmpty || newAircraftType.isEmpty)
                }
            }
            .navigationTitle("Add New Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                focusedField = .registration
            }
        }
    }

    private func saveAircraft() {
        guard !newAircraftReg.isEmpty && !newAircraftType.isEmpty else { return }

        let trimmedReg = newAircraftReg.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedType = newAircraftType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Create new aircraft
        let aircraft = Aircraft(registration: trimmedReg, type: trimmedType)

        // Save to fleet service
        let success = fleetService.saveAircraft(aircraft)

        if success {
            // Update the selected values
            selectedReg = trimmedReg
            selectedType = trimmedType

            HapticManager.shared.impact(.medium)
        }

        onDismiss()
    }
}

// MARK: - BulkEditAircraftTypeField

struct BulkEditAircraftTypeField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>

    @State private var textValue: String = ""
    @State private var showingPicker = false
    @State private var searchText = ""
    @State private var availableTypes: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button(action: {
                // Load existing aircraft types from database
                loadAircraftTypes()
                searchText = textValue
                showingPicker = true
            }) {
                HStack {
                    Text(fieldState.isMixed ? "(Mixed)" : (textValue.isEmpty ? "Select type..." : textValue))
                        .font(.body)
                        .foregroundColor(fieldState.isMixed ? .secondary : (textValue.isEmpty ? .secondary : .primary))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .sheet(isPresented: $showingPicker) {
                AircraftTypePickerSheet(
                    title: label,
                    selectedType: $textValue,
                    searchText: $searchText,
                    availableTypes: availableTypes,
                    onDismiss: {
                        showingPicker = false
                        searchText = ""
                        fieldState = .value(textValue)
                    }
                )
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val
                }
            }
        }
    }

    private func loadAircraftTypes() {
        // Get all flights from database
        let flights = FlightDatabaseService.shared.fetchAllFlights()

        // Extract unique aircraft types and sort them
        let uniqueTypes = Set(flights.map { $0.aircraftType.uppercased() }.filter { !$0.isEmpty })
        availableTypes = Array(uniqueTypes).sorted()
    }
}

// MARK: - AircraftTypePickerSheet

struct AircraftTypePickerSheet: View {
    let title: String
    @Binding var selectedType: String
    @Binding var searchText: String
    let availableTypes: [String]
    let onDismiss: () -> Void

    private var filteredTypes: [String] {
        if searchText.isEmpty {
            return availableTypes
        } else {
            return availableTypes.filter { type in
                type.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field and actions
                VStack(spacing: 12) {
                    TextField("Search or enter new type...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .padding(.horizontal)

                    // Action buttons for search text
                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 12) {
                            // Use current search text button
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                let trimmedType = searchText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                selectedType = trimmedType
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
                    if !filteredTypes.isEmpty {
                        Section(
                            header: Text(searchText.isEmpty ? "All Aircraft Types" : "Matching Types")
                        ) {
                            ForEach(filteredTypes, id: \.self) { type in
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    selectedType = type
                                    onDismiss()
                                }) {
                                    HStack {
                                        Text(type)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedType.uppercased() == type.uppercased() {
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
                                Text("No matching types found")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    } else if availableTypes.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: "airplane")
                                    .foregroundColor(.gray)
                                Text("No aircraft types in database yet")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !selectedType.isEmpty {
                        Button("Clear Type") {
                            HapticManager.shared.impact(.light)
                            selectedType = ""
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
