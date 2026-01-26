//
//  ImportMappingView.swift
//  Block-Time
//
//  Created by Nelson on 1/10/2025.
//

import SwiftUI

// MARK: - Import Data Model
struct ImportData: Identifiable, Equatable {
    let id = UUID()
    let headers: [String]
    let rows: [[String]]
    let fileURL: URL
    let delimiter: String

    // Equatable conformance - compare by file URL since UUID is always unique
    static func == (lhs: ImportData, rhs: ImportData) -> Bool {
        return lhs.fileURL == rhs.fileURL &&
               lhs.headers == rhs.headers &&
               lhs.delimiter == rhs.delimiter &&
               lhs.rows.count == rhs.rows.count
    }
}

enum ImportMode: Sendable, Equatable {
    case merge
    case replace
}

// MARK: - Registration to Type Mapping
struct RegistrationTypeMapping: Identifiable {
    let id = UUID()
    let pattern: String  // e.g., "EB*", "OE*"
    var aircraftType: String  // e.g., "A330", "B787"
    let sampleRegistrations: [String]  // Show examples to user
}

// MARK: - Combination Strategy
enum CombinationStrategy: String, CaseIterable, Identifiable {
    case sum = "Sum"

    var id: String { self.rawValue }

    var description: String {
        return "Add all selected columns together"
    }

    var icon: String {
        return "plus.circle"
    }
}

// MARK: - Field Mapping
struct FieldMapping: Identifiable {
    let id: UUID
    let logbookField: String
    let logbookFieldDescription: String
    var sourceColumns: [String]  // Changed from sourceColumn to support multiple
    let isRequired: Bool
    var combinationStrategy: CombinationStrategy
    let supportsMultipleColumns: Bool  // Some fields like Night Time can combine multiple sources

    // Convenience initializer for single column
    init(logbookField: String, logbookFieldDescription: String, sourceColumn: String?, isRequired: Bool, supportsMultipleColumns: Bool = false) {
        self.id = UUID()
        self.logbookField = logbookField
        self.logbookFieldDescription = logbookFieldDescription
        self.sourceColumns = sourceColumn != nil ? [sourceColumn!] : []
        self.isRequired = isRequired
        self.combinationStrategy = .sum  // Always use sum strategy
        self.supportsMultipleColumns = supportsMultipleColumns
    }

    var sourceColumn: String? {
        sourceColumns.first
    }
}

