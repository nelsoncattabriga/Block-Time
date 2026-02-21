//
//  NewDashboardViewModel.swift
//  Block-Time
//
//  Data models and ViewModel for the new Insights dashboard.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Data Models

struct NDMonthlyActivity: Identifiable {
    let id = UUID()
    let month: Date
    let blockHours: Double
    let simHours: Double
    let nightHours: Double
    var totalHours: Double { blockHours + simHours }
}

struct NDMonthlyRoleHours: Identifiable {
    let id = UUID()
    let month: Date
    let role: String
    let hours: Double
}

struct NDMonthlyPFRatio: Identifiable {
    let id = UUID()
    let month: Date
    let pfRatio: Double        // 0.0 – 1.0
    let totalSectors: Int
}

struct NDMonthlyNight: Identifiable {
    let id = UUID()
    let month: Date
    let nightHours: Double
}

struct NDFleetHours: Identifiable {
    let id = UUID()
    let aircraftType: String
    let hours: Double
    let sectors: Int
}

struct NDRouteFrequency: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let sectors: Int
    var routeString: String { "\(from) → \(to)" }
}

struct NDRegistrationHours: Identifiable {
    let id = UUID()
    let registration: String
    let aircraftType: String
    let hours: Double
    let sectors: Int
}

struct NDApproachTypeStat: Identifiable {
    let id = UUID()
    let typeName: String
    let count: Int
    let percentage: Double
    let color: Color
}

struct NDTakeoffLandingStats {
    let dayTakeoffs: Int
    let nightTakeoffs: Int
    let dayLandings: Int
    let nightLandings: Int

    var totalTakeoffs: Int { dayTakeoffs + nightTakeoffs }
    var totalLandings: Int { dayLandings + nightLandings }
    var nightTakeoffPct: Double { totalTakeoffs > 0 ? Double(nightTakeoffs) / Double(totalTakeoffs) : 0 }
    var nightLandingPct: Double { totalLandings > 0 ? Double(nightLandings) / Double(totalLandings) : 0 }

    static let empty = NDTakeoffLandingStats(dayTakeoffs: 0, nightTakeoffs: 0, dayLandings: 0, nightLandings: 0)
}

struct NDCareerStats {
    let totalHours: Double
    let totalSectors: Int
    let firstFlightDate: Date?

    static let empty = NDCareerStats(totalHours: 0, totalSectors: 0, firstFlightDate: nil)

    var yearsOfData: Double {
        guard let first = firstFlightDate else { return 0 }
        return Date().timeIntervalSince(first) / (365.25 * 24 * 3600)
    }

    static let milestones: [Double] = [500, 1000, 2500, 5000, 10000, 20000]

    var nextMilestone: Double? { NDCareerStats.milestones.first { $0 > totalHours } }
    var previousMilestone: Double { NDCareerStats.milestones.filter { $0 <= totalHours }.last ?? 0 }

    var milestoneProgress: Double {
        guard let next = nextMilestone else { return 1.0 }
        let range = next - previousMilestone
        guard range > 0 else { return 1.0 }
        return (totalHours - previousMilestone) / range
    }
}

struct NDFRMSStripData {
    let hours7d: Double
    let hours28d: Double
    let hours365d: Double
    let fleet: FRMSFleet

    var max7d: Double? { fleet.maxFlightTime7Days }
    var max28d: Double { fleet.maxFlightTime28Days }
    var max365d: Double { fleet.maxFlightTime365Days }
    var periodDays: Int { fleet.flightTimePeriodDays }

    func ratio(hours: Double, max: Double) -> Double { min(hours / max, 1.0) }

    func limitColor(hours: Double, max: Double) -> Color {
        let r = ratio(hours: hours, max: max)
        if r >= 0.9 { return .red }
        if r >= 0.8 { return .orange }
        return .green
    }

    static let empty = NDFRMSStripData(hours7d: 0, hours28d: 0, hours365d: 0, fleet: .a320B737)
}

// MARK: - ViewModel

@Observable
@MainActor
final class NewDashboardViewModel {

    var monthlyActivity: [NDMonthlyActivity] = []
    var fleetHours: [NDFleetHours] = []
    var monthlyRoles: [NDMonthlyRoleHours] = []
    var pfRatioByMonth: [NDMonthlyPFRatio] = []
    var monthlyNight: [NDMonthlyNight] = []
    var topRoutes: [NDRouteFrequency] = []
    var topRegistrations: [NDRegistrationHours] = []
    var approachTypes: [NDApproachTypeStat] = []
    var tlStats: NDTakeoffLandingStats = .empty
    var careerStats: NDCareerStats = .empty
    var frmsStrip: NDFRMSStripData = .empty
    var isLoading = true

