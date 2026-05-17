//
//  FRMSLimitsGaugeCard.swift
//  Block-Time
//
//  Horizontal fuel-bar gauges for all active FRMS rolling limits.
//  Shows actual hours consumed, warning zone, and a hard-limit tick mark.
//
//  Each gauge row shows:
//    [■■■■■░░░░░░░░|] 68.4 / 100 hrs
//     actual         limit

import SwiftUI
import BlockTimeDomain

// MARK: - Data Model

struct FRMSLimitGaugeItem: Identifiable {
    let id = UUID()
    let label: String
    let sublabel: String
    let actual: Double
    let limit: Double
    let warnAt: Double
    let accentColor: Color

    var actualRatio: Double { limit > 0 ? min(actual / limit, 1.0) : 0 }
    var warnRatio: Double { limit > 0 ? warnAt / limit : 0 }

    var statusColor: Color {
        let r = actualRatio
        if r >= 1.0 { return .red }
        if r >= warnRatio { return .orange }
        return accentColor
    }
}

// MARK: - Card View

struct FRMSLimitsGaugeCard: View {
    var frmsViewModel: FRMSViewModel
    let strip: NDFRMSStripData
    @AppStorage("showTimesInHoursMinutes") private var showTimesInHoursMinutes = false

    private var totals: FRMSCumulativeTotals? { frmsViewModel.cumulativeTotals }
    private var fleet: FRMSFleet { strip.fleet }
    private var config: FRMSConfiguration { frmsViewModel.configuration }

    private var warnFraction: Double { config.showWarningsAtPercentage }

    private var gaugeItems: [FRMSLimitGaugeItem] {
        var items: [FRMSLimitGaugeItem] = []

        if let max7d = fleet.maxFlightTime7Days {
            items.append(FRMSLimitGaugeItem(
                label: "7 Days",
                sublabel: "Flight Time",
                actual: strip.hours7d,
                limit: max7d,
                warnAt: warnFraction * max7d,
                accentColor: .blue
            ))
        }

        items.append(FRMSLimitGaugeItem(
            label: "\(fleet.flightTimePeriodDays) Days",
            sublabel: "Flight Time",
            actual: strip.hours28d,
            limit: strip.max28d,
            warnAt: warnFraction * strip.max28d,
            accentColor: .blue
        ))

        items.append(FRMSLimitGaugeItem(
            label: "365 Days",
            sublabel: "Flight Time",
            actual: strip.hours365d,
            limit: strip.max365d,
            warnAt: warnFraction * strip.max365d,
            accentColor: .blue
        ))

        items.append(FRMSLimitGaugeItem(
            label: "7 Days",
            sublabel: "Duty Time",
            actual: totals?.dutyTime7Days ?? 0,
            limit: fleet.maxDutyTime7Days,
            warnAt: warnFraction * fleet.maxDutyTime7Days,
            accentColor: .orange
        ))

        let limit14d = fleet.maxDutyTime14DaysInitial ?? fleet.maxDutyTime14Days
        items.append(FRMSLimitGaugeItem(
            label: "14 Days",
            sublabel: "Duty Time",
            actual: totals?.dutyTime14Days ?? 0,
            limit: limit14d,
            warnAt: warnFraction * limit14d,
            accentColor: .orange
        ))

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            CardHeader(title: "FRMS Limits", icon: "gauge.with.needle.fill", iconColor: .orange)

            if frmsViewModel.isLoading {
                loadingView
            } else {
                VStack(spacing: 16) {
                    // Group flight vs duty with a section divider
                    let flightItems = gaugeItems.filter { $0.sublabel == "Flight Time" }
                    let dutyItems = gaugeItems.filter { $0.sublabel == "Duty Time" }

                    sectionGroup(label: "FLIGHT TIME", color: .blue, items: flightItems)
                    Divider().padding(.vertical, 2)
                    sectionGroup(label: "DUTY TIME", color: .orange, items: dutyItems)
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .task { await triggerFRMSLoadIfNeeded() }
    }

    // MARK: - Section Group

    @ViewBuilder
    private func sectionGroup(label: String, color: Color, items: [FRMSLimitGaugeItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(color.opacity(0.7))
                .tracking(1.2)

            ForEach(items) { item in
                gaugeRow(item: item)
            }
        }
    }

    // MARK: - Individual Gauge Row

    @ViewBuilder
    private func gaugeRow(item: FRMSLimitGaugeItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {

            // Labels row
            HStack(alignment: .firstTextBaseline) {
                Text(item.label)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                // Actual hours
                HStack(spacing: 4) {
                    Text(formattedHours(item.actual))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(item.statusColor)


                    Text("/ \(formattedHours(item.limit))")
                        .iPadScaledFont(.caption, phoneFont: .footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Gauge bar
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 10)

                    // Warning zone (from warnAt to limit)
                    let warnStart = item.warnRatio * w
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: max(0, w - warnStart), height: 10)
                        .offset(x: warnStart)

                    // Actual bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [item.statusColor.opacity(0.7), item.statusColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(item.actualRatio * w, w)), height: 10)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: item.actualRatio)

                    // Warning threshold tick mark
                    Rectangle()
                        .fill(Color.orange.opacity(0.5))
                        .frame(width: 1.5, height: 14)
                        .offset(x: item.warnRatio * w - 0.75, y: -2)

                    // Limit cap (right edge marker)
                    Rectangle()
                        .fill(Color.primary.opacity(0.25))
                        .frame(width: 2, height: 14)
                        .offset(x: w - 1, y: -2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 10)
        }
    }

    // MARK: - Loading / Empty

    private var loadingView: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text("Loading FRMS…")
                .iPadScaledFont(.caption, phoneFont: .footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func formattedHours(_ h: Double) -> String {
        showTimesInHoursMinutes ? FlightSector.decimalToHHMM(h) : String(format: "%.1f", h)
    }

    @MainActor
    private func triggerFRMSLoadIfNeeded() async {
        guard frmsViewModel.cumulativeTotals == nil, !frmsViewModel.isLoading else { return }
        let raw = UserDefaults.standard.string(forKey: "flightTimePosition") ?? ""
        let position = FlightTimePosition(rawValue: raw) ?? .captain
        frmsViewModel.loadFlightData(crewPosition: position)
    }
}
