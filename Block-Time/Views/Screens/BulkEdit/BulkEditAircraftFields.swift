//
//  BulkEditAircraftFields.swift
//  Block-Time
//

import SwiftUI

// MARK: - BulkEditAircraftTypeField

struct BulkEditAircraftTypeField: View {
    let label: String
    @Binding var fieldState: BulkEditViewModel.FieldState<String>

    @State private var textValue: String = ""
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                Button(action: { showingPicker = true }) {
                    HStack {
                        Text(fieldState.isMixed ? "(Mixed)" : (textValue.isEmpty ? "Select aircraft type..." : textValue))
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

                if !textValue.isEmpty || fieldState.isMixed {
                    Button(action: {
                        textValue = ""
                        fieldState = .value("")
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color(.secondarySystemBackground))
                }
            }
            .cornerRadius(8)
            .sheet(isPresented: $showingPicker) {
                BulkEditAircraftTypePickerSheet(
                    selectedType: Binding(
                        get: { textValue },
                        set: { newValue in
                            textValue = newValue
                            fieldState = .value(newValue)
                        }
                    ),
                    onDismiss: { showingPicker = false }
                )
            }
            .onAppear {
                if case .value(let val) = fieldState {
                    textValue = val
                }
            }
            .onChange(of: fieldState) { _, newState in
                if case .value(let val) = newState {
                    textValue = val
                }
            }
        }
    }
}

// MARK: - BulkEditAircraftTypePickerSheet

struct BulkEditAircraftTypePickerSheet: View {
    @Binding var selectedType: String
    let onDismiss: () -> Void

    @State private var logbookTypes: [String] = []
    @State private var customText: String = ""
    @FocusState private var isCustomFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Enter Custom Type")) {
                    HStack {
                        TextField("e.g. B738", text: $customText)
                            .textCase(.uppercase)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isCustomFocused)
                            .submitLabel(.done)
                            .onSubmit { applyCustom() }
                        if !customText.isEmpty {
                            Button(action: applyCustom) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                if !logbookTypes.isEmpty {
                    Section(header: Text("From Logbook")) {
                        ForEach(logbookTypes, id: \.self) { type in
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                selectedType = type
                                onDismiss()
                            }) {
                                HStack {
                                    Text(type)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedType == type {
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
            }
            .navigationTitle("Select A/C Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !selectedType.isEmpty {
                        Button("Clear") {
                            HapticManager.shared.impact(.light)
                            selectedType = ""
                            onDismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            customText = selectedType
            Task {
                logbookTypes = await FlightDatabaseService.shared.getAllAircraftTypesAsync()
            }
        }
    }

    private func applyCustom() {
        let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        HapticManager.shared.impact(.light)
        selectedType = trimmed
        onDismiss()
    }
}

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

            HStack(spacing: 0) {
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

                if !textValue.isEmpty || fieldState.isMixed {
                    Button(action: {
                        textValue = ""
                        fieldState = .value("")
                        aircraftTypeFieldState = .value("")
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color(.secondarySystemBackground))
                }
            }
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

    @StateObject private var fleetService = AircraftFleetService.shared
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
                ToolbarItem(placement: .topBarLeading) {
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

                ToolbarItem(placement: .topBarTrailing) {
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
    @ObservedObject var fleetService: AircraftFleetService
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
                ToolbarItem(placement: .topBarLeading) {
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
