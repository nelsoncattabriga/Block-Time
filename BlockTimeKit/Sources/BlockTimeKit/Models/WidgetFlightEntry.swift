import Foundation

/// Lightweight snapshot written by the main app and read by the widget extension.
/// Stored as JSON in the shared App Group UserDefaults.
public struct WidgetFlightEntry: Codable {

    // MARK: - Flight identity
    public var flightNumber: String
    public var fromAirport: String
    public var toAirport: String

    // MARK: - Times (UTC)
    public var flightDate: Date
    public var departureDatetime: Date?
    public var arrivalDatetime: Date?

    // MARK: - Display preference
    public var useIATACodes: Bool

    // MARK: - Snapshot metadata
    public var snapshotDate: Date

    public init(
        flightNumber: String,
        fromAirport: String,
        toAirport: String,
        flightDate: Date,
        departureDatetime: Date? = nil,
        arrivalDatetime: Date? = nil,
        useIATACodes: Bool,
        snapshotDate: Date
    ) {
        self.flightNumber = flightNumber
        self.fromAirport = fromAirport
        self.toAirport = toAirport
        self.flightDate = flightDate
        self.departureDatetime = departureDatetime
        self.arrivalDatetime = arrivalDatetime
        self.useIATACodes = useIATACodes
        self.snapshotDate = snapshotDate
    }
}

// MARK: - Stable identity for ForEach
extension WidgetFlightEntry {
    public var stableID: String {
        let dep = departureDatetime?.timeIntervalSinceReferenceDate ?? flightDate.timeIntervalSinceReferenceDate
        return "\(fromAirport)-\(toAirport)-\(flightNumber)-\(dep)"
    }
}

// MARK: - UserDefaults key
extension WidgetFlightEntry {
    public static let appGroupID       = "group.com.thezoolab.blocktime"
    public static let defaultsKey      = "nextFlightSnapshot"
    public static let listDefaultsKey  = "upcomingFlightsSnapshot"
}
