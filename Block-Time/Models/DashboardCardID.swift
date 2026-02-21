//
//  DashboardCardID.swift
//  Block-Time
//
//  Unified identifier for every card available in the Insights dashboard.
//  Used by DashboardConfiguration to persist sidebar/detail layouts.
//

import SwiftUI

enum DashboardCardID: String, Codable, CaseIterable, Hashable {

    // ── Insights-specific cards ─────────────────────────────────────────────
    case frmsFlightTime    // 2-ring flight time gauge (28d/365d)
    case frmsDutyTime      // 2-ring duty time gauge (7d/14d)
    case activityChart     // Monthly block hours bar chart
    case fleetDonut        // Fleet distribution pie chart
    case roleDistribution  // PF/PNF role breakdown
    case pfRatioChart      // PF ratio trend line
    case takeoffLanding    // Takeoff & landing stats
    case approachTypes     // Approach type breakdown
    case topRoutes         // Most-flown route pairs
    case topRegistrations  // Most-flown registrations
    case nightHeatmap      // Night-hour calendar heatmap
    case careerMilestones  // Career overview & milestone progress

    // ── Dashboard stat cards ────────────────────────────────────────────────
    case totalTime
    case picTime
    case icusTime
    case nightTime
    case simTime
    case pfRatioStat
    case recentActivity7
    case recentActivity28
    case recentActivity30
    case recentActivity365
    case pfRecency
    case aiiiRecency
    case takeoffRecency
    case landingRecency
    case aircraftTypeTime
    case averageMetric

    // MARK: - Display

    var displayName: String {
        switch self {
        case .frmsFlightTime:    return "FRMS Flight Time"
        case .frmsDutyTime:      return "FRMS Duty Time"
        case .activityChart:     return "Activity Chart"
        case .fleetDonut:        return "Fleet Distribution"
        case .roleDistribution:  return "Role Distribution"
        case .pfRatioChart:      return "PF Ratio Chart"
        case .takeoffLanding:    return "Takeoffs & Landings"
        case .approachTypes:     return "Approach Types"
        case .topRoutes:         return "Top Routes"
        case .topRegistrations:  return "Top Registrations"
        case .nightHeatmap:      return "Night Heatmap"
        case .careerMilestones:  return "Career Overview"
        case .totalTime:         return "Total Time"
        case .picTime:           return "PIC Time"
        case .icusTime:          return "ICUS Time"
        case .nightTime:         return "Night Time"
        case .simTime:           return "Simulator Time"
        case .pfRatioStat:       return "PF Ratio"
        case .recentActivity7:   return "Last 7 Days"
        case .recentActivity28:  return "Last 28 Days"
        case .recentActivity30:  return "Last 30 Days"
        case .recentActivity365: return "Last 365 Days"
        case .pfRecency:         return "PF Recency"
        case .aiiiRecency:       return "AIII Recency"
        case .takeoffRecency:    return "T/O Recency"
        case .landingRecency:    return "LDG Recency"
        case .aircraftTypeTime:  return "Time on Type"
        case .averageMetric:     return "Average Stats"
        }
    }

    var icon: String {
        switch self {
        case .frmsFlightTime:    return "airplane.circle.fill"
        case .frmsDutyTime:      return "briefcase.fill"
        case .activityChart:     return "chart.bar.fill"
        case .fleetDonut:        return "chart.pie.fill"
        case .roleDistribution:  return "person.2.fill"
        case .pfRatioChart:      return "chart.line.uptrend.xyaxis"
        case .takeoffLanding:    return "airplane.departure"
        case .approachTypes:     return "airplane.arrival"
        case .topRoutes:         return "map.fill"
        case .topRegistrations:  return "tag.fill"
        case .nightHeatmap:      return "moon.stars.fill"
        case .careerMilestones:  return "trophy.fill"
        case .totalTime:         return "clock.fill"
        case .picTime:           return "person.badge.shield.checkmark.fill"
        case .icusTime:          return "person.2.fill"
        case .nightTime:         return "moon.fill"
        case .simTime:           return "desktopcomputer"
        case .pfRatioStat:       return "chart.pie.fill"
        case .recentActivity7:   return "calendar"
        case .recentActivity28:  return "calendar"
        case .recentActivity30:  return "calendar"
        case .recentActivity365: return "calendar"
        case .pfRecency:         return "checkmark.circle.fill"
        case .aiiiRecency:       return "checkmark.circle.fill"
        case .takeoffRecency:    return "airplane.departure"
        case .landingRecency:    return "airplane.arrival"
        case .aircraftTypeTime:  return "airplane"
        case .averageMetric:     return "chart.line.uptrend.xyaxis"
        }
    }

    var accentColor: Color {
        switch self {
        case .frmsFlightTime:    return .orange
        case .frmsDutyTime:      return .teal
        case .activityChart:     return .blue
        case .fleetDonut:        return .purple
        case .roleDistribution:  return .teal
        case .pfRatioChart:      return .orange
        case .takeoffLanding:    return .green
        case .approachTypes:     return .indigo
        case .topRoutes:         return .red
        case .topRegistrations:  return .cyan
        case .nightHeatmap:      return .indigo
        case .careerMilestones:  return .yellow
        case .totalTime:         return .blue
        case .picTime:           return .green
        case .icusTime:          return .orange
        case .nightTime:         return .indigo
        case .simTime:           return .cyan
        case .pfRatioStat:       return .orange
        case .recentActivity7:   return .green
        case .recentActivity28:  return .green
        case .recentActivity30:  return .green
        case .recentActivity365: return .green
        case .pfRecency:         return .blue
        case .aiiiRecency:       return .blue
        case .takeoffRecency:    return .blue
        case .landingRecency:    return .blue
        case .aircraftTypeTime:  return .mint
        case .averageMetric:     return .purple
        }
    }

    /// Advisory hint: this card was designed to look good at sidebar (narrow) widths.
    var sidebarHint: Bool {
        switch self {
        case .frmsFlightTime, .frmsDutyTime, .totalTime, .picTime, .icusTime, .nightTime, .simTime,
             .pfRatioStat, .recentActivity7, .recentActivity28, .recentActivity30,
             .recentActivity365, .pfRecency, .aiiiRecency, .takeoffRecency,
             .landingRecency, .aircraftTypeTime, .averageMetric, .careerMilestones:
            return true
        default:
            return false
        }
    }
}
