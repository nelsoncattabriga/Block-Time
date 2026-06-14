//
//  DashboardCardView.swift
//  Block-Time
//
//  Factory view: given an DashboardCardID, renders the correct card with
//  the correct data from NewDashboardViewModel / FRMSViewModel.
//
//  Pass isCompact: true to force .compact horizontalSizeClass (sidebar use).
//

import SwiftUI
import BlockTimeKit

struct DashboardCardView: View {
    let cardID: DashboardCardID
    var frmsViewModel: FRMSViewModel
    let viewModel: NewDashboardViewModel
    var isCompact: Bool = false

    @State private var showTimesInHoursMinutes: Bool =
        UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
    @AppStorage("showSpInsSelector") private var showSpInsSelector: Bool = false
    @AppStorage("countSimInTotal") private var countSimInTotal: Bool = true
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

    private func isInsightsCard(_ id: DashboardCardID) -> Bool {
        // Custom counter cards are always rendered as insights cards
        if id.customCounterColumnIndex != nil { return true }
        switch id {
        case .frmsFlightTime, .frmsDutyTime, .frmsRestWindow, .frmsLimitsGauge,
             .frmsRollingLine, .activityChart, .timeByType,
             .pfRatioChart, .takeoffLanding, .approachTypes, .topRoutes,
             .topRegistrations, .airportStats, .workRateHeatmap, .careerMilestones, .customCount,
             .punctuality, .crewFrequency:
            return true
        default:
            return false
        }
    }

    // MARK: - Insights cards

    @ViewBuilder
    private var insightsContent: some View {
        // Custom counter cards: dispatch before the main switch
        if let columnIndex = cardID.customCounterColumnIndex {
            CustomCounterDashboardCard(columnIndex: columnIndex)
        } else {
        switch cardID {
        case .frmsFlightTime:
            FRMSFlightStripCard(data: viewModel.frmsStrip)
        case .frmsDutyTime:
            FRMSDutyStripCard(flightStrip: viewModel.frmsStrip, frmsViewModel: frmsViewModel)
        case .frmsRestWindow:
            SHRestWindowCard(frmsViewModel: frmsViewModel)
        case .frmsLimitsGauge:
            FRMSLimitsGaugeCard(
                frmsViewModel: frmsViewModel,
                strip: viewModel.frmsStrip
            )
        case .frmsRollingLine:
            FRMSRollingLineCard(data: viewModel.frmsRolling)
        case .activityChart:
            FlyingActivityChartCard(data: viewModel.monthlyActivity)
        case .timeByType:
            FlyingByTypeCard(data: viewModel.fleetHours)
        case .pfRatioChart:
            PFRatioCard(data: viewModel.pfRatioByMonth)
        case .takeoffLanding:
            TakeoffLandingCard()
        case .approachTypes:
            ApproachTypesCard()
        case .topRoutes:
            TopRoutesCard()
        case .topRegistrations:
            TopRegistrationsCard()
        case .airportStats:
            AirportStatsCard()
        case .workRateHeatmap:
            WorkRateHeatmapCard(monthlyActivity: viewModel.monthlyActivity, dailyActivity: viewModel.dailyActivity)
        case .careerMilestones:
            CareerMilestonesCard(stats: viewModel.careerStats)
        case .customCount:
            if !CustomCounterService.shared.definitions.isEmpty { CustomCountCard() }
        case .punctuality:
            PunctualityCard()
        case .crewFrequency:
            TopCrewCard()
        default:
            EmptyView()
        }
        } // end else (non-custom-counter)
    }

    // MARK: - Dashboard stat cards

