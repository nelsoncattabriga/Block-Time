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
        case .time:    return "Time (HH:MM)"
        case .decimal: return "Decimal"
        case .integer: return "Integer"
        }
    }
}

struct CustomCounterDefinition: Codable, Identifiable, Hashable {
    let id: UUID
    var label: String
    var type: CounterType
}
