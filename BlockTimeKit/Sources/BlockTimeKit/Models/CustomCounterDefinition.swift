import Foundation

public enum CounterType: String, Codable, CaseIterable, Identifiable, Sendable {
    case time     // HH:MM via ModernDecimalTimeField
    case decimal  // decimal keyboard
    case integer  // integer keyboard
    case text     // free-form text, no totalling

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .integer: return "Integer"
        case .decimal: return "Decimal"
        case .time:    return "Time"
        case .text:    return "Text"
        }
    }

    public var subtitle: String {
        switch self {
        case .integer: return "Whole Numbers"
        case .decimal: return "Shown as 1.5"
        case .time:    return "Duration"
        case .text:    return "Any text value"
        }
    }
}

public struct CustomCounterDefinition: Codable, Identifiable, Hashable, Sendable {
    public let columnIndex: Int  // 1–10, permanent slot in FlightEntity.counter1…counter10
    public var label: String
    public var type: CounterType
    public var showTotal: Bool

    public var id: Int { columnIndex }

    public init(columnIndex: Int, label: String, type: CounterType, showTotal: Bool = true) {
        self.columnIndex = columnIndex
        self.label = label
        self.type = type
        self.showTotal = showTotal
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        columnIndex = try c.decode(Int.self, forKey: .columnIndex)
        label = try c.decode(String.self, forKey: .label)
        type = try c.decode(CounterType.self, forKey: .type)
        showTotal = try c.decodeIfPresent(Bool.self, forKey: .showTotal) ?? true
    }

    enum CodingKeys: String, CodingKey {
        case columnIndex, label, type, showTotal
    }
}
