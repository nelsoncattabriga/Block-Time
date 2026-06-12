import Foundation

public struct Airline: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let prefix: String
    public let iconName: String

    public init(id: String, name: String, prefix: String, iconName: String) {
        self.id = id
        self.name = name
        self.prefix = prefix
        self.iconName = iconName
    }

    public static let airlines: [Airline] = [
        Airline(id: "QF", name: "Qantas", prefix: "QF", iconName: "QF"),
//        Airline(id: "EK", name: "Emirates", prefix: "EK", iconName: "EK"),
//        Airline(id: "CX", name: "Cathay", prefix: "CX", iconName: "CX"),
//        Airline(id: "JQ", name: "Jetstar", prefix: "JQ", iconName: "JQ"),
        // Airline(id: "VA", name: "Virgin Australia", prefix: "VA", iconName: "VA"),
        Airline(id: "CUSTOM", name: "Custom", prefix: "", iconName: ""),
    ]

    public static func getAirline(byPrefix prefix: String) -> Airline? {
        return airlines.first { $0.prefix == prefix }
    }

    public static func getAirline(byId id: String) -> Airline? {
        return airlines.first { $0.id == id }
    }
}
