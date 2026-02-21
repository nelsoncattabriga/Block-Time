//
//  FlightDatabaseService+InsightsQueries.swift
//  Block-Time
//
//  Consolidated analytics computations for the Insights dashboard.
//  Single source of truth — all ND* analytics flow through here.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Aggregate insights payload

struct NDInsightsData {
    let flightStatistics: FlightStatistics
    let monthlyActivity: [NDMonthlyActivity]
    let fleetHours: [NDFleetHours]
    let monthlyRoles: [NDMonthlyRoleHours]
    let pfRatioByMonth: [NDMonthlyPFRatio]
    let monthlyNight: [NDMonthlyNight]
    let topRoutes: [NDRouteFrequency]
    let topRegistrations: [NDRegistrationHours]
    let approachTypes: [NDApproachTypeStat]
    let tlStats: NDTakeoffLandingStats
    let careerStats: NDCareerStats
    let frmsStrip: NDFRMSStripData
}

// MARK: - Extension

extension FlightDatabaseService {

    /// Returns all analytics for the Insights dashboard.
    /// Calls the proven `getFlightStatistics()` for aggregate totals, then
    /// performs one additional Core Data fetch for analytics computations.
    func getInsightsData() -> NDInsightsData {
        let stats = getFlightStatistics()

        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)",
            "0", "0.0", "0.00", "0", "0.0", "0.00"
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let flights: [FlightEntity]
        do {
            flights = try viewContext.fetch(request)
        } catch {
            return NDInsightsData(
                flightStatistics: stats,
                monthlyActivity: [],
                fleetHours: [],
                monthlyRoles: [],
                pfRatioByMonth: [],
                monthlyNight: [],
                topRoutes: [],
                topRegistrations: [],
                approachTypes: [],
                tlStats: .empty,
                careerStats: .empty,
                frmsStrip: .empty
            )
        }

