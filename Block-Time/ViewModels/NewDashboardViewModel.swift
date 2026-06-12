//
//  NewDashboardViewModel.swift
//  Block-Time
//
//  Data models for the Insights dashboard.
//  All analytics computations live in FlightDatabaseService+InsightsQueries.swift.
//

import Foundation
import SwiftUI
import BlockTimeKit

// MARK: - Data Models

struct NDMonthlyActivity: Identifiable {
    let id = UUID()
    let month: Date
    let blockHours: Double
    let simHours: Double
    let nightHours: Double
    let sectorCount: Int
    var totalHours: Double { blockHours + simHours }
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

struct NDDailyActivity: Identifiable {
    let id = UUID()
    let day: Date           // start of day (midnight)
    let blockHours: Double
    let simHours: Double
    var totalHours: Double { blockHours + simHours }
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
    let totalBlockHours: Double
    let totalSIMHours: Double
    let totalSectors: Int
    let totalAircraftTypes: Int
    let totalAirports: Int
    let firstFlightDate: Date?

    /// Combined block + SIM — used internally and for backwards compatibility
    var totalHours: Double { totalBlockHours + totalSIMHours }

    func totalHours(includeSim: Bool) -> Double {
        includeSim ? totalBlockHours + totalSIMHours : totalBlockHours
    }

    static let empty = NDCareerStats(totalBlockHours: 0, totalSIMHours: 0, totalSectors: 0, totalAircraftTypes: 0, totalAirports: 0, firstFlightDate: nil)

    var yearsOfData: Double {
        guard let first = firstFlightDate else { return 0 }
        return Date().timeIntervalSince(first) / (365.25 * 24 * 3600)
    }

    static let milestones: [Double] = [500, 1000, 2500, 5000, 10000, 20000]

    func nextMilestone(includeSim: Bool) -> Double? { NDCareerStats.milestones.first { $0 > totalHours(includeSim: includeSim) } }
    func previousMilestone(includeSim: Bool) -> Double { NDCareerStats.milestones.filter { $0 <= totalHours(includeSim: includeSim) }.last ?? 0 }

    func milestoneProgress(includeSim: Bool) -> Double {
        guard let next = nextMilestone(includeSim: includeSim) else { return 1.0 }
        let prev = previousMilestone(includeSim: includeSim)
        let range = next - prev
        guard range > 0 else { return 1.0 }
        return (totalHours(includeSim: includeSim) - prev) / range
    }

    // Keep non-parameterised versions for any callsites that don't need the setting
    var nextMilestone: Double? { nextMilestone(includeSim: true) }
    var previousMilestone: Double { previousMilestone(includeSim: true) }
    var milestoneProgress: Double { milestoneProgress(includeSim: true) }
}

// MARK: - FRMS Rolling Time Series

/// One data point in a rolling FRMS time-series chart.
struct NDFRMSRollingPoint: Identifiable {
    let id = UUID()
    let date: Date          // The day this rolling total is computed for
    let total: Double       // Rolling total ending on this day (hours)
    let isProjected: Bool   // true = future rostered flight, false = actual
}

/// A single FRMS limit expressed as a labelled time series.
struct NDFRMSRollingSeries {
    let limitLabel: String           // e.g. "28-Day Flight"
    let limit: Double                // Hard cap (hours)
    let warnAt: Double               // Warning threshold
    let points: [NDFRMSRollingPoint] // Sorted ascending by date
    let fleet: FRMSFleet
    let chartStart: Date             // x-axis domain start (today - windowDays)
    let chartEnd: Date               // x-axis domain end (today + windowDays, capped at last roster day)
}

/// All rolling series for the FRMS limits card charts.
struct NDFRMSRollingData {
    let flight28d:  NDFRMSRollingSeries
    let flight365d: NDFRMSRollingSeries
    let duty7d:     NDFRMSRollingSeries
    let duty14d:    NDFRMSRollingSeries
    let flight7d:   NDFRMSRollingSeries? // LH fleet only

    static let empty: NDFRMSRollingData = {
        let now = Date()
        func emptySeries(_ label: String, limit: Double, warn: Double) -> NDFRMSRollingSeries {
            NDFRMSRollingSeries(limitLabel: label, limit: limit, warnAt: warn, points: [],
                                fleet: .a320B737, chartStart: now, chartEnd: now)
        }
        return NDFRMSRollingData(
            flight28d:  emptySeries("28-Day Flight",  limit: 100,  warn: 90),
            flight365d: emptySeries("365-Day Flight", limit: 1000, warn: 900),
            duty7d:     emptySeries("7-Day Duty",     limit: 60,   warn: 54),
            duty14d:    emptySeries("14-Day Duty",    limit: 90,   warn: 81),
            flight7d:   nil
        )
    }()
}

struct NDProjectedFRMSData {
    /// Peak rolling total for each limit across all future duty days.
    /// e.g. flightHours28d = max over all future duty days D of:
    ///      (actual block hours in [D-27, today]) + (projected block hours in [D-27, D])
    /// This represents the highest your rolling total will reach if all rostered duties are flown.
    let flightHours7d: Double
    let flightHours28d: Double
    let flightHours365d: Double
    let dutyHours7d: Double
    let dutyHours14d: Double

    static let empty = NDProjectedFRMSData(
        flightHours7d: 0, flightHours28d: 0, flightHours365d: 0,
        dutyHours7d: 0, dutyHours14d: 0
    )
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
    var dailyActivity: [NDDailyActivity] = []
    var fleetHours: [NDFleetHours] = []
    var pfRatioByMonth: [NDMonthlyPFRatio] = []
    var monthlyNight: [NDMonthlyNight] = []
    var topRoutes: [NDRouteFrequency] = []
    var topRegistrations: [NDRegistrationHours] = []
    var approachTypes: [NDApproachTypeStat] = []
    var tlStats: NDTakeoffLandingStats = .empty
    var careerStats: NDCareerStats = .empty
    var frmsStrip: NDFRMSStripData = .empty
    var projectedFRMS: NDProjectedFRMSData = .empty
    var frmsRolling: NDFRMSRollingData = .empty
    var flightStatistics: FlightStatistics = .empty
    var isLoading = true
    private(set) var hasLoadedOnce = false

    func load(duties: [FRMSDuty] = []) async {
        if !hasLoadedOnce { isLoading = true }
        let data = await FlightDatabaseService.shared.getInsightsData(duties: duties)
        monthlyActivity  = data.monthlyActivity
        dailyActivity    = data.dailyActivity
        fleetHours       = data.fleetHours
        pfRatioByMonth   = data.pfRatioByMonth
        monthlyNight     = data.monthlyNight
        topRoutes        = data.topRoutes
        topRegistrations = data.topRegistrations
        approachTypes    = data.approachTypes
        tlStats          = data.tlStats
        careerStats      = data.careerStats
        frmsStrip        = data.frmsStrip
        projectedFRMS    = data.projectedFRMS
        frmsRolling      = data.frmsRolling
        flightStatistics = data.flightStatistics
        isLoading = false
        hasLoadedOnce = true
    }
}
