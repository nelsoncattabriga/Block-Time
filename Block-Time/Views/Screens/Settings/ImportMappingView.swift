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

// MARK: - Registration Rule (one entry in an advanced mapping)
struct RegistrationRule: Identifiable, Codable {
    var id: UUID
    var regFrom: String      // e.g. "EBA" — full reg, inclusive lower bound
    var regTo: String        // e.g. "EBV" — inclusive upper bound; "" = exact match on regFrom
    var afterDate: String?   // "dd/MM/yyyy" inclusive, nil = no lower bound
    var beforeDate: String?  // "dd/MM/yyyy" inclusive, nil = no upper bound
    var aircraftType: String

    init(id: UUID = UUID(), regFrom: String = "", regTo: String = "", afterDate: String? = nil, beforeDate: String? = nil, aircraftType: String = "") {
        self.id = id
        self.regFrom = regFrom
        self.regTo = regTo
        self.afterDate = afterDate
        self.beforeDate = beforeDate
        self.aircraftType = aircraftType
    }

    func matches(reg: String, date: String) -> Bool {
        guard !aircraftType.isEmpty else { return false }
        let regUpper = reg.uppercased()
        let fromUpper = regFrom.uppercased()
        // Registration range check — empty regFrom means "all regs in group", skip check
        if !fromUpper.isEmpty {
            if regTo.isEmpty {
                guard regUpper == fromUpper else { return false }
            } else {
                let toUpper = regTo.uppercased()
                guard regUpper >= fromUpper && regUpper <= toUpper else { return false }
            }
        }
        // Date bounds — dd/MM/yyyy string comparison works correctly when zero-padded
        if let after = afterDate, !after.isEmpty {
            guard compareDDMMYYYY(date, isOnOrAfter: after) else { return false }
        }
        if let before = beforeDate, !before.isEmpty {
            guard compareDDMMYYYY(date, isOnOrBefore: before) else { return false }
        }
        return true
    }
}

// Compares two "dd/MM/yyyy" strings by converting to "yyyy/MM/dd" for lexicographic ordering.
private func compareDDMMYYYY(_ date: String, isOnOrAfter bound: String) -> Bool {
    ddmmyyyyToComparable(date) >= ddmmyyyyToComparable(bound)
}
private func compareDDMMYYYY(_ date: String, isOnOrBefore bound: String) -> Bool {
    ddmmyyyyToComparable(date) <= ddmmyyyyToComparable(bound)
}
private func ddmmyyyyToComparable(_ s: String) -> String {
    let p = s.split(separator: "/")
    guard p.count == 3 else { return s }
    return "\(p[2])/\(p[1])/\(p[0])"
}

// MARK: - Registration to Type Mapping
struct RegistrationTypeMapping: Identifiable, Codable {
    var id: UUID
    let pattern: String              // e.g., "EB*", "OE*"
    var sampleRegistrations: [String]
    var useAdvancedRules: Bool
    var simpleType: String           // used when !useAdvancedRules
    var rules: [RegistrationRule]    // ordered, first-match wins; used when useAdvancedRules

    init(id: UUID = UUID(), pattern: String, sampleRegistrations: [String], simpleType: String = "", useAdvancedRules: Bool = false, rules: [RegistrationRule] = []) {
        self.id = id
        self.pattern = pattern
        self.sampleRegistrations = sampleRegistrations
        self.simpleType = simpleType
        self.useAdvancedRules = useAdvancedRules
        self.rules = rules
    }

    func resolve(reg: String, date: String) -> String {
        if useAdvancedRules {
            return rules.first { $0.matches(reg: reg, date: date) }?.aircraftType ?? ""
        }
        return simpleType
    }
}

// MARK: - Remarks Append Entry
struct RemarksAppendEntry: Identifiable {
    let id: UUID
    var sourceColumn: String
    var label: String  // empty = no label, use "." as separator

    init(sourceColumn: String, label: String = "") {
        self.id = UUID()
        self.sourceColumn = sourceColumn
        self.label = label
    }
}

// MARK: - Pending Slot Config (for undefined counter slots being configured during import)
private struct PendingSlotConfig {
    var label: String = ""
    var type: CounterType = .integer
}

// MARK: - Saved Mapping
private struct SavedRemarksAppendEntry: Codable {
    let sourceColumn: String
    let label: String
}

private struct SavedMappingEntry: Codable {
    let logbookField: String
    let sourceColumns: [String]
    let remarksAppendEntries: [SavedRemarksAppendEntry]?
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
    var remarksAppendEntries: [RemarksAppendEntry]  // Only used for Remarks field

    // Convenience initializer for single column
    init(logbookField: String, logbookFieldDescription: String, sourceColumn: String?, isRequired: Bool, supportsMultipleColumns: Bool = false) {
        self.id = UUID()
        self.logbookField = logbookField
        self.logbookFieldDescription = logbookFieldDescription
        self.sourceColumns = sourceColumn != nil ? [sourceColumn!] : []
        self.isRequired = isRequired
        self.combinationStrategy = .sum  // Always use sum strategy
        self.supportsMultipleColumns = supportsMultipleColumns
        self.remarksAppendEntries = []
    }

    var sourceColumn: String? {
        sourceColumns.first
    }
}

