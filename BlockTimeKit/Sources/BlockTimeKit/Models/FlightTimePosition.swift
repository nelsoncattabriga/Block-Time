import Foundation

public enum FlightTimePosition: String, CaseIterable, Sendable {
    case captain = "Capt"
    case firstOfficer = "F/O"
    case secondOfficer = "S/O"

    public var userDefaultsKey: String {
        return "flightTimePosition"
    }
}
