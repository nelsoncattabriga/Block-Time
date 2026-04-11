//
//  FileImportService.swift
//  Block-Time
//
//  Created by Nelson on 1/10/2025.
//


import Foundation
import CommonCrypto

class FileImportService {
    static let shared = FileImportService()

    private init() {}

    // MARK: - Parse File
    func parseFile(url: URL, forceSecurityScoping: Bool = true) throws -> ImportData {
        // Check if this file needs security-scoped access
        // Files in the app's own container (local or iCloud) don't need it
        // forceSecurityScoping can be set to false to skip this for files we know are in our container
        let needsSecurityScopedAccess = forceSecurityScoping && !isInAppContainer(url)

        if needsSecurityScopedAccess {
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.accessDenied
            }
        }
        defer {
            if needsSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let content = try String(contentsOf: url, encoding: .utf8)

        // Detect delimiter
        let delimiter = detectDelimiter(content: content)

        // Parse into rows using multiline-aware parser
        let allRows = parseCSVRows(content: content, delimiter: delimiter)

        guard !allRows.isEmpty else {
            throw ImportError.emptyFile
        }

        // First row is headers
        let headers = allRows[0]

        // Remaining rows are data
        let dataRows = Array(allRows.dropFirst())

        // Apply profile-specific pre-processing so the data is Block-Time-friendly before mapping
        let (processedHeaders, processedRows) = FileImportService.preprocess(headers: headers, rows: dataRows)

        return ImportData(
            headers: processedHeaders,
            rows: processedRows,
            fileURL: url,
            delimiter: delimiter
        )
    }

    // MARK: - Check if URL is in App Container
    /// Check if a file URL is in the app's own container (local Documents or iCloud container)
    /// Files in the app's container don't need security-scoped resource access
    private func isInAppContainer(_ url: URL) -> Bool {
        let path = url.path

        // Check if in app's local Documents directory
        if let appDocuments = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            if path.hasPrefix(appDocuments.path) {
                LogManager.shared.info("📁 File is in app's local Documents directory")
                return true
            }
        }

        // Check if in app's iCloud container
        if path.contains("iCloud~com~thezoolab~blocktime") {
            LogManager.shared.info("File is in app's iCloud container")
            return true
        }

