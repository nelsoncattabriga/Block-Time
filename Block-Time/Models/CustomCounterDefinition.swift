//
//  CustomCounterDefinition.swift
//  Block-Time
//
//  Model types for user-defined custom flight counters.
//

import Foundation

enum CounterType: String, Codable, CaseIterable, Identifiable {
    case time     // HH:MM via ModernDecimalTimeField
    case decimal  // decimal keyboard
    case integer  // integer keyboard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .integer: return "Count"
        case .decimal: return "Decimal"
        case .time:    return "Time"
        }
    }

    var subtitle: String {
        switch self {
        case .integer: return "Whole numbers, e.g. PAX, approaches."
        case .decimal: return "Decimal numbers, e.g. fuel, distance. Shown as 1.5"
        case .time:    return "Duration, e.g. Dual Time. Shown as 1:30 or 1.5"
        }
    }
}

struct CustomCounterDefinition: Codable, Identifiable, Hashable {
    let columnIndex: Int  // 1–10, permanent slot in FlightEntity.counter1…counter10
    var label: String
    var type: CounterType
    var showTotal: Bool

    var id: Int { columnIndex }

    init(columnIndex: Int, label: String, type: CounterType, showTotal: Bool = true) {
        self.columnIndex = columnIndex
        self.label = label
        self.type = type
        self.showTotal = showTotal
    }

    init(from decoder: Decoder) throws {
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
