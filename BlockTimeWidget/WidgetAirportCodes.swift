//
//  WidgetAirportCodes.swift
//  BlockTimeWidget
//
//  Lightweight ICAO→IATA lookup for use in the widget extension.
//  Parses the same airports.dat.txt file used by AirportService.
//  Add airports.dat.txt to the widget extension target in Build Phases → Copy Bundle Resources.
//

import Foundation

enum WidgetAirportCodes {

    // Parsed once, lazily, and cached for the widget's lifetime
    private static let map: [String: String] = buildMap()

    /// Returns the IATA code for an ICAO code, or nil if unknown.
    static func iataFor(icao: String) -> String? {
        map[icao.uppercased()]
    }

    // MARK: - Parser

    private static func buildMap() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "airports.dat", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }

        var result: [String: String] = [:]
        result.reserveCapacity(10_000)

        content.enumerateLines { line, _ in
            // CSV: id,name,city,country,IATA,ICAO,...
            // We only need columns 4 (IATA) and 5 (ICAO)
            let parts = line.components(separatedBy: ",")
            guard parts.count > 5 else { return }

            let iata = parts[4].trimmingCharacters(in: .init(charactersIn: "\" "))
            let icao = parts[5].trimmingCharacters(in: .init(charactersIn: "\" "))

            guard iata.count == 3, icao.count == 4,
                  iata != "\\N", iata != "" else { return }

            result[icao] = iata
        }

        return result
    }
}
