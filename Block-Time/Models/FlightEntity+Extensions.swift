//
//  FlightEntity+Extensions.swift
//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//

import Foundation
import CoreData
import BlockTimeKit

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

    /// Read counter value for a given column index (1–10).
    func counterValue(at index: Int) -> String? {
        switch index {
        case 1:  return counter1
        case 2:  return counter2
        case 3:  return counter3
        case 4:  return counter4
        case 5:  return counter5
        case 6:  return counter6
        case 7:  return counter7
        case 8:  return counter8
        case 9:  return counter9
        case 10: return counter10
        default: return nil
        }
    }

    /// Write counter value for a given column index (1–10). Pass nil to clear.
    func setCounter(_ index: Int, value: String?) {
        switch index {
        case 1:  counter1  = value
        case 2:  counter2  = value
        case 3:  counter3  = value
        case 4:  counter4  = value
        case 5:  counter5  = value
        case 6:  counter6  = value
        case 7:  counter7  = value
        case 8:  counter8  = value
        case 9:  counter9  = value
        case 10: counter10 = value
        default: break
        }
    }
}
