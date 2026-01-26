import SwiftUI

// MARK: - Statistics Card Types and Settings
enum StatCardType: String, CaseIterable, Identifiable {
    case totalTime = "totalTime"
    case picTime = "picTime"
    case p1usTime = "p1usTime"
    case nightTime = "nightTime"
    case simTime = "simTime"
    case pfRatio = "pfRatio"
    case recentActivity7 = "recentActivity7"
    case recentActivity28 = "recentActivity28"
    case recentActivity30 = "recentActivity30"
    case recentActivity365 = "recentActivity365"
    case pfRecency = "pfRecency"
    case aiiiRecency = "aiiiRecency"
    case takeoffRecency = "takeoffRecency"
    case landingRecency = "landingRecency"
    case aircraftTypeTime = "aircraftTypeTime"
    case averageMetric = "averageMetric"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .totalTime: return "Total Time"
        case .picTime: return "PIC Time"
        case .p1usTime: return "ICUS Time"
        case .nightTime: return "Night Time"
        case .simTime: return "Simulator Time"
        case .pfRatio: return "PF Ratio"
        case .recentActivity7: return "Last 7 Days"
        case .recentActivity28: return "Last 28 Day"
        case .recentActivity30: return "Last 30 Days"
        case .recentActivity365: return "Last 365 Days"
        case .pfRecency: return "PF Recency"
        case .aiiiRecency: return "AIII Recency"
        case .takeoffRecency: return "T/O Recency"
        case .landingRecency: return "LDG Recency"
        case .aircraftTypeTime: return "Time on Type"
        case .averageMetric: return "Average Stats"
        }
    }

    var icon: String {
        switch self {
        case .totalTime: return "clock.fill"
        case .picTime: return "person.badge.shield.checkmark.fill"
        case .p1usTime: return "person.2.fill"
        case .nightTime: return "moon.fill"
        case .simTime: return "desktopcomputer"
        case .pfRatio: return "chart.pie.fill"
        case .recentActivity7: return "calendar"
        case .recentActivity28: return "calendar"
        case .recentActivity30: return "calendar"
        case .recentActivity365: return "calendar"
        case .pfRecency: return "checkmark.circle.badge.airplane"
        case .aiiiRecency: return "checkmark.circle.badge.airplane"
        case .takeoffRecency: return "checkmark.circle.badge.airplane"
        case .landingRecency: return "checkmark.circle.badge.airplane"
        case .aircraftTypeTime: return "airplane"
        case .averageMetric: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: Color {
        switch self {
        case .totalTime: return .blue
        case .picTime: return .green
        case .p1usTime: return .orange
        case .nightTime: return .indigo
        case .simTime: return .cyan
        case .pfRatio: return .orange
        case .recentActivity7: return .green
        case .recentActivity28: return .green
        case .recentActivity30: return .green
        case .recentActivity365: return .green
        case .pfRecency: return .blue
        case .aiiiRecency: return .blue
        case .takeoffRecency: return .blue
        case .landingRecency: return .blue
        case .aircraftTypeTime: return .mint
        case .averageMetric: return .purple
        }
    }
}
