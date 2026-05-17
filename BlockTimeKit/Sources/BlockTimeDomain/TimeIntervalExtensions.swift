import Foundation

public extension TimeInterval {
    /// Converts TimeInterval (seconds) to decimal hours rounded to 2dp.
    /// Mirrors Block-Time/Models/TimeInterval+Extensions.swift (kept identical to avoid drift).
    var toDecimalHours: Double {
        let hours = self / 3600.0
        return (hours * 100).rounded() / 100
    }
}