        LogManager.shared.info("🔐 File is in external location, will use security-scoped access")
        return false
    }

    // MARK: - Detect Delimiter
    private func detectDelimiter(content: String) -> String {
        let firstLine = content.components(separatedBy: .newlines).first ?? ""

        let tabCount = firstLine.components(separatedBy: "\t").count - 1
        let commaCount = firstLine.components(separatedBy: ",").count - 1

        // Tab takes precedence if both exist (more common for exports)
        return tabCount > commaCount ? "\t" : ","
    }

    // MARK: - Parse CSV Line (handles quoted fields)
    private func parseCSVLine(_ line: String, delimiter: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if String(char) == delimiter && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
    }

    // MARK: - Parse CSV with Multiline Support
    /// Parse CSV content that may contain newlines within quoted fields
    /// This is more robust than splitting by newlines first
    private func parseCSVRows(content: String, delimiter: String) -> [[String]] {
        LogManager.shared.info("🔍 parseCSVRows started, content length: \(content.count)")

        // Strip BOM if present
        var cleanedContent = content
        if cleanedContent.hasPrefix("\u{FEFF}") {
            LogManager.shared.info("🔍 Stripping UTF-8 BOM")
            cleanedContent.removeFirst()
        }

        // Normalise line endings: Swift treats \r\n as a single grapheme cluster,
        // so character iteration won't see \r or \n separately without this step.
        cleanedContent = cleanedContent
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let delimChar: Character = delimiter.isEmpty ? "," : delimiter.first!
        var rows: [[String]] = []
        var currentField = ""
        var fields: [String] = []
        var inQuotes = false
        let chars = Array(cleanedContent)
        var i = 0

        while i < chars.count {
            let char = chars[i]
            if char == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    currentField.append("\"")
                    i += 2
                    continue
                } else {
                    inQuotes.toggle()
                }
            } else if char == delimChar && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else if char == "\n" && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                if !fields.isEmpty && !fields.allSatisfy({ $0.isEmpty }) {
                    rows.append(fields)
                }
                fields = []
            } else {
                currentField.append(char)
            }
            i += 1
        }
        // Handle final field/row
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        if !fields.isEmpty && !fields.allSatisfy({ $0.isEmpty }) {
            rows.append(fields)
        }

        LogManager.shared.info("🔍 parseCSVRows completed: \(rows.count) rows total")
        if rows.count > 0 {
            LogManager.shared.info("🔍 Row 1: \(rows[0].count) fields")
        }
        if rows.count > 1 {
            LogManager.shared.info("🔍 Row 2: \(rows[1].count) fields")
        }
        if rows.count > 2 {
            LogManager.shared.info("🔍 Row 3: \(rows[2].count) fields")
        }
        if !rows.isEmpty {
            LogManager.shared.info("🔍 First row has \(rows[0].count) fields")
        }

        return rows
    }

    private func parseCVSLine(_ line: String, delimiter: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var previousChar: Character? = nil

        for char in line {
            if char == "\"" {
                // Handle escaped quotes ("")
                if insideQuotes && previousChar == "\"" {
                    currentField.append(char)
                    previousChar = nil
                    continue
                }
                insideQuotes.toggle()
                previousChar = char
            } else if String(char) == delimiter && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                previousChar = char
            } else {
                currentField.append(char)
                previousChar = char
            }
        }

        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
    }

    // MARK: - Import with Mapping
    func importFlights(
        from importData: ImportData,
        mapping: [FieldMapping],
        mode: ImportMode,
        registrationMappings: [RegistrationTypeMapping] = [],
        completion: @escaping (Result<ImportResult, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let databaseService = FlightDatabaseService.shared

            // Disable CloudKit sync for large imports to avoid background task timeouts
            var cloudKitWasEnabled = false
            DispatchQueue.main.sync {
                cloudKitWasEnabled = databaseService.disableCloudKitSync()
            }

            // Delete all if replace mode - with proper cleanup
            if case .replace = mode {
                DispatchQueue.main.sync {
                    _ = databaseService.clearAllFlights()
                }
                // Give Core Data time to process the deletions
                Thread.sleep(forTimeInterval: 0.5)
            }

            // Create column index mapping
            let columnMapping = self.createColumnMapping(
                headers: importData.headers,
                fieldMappings: mapping
            )


            // Create registration to type lookup
            let regToTypeMap = self.createRegistrationTypeMap(mappings: registrationMappings)

            var successCount = 0
            var failureCount = 0
            var flightsToImport: [(flight: FlightSector, rowIndex: Int)] = []
            var failureReasons: [String: Int] = [:]
            var sampleFailures: [(row: Int, reason: String)] = []

            // Collect unique crew names during import
            var captainNames = Set<String>()
            var foNames = Set<String>()
            var so1Names = Set<String>()
            var so2Names = Set<String>()

            // First, create all flight objects
            for (index, row) in importData.rows.enumerated() {
                let result = self.createFlightFromRow(row, mapping: columnMapping, registrationTypeMap: regToTypeMap, rowIndex: index + 1)

                switch result {
                case .success(let flight):
                    flightsToImport.append((flight, index + 1))

                    // Collect crew names
                    if !flight.captainName.isEmpty && flight.captainName != "Self" {
                        captainNames.insert(flight.captainName)
                    }
                    if !flight.foName.isEmpty && flight.foName != "Self" {
                        foNames.insert(flight.foName)
                    }
                    if let so1 = flight.so1Name, !so1.isEmpty {
                        so1Names.insert(so1)
                    }
                    if let so2 = flight.so2Name, !so2.isEmpty {
                        so2Names.insert(so2)
                    }

                case .failure(let error):
                    failureCount += 1
                    let reason = error.message
                    failureReasons[reason, default: 0] += 1

                    // Keep first 10 failures for detailed reporting
                    if sampleFailures.count < 10 {
                        sampleFailures.append((index + 1, reason))
                    }
                }
            }

            // Save collected crew names to UserDefaults
            DispatchQueue.main.sync {
                self.saveCrewNamesToUserDefaults(
                    captainNames: captainNames,
                    foNames: foNames,
                    so1Names: so1Names,
                    so2Names: so2Names
                )
            }

            // Use optimized batch save - dramatically faster than individual saves
            let flights = flightsToImport.map { $0.flight }
            var duplicateCount = 0
            var importSessionID: UUID? = nil
            var mergeProposals: [MergeProposal] = []

            DispatchQueue.main.sync {
                let result = databaseService.saveFlightsBatch(flights)
                successCount = result.successCount
                let dbFailures = result.failureCount
                duplicateCount = result.duplicateCount
                importSessionID = result.sessionID
                mergeProposals = result.mergeProposals

                // Track database failures (NOT duplicates) in the import result
                if dbFailures > 0 {
                    failureCount += dbFailures
                    failureReasons["Database save failed (invalid data)", default: 0] += dbFailures
                }
            }

            let result = ImportResult(
                successCount: successCount,
                failureCount: failureCount,
                duplicateCount: duplicateCount,
                failureReasons: failureReasons,
                sampleFailures: sampleFailures,
                sessionID: importSessionID,
                mergeProposals: mergeProposals
            )

            // Re-enable CloudKit sync if it was previously enabled
            if cloudKitWasEnabled {
                DispatchQueue.main.sync {
                    databaseService.enableCloudKitSync()
                }
                LogManager.shared.info("Import complete. CloudKit will now sync \(successCount) flights in the background.")
            }

            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
    }

    // MARK: - Save Crew Names to UserDefaults
    private func saveCrewNamesToUserDefaults(
        captainNames: Set<String>,
        foNames: Set<String>,
        so1Names: Set<String>,
        so2Names: Set<String>
    ) {
        let userDefaultsService = UserDefaultsService()

        LogManager.shared.debug("Saving crew names to UserDefaults")
//        LogManager.shared.debug("DEBUG: Captain names: \(captainNames.sorted())")
//        LogManager.shared.debug("DEBUG: F/O names: \(foNames.sorted())")
//        LogManager.shared.debug("DEBUG: SO1 names: \(so1Names.sorted())")
//        LogManager.shared.debug("DEBUG: SO2 names: \(so2Names.sorted())")

        // Add captain names
        for name in captainNames {
            _ = userDefaultsService.addCaptainName(name)
        }

        // Add F/O names
        for name in foNames {
            _ = userDefaultsService.addCoPilotName(name)
        }

        // Add SO names (both SO1 and SO2 go to the same shared list)
        for name in so1Names {
            _ = userDefaultsService.addSOName(name)
        }

        for name in so2Names {
            _ = userDefaultsService.addSOName(name)
        }

        // Verify what was saved
//        let savedSettings = userDefaultsService.loadSettings()
//        LogManager.shared.debug("DEBUG: After saving - Captain names in UserDefaults: \(savedSettings.savedCaptainNames)")
//        LogManager.shared.debug("DEBUG: After saving - F/O names in UserDefaults: \(savedSettings.savedCoPilotNames)")
//        LogManager.shared.debug("DEBUG: After saving - SO names in UserDefaults: \(savedSettings.savedSONames)")
    }

    // MARK: - Create Column Mapping
    private func createColumnMapping(
        headers: [String],
        fieldMappings: [FieldMapping]
    ) -> [String: FieldMappingInfo] {
        var mapping: [String: FieldMappingInfo] = [:]

        for fieldMapping in fieldMappings {
            if !fieldMapping.sourceColumns.isEmpty {
                let columnIndices = fieldMapping.sourceColumns.compactMap { column in
                    headers.firstIndex(of: column)
                }

                if !columnIndices.isEmpty {
                    var appendEntries: [(columnIndex: Int, label: String)] = []
                    if fieldMapping.logbookField == "Remarks" {
                        appendEntries = fieldMapping.remarksAppendEntries.compactMap { entry in
                            guard let idx = headers.firstIndex(of: entry.sourceColumn) else { return nil }
                            return (columnIndex: idx, label: entry.label)
                        }
                    }
                    mapping[fieldMapping.logbookField] = FieldMappingInfo(
                        columnIndices: columnIndices,
                        appendEntries: appendEntries
                    )
                }
            }
        }

        return mapping
    }

    // MARK: - Create Registration Type Map
    private func createRegistrationTypeMap(mappings: [RegistrationTypeMapping]) -> [String: String] {
        var map: [String: String] = [:]

        for mapping in mappings where !mapping.aircraftType.isEmpty {
            // Remove the * from pattern (e.g., "EB*" -> "EB")
            let pattern = mapping.pattern.replacingOccurrences(of: "*", with: "")
            map[pattern] = mapping.aircraftType
        }

        return map
    }

    // Helper struct for mapping info
    private struct FieldMappingInfo {
        let columnIndices: [Int]
        // Only populated for Remarks field
        let appendEntries: [(columnIndex: Int, label: String)]

        init(columnIndices: [Int], appendEntries: [(columnIndex: Int, label: String)] = []) {
            self.columnIndices = columnIndices
            self.appendEntries = appendEntries
        }
    }

    // MARK: - Create Flight from Row
    private func createFlightFromRow(
        _ row: [String],
        mapping: [String: FieldMappingInfo],
        registrationTypeMap: [String: String],
        rowIndex: Int
    ) -> Result<FlightSector, FlightCreationError> {
        // Helper to get value safely - now handles multiple columns with strategies
        func getValue(_ field: String) -> String {
            guard let mappingInfo = mapping[field] else { return "" }

            // Get all values from mapped columns
            let values = mappingInfo.columnIndices.compactMap { index -> String? in
                guard index < row.count else { return nil }
                return row[index]
            }

            // If no values found, return empty
            guard !values.isEmpty else { return "" }

            // If only one value, return it directly
            if values.count == 1 {
                return values[0]
            }

            // For multiple values, sum them together.
            // Use sumWebCISTimes so that h:mm strings (e.g. "1:46") are handled correctly
            // alongside decimal values — Double("1:46") returns nil, so the old
            // Double() path silently dropped all but the first column for h:mm data.
            let hasColonFormat = values.contains { $0.contains(":") }
            if hasColonFormat {
                return sumWebCISTimes(values)
            }

            // All decimal values — sum directly
            let doubleValues = values.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if doubleValues.count == values.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }).count {
                let sum = doubleValues.reduce(0, +)
                return String(format: "%.2f", sum)
            }

            // For non-numeric values, just use first non-empty
            return values.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? values[0]
        }

        // Get all fields
        let rawDate = getValue("Date")
        let date = parseDate(rawDate)
        let flightNumber = getValue("Flight Number")
        let aircraftReg = getValue("Aircraft Reg")
        let fromAirport = getValue("From Airport")
        let toAirport = getValue("To Airport")
        let captainName = parseCrewName(getValue("Captain Name"))
        let foName = parseCrewName(getValue("F/O Name"))
        let scheduledDeparture = parseTime(getValue("STD"))
        let scheduledArrival = parseTime(getValue("STA"))
        let outTime = parseTime(getValue("OUT Time"))
        let inTime = parseTime(getValue("IN Time"))

        // Always use imported block time for consistency in duplicate detection
        // Do NOT recalculate from OUT/IN as this can cause the same flight to get different UUIDs
        let blockTime = parseDurationTime(getValue("Block Time"))

        let importedNightTime = parseDurationTime(getValue("Night Time"))
        let simTime = parseDurationTime(getValue("SIM Time"))
        let spInsTime = parseDurationTime(getValue("Sp/Ins Time"))

        let p1Time = parseDurationTime(getValue("P1 Time"))
        let p1usTime = parseDurationTime(getValue("P1US Time"))
        let p2Time = parseDurationTime(getValue("P2 Time"))
        let instrumentTime = parseDurationTime(getValue("Instrument Time"))

        // Minimal validation - only require date
        if date.isEmpty {
            return .failure(FlightCreationError(message: "Missing required field: Date"))
        }

        // Validate that date looks like a date (not remarks or other text)
        if date.count > 15 {
            return .failure(FlightCreationError(message: "Invalid date (text too long): '\(date.prefix(50))...'"))
        }

        // Validate numeric fields if they're not empty
        // Be resilient: if a field contains boolean-like text (e.g., "sim", "true"), treat it as 0
        func validateNumericField(_ value: String, fieldName: String) -> Result<Void, FlightCreationError> {
            guard !value.isEmpty else { return .success(()) }

            // Try to parse as number
            if Double(value) != nil {
                return .success(())
            }

            // If not numeric, check if it's a boolean-like value (likely data mapping error)
            let normalized = value.lowercased().trimmingCharacters(in: .whitespaces)
            let booleanLikeValues = ["true", "false", "yes", "no", "sim", "y", "n", "1", "0"]
            if booleanLikeValues.contains(normalized) {
                // Log warning but allow import - we'll treat it as 0
                LogManager.shared.warning("Import: Found boolean-like value '\(value)' in numeric field \(fieldName), treating as 0")
                return .success(())
            }

            // Not a valid number or boolean - fail
            return .failure(FlightCreationError(message: "Invalid \(fieldName) value: '\(value)'"))
        }

        if case .failure(let error) = validateNumericField(blockTime, fieldName: "Block Time") {
            return .failure(error)
        }
        if case .failure(let error) = validateNumericField(simTime, fieldName: "SIM Time") {
            return .failure(error)
        }

        // Parse boolean fields
        var isPilotFlying = parseBool(getValue("Pilot Flying"))
        let isAIII = parseBool(getValue("AIII"))
        let isRNP = parseBool(getValue("RNP"))
        let isILS = parseBool(getValue("ILS"))
        let isGLS = parseBool(getValue("GLS"))
        let isNPA = parseBool(getValue("NPA"))
        let isPositioning = parseBool(getValue("PAX"))
        let customCountRaw = getValue("Custom Count")
        let customCount = Int(customCountRaw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        // If Pilot Flying is not set or false, check if we should infer it from Instrument Time
        if !isPilotFlying {
            // If there's instrument time recorded (and it's > 0), assume pilot flying
            if !instrumentTime.isEmpty, let instTime = Double(instrumentTime), instTime > 0 {
                isPilotFlying = true
            }
        }

        // Parse integer fields for takeoffs/landings
        func getIntValue(_ field: String) -> Int {
            let value = getValue(field)
            return Int(value) ?? 0
        }

        // Calculate takeoffs/landings if not provided or if we should override
        let importedDayTakeoffs = getIntValue("Day Takeoffs")
        let importedDayLandings = getIntValue("Day Landings")
        let importedNightTakeoffs = getIntValue("Night Takeoffs")
        let importedNightLandings = getIntValue("Night Landings")

        // Skip expensive calculation if we have imported data OR if we're missing required times
        let hasImportedData = importedDayTakeoffs > 0 || importedDayLandings > 0 ||
                             importedNightTakeoffs > 0 || importedNightLandings > 0

        let (dayTakeoffs, dayLandings, nightTakeoffs, nightLandings): (Int, Int, Int, Int)

        if hasImportedData {
            // Use imported values directly
            (dayTakeoffs, dayLandings, nightTakeoffs, nightLandings) =
                (importedDayTakeoffs, importedDayLandings, importedNightTakeoffs, importedNightLandings)
        } else if outTime.isEmpty || blockTime.isEmpty {
            // Skip calculation if missing required times (major performance boost)
            (dayTakeoffs, dayLandings, nightTakeoffs, nightLandings) = (0, 0, 0, 0)
        } else {
            // Calculate from times and airports
            (dayTakeoffs, dayLandings, nightTakeoffs, nightLandings) = calculateTakeoffsLandings(
                fromAirport: fromAirport,
                toAirport: toAirport,
                outTime: outTime,
                blockTime: blockTime,
                isPilotFlying: isPilotFlying,
                importedDayTakeoffs: importedDayTakeoffs,
                importedDayLandings: importedDayLandings,
                importedNightTakeoffs: importedNightTakeoffs,
                importedNightLandings: importedNightLandings
            )
        }

        // Determine aircraft type
        var aircraftType = ""
        let rawAircraftType = getValue("Aircraft Type")

        // First, try to use the type from the CSV if valid
        if rawAircraftType.count == 4 || rawAircraftType.count == 5 {
            aircraftType = rawAircraftType
        }

        // If no type in CSV, try to infer from registration mapping
        if aircraftType.isEmpty && !registrationTypeMap.isEmpty {
            let registration = aircraftReg
            // Try to match registration pattern (first 2 chars)
            if registration.count >= 2 {
                let pattern = String(registration.prefix(2))
                if let mappedType = registrationTypeMap[pattern] {
                    aircraftType = mappedType
                }
            }
        }

        // Create deterministic ID based on flight data to prevent duplicates
        // Use date + flight number + aircraft type + aircraft reg + from + to + block time as unique identifier
        // For flights without flight numbers, use OUT/IN times for additional uniqueness
        // simTime is appended for sim-only rows (no route, no block time) so two sim sessions
        // on the same date produce distinct UUIDs and re-imports don't create duplicates.
        let uniqueString: String
        if flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // No flight number - use OUT/IN times and sim time for additional uniqueness
            uniqueString = "\(date)-\(aircraftType)-\(aircraftReg)-\(fromAirport)-\(toAirport)-\(outTime)-\(inTime)-\(blockTime)-\(simTime)"
        } else {
            // Normal flight with flight number
            uniqueString = "\(date)-\(flightNumber)-\(aircraftType)-\(aircraftReg)-\(fromAirport)-\(toAirport)-\(blockTime)"
        }
        let deterministicID = UUID(uuidString: uniqueString.md5UUID()) ?? UUID()

        // For simulator flights (simTime > 0), blockTime should be 0
        // This ensures simulator time is only counted in simTime, not blockTime
        let finalBlockTime: String
        let nightTime: String

        if !simTime.isEmpty, let simValue = Double(simTime), simValue > 0 {
            // This is a simulator flight
            finalBlockTime = "0.0"
            nightTime = importedNightTime  // Keep night time as-is for simulator flights
        } else {
            // Regular flight - validate night time doesn't exceed block time
            finalBlockTime = blockTime

            if !importedNightTime.isEmpty, !blockTime.isEmpty,
               let nightValue = Double(importedNightTime),
               let blockValue = Double(blockTime), blockValue > 0 {
                // Cap night time at block time
                let cappedNight = min(nightValue, blockValue)
                nightTime = String(format: "%.2f", cappedNight)
            } else {
                nightTime = importedNightTime
            }
        }

        let flight = FlightSector(
            id: deterministicID,
            date: date,
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: fromAirport,
            toAirport: toAirport,
            captainName: captainName,
            foName: foName,
            so1Name: getValue("S/O1 Name").isEmpty ? nil : parseCrewName(getValue("S/O1 Name")),
            so2Name: getValue("S/O2 Name").isEmpty ? nil : parseCrewName(getValue("S/O2 Name")),
            blockTime: finalBlockTime,
            nightTime: nightTime,
            p1Time: p1Time,
            p1usTime: p1usTime,
            p2Time: p2Time,
            instrumentTime: instrumentTime,
            simTime: simTime,
            spInsTime: spInsTime,
            isPilotFlying: isPilotFlying,
            isPositioning: isPositioning,
            isAIII: isAIII,
            isRNP: isRNP,
            isILS: isILS,
            isGLS: isGLS,
            isNPA: isNPA,
            remarks: buildRemarks(baseRemarks: getValue("Remarks"), row: row, mappingInfo: mapping["Remarks"]),
            dayTakeoffs: dayTakeoffs,
            dayLandings: dayLandings,
            nightTakeoffs: nightTakeoffs,
            nightLandings: nightLandings,
            outTime: outTime,
            inTime: inTime,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival,
            customCount: isPositioning ? 0 : max(0, customCount)
        )

        return .success(flight)
    }

    // MARK: - Parse Boolean
    /// Parse boolean values with resilient handling
    /// - Any non-empty text (except explicit "false", "no", "0") is treated as true
    /// - Empty/blank values are treated as false
    /// This handles variations like "sim", "True", "YES", "1", etc.
    private func buildRemarks(baseRemarks: String, row: [String], mappingInfo: FieldMappingInfo?) -> String {
        var result = baseRemarks.trimmingCharacters(in: .whitespaces)
        guard let appendEntries = mappingInfo?.appendEntries, !appendEntries.isEmpty else { return result }

        for entry in appendEntries {
            guard entry.columnIndex < row.count else { continue }
            let value = row[entry.columnIndex].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }

            let label = entry.label.trimmingCharacters(in: .whitespaces)
            let fragment = label.isEmpty ? value : "\(label): \(value)"

            if result.isEmpty {
                result = fragment
            } else {
                // Append with "." separator if needed
                if result.hasSuffix(".") {
                    result += " \(fragment)"
                } else {
                    result += ". \(fragment)"
                }
            }
        }

        return result
    }

    private func parseCrewName(_ value: String) -> String {
        let t = value.trimmingCharacters(in: .whitespaces)
        guard t.contains(",") else { return t }
        let parts = t.components(separatedBy: ",")
        guard parts.count == 2 else { return t }
        let last = parts[0].trimmingCharacters(in: .whitespaces)
        let first = parts[1].trimmingCharacters(in: .whitespaces)
        guard !first.isEmpty, !last.isEmpty else { return t }
        return "\(first) \(last)"
    }

    private func parseBool(_ value: String) -> Bool {
        let normalized = value.lowercased().trimmingCharacters(in: .whitespaces)

        // Empty or whitespace-only = false
        if normalized.isEmpty {
            return false
        }

        // Explicit false values
        if normalized == "false" || normalized == "no" || normalized == "0" || normalized == "n" {
            return false
        }

        // Any other non-empty text = true
        // This handles: "true", "yes", "1", "sim", "y", "x", etc.
        return true
    }

    // MARK: - Quick Restore from BlockTime Backup
    /// Detects if a CSV file is from Logger's own export format and imports it automatically
    func quickRestoreFromBackup(
        url: URL,
        mode: ImportMode = .merge,
        skipSecurityScoping: Bool = false,
        completion: @escaping (Result<ImportResult, Error>) -> Void
    ) {
        LogManager.shared.info("quickRestoreFromBackup called with mode: \(mode)")
        LogManager.shared.info("File: \(url.lastPathComponent)")
        LogManager.shared.info("skipSecurityScoping: \(skipSecurityScoping)")

        do {
            // Parse the file
            // skipSecurityScoping=true means the file is in our app container and doesn't need security-scoped access
            let importData = try parseFile(url: url, forceSecurityScoping: !skipSecurityScoping)
            LogManager.shared.info("Successfully parsed file: \(importData.rows.count) rows")
            LogManager.shared.info("   Headers: \(importData.headers.prefix(6).joined(separator: ", "))")

            // Detect if this is Block-Time's export format
            guard isLoggerExportFormat(headers: importData.headers) else {
                // Not Block-Time format - use regular import with mapping
                LogManager.shared.info("File is not in Block-Time export format")
                throw ImportError.notLoggerFormat
            }

            LogManager.shared.info("Detected Block-Time export format")

            // Create automatic field mapping based on Logger's export header
            let mappings = createLoggerFieldMapping(headers: importData.headers)
            LogManager.shared.info("Created \(mappings.count) field mappings")

            // Perform import with automatic mapping
            LogManager.shared.info("Starting import with mode: \(mode)")
            importFlights(from: importData, mapping: mappings, mode: mode, completion: completion)

        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Import webCIS Data
    /// Imports webcis fixed-width format data directly
    func importWebCISData(
        importData: ImportData,
        mode: ImportMode = .merge,
        registrationMappings: [RegistrationTypeMapping] = [],
        completion: @escaping (Result<ImportResult, Error>) -> Void
    ) {
        // Create automatic field mapping for webCIS format
        let mappings = createWebCISFieldMapping(headers: importData.headers)

        // Perform import with automatic mapping and registration mappings
        importFlights(from: importData, mapping: mappings, mode: mode, registrationMappings: registrationMappings, completion: completion)
    }

    /// Public method to parse webCIS file (needed for UI)
    func parseWebCISFile(url: URL) throws -> ImportData {
        return try parseWebCISFileInternal(url: url)
    }

    /// Returns true if the file content looks like a webCIS export (tab-separated live extract
    /// or fixed-width report where data lines start with a date digit).
    func looksLikeWebCISFile(url: URL) -> Bool {
        let needsSecurityScopedAccess = !isInAppContainer(url)
        if needsSecurityScopedAccess {
            guard url.startAccessingSecurityScopedResource() else { return false }
        }
        defer { if needsSecurityScopedAccess { url.stopAccessingSecurityScopedResource() } }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }

        let nonEmptyLines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstLine = nonEmptyLines.first else { return false }

        // Saved webCIS files always have "webcis_web_download" in their filename.
        // Only auto-redirect files with that name signature.
        let filename = url.lastPathComponent.lowercased()
        guard filename.contains("webcis_web_download") else { return false }

        // Tab-separated = saved output from the live WebCIS JS extractor or file download.
        if firstLine.contains("\t") {
            let cells = firstLine.components(separatedBy: "\t")
            return cells.count >= 3 && cells[0].first?.isNumber == true
        }

        return false
    }

    /// Public method to create webCIS field mapping (needed for UI)
    func createWebCISFieldMappingPublic(headers: [String]) -> [FieldMapping] {
        return createWebCISFieldMapping(headers: headers)
    }

    /// Parse webCIS text extracted from the DOM (live import via WKWebView) or re-imported
    /// from a Block-Time saved download file. Both use the same 19-column tab-separated format.
    /// Column order (0-based):
    ///   0:Date  1:Reg  2:Sector(DEP-ARR)  3:Inst
    ///   4:SE Dual D  5:SE Dual N  6:SE Cmd D  7:SE Cmd N
    ///   8:ME ICUS D  9:ME ICUS N  10:ME Dual D  11:ME Dual N
    ///   12:ME Co-Pilot D  13:ME Co-Pilot N  14:ME Cmd D  15:ME Cmd N
    ///   16:Flight Engr (ignored)  17:Sim  18:Sp/Ins (parsed, not totalled)
    func parseWebCISText(_ content: String) throws -> ImportData {
        let lines = content.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { throw ImportError.invalidFormat }

        let headers = ["DATE", "REG", "DEP", "DES", "INST", "P2D", "P2N", "P1D", "P1N",
                       "P1USD", "P1USN", "MEDD", "MEDN", "MEFD", "MEFN", "MECD", "MECN", "SIMU", "FLEN", "TOTAL", "SPINS"]

        // Regex to detect a bare time value like "2:30" or "12:05" (not a route like "SYD-MEL")
        let timeOnlyPattern = try? NSRegularExpression(pattern: #"^\d{1,3}:\d{2}$"#)
        func looksLikeTime(_ s: String) -> Bool {
            guard !s.isEmpty else { return false }
            let range = NSRange(s.startIndex..., in: s)
            return timeOnlyPattern?.firstMatch(in: s, range: range) != nil
        }

        var dataRows: [[String]] = []
        for line in lines {
            let cells = line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cells.count >= 3, cells[0].first?.isNumber == true else { continue }

            func c(_ i: Int) -> String { i < cells.count ? cells[i] : "" }

            // Sim row: reg cell contains "SIM", time is in col17, SpIns in col18
            if c(1).uppercased() == "SIM" {
                let simTime = c(17).isEmpty ? c(cells.count - 1) : c(17)  // fallback for malformed rows
                let spins = c(18)
                // If SpIns matches SimTime, exclude sim from total (instructor session)
                let simuForTotal = (!spins.isEmpty && spins.contains(":") && spins == simTime) ? "" : simTime
                let total = sumWebCISTimes([simuForTotal])
                let row: [String] = [
                    c(0),  // DATE
                    "",    // REG — "SIM" is not a rego
                    "",    // DEP
                    "",    // DES
                    "",    // INST
                    "", "", "", "", "", "", "", "", "", "", "", "",  // all flight-time cols empty
                    simTime, // SIMU
                    "",    // FLEN
                    total, // TOTAL
                    spins  // SPINS
                ]
                dataRows.append(row)
                continue
            }

            // Sparse sim row fallback: few cells where cell[2] is a bare time, no route
            if cells.count < 5 && looksLikeTime(c(2)) {
                let total = sumWebCISTimes([c(2)])
                let row: [String] = [
                    c(0),  // DATE
                    c(1),  // REG
                    "",    // DEP
                    "",    // DES
                    "",    // INST
                    "", "", "", "", "", "", "", "", "", "", "", "",  // all flight-time cols empty
                    c(2),  // SIMU — the time value from cell[2]
                    "",    // FLEN
                    total, // TOTAL
                    ""     // SPINS
                ]
                dataRows.append(row)
                continue
            }

            // Split sector "SYD-MEL" into dep/dest
            let sector = c(2)
            let dashIdx = sector.firstIndex(of: "-")
            let dep  = dashIdx.map { String(sector[sector.startIndex..<$0]) } ?? sector
            let dest = dashIdx.map { String(sector[sector.index(after: $0)...]) } ?? ""

            var mefd = c(12)  // ME CoPilot D
            var mefn = c(13)  // ME CoPilot N
            let meid = c(8)   // ME ICUS D
            let mein = c(9)   // ME ICUS N

            // Deduplication: if ICUS time exists, blank CoPilot to avoid double-counting
            if !meid.isEmpty && meid.contains(":") && !mefd.isEmpty && mefd.contains(":") { mefd = "" }
            if !mein.isEmpty && mein.contains(":") && !mefn.isEmpty && mefn.contains(":") { mefn = "" }

            // col16 = Flight Engr (ignored), col17 = Sim, col18 = Sp/Ins (parsed, not totalled)
            let simu = c(17)
            let spins = c(18)

            // If SpIns matches SimTime, pilot was instructing — exclude sim from totals
            let simuForTotal = (!spins.isEmpty && spins.contains(":") && spins == simu) ? "" : simu
            let timeFields = [c(4), c(5), c(6), c(7), meid, mein, c(10), c(11), mefd, mefn, c(14), c(15), simuForTotal]
            let total = sumWebCISTimes(timeFields)

            let row: [String] = [
                c(0),   // DATE
                c(1),   // REG
                dep,    // DEP
                dest,   // DES
                c(3),   // INST
                c(4),   // P2D  (SE Dual D)
                c(5),   // P2N  (SE Dual N)
                c(6),   // P1D  (SE Cmd D)
                c(7),   // P1N  (SE Cmd N)
                meid,   // P1USD (ME ICUS D)
                mein,   // P1USN (ME ICUS N)
                c(10),  // MEDD (ME Dual D)
                c(11),  // MEDN (ME Dual N)
                mefd,   // MEFD (ME CoPilot D)
                mefn,   // MEFN (ME CoPilot N)
                c(14),  // MECD (ME Cmd D)
                c(15),  // MECN (ME Cmd N)
                simu,   // SIMU (stored as-is; isSpInsOnly logic handles display/totals)
                "",     // FLEN (ignored)
                total,  // TOTAL
                spins   // SPINS
            ]
            dataRows.append(row)
        }

        return ImportData(headers: headers, rows: dataRows, fileURL: URL(string: "webcis://live")!, delimiter: ",")
    }

    /// Check if CSV headers match Logger's export format
    private func isLoggerExportFormat(headers: [String]) -> Bool {
        // Logger's export has these key headers in this order
        let requiredHeaders = ["Date", "Flight Number", "Aircraft Reg", "Aircraft Type", "From Airport", "To Airport"]

        // Check if first 6 headers match (case-insensitive)
        guard headers.count >= requiredHeaders.count else { return false }

        for (index, required) in requiredHeaders.enumerated() {
            if headers[index].lowercased() != required.lowercased() {
                return false
            }
        }

        return true
    }

    /// Create automatic field mapping for Logger's export format
    private func createLoggerFieldMapping(headers: [String]) -> [FieldMapping] {
        var mappings: [FieldMapping] = []

        LogManager.shared.info("🗺️ Creating Block-Time field mapping from headers:")
        LogManager.shared.info("   Headers: \(headers)")

        for header in headers {
            let headerLower = header.lowercased()

            if headerLower == "date" {
                LogManager.shared.info("   ✓ Mapping 'Date' from column '\(header)'")
                mappings.append(FieldMapping(logbookField: "Date", logbookFieldDescription: "Date", sourceColumn: header, isRequired: true))
            } else if headerLower == "flight number" {
                mappings.append(FieldMapping(logbookField: "Flight Number", logbookFieldDescription: "Flight Number", sourceColumn: header, isRequired: true))
            } else if headerLower == "aircraft reg" {
                mappings.append(FieldMapping(logbookField: "Aircraft Reg", logbookFieldDescription: "Aircraft Reg", sourceColumn: header, isRequired: true))
            } else if headerLower == "aircraft type" {
                mappings.append(FieldMapping(logbookField: "Aircraft Type", logbookFieldDescription: "Aircraft Type", sourceColumn: header, isRequired: true))
            } else if headerLower == "from airport" {
                mappings.append(FieldMapping(logbookField: "From Airport", logbookFieldDescription: "From Airport", sourceColumn: header, isRequired: true))
            } else if headerLower == "to airport" {
                mappings.append(FieldMapping(logbookField: "To Airport", logbookFieldDescription: "To Airport", sourceColumn: header, isRequired: true))
            } else if headerLower == "captain name" {
                mappings.append(FieldMapping(logbookField: "Captain Name", logbookFieldDescription: "Captain Name", sourceColumn: header, isRequired: true))
            } else if headerLower == "f/o name" {
                mappings.append(FieldMapping(logbookField: "F/O Name", logbookFieldDescription: "F/O Name", sourceColumn: header, isRequired: true))
            } else if headerLower == "s/o1 name" {
                mappings.append(FieldMapping(logbookField: "S/O1 Name", logbookFieldDescription: "S/O1 Name", sourceColumn: header, isRequired: false))
            } else if headerLower == "s/o2 name" {
                mappings.append(FieldMapping(logbookField: "S/O2 Name", logbookFieldDescription: "S/O2 Name", sourceColumn: header, isRequired: false))
            } else if headerLower == "std" {
                mappings.append(FieldMapping(logbookField: "STD", logbookFieldDescription: "Scheduled Departure", sourceColumn: header, isRequired: false))
            } else if headerLower == "sta" {
                mappings.append(FieldMapping(logbookField: "STA", logbookFieldDescription: "Scheduled Arrival", sourceColumn: header, isRequired: false))
            } else if headerLower == "out time" {
                mappings.append(FieldMapping(logbookField: "OUT Time", logbookFieldDescription: "OUT Time", sourceColumn: header, isRequired: false))
            } else if headerLower == "in time" {
                mappings.append(FieldMapping(logbookField: "IN Time", logbookFieldDescription: "IN Time", sourceColumn: header, isRequired: false))
            } else if headerLower == "block time" {
                mappings.append(FieldMapping(logbookField: "Block Time", logbookFieldDescription: "Block Time", sourceColumn: header, isRequired: true))
            } else if headerLower == "night time" {
                mappings.append(FieldMapping(logbookField: "Night Time", logbookFieldDescription: "Night Time", sourceColumn: header, isRequired: true))
            } else if headerLower == "p1 time" {
                mappings.append(FieldMapping(logbookField: "P1 Time", logbookFieldDescription: "P1 Time", sourceColumn: header, isRequired: true))
            } else if headerLower == "p1us time" {
                mappings.append(FieldMapping(logbookField: "P1US Time", logbookFieldDescription: "P1US Time", sourceColumn: header, isRequired: true))
            } else if headerLower == "p2 time" {
                mappings.append(FieldMapping(logbookField: "P2 Time", logbookFieldDescription: "P2 Time", sourceColumn: header, isRequired: false))
            } else if headerLower == "instrument time" {
                mappings.append(FieldMapping(logbookField: "Instrument Time", logbookFieldDescription: "Instrument Time", sourceColumn: header, isRequired: true))
            } else if headerLower == "sim time" {
                mappings.append(FieldMapping(logbookField: "SIM Time", logbookFieldDescription: "SIM Time", sourceColumn: header, isRequired: true))
            } else if headerLower == "sp/ins time" {
                mappings.append(FieldMapping(logbookField: "Sp/Ins Time", logbookFieldDescription: "Sp/Ins Time", sourceColumn: header, isRequired: false))
            } else if headerLower == "pilot flying" {
                mappings.append(FieldMapping(logbookField: "Pilot Flying", logbookFieldDescription: "Pilot Flying", sourceColumn: header, isRequired: false))
            } else if headerLower == "aiii" {
                mappings.append(FieldMapping(logbookField: "AIII", logbookFieldDescription: "AIII", sourceColumn: header, isRequired: false))
            } else if headerLower == "rnp" {
                mappings.append(FieldMapping(logbookField: "RNP", logbookFieldDescription: "RNP", sourceColumn: header, isRequired: false))
            } else if headerLower == "ils" {
                mappings.append(FieldMapping(logbookField: "ILS", logbookFieldDescription: "ILS", sourceColumn: header, isRequired: false))
            } else if headerLower == "gls" {
                mappings.append(FieldMapping(logbookField: "GLS", logbookFieldDescription: "GLS", sourceColumn: header, isRequired: false))
            } else if headerLower == "npa" {
                mappings.append(FieldMapping(logbookField: "NPA", logbookFieldDescription: "NPA", sourceColumn: header, isRequired: false))
            } else if headerLower == "day takeoffs" {
                mappings.append(FieldMapping(logbookField: "Day Takeoffs", logbookFieldDescription: "Day Takeoffs", sourceColumn: header, isRequired: false))
            } else if headerLower == "day landings" {
                mappings.append(FieldMapping(logbookField: "Day Landings", logbookFieldDescription: "Day Landings", sourceColumn: header, isRequired: false))
            } else if headerLower == "night takeoffs" {
                mappings.append(FieldMapping(logbookField: "Night Takeoffs", logbookFieldDescription: "Night Takeoffs", sourceColumn: header, isRequired: false))
            } else if headerLower == "night landings" {
                mappings.append(FieldMapping(logbookField: "Night Landings", logbookFieldDescription: "Night Landings", sourceColumn: header, isRequired: false))
            } else if headerLower == "pax" {
                mappings.append(FieldMapping(logbookField: "PAX", logbookFieldDescription: "PAX", sourceColumn: header, isRequired: false))
            } else if headerLower == "custom count" {
                mappings.append(FieldMapping(logbookField: "Custom Count", logbookFieldDescription: "Custom Count", sourceColumn: header, isRequired: false))
            } else if headerLower == "remarks" {
                mappings.append(FieldMapping(logbookField: "Remarks", logbookFieldDescription: "Remarks", sourceColumn: header, isRequired: false))
            }
        }

        return mappings
    }

    // MARK: - Export to CSV
    func exportToCSV(flights: [FlightSector]) -> String {
        // CSV Header
        var csv = "Date,Flight Number,Aircraft Reg,Aircraft Type,From Airport,To Airport,Captain Name,F/O Name,S/O1 Name,S/O2 Name,STD,STA,OUT Time,IN Time,Block Time,Night Time,P1 Time,P1US Time,P2 Time,Instrument Time,SIM Time,Sp/Ins Time,PAX,Pilot Flying,AIII,RNP,ILS,GLS,NPA,Day Takeoffs,Day Landings,Night Takeoffs,Night Landings,Remarks,Custom Count\n"

        // Add each flight as a row
        for flight in flights {
            let row = [
                flight.date,
                flight.flightNumber,
                flight.aircraftReg,
                flight.aircraftType,
                flight.fromAirport,
                flight.toAirport,
                flight.captainName,
                flight.foName,
                flight.so1Name ?? "",
                flight.so2Name ?? "",
                flight.scheduledDeparture,
                flight.scheduledArrival,
                flight.outTime,
                flight.inTime,
                flight.blockTime,
                flight.nightTime,
                flight.p1Time,
                flight.p1usTime,
                flight.p2Time,
                flight.instrumentTime,
                flight.simTime,
                flight.spInsTime,
                flight.isPositioning ? "1" : "",
                flight.isPilotFlying ? "1" : "",
                flight.isAIII ? "1" : "",
                flight.isRNP ? "1" : "",
                flight.isILS ? "1" : "",
                flight.isGLS ? "1" : "",
                flight.isNPA ? "1" : "",
                String(flight.dayTakeoffs),
                String(flight.dayLandings),
                String(flight.nightTakeoffs),
                String(flight.nightLandings),
                escapeCSVField(flight.remarks),
                flight.customCount > 0 ? String(flight.customCount) : ""
            ]

            csv += row.joined(separator: ",") + "\n"
        }

        return csv
    }

    // Helper to escape CSV fields that contain commas or quotes
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    // MARK: - Calculate Takeoffs and Landings
    private func calculateTakeoffsLandings(
        fromAirport: String,
        toAirport: String,
        outTime: String,
        blockTime: String,
        isPilotFlying: Bool,
        importedDayTakeoffs: Int,
        importedDayLandings: Int,
        importedNightTakeoffs: Int,
        importedNightLandings: Int
    ) -> (dayTakeoffs: Int, dayLandings: Int, nightTakeoffs: Int, nightLandings: Int) {

        // If imported values are provided (non-zero), use them
        let hasImportedData = importedDayTakeoffs > 0 || importedDayLandings > 0 ||
                             importedNightTakeoffs > 0 || importedNightLandings > 0

        if hasImportedData {
            return (importedDayTakeoffs, importedDayLandings, importedNightTakeoffs, importedNightLandings)
        }

        // Otherwise calculate based on night time (same logic as manual entry)

        // If not pilot flying, no takeoffs/landings logged
        guard isPilotFlying else {
            return (0, 0, 0, 0)
        }

        // Need valid data to calculate day/night; fall back to 1 day T/O + 1 day landing if unavailable
        let dayFallback = (dayTakeoffs: 1, dayLandings: 1, nightTakeoffs: 0, nightLandings: 0)

        guard !fromAirport.isEmpty, !toAirport.isEmpty,
              !outTime.isEmpty, !blockTime.isEmpty else {
            return dayFallback
        }

        // Get airport coordinates
        let nightCalcService = NightCalcService()
        guard let fromCoords = nightCalcService.getAirportCoordinates(for: fromAirport),
              let toCoords = nightCalcService.getAirportCoordinates(for: toAirport) else {
            return dayFallback
        }

        // Parse departure time
        guard let departureTime = nightCalcService.parseUTCTime(outTime) else {
            return dayFallback
        }

        // Parse block time to calculate arrival time
        guard let blockTimeValue = Double(blockTime), blockTimeValue > 0 else {
            return dayFallback
        }

        let arrivalTime = departureTime.addingTimeInterval(blockTimeValue * 3600)

        // Check if departure is at night
        let isDepartureNight = nightCalcService.isNight(
            at: fromCoords.latitude,
            lon: fromCoords.longitude,
            time: departureTime
        )

        // Check if arrival is at night
        let isArrivalNight = nightCalcService.isNight(
            at: toCoords.latitude,
            lon: toCoords.longitude,
            time: arrivalTime
        )

        // Calculate takeoffs/landings
        let dayTakeoffs = isDepartureNight ? 0 : 1
        let nightTakeoffs = isDepartureNight ? 1 : 0
        let dayLandings = isArrivalNight ? 0 : 1
        let nightLandings = isArrivalNight ? 1 : 0

        return (dayTakeoffs, dayLandings, nightTakeoffs, nightLandings)
    }

    // MARK: - Calculate Block Time from OUT/IN times
    private func calculateBlockTimeFromOutIn(outTime: String, inTime: String, fallback: String) -> String {
        // If either OUT or IN is missing, use the fallback (imported) block time
        guard !outTime.isEmpty, !inTime.isEmpty else {
            return fallback
        }

        // Parse times using DateFormatter
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let outTimeDate = formatter.date(from: outTime),
              let inTimeDate = formatter.date(from: inTime) else {
            // If parsing fails, use fallback
            return fallback
        }

        // Calculate duration
        var flightDuration = inTimeDate.timeIntervalSince(outTimeDate)

        // Handle overnight flights (IN time is next day)
        if flightDuration < 0 {
            flightDuration += 24 * 60 * 60
        }

        // Convert to hours with 2 decimal precision
        let totalSeconds = Int(flightDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds - (hours * 3600)) / 60
        let decimalHours = Double(hours) + (Double(minutes) / 60.0)

        return String(format: "%.2f", decimalHours)
    }

    // MARK: - Parse Duration Time (handles decimal or HH:MM formats)
    private func parseDurationTime(_ timeString: String) -> String {
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines)

        // If empty, return as-is
        if trimmed.isEmpty {
            return ""
        }

        // Handle boolean-like values (data mapping errors) - treat as 0
        let normalized = trimmed.lowercased()
        let booleanLikeValues = ["true", "false", "yes", "no", "sim", "y", "n"]
        if booleanLikeValues.contains(normalized) {
            return "0.0"
        }

        // If it contains a colon, assume it's HH:MM, H:MM, or :MM format
        if trimmed.contains(":") {
            let components = trimmed.split(separator: ":")

            // Handle :MM format (just minutes, e.g., ":01")
            if components.count == 1, let minutes = Double(components[0]) {
                let decimal = minutes / 60.0
                return String(format: "%.2f", decimal)
            }

            // Handle HH:MM or H:MM format
            if components.count == 2 {
                let hoursStr = components[0].trimmingCharacters(in: .whitespaces)
                let minutesStr = components[1].trimmingCharacters(in: .whitespaces)

                // If hours part is empty, it's :MM format
                if hoursStr.isEmpty, let minutes = Double(minutesStr) {
                    let decimal = minutes / 60.0
                    return String(format: "%.2f", decimal)
                }

                // Normal HH:MM format
                if let hours = Double(hoursStr), let minutes = Double(minutesStr) {
                    // Convert to decimal: hours + (minutes / 60)
                    let decimal = hours + (minutes / 60.0)
                    return String(format: "%.2f", decimal)
                }
            }
        }

        // If it's already a valid decimal, format with proper precision
        if let decimalValue = Double(trimmed) {
            return String(format: "%.2f", decimalValue)
        }

        // If we can't parse it, return the original string
        return trimmed
    }

    // MARK: - Parse Time (handles 1130 or 11:30 formats, ensures HH:MM format with leading zeros)
    private func parseTime(_ timeString: String) -> String {
        let trimmed = timeString.trimmingCharacters(in: .whitespaces)

        // If empty, return as-is
        if trimmed.isEmpty {
            return ""
        }

        // If already in colon format (e.g., "7:10" or "11:30"), parse and reformat with leading zeros
        if trimmed.contains(":") {
            let components = trimmed.split(separator: ":")
            if components.count == 2,
               let hours = Int(components[0]),
               let minutes = Int(components[1]),
               hours < 24, minutes < 60 {
                return String(format: "%02d:%02d", hours, minutes)
            }
            // If parsing fails, return as-is
            return trimmed
        }

        // Handle 4-digit format (e.g., "1130" -> "11:30")
        if trimmed.count == 4, let _ = Int(trimmed) {
            let hours = String(trimmed.prefix(2))
            let minutes = String(trimmed.suffix(2))
            return "\(hours):\(minutes)"
        }

        // Handle 3-digit format (e.g., "930" -> "09:30")
        if trimmed.count == 3, let _ = Int(trimmed) {
            let hours = String(format: "%02d", Int(String(trimmed.prefix(1))) ?? 0)
            let minutes = String(trimmed.suffix(2))
            return "\(hours):\(minutes)"
        }

        // If we can't parse it, return the original string
        return trimmed
    }

    // MARK: - Parse webCIS File
    private func parseWebCISFileInternal(url: URL) throws -> ImportData {
        // Check if this file needs security-scoped access
        let needsSecurityScopedAccess = !isInAppContainer(url)

        if needsSecurityScopedAccess {
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.accessDenied
            }
        }
        defer {
            if needsSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let content = try String(contentsOf: url, encoding: .utf8)

        // Tab-separated = saved output from the live WebCIS JS extractor.
        // Delegate to the same parser used during live import so both paths behave identically.
        let firstDataLine = content.components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if firstDataLine?.contains("\t") == true {
            return try parseWebCISText(content)
        }

        let lines = content.components(separatedBy: .newlines)

        // Find where data starts (after header lines that start with whitespace or contain "Date")
        var dataStartIndex = 0
        for (index, line) in lines.enumerated() {
            // Data lines start with a digit (date)
            if line.trimmingCharacters(in: .whitespaces).first?.isNumber == true {
                dataStartIndex = index
                break
            }
        }

        guard dataStartIndex < lines.count else {
            throw ImportError.invalidFormat
        }

        // Create CSV headers for webCIS data
        let headers = ["DATE", "REG", "DEP", "DES", "INST", "P2D", "P2N", "P1D", "P1N",
                       "P1USD", "P1USN", "MEDD", "MEDN", "MEFD", "MEFN", "MECD", "MECN", "SIMU", "FLEN", "TOTAL", "SPINS"]

        // Parse data rows
        var dataRows: [[String]] = []

        for line in lines[dataStartIndex...] {
            // Skip empty lines
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            // Only process lines that start with a digit (date)
            guard line.first?.isNumber == true || (line.count > 0 && line.prefix(1).first?.isNumber == true) else {
                continue
            }

            let row = parseWebCISLine(line)
            dataRows.append(row)
        }

        return ImportData(
            headers: headers,
            rows: dataRows,
            fileURL: url,
            delimiter: ","
        )
    }

    private func parseWebCISLine(_ line: String) -> [String] {
        var columns: [String] = []

        // Ensure line is long enough (at least 148 chars for full data including SpIns)
        let paddedLine = line.padding(toLength: 148, withPad: " ", startingAt: 0)

        // Extract fields based on character positions (from Perl script)
        columns.append(String(paddedLine.prefix(7)).trimmingCharacters(in: .whitespaces))  // Date (0-6)
        columns.append(String(paddedLine.dropFirst(8).prefix(3)).trimmingCharacters(in: .whitespaces))  // Reg (8-10)
        columns.append(String(paddedLine.dropFirst(12).prefix(3)).trimmingCharacters(in: .whitespaces)) // Dep (12-14)
        columns.append(String(paddedLine.dropFirst(16).prefix(3)).trimmingCharacters(in: .whitespaces)) // Dest (16-18)
        columns.append(String(paddedLine.dropFirst(20).prefix(4)).trimmingCharacters(in: .whitespaces)) // Inst (20-23)

        // Multi-engine columns - will be summed according to P1/P2/P1US logic
        let sedd = String(paddedLine.dropFirst(26).prefix(5)).trimmingCharacters(in: .whitespaces)  // P2 Day
        let sedn = String(paddedLine.dropFirst(33).prefix(5)).trimmingCharacters(in: .whitespaces)  // P2 Night
        let secd = String(paddedLine.dropFirst(40).prefix(5)).trimmingCharacters(in: .whitespaces)  // P1 Day
        let secn = String(paddedLine.dropFirst(47).prefix(5)).trimmingCharacters(in: .whitespaces)  // P1 Night
        let meid = String(paddedLine.dropFirst(54).prefix(5)).trimmingCharacters(in: .whitespaces)  // P1US Day
        let mein = String(paddedLine.dropFirst(62).prefix(5)).trimmingCharacters(in: .whitespaces)  // P1US Night
        let medd = String(paddedLine.dropFirst(70).prefix(5)).trimmingCharacters(in: .whitespaces)  // ME Dual Day (P2)
        let medn = String(paddedLine.dropFirst(78).prefix(5)).trimmingCharacters(in: .whitespaces)  // ME Dual Night (P2)
        var mefd = String(paddedLine.dropFirst(86).prefix(5)).trimmingCharacters(in: .whitespaces)  // ME CoPilot Day (P2)
        var mefn = String(paddedLine.dropFirst(94).prefix(5)).trimmingCharacters(in: .whitespaces)  // ME CoPilot Night (P2)
        let mecd = String(paddedLine.dropFirst(103).prefix(5)).trimmingCharacters(in: .whitespaces) // ME Cmd Day (P1)
        let mecn = String(paddedLine.dropFirst(114).prefix(5)).trimmingCharacters(in: .whitespaces) // ME Cmd Night (P1)

        // Deduplication logic: If ICUS time exists, blank out CoPilot time
        if !meid.isEmpty && meid.contains(":") && !mefd.isEmpty && mefd.contains(":") {
            mefd = ""
        }
        if !mein.isEmpty && mein.contains(":") && !mefn.isEmpty && mefn.contains(":") {
            mefn = ""
        }

        columns.append(sedd)  // P2D
        columns.append(sedn)  // P2N
        columns.append(secd)  // P1D
        columns.append(secn)  // P1N
        columns.append(meid)  // P1USD
        columns.append(mein)  // P1USN
        columns.append(medd)  // MEDD
        columns.append(medn)  // MEDN
        columns.append(mefd)  // MEFD
        columns.append(mefn)  // MEFN
        columns.append(mecd)  // MECD
        columns.append(mecn)  // MECN

        let simu = String(paddedLine.dropFirst(132).prefix(4)).trimmingCharacters(in: .whitespaces) // Sim
        let flen = String(paddedLine.dropFirst(123).prefix(5)).trimmingCharacters(in: .whitespaces) // Flight Eng (ignore)
        let spins = String(paddedLine.dropFirst(138).prefix(7)).trimmingCharacters(in: .whitespaces) // SpIns (138-144)

        columns.append(simu)  // SIMU
        columns.append(flen)  // FLEN (will be ignored)

        // If SpIns matches SimTime, pilot was instructing — exclude sim from total
        let simuForTotal = (!spins.isEmpty && spins.contains(":") && spins == simu) ? "" : simu
        let total = sumWebCISTimes([sedd, sedn, secd, secn, meid, mein, medd, medn, mefd, mefn, mecd, mecn, simuForTotal])
        columns.append(total)  // TOTAL
        columns.append(spins)  // SPINS

        return columns
    }

    private func sumWebCISTimes(_ times: [String]) -> String {
        var totalMinutes = 0

        for time in times {
            let trimmed = time.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == "     " {
                continue
            }

            // Parse h:mm or :mm format
            if trimmed.contains(":") {
                let parts = trimmed.split(separator: ":")
                if parts.count == 2 {
                    let hours = Int(parts[0].trimmingCharacters(in: .whitespaces)) ?? 0
                    let minutes = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                    totalMinutes += (hours * 60) + minutes
                } else if parts.count == 1 {
                    // Just :mm format
                    let minutes = Int(parts[0].trimmingCharacters(in: .whitespaces)) ?? 0
                    totalMinutes += minutes
                }
            }
        }

        // Convert back to decimal hours
        // Use %.2f to match parseDurationTime precision — %.1f caused rounding errors
        // e.g. 1:46 (106 min) → 1.7666... → "1.8" (%.1f) → stored as 1.80 → displayed as 1:48
        // With %.2f: 1.7666... → "1.77" → displayed as 1:46 (correct)
        let decimalHours = Double(totalMinutes) / 60.0
        return String(format: "%.2f", decimalHours)
    }

    private func createWebCISFieldMapping(headers: [String]) -> [FieldMapping] {
        var mappings: [FieldMapping] = []

        // Map fields from webCIS to Block-Time format
        mappings.append(FieldMapping(logbookField: "Date", logbookFieldDescription: "Date", sourceColumn: "DATE", isRequired: true))
        mappings.append(FieldMapping(logbookField: "Aircraft Reg", logbookFieldDescription: "Aircraft Reg", sourceColumn: "REG", isRequired: true))
        mappings.append(FieldMapping(logbookField: "From Airport", logbookFieldDescription: "From Airport", sourceColumn: "DEP", isRequired: true))
        mappings.append(FieldMapping(logbookField: "To Airport", logbookFieldDescription: "To Airport", sourceColumn: "DES", isRequired: true))
        mappings.append(FieldMapping(logbookField: "Instrument Time", logbookFieldDescription: "Instrument Time", sourceColumn: "INST", isRequired: false))

        // P1 Time - sum of P1 Day + P1 Night + ME Cmd Day + ME Cmd Night
        var p1Mapping = FieldMapping(logbookField: "P1 Time", logbookFieldDescription: "P1 Time", sourceColumn: "P1D", isRequired: false, supportsMultipleColumns: true)
        p1Mapping.sourceColumns = ["P1D", "P1N", "MECD", "MECN"]
        mappings.append(p1Mapping)

        // P1US Time - sum of P1US Day + P1US Night
        var p1usMapping = FieldMapping(logbookField: "P1US Time", logbookFieldDescription: "P1US Time", sourceColumn: "P1USD", isRequired: false, supportsMultipleColumns: true)
        p1usMapping.sourceColumns = ["P1USD", "P1USN"]
        mappings.append(p1usMapping)

        // P2 Time - sum of P2 Day + P2 Night + ME Dual Day + ME Dual Night + ME CoPilot Day + ME CoPilot Night
        var p2Mapping = FieldMapping(logbookField: "P2 Time", logbookFieldDescription: "P2 Time", sourceColumn: "P2D", isRequired: false, supportsMultipleColumns: true)
        p2Mapping.sourceColumns = ["P2D", "P2N", "MEDD", "MEDN", "MEFD", "MEFN"]
        mappings.append(p2Mapping)

        // Night Time - sum of all night columns (P2 Night + P1 Night + P1US Night + ME Dual Night + ME CoPilot Night + ME Cmd Night)
        var nightMapping = FieldMapping(logbookField: "Night Time", logbookFieldDescription: "Night Time", sourceColumn: "P2N", isRequired: false, supportsMultipleColumns: true)
        nightMapping.sourceColumns = ["P2N", "P1N", "P1USN", "MEDN", "MEFN", "MECN"]
        mappings.append(nightMapping)

        // Block Time = Total
        mappings.append(FieldMapping(logbookField: "Block Time", logbookFieldDescription: "Block Time", sourceColumn: "TOTAL", isRequired: true))

        // SIM Time
        mappings.append(FieldMapping(logbookField: "SIM Time", logbookFieldDescription: "SIM Time", sourceColumn: "SIMU", isRequired: false))

        // Sp/Ins Time
        mappings.append(FieldMapping(logbookField: "Sp/Ins Time", logbookFieldDescription: "Sp/Ins Time", sourceColumn: "SPINS", isRequired: false))

        return mappings
    }

    // MARK: - Parse Date
    private func parseDate(_ dateString: String) -> String {
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)

        // If already in DD/MM/YYYY format with valid 4-digit year, normalize it to ensure leading zeros
        if isValidDDMMYYYY(trimmed) {
            // Additional check: make sure it's not year 0001-0999
            let components = trimmed.split(separator: "/")
            if components.count == 3, let year = Int(components[2]), year >= 1950 {
                // Parse and reformat to ensure consistent "dd/MM/yyyy" format with leading zeros
                let parseFormatter = DateFormatter()
                parseFormatter.dateFormat = "d/M/yyyy"  // Flexible format to parse both "5/12/2025" and "05/12/2025"
                parseFormatter.locale = Locale(identifier: "en_US_POSIX")
                parseFormatter.timeZone = TimeZone(secondsFromGMT: 0)

                if let date = parseFormatter.date(from: trimmed) {
                    let outputFormatter = DateFormatter()
                    outputFormatter.dateFormat = "dd/MM/yyyy"  // Strict format with leading zeros
                    outputFormatter.locale = Locale(identifier: "en_US_POSIX")
                    outputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    return outputFormatter.string(from: date)
                }

                // If parsing fails, return as-is (shouldn't happen if isValidDDMMYYYY passed)
                return trimmed
            }
        }

        // Try to parse various date formats
        let dateFormatters = createDateFormatters()

        for formatter in dateFormatters {
            if let date = formatter.date(from: trimmed) {
                // Convert to DD/MM/YYYY format
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "dd/MM/yyyy"
                outputFormatter.locale = Locale(identifier: "en_US_POSIX")
                outputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                return outputFormatter.string(from: date)
            }
        }

        // If all parsing fails, return original string
        return trimmed
    }

    private func createDateFormatters() -> [DateFormatter] {
        let formats = [
            // Try 2-digit year formats first (more specific)
            "dd/MM/yy",        // 31/12/24 or 15/06/01
            "d/M/yy",          // 1/1/24
            "MM/dd/yy",        // 12/31/24 (US)
            "yy-MM-dd",        // 24-12-31
            "ddMMMyy",         // 25Sep04 (webCIS file format)
            "dMMMyy",          // 1Sep04 (webCIS file format with single digit day)
            "dd-MMM-yy",       // 25-Sep-04 (webCIS saved download format)
            "d-MMM-yy",        // 6-May-23 (webCIS saved download format single digit day)
            "dd MMM yy",       // 11 May 01 (webCIS DOM/live format)
            "d MMM yy",        // 1 May 01 (webCIS DOM/live format single digit day)
            // Then 4-digit year formats
            "dd/MM/yyyy",      // 31/12/2024
            "d/M/yyyy",        // 1/1/2024
            "dd-MM-yyyy",      // 31-12-2024
            "d-M-yyyy",        // 1-1-2024
            "yyyy-MM-dd",      // 2024-12-31 (ISO)
            "MM/dd/yyyy",      // 12/31/2024 (US)
            "M/d/yyyy",        // 1/1/2024 (US short)
            "dd.MM.yyyy",      // 31.12.2024 (European)
            "d.M.yyyy",        // 1.1.2024 (European short)
            "yyyyMMdd",        // 20241231
            "dd MMM yyyy",     // 31 Dec 2024
            "d MMM yyyy",      // 1 Dec 2024
            "dd MMMM yyyy",    // 31 December 2024
            "MMM dd, yyyy",    // Dec 31, 2024
            "MMMM dd, yyyy",   // December 31, 2024
            "yyyy/MM/dd",      // 2024/12/31
        ]

        // Set reference date for 2-digit year parsing (Jan 1, 1950)
        // This makes years 50-99 -> 1950-1999, and 00-49 -> 2000-2049
        let referenceDate = Calendar.current.date(from: DateComponents(year: 1950, month: 1, day: 1))!

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            // Set the two-digit year window for formats with 2-digit years
            if format.contains("yy") && !format.contains("yyyy") {
                formatter.twoDigitStartDate = referenceDate
            }

            return formatter
        }
    }

    private func isValidDDMMYYYY(_ dateString: String) -> Bool {
        let pattern = "^\\d{1,2}/\\d{1,2}/\\d{4}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: dateString.utf16.count)
        return regex?.firstMatch(in: dateString, range: range) != nil
    }

    // MARK: - Profile-Aware Pre-Processing

    /// Applies profile-specific column transformations before the data reaches ImportMappingView.
    /// Returns transformed (headers, rows) — headers may gain new synthetic columns.
    private static func preprocess(headers: [String], rows: [[String]]) -> ([String], [[String]]) {
        // PilotLog: ac_issim column — rows where value contains "sim" are simulator sessions.
        // time_total holds the sim duration; move it to sim_time and zero out time_total.
        if let isSimIdx = headers.firstIndex(of: "ac_issim"),
           let totalIdx = headers.firstIndex(of: "time_total") {

            // Add sim_time column if not already present
            var outHeaders = headers
            let simTimeCol = "sim_time"
            let simTimeIdx: Int
            if let existing = headers.firstIndex(of: simTimeCol) {
                simTimeIdx = existing
            } else {
                outHeaders.append(simTimeCol)
                simTimeIdx = outHeaders.count - 1
            }

            var simCount = 0
            let outRows: [[String]] = rows.map { row in
                guard isSimIdx < row.count else { return row }
                let isSim = row[isSimIdx].lowercased().contains("sim")
                guard isSim else {
                    // Non-sim row: pad sim_time column with empty string if we added it
                    if simTimeIdx == outHeaders.count - 1 && simTimeIdx >= row.count {
                        return row + [""]
                    }
                    return row
                }

                simCount += 1
                var mutable = row
                // Pad row to accommodate the new column if needed
                while mutable.count <= simTimeIdx { mutable.append("") }

                let totalValue = totalIdx < row.count ? row[totalIdx] : ""
                mutable[simTimeIdx] = totalValue   // move to sim_time
                mutable[totalIdx] = "00:00"        // zero out time_total
                return mutable
            }

            if simCount > 0 {
                LogManager.shared.info("🔧 PilotLog pre-process: moved time_total → sim_time for \(simCount) simulator row(s)")
            }
            return (outHeaders, outRows)
        }

        return (headers, rows)
    }
}

