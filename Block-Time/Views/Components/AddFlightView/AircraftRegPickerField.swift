import SwiftUI

struct AircraftRegPickerField: View {
    let label: String
    @Binding var regString: String
    @Binding var aircraftType: String
    let showFullReg: Bool
    @State private var showingRegPicker = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(width: 80, alignment: .leading)
            
            Button(action: {
                HapticManager.shared.impact(.medium)
                showingRegPicker = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(regString.isEmpty ? "Select aircraft..." : regString)
                            .foregroundStyle(regString.isEmpty ? .secondary : .primary)
                        
                        if !regString.isEmpty && !aircraftType.isEmpty {
                            Text(aircraftType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "airplane")
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.systemGray6).opacity(0.75))
                .clipShape(.rect(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingRegPicker) {
            AircraftRegPickerSheet(
                selectedReg: $regString,
                selectedType: $aircraftType,
                showFullReg: showFullReg,
                onDismiss: {
                    showingRegPicker = false
                }
            )
        }
    }
}

// MARK: - Supporting Views
struct AircraftRegPickerSheet: View {
    @Binding var selectedReg: String
    @Binding var selectedType: String
    let showFullReg: Bool
    var recentAircraftRegs: [String] = []
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

        // Find the selected fleet
        selectedFleet = availableFleets.first(where: { $0.id == selectedFleetID }) ?? availableFleets.first

        // Get all other fleets (excluding the selected fleet)
        otherFleets = availableFleets.filter { fleet in
            fleet.id != selectedFleetID
        }

        updateFilteredAircraft()
    }

    // Pre-compute displayed registrations to avoid repeated calculations
    private func getDisplayedRegistrations() -> [String: String] {
        guard let selectedFleet = selectedFleet else { return [:] }
        let result = Dictionary(uniqueKeysWithValues:
            selectedFleet.aircraft.map { ($0.id, $0.displayRegistration(showFullReg: showFullReg)) }
        )
        LogManager.shared.debug("Generated displayedRegs for \(selectedFleet.aircraft.count) aircraft: \(result)")
        return result
    }

    private func updateFilteredAircraft() {
        var fleetAircraftPairs: [(fleet: Fleet, aircraft: [Aircraft])] = []

        if searchText.isEmpty {
            // No search - show selected fleet first, then others
            if let selectedFleet = selectedFleet {
                fleetAircraftPairs.append((fleet: selectedFleet, aircraft: selectedFleet.aircraft))
            }

            for fleet in otherFleets {
                fleetAircraftPairs.append((fleet: fleet, aircraft: fleet.aircraft))
            }
        } else {
            // With search - filter all fleets and show only those with matches
            let lowercaseSearch = searchText.lowercased()

            // Filter selected fleet
            if let selectedFleet = selectedFleet {
                let filtered = selectedFleet.aircraft.filter {
                    $0.registration.lowercased().contains(lowercaseSearch) ||
                    $0.type.lowercased().contains(lowercaseSearch)
                }
                if !filtered.isEmpty {
                    fleetAircraftPairs.append((fleet: selectedFleet, aircraft: filtered))
                }
            }

            // Filter other fleets
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
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            if !Task.isCancelled {
                await MainActor.run {
                    updateFilteredAircraft()
                }
            }
        }
    }

    private func deleteAircraft(_ aircraft: Aircraft) {
        let success = fleetService.deleteAircraft(aircraft)
        if success {
            HapticManager.shared.impact(.medium)
            loadFleets() // Refresh the list after deletion
        }
    }

