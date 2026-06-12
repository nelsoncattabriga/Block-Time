//
//  WidgetFlightEntry.swift
//  Block-Time
//
//  Shared between the main app target and the BlockTimeWidget extension.
//  Add this file to both targets in Build Phases → Compile Sources.
//

import Foundation
import BlockTimeKit

/// Lightweight snapshot written by the main app and read by the widget extension.
/// Stored as JSON in the shared App Group UserDefaults.
struct WidgetFlightEntry: Codable {

    // MARK: - Flight identity
    var flightNumber: String       // e.g. "QF63"
    var fromAirport: String        // ICAO e.g. "FAOR" — widget converts to display format
    var toAirport: String          // ICAO e.g. "YSSY"

    // MARK: - Times (UTC)
    /// UTC date of the flight (midnight UTC of the flight date)
    var flightDate: Date

    /// Full UTC departure datetime — flightDate + scheduledDeparture offset.
    /// Nil if scheduledDeparture was empty; widget falls back to flightDate-only display.
    var departureDatetime: Date?

    /// Full UTC arrival datetime — flightDate + scheduledArrival offset.
    /// Nil if scheduledArrival was empty.
    var arrivalDatetime: Date?

    // MARK: - Display preference (written by main app from UserDefaults)
    /// When true, widget displays IATA codes; false = ICAO codes.
    var useIATACodes: Bool

    // MARK: - Snapshot metadata
    /// When this snapshot was written — used to detect staleness.
    var snapshotDate: Date
}

// MARK: - Stable identity for ForEach
extension WidgetFlightEntry {
    /// Composite ID combining route + departure time so duplicate flight numbers (or blank ones)
    /// don't cause SwiftUI to treat multiple rows as the same view and trigger layout loops.
    var stableID: String {
        let dep = departureDatetime?.timeIntervalSinceReferenceDate ?? flightDate.timeIntervalSinceReferenceDate
        return "\(fromAirport)-\(toAirport)-\(flightNumber)-\(dep)"
    }
}

// MARK: - UserDefaults key
extension WidgetFlightEntry {
    static let appGroupID    = "group.com.thezoolab.blocktime"
    static let defaultsKey   = "nextFlightSnapshot"
    static let listDefaultsKey = "upcomingFlightsSnapshot"
}