// MARK: - Import Result
struct ImportResult {
    let successCount: Int
    let failureCount: Int
    let duplicateCount: Int
    let failureReasons: [String: Int] // Reason -> Count
    let sampleFailures: [(row: Int, reason: String)] // First 10 failures with row numbers
    let sessionID: UUID?
    let mergeProposals: [MergeProposal]
}

// MARK: - Import Error
enum ImportError: LocalizedError {
    case accessDenied
    case emptyFile
    case invalidFormat
    case notLoggerFormat

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to file was denied"
        case .emptyFile:
            return "The file is empty"
        case .invalidFormat:
            return "The file format is invalid"
        case .notLoggerFormat:
            return "File is not in Block-Time backup format"
        }
    }
}

// MARK: - Flight Creation Error
struct FlightCreationError: Error {
    let message: String
}

// MARK: - String Extension for Deterministic UUID
extension String {
    /// Creates a deterministic UUID from the string using SHA256 hash
    /// This ensures the same input always produces the same UUID
    /// Note: This is NOT for cryptographic security - it's for generating consistent UUIDs from flight data to detect duplicates
    func md5UUID() -> String {
        // Convert string to data
        guard let data = self.data(using: .utf8) else {
            return UUID().uuidString
        }

        // Create SHA256 hash (using SHA256 instead of deprecated MD5)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }

        // Convert to UUID string format (version 5 UUID - SHA-1 based, but we're using SHA256 which is stronger)
        // Format: xxxxxxxx-xxxx-5xxx-yxxx-xxxxxxxxxxxx
        // Set version to 5 (SHA-based UUID)
        digest[6] = (digest[6] & 0x0F) | 0x50
        // Set variant to RFC4122
        digest[8] = (digest[8] & 0x3F) | 0x80

        // Format as UUID string (use first 16 bytes of SHA256 hash)
        return String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                     digest[0], digest[1], digest[2], digest[3],
                     digest[4], digest[5],
                     digest[6], digest[7],
                     digest[8], digest[9],
                     digest[10], digest[11], digest[12], digest[13], digest[14], digest[15])
    }
}