    @ViewBuilder
    private var statContent: some View {
        let stats = viewModel.flightStatistics
        switch cardID {
        case .totalTime:
            StatCard(
                title: "Total Time",
                value: stats.formattedTotalFlightTime(includeSim: countSimInTotal, asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "\(stats.totalSectors) sectors · \(viewModel.careerStats.totalAircraftTypes) types · \(stats.totalAirports) airports",
                color: .blue,
                icon: "clock.fill"
            )
        case .picTime:
            StatCard(
                title: "PIC Time",
                value: stats.formattedP1Time(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: stats.totalBlockTime > 0 ? String(format: "%.0f%% of total block time", stats.totalP1Time / stats.totalBlockTime * 100) : "In Command",
                color: .green,
                icon: "person.badge.shield.checkmark.fill",
                fraction: stats.totalBlockTime > 0 ? stats.totalP1Time / stats.totalBlockTime : nil
            )
        case .icusTime:
            StatCard(
                title: "ICUS Time",
                value: stats.formattedP1USTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: stats.totalBlockTime > 0 ? String(format: "%.0f%% of total block time", stats.totalP1USTime / stats.totalBlockTime * 100) : "Under Supervision",
                color: .orange,
                icon: "person.2.fill",
                fraction: stats.totalBlockTime > 0 ? stats.totalP1USTime / stats.totalBlockTime : nil
            )
        case .nightTime:
            StatCard(
                title: "Night Time",
                value: stats.formattedNightTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: stats.totalBlockTime > 0 ? String(format: "%.0f%% of total block time", stats.totalNightTime / stats.totalBlockTime * 100) : "Night flying",
                color: .indigo,
                icon: "moon.fill",
                fraction: stats.totalBlockTime > 0 ? stats.totalNightTime / stats.totalBlockTime : nil
            )
        case .instrumentTime:
            StatCard(
                title: "Instrument Time",
                value: stats.formattedInstrumentTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: stats.totalBlockTime > 0 ? String(format: "%.0f%% of total block time", stats.totalInstrumentTime / stats.totalBlockTime * 100) : "Instrument flying",
                color: .teal,
                icon: "gauge.with.dots.needle.67percent",
                fraction: stats.totalBlockTime > 0 ? stats.totalInstrumentTime / stats.totalBlockTime : nil
            )
        case .simTime:
            StatCard(
                title: "SIM Time",
                value: stats.formattedSIMTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: stats.totalFlightTime > 0 ? String(format: "%.0f%% of total flight time", stats.totalSIMTime / stats.totalFlightTime * 100) : "Simulator training",
                color: .cyan,
                icon: "desktopcomputer",
                fraction: stats.totalFlightTime > 0 ? stats.totalSIMTime / stats.totalFlightTime : nil
            )
        case .insTime:
            if showSpInsSelector { SpInsTimeCard(stats: stats, showTimesInHoursMinutes: showTimesInHoursMinutes) }
//        case .pfRatioStat:
//            StatCard(
//                title: "PF Ratio",
//                value: String(format: "%.0f%%", stats.pfPercentage),
//                subtitle: "\(stats.pfSectors) of \(stats.totalSectors)",
//                color: .orange,
//                icon: "chart.pie.fill"
//            )
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

// MARK: - Instructor Time Card
struct SpInsTimeCard: View {
    let stats: FlightStatistics
    let showTimesInHoursMinutes: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Instructor Time", icon: "person.wave.2", iconColor: .blue)

            VStack(alignment: .leading, spacing: 10) {
                // Total — large primary value
                VStack(alignment: .leading, spacing: 2) {
                    Text(stats.formattedSpInsTime(asHoursMinutes: showTimesInHoursMinutes))
                        .iPadScaledFont(.subheadline)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)

                    if stats.totalFlightTime > 0 && stats.totalSpInsTime > 0 {
                        ProgressView(value: min(stats.totalSpInsTime / stats.totalFlightTime, 1))
                            .tint(AppColors.insColor)
                            .frame(height: 6)
                    } else {
                        Spacer().frame(height: 6)
                    }

                    Text("Total")
                        .iPadScaledFont(.caption, phoneFont: .footnote)
                        .foregroundStyle(.secondary)
                }

                // FLT / SIM breakdown row
                if stats.totalSpInsTime > 0 {
                    HStack(spacing: 0) {
                        if stats.totalSpInsFltTime > 0 {
                            breakdownItem(
                                label: "FLT",
                                count: stats.spInsFltCount,
                                value: stats.formattedSpInsFltTime(asHoursMinutes: showTimesInHoursMinutes),
                                color: .blue,
                                countLabel: "flight"
                            )
                        }
                        Spacer()
                        if stats.totalSpInsSimTime > 0 {
                            breakdownItem(
                                label: "SIM",
                                count: stats.spInsSimCount,
                                value: stats.formattedSpInsSimTime(asHoursMinutes: showTimesInHoursMinutes),
                                color: AppColors.insColor
                            )
                        }
                    }
                } else {
                    Text("Simulator & aircraft instruction")
                        .iPadScaledFont(.caption, phoneFont: .footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }

    private func breakdownItem(label: String, count: Int, value: String, color: Color, countLabel: String = "session") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label)
                    .iPadScaledFont(.caption, phoneFont: .caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .iPadScaledFont(.footnote, phoneFont: .subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color.opacity(0.85))
            }
            if count > 0 {
                Text("\(count) \(countLabel)\(count == 1 ? "" : "s")")
                    .iPadScaledFont(.caption, phoneFont: .footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
