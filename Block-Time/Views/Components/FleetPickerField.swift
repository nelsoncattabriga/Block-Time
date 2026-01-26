import SwiftUI

// MARK: - Fleet Picker Field Component
struct FleetPickerField: View {
    let label: String
    @Binding var selectedFleet: Fleet
    @Binding var selectedAircraft: Aircraft?
    let showFullReg: Bool
    @State private var showingFleetPicker = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            Button(action: {
                showingFleetPicker = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedFleet.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        if let aircraft = selectedAircraft {
                            Text("\(aircraft.displayRegistration(showFullReg: showFullReg)) • \(aircraft.type)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Select aircraft from fleet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "building.2")
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
        .sheet(isPresented: $showingFleetPicker) {
            FleetPickerSheet(
                selectedFleet: $selectedFleet,
                selectedAircraft: $selectedAircraft,
                showFullReg: showFullReg,
                onDismiss: {
                    showingFleetPicker = false
                }
            )
        }
    }
}

// MARK: - Fleet Picker Sheet
struct FleetPickerSheet: View {
    @Binding var selectedFleet: Fleet
    @Binding var selectedAircraft: Aircraft?
    let showFullReg: Bool
    let onDismiss: () -> Void
    
    @State private var searchText = ""
    
    var filteredAircraft: [Aircraft] {
        let aircraft = selectedFleet.aircraft
        if searchText.isEmpty {
            return aircraft
        } else {
            return aircraft.filter { 
                $0.registration.localizedCaseInsensitiveContains(searchText) ||
                $0.type.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Fleet Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AircraftFleetService.availableFleets, id: \.id) { fleet in
                            Button(action: {
                                selectedFleet = fleet
                                // Clear selected aircraft when changing fleets
                                selectedAircraft = nil
                            }) {
                                VStack(spacing: 4) {
                                    Text(fleet.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("\(fleet.aircraft.count) aircraft")
                                        .font(.caption2)
                                        .foregroundColor(
                                            selectedFleet.id == fleet.id ? 
                                            .white.opacity(0.8) : .secondary
                                        )
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    selectedFleet.id == fleet.id ? 
                                    Color.blue : Color(.systemGray5)
                                )
                                .foregroundColor(
                                    selectedFleet.id == fleet.id ? 
                                    .white : .primary
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search aircraft...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(Color(.systemGroupedBackground))
                
                // Aircraft List
                List {
                    Section(header: HStack {
                        Text(selectedFleet.name)
                        Spacer()
                        Text("\(filteredAircraft.count) aircraft")
                            .foregroundColor(.secondary)
                    }) {
                        ForEach(filteredAircraft, id: \.id) { aircraft in
                            Button(action: {
                                selectedAircraft = aircraft
                                onDismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(aircraft.displayRegistration(showFullReg: showFullReg))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(aircraft.type)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if let selected = selectedAircraft, 
                                       selected.id == aircraft.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Select Fleet & Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedAircraft != nil {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    VStack {
        FleetPickerField(
            label: "Fleet",
            selectedFleet: .constant(AircraftFleetService.availableFleets[0]),
            selectedAircraft: .constant(nil),
            showFullReg: true
        )
    }
    .padding()
}

