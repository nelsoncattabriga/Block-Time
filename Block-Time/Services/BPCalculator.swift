// Ported from RosterTools. Epoch arithmetic is specific to this airline's BP numbering scheme.
import Foundation

struct BPCalculator {

    /// Returns the start and end dates for a given BP number.
    /// 3-digit BP = LH (56-day period). 4-digit BP = SH (28-day period).
    static func bpDates(bp: Int) -> (startDate: Date, endDate: Date)? {
        let calendar = Calendar.current
        let bpString = String(abs(bp))

        switch bpString.count {
        case 4:
            guard let lastDigit = bpString.last else { return nil }
            let epochBP: Int
            let epochDate: Date
            if lastDigit == "1" {
                epochBP = 11
                epochDate = calendar.date(from: DateComponents(year: 1969, month: 1, day: 13))!
            } else {
                epochBP = 15
                epochDate = calendar.date(from: DateComponents(year: 1969, month: 2, day: 10))!
            }
            let diffBP = (bp - epochBP) / 5
            guard let startDate = calendar.date(byAdding: .day, value: 28 * diffBP, to: epochDate),
                  let endDate = calendar.date(byAdding: .day, value: 27, to: startDate) else { return nil }
            return (startDate, endDate)

        case 3:
            let epochDate = calendar.date(from: DateComponents(year: 1969, month: 1, day: 13))!
            let diffBP = bp - 1
            guard let startDate = calendar.date(byAdding: .day, value: 56 * diffBP, to: epochDate),
                  let endDate = calendar.date(byAdding: .day, value: 55, to: startDate) else { return nil }
            return (startDate, endDate)

        default:
            return nil
        }
    }

    /// Returns BP info for the roster period containing `date` for the given fleet type.
    static func rosterPeriod(containing date: Date, isShortHaul: Bool) -> (bp: String, startDate: Date, endDate: Date)? {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let lhEpochDate = calendar.date(from: DateComponents(year: 1969, month: 1, day: 13))!

        let daysFromEpoch = calendar.dateComponents([.day], from: lhEpochDate, to: normalizedDate).day ?? 0
        let lhBPNumber = 1 + (daysFromEpoch / 56)

        if isShortHaul {
            guard let lhDates = bpDates(bp: lhBPNumber) else { return nil }
            let lhStart = calendar.startOfDay(for: lhDates.startDate)
            let daysIntoLH = calendar.dateComponents([.day], from: lhStart, to: normalizedDate).day ?? 0
            let shSuffix = daysIntoLH < 28 ? 1 : 5
            let shBPNumber = (lhBPNumber * 10) + shSuffix
            guard let shDates = bpDates(bp: shBPNumber) else { return nil }
            return ("\(shBPNumber)", shDates.startDate, shDates.endDate)
        } else {
            guard let lhDates = bpDates(bp: lhBPNumber) else { return nil }
            return ("\(lhBPNumber)", lhDates.startDate, lhDates.endDate)
        }
    }
}
