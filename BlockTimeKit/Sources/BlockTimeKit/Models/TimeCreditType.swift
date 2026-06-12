import Foundation

public enum TimeCreditType: String, CaseIterable, Codable, Sendable {
    case p1 = "P1"
    case p1us = "P1US"
    case p2 = "P2"

    public var displayName: String {
        switch self {
        case .p1:   return "P1"
        case .p1us: return "ICUS"
        case .p2:   return "P2"
        }
    }

    public var shortName: String {
        return self.rawValue
    }
}