        return NDInsightsData(
            flightStatistics: stats,
            monthlyActivity: computeMonthlyActivity(flights),
            fleetHours: computeFleetHours(flights),
            monthlyRoles: computeMonthlyRoles(flights),
            pfRatioByMonth: computePFRatioByMonth(flights),
            monthlyNight: computeMonthlyNight(flights),
            topRoutes: computeTopRoutes(flights),
            topRegistrations: computeTopRegistrations(flights),
            approachTypes: computeApproachTypes(flights),
            tlStats: computeTLStats(flights),
            careerStats: computeCareerStats(flights),
            frmsStrip: computeFRMSStrip(flights)
        )
    }

    // MARK: - Private helpers

    private func hrs(_ s: String?) -> Double { Double(s ?? "0") ?? 0 }

    private func monthStart(for date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    // MARK: - Compute methods

    private func computeMonthlyActivity(_ flights: [FlightEntity]) -> [NDMonthlyActivity] {
        var block: [Date: Double] = [:]
        var sim: [Date: Double] = [:]
        var night: [Date: Double] = [:]

        for f in flights {
            guard let date = f.date else { continue }
            let m = monthStart(for: date)
            block[m, default: 0] += hrs(f.blockTime)
            sim[m, default: 0]   += hrs(f.simTime)
            night[m, default: 0] += hrs(f.nightTime)
        }

        let months = Set(block.keys).union(sim.keys).union(night.keys)
        return months.sorted().map {
            NDMonthlyActivity(month: $0, blockHours: block[$0] ?? 0, simHours: sim[$0] ?? 0, nightHours: night[$0] ?? 0)
        }
    }

    private func computeFleetHours(_ flights: [FlightEntity]) -> [NDFleetHours] {
        var hours: [String: Double] = [:]
        var sectors: [String: Int] = [:]

        for f in flights {
            let t = f.aircraftType ?? ""
            guard !t.isEmpty else { continue }
            hours[t, default: 0]   += hrs(f.blockTime)
            sectors[t, default: 0] += 1
        }

        return hours.map { NDFleetHours(aircraftType: $0.key, hours: $0.value, sectors: sectors[$0.key] ?? 0) }
            .sorted { $0.hours > $1.hours }
    }

    private func computeMonthlyRoles(_ flights: [FlightEntity]) -> [NDMonthlyRoleHours] {
        var p1: [Date: Double] = [:]
        var p1us: [Date: Double] = [:]
        var p2: [Date: Double] = [:]

        for f in flights {
            guard let date = f.date else { continue }
            let m = monthStart(for: date)
            p1[m, default: 0]   += hrs(f.p1Time)
            p1us[m, default: 0] += hrs(f.p1usTime)
            p2[m, default: 0]   += hrs(f.p2Time)
        }

        var result: [NDMonthlyRoleHours] = []
        let months = Set(p1.keys).union(p1us.keys).union(p2.keys)
        for m in months.sorted() {
            if let h = p1[m],   h > 0.01 { result.append(NDMonthlyRoleHours(month: m, role: "Captain", hours: h)) }
            if let h = p1us[m], h > 0.01 { result.append(NDMonthlyRoleHours(month: m, role: "ICUS",    hours: h)) }
            if let h = p2[m],   h > 0.01 { result.append(NDMonthlyRoleHours(month: m, role: "F/O",     hours: h)) }
        }
        return result
    }

    private func computePFRatioByMonth(_ flights: [FlightEntity]) -> [NDMonthlyPFRatio] {
        var pf: [Date: Int] = [:]
        var total: [Date: Int] = [:]

        for f in flights {
            guard let date = f.date else { continue }
            let m = monthStart(for: date)
            total[m, default: 0] += 1
            if f.isPilotFlying { pf[m, default: 0] += 1 }
        }

        return total.keys.sorted().map { m in
            NDMonthlyPFRatio(
                month: m,
                pfRatio: Double(pf[m] ?? 0) / Double(total[m] ?? 1),
                totalSectors: total[m] ?? 0
            )
        }
    }

    private func computeMonthlyNight(_ flights: [FlightEntity]) -> [NDMonthlyNight] {
        var night: [Date: Double] = [:]
        for f in flights {
            guard let date = f.date else { continue }
            night[monthStart(for: date), default: 0] += hrs(f.nightTime)
        }
        return night.keys.sorted().map { NDMonthlyNight(month: $0, nightHours: night[$0] ?? 0) }
    }

    private func computeTopRoutes(_ flights: [FlightEntity]) -> [NDRouteFrequency] {
        var counts: [String: (from: String, to: String, n: Int)] = [:]
        for f in flights {
            let from = f.fromAirport ?? ""; let to = f.toAirport ?? ""
            guard !from.isEmpty, !to.isEmpty else { continue }
            let key = "\(from)-\(to)"
            counts[key] = (from, to, (counts[key]?.n ?? 0) + 1)
        }
        return counts.values.sorted { $0.n > $1.n }.prefix(10)
            .map { NDRouteFrequency(from: $0.from, to: $0.to, sectors: $0.n) }
    }

    private func computeTopRegistrations(_ flights: [FlightEntity]) -> [NDRegistrationHours] {
        var data: [String: (reg: String, type: String, hours: Double, sectors: Int)] = [:]
        for f in flights {
            let reg = f.aircraftReg ?? ""; guard !reg.isEmpty else { continue }
            let current = data[reg]
            data[reg] = (reg, f.aircraftType ?? "", (current?.hours ?? 0) + hrs(f.blockTime), (current?.sectors ?? 0) + 1)
        }
        return data.values.sorted { $0.hours > $1.hours }.prefix(10)
            .map { NDRegistrationHours(registration: $0.reg, aircraftType: $0.type, hours: $0.hours, sectors: $0.sectors) }
    }

    private func computeApproachTypes(_ flights: [FlightEntity]) -> [NDApproachTypeStat] {
        var aiii = 0, ils = 0, rnp = 0, gls = 0, npa = 0, total = 0
        for f in flights {
            guard (f.dayLandings + f.nightLandings) > 0 else { continue }
            total += 1
            if f.isAIII { aiii += 1 }
            if f.isILS  { ils  += 1 }
            if f.isRNP  { rnp  += 1 }
            if f.isGLS  { gls  += 1 }
            if f.isNPA  { npa  += 1 }
        }
        guard total > 0 else { return [] }

        let d = Double(total)
        let raw: [(String, Int, Color)] = [
            ("AIII", aiii, .blue),
            ("ILS",  ils,  .green),
            ("RNP",  rnp,  .orange),
            ("GLS",  gls,  .purple),
            ("NPA",  npa,  .red)
        ]
        return raw.filter { $0.1 > 0 }
            .map { NDApproachTypeStat(typeName: $0.0, count: $0.1, percentage: Double($0.1) / d * 100, color: $0.2) }
            .sorted { $0.count > $1.count }
    }

    private func computeTLStats(_ flights: [FlightEntity]) -> NDTakeoffLandingStats {
        var dTO = 0, nTO = 0, dLDG = 0, nLDG = 0
        for f in flights {
            dTO  += Int(f.dayTakeoffs);  nTO  += Int(f.nightTakeoffs)
            dLDG += Int(f.dayLandings);  nLDG += Int(f.nightLandings)
        }
        return NDTakeoffLandingStats(dayTakeoffs: dTO, nightTakeoffs: nTO, dayLandings: dLDG, nightLandings: nLDG)
    }

    private func computeCareerStats(_ flights: [FlightEntity]) -> NDCareerStats {
        let block = flights.reduce(0.0) { $0 + hrs($1.blockTime) }
        let sim   = flights.reduce(0.0) { $0 + hrs($1.simTime) }
        return NDCareerStats(
            totalHours: block + sim,
            totalSectors: flights.count,
            firstFlightDate: flights.compactMap { $0.date }.min()
        )
    }

    private func computeFRMSStrip(_ flights: [FlightEntity]) -> NDFRMSStripData {
        let cal = Calendar.current
        let now = Date()
        guard let ago7   = cal.date(byAdding: .day, value: -7,   to: now),
              let ago28  = cal.date(byAdding: .day, value: -28,  to: now),
              let ago365 = cal.date(byAdding: .day, value: -365, to: now) else { return .empty }

        var h7 = 0.0, h28 = 0.0, h365 = 0.0
        for f in flights {
            guard let date = f.date else { continue }
            let total = hrs(f.blockTime) + hrs(f.simTime)
            if date >= ago7   { h7   += total }
            if date >= ago28  { h28  += total }
            if date >= ago365 { h365 += total }
        }

        let fleet: FRMSFleet
        if let data   = UserDefaults.standard.data(forKey: "FRMSConfiguration"),
           let config = try? JSONDecoder().decode(FRMSConfiguration.self, from: data) {
            fleet = config.fleet
        } else {
            fleet = .a320B737
        }

        return NDFRMSStripData(hours7d: h7, hours28d: h28, hours365d: h365, fleet: fleet)
    }
}
