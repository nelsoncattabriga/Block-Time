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

// MARK: - Saved Mapping
private struct SavedMappingEntry: Codable {
    let logbookField: String
    let sourceColumns: [String]
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
        print("🔍 ImportMappingView init started")
        print("🔍 Row count: \(importData.rows.count)")
        print("🔍 Header count: \(importData.headers.count)")
        self.importData = importData
        self.onImport = onImport

        // Try saved mapping first, fall back to auto-detection
        let key = "LastImportMapping_\(importData.delimiter)"
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([SavedMappingEntry].self, from: data) {
            let validHeaders = Set(importData.headers)
            var mappings = Self.createInitialMappings(headers: importData.headers)
            for i in mappings.indices {
                if let entry = saved.first(where: { $0.logbookField == mappings[i].logbookField }) {
                    let validColumns = entry.sourceColumns.filter { validHeaders.contains($0) }
                    mappings[i].sourceColumns = validColumns
                }
            }
            _fieldMappings = State(initialValue: mappings)
        } else {
            _fieldMappings = State(initialValue: Self.createInitialMappings(headers: importData.headers))
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
                        // Save current mapping for next time
                        let entries = fieldMappings.map { SavedMappingEntry(logbookField: $0.logbookField, sourceColumns: $0.sourceColumns) }
                        if let data = try? JSONEncoder().encode(entries) {
                            UserDefaults.standard.set(data, forKey: "LastImportMapping_\(importData.delimiter)")
                        }
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
                sampleRegistrations: Array(regs.sorted())
            ))
        }

        return mappings
    }

    // MARK: - Smart Field Detection
    private static func createInitialMappings(headers: [String]) -> [FieldMapping] {
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

        // Detect app profile once for all fields
        let profileMap = detectAppProfile(headers: headers)

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
        return mappings
    }

    // MARK: - Column Detection

    /// Strips punctuation, underscores, spaces and lowercases for fuzzy matching
    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "")
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
            "pilotflying":    "flight_pilotFlyingCapacity",
            "daytakeoffs":    "flight_dayTakeoffs",
            "daylandings":    "flight_dayLanding",
            "remarks":        "flight_remarks",
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

        // mccPilotLog — typical CSV export headers
        "mccPilotLog": [
            "date":           "Date",
            "fromairport":    "Departure Place",
            "toairport":      "Arrival Place",
            "aircrafttype":   "Aircraft Model",
            "aircraftreg":    "Registration",
            "blocktime":      "Total Time",
            "p1time":         "PIC",
            "p2time":         "SIC/Co-Pilot",
            "nighttime":      "Night",
            "instrumenttime": "IFR",
            "pilotflying":    "PF",
            "daytakeoffs":    "TO Day",
            "nighttakeoffs":  "TO Night",
            "daylandings":    "LDG Day",
            "nightlandings":  "LDG Night",
            "remarks":        "Remarks",
        ],

        // Logbook Pro (NC Software) — typical CSV export headers
        "Logbook Pro": [
            "date":           "Date",
            "flightnumber":   "Flight No",
            "fromairport":    "From",
            "toairport":      "To",
            "aircraftreg":    "Tail Number",
            "aircrafttype":   "Aircraft Type",
            "blocktime":      "Total Duration",
            "p1time":         "PIC",
            "p2time":         "SIC",
            "nighttime":      "Night",
            "instrumenttime": "Actual IMC",
            "simtime":        "Simulated IMC",
            "daytakeoffs":    "Day Takeoffs",
            "nighttakeoffs":  "Night Takeoffs",
            "daylandings":    "Day Landings",
            "nightlandings":  "Night Landings",
            "remarks":        "Remarks",
        ],
    ]

    /// Returns the best-matching app profile for a given set of headers, or nil if none scores well enough.
    private static func detectAppProfile(headers: [String]) -> [String: String]? {
        let normalizedHeaders = Set(headers.map { normalize($0) })
        var bestProfile: [String: String]? = nil
        var bestScore = 0

        for (_, mapping) in appProfiles {
            // Score = number of profile header values whose normalized form is in the file headers
            let score = mapping.values.filter { normalizedHeaders.contains(normalize($0)) }.count
            // Require at least 4 distinctive matches to use a profile
            if score > bestScore && score >= 4 {
                bestScore = score
                bestProfile = mapping
            }
        }
        return bestProfile
    }

    // MARK: - Synonym Fallback Table
    // Keys are normalized logbook field names.
    // Values are ordered lists of normalized synonyms — more specific first to avoid greedy matches.
    // A synonym only matches if it appears as a WHOLE TOKEN in the normalized header
    // (i.e. the header equals the synonym, or the header contains it surrounded by word boundaries).
    private static let synonyms: [String: [String]] = [
        "date":           ["flightdate", "flightday", "date"],
        "flightnumber":   ["flightnumber", "flightno", "fltno", "flt"],
        "aircraftreg":    ["aircraftreg", "registration", "tailnumber", "tail", "acident", "acid", "regno"],
        "aircrafttype":   ["aircrafttype", "aircraftmodel", "makemodel", "actype", "type", "model", "make"],
        "fromairport":    ["fromairport", "departureplace", "depairport", "departure", "origin", "from", "dep"],
        "toairport":      ["toairport", "arrivalplace", "arrairport", "destination", "arrival", "dest", "arr"],
        "captainname":    ["captainname", "crewpic", "p1crew", "picname", "captain", "cpt", "pic"],
        "f/oname":        ["f/oname", "crewsic", "p2crew", "sicname", "firstofficer", "copilot", "fo"],
        "s/o1name":       ["relief1", "crewrelief", "secondofficer1", "so1", "relief", "cruise", "p3"],
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
        "remarks":        ["remarks", "endorsements", "comments", "notes"],
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