    private var recentAircraft: [Aircraft] {
        guard searchText.isEmpty else { return [] }
        // Search across all fleets for recent aircraft
        let allAircraft = availableFleets.flatMap { $0.aircraft }
        return recentAircraftRegs.compactMap { reg in
            allAircraft.first { aircraft in
                aircraft.displayRegistration(showFullReg: showFullReg) == reg
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
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
                        .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(Color(.systemGroupedBackground))
                
                //                // Add New Aircraft Button
                //                Button(action: {
                //                    HapticManager.shared.impact(.medium)
                //                    showingAddAircraftSheet = true
                //                }) {
                //                    HStack {
                //                        Image(systemName: "plus.circle.fill")
                //                            .foregroundStyle(.green)
                //                            .font(.title3)
                //
                //                        VStack(alignment: .leading, spacing: 4) {
                //                            Text("Add New Aircraft")
                //                                .font(.headline)
                //                                .foregroundStyle(.primary)
                //
                ////                            Text("Enter registration and type")
                ////                                .font(.subheadline)
                ////                                .foregroundStyle(.secondary)
                //                        }
                //
                //                        Spacer()
                //                    }
                //                }
                //                .buttonStyle(PlainButtonStyle())
                //                .padding(16)
                
                
                
                
                // Aircraft List
                List {
                    // Recent Aircraft Section
                    if !recentAircraft.isEmpty {
                        Section(header: Text("Recently Used")) {
                            ForEach(recentAircraft, id: \.id) { aircraft in
                                let displayReg = aircraft.displayRegistration(showFullReg: showFullReg)
                                let isSelected = selectedReg == displayReg
                                
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(displayReg)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        
                                        //                                        Text(aircraft.type)
                                        //                                            .font(.subheadline)
                                        //                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.shared.impact(.medium)
                                    selectedReg = displayReg
                                    selectedType = aircraft.type
                                    onDismiss()
                                }
                            }
                        }
                    }
                    
                    // All Aircraft Sections - Grouped by Fleet
                    ForEach(filteredAircraftByFleet, id: \.fleet.id) { fleetGroup in
                        Section(header: Text(fleetGroup.fleet.name)) {
                            ForEach(fleetGroup.aircraft, id: \.id) { aircraft in
                                let displayReg = aircraft.displayRegistration(showFullReg: showFullReg)
                                let isSelected = selectedReg == displayReg

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(displayReg)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        //                                    Text(aircraft.type)
                                        //                                        .font(.subheadline)
                                        //                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.shared.impact(.medium)
                                            LogManager.shared.debug("Tapped aircraft: \(aircraft.registration), displayReg: \(displayReg)")
                                    selectedReg = displayReg
                                    selectedType = aircraft.type
                                            LogManager.shared.debug("Updated selectedReg: \(selectedReg), selectedType: \(selectedType)")
                                    onDismiss()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if fleetService.isCustomAircraft(aircraft) {
                                        Button(role: .destructive) {
                                            deleteAircraft(aircraft)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            
                // Add New Aircraft Button
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    showingAddAircraftSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add New Aircraft")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

//                            Text("Enter registration and type")
//                                .font(.subheadline)
//                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(16)

                
                
                
            }
            .navigationTitle("Select Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !selectedReg.isEmpty {
                        Button("Clear Rego") {
                            HapticManager.shared.impact(.medium)
                            selectedReg = ""
                            selectedType = ""
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingAddAircraftSheet) {
            AddAircraftSheet(
                selectedReg: $selectedReg,
                selectedType: $selectedType,
                showFullReg: showFullReg,
                fleetService: fleetService,
                onDismiss: {
                    showingAddAircraftSheet = false
                    loadFleets() // Reload the fleets after adding
                    onDismiss()
                }
            )
        }
        .onAppear {
            loadFleets()
        }
    }
}

// MARK: - Add Aircraft Sheet
private struct AddAircraftSheet: View {
    @Binding var selectedReg: String
    @Binding var selectedType: String
    let showFullReg: Bool
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
                            .foregroundStyle(.secondary)
                        TextField("e.g., VH-ABC or B738SIM", text: $newAircraftReg)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .focused($focusedField, equals: .registration)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .type
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aircraft Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., B738", text: $newAircraftType)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
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

        let trimmedType = newAircraftType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Use customRegistration init: handles "VH-ABC" (strips prefix for toggle support)
        // and non-VH entries like "B738SIM" (stored as-is, never gets "VH-" prepended).
        let aircraft = Aircraft(customRegistration: newAircraftReg, type: trimmedType)

        let success = fleetService.saveAircraft(aircraft)

        if success {
            // Set selectedReg to the display form so it matches what the picker shows
            selectedReg = aircraft.displayRegistration(showFullReg: showFullReg)
            selectedType = aircraft.type
            HapticManager.shared.impact(.medium)
        } else {
            LogManager.shared.debug("Failed to save aircraft")
        }

        onDismiss()
    }
}


