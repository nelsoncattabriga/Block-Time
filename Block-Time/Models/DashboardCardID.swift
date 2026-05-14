//
//  DashboardCardID.swift
//  Block-Time
//
//  Unified identifier for every card available in the Dashboard.
//  Used by DashboardConfiguration to persist sidebar/detail layouts.
//

import SwiftUI

enum DashboardCardID: String, Codable, CaseIterable, Hashable {

    // ── New Dashboard Cards  ─────────────────────────────────────────────
    case frmsFlightTime    // 2-ring flight time gauge (28d/365d)
    case frmsDutyTime      // 2-ring duty time gauge (7d/14d)
    case frmsRestWindow    // Rest window timeline (sign-off → earliest sign-on)
    case frmsLimitsGauge   // Horizontal fuel-bar gauges for all 5 rolling limits
    case frmsRollingLine   // Rolling-total line/area chart with projected dashed line
    case activityChart     // Monthly block hours bar chart
    case timeByType        // Time by Type distribution pie chart
    case pfRatioChart      // PF ratio trend line
    case takeoffLanding    // Takeoff & landing stats
    case approachTypes     // Approach type breakdown
    case topRoutes         // Most-flown route pairs
    case topRegistrations  // Most-flown registrations
    case airportStats      // Airport visit breakdown (visits, dep/arr, top reg)
    case workRateHeatmap      // Work Rate calendar heatmap
    case careerMilestones  // Career overview & milestone progress
    case customCount       // User-defined counter totals (e.g. PAX carried)
    case punctuality       // Departure punctuality (STD vs ATD)
    case crewFrequency     // Most-flown crew members

    // ── Original Dashboard stat cards ────────────────────────────────────────────────
    case totalTime
    case picTime
    case icusTime
    case nightTime
    case instrumentTime
    case simTime
    case insTime
//    case pfRatioStat
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
        case .frmsRestWindow:    return "FRMS SH Rest"
        case .frmsLimitsGauge:   return "FRMS Limits"
        case .frmsRollingLine:   return "FRMS Rolling Line"
        case .activityChart:     return "Flying Activity"
        case .timeByType:        return "Time by Type"
        case .pfRatioChart:      return "PF Ratio"
        case .takeoffLanding:    return "Takeoffs & Landings"
        case .approachTypes:     return "Approach Types"
        case .topRoutes:         return "Top Routes"
        case .topRegistrations:  return "Top Registrations"
        case .airportStats:      return "Airport Stats"
        case .workRateHeatmap:   return "Work Rate"
        case .careerMilestones:  return "Career Overview"
        case .customCount:       return UserDefaults.standard.string(forKey: "customCountLabel") ?? "Passengers"
        case .punctuality:       return "On Time Performance"
        case .crewFrequency:     return "Top Crew"
        case .totalTime:         return "Total Time"
        case .picTime:           return "PIC Time"
        case .icusTime:          return "ICUS Time"
        case .nightTime:         return "Night Time"
        case .instrumentTime:    return "Instrument Time"
        case .simTime:           return "Simulator Time"
        case .insTime:           return "Instructor Time"
//        case .pfRatioStat:       return "PF Ratio"
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
        case .frmsRestWindow:    return "bed.double.fill"
        case .frmsLimitsGauge:   return "gauge.with.needle.fill"
        case .frmsRollingLine:   return "chart.line.uptrend.xyaxis"
        case .activityChart:     return "chart.bar.fill"
        case .timeByType:        return "chart.pie.fill"
        case .pfRatioChart:      return "chart.line.uptrend.xyaxis"
        case .takeoffLanding:    return "airplane.departure"
        case .approachTypes:     return "airplane.arrival"
        case .topRoutes:         return "map.fill"
        case .topRegistrations:  return "tag.fill"
        case .airportStats:      return "building.columns.fill"
        case .workRateHeatmap:      return "chart.bar.xaxis"
        case .careerMilestones:  return "trophy.fill"
        case .customCount:       return "person.2.fill"
        case .punctuality:       return "clock.badge.checkmark.fill"
        case .crewFrequency:     return "person.2.fill"
        case .totalTime:         return "clock.fill"
        case .picTime:           return "person.badge.shield.checkmark.fill"
        case .icusTime:          return "person.2.fill"
        case .nightTime:         return "moon.fill"
        case .instrumentTime:    return "gauge.with.dots.needle.67percent"
        case .simTime:           return "desktopcomputer"
        case .insTime:           return "person.fill.badge.plus"
//        case .pfRatioStat:       return "chart.pie.fill"
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
        case .frmsRestWindow:    return .orange
        case .frmsLimitsGauge:   return .orange
        case .frmsRollingLine:   return .blue
        case .activityChart:     return .blue
        case .timeByType:        return .purple
        case .pfRatioChart:      return .orange
        case .takeoffLanding:    return .green
        case .approachTypes:     return .indigo
        case .topRoutes:         return .red
        case .topRegistrations:  return .cyan
        case .airportStats:      return .teal
        case .workRateHeatmap:      return .indigo
        case .careerMilestones:  return .yellow
        case .customCount:       return .teal
        case .punctuality:       return .teal
        case .crewFrequency:     return .purple
        case .totalTime:         return .blue
        case .picTime:           return .green
        case .icusTime:          return .orange
        case .nightTime:         return .indigo
        case .instrumentTime:    return .teal
        case .simTime:           return .cyan
        case .insTime:           return .pink
//        case .pfRatioStat:       return .orange
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
        case .frmsFlightTime, .frmsDutyTime, .frmsRestWindow, .totalTime, .picTime, .icusTime, .nightTime, .instrumentTime, .simTime, .insTime, .recentActivity7, .recentActivity28, .recentActivity30, .recentActivity365, .pfRecency, .aiiiRecency, .takeoffRecency, .landingRecency, .aircraftTypeTime, .averageMetric, .careerMilestones, .customCount:
            return true
        default:
            return false
        }
    }
}
