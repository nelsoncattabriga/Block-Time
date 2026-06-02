//
//  DashboardCardID.swift
//  Block-Time
//
//  Unified identifier for every card available in the Dashboard.
//  Used by DashboardConfiguration to persist sidebar/detail layouts.
//
//  Refactored from enum to struct so custom counter card IDs (non-static,
//  UUID-keyed) can coexist with the fixed standard cards — while preserving
//  every existing rawValue string so UserDefaults selections survive the change.
//

import SwiftUI

struct DashboardCardID: RawRepresentable, Codable, Hashable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
    init(rawValue: String) { self.rawValue = rawValue }

    // MARK: - Standard cards (rawValues are IDENTICAL to the old enum case names)

    static let frmsFlightTime    = DashboardCardID(rawValue: "frmsFlightTime")
    static let frmsDutyTime      = DashboardCardID(rawValue: "frmsDutyTime")
    static let frmsRestWindow    = DashboardCardID(rawValue: "frmsRestWindow")
    static let frmsLimitsGauge   = DashboardCardID(rawValue: "frmsLimitsGauge")
    static let frmsRollingLine   = DashboardCardID(rawValue: "frmsRollingLine")
    static let activityChart     = DashboardCardID(rawValue: "activityChart")
    static let timeByType        = DashboardCardID(rawValue: "timeByType")
    static let pfRatioChart      = DashboardCardID(rawValue: "pfRatioChart")
    static let takeoffLanding    = DashboardCardID(rawValue: "takeoffLanding")
    static let approachTypes     = DashboardCardID(rawValue: "approachTypes")
    static let topRoutes         = DashboardCardID(rawValue: "topRoutes")
    static let topRegistrations  = DashboardCardID(rawValue: "topRegistrations")
    static let airportStats      = DashboardCardID(rawValue: "airportStats")
    static let workRateHeatmap   = DashboardCardID(rawValue: "workRateHeatmap")
    static let careerMilestones  = DashboardCardID(rawValue: "careerMilestones")
    static let customCount       = DashboardCardID(rawValue: "customCount")
    static let punctuality       = DashboardCardID(rawValue: "punctuality")
    static let crewFrequency     = DashboardCardID(rawValue: "crewFrequency")
    static let totalTime         = DashboardCardID(rawValue: "totalTime")
    static let picTime           = DashboardCardID(rawValue: "picTime")
    static let icusTime          = DashboardCardID(rawValue: "icusTime")
    static let nightTime         = DashboardCardID(rawValue: "nightTime")
    static let instrumentTime    = DashboardCardID(rawValue: "instrumentTime")
    static let simTime           = DashboardCardID(rawValue: "simTime")
    static let insTime           = DashboardCardID(rawValue: "insTime")
    static let recentActivity7   = DashboardCardID(rawValue: "recentActivity7")
    static let recentActivity28  = DashboardCardID(rawValue: "recentActivity28")
    static let recentActivity30  = DashboardCardID(rawValue: "recentActivity30")
    static let recentActivity365 = DashboardCardID(rawValue: "recentActivity365")
    static let pfRecency         = DashboardCardID(rawValue: "pfRecency")
    static let aiiiRecency       = DashboardCardID(rawValue: "aiiiRecency")
    static let takeoffRecency    = DashboardCardID(rawValue: "takeoffRecency")
    static let landingRecency    = DashboardCardID(rawValue: "landingRecency")
    static let aircraftTypeTime  = DashboardCardID(rawValue: "aircraftTypeTime")
    static let averageMetric     = DashboardCardID(rawValue: "averageMetric")

    /// All standard (non-custom-counter) cards, in the original enum declaration order.
    static let allStandardCases: [DashboardCardID] = [
        .frmsFlightTime, .frmsDutyTime, .frmsRestWindow, .frmsLimitsGauge,
        .frmsRollingLine, .activityChart, .timeByType, .pfRatioChart,
        .takeoffLanding, .approachTypes, .topRoutes, .topRegistrations,
        .airportStats, .workRateHeatmap, .careerMilestones, .customCount,
        .punctuality, .crewFrequency,
        .totalTime, .picTime, .icusTime, .nightTime, .instrumentTime,
        .simTime, .insTime,
        .recentActivity7, .recentActivity28, .recentActivity30, .recentActivity365,
        .pfRecency, .aiiiRecency, .takeoffRecency, .landingRecency,
        .aircraftTypeTime, .averageMetric
    ]

    // MARK: - Custom counter factory

    static func customCounter(_ columnIndex: Int) -> DashboardCardID {
        DashboardCardID(rawValue: "customCounter.\(columnIndex)")
    }

    /// Non-nil when this card represents a user-defined counter.
    var customCounterColumnIndex: Int? {
        guard rawValue.hasPrefix("customCounter.") else { return nil }
        return Int(String(rawValue.dropFirst("customCounter.".count)))
    }

    // MARK: - Display

    var displayName: String {
        if let columnIndex = customCounterColumnIndex {
            return CustomCounterService.shared.definition(for: columnIndex)?.label ?? "Field"
        }
        switch rawValue {
        case "frmsFlightTime":    return "FRMS Flight Time"
        case "frmsDutyTime":      return "FRMS Duty Time"
        case "frmsRestWindow":    return "FRMS SH Rest"
        case "frmsLimitsGauge":   return "FRMS Limits"
        case "frmsRollingLine":   return "FRMS Rolling Line"
        case "activityChart":     return "Flying Activity"
        case "timeByType":        return "Time by Type"
        case "pfRatioChart":      return "PF Ratio"
        case "takeoffLanding":    return "Takeoffs & Landings"
        case "approachTypes":     return "Approach Types"
        case "topRoutes":         return "Top Routes"
        case "topRegistrations":  return "Top Registrations"
        case "airportStats":      return "Airport Stats"
        case "workRateHeatmap":   return "Work Rate"
        case "careerMilestones":  return "Career Overview"
        case "customCount":       return UserDefaults.standard.string(forKey: "customCountLabel") ?? "Passengers"
        case "punctuality":       return "On Time Performance"
        case "crewFrequency":     return "Top Crew"
        case "totalTime":         return "Total Time"
        case "picTime":           return "PIC Time"
        case "icusTime":          return "ICUS Time"
        case "nightTime":         return "Night Time"
        case "instrumentTime":    return "Instrument Time"
        case "simTime":           return "Simulator Time"
        case "insTime":           return "Instructor Time"
        case "recentActivity7":   return "Last 7 Days"
        case "recentActivity28":  return "Last 28 Days"
        case "recentActivity30":  return "Last 30 Days"
        case "recentActivity365": return "Last 365 Days"
        case "pfRecency":         return "PF Recency"
        case "aiiiRecency":       return "AIII Recency"
        case "takeoffRecency":    return "T/O Recency"
        case "landingRecency":    return "LDG Recency"
        case "aircraftTypeTime":  return "Time on Type"
        case "averageMetric":     return "Average Stats"
        default:                  return rawValue
        }
    }

    var icon: String {
        if let columnIndex = customCounterColumnIndex {
            guard let def = CustomCounterService.shared.definition(for: columnIndex) else {
                return "questionmark.circle"
            }
            switch def.type {
            case .time:    return "clock.fill"
            case .decimal: return "number.circle.fill"
            case .integer: return "number.square.fill"
            case .text:    return "text.alignleft"
            }
        }
        switch rawValue {
        case "frmsFlightTime":    return "airplane.circle.fill"
        case "frmsDutyTime":      return "briefcase.fill"
        case "frmsRestWindow":    return "bed.double.fill"
        case "frmsLimitsGauge":   return "gauge.with.needle.fill"
        case "frmsRollingLine":   return "chart.line.uptrend.xyaxis"
        case "activityChart":     return "chart.bar.fill"
        case "timeByType":        return "chart.pie.fill"
        case "pfRatioChart":      return "chart.line.uptrend.xyaxis"
        case "takeoffLanding":    return "airplane.departure"
        case "approachTypes":     return "airplane.arrival"
        case "topRoutes":         return "map.fill"
        case "topRegistrations":  return "tag.fill"
        case "airportStats":      return "building.columns.fill"
        case "workRateHeatmap":   return "chart.bar.xaxis"
        case "careerMilestones":  return "trophy.fill"
        case "customCount":       return "person.2.fill"
        case "punctuality":       return "clock.badge.checkmark.fill"
        case "crewFrequency":     return "person.2.fill"
        case "totalTime":         return "clock.fill"
        case "picTime":           return "person.badge.shield.checkmark.fill"
        case "icusTime":          return "person.2.fill"
        case "nightTime":         return "moon.fill"
        case "instrumentTime":    return "gauge.with.dots.needle.67percent"
        case "simTime":           return "desktopcomputer"
        case "insTime":           return "person.fill.badge.plus"
        case "recentActivity7",
             "recentActivity28",
             "recentActivity30",
             "recentActivity365": return "calendar"
        case "pfRecency":         return "checkmark.circle.fill"
        case "aiiiRecency":       return "checkmark.circle.fill"
        case "takeoffRecency":    return "airplane.departure"
        case "landingRecency":    return "airplane.arrival"
        case "aircraftTypeTime":  return "airplane"
        case "averageMetric":     return "chart.line.uptrend.xyaxis"
        default:                  return "questionmark.circle"
        }
    }

    var accentColor: Color {
        if let columnIndex = customCounterColumnIndex {
            guard let def = CustomCounterService.shared.definition(for: columnIndex) else {
                return .gray
            }
            switch def.type {
            case .time:    return .blue
            case .decimal: return .orange
            case .integer: return .teal
            case .text:    return .purple
            }
        }
        switch rawValue {
        // FRMS
        case "frmsFlightTime":    return .orange
        case "frmsDutyTime":      return .orange
        case "frmsRestWindow":    return .orange
        case "frmsLimitsGauge":   return .orange
        case "frmsRollingLine":   return .orange
        // Logged time / stats
        case "totalTime":         return .blue
        case "picTime":           return .blue
        case "icusTime":          return .blue
        case "nightTime":         return .blue
        case "instrumentTime":    return .blue
        case "simTime":           return .blue
        case "insTime":           return AppColors.insColor
        // Recency
        case "recentActivity7",
             "recentActivity28",
             "recentActivity30",
             "recentActivity365": return .teal
        case "pfRecency":         return .teal
        case "aiiiRecency":       return .teal
        case "takeoffRecency":    return .teal
        case "landingRecency":    return .teal
        // Charts / analysis
        case "activityChart":     return .purple
        case "timeByType":        return .purple
        case "pfRatioChart":      return .purple
        case "workRateHeatmap":   return .purple
        case "crewFrequency":     return .purple
        case "averageMetric":     return .purple
        // Routes / airports / fleet
        case "takeoffLanding":    return .indigo
        case "approachTypes":     return .indigo
        case "topRoutes":         return .indigo
        case "topRegistrations":  return .indigo
        case "airportStats":      return .indigo
        case "aircraftTypeTime":  return .indigo
        // Other
        case "punctuality":       return .green
        case "careerMilestones":  return .yellow
        case "customCount":       return .teal
        default:                  return .gray
        }
    }

    /// Advisory hint: this card was designed to look good at sidebar (narrow) widths.
    var sidebarHint: Bool {
        // Custom counter cards are sidebar-friendly
        if customCounterColumnIndex != nil { return true }
        switch rawValue {
        case "frmsFlightTime", "frmsDutyTime", "frmsRestWindow",
             "totalTime", "picTime", "icusTime", "nightTime", "instrumentTime",
             "simTime", "insTime",
             "recentActivity7", "recentActivity28", "recentActivity30", "recentActivity365",
             "pfRecency", "aiiiRecency", "takeoffRecency", "landingRecency",
             "aircraftTypeTime", "averageMetric", "careerMilestones", "customCount":
            return true
        default:
            return false
        }
    }
}
