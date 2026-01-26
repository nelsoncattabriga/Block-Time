//
//  LogbookImportService.swift
//  Block-Time
//
//  Created by Nelson on 21/10/2025.
//  Extracted from FlightTimeExtractorViewModel for better separation of concerns
//

import Foundation

/// Handles all logbook data import/export operations
/// Supports CSV and tab-delimited formats for importing flight data
class LogbookImportService {

    // MARK: - Dependencies

    private let databaseService: FlightDatabaseService
    private let airportService: AirportService

    // MARK: - Initialization

    init(
        databaseService: FlightDatabaseService = .shared,
        airportService: AirportService = .shared
    ) {
        self.databaseService = databaseService
        self.airportService = airportService
    }

    // MARK: - Import Operations

    /// Import logbook data from a CSV file
    /// - Parameter fileURL: URL to the CSV file
    /// - Returns: Result with success/failure counts or error
    func importLogbookData(from fileURL: URL) async -> Result<LogbookImportResult, LogbookImportError> {
        do {
            // Start accessing the security-scoped resource
            guard fileURL.startAccessingSecurityScopedResource() else {
                return .failure(.fileAccessDenied)
            }

            defer {
                fileURL.stopAccessingSecurityScopedResource()
            }

            // Read the CSV file
            let csvContent = try String(contentsOf: fileURL, encoding: .utf8)
            let flightSectors = try parseCSVContent(csvContent)

            // Clear existing data before importing
            guard databaseService.clearAllFlights() else {
                return .failure(.databaseClearFailed)
            }

            // Import new data to database
            var successCount = 0
            var failureCount = 0

            for sector in flightSectors {
                if databaseService.saveFlight(sector) {
                    successCount += 1
                } else {
                    failureCount += 1
                }
            }

            // Database service observers will automatically post debounced .flightDataChanged notification

            return .success(LogbookImportResult(successCount: successCount, failureCount: failureCount))

        } catch let error as LogbookImportError {
            return .failure(error)
        } catch {
            return .failure(.unknownError(error.localizedDescription))
        }
    }

    /// Import logbook data from a tab-delimited file
    /// - Parameter fileURL: URL to the tab-delimited file
    /// - Returns: Result with success/failure counts or error
    func importTabDelimitedLogbookData(from fileURL: URL) async -> Result<LogbookImportResult, LogbookImportError> {
        do {
            // Start accessing the security-scoped resource
            guard fileURL.startAccessingSecurityScopedResource() else {
                return .failure(.fileAccessDenied)
            }

            defer {
                fileURL.stopAccessingSecurityScopedResource()
            }

            // Read the tab-delimited file
            let tsvContent = try String(contentsOf: fileURL, encoding: .utf8)
            let flightSectors = try parseTabDelimitedContent(tsvContent)

            // Clear existing data before importing
            guard databaseService.clearAllFlights() else {
                return .failure(.databaseClearFailed)
            }

            // Import new data to database
            var successCount = 0
            var failureCount = 0

            for sector in flightSectors {
                if databaseService.saveFlight(sector) {
                    successCount += 1
                } else {
                    failureCount += 1
                }
            }

            // Database service observers will automatically post debounced .flightDataChanged notification

            return .success(LogbookImportResult(successCount: successCount, failureCount: failureCount))

        } catch let error as LogbookImportError {
            return .failure(error)
        } catch {
            return .failure(.unknownError(error.localizedDescription))
        }
    }

    // MARK: - CSV Parsing