    private var allFlights: [FlightEntity] = []

    func load() async {
        isLoading = true

        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)",
            "0", "0.0", "0.00", "0", "0.0", "0.00"
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        do {
            allFlights = try FlightDatabaseService.shared.viewContext.fetch(request)
        } catch {
            isLoading = false
            return
        }

        computeMonthlyActivity()
        computeFleetHours()
        computeMonthlyRoles()
        computePFRatioByMonth()
        computeMonthlyNight()
        computeTopRoutes()
        computeTopRegistrations()
        computeApproachTypes()
        computeTLStats()
        computeCareerStats()
        computeFRMSStrip()

        isLoading = false
    }

    // MARK: - Private Computations

    private func monthStart(for date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private func toDouble(_ s: String?) -> Double { Double(s ?? "0") ?? 0 }

    private func computeMonthlyActivity() {
        var block: [Date: Double] = [:]
        var sim: [Date: Double] = [:]
        var night: [Date: Double] = [:]

        for f in allFlights {
            guard let date = f.date else { continue }
            let m = monthStart(for: date)
            block[m, default: 0] += toDouble(f.blockTime)
            sim[m, default: 0]   += toDouble(f.simTime)
            night[m, default: 0] += toDouble(f.nightTime)
        }

        let months = Set(block.keys).union(sim.keys).union(night.keys)
        monthlyActivity = months.sorted().map {
            NDMonthlyActivity(month: $0, blockHours: block[$0] ?? 0, simHours: sim[$0] ?? 0, nightHours: night[$0] ?? 0)
        }
    }

    private func computeFleetHours() {
        var hours: [String: Double] = [:]
        var sectors: [String: Int] = [:]

        for f in allFlights {
            let t = f.aircraftType ?? ""
            guard !t.isEmpty else { continue }
            hours[t, default: 0]   += toDouble(f.blockTime)
            sectors[t, default: 0] += 1
        }

        fleetHours = hours.map { NDFleetHours(aircraftType: $0.key, hours: $0.value, sectors: sectors[$0.key] ?? 0) }
            .sorted { $0.hours > $1.hours }
    }

    private func computeMonthlyRoles() {
        var p1: [Date: Double] = [:]
        var p1us: [Date: Double] = [:]
        var p2: [Date: Double] = [:]

        for f in allFlights {
            guard let date = f.date else { continue }
            let m = monthStart(for: date)
            p1[m, default: 0]   += toDouble(f.p1Time)
            p1us[m, default: 0] += toDouble(f.p1usTime)
            p2[m, default: 0]   += toDouble(f.p2Time)
        }

        var result: [NDMonthlyRoleHours] = []
        let months = Set(p1.keys).union(p1us.keys).union(p2.keys)
        for m in months.sorted() {
            if let h = p1[m],   h > 0.01 { result.append(NDMonthlyRoleHours(month: m, role: "Captain", hours: h)) }
            if let h = p1us[m], h > 0.01 { result.append(NDMonthlyRoleHours(month: m, role: "ICUS",    hours: h)) }
            if let h = p2[m],   h > 0.01 { result.append(NDMonthlyRoleHours(month: m, role: "F/O",     hours: h)) }
        }
        monthlyRoles = result
    }

    private func computePFRatioByMonth() {
        var pf: [Date: Int] = [:]
        var total: [Date: Int] = [:]

        for f in allFlights {
            guard let date = f.date else { continue }
            let m = monthStart(for: date)
            total[m, default: 0] += 1
            if f.isPilotFlying { pf[m, default: 0] += 1 }
        }

        pfRatioByMonth = total.keys.sorted().map { m in
            NDMonthlyPFRatio(
                month: m,
                pfRatio: Double(pf[m] ?? 0) / Double(total[m] ?? 1),
                totalSectors: total[m] ?? 0
            )
        }
    }

    private func computeMonthlyNight() {
        var night: [Date: Double] = [:]

        for f in allFlights {
            guard let date = f.date else { continue }
            night[monthStart(for: date), default: 0] += toDouble(f.nightTime)
        }

        monthlyNight = night.keys.sorted().map { NDMonthlyNight(month: $0, nightHours: night[$0] ?? 0) }
    }

    private func computeTopRoutes() {
        var counts: [String: (from: String, to: String, n: Int)] = [:]

        for f in allFlights {
            let from = f.fromAirport ?? ""; let to = f.toAirport ?? ""
            guard !from.isEmpty, !to.isEmpty else { continue }
            let key = "\(from)-\(to)"
            counts[key] = (from, to, (counts[key]?.n ?? 0) + 1)
        }

        topRoutes = counts.values.sorted { $0.n > $1.n }.prefix(10)
            .map { NDRouteFrequency(from: $0.from, to: $0.to, sectors: $0.n) }
    }

    private func computeTopRegistrations() {
        var data: [String: (reg: String, type: String, hours: Double, sectors: Int)] = [:]

        for f in allFlights {
            let reg = f.aircraftReg ?? ""; guard !reg.isEmpty else { continue }
            let current = data[reg]
            data[reg] = (reg, f.aircraftType ?? "", (current?.hours ?? 0) + toDouble(f.blockTime), (current?.sectors ?? 0) + 1)
        }

        topRegistrations = data.values.sorted { $0.hours > $1.hours }.prefix(10)
            .map { NDRegistrationHours(registration: $0.reg, aircraftType: $0.type, hours: $0.hours, sectors: $0.sectors) }
    }

    private func computeApproachTypes() {
        var aiii = 0, ils = 0, rnp = 0, gls = 0, npa = 0, total = 0

        for f in allFlights {
            guard (f.dayLandings + f.nightLandings) > 0 else { continue }
            total += 1
            if f.isAIII { aiii += 1 }
            if f.isILS  { ils  += 1 }
            if f.isRNP  { rnp  += 1 }
            if f.isGLS  { gls  += 1 }
            if f.isNPA  { npa  += 1 }
        }

        guard total > 0 else { approachTypes = []; return }

        let d = Double(total)
        let raw: [(String, Int, Color)] = [
            ("AIII", aiii, .blue),
            ("ILS",  ils,  .green),
            ("RNP",  rnp,  .orange),
            ("GLS",  gls,  .purple),
            ("NPA",  npa,  .red)
        ]
        approachTypes = raw.filter { $0.1 > 0 }
            .map { NDApproachTypeStat(typeName: $0.0, count: $0.1, percentage: Double($0.1) / d * 100, color: $0.2) }
            .sorted { $0.count > $1.count }
    }

    private func computeTLStats() {
        var dTO = 0, nTO = 0, dLDG = 0, nLDG = 0
        for f in allFlights {
            dTO  += Int(f.dayTakeoffs);  nTO  += Int(f.nightTakeoffs)
            dLDG += Int(f.dayLandings);  nLDG += Int(f.nightLandings)
        }
        tlStats = NDTakeoffLandingStats(dayTakeoffs: dTO, nightTakeoffs: nTO, dayLandings: dLDG, nightLandings: nLDG)
    }

    private func computeCareerStats() {
        let block = allFlights.reduce(0.0) { $0 + toDouble($1.blockTime) }
        let sim   = allFlights.reduce(0.0) { $0 + toDouble($1.simTime) }
        careerStats = NDCareerStats(
            totalHours: block + sim,
            totalSectors: allFlights.count,
            firstFlightDate: allFlights.compactMap { $0.date }.min()
        )
    }

    private func computeFRMSStrip() {
        let cal = Calendar.current
        let now = Date()
        guard let ago7   = cal.date(byAdding: .day, value: -7,   to: now),
              let ago28  = cal.date(byAdding: .day, value: -28,  to: now),
              let ago365 = cal.date(byAdding: .day, value: -365, to: now) else { return }

        var h7 = 0.0, h28 = 0.0, h365 = 0.0
        for f in allFlights {
            guard let date = f.date else { continue }
            let hrs = toDouble(f.blockTime) + toDouble(f.simTime)
            if date >= ago7   { h7   += hrs }
            if date >= ago28  { h28  += hrs }
            if date >= ago365 { h365 += hrs }
        }

        let fleet: FRMSFleet
        if let data   = UserDefaults.standard.data(forKey: "FRMSConfiguration"),
           let config = try? JSONDecoder().decode(FRMSConfiguration.self, from: data) {
            fleet = config.fleet
        } else {
            fleet = .a320B737
        }

        frmsStrip = NDFRMSStripData(hours7d: h7, hours28d: h28, hours365d: h365, fleet: fleet)
    }
}
