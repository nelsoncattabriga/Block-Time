//
//  AeroDataBoxService.swift
//  Block-Time
//

import Foundation

// MARK: - AeroDataBox Response Models (private to this file)

private struct ADBFlight: Codable {
    let departure: ADBEndpoint
    let arrival: ADBEndpoint
    let number: String?
    let status: String?
    let isCargo: Bool?
    let aircraft: ADBaircraft?
}

private struct ADBEndpoint: Codable {
    let airport: ADBPort
    let scheduledTime: ADBTimeEntry?  // STD / STA
    let revisedTime: ADBTimeEntry?    // Actual OUT / IN (gate times)
    let runwayTime: ADBTimeEntry?     // Wheels off / on — NOT used for logbook
    let predictedTime: ADBTimeEntry?  // Prediction — NOT used
}

private struct ADBPort: Codable {
    let icao: String?
    let iata: String?
    let name: String?
    let shortName: String?
    let municipalityName: String?
    let timeZone: String?
}

private struct ADBTimeEntry: Codable {
    let utc: String
    let local: String?
}

private struct ADBaircraft: Codable {
    let reg: String?
    let modeS: String?
    let model: String?
}

// MARK: - Error

enum AeroDataBoxError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid AeroDataBox URL"
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .parsingError(let msg):
            return "Unable to parse AeroDataBox response: \(msg)"
        case .httpError(let code):
            return "AeroDataBox HTTP error \(code)"
        }
    }
}

// MARK: - Service

final class AeroDataBoxService {

    static let shared = AeroDataBoxService()
    private init() {}

    private let baseURL = "https://aerodatabox.p.rapidapi.com"

    // MARK: - Public API

    /// Fetch flight data from AeroDataBox for a specific local departure date.
    ///
    /// The caller is responsible for supplying the correct LOCAL departure date
    /// (not UTC). Use AirportService.convertToLocalDate with the departure airport
    /// ICAO and UTC departure time to derive it before calling this method.
    ///
    /// - Parameters:
    ///   - flightNumber: IATA format, e.g. "QF1" or "QF933"
    ///   - localDepartureDate: Local departure date in app format dd/MM/yyyy
    func fetchFlightData(flightNumber: String, localDepartureDate: String) async -> [FlightAwareData] {
        let cleanNumber = flightNumber.replacingOccurrences(of: " ", with: "")
        LogManager.shared.info("🌐 AeroDataBox: Starting fetch — flight=\(cleanNumber), localDate=\(localDepartureDate)")

        guard let apiDate = convertDateToAPIFormat(localDepartureDate) else {
            LogManager.shared.error("🌐 AeroDataBox: Failed to convert date '\(localDepartureDate)' — expected dd/MM/yyyy")
            return []
        }

        return await fetchForAPIDate(apiDate, flightNumber: cleanNumber)
    }

    // MARK: - Private single-date fetch

    /// Fetch and parse flights for one specific YYYY-MM-DD date string.
    /// Returns empty array (never throws) so concurrent fan-out ignores individual failures gracefully.
    private func fetchForAPIDate(_ apiDate: String, flightNumber: String) async -> [FlightAwareData] {
        let urlString = "\(baseURL)/flights/number/\(flightNumber)/\(apiDate)"
            + "?withAircraftImage=false&withLocation=false&withFlightPlan=false&dateLocalRole=Departure"

        guard let url = URL(string: urlString) else {
            LogManager.shared.error("🌐 AeroDataBox: Could not build URL for date \(apiDate)")
            return []
        }

        LogManager.shared.info("🌐 AeroDataBox: GET \(urlString)")

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15.0)
        request.httpMethod = "GET"
        request.setValue(APIKeys.aeroDataBoxAPIKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue("aerodatabox.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            LogManager.shared.error("🌐 AeroDataBox (\(apiDate)): Network error — \(error.localizedDescription)")
            return []
        }

        if let http = response as? HTTPURLResponse {
            LogManager.shared.info("🌐 AeroDataBox (\(apiDate)): HTTP \(http.statusCode)")
            guard http.statusCode == 200 else {
                if http.statusCode != 404 {
                    let body = String(data: data, encoding: .utf8) ?? "<no body>"
                    LogManager.shared.error("🌐 AeroDataBox (\(apiDate)): HTTP \(http.statusCode) — \(body.prefix(200))")
                }
                return []
            }
        }

        if let rawJSON = String(data: data, encoding: .utf8) {
            LogManager.shared.debug("🌐 AeroDataBox (\(apiDate)): Raw JSON (first 1500 chars): \(rawJSON.prefix(1500))")
        }

        let flights: [ADBFlight]
        do {
            flights = try JSONDecoder().decode([ADBFlight].self, from: data)
        } catch {
            LogManager.shared.error("🌐 AeroDataBox (\(apiDate)): JSON decode failed — \(error)")
            return []
        }

        LogManager.shared.info("🌐 AeroDataBox (\(apiDate)): Decoded \(flights.count) flight object(s)")

        return parseFlights(flights, searchDate: apiDate)
    }

