//
//  FlightTimePosition.swift
//  Block-Time
//
//  Created by Nelson on 3/9/2025.
//

import Foundation

enum FlightTimePosition: String, CaseIterable {
    case captain = "Capt"
    case firstOfficer = "F/O"
    case secondOfficer = "S/O"

    var userDefaultsKey: String {
        return "flightTimePosition"
    }
}
