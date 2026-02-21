//
//  NewDashboardViewModel.swift
//  Block-Time
//
//  Data models for the Insights dashboard.
//  All analytics computations live in FlightDatabaseService+InsightsQueries.swift.
//

import Foundation
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
    var flightStatistics: FlightStatistics = .empty
    var isLoading = true

    func load() async {
        isLoading = true
        let data = FlightDatabaseService.shared.getInsightsData()
        monthlyActivity  = data.monthlyActivity
        fleetHours       = data.fleetHours
        monthlyRoles     = data.monthlyRoles
        pfRatioByMonth   = data.pfRatioByMonth
        monthlyNight     = data.monthlyNight
        topRoutes        = data.topRoutes
        topRegistrations = data.topRegistrations
        approachTypes    = data.approachTypes
        tlStats          = data.tlStats
        careerStats      = data.careerStats
        frmsStrip        = data.frmsStrip
        flightStatistics = data.flightStatistics
        isLoading = false
    }
}
