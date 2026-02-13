//
//  TimeCreditType.swift
//  Block-Time
//
//  Created by Nelson on 13/2/2025.
//

import Foundation

enum TimeCreditType: String, CaseIterable, Codable {
    case p1 = "P1"
    case p1us = "P1US"
    case p2 = "P2"

    var displayName: String {
        switch self {
        case .p1:
            return "P1 (CMD)"
        case .p1us:
            return "P1US (ICUS)"
        case .p2:
            return "P2 (CO-PLT)"
        }
    }

    var shortName: String {
        return self.rawValue
    }
}