    // MARK: - Parse

    private func parseFlights(_ flights: [ADBFlight], searchDate: String) -> [FlightAwareData] {
        var results: [FlightAwareData] = []

        for (idx, flight) in flights.enumerated() {
            let flightNum   = flight.number ?? "unknown"
            let status      = flight.status ?? "unknown"
            let isCargo     = flight.isCargo ?? false
            let aircraftReg = flight.aircraft?.reg

            LogManager.shared.info("🌐 AeroDataBox (\(searchDate)) [\(idx)] number=\(flightNum), status=\(status), isCargo=\(isCargo), aircraftReg=\(aircraftReg ?? "nil")")

            if isCargo {
                LogManager.shared.info("🌐 AeroDataBox (\(searchDate)) [\(idx)]: Skipping cargo flight")
                continue
            }

            guard let depICAO = flight.departure.airport.icao, !depICAO.isEmpty,
                  let arrICAO = flight.arrival.airport.icao, !arrICAO.isEmpty else {
                LogManager.shared.warning("🌐 AeroDataBox (\(searchDate)) [\(idx)]: Missing ICAO code(s) — skipping")
                continue
            }

            // ── Departure times ──────────────────────────────────────────────
            let depScheduled = flight.departure.scheduledTime?.utc
            let depRevised   = flight.departure.revisedTime?.utc
            let depRunway    = flight.departure.runwayTime?.utc

            LogManager.shared.info("🌐 AeroDataBox (\(searchDate)) [\(idx)] DEP \(depICAO):")
            LogManager.shared.info("   scheduledTime (STD) = \(depScheduled ?? "nil")")
            LogManager.shared.info("   revisedTime  (OUT)  = \(depRevised  ?? "nil")")
            LogManager.shared.info("   runwayTime  (T/O)   = \(depRunway   ?? "nil")")

            // ── Arrival times ────────────────────────────────────────────────
            let arrScheduled = flight.arrival.scheduledTime?.utc
            let arrRevised   = flight.arrival.revisedTime?.utc
            let arrRunway    = flight.arrival.runwayTime?.utc

            LogManager.shared.info("🌐 AeroDataBox (\(searchDate)) [\(idx)] ARR \(arrICAO):")
            LogManager.shared.info("   scheduledTime (STA) = \(arrScheduled ?? "nil")")
            LogManager.shared.info("   revisedTime  (IN)   = \(arrRevised   ?? "nil")")
            LogManager.shared.info("   runwayTime  (LDG)   = \(arrRunway    ?? "nil")")

            // revisedTime = actual gate OUT/IN; falls back to scheduledTime if absent
            let departureIsActual = depRevised != nil
            let arrivalIsActual   = arrRevised != nil

            guard let depRaw = depRevised ?? depScheduled,
                  let arrRaw = arrRevised ?? arrScheduled else {
                LogManager.shared.warning("🌐 AeroDataBox (\(searchDate)) [\(idx)] \(depICAO)→\(arrICAO): No usable times — skipping")
                continue
            }

            guard let depTime = parseUTCTime(depRaw),
                  let arrTime = parseUTCTime(arrRaw) else {
                LogManager.shared.warning("🌐 AeroDataBox (\(searchDate)) [\(idx)] \(depICAO)→\(arrICAO): Failed to parse times '\(depRaw)' / '\(arrRaw)' — skipping")
                continue
            }

            let scheduledDepTime = depScheduled.flatMap { parseUTCTime($0) }
            let scheduledArrTime = arrScheduled.flatMap { parseUTCTime($0) }
            let runwayDepTime    = depRunway.flatMap { parseUTCTime($0) }
            let runwayArrTime    = arrRunway.flatMap { parseUTCTime($0) }

            // Derive dd/MM/yyyy from the UTC departure time (most stable reference)
            let flightDateSource = depScheduled ?? depRevised ?? depRaw
            let flightDate = parseUTCDate(flightDateSource) ?? searchDate.replacingOccurrences(of: "-", with: "/")

            LogManager.shared.info("🌐 AeroDataBox (\(searchDate)) [\(idx)] \(depICAO)→\(arrICAO) RESOLVED:")
            LogManager.shared.info("   OUT (revisedTime) = \(depTime) UTC (actual=\(departureIsActual))")
            LogManager.shared.info("   IN  (revisedTime) = \(arrTime) UTC (actual=\(arrivalIsActual))")
            LogManager.shared.info("   STD               = \(scheduledDepTime ?? "nil") UTC")
            LogManager.shared.info("   STA               = \(scheduledArrTime ?? "nil") UTC")
            LogManager.shared.info("   T/O (runwayTime)  = \(runwayDepTime ?? "nil") UTC")
            LogManager.shared.info("   LDG (runwayTime)  = \(runwayArrTime ?? "nil") UTC")
            LogManager.shared.info("   Date              = \(flightDate)")

            results.append(FlightAwareData(
                origin: depICAO,
                destination: arrICAO,
                departureTime: depTime,
                arrivalTime: arrTime,
                scheduledDepartureTime: scheduledDepTime,
                scheduledArrivalTime: scheduledArrTime,
                flightDate: flightDate,
                source: .aeroDataBox,
                departureIsActual: departureIsActual,
                arrivalIsActual: arrivalIsActual,
                departureRunwayTime: runwayDepTime,
                arrivalRunwayTime: runwayArrTime,
                aircraftRegistration: aircraftReg
            ))
        }

        return results
    }

