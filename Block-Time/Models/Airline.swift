//
//  Airline.swift
//  Block-Time
//
//  Created by Nelson on 11/10/2025.
//

import Foundation

struct Airline: Identifiable, Equatable {
    let id: String
    let name: String
    let prefix: String
    let iconName: String

    static let airlines: [Airline] = [
        Airline(id: "QF", name: "Qantas", prefix: "QF", iconName: "QF"),
//        Airline(id: "EK", name: "Emirates", prefix: "EK", iconName: "EK"),
//        Airline(id: "CX", name: "Cathay", prefix: "CX", iconName: "CX"),
//        Airline(id: "JQ", name: "Jetstar", prefix: "JQ", iconName: "JQ"),
        // Airline(id: "VA", name: "Virgin Australia", prefix: "VA", iconName: "VA"),
        Airline(id: "CUSTOM", name: "Custom", prefix: "", iconName: ""),
        
    ]

    static func getAirline(byPrefix prefix: String) -> Airline? {
        return airlines.first { $0.prefix == prefix }
    }

    static func getAirline(byId id: String) -> Airline? {
        return airlines.first { $0.id == id }
    }
}
