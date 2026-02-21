//
//  InsightsCardView.swift
//  Block-Time
//
//  Factory view: given an InsightsCardID, renders the correct card with
//  the correct data from NewDashboardViewModel / FRMSViewModel.
//
//  Pass isCompact: true to force .compact horizontalSizeClass (sidebar use).
//

import SwiftUI

struct InsightsCardView: View {
    let cardID: InsightsCardID
    @ObservedObject var frmsViewModel: FRMSViewModel
    let viewModel: NewDashboardViewModel
    var isCompact: Bool = false

    @State private var showTimesInHoursMinutes: Bool =
        UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
    @Environment(\.horizontalSizeClass) private var naturalSizeClass

    var body: some View {
        cardContent
            .environment(\.horizontalSizeClass, isCompact ? .compact : naturalSizeClass)
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                showTimesInHoursMinutes = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
            }
    }

    // MARK: - Card dispatch (split to avoid type-checker timeouts)

    @ViewBuilder
    private var cardContent: some View {
        if isInsightsCard(cardID) {
            insightsContent
        } else {
            statContent
        }
    }

    private func isInsightsCard(_ id: InsightsCardID) -> Bool {
        switch id {
        case .frmsFlightTime, .frmsDutyTime, .activityChart, .fleetDonut, .roleDistribution,
             .pfRatioChart, .takeoffLanding, .approachTypes, .topRoutes,
             .topRegistrations, .nightHeatmap, .careerMilestones:
            return true
        default:
            return false
        }
    }

    // MARK: - Insights cards

    @ViewBuilder
    private var insightsContent: some View {
        switch cardID {
        case .frmsFlightTime:
            if !isCompact && UIDevice.current.userInterfaceIdiom != .pad {
                FRMSStatusStripCard(data: viewModel.frmsStrip)
            } else {
                FRMSLimitsCard(flightStrip: viewModel.frmsStrip, frmsViewModel: frmsViewModel, showFlight: true, showDuty: false)
            }
        case .frmsDutyTime:
            if !isCompact && UIDevice.current.userInterfaceIdiom != .pad {
                FRMSDutyStripCard(flightStrip: viewModel.frmsStrip, frmsViewModel: frmsViewModel)
            } else {
                FRMSLimitsCard(flightStrip: viewModel.frmsStrip, frmsViewModel: frmsViewModel, showFlight: false, showDuty: true)
            }
        case .activityChart:
            ActivityChartCard(data: viewModel.monthlyActivity)
        case .fleetDonut:
            FleetDonutCard(data: viewModel.fleetHours)
        case .roleDistribution:
            RoleDistributionCard(data: viewModel.monthlyRoles)
        case .pfRatioChart:
            PFRatioCard(data: viewModel.pfRatioByMonth)
        case .takeoffLanding:
            TakeoffLandingCard(stats: viewModel.tlStats)
        case .approachTypes:
            ApproachTypesCard(data: viewModel.approachTypes)
        case .topRoutes:
            TopRoutesCard(routes: viewModel.topRoutes)
        case .topRegistrations:
            TopRegistrationsCard(registrations: viewModel.topRegistrations)
        case .nightHeatmap:
            NightHeatmapCard(data: viewModel.monthlyNight)
        case .careerMilestones:
            CareerMilestonesCard(stats: viewModel.careerStats)
        default:
            EmptyView()
        }
    }

    // MARK: - Dashboard stat cards

    @ViewBuilder
    private var statContent: some View {
        let stats = viewModel.flightStatistics
        switch cardID {
        case .totalTime:
            StatCard(
                title: "Total Time",
                value: stats.formattedTotalFlightTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "\(stats.totalSectors) sectors",
                color: .blue,
                icon: "clock.fill"
            )
        case .picTime:
            StatCard(
                title: "PIC Time",
                value: stats.formattedP1Time(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "In Command",
                color: .green,
                icon: "person.badge.shield.checkmark.fill"
            )
        case .icusTime:
            StatCard(
                title: "ICUS Time",
                value: stats.formattedP1USTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "Under Supervision",
                color: .orange,
                icon: "person.2.fill"
            )
        case .nightTime:
            StatCard(
                title: "Night Time",
                value: stats.formattedNightTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "Night flying",
                color: .indigo,
                icon: "moon.fill"
            )
        case .simTime:
            StatCard(
                title: "SIM Time",
                value: stats.formattedSIMTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "Simulator training",
                color: .cyan,
                icon: "desktopcomputer"
            )
        case .pfRatioStat:
            StatCard(
                title: "PF Ratio",
                value: String(format: "%.0f%%", stats.pfPercentage),
                subtitle: "\(stats.pfSectors) of \(stats.totalSectors)",
                color: .orange,
                icon: "chart.pie.fill"
            )
        case .recentActivity7:
            RecentActivityCard(statistics: stats, days: 7)
        case .recentActivity28:
            RecentActivityCard(statistics: stats, days: 28)
        case .recentActivity30:
            RecentActivityCard(statistics: stats, days: 30)
        case .recentActivity365:
            RecentActivityCard(statistics: stats, days: 365)
        case .pfRecency:
            RecencyCard(statistics: stats, recencyType: .pf)
        case .aiiiRecency:
            RecencyCard(statistics: stats, recencyType: .aiii)
        case .takeoffRecency:
            RecencyCard(statistics: stats, recencyType: .takeoff)
        case .landingRecency:
            RecencyCard(statistics: stats, recencyType: .landing)
        case .aircraftTypeTime:
            AircraftTypeTimeCard(statistics: stats, isEditMode: false)
        case .averageMetric:
            AverageMetricCard(statistics: stats, isEditMode: false)
        default:
            EmptyView()
        }
    }
}