// MARK: - Import Mapping View
struct ImportMappingView: View {
    let importData: ImportData
    let onImport: ([FieldMapping], ImportMode, [RegistrationTypeMapping]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var fieldMappings: [FieldMapping]
    @State private var importMode: ImportMode = .merge
    @State private var showingPreview = false
    @State private var previewSelection: PreviewSelection = .first100
    @State private var enableRegistrationMapping = false
    @State private var showingRegistrationMapping = false
    @State private var registrationMappings: [RegistrationTypeMapping] = []

    enum PreviewSelection: String, CaseIterable, Identifiable {
        case first100 = "First Rows"
        case last100 = "Last Rows"

        var id: String { self.rawValue }
    }

    init(importData: ImportData, onImport: @escaping ([FieldMapping], ImportMode, [RegistrationTypeMapping]) -> Void) {
        self.importData = importData
        self.onImport = onImport

        // Initialize field mappings with smart auto-detection
        _fieldMappings = State(initialValue: Self.createInitialMappings(headers: importData.headers))
    }

    var body: some View {
        NavigationStack {
            Form {
//                Section {
//                    Text("Map columns from your import file to logbook fields")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }

                Section(header: Text("Import Mode")) {
                    Picker("Mode", selection: $importMode) {
                        Label("Merge with existing flights", systemImage: "arrow.triangle.merge")
                            .tag(ImportMode.merge)
                        Label("Replace all flights", systemImage: "arrow.triangle.swap")
                            .tag(ImportMode.replace)
                    }
                    .pickerStyle(.inline)

                    if importMode == .replace {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("This will delete all existing flights")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section(header: Text("Field Mapping")) {
                    ForEach($fieldMappings) { $mapping in
                        FieldMappingRow(
                            mapping: $mapping,
                            availableHeaders: importData.headers
                        )
                    }
                }

                Section(header: Text("Aircraft Type Mapping")) {
                    Toggle(isOn: $enableRegistrationMapping) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Map Registrations to Types")
                                .font(.subheadline)
                            Text("This will map imported aircraft registrations to aircraft type. Only use this if import data does not contain aircraft type information.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if enableRegistrationMapping {
                        Button {
                            // Detect registration patterns from import data
                            registrationMappings = detectRegistrationPatterns()
                            showingRegistrationMapping = true
                        } label: {
                            HStack {
                                Image(systemName: "airplane")
                                Text("Configure Type Mappings")
                                Spacer()
                                if !registrationMappings.isEmpty {
                                    Text("\(registrationMappings.filter { !$0.aircraftType.isEmpty }.count) mapped")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text("Preview")) {
                    Button {
                        showingPreview.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "eye")
                            Text(showingPreview ? "Hide Preview" : "Show Preview")
                            Spacer()
                            Image(systemName: showingPreview ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                    }

                    if showingPreview {
                        let mappedFields = fieldMappings.filter { !$0.sourceColumns.isEmpty }
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Preview Selection", selection: $previewSelection) {
                                ForEach(PreviewSelection.allCases) { selection in
                                    Text(selection.rawValue).tag(selection)
                                }
                            }
                            .pickerStyle(.segmented)

                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(previewRows.indices, id: \.self) { index in
                                        PreviewRowView(
                                            row: previewRows[index],
                                            rowNumber: previewSelection == .first100 ? index + 1 : importData.rows.count - previewRows.count + index + 1,
                                            fieldMappings: mappedFields,
                                            headers: importData.headers
                                        )
                                    }
                                }
                            }
                            .frame(maxHeight: 400)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Found \(importData.rows.count) rows to import")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Show mapping validation warnings
                        if !isValidMapping {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Some required fields are not mapped")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

                        // Show which required fields are missing
                        let unmappedRequired = fieldMappings.filter { $0.isRequired && $0.sourceColumns.isEmpty }
                        if !unmappedRequired.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unmapped required fields:")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                ForEach(unmappedRequired, id: \.id) { mapping in
                                    Text("• \(mapping.logbookField)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        onImport(fieldMappings, importMode, enableRegistrationMapping ? registrationMappings : [])
                        dismiss()
                    }
                    .disabled(!isValidMapping)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingRegistrationMapping) {
                RegistrationTypeMappingView(
                    mappings: $registrationMappings,
                    importData: importData,
                    fieldMappings: fieldMappings
                )
            }
        }
    }

    private var isValidMapping: Bool {
        // Check that all required fields are mapped
        fieldMappings.filter { $0.isRequired }.allSatisfy { !$0.sourceColumns.isEmpty }
    }

    private var previewRows: [[String]] {
        let totalRows = importData.rows.count
        // Limit preview to 20 rows for better performance with large files
        let maxRows = min(20, totalRows)

        switch previewSelection {
        case .first100:
            return Array(importData.rows.prefix(maxRows))
        case .last100:
            return Array(importData.rows.suffix(maxRows))
        }
    }

    // MARK: - Registration Pattern Detection
    private func detectRegistrationPatterns() -> [RegistrationTypeMapping] {
        // Find the registration column
        guard let regMapping = fieldMappings.first(where: { $0.logbookField == "Aircraft Reg" }),
              let regColumnName = regMapping.sourceColumn,
              let regColumnIndex = importData.headers.firstIndex(of: regColumnName) else {
            return []
        }

        // Extract all unique registrations
        var registrations = Set<String>()
        for row in importData.rows {
            guard regColumnIndex < row.count else { continue }
            let reg = row[regColumnIndex].trimmingCharacters(in: .whitespaces)
            if !reg.isEmpty {
                registrations.insert(reg)
            }
        }

        // Group registrations by pattern (first 2-3 characters)
        var patternGroups: [String: [String]] = [:]
        for reg in registrations {
            let pattern = String(reg.prefix(2)) // Use first 2 chars as pattern
            patternGroups[pattern, default: []].append(reg)
        }

        // Create mappings for each pattern, auto-detect from AircraftFleetService
        var mappings: [RegistrationTypeMapping] = []
        for (pattern, regs) in patternGroups.sorted(by: { $0.key < $1.key }) {
            // Try to detect type from AircraftFleetService
            let detectedType = AircraftFleetService.getAircraftType(byRegistration: regs.first ?? "")

            mappings.append(RegistrationTypeMapping(
                pattern: pattern + "*",
                aircraftType: detectedType,
                sampleRegistrations: Array(regs.prefix(3).sorted())
            ))
        }

        return mappings
    }

    // MARK: - Smart Field Detection
    private static func createInitialMappings(headers: [String]) -> [FieldMapping] {
        let logbookFields: [(String, String, Bool, Bool)] = [  // Added supportsMultiple
            ("Date", "Flight date", true, false),
            ("Flight Number", "Flight number", false, false),
            ("Aircraft Reg", "Aircraft registration", false, false),
            ("Aircraft Type", "Aircraft type", false, false),
            ("From Airport", "Departure airport", false, false),
            ("To Airport", "Arrival airport", false, false),
            ("Captain Name", "Captain name", false, false),
            ("F/O Name", "First Officer name", false, false),
            ("S/O1 Name", "Second Officer 1 name", false, false),
            ("S/O2 Name", "Second Officer 2 name", false, false),
            ("STD", "Scheduled Departure Time", false, false),
            ("STA", "Scheduled Arrival Time", false, false),
            ("OUT Time", "Block OUT time (1130 or 11:30)", false, false),
            ("IN Time", "Block IN time (1130 or 11:30)", false, false),
            ("Block Time", "Block time (decimal hours)", false, false),
            ("Night Time", "Night time - can combine PIC Night, SIC Night, etc.", false, true),  // Supports multiple!
            ("P1 Time", "P1/PIC time - can combine multiple sources", false, true),  // Supports multiple!
            ("P1US Time", "P1US/ICUS time - can combine multiple sources", false, true),  // Supports multiple!
            ("P2 Time", "P2/SIC time - can combine multiple sources", false, true),  // Supports multiple!
            ("Instrument Time", "Instrument time - can combine multiple sources", false, true),  // Supports multiple!
            ("SIM Time", "Simulator time (decimal hours)", false, false),
            ("Pilot Flying", "PF (yes/no, true/false, 1/0)", false, false),
            ("PAX", "PAX Flight (yes/no, true/false, 1/0)", false, false),
            ("Day Takeoffs", "Day takeoffs (integer)", false, false),
            ("Day Landings", "Day landings (integer)", false, false),
            ("Night Takeoffs", "Night takeoffs (integer)", false, false),
            ("Night Landings", "Night landings (integer)", false, false),
            ("RNP", "RNP (yes/no, true/false, 1/0)", false, false),
            ("ILS", "ILS (yes/no, true/false, 1/0)", false, false),
            ("GLS", "GLS (yes/no, true/false, 1/0)", false, false),
            ("NPA", "NPA (yes/no, true/false, 1/0)", false, false),
            ("AIII", "AIII (yes/no, true/false, 1/0)", false, false),
            ("Remarks", "Remarks/notes", false, false)
        ]

        return logbookFields.map { (field, description, required, supportsMultiple) in
            let detectedColumns = detectColumns(for: field, in: headers, allowMultiple: supportsMultiple)
            return FieldMapping(
                logbookField: field,
                logbookFieldDescription: description,
                sourceColumn: detectedColumns.first,
                isRequired: required,
                supportsMultipleColumns: supportsMultiple
            )
        }
    }

    private static func detectColumns(for logbookField: String, in headers: [String], allowMultiple: Bool) -> [String] {
        let normalized = logbookField.lowercased().replacingOccurrences(of: " ", with: "")

        var matches: [String] = []

        // Try exact match first
        if let match = headers.first(where: { $0.lowercased().replacingOccurrences(of: " ", with: "") == normalized }) {
            return [match]
        }

        // Try common variations
        let variations: [String: [String]] = [
            "date": ["date", "flightdate", "flightday"],
            "flightnumber": ["flight", "flightnumber", "flightno", "flt"],
            "aircraftreg": ["reg", "registration", "aircraft", "aircraftreg", "tail", "id"],
            "aircrafttype": ["type", "aircrafttype", "make", "model","make/model"],
            "fromairport": ["from", "departure", "dep", "origin"],
            "toairport": ["to", "arrival", "arr", "destination", "dest", "des"],
            "captainname": ["captain", "cpt", "pic", "captainname","PIC/P1 Crew","P1 Crew"],
            "f/oname": ["fo", "firstofficer", "copilot", "sic","SIC/P2 Crew","P2 Crew","P2"],
            "s/o1name": ["so1", "so", "secondofficer","relief","cruise","P3"],
            "s/o2name": ["so2", "so", "secondofficer","relief","cruise","P4"],
            "std": ["std", "scheduleddeparture", "scheduleddep", "scheddep", "etd"],
            "sta": ["sta", "scheduledarrival", "scheduledarr", "schedarr", "eta"],
            "outtime": ["out", "outtime", "blockout", "off"],
            "intime": ["in", "intime", "blockin", "on"],
            "blocktime": ["block", "blocktime", "total", "totaltime"],
            "nighttime": ["night", "nighttime", "picnight", "p1night", "sicnight", "p2night", "fonight", "captainnight", "firstofficernight"],
            "p1time": ["p1", "p1time", "pictime"],
            "p1ustime": ["p1us", "icus", "p1u/s", "p1ustime", "icustime", "p1supervisedtime"],
            "p2time": ["p2", "sic", "p2time", "sictime", "firstofficer", "copilot", "copilottime", "relief"],
            "instrumenttime": ["instrument", "ifr", "inst", "instr", "actualinstrument", "hood"],
            "simtime": ["sim", "simulator","synthetic","cyclic"],
            "pilotflying": ["pf", "pilotflying", "flying"],
            "pax": ["pax", "positioning", "deadhead", "passenger"],
            "daytakeoffs": ["daytakeoffs", "dayt/o", "dayto", "takeoffsday", "to_day"],
            "daylandings": ["daylandings", "dayldg", "daylandings", "landingsday", "ldg_day"],
            "nighttakeoffs": ["nighttakeoffs", "nightt/o", "nightto", "takeoffsnight", "to_night"],
            "nightlandings": ["nightlandings", "nightldg", "landingsnight", "ldgnight"],
            "rnp": ["rnp", "rnav", "rnp-ar", "rnv"],
            "ils": ["ils", "cat1","cat2"],
            "gls": ["gls"],
            "npa": ["npa"],
            "aiii": ["aiii","cat3"],
            "remarks": ["remarks", "notes", "comments","endorsements"]
        ]

        if let possibleMatches = variations[normalized] {
            if allowMultiple {
                // For fields that support multiple columns, find all matches
                for variation in possibleMatches {
                    let found = headers.filter { $0.lowercased().replacingOccurrences(of: " ", with: "").contains(variation) }
                    matches.append(contentsOf: found)
                }
                // Remove duplicates while preserving order
                matches = Array(NSOrderedSet(array: matches)) as! [String]
            } else {
                // For single column fields, find first match
                for variation in possibleMatches {
                    if let match = headers.first(where: { $0.lowercased().replacingOccurrences(of: " ", with: "").contains(variation) }) {
                        return [match]
                    }
                }
            }
        }

        return matches
    }
}

// MARK: - Field Mapping Row Component
struct FieldMappingRow: View {
    @Binding var mapping: FieldMapping
    let availableHeaders: [String]
    @State private var showingColumnPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(mapping.logbookField)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if mapping.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
                Spacer()
                if mapping.supportsMultipleColumns && mapping.sourceColumns.count > 1 {
                    Text("\(mapping.sourceColumns.count) columns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(mapping.logbookFieldDescription)
                .font(.caption)
                .foregroundColor(.secondary)

            // Column Selection
            if mapping.supportsMultipleColumns {
                // Multiple column selection with strategy
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        showingColumnPicker.toggle()
                    } label: {
                        HStack {
                            if mapping.sourceColumns.isEmpty {
                                Text("Not Mapped")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(mapping.sourceColumns.joined(separator: ", "))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color(.systemGray6).opacity(0.75))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    if !mapping.sourceColumns.isEmpty && mapping.sourceColumns.count > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Will sum all selected columns")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                }
            } else {
                // Single column selection
                Picker("Source Column", selection: Binding(
                    get: { mapping.sourceColumns.first },
                    set: { newValue in
                        mapping.sourceColumns = newValue != nil ? [newValue!] : []
                    }
                )) {
                    Text("Not Mapped").tag(nil as String?)
                    ForEach(availableHeaders.indices, id: \.self) { index in
                        Text(availableHeaders[index]).tag(availableHeaders[index] as String?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingColumnPicker) {
            ColumnPickerView(
                selectedColumns: $mapping.sourceColumns,
                availableHeaders: availableHeaders,
                fieldName: mapping.logbookField
            )
        }
    }
}

// MARK: - Column Picker View
struct ColumnPickerView: View {
    @Binding var selectedColumns: [String]
    let availableHeaders: [String]
    let fieldName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select one or more columns to map to \(fieldName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Available Columns")) {
                    ForEach(availableHeaders.indices, id: \.self) { index in
                        let header = availableHeaders[index]
                        Button {
                            toggleSelection(header)
                        } label: {
                            HStack {
                                Text(header)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedColumns.contains(header) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                if !selectedColumns.isEmpty {
                    Section(header: Text("Selected Columns")) {
                        ForEach(selectedColumns.indices, id: \.self) { index in
                            let column = selectedColumns[index]
                            HStack {
                                Text(column)
                                Spacer()
                                Button {
                                    selectedColumns.removeAll { $0 == column }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Columns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        selectedColumns.removeAll()
                    }
                    .disabled(selectedColumns.isEmpty)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleSelection(_ header: String) {
        if selectedColumns.contains(header) {
            selectedColumns.removeAll { $0 == header }
        } else {
            selectedColumns.append(header)
        }
    }
}

// MARK: - Registration Type Mapping View
struct RegistrationTypeMappingView: View {
    @Binding var mappings: [RegistrationTypeMapping]
    let importData: ImportData
    let fieldMappings: [FieldMapping]
    @Environment(\.dismiss) private var dismiss

    @State private var availableTypes: [String] = []
    @State private var showingAddCustomType = false
    @State private var customTypeName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Map registration patterns to aircraft types. Types will be automatically assigned during import.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button {
                        showingAddCustomType = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Custom Aircraft Type")
                        }
                    }
                }
                
                
                Section(header: Text("Registration Patterns")) {
                    ForEach($mappings) { $mapping in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Registrations: \(mapping.pattern)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(mapping.sampleRegistrations.count) aircraft")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("Examples: \(mapping.sampleRegistrations.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Picker("Aircraft Type", selection: $mapping.aircraftType) {
                                Text("Not Mapped").tag("")
                                ForEach(availableTypes.indices, id: \.self) { index in
                                    Text(availableTypes[index]).tag(availableTypes[index])
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.vertical, 4)
                    }
                }

//                Section {
//                    Button {
//                        showingAddCustomType = true
//                    } label: {
//                        HStack {
//                            Image(systemName: "plus.circle")
//                            Text("Add Custom Aircraft Type")
//                        }
//                    }
//                }
            }
            .navigationTitle("Map Aircraft Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Add Custom Type", isPresented: $showingAddCustomType) {
                TextField("ICAO Type (B788, A35K, etc)", text: $customTypeName)
                Button("Cancel", role: .cancel) {
                    customTypeName = ""
                }
                Button("Add") {
                    if !customTypeName.isEmpty && !availableTypes.contains(customTypeName) {
                        availableTypes.append(customTypeName)
                        customTypeName = ""
                    }
                }
            } message: {
                Text("Enter the ICAO aircraft type")
            }
            .onAppear {
                loadAvailableTypes()
            }
        }
    }

    private func loadAvailableTypes() {
        // Get types from AircraftFleetService
        var types = Set(AircraftFleetService.getAllAircraftTypes())

        // Add any types already in the mappings
        for mapping in mappings {
            if !mapping.aircraftType.isEmpty {
                types.insert(mapping.aircraftType)
            }
        }

        availableTypes = Array(types).sorted()
    }
}

// MARK: - Preview Row View
private struct PreviewRowView: View {
    let row: [String]
    let rowNumber: Int
    let fieldMappings: [FieldMapping]
    let headers: [String]

    // Cache column indices to avoid repeated searches
    private var columnIndices: [String: Int] {
        Dictionary(uniqueKeysWithValues: headers.enumerated().map { ($1, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Row \(rowNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(fieldMappings, id: \.id) { mapping in
                HStack(alignment: .top, spacing: 12) {
                    Text(mapping.logbookField + ":")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 80, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if mapping.sourceColumns.count == 1 {
                        // Single column - show value
                        if let columnIndex = columnIndices[mapping.sourceColumns[0]],
                           columnIndex < row.count {
                            Text(row[columnIndex])
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        // Multiple columns - show combined result
                        VStack(alignment: .leading, spacing: 2) {
                            let values = mapping.sourceColumns.compactMap { column -> Double? in
                                guard let columnIndex = columnIndices[column],
                                      columnIndex < row.count,
                                      let value = Double(row[columnIndex]) else {
                                    return nil
                                }
                                return value
                            }

                            let combined = values.reduce(0, +)
                            Text(String(format: "%.1f", combined))
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("(Sum: \(mapping.sourceColumns.joined(separator: " + ")))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(6)
    }
}