    private func parseCSVContent(_ content: String) throws -> [FlightSector] {
        LogManager.shared.info("CSV Import: Starting to parse CSV content")
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else {
            LogManager.shared.error("CSV Import: Empty file")
            throw LogbookImportError.emptyFile
        }

        // Expect first line to be headers
        let headers = parseCSVLine(lines[0])
        let dataLines = Array(lines.dropFirst())
        LogManager.shared.debug("CSV Import: Found \(dataLines.count) data lines with headers: \(headers.joined(separator: ", "))")

        // Validate required headers
        let requiredHeaders = ["date", "flightNumber", "aircraftReg", "fromAirport", "toAirport", "captainName", "foName", "blockTime"]
        for required in requiredHeaders {
            guard headers.contains(where: { $0.lowercased().contains(required.lowercased()) }) else {
                throw LogbookImportError.missingRequiredColumn(required)
            }
        }

        var flightSectors: [FlightSector] = []

        for (index, line) in dataLines.enumerated() {
            do {
                let values = parseCSVLine(line)
                guard values.count == headers.count else {
                    LogManager.shared.warning("CSV Import: Line \(index + 2) has \(values.count) values but expected \(headers.count)")
                    continue
                }

                let flightSector = try createFlightSectorFromCSV(headers: headers, values: values)
                flightSectors.append(flightSector)

            } catch {
                LogManager.shared.error("CSV Import: Error parsing line \(index + 2): \(error)")
                continue
            }
        }

        LogManager.shared.info("CSV Import: Successfully parsed \(flightSectors.count) flight sectors")
        return flightSectors
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var insideQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                values.append(currentValue.trimmingCharacters(in: .whitespaces))
                currentValue = ""
            } else {
                currentValue.append(char)
            }

