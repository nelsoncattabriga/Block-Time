//
//  UnifiedRosterParser.swift
//  Block-Time
//
//  Created by Nelson on 03/11/2025.
//

import Foundation

// MARK: - Roster Type

enum RosterType: String {
    case shortHaul = "SH"
    case longHaul = "LH"

    var displayName: String {
        switch self {
        case .shortHaul: return "SH"
        case .longHaul: return "LH"
        }
    }
}

// MARK: - Unified Data Models

/// Unified flight model that works for both SH and LH rosters
struct UnifiedParsedFlight {
    let date: Date
    let flightNumber: String
    let departureAirport: String
    let arrivalAirport: String
    let departureTime: String  // HHmm format (e.g., "1239")
    let arrivalTime: String    // HHmm format (e.g., "1517")
    let aircraftType: String   // ICAO code (e.g., "B738", "B787")
    let role: String           // "Captain", "First Officer", or "Second Officer"
    let isPositioning: Bool    // True if positioning/PAX flight
    let bidPeriod: String      // e.g., "3711" (SH) or "356" (LH)
    let dutyCode: String?      // e.g., "5017A2" (SH) or "EN04X011" (LH)
    let rosterType: RosterType // Type of roster this came from
}

/// Unified parse result that works for both SH and LH rosters
struct UnifiedParseResult {
    let flights: [UnifiedParsedFlight]
    let pilotName: String
    let staffNumber: String
    let bidPeriod: String
    let base: String
    let category: String
    let rosterType: RosterType
}

// MARK: - Roster Parser Protocol

/// Protocol that all roster parsers must conform to
protocol RosterParser {
    /// Parse roster content from a string
    static func parseRoster(from content: String) throws -> UnifiedParseResult

    /// Parse roster from a file URL
    static func parseRoster(from fileURL: URL) throws -> UnifiedParseResult

    /// Detect if this parser can handle the given content
    static func canParse(content: String) -> Bool
}

// MARK: - Unified Roster Service

/// Main service that automatically detects roster type and routes to appropriate parser
class UnifiedRosterService {

    enum RosterDetectionError: Error, LocalizedError {
        case unknownRosterType
        case emptyContent

        var errorDescription: String? {
            switch self {
            case .unknownRosterType:
                return "Unable to determine roster type. Please ensure you've selected a valid Qantas roster file."
            case .emptyContent:
                return "The roster file is empty or could not be read."
            }
        }
    }

    /// Parse roster from file URL with automatic type detection
    static func parseRoster(from fileURL: URL) throws -> UnifiedParseResult {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try parseRoster(from: content)
    }

    /// Parse roster from string with automatic type detection
    static func parseRoster(from content: String) throws -> UnifiedParseResult {
        guard !content.isEmpty else {
            throw RosterDetectionError.emptyContent
        }

        // Try SH parser
        if SHRosterParser.canParse(content: content) {
            print("Detected Short Haul roster")
            return try SHRosterParser.parseRoster(from: content)
        }

        // Try LH parser
        if LHRosterParser.canParse(content: content) {
            print("Detected Long Haul roster")
            return try LHRosterParser.parseRoster(from: content)
        }

        // Unknown roster type
        throw RosterDetectionError.unknownRosterType
    }

    /// Detect roster type without parsing
    static func detectRosterType(from content: String) -> RosterType? {
        if SHRosterParser.canParse(content: content) {
            return .shortHaul
        }
        if LHRosterParser.canParse(content: content) {
            return .longHaul
        }
        return nil
    }
}

// MARK: - SH Roster Parser Wrapper

/// Wrapper for RosterParserService to conform to RosterParser protocol
class SHRosterParser: RosterParser {

    static func parseRoster(from content: String) throws -> UnifiedParseResult {
        let result = try RosterParserService.parseRoster(from: content)
        return convertToUnified(result)
    }

    static func parseRoster(from fileURL: URL) throws -> UnifiedParseResult {
        let result = try RosterParserService.parseRoster(from: fileURL)
        return convertToUnified(result)
    }

    static func canParse(content: String) -> Bool {
        // SH rosters contain these distinctive patterns
        return content.contains("Pattern Details") ||
               (content.contains("1-CPT") || content.contains("1-F/O")) ||
               content.contains("Bid Period") && content.range(of: #"Bid Period \d{4}"#, options: .regularExpression) != nil
    }

    private static func convertToUnified(_ result: RosterParserService.ParseResult) -> UnifiedParseResult {
        let flights = result.flights.map { flight in
            UnifiedParsedFlight(
                date: flight.date,
                flightNumber: flight.flightNumber,
                departureAirport: flight.departureAirport,
                arrivalAirport: flight.arrivalAirport,
                departureTime: flight.departureTime,
                arrivalTime: flight.arrivalTime,
                aircraftType: flight.aircraftType,
                role: flight.role,
                isPositioning: flight.isPositioning,
                bidPeriod: flight.bidPeriod,
                dutyCode: flight.dutyCode,
                rosterType: .shortHaul
            )
        }

        return UnifiedParseResult(
            flights: flights,
            pilotName: result.pilotName,
            staffNumber: result.staffNumber,
            bidPeriod: result.bidPeriod,
            base: result.base,
            category: result.category,
            rosterType: .shortHaul
        )
    }
}

// MARK: - LH Roster Parser Wrapper

/// Wrapper for LHRosterParserService to conform to RosterParser protocol
class LHRosterParser: RosterParser {

    static func parseRoster(from content: String) throws -> UnifiedParseResult {
        let result = try LHRosterParserService.parseRoster(from: content)
        return convertToUnified(result)
    }

    static func parseRoster(from fileURL: URL) throws -> UnifiedParseResult {
        let result = try LHRosterParserService.parseRoster(from: fileURL)
        return convertToUnified(result)
    }

    static func canParse(content: String) -> Bool {
        // LH rosters contain these distinctive patterns
        return content.contains("OPERATIONS ROSTER FOR BID PERIOD") ||
               content.contains("Pattern:") && content.contains("Route Code:") ||
               content.range(of: #"BID PERIOD\s+\d{3}"#, options: .regularExpression) != nil
    }

    private static func convertToUnified(_ result: LHRosterParserService.ParseResult) -> UnifiedParseResult {
        let flights = result.flights.map { flight in
            UnifiedParsedFlight(
                date: flight.date,
                flightNumber: flight.flightNumber,
                departureAirport: flight.departureAirport,
                arrivalAirport: flight.arrivalAirport,
                departureTime: flight.departureTime,
                arrivalTime: flight.arrivalTime,
                aircraftType: flight.aircraftType,
                role: flight.role,
                isPositioning: flight.isPositioning,
                bidPeriod: flight.bidPeriod,
                dutyCode: flight.patternCode,
                rosterType: .longHaul
            )
        }

        return UnifiedParseResult(
            flights: flights,
            pilotName: result.pilotName,
            staffNumber: result.staffNumber,
            bidPeriod: result.bidPeriod,
            base: result.base,
            category: result.category,
            rosterType: .longHaul
        )
    }
}