    // MARK: - Date/Time Helpers

    /// Extract HH:MM from AeroDataBox UTC string e.g. "2026-02-27 05:25Z" → "05:25"
    private func parseUTCTime(_ utcString: String) -> String? {
        let parts = utcString.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }
        var timePart = parts[1]
        if timePart.hasSuffix("Z") { timePart = String(timePart.dropLast()) }
        let timeComponents = timePart.components(separatedBy: ":")
        guard timeComponents.count >= 2,
              timeComponents[0].count == 2,
              timeComponents[1].count == 2 else { return nil }
        return "\(timeComponents[0]):\(timeComponents[1])"
    }

    /// Extract dd/MM/yyyy from AeroDataBox UTC string e.g. "2026-02-27 05:25Z" → "27/02/2026"
    private func parseUTCDate(_ utcString: String) -> String? {
        let parts = utcString.components(separatedBy: " ")
        guard let datePart = parts.first else { return nil }
        let c = datePart.components(separatedBy: "-")
        guard c.count == 3 else { return nil }
        return "\(c[2])/\(c[1])/\(c[0])"
    }

    /// Convert app date dd/MM/yyyy → YYYY-MM-DD for the API.
    private func convertDateToAPIFormat(_ date: String) -> String? {
        let parts = date.components(separatedBy: "/")
        guard parts.count == 3 else { return nil }
        return "\(parts[2])-\(parts[1])-\(parts[0])"
    }

}
