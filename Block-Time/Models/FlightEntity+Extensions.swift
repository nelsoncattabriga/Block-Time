//
//  FlightEntity+Extensions.swift
//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//

import Foundation
import CoreData

extension FlightEntity {
    /// Safe access to remarks field
    var safeRemarks: String {
        get {
            return self.value(forKey: "remarks") as? String ?? ""
        }
        set {
            self.setValue(newValue, forKey: "remarks")
        }
    }
}
