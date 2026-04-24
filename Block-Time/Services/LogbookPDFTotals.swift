//
//  LogbookPDFTotals.swift
//  Block-Time
//

import Foundation

// MARK: - Page Totals

struct PageTotals: Sendable {
    nonisolated init(
        block: Double = 0, night: Double = 0, p1: Double = 0, p1us: Double = 0,
        p2: Double = 0, instr: Double = 0, sim: Double = 0, spins: Double = 0,
        dayTO: Int = 0, nightTO: Int = 0, dayLdg: Int = 0, nightLdg: Int = 0,
        ils: Int = 0, rnp: Int = 0, aiii: Int = 0, gls: Int = 0, npa: Int = 0
    ) {
        self.block = block; self.night = night; self.p1 = p1; self.p1us = p1us
        self.p2 = p2; self.instr = instr; self.sim = sim; self.spins = spins
        self.dayTO = dayTO; self.nightTO = nightTO; self.dayLdg = dayLdg; self.nightLdg = nightLdg
        self.ils = ils; self.rnp = rnp; self.aiii = aiii; self.gls = gls; self.npa = npa
    }

    var block: Double = 0
    var night: Double = 0
    var p1: Double = 0
    var p1us: Double = 0
    var p2: Double = 0
    var instr: Double = 0
    var sim: Double = 0
    var spins: Double = 0
    var dayTO: Int = 0
    var nightTO: Int = 0
    var dayLdg: Int = 0
    var nightLdg: Int = 0
    var ils: Int = 0
    var rnp: Int = 0
    var aiii: Int = 0
    var gls: Int = 0
    var npa: Int = 0

    static nonisolated func + (lhs: PageTotals, rhs: PageTotals) -> PageTotals {
        PageTotals(
            block:   lhs.block   + rhs.block,
            night:   lhs.night   + rhs.night,
            p1:      lhs.p1      + rhs.p1,
            p1us:    lhs.p1us    + rhs.p1us,
            p2:      lhs.p2      + rhs.p2,
            instr:   lhs.instr   + rhs.instr,
            sim:     lhs.sim     + rhs.sim,
            spins:   lhs.spins   + rhs.spins,
            dayTO:   lhs.dayTO   + rhs.dayTO,
            nightTO: lhs.nightTO + rhs.nightTO,
            dayLdg:  lhs.dayLdg  + rhs.dayLdg,
            nightLdg:lhs.nightLdg + rhs.nightLdg,
            ils:     lhs.ils     + rhs.ils,
            rnp:     lhs.rnp     + rhs.rnp,
            aiii:    lhs.aiii    + rhs.aiii,
            gls:     lhs.gls     + rhs.gls,
            npa:     lhs.npa     + rhs.npa
        )
    }

    nonisolated mutating func accumulate(_ flight: FlightSector) {
        block    += flight.blockTimeValue
        night    += flight.nightTimeValue
        p1       += flight.p1TimeValue
        p1us     += flight.p1usTimeValue
        p2       += flight.p2TimeValue
        instr    += flight.instrumentTimeValue
        sim      += flight.simTimeValue
        spins    += flight.spInsTimeValue
        dayTO    += flight.dayTakeoffs
        nightTO  += flight.nightTakeoffs
        dayLdg   += flight.dayLandings
        nightLdg += flight.nightLandings
        if flight.isILS  { ils  += 1 }
        if flight.isRNP  { rnp  += 1 }
        if flight.isAIII { aiii += 1 }
        if flight.isGLS  { gls  += 1 }
        if flight.isNPA  { npa  += 1 }
    }

    // Returns formatted string for a given column id, blank when zero.
    nonisolated func formattedValue(for columnId: Int) -> String {
        switch columnId {
        case 11: return formatTime(block)
        case 12: return formatTime(night)
        case 13: return formatTime(p1)
        case 14: return formatTime(p1us)
        case 15: return formatTime(p2)
        case 16: return formatTime(instr)
        case 17: return formatTime(sim)
        case 18: return formatTime(spins)
        case 19: return formatInt(dayTO)
        case 20: return formatInt(nightTO)
        case 21: return formatInt(dayLdg)
        case 22: return formatInt(nightLdg)
        case 23: return formatInt(ils)
        case 24: return formatInt(rnp)
        case 25: return formatInt(aiii)
        case 26: return formatInt(gls)
        case 27: return formatInt(npa)
        default: return ""
        }
    }

    private nonisolated func formatTime(_ v: Double) -> String {
        v > 0 ? String(format: "%.1f", v) : ""
    }

    private nonisolated func formatInt(_ v: Int) -> String {
        v > 0 ? "\(v)" : ""
    }
}

// MARK: - Row Slot

enum RowSlot {
    case monthBand(String)          // "APRIL 2026"
    case flight(FlightSector)
}

// MARK: - Pagination

enum LogbookPDFPaginator {

    private static nonisolated let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    private static nonisolated let mf: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    private static nonisolated func monthYear(from dateString: String) -> String {
        guard let d = df.date(from: dateString) else { return "" }
        return mf.string(from: d).uppercased()
    }

    // Builds ordered [RowSlot] with month bands inserted, skipping positioning flights.
    static nonisolated func buildSlots(from flights: [FlightSector]) -> [RowSlot] {
        // Filter out positioning flights and future/unflown entries
        let logbookFlights = flights.filter { !$0.isPositioning && ($0.blockTimeValue > 0 || $0.simTimeValue > 0) }

        var slots: [RowSlot] = []
        var currentMonth = ""

        for flight in logbookFlights {
            let month = monthYear(from: flight.date)
            if month != currentMonth {
                slots.append(.monthBand(month))
                currentMonth = month
            }
            slots.append(.flight(flight))
        }
        return slots
    }

    // Splits slots into pages of maxDataSlotsPerPage, preventing orphaned month bands.
    static nonisolated func paginate(_ slots: [RowSlot]) -> [[RowSlot]] {
        let max = LogbookPDFLayout.maxDataSlotsPerPage
        var pages: [[RowSlot]] = []
        var current: [RowSlot] = []

        for (_, slot) in slots.enumerated() {
            // Orphan guard: if this band would be the last slot on the current page, push to next page.
            if case .monthBand = slot {
                let remainingOnPage = max - current.count
                if remainingOnPage == 1 {
                    pages.append(current)
                    current = [slot]
                    continue
                }
            }

            current.append(slot)

            if current.count == max {
                pages.append(current)
                current = []
                // If the next slot is a month band, carry it to the new page naturally
                // (it will be appended in the next iteration).
            }
        }

        if !current.isEmpty {
            pages.append(current)
        }

        return pages
    }

    // Computes per-page totals and the running brought-forward for each page.
    static nonisolated func computeTotals(pages: [[RowSlot]]) -> [(page: PageTotals, broughtForward: PageTotals)] {
        var result: [(page: PageTotals, broughtForward: PageTotals)] = []
        var runningTotal = PageTotals()

        for page in pages {
            let bf = runningTotal
            var pageTotals = PageTotals()
            for slot in page {
                if case .flight(let f) = slot {
                    pageTotals.accumulate(f)
                }
            }
            result.append((page: pageTotals, broughtForward: bf))
            runningTotal = runningTotal + pageTotals
        }

        return result
    }
}
