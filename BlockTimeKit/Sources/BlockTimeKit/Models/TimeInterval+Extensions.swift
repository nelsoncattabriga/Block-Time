import Foundation

extension TimeInterval {
    public var toDecimalHours: Double {
        let hours = self / 3600.0
        return (hours * 100).rounded() / 100
    }

    public var toDecimalHoursString: String {
        return String(format: "%.2f", toDecimalHours)
    }
}

extension Double {
    public var toHoursAndMinutes: (hours: Int, minutes: Int) {
        let hours = Int(self)
        let fractionalPart = self - Double(hours)
        let minutes = Int((fractionalPart * 60).rounded())
        return (hours: hours, minutes: minutes)
    }

    public var toHoursMinutesString: String {
        let (hours, minutes) = toHoursAndMinutes
        return String(format: "%d:%02d", hours, minutes)
    }

    public var roundedToTwoDecimals: Double {
        return (self * 100).rounded() / 100
    }
}