// MARK: - Import Mapping View
struct ImportMappingView: View {
    let importData: ImportData
    let onImport: ([FieldMapping], ImportMode, [RegistrationTypeMapping], Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var fieldMappings: [FieldMapping]
    @State private var detectedProfileName: String?
    @State private var importMode: ImportMode = .merge
    @State private var showingPreview = false
    @State private var previewSelection: PreviewSelection = .first100
    @State private var enableRegistrationMapping = false
    @State private var showingRegistrationMapping = false
    @State private var registrationMappings: [RegistrationTypeMapping] = []
    @AppStorage("importTimesAreLocal") private var timesAreLocal = false
    @State private var pendingSlotConfigs: [Int: PendingSlotConfig] = [:]

    enum PreviewSelection: String, CaseIterable, Identifiable {
        case first100 = "First Rows"
        case last100 = "Last Rows"

        var id: String { self.rawValue }
    }

    init(importData: ImportData, onImport: @escaping ([FieldMapping], ImportMode, [RegistrationTypeMapping], Bool) -> Void) {
        print("🔍 ImportMappingView init started")
        print("🔍 Row count: \(importData.rows.count)")
        print("🔍 Header count: \(importData.headers.count)")
        self.importData = importData
        self.onImport = onImport

        // Try saved mapping first, fall back to auto-detection
        let key = "LastImportMapping_\(importData.delimiter)"
        let initial = Self.createInitialMappings(headers: importData.headers)
        _detectedProfileName = State(initialValue: initial.profileName)

        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([SavedMappingEntry].self, from: data) {
            let validHeaders = Set(importData.headers)
            var mappings = initial.mappings
            for i in mappings.indices {
                if let entry = saved.first(where: { $0.logbookField == mappings[i].logbookField }) {
                    let validColumns = entry.sourceColumns.filter { validHeaders.contains($0) }
                    if !validColumns.isEmpty {
                        mappings[i].sourceColumns = validColumns
                    }
                    if mappings[i].logbookField == "Remarks", let savedAppend = entry.remarksAppendEntries {
                        mappings[i].remarksAppendEntries = savedAppend
                            .filter { validHeaders.contains($0.sourceColumn) }
                            .map { RemarksAppendEntry(sourceColumn: $0.sourceColumn, label: $0.label) }
                    }
                }
            }
            _fieldMappings = State(initialValue: mappings)
        } else {
            _fieldMappings = State(initialValue: initial.mappings)
        }
    }

    var body: some View {
        print("🔍 ImportMappingView body called")
        return NavigationStack {
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

                Section(header: Text("Times Are")) {
                    Picker("Times Are", selection: $timesAreLocal) {
                        Text("UTC").tag(false)
                        Text("Local").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if timesAreLocal {
                        Text("OUT/IN/STD/STA will be converted from local airport time to UTC during import.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Field Mapping")) {
                    if let profileName = detectedProfileName {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("\(profileName) mapping detected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.green.opacity(0.08))
                    }
                    ForEach($fieldMappings) { $mapping in
                        if !isCustomCounterField(mapping.logbookField) {
                            FieldMappingRow(
                                mapping: $mapping,
                                availableHeaders: importData.headers
                            )
                        }
                    }
                }

                Section(header: Text("Custom Fields")) {
                    ForEach(1...10, id: \.self) { slot in
                        let service = CustomCounterService.shared
                        let def = service.definition(for: slot)
                        let mappingIndex = fieldMappings.firstIndex { $0.logbookField == "Counter\(slot)" }
                        if let idx = mappingIndex {
                            CustomFieldSlotRow(
                                slot: slot,
                                mapping: $fieldMappings[idx],
                                pendingConfig: Binding(
                                    get: { pendingSlotConfigs[slot] ?? PendingSlotConfig() },
                                    set: { pendingSlotConfigs[slot] = $0 }
                                ),
                                availableHeaders: importData.headers,
                                isDefined: def != nil,
                                definitionLabel: def?.label ?? "",
                                definitionTypeName: def?.type.displayName ?? ""
                            )
                        }
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
                                    Text("\(registrationMappings.filter { !$0.simpleType.isEmpty }.count) mapped")
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
                        // Save current mapping for next time
                        let entries = fieldMappings.map { m in
                            SavedMappingEntry(
                                logbookField: m.logbookField,
                                sourceColumns: m.sourceColumns,
                                remarksAppendEntries: m.remarksAppendEntries.isEmpty ? nil :
                                    m.remarksAppendEntries.map { SavedRemarksAppendEntry(sourceColumn: $0.sourceColumn, label: $0.label) }
                            )
                        }
                        if let data = try? JSONEncoder().encode(entries) {
                            UserDefaults.standard.set(data, forKey: "LastImportMapping_\(importData.delimiter)")
                        }
                        // Commit any pending new counter definitions before import
                        for slot in 1...10 {
                            guard CustomCounterService.shared.definition(for: slot) == nil else { continue }
                            guard let mapping = fieldMappings.first(where: { $0.logbookField == "Counter\(slot)" }),
                                  !mapping.sourceColumns.isEmpty,
                                  let config = pendingSlotConfigs[slot] else { continue }
                            let trimmedLabel = config.label.trimmingCharacters(in: .whitespaces)
                            guard !trimmedLabel.isEmpty else { continue }
                            CustomCounterService.shared.addToSlot(slot, label: trimmedLabel, type: config.type)
                            UserDefaults.standard.set(true, forKey: "logCustomCount")
                        }
                        onImport(fieldMappings, importMode, enableRegistrationMapping ? registrationMappings : [], timesAreLocal)
                        dismiss()
                    }
                    .disabled(!isValidMapping)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingRegistrationMapping) {
                RegistrationTypeMappingView(mappings: $registrationMappings)
            }
        }
    }

    private var isValidMapping: Bool {
        // Check that all required fields are mapped
        let requiredMapped = fieldMappings.filter { $0.isRequired }.allSatisfy { !$0.sourceColumns.isEmpty }
        // Check: any Counter1..10 slot that is undefined but has a column assigned must have a non-empty label
        let counterSlotsValid = (1...10).allSatisfy { slot in
            guard CustomCounterService.shared.definition(for: slot) == nil else { return true }
            let mapping = fieldMappings.first { $0.logbookField == "Counter\(slot)" }
            guard let cols = mapping?.sourceColumns, !cols.isEmpty else { return true }
            let label = pendingSlotConfigs[slot]?.label.trimmingCharacters(in: .whitespaces) ?? ""
            return !label.isEmpty
        }
        return requiredMapped && counterSlotsValid
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

    // MARK: - Field Classification

    /// Returns true for logbookField values of the form "Counter" followed by one or more digits
    /// (e.g. "Counter1"…"Counter10"). These entries render exclusively in the "Custom Fields"
    /// section and must be excluded from the generic "Field Mapping" ForEach.
    private func isCustomCounterField(_ logbookField: String) -> Bool {
        guard logbookField.hasPrefix("Counter") else { return false }
        let suffix = logbookField.dropFirst("Counter".count)
        return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
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
                sampleRegistrations: Array(regs.sorted()),
                simpleType: detectedType
            ))
        }

        return mappings
    }

    // MARK: - Smart Field Detection
    private static func createInitialMappings(headers: [String]) -> (mappings: [FieldMapping], profileName: String?) {
        print("🔍 createInitialMappings started with \(headers.count) headers")
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
            ("Block Time", "Block time - can combine multiple sources", true, true),    // Supports multiple!
            ("Night Time", "Night time - can combine multiple sources", false, true),  // Supports multiple!
            ("P1 Time", "P1/PIC time - can combine multiple sources", false, true),    // Supports multiple!
            ("P1US Time", "P1US/ICUS time - can combine multiple sources", false, true),  // Supports multiple!
            ("P2 Time", "P2/SIC time - can combine multiple sources", false, true),  // Supports multiple!
            ("Instrument Time", "Instrument time - can combine multiple sources", false, true),  // Supports multiple!
            ("SIM Time", "Simulator time", false, false),
            ("Sp/Ins Time", "Sp/Ins instructor time", false, false),
            ("Pilot Flying", "Is Pilot Flying", false, false),
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

        // Detect app profile once for all fields
        let detected = detectAppProfile(headers: headers)
        let profileMap = detected.map { $0.map }

        let mappings = logbookFields.map { (field, description, required, supportsMultiple) in
            let detectedColumns = detectColumns(for: field, in: headers, allowMultiple: supportsMultiple, profileMap: profileMap)
            return FieldMapping(
                logbookField: field,
                logbookFieldDescription: description,
                sourceColumn: detectedColumns.first,
                isRequired: required,
                supportsMultipleColumns: supportsMultiple
            )
        }

        // Append Counter1…Counter10 entries with auto-detection for defined slots
        let service = CustomCounterService.shared
        var counterMappings: [FieldMapping] = []
        for slot in 1...10 {
            let logbookKey = "Counter\(slot)"
            var detectedColumn: String? = nil
            if let def = service.definition(for: slot) {
                // Fuzzy-match: normalize def.label, check if any header contains/prefixes it
                let normLabel = normalize(def.label)
                detectedColumn = headers.first { h in
                    let normH = normalize(h)
                    return normH == normLabel || normH.hasPrefix(normLabel) || normLabel.hasPrefix(normH)
                }
            }
            counterMappings.append(FieldMapping(
                logbookField: logbookKey,
                logbookFieldDescription: service.definition(for: slot)?.label ?? "Custom Field \(slot)",
                sourceColumn: detectedColumn,
                isRequired: false,
                supportsMultipleColumns: false
            ))
        }
        let allMappings = mappings + counterMappings
        return (mappings: allMappings, profileName: detected?.name)
    }

    // MARK: - Column Detection

    /// Strips all non-alphanumeric characters and lowercases for fuzzy matching
    private static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - Known App Profiles
    // Maps logbook field keys → exact header strings as exported by each app.
    // Detected by scoring how many signature headers are present in the file.
    private static let appProfiles: [String: [String: String]] = [

        // LogTen Pro (Coradine Aviation) — exact export headers
        "LogTen Pro": [
            "date":           "flight_flightDate",
            "flightnumber":   "flight_flightNumber",
            "aircraftreg":    "aircraft_aircraftID",
            "aircrafttype":   "aircraftType_type",
            "fromairport":    "flight_from",
            "toairport":      "flight_to",
            "captainname":    "flight_selectedCrewPIC",
            "f/oname":        "flight_selectedCrewSIC",
            "s/o1name":       "flight_selectedCrewRelief",
            "s/o2name":       "flight_selectedCrewRelief2",
            "std":            "flight_scheduledDepartureTime",
            "sta":            "flight_scheduledArrivalTime",
            "outtime":        "flight_actualDepartureTime",
            "intime":         "flight_actualArrivalTime",
            "blocktime":      "flight_totalTime",
            "nighttime":      "flight_night",
            "p1time":         "flight_pic",
            "p1ustime":       "flight_p1us",
            "p2time":         "flight_sic",
            "instrumenttime": "flight_actualInstrument",
            "simtime":        "flight_simulator",
            "daytakeoffs":    "flight_dayTakeoffs",
            "daylandings":    "flight_dayLandings",
            "nighttakeoffs":  "flight_nightTakeoffs",
            "nightlandings":  "flight_nightLandings",
            "customcount":    "flight_paxCount",
            "remarks":        "flight_remarks",
        ],

       

        // PilotLog (Nolan Systems) — CSV export headers
        "PilotLog": [
            "date":           "pilotlog_date",
            "flightnumber":   "flightnumber",
            "aircraftreg":    "ac_reg",
            "aircrafttype":   "ac_model",
            "fromairport":    "af_dep",
            "toairport":      "af_arr",
            "captainname":    "pilot1_name",
            "f/oname":        "pilot2_name",
            "s/o1name":       "pilot3_name",
            "s/o2name":       "pilot4_name",
            "std":            "time_depsch",
            "sta":            "time_arrsch",
            "outtime":        "time_dep",
            "intime":         "time_arr",
            "blocktime":      "time_total",
            "nighttime":      "time_night",
            "p1time":         "time_pic",
            "p1ustime":       "time_picus",
            "p2time":         "time_sic",
            "instrumenttime": "time_actual",
            "simtime":        "sim_time",     // populated by pre-processing; absent in raw export
            "pilotflying":    "pf",
            "daytakeoffs":    "to_day",
            "daylandings":    "ldg_day",
            "nighttakeoffs":  "to_night",
            "nightlandings":  "ldg_night",
            "remarks":        "remarks",
        ],
        
        // Safelog — typical CSV export headers
        "Safelog": [
            "date":           "DATE",
            "flightnumber":   "FLT_NUM",
            "aircraftreg":    "AC_REG",
            "aircrafttype":   "AC_TYP",
            "fromairport":    "FROM",
            "toairport":      "TO",
            "captainname":    "CAPTAIN",
            "f/oname":        "FIRST_OFFICER",
            "blocktime":      "TOTAL",
            "p1time":         "PIC",
            "p2time":         "SIC",
            "nighttime":      "NIGHT",
            "instrumenttime": "IFR",
            "simtime":        "SIM_TIME",
            "daytakeoffs":    "DAY_TO",
            "nighttakeoffs":  "NIGHT_TO",
            "daylandings":    "DAY_LDG",
            "nightlandings":  "NIGHT_LDG",
            "remarks":        "REMARKS",
        ],
        
    ]

    /// Returns the best-matching app profile name and its normalized key→header map, or nil if none scores well enough.
    private static func detectAppProfile(headers: [String]) -> (name: String, map: [String: String])? {
        let normalizedHeaders = Set(headers.map { normalize($0) })
        var bestName: String? = nil
        var bestMap: [String: String]? = nil
        var bestScore = 0

        for (name, mapping) in appProfiles {
            // Score = number of profile header values whose normalized form is in the file headers
            let score = mapping.values.filter { normalizedHeaders.contains(normalize($0)) }.count
            // Require at least 4 distinctive matches to use a profile
            if score > bestScore && score >= 8 {
                bestScore = score
                bestName = name
                // Return with normalized keys so lookup works correctly
                bestMap = Dictionary(uniqueKeysWithValues: mapping.map { (normalize($0.key), $0.value) })
            }
        }
        guard let name = bestName, let map = bestMap else { return nil }
        return (name: name, map: map)
    }

    // MARK: - Synonym Fallback Table
    // Keys are normalized logbook field names.
    // Values are ordered lists of normalized synonyms — more specific first to avoid greedy matches.
    // A synonym only matches if it appears as a WHOLE TOKEN in the normalized header
    // (i.e. the header equals the synonym, or the header contains it surrounded by word boundaries).
    private static let synonyms: [String: [String]] = [
        "date":           ["flightdate", "flightday", "date"],
        "flightnumber":   ["flightnumber", "flightno", "fltno", "flt"],
        "aircraftreg":    ["aircraftreg", "registration", "tailnumber", "tail", "reg", "rego", "regno"],
        "aircrafttype":   ["aircrafttype", "aircraftmodel", "makemodel", "actype", "type", "model", "make"],
        "fromairport":    ["fromairport", "departureplace", "depairport", "departure", "origin", "from", "dep"],
        "toairport":      ["toairport", "arrivalplace", "arrairport", "destination", "arrival", "dest", "arr","des"],
        "captainname":    ["captainname", "crewpic", "p1crew", "picname", "captain", "capt", "cpt", "pic"],
        "f/oname":        ["f/oname", "crewsic", "p2crew", "sicname", "firstofficer", "copilot", "fo"],
        "s/o1name":       ["relief1", "crewrelief", "secondofficer1", "so1", "relief", "cruise", "p3", "so"],
        "s/o2name":       ["relief2", "crewrelief2", "secondofficer2", "so2", "p4"],
        "std":            ["scheduleddeparturetime", "scheduleddeparture", "scheduleddep", "scheddep", "std", "etd"],
        "sta":            ["scheduledarrivaltime", "scheduledarrival", "scheduledarr", "schedarr", "sta", "eta"],
        "outtime":        ["actualdeparturetime", "blockout", "outtime", "out"],
        "intime":         ["actualarrivaltime", "blockin", "intime"],
        "blocktime":      ["totaltime", "totalduration", "blocktime", "total", "block", "tot"],
        "nighttime":      ["nighttime", "picnight", "p1night", "sicnight", "p2night", "fonight", "captainnight", "night"],
        "p1time":         ["pictime", "p1time", "pic"],
        "p1ustime":       ["p1ustime", "icustime", "p1supervisedtime", "spte", "p1us", "icus"],
        "p2time":         ["sictime", "p2time", "siccopilot", "copilottime", "sic", "p2"],
        "instrumenttime": ["actualinstrument", "actualimc", "instrumenttime", "instrument", "actualifr", "ifrtime", "ifr", "inst"],
        "simtime":        ["simulatortime", "simtime", "simulator", "synthetic", "simimc", "sim"],
        "spinstime":      ["spinstructortime", "spinstime", "spinstructor", "spins", "spinstr", "inst", "instructor", "instruct", "special"],
        "pilotflying":    ["pilotflyingcapacity", "pilotflying", "flying", "pf"],
        "pax":            ["positioning", "deadhead", "passengerflight", "dh", "pax"],
        "daytakeoffs":    ["daytakeoffs", "takeoffsday", "today", "tday", "dayt/o", "dto"],
        "daylandings":    ["daylanding", "daylandings", "landingsday", "ldgday", "dayldg"],
        "nighttakeoffs":  ["nighttakeoffs", "takeoffsnight", "tonight", "nightt/o", "nto"],
        "nightlandings":  ["nightlanding", "nightlandings", "landingsnight", "ldgnight", "nightldg"],
        "rnp":            ["rnpapproach", "rnpar", "rnav", "rnp"],
        "ils":            ["ilsapproach", "catii", "cati", "cat2", "cat1", "ils"],
        "gls":            ["glsapproach", "gls"],
        "npa":            ["npaapproach", "npa"],
        "aiii":           ["aiiiapproach", "catiii", "cat3", "aiii"],
        "remarks":        ["remarks", "endorsements", "comments", "notes", "details"],
        "customcount":    ["customcount", "paxcount", "totalpax", "passengercount", "soulsonboard", "sob", "passengers"],
    ]

    /// Returns true if `synonym` matches `header` as a whole token or exact equality.
    /// This prevents "to" matching "totaltime", "type" matching "aircrafttype", etc.
    private static func tokenMatches(_ header: String, synonym: String) -> Bool {
        guard !synonym.isEmpty else { return false }
        if header == synonym { return true }
        // Whole-word containment: synonym must not be surrounded by other word characters
        // We check by seeing if splitting on the synonym leaves only empty/non-alpha boundaries
        let parts = header.components(separatedBy: synonym)
        guard parts.count >= 2 else { return false }
        let before = parts.first ?? ""
        let after = parts.dropFirst().joined(separator: synonym) // rejoin in case synonym appears twice
        let beforeOK = before.isEmpty || !before.last!.isLetter && !before.last!.isNumber
        let afterOK = after.isEmpty || !after.first!.isLetter && !after.first!.isNumber
        return beforeOK && afterOK
    }

    private static func detectColumns(for logbookField: String, in headers: [String], allowMultiple: Bool, profileMap: [String: String]?) -> [String] {
        let fieldKey = normalize(logbookField)
        let normalizedHeaders = headers.map { (original: $0, norm: normalize($0)) }

        // TIER 1: Exact match on raw header string (case-insensitive)
        let fieldNorm = normalize(logbookField)
        if let exact = normalizedHeaders.first(where: { $0.norm == fieldNorm }) {
            return [exact.original]
        }

        // TIER 2: Known app profile — look up by normalized profile header value
        if let profileMap = profileMap, let profileHeader = profileMap[fieldKey] {
            let profileNorm = normalize(profileHeader)
            if let match = normalizedHeaders.first(where: { $0.norm == profileNorm }) {
                return [match.original]
            }
        }

        // TIER 3: Synonym fallback
        guard let fieldSynonyms = synonyms[fieldKey] else { return [] }

        if allowMultiple {
            var matches: [String] = []
            var seen = Set<String>()
            for synonym in fieldSynonyms {
                for entry in normalizedHeaders {
                    if tokenMatches(entry.norm, synonym: synonym) && !seen.contains(entry.original) {
                        matches.append(entry.original)
                        seen.insert(entry.original)
                    }
                }
            }
            return matches
        } else {
            for synonym in fieldSynonyms {
                if let match = normalizedHeaders.first(where: { tokenMatches($0.norm, synonym: synonym) }) {
                    return [match.original]
                }
            }
            return []
        }
    }
}

// MARK: - Field Mapping Row Component
struct FieldMappingRow: View {
    @Binding var mapping: FieldMapping
    let availableHeaders: [String]
    @State private var showingColumnPicker = false
    @State private var showingAppendColumnPicker = false
    // Temporary single-selection binding for append picker
    @State private var appendPickerSelection: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text({
                    let f = mapping.logbookField
                    let isCounter = f.hasPrefix("Counter") && f.dropFirst("Counter".count).allSatisfy(\.isNumber)
                    return isCounter ? (mapping.logbookFieldDescription.isEmpty ? f : mapping.logbookFieldDescription) : f
                }())
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
                // Single column selection — use sheet picker to avoid eagerly building all header rows
                Button {
                    showingColumnPicker.toggle()
                } label: {
                    HStack {
                        if let selected = mapping.sourceColumns.first {
                            Text(selected)
                                .lineLimit(1)
                        } else {
                            Text("Not Mapped")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(.systemGray6).opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            // Remarks append section — only for Remarks field
            if mapping.logbookField == "Remarks" {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Append to Remarks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            appendPickerSelection = []
                            showingAppendColumnPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                                Text("Add column")
                                    .font(.caption)
                            }
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach($mapping.remarksAppendEntries) { $entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.sourceColumn)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    mapping.remarksAppendEntries.removeAll { $0.id == entry.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            TextField("Label (optional)", text: $entry.label)
                                .font(.caption)
                                .padding(6)
                                .background(Color(.systemGray6).opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(8)
                        .background(Color(.systemGray6).opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if !mapping.remarksAppendEntries.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "text.append")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Appended after remarks, separated by \".\"")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingColumnPicker) {
            ColumnPickerView(
                selectedColumns: $mapping.sourceColumns,
                availableHeaders: availableHeaders,
                fieldName: mapping.logbookField,
                allowMultiple: mapping.supportsMultipleColumns
            )
        }
        .sheet(isPresented: $showingAppendColumnPicker, onDismiss: {
            if let selected = appendPickerSelection.first {
                let alreadyMapped = mapping.sourceColumns.contains(selected) ||
                    mapping.remarksAppendEntries.contains { $0.sourceColumn == selected }
                if !alreadyMapped {
                    mapping.remarksAppendEntries.append(RemarksAppendEntry(sourceColumn: selected))
                }
            }
            appendPickerSelection = []
        }) {
            ColumnPickerView(
                selectedColumns: $appendPickerSelection,
                availableHeaders: availableHeaders,
                fieldName: "Append to Remarks",
                allowMultiple: false
            )
        }
    }
}

// MARK: - Custom Field Slot Row
private struct CustomFieldSlotRow: View {
    let slot: Int
    @Binding var mapping: FieldMapping
    @Binding var pendingConfig: PendingSlotConfig
    let availableHeaders: [String]
    let isDefined: Bool
    let definitionLabel: String      // non-empty when isDefined
    let definitionTypeName: String   // non-empty when isDefined

    @State private var showingColumnPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isDefined {
                HStack(spacing: 6) {
                    Text(definitionLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("· \(definitionTypeName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                HStack {
                    Text("Custom Field \(slot)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            // Column picker button (same style as FieldMappingRow single-column picker)
            Button { showingColumnPicker.toggle() } label: {
                HStack {
                    if let selected = mapping.sourceColumns.first {
                        Text(selected).lineLimit(1)
                    } else {
                        Text("Not Mapped").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color(.systemGray6).opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            // Inline label + type config — only for undefined slots that have a column assigned
            if !isDefined && !mapping.sourceColumns.isEmpty {
                HStack(spacing: 8) {
                    TextField("Label", text: $pendingConfig.label)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    Picker("Type", selection: $pendingConfig.type) {
                        ForEach(CounterType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingColumnPicker) {
            ColumnPickerView(
                selectedColumns: $mapping.sourceColumns,
                availableHeaders: availableHeaders,
                fieldName: isDefined ? definitionLabel : "Custom Field \(slot)",
                allowMultiple: false
            )
        }
    }
}

// MARK: - Column Picker View
struct ColumnPickerView: View {
    @Binding var selectedColumns: [String]
    let availableHeaders: [String]
    let fieldName: String
    var allowMultiple: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(allowMultiple ? "Select one or more columns to map to \(fieldName)" : "Select a column to map to \(fieldName)")
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

                if allowMultiple && !selectedColumns.isEmpty {
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
            .navigationTitle("Select Column\(allowMultiple ? "s" : "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if allowMultiple {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Clear All") {
                            selectedColumns.removeAll()
                        }
                        .disabled(selectedColumns.isEmpty)
                    }
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
        if !allowMultiple {
            selectedColumns = selectedColumns.first == header ? [] : [header]
            dismiss()
            return
        }
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
    @Environment(\.dismiss) private var dismiss

    @State private var availableTypes: [String] = []
    @State private var showingManageTypes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Explainer
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AppColors.accentBlue)
                        Text("Use **Simple** when one prefix = one fleet. Use **Advanced** when the same prefix spans multiple fleets (different rego ranges or time periods).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .appCardStyle()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    ForEach($mappings) { $mapping in
                        RegistrationPatternRow(mapping: $mapping, availableTypes: $availableTypes)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }

                    // Manage custom types
                    Button {
                        showingManageTypes = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(AppColors.accentBlue)
                            Text("Manage Custom Types")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.accentBlue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .appCardStyle()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Aircraft Type Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingManageTypes) {
                ManageCustomTypesView(
                    availableTypes: $availableTypes,
                    mappings: $mappings
                )
            }
            .onAppear { loadAvailableTypes() }
        }
    }

    private func loadAvailableTypes() {
        var types = Set(AircraftFleetService.getAllAircraftTypes())
        for mapping in mappings {
            if !mapping.simpleType.isEmpty { types.insert(mapping.simpleType) }
            for rule in mapping.rules where !rule.aircraftType.isEmpty { types.insert(rule.aircraftType) }
        }
        availableTypes = Array(types).sorted()
    }
}

// MARK: - Manage Custom Types View
private struct ManageCustomTypesView: View {
    @Binding var availableTypes: [String]
    @Binding var mappings: [RegistrationTypeMapping]
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddType = false
    @State private var newTypeName = ""
    @State private var typeToDelete: String? = nil

    private let builtIn: Set<String> = Set(AircraftFleetService.getAllAircraftTypes())

    private var customTypes: [String] {
        availableTypes.filter { !builtIn.contains($0) }
    }

    private func usageCount(for type: String) -> Int {
        var count = 0
        for mapping in mappings {
            if mapping.simpleType == type { count += 1 }
            count += mapping.rules.filter { $0.aircraftType == type }.count
        }
        return count
    }

    private func delete(_ type: String) {
        availableTypes.removeAll { $0 == type }
        for i in mappings.indices {
            if mappings[i].simpleType == type { mappings[i].simpleType = "" }
            for j in mappings[i].rules.indices {
                if mappings[i].rules[j].aircraftType == type {
                    mappings[i].rules[j].aircraftType = ""
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !customTypes.isEmpty {
                    Section("Custom") {
                        ForEach(customTypes, id: \.self) { type in
                            HStack {
                                Text(type)
                                    .font(.subheadline)
                                Spacer()
                                let count = usageCount(for: type)
                                if count > 0 {
                                    Text("\(count) mapping\(count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    typeToDelete = type
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("No custom types added yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Built-in") {
                    ForEach(availableTypes.filter { builtIn.contains($0) }, id: \.self) { type in
                        Text(type)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Manage Custom Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddType = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Add Custom Type", isPresented: $showingAddType) {
                TextField("ICAO Type (B788, A35K, etc)", text: $newTypeName)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) { newTypeName = "" }
                Button("Add") {
                    let t = newTypeName.trimmingCharacters(in: .whitespaces).uppercased()
                    if !t.isEmpty && !availableTypes.contains(t) {
                        availableTypes.append(t)
                        availableTypes.sort()
                    }
                    newTypeName = ""
                }
            } message: {
                Text("Enter the ICAO aircraft type")
            }
            .alert(
                "Delete \(typeToDelete ?? "")?",
                isPresented: Binding(
                    get: { typeToDelete != nil },
                    set: { if !$0 { typeToDelete = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { typeToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let t = typeToDelete { delete(t) }
                    typeToDelete = nil
                }
            } message: {
                if let t = typeToDelete {
                    let count = usageCount(for: t)
                    if count > 0 {
                        Text("\(count) mapping\(count == 1 ? "" : "s") use this type. Deleting will clear those assignments.")
                    } else {
                        Text("This type is not currently assigned to any mappings.")
                    }
                }
            }
        }
    }
}

// MARK: - Registration Pattern Row
private struct RegistrationPatternRow: View {
    @Binding var mapping: RegistrationTypeMapping
    @Binding var availableTypes: [String]
    @State private var showingAddType = false
    @State private var newTypeName = ""

    var resolvedLabel: String {
        if mapping.useAdvancedRules {
            let count = mapping.rules.count
            return count == 0 ? "No rules yet" : "\(count) rule\(count == 1 ? "" : "s")"
        }
        return mapping.simpleType.isEmpty ? "Not mapped" : mapping.simpleType
    }

    var isResolved: Bool {
        if mapping.useAdvancedRules {
            return !mapping.rules.isEmpty && mapping.rules.allSatisfy { !$0.aircraftType.isEmpty }
        }
        return !mapping.simpleType.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "airplane")
                            .font(.footnote)
                            .foregroundStyle(isResolved ? AppColors.accentBlue : .orange)
                        Text(mapping.pattern)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text(mapping.sampleRegistrations.prefix(6).joined(separator: "  ") + (mapping.sampleRegistrations.count > 6 ? "  …" : ""))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                // Resolved badge
                Text(resolvedLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isResolved ? AppColors.accentBlue : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isResolved ? AppColors.accentBlue : Color.orange).opacity(0.12))
                    .clipShape(Capsule())
            }

            Divider()

            // Mode picker
            HStack {
                Text("Mode")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Mode", selection: $mapping.useAdvancedRules) {
                    Text("Simple").tag(false)
                    Text("Advanced").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            // Content
            if mapping.useAdvancedRules {
                AdvancedRulesEditor(rules: $mapping.rules, availableTypes: $availableTypes)
            } else {
                HStack {
                    Text("Aircraft type")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Aircraft Type", selection: $mapping.simpleType) {
                        Text("Not mapped").tag("")
                        ForEach(availableTypes, id: \.self) { Text($0).tag($0) }
                        Divider()
                        Text("Add type...").tag("__add__")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: mapping.simpleType) { _, newValue in
                        if newValue == "__add__" {
                            mapping.simpleType = ""
                            showingAddType = true
                        }
                    }
                }
            }
        }
        .padding(14)
        .appCardStyle()
        .alert("Add Custom Type", isPresented: $showingAddType) {
            TextField("ICAO Type (B788, A35K, etc)", text: $newTypeName)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { newTypeName = "" }
            Button("Add") {
                let t = newTypeName.trimmingCharacters(in: .whitespaces).uppercased()
                if !t.isEmpty && !availableTypes.contains(t) {
                    availableTypes.append(t)
                    availableTypes.sort()
                    mapping.simpleType = t
                }
                newTypeName = ""
            }
        } message: {
            Text("Enter the ICAO aircraft type")
        }
    }
}

// MARK: - Advanced Rules Editor
private struct AdvancedRulesEditor: View {
    @Binding var rules: [RegistrationRule]
    @Binding var availableTypes: [String]
    @State private var expandedRuleID: UUID? = nil

    private enum DatePickTarget: Identifiable {
        case after(UUID)
        case before(UUID)
        var id: String {
            switch self {
            case .after(let id): return "after-\(id)"
            case .before(let id): return "before-\(id)"
            }
        }
        var ruleID: UUID {
            switch self { case .after(let id), .before(let id): return id }
        }
        var isAfter: Bool {
            if case .after = self { return true }
            return false
        }
    }
    @State private var datePickTarget: DatePickTarget? = nil

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($rules) { $rule in
                RegistrationRuleRow(
                    rule: $rule,
                    availableTypes: $availableTypes,
                    isExpanded: expandedRuleID == rule.id,
                    onToggle: {
                        expandedRuleID = (expandedRuleID == rule.id) ? nil : rule.id
                    },
                    onDelete: {
                        let idToRemove = rule.id
                        if expandedRuleID == idToRemove { expandedRuleID = nil }
                        Task { @MainActor in
                            rules.removeAll { $0.id == idToRemove }
                        }
                    },
                    onPickAfterDate: { datePickTarget = .after(rule.id) },
                    onPickBeforeDate: { datePickTarget = .before(rule.id) }
                )
            }

            Button {
                let newRule = RegistrationRule()
                rules.append(newRule)
                expandedRuleID = newRule.id
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Rule")
                        .fontWeight(.medium)
                }
                .font(.footnote)
                .foregroundStyle(AppColors.accentBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColors.accentBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.accentBlue.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if !rules.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                    Text("Evaluated top to bottom — first match wins")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $datePickTarget) { target in
            datePickerSheet(for: target)
        }
    }

    @ViewBuilder
    private func datePickerSheet(for target: DatePickTarget) -> some View {
        let ruleID = target.ruleID
        let isAfter = target.isAfter
        if let idx = rules.firstIndex(where: { $0.id == ruleID }) {
            let currentValue = isAfter ? rules[idx].afterDate : rules[idx].beforeDate
            let initial = currentValue.flatMap { Self.displayFormatter.date(from: $0) } ?? Date()
            DatePickerSheet(
                title: isAfter ? "Flights after" : "Flights before",
                initialDate: initial,
                onSelect: { date in
                    if let i = rules.firstIndex(where: { $0.id == ruleID }) {
                        if isAfter { rules[i].afterDate = Self.displayFormatter.string(from: date) }
                        else       { rules[i].beforeDate = Self.displayFormatter.string(from: date) }
                    }
                },
                onClear: {
                    if let i = rules.firstIndex(where: { $0.id == ruleID }) {
                        if isAfter { rules[i].afterDate = nil }
                        else       { rules[i].beforeDate = nil }
                    }
                }
            )
        } else {
            EmptyView()
        }
    }
}

// MARK: - Registration Rule Row
private struct RegistrationRuleRow: View {
    @Binding var rule: RegistrationRule
    @Binding var availableTypes: [String]
    let isExpanded: Bool
    @State private var showingAddType = false
    @State private var newTypeName = ""
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onPickAfterDate: () -> Void
    let onPickBeforeDate: () -> Void

    private var isComplete: Bool { !rule.aircraftType.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed summary row — always visible
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    // Status dot
                    Circle()
                        .fill(isComplete ? AppColors.accentBlue : Color.orange)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        ruleConditionSummary
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(rule.aircraftType.isEmpty ? "Type not set" : rule.aircraftType)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(rule.aircraftType.isEmpty ? .orange : AppColors.accentBlue)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)

            // Expanded editor
            if isExpanded {
                Divider().padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 14) {
                    // Registration range
                    fieldGroup(label: "Rego range within group  (blank = all regos in group)", systemImage: "airplane") {
                        HStack(spacing: 8) {
                            TextField("From  e.g. EBA", text: $rule.regFrom)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .textFieldStyle(InlineTextFieldStyle())
                            Text("to")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            TextField("To  e.g. EBV", text: $rule.regTo)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .textFieldStyle(InlineTextFieldStyle())
                        }
                    }

                    // Date range
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Date range  (optional — set either, both, or neither)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .center, spacing: 10) {
                            // Timeline rail
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(rule.afterDate != nil ? AppColors.accentBlue : Color.secondary.opacity(0.3))
                                    .frame(width: 7, height: 7)
                                Rectangle()
                                    .fill(
                                        rule.afterDate != nil && rule.beforeDate != nil
                                            ? AppColors.accentBlue.opacity(0.4)
                                            : Color.secondary.opacity(0.15)
                                    )
                                    .frame(width: 1.5)
                                    .frame(minHeight: 20)
                                Circle()
                                    .fill(rule.beforeDate != nil ? AppColors.accentBlue : Color.secondary.opacity(0.3))
                                    .frame(width: 7, height: 7)
                            }

                            // Chips
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text("After")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 42, alignment: .trailing)
                                    dateChip(label: "any date", value: $rule.afterDate, onTap: onPickAfterDate)
                                    Spacer()
                                }
                                HStack(spacing: 8) {
                                    Text("Before")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 42, alignment: .trailing)
                                    dateChip(label: "any date", value: $rule.beforeDate, onTap: onPickBeforeDate)
                                    Spacer()
                                }
                            }
                        }
                    }

                    // Aircraft type
                    fieldGroup(label: "Aircraft type", systemImage: "tag") {
                        Picker("Type", selection: $rule.aircraftType) {
                            Text("Not set").tag("")
                            ForEach(availableTypes, id: \.self) { Text($0).tag($0) }
                            Divider()
                            Text("Add type...").tag("__add__")
                        }
                        .pickerStyle(.menu)
                        .padding(.leading, -8)
                        .onChange(of: rule.aircraftType) { _, newValue in
                            if newValue == "__add__" {
                                rule.aircraftType = ""
                                showingAddType = true
                            }
                        }
                    }

                    Divider()

                    Button(role: .destructive, action: onDelete) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Remove this rule")
                        }
                        .font(.footnote)
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
        }
        .background(Color(.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isComplete ? AppColors.accentBlue.opacity(0.25) : Color.orange.opacity(0.35), lineWidth: 1)
        )
        .alert("Add Custom Type", isPresented: $showingAddType) {
            TextField("ICAO Type (B788, A35K, etc)", text: $newTypeName)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { newTypeName = "" }
            Button("Add") {
                let t = newTypeName.trimmingCharacters(in: .whitespaces).uppercased()
                if !t.isEmpty && !availableTypes.contains(t) {
                    availableTypes.append(t)
                    availableTypes.sort()
                    rule.aircraftType = t
                }
                newTypeName = ""
            }
        } message: {
            Text("Enter the ICAO aircraft type")
        }
    }

    @ViewBuilder
    private var ruleConditionSummary: some View {
        let regPart: String = {
            let f = rule.regFrom.trimmingCharacters(in: .whitespaces)
            let t = rule.regTo.trimmingCharacters(in: .whitespaces)
            if f.isEmpty { return "All regos in group" }
            return t.isEmpty ? f : "\(f) – \(t)"
        }()
        let datePart: String = {
            let a = rule.afterDate ?? ""
            let b = rule.beforeDate ?? ""
            if a.isEmpty && b.isEmpty { return "Any date" }
            if a.isEmpty { return "Before \(b)" }
            if b.isEmpty { return "From \(a)" }
            return "\(a) – \(b)"
        }()
        Text("\(regPart)  ·  \(datePart)")
            .font(.footnote)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(label: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    @ViewBuilder
    private func dateChip(label: String, value: Binding<String?>, onTap: @escaping () -> Void) -> some View {
        let isSet = value.wrappedValue != nil
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(value.wrappedValue ?? label)
                    .font(.footnote)
                    .foregroundStyle(isSet ? AppColors.accentBlue : .secondary)
                if isSet {
                    Button { value.wrappedValue = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.accentBlue.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSet ? AppColors.accentBlue.opacity(0.08) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(
                isSet ? AppColors.accentBlue.opacity(0.35) : Color.primary.opacity(0.1),
                lineWidth: isSet ? 1.5 : 1
            ))
        }
        .buttonStyle(.plain)
    }
}

private struct InlineTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.footnote)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Date Picker Sheet
private struct DatePickerSheet: View {
    let title: String
    let initialDate: Date
    let onSelect: (Date) -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Date

    init(title: String, initialDate: Date, onSelect: @escaping (Date) -> Void, onClear: @escaping () -> Void) {
        self.title = title
        self.initialDate = initialDate
        self.onSelect = onSelect
        self.onClear = onClear
        _selected = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(title, selection: $selected, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Button("Clear date", role: .destructive) {
                    onClear()
                    dismiss()
                }
                .padding(.bottom)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        onSelect(selected)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(480)])
    }
}

// MARK: - Preview Row View
private struct PreviewRowView: View {
    let row: [String]
    let rowNumber: Int
    let fieldMappings: [FieldMapping]
    let headers: [String]

    // Cache column indices to avoid repeated searches
    // Uses keepingLast to safely handle duplicate header names (e.g. empty string columns)
    private var columnIndices: [String: Int] {
        Dictionary(headers.enumerated().map { ($1, $0) }, uniquingKeysWith: { _, last in last })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Row \(rowNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(fieldMappings, id: \.id) { mapping in
                HStack(alignment: .top, spacing: 12) {
                    Text({
                        let f = mapping.logbookField
                        let isCounter = f.hasPrefix("Counter") && f.dropFirst("Counter".count).allSatisfy(\.isNumber)
                        let label = isCounter ? (mapping.logbookFieldDescription.isEmpty ? f : mapping.logbookFieldDescription) : f
                        return label + ":"
                    }())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 80, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if mapping.sourceColumns.count == 1 {
                        // Single column - show value
                        VStack(alignment: .leading, spacing: 2) {
                            if let columnIndex = columnIndices[mapping.sourceColumns[0]],
                               columnIndex < row.count {
                                let base = row[columnIndex]
                                let appended = mapping.remarksAppendEntries.compactMap { entry -> String? in
                                    guard let idx = columnIndices[entry.sourceColumn], idx < row.count else { return nil }
                                    let val = row[idx].trimmingCharacters(in: .whitespaces)
                                    guard !val.isEmpty else { return nil }
                                    return entry.label.trimmingCharacters(in: .whitespaces).isEmpty ? val : "\(entry.label.trimmingCharacters(in: .whitespaces)): \(val)"
                                }
                                let preview = ([base] + appended).filter { !$0.isEmpty }.joined(separator: ". ")
                                Text(preview)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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

