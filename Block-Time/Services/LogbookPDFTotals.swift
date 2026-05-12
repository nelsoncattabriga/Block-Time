//
//  LogbookPDFTotals.swift
//  Block-Time
//

import Foundation

// MARK: - Page Totals

struct PageTotals: Sendable {
    nonisolated init(
        block: Double = 0, night: Double = 0, p1: Double = 0, p1us: Double = 0,
        p2: Double = 0, instr: Double = 0, sim: Double = 0, spins: Double = 0
    ) {
        self.block = block; self.night = night; self.p1 = p1; self.p1us = p1us
        self.p2 = p2; self.instr = instr; self.sim = sim; self.spins = spins
    }

    var block: Double = 0
    var night: Double = 0
    var p1: Double = 0
    var p1us: Double = 0
    var p2: Double = 0
    var instr: Double = 0
    var sim: Double = 0
    var spins: Double = 0

    static nonisolated func + (lhs: PageTotals, rhs: PageTotals) -> PageTotals {
        PageTotals(
            block:  lhs.block  + rhs.block,
            night:  lhs.night  + rhs.night,
            p1:     lhs.p1     + rhs.p1,
            p1us:   lhs.p1us   + rhs.p1us,
            p2:     lhs.p2     + rhs.p2,
            instr:  lhs.instr  + rhs.instr,
            sim:    lhs.sim    + rhs.sim,
            spins:  lhs.spins  + rhs.spins
        )
    }

    nonisolated mutating func accumulate(_ flight: FlightSector) {
        block  += flight.blockTimeValue
        night  += flight.nightTimeValue
        p1     += flight.p1TimeValue
        p1us   += flight.p1usTimeValue
        p2     += flight.p2TimeValue
        instr  += flight.instrumentTimeValue
        sim    += flight.simTimeValue
        spins  += flight.spInsTimeValue
    }

    // Returns formatted string for a given column id, blank when zero.
    nonisolated func formattedValue(for columnId: Int) -> String {
        switch columnId {
        case 9:  return formatTime(block)
        case 10: return formatTime(night)
        case 11: return formatTime(p1)
        case 12: return formatTime(p1us)
        case 13: return formatTime(p2)
        case 14: return formatTime(instr)
        case 15: return formatTime(sim)
        case 16: return formatTime(spins)
        default: return ""
        }
    }

    nonisolated func formattedValue(for columnId: Int, useHHMM: Bool) -> String {
        guard useHHMM else { return formattedValue(for: columnId) }
        switch columnId {
        case 9:  return formatHHMM(block)
        case 10: return formatHHMM(night)
        case 11: return formatHHMM(p1)
        case 12: return formatHHMM(p1us)
        case 13: return formatHHMM(p2)
        case 14: return formatHHMM(instr)
        case 15: return formatHHMM(sim)
        case 16: return formatHHMM(spins)
        default: return ""
        }
    }

    private nonisolated func formatTime(_ v: Double) -> String {
        v > 0 ? String(format: "%.1f", v) : ""
    }

    private nonisolated func formatHHMM(_ v: Double) -> String {
        guard v > 0 else { return "" }
        let totalMinutes = Int((v * 60).rounded())
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    private nonisolated func formatInt(_ v: Int) -> String {
        v > 0 ? "\(v)" : ""
    }
}

// MARK: - Row Slot

enum RowSlot {
    case flight(FlightSector)
}

// MARK: - Pagination

enum LogbookPDFPaginator {

    // Builds ordered [RowSlot], filtering out positioning and unflown entries.
    static nonisolated func buildSlots(from flights: [FlightSector]) -> [RowSlot] {
        flights
            .filter { !$0.isPositioning && ($0.blockTimeValue > 0 || $0.simTimeValue > 0) }
            .map { .flight($0) }
    }

    // Splits slots into pages of maxDataSlotsPerPage.
    static nonisolated func paginate(_ slots: [RowSlot]) -> [[RowSlot]] {
        let max = LogbookPDFLayout.maxDataSlotsPerPage
        var pages: [[RowSlot]] = []
        var current: [RowSlot] = []

        for slot in slots {
            current.append(slot)
            if current.count == max {
                pages.append(current)
                current = []
            }
        }

        if !current.isEmpty {
            pages.append(current)
        }

        return pages
    }

    // Computes per-page totals and the running brought-forward for each page.
    // seed: career totals for flights prior to the rendered range (zero for full logbook).
    static nonisolated func computeTotals(pages: [[RowSlot]], seed: PageTotals = PageTotals()) -> [(page: PageTotals, broughtForward: PageTotals)] {
        var result: [(page: PageTotals, broughtForward: PageTotals)] = []
        var runningTotal = seed

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
