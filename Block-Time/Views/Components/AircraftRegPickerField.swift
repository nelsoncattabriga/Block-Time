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
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            Button(action: {
                HapticManager.shared.impact(.light)
                showingRegPicker = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(regString.isEmpty ? "Select aircraft..." : regString)
                            .foregroundColor(regString.isEmpty ? .secondary : .primary)
                        
                        if !regString.isEmpty && !aircraftType.isEmpty {
                            Text(aircraftType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "airplane")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.systemGray6).opacity(0.75))
                .cornerRadius(6)
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

    @StateObject private var fleetService = AircraftFleetService.shared
    @State private var availableFleets: [Fleet] = []
    @State private var selectedFleet: Fleet?
    @State private var otherFleets: [Fleet] = []
    @AppStorage("selectedFleetID") private var selectedFleetID: String = "All Aircraft"
    @State private var searchText = ""
    @State private var filteredAircraftByFleet: [(fleet: Fleet, aircraft: [Aircraft])] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var showingAddAircraftSheet = false

    private func loadFleets() {
        availableFleets = fleetService.getAvailableFleetsWithCustom()

        // Find the selected fleet
        selectedFleet = availableFleets.first(where: { $0.id == selectedFleetID }) ?? availableFleets.first

        // Get all other fleets (excluding "All Aircraft" and the selected fleet)
        otherFleets = availableFleets.filter { fleet in
            fleet.id != "All Aircraft" && fleet.id != selectedFleetID
        }

        updateFilteredAircraft()
    }

    // Pre-compute displayed registrations to avoid repeated calculations
    private func getDisplayedRegistrations() -> [String: String] {
        guard let selectedFleet = selectedFleet else { return [:] }
        let result = Dictionary(uniqueKeysWithValues:
            selectedFleet.aircraft.map { ($0.id, $0.displayRegistration(showFullReg: showFullReg)) }
        )
        print("Generated displayedRegs for \(selectedFleet.aircraft.count) aircraft: \(result)")
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
        NavigationView {
            VStack(spacing: 0) {
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
                //                            .foregroundColor(.green)
                //                            .font(.title3)
                //
                //                        VStack(alignment: .leading, spacing: 4) {
                //                            Text("Add New Aircraft")
                //                                .font(.headline)
                //                                .foregroundColor(.primary)
                //
                ////                            Text("Enter registration and type")
                ////                                .font(.subheadline)
                ////                                .foregroundColor(.secondary)
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
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(displayReg)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        //                                        Text(aircraft.type)
                                        //                                            .font(.subheadline)
                                        //                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.shared.impact(.light)
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
                                            .foregroundColor(.primary)

                                        //                                    Text(aircraft.type)
                                        //                                        .font(.subheadline)
                                        //                                        .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.shared.impact(.light)
                                    print("Tapped aircraft: \(aircraft.registration), displayReg: \(displayReg)")
                                    selectedReg = displayReg
                                    selectedType = aircraft.type
                                    print("Updated selectedReg: \(selectedReg), selectedType: \(selectedType)")
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
                            .foregroundColor(.green)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add New Aircraft")
                                .font(.subheadline)
                                .foregroundColor(.primary)

//                            Text("Enter registration and type")
//                                .font(.subheadline)
//                                .foregroundColor(.secondary)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if !selectedReg.isEmpty {
                        Button("Clear Rego") {
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
            AddAircraftSheet(
                selectedReg: $selectedReg,
                selectedType: $selectedType,
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
        NavigationView {
            Form {
                Section(header: Text("Aircraft Details")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Registration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., VH-ABC", text: $newAircraftReg)
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
                            .foregroundColor(.secondary)
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

        // Save to database
        let success = fleetService.saveAircraft(aircraft)

        if success {
            // Update the selected values
            selectedReg = trimmedReg
            selectedType = trimmedType

            HapticManager.shared.impact(.medium)
//            print("Aircraft added and saved: \(trimmedReg) - \(trimmedType)")
        } else {
            print("Failed to save aircraft")
        }

        onDismiss()
    }
}


