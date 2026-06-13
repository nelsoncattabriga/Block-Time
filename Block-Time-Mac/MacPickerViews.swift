//
//  MacPickerViews.swift
//  Block-Time-Mac
//
//  Aircraft registration picker and crew name picker for the flight edit panel.
//  Both open as popovers anchored to their respective row buttons.
//

import SwiftUI

// MARK: - Aircraft Reg Picker Row

struct MacAircraftRegPickerRow: View {
    @Binding var registration: String
    @Binding var aircraftType: String
    let viewModel: MacLogbookViewModel

    @AppStorage("showFullAircraftReg") private var showFullReg: Bool = true
    @State private var showingPicker = false

    var body: some View {
        MacFormRow(label: "REG") {
            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 4) {
                    if registration.isEmpty {
                        Text("Select...")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(registration)
                            .foregroundStyle(.primary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .font(.system(.body, design: .monospaced))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPicker, arrowEdge: .trailing) {
                MacAircraftPickerPopover(
                    selectedReg: $registration,
                    selectedType: $aircraftType,
                    showFullReg: showFullReg,
                    viewModel: viewModel,
                    onDismiss: { showingPicker = false }
                )
            }
        }
    }
}

// MARK: - Aircraft Picker Popover

private struct MacAircraftPickerPopover: View {
    @Binding var selectedReg: String
    @Binding var selectedType: String
    let showFullReg: Bool
    let viewModel: MacLogbookViewModel
    let onDismiss: () -> Void

    @ObservedObject private var fleetService = MacAircraftFleetService.shared
    @AppStorage("selectedFleetID") private var selectedFleetID: String = "B737"
    @State private var searchText = ""
    @State private var showingAddSheet = false

    private var filteredFleets: [MacFleet] {
        let lower = searchText.lowercased()
        if lower.isEmpty {
            var ordered = fleetService.fleets.filter { $0.id == selectedFleetID }
            ordered += fleetService.fleets.filter { $0.id != selectedFleetID }
            return ordered
        }
        return fleetService.fleets.compactMap { fleet in
            let matching = fleet.aircraft.filter {
                $0.registration.localizedStandardContains(lower) ||
                $0.fullRegistration.localizedStandardContains(lower) ||
                $0.type.localizedStandardContains(lower)
            }
            return matching.isEmpty ? nil : MacFleet(id: fleet.id, name: fleet.name, aircraft: matching)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Aircraft")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Add custom aircraft")
                if !selectedReg.isEmpty {
                    Button("Clear") {
                        selectedReg = ""
                        selectedType = ""
                        onDismiss()
                    }
                    .foregroundStyle(.red)
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search registration or type...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // List
            List {
                ForEach(filteredFleets) { fleet in
                    Section(fleet.name) {
                        ForEach(fleet.aircraft) { aircraft in
                            let display = aircraft.displayRegistration(showFullReg: showFullReg)
                            let isSelected = selectedReg == display
                            HStack {
                                Button {
                                    selectedReg  = display
                                    selectedType = aircraft.type
                                    onDismiss()
                                } label: {
                                    HStack {
                                        Text(display)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(.primary)
                                        Text(aircraft.type)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                                .font(.caption)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                if aircraft.isCustom {
                                    Button {
                                        _ = viewModel.deleteAircraft(aircraft)
                                        if isSelected {
                                            selectedReg = ""
                                            selectedType = ""
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete custom aircraft")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 280, height: 440)
        .sheet(isPresented: $showingAddSheet) {
            MacAddAircraftSheet(
                showFullReg: showFullReg,
                viewModel: viewModel,
                onSave: { display, type in
                    selectedReg = display
                    selectedType = type
                    onDismiss()
                }
            )
        }
    }
}

// MARK: - Add Aircraft Sheet

private struct MacAddAircraftSheet: View {
    let showFullReg: Bool
    let viewModel: MacLogbookViewModel
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newReg = ""
    @State private var newType = ""
    @FocusState private var focusedField: Field?

    private enum Field { case registration, type }

    var body: some View {
        NavigationStack {
            Form {
                Section("Aircraft Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Registration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. VH-ABC or B738SIM", text: $newReg)
                            .focused($focusedField, equals: .registration)
                            .onSubmit { focusedField = .type }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aircraft Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. B738", text: $newType)
                            .focused($focusedField, equals: .type)
                            .onSubmit { saveAircraft() }
                    }
                }
                Section {
                    Button("Add Aircraft", action: saveAircraft)
                        .frame(maxWidth: .infinity)
                        .disabled(newReg.isEmpty || newType.isEmpty)
                }
            }
            .navigationTitle("Add New Aircraft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focusedField = .registration }
            .onChange(of: newReg) { _, v in newReg = v.uppercased() }
            .onChange(of: newType) { _, v in newType = v.uppercased() }
        }
        .frame(width: 340, height: 260)
    }

    private func saveAircraft() {
        let trimmedType = newType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newReg.isEmpty, !trimmedType.isEmpty else { return }
        let aircraft = MacAircraft(customRegistration: newReg, type: trimmedType)
        if viewModel.saveAircraft(aircraft) {
            onSave(aircraft.displayRegistration(showFullReg: showFullReg), aircraft.type)
        }
        dismiss()
    }
}

// MARK: - Crew Name Picker Row

struct MacCrewNamePickerRow: View {
    let label: String
    @Binding var name: String
    let savedNames: [String]
    let onSave: (String) -> Void

    @State private var showingPicker = false

    var body: some View {
        MacFormRow(label: label) {
            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 4) {
                    if name.isEmpty {
                        Text("Select...")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(name)
                            .foregroundStyle(.primary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPicker, arrowEdge: .trailing) {
                MacCrewNamePickerPopover(
                    title: label,
                    selectedName: $name,
                    savedNames: savedNames,
                    onSave: onSave,
                    onDismiss: { showingPicker = false }
                )
            }
        }
    }
}

// MARK: - Crew Name Picker Popover

private struct MacCrewNamePickerPopover: View {
    let title: String
    @Binding var selectedName: String
    let savedNames: [String]
    let onSave: (String) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""

    private var filtered: [String] {
        searchText.isEmpty ? savedNames : savedNames.filter {
            $0.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if !selectedName.isEmpty {
                    Button("Clear") {
                        selectedName = ""
                        onDismiss()
                    }
                    .foregroundStyle(.red)
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Search / new name entry
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search or type new name...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            // "Use <typed>" button when search text doesn't match a saved name exactly
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !savedNames.contains(trimmed) {
                Button {
                    selectedName = trimmed
                    onSave(trimmed)
                    onDismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Use \"\(trimmed)\"")
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Saved names list
            List {
                if filtered.isEmpty && !searchText.isEmpty {
                    Text("No matching names")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            selectedName = name
                            onDismiss()
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedName == name {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 260, height: 320)
    }
}
