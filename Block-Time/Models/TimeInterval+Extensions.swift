//
//  TimeInterval+Extensions.swift
//  Block-Time
//
//  Created by Nelson on 12/2/2025.
//

import Foundation

extension TimeInterval {
    /// Converts TimeInterval (seconds) to decimal hours with standard rounding
    /// Matches the app's standard format of 2 decimal places (e.g., 4.53 hours)
    /// - Returns: Decimal hours as a Double, rounded to 2 decimal places
    var toDecimalHours: Double {
        let hours = self / 3600.0
        // Round to 2 decimal places for consistency with TimeCalculationManager
        return (hours * 100).rounded() / 100
    }

    /// Converts TimeInterval (seconds) to formatted decimal hours string
    /// Matches the app's standard format (e.g., "4.53")
    /// - Returns: Formatted string with 2 decimal places
    var toDecimalHoursString: String {
        return String(format: "%.2f", toDecimalHours)
    }
}

extension Double {
    /// Converts decimal hours to hours and minutes with standard rounding
    /// Uses proper rounding instead of truncation for consistency
    /// - Returns: Tuple of (hours: Int, minutes: Int)
    var toHoursAndMinutes: (hours: Int, minutes: Int) {
        let hours = Int(self)
        let fractionalPart = self - Double(hours)
        // Use rounded() instead of truncation for consistency
        let minutes = Int((fractionalPart * 60).rounded())
        return (hours: hours, minutes: minutes)
    }

    /// Converts decimal hours to formatted time string (e.g., "4:32")
    /// Uses proper rounding for minutes calculation
    /// - Returns: Formatted string in "H:MM" format
    var toHoursMinutesString: String {
        let (hours, minutes) = toHoursAndMinutes
        return String(format: "%d:%02d", hours, minutes)
    }

    /// Rounds decimal hours to 2 decimal places for consistency across the app
    /// - Returns: Decimal hours rounded to 2 decimal places
    var roundedToTwoDecimals: Double {
        return (self * 100).rounded() / 100
    }
}
