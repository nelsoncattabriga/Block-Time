//
//  MacFlightSearchHelpers.swift
//  Block-Time-Mac
//

import Foundation

extension String {
    /// Converts airline code to FlightAware format (e.g., QF -> QFA)
    static func toFlightAwareAirlineCode(_ code: String) -> String {
        let airlineMappings: [String: String] = [
            "QF": "QFA",
            "QFA": "QFA",
            "VA": "VOZ",
            "VOZ": "VOZ",
            "JQ": "JST",
            "JST": "JST",
            "NZ": "ANZ",
            "ANZ": "ANZ",
            "SQ": "SIA",
            "SIA": "SIA",
            "BA": "BAW",
            "BAW": "BAW",
            "QR": "QTR",
            "QTR": "QTR",
            "EK": "UAE",
            "UAE": "UAE",
            "TG": "THA",
            "THA": "THA",
        ]
        return airlineMappings[code.uppercased()] ?? code.uppercased()
    }

    /// Converts a flight number to FlightAware URL format.
    /// - "QF933" or "QFA933" -> "QFA933"
    /// - "933" (with userAirlinePrefix "QF") -> "QFA933"
    func toFlightAwareFormat(userAirlinePrefix: String? = nil) -> String? {
        let cleaned = self.trimmingCharacters(in: .whitespaces).uppercased()

        let patternWithAirline = "^([A-Z]{2,3})(0?\\d+)$"
        if let regex = try? NSRegularExpression(pattern: patternWithAirline),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let airlineRange = Range(match.range(at: 1), in: cleaned),
           let numberRange = Range(match.range(at: 2), in: cleaned) {

            let airlineCode = String(cleaned[airlineRange])
            var flightNumber = String(cleaned[numberRange])
            if flightNumber.hasPrefix("0") {
                flightNumber = String(flightNumber.dropFirst())
            }
            return String.toFlightAwareAirlineCode(airlineCode) + flightNumber
        }

        let patternNumberOnly = "^(0?\\d+)$"
        if let regex = try? NSRegularExpression(pattern: patternNumberOnly),
           regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) != nil,
           let userPrefix = userAirlinePrefix, !userPrefix.isEmpty {

            var flightNumber = cleaned
            if flightNumber.hasPrefix("0") {
                flightNumber = String(flightNumber.dropFirst())
            }
            return String.toFlightAwareAirlineCode(userPrefix) + flightNumber
        }

        return nil
    }
}