            i = line.index(after: i)
        }

        // Add the last value
        values.append(currentValue.trimmingCharacters(in: .whitespaces))

        return values
    }

    private func createFlightSectorFromCSV(headers: [String], values: [String]) throws -> FlightSector {
        func getValue(for key: String) -> String {
            guard let index = headers.firstIndex(where: { $0.lowercased().contains(key.lowercased()) }) else {
                return ""
            }
            return index < values.count ? values[index] : ""
        }

        let date = getValue(for: "date")
        let flightNumber = getValue(for: "flightNumber")
        let aircraftReg = getValue(for: "aircraftReg")
        let fromAirport = getValue(for: "fromAirport")
        let toAirport = getValue(for: "toAirport")
        let captainName = getValue(for: "captainName")
        let foName = getValue(for: "foName")
        let blockTime = getValue(for: "blockTime")

        // Validate required fields
        guard !date.isEmpty, !flightNumber.isEmpty, !aircraftReg.isEmpty,
              !fromAirport.isEmpty, !toAirport.isEmpty, !captainName.isEmpty,
              !foName.isEmpty, !blockTime.isEmpty else {
            throw LogbookImportError.missingRequiredData
        }

        // Optional fields with defaults and validation
        let aircraftType = getValue(for: "aircraftType").isEmpty ? "" : getValue(for: "aircraftType")

        // Use the global validateTimeString function for all time fields
        let nightTime = validateTimeString(getValue(for: "nightTime").isEmpty ? "0.0" : getValue(for: "nightTime"))
        let p1Time = validateTimeString(getValue(for: "p1Time").isEmpty ? "0.0" : getValue(for: "p1Time"))
        let p1usTime = validateTimeString(getValue(for: "p1usTime").isEmpty ? "0.0" : getValue(for: "p1usTime"))
        let p2Time = validateTimeString(getValue(for: "p2Time").isEmpty ? "0.0" : getValue(for: "p2Time"))
        let instrumentTime = validateTimeString(getValue(for: "instrumentTime").isEmpty ? "0.0" : getValue(for: "instrumentTime"))
        let simTime = validateTimeString(getValue(for: "simTime").isEmpty ? "0.0" : getValue(for: "simTime"))
        let validatedBlockTime = validateTimeString(blockTime)
        let isPilotFlying = getValue(for: "isPilotFlying").lowercased() == "true" || getValue(for: "isPF") == "1"
        let isAIII = getValue(for: "isAIII").lowercased() == "true" || getValue(for: "isAIII") == "1"
        let dayTakeoffs = Int(getValue(for: "dayTakeoffs")) ?? 0
        let dayLandings = Int(getValue(for: "dayLandings")) ?? 0
        let nightTakeoffs = Int(getValue(for: "nightTakeoffs")) ?? 0
        let nightLandings = Int(getValue(for: "nightLandings")) ?? 0
        let outTime = getValue(for: "outTime")
        let inTime = getValue(for: "inTime")

        return FlightSector(
            date: date,
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: airportService.convertToICAO(fromAirport),
            toAirport: airportService.convertToICAO(toAirport),
            captainName: captainName,
            foName: foName,
            so1Name: getValue(for: "so1Name").isEmpty ? nil : getValue(for: "so1Name"),
            so2Name: getValue(for: "so2Name").isEmpty ? nil : getValue(for: "so2Name"),
            blockTime: validatedBlockTime,
            nightTime: nightTime,
            p1Time: p1Time,
            p1usTime: p1usTime,
            p2Time: p2Time,
            instrumentTime: instrumentTime,
            simTime: simTime,
            isPilotFlying: isPilotFlying,
            isAIII: isAIII,
            dayTakeoffs: dayTakeoffs,
            dayLandings: dayLandings,
            nightTakeoffs: nightTakeoffs,
            nightLandings: nightLandings,
            outTime: outTime,
            inTime: inTime
        )
    }

    // MARK: - Tab-Delimited Parsing

    private func parseTabDelimitedContent(_ content: String) throws -> [FlightSector] {
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else {
            throw LogbookImportError.emptyFile
        }

        // Expect first line to be headers
        let headers = parseTabDelimitedLine(lines[0])
        let dataLines = Array(lines.dropFirst())

        // Validate required headers
        let requiredHeaders = ["Date", "Flight #", "From", "To", "Total Time"]
        for required in requiredHeaders {
            guard headers.contains(required) else {
                throw LogbookImportError.missingRequiredColumn(required)
            }
        }

        var flightSectors: [FlightSector] = []

        for (index, line) in dataLines.enumerated() {
            do {
                let values = parseTabDelimitedLine(line)
                // Allow value count to be less than or equal to header count (handles trailing tabs)
                guard values.count <= headers.count && values.count > 0 else {
                    LogManager.shared.warning("CSV Import: Line \(index + 2) has \(values.count) values but expected \(headers.count) or fewer")
                    continue
                }

                let flightSector = try createFlightSectorFromTabDelimited(headers: headers, values: values)
                flightSectors.append(flightSector)

            } catch {
                LogManager.shared.error("CSV Import: Error parsing line \(index + 2): \(error)")
                continue
            }
        }

        return flightSectors
    }

    private func parseTabDelimitedLine(_ line: String) -> [String] {
        return line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func createFlightSectorFromTabDelimited(headers: [String], values: [String]) throws -> FlightSector {
        func getValue(for key: String) -> String {
            guard let index = headers.firstIndex(of: key) else {
                return ""
            }
            return index < values.count ? values[index] : ""
        }

        let dateString = getValue(for: "Date")
        let rawFlightNumber = getValue(for: "Flight #")
        let aircraftReg = getValue(for: "Aircraft ID")
        let aircraftType = getValue(for: "Aircraft Type")
        let fromAirport = getValue(for: "From")
        let toAirport = getValue(for: "To")
        let picCrew = getValue(for: "PIC/P1 Crew")
        let sicCrew = getValue(for: "SIC/P2 Crew")
        let outTime = getValue(for: "Out")
        let inTime = getValue(for: "In")
        let blockTime = getValue(for: "Total Time")

        // Convert date from YYYY-MM-DD to DD/MM/YYYY
        let date: String
        if dateString.contains("-") {
            let components = dateString.split(separator: "-").map(String.init)
            if components.count == 3 {
                date = "\(components[2])/\(components[1])/\(components[0])"
            } else {
                date = dateString
            }
        } else {
            date = dateString
        }

        // Validate only essential required fields - allow empty airports for simulator/ground training
        guard !date.isEmpty, !blockTime.isEmpty else {
            throw LogbookImportError.missingRequiredData
        }

        // Determine crew positions based on where "Self" appears
        // If "Self" is in PIC/P1 column, user was captain
        // If "Self" is in SIC/P2 column, user was first officer
        var captainName: String
        var foName: String

        if picCrew.lowercased() == "self" {
            // User was PIC/Captain
            captainName = "Self"
            foName = sicCrew.isEmpty ? "" : sicCrew
        } else if sicCrew.lowercased() == "self" {
            // User was SIC/First Officer
            captainName = picCrew.isEmpty ? "" : picCrew
            foName = "Self"
        } else {
            // Neither contains "Self" - use values as-is
            captainName = picCrew
            foName = sicCrew
        }

        // Optional fields with defaults and validation
        let nightTime = validateTimeString(getValue(for: "Night").isEmpty ? "0.0" : getValue(for: "Night"))
        let p1Time = validateTimeString(getValue(for: "PIC").isEmpty ? "0.0" : getValue(for: "PIC"))
        let p1usTime = validateTimeString(getValue(for: "P1u/s").isEmpty ? "0.0" : getValue(for: "P1u/s"))
        let p2Time = validateTimeString(getValue(for: "P2").isEmpty ? "0.0" : getValue(for: "P2"))
        let simTime = validateTimeString(getValue(for: "Simulator").isEmpty ? "0.0" : getValue(for: "Simulator"))
        let validatedBlockTime = validateTimeString(blockTime)
        let isPilotFlying = getValue(for: "Pilot Flying").lowercased() == "true" || getValue(for: "Pilot Flying") == "1"
        let isAIII = getValue(for: "AIII").lowercased() == "true" || getValue(for: "AIII") == "1"
        let dayTakeoffs = Int(getValue(for: "Day T/O")) ?? 0
        let dayLandings = Int(getValue(for: "Day Ldg")) ?? 0
        let nightTakeoffs = Int(getValue(for: "Night T/O")) ?? 0
        let nightLandings = Int(getValue(for: "Night Ldg")) ?? 0
        let remarks = getValue(for: "Remarks")

        // For tab-delimited imports, keep flight numbers as-is (they're already in final format)
        // Don't apply any formatting or airline prefix
        let flightNumber = rawFlightNumber

        return FlightSector(
            date: date,
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: fromAirport,
            toAirport: toAirport,
            captainName: captainName,
            foName: foName,
            blockTime: validatedBlockTime,
            nightTime: nightTime,
            p1Time: p1Time,
            p1usTime: p1usTime,
            p2Time: p2Time,
            instrumentTime: "0.0",
            simTime: simTime,
            isPilotFlying: isPilotFlying,
            isAIII: isAIII,
            remarks: remarks,
            dayTakeoffs: dayTakeoffs,
            dayLandings: dayLandings,
            nightTakeoffs: nightTakeoffs,
            nightLandings: nightLandings,
            outTime: outTime,
            inTime: inTime
        )
    }
}

// MARK: - Result Types

/// Result of a logbook import operation
struct LogbookImportResult {
    let successCount: Int
    let failureCount: Int

    var totalCount: Int {
        successCount + failureCount
    }

    var isFullSuccess: Bool {
        failureCount == 0
    }
}

/// Logbook import errors
enum LogbookImportError: LocalizedError {
    case emptyFile
    case missingRequiredColumn(String)
    case missingRequiredData
    case invalidFileFormat
    case fileAccessDenied
    case databaseClearFailed
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The selected file is empty"
        case .missingRequiredColumn(let column):
            return "Missing required column: \(column)"
        case .missingRequiredData:
            return "Some rows are missing required data"
        case .invalidFileFormat:
            return "Invalid file format"
        case .fileAccessDenied:
            return "Unable to access the selected file"
        case .databaseClearFailed:
            return "Failed to clear existing flight data"
        case .unknownError(let message):
            return "Import failed: \(message)"
        }
    }
}
