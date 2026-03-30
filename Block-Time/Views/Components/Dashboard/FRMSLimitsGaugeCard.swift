//
//  FRMSLimitsGaugeCard.swift
//  Block-Time
//
//  Horizontal fuel-bar gauges for all active FRMS rolling limits.
//  Shows actual hours consumed, a projected-future overlay (upcoming
//  scheduled flights), warning zone, and a hard-limit tick mark.
//
//  Projected hours come from flights that have an STD but no actual
//  OUT/IN time — i.e., future roster entries stored in Core Data.
//
//  Each gauge row shows:
//    [■■■■■░░░░░░░░|] 68.4 / 100 hrs
//     actual  projected  limit
//

import SwiftUI
import Charts

// MARK: - Data Model

struct FRMSLimitGaugeItem: Identifiable {
    let id = UUID()
    let label: String          // e.g. "28 Days", "365 Days"
    let sublabel: String       // e.g. "Flight Time", "Duty Time"
    let actual: Double         // Hours already flown/worked (current rolling total)
    let projected: Double      // Peak rolling total if all rostered duties are flown
    let limit: Double          // Hard limit (FRMS max)
    let warnAt: Double         // Warning threshold (default 0.9 * limit)
    let accentColor: Color     // Track colour

    var actualRatio: Double { limit > 0 ? min(actual / limit, 1.0) : 0 }
    // projected is already an absolute rolling total, not additive
    var projectedRatio: Double { limit > 0 ? min(projected / limit, 1.0) : 0 }
    var warnRatio: Double { limit > 0 ? warnAt / limit : 0 }

    // projected bar only shows if it exceeds actual (i.e. roster adds meaningful exposure)
    var hasProjected: Bool { projected > actual }

    var statusColor: Color {
        let r = actualRatio
        if r >= 1.0 { return .red }
        if r >= warnRatio { return .orange }
        return accentColor
    }

    var projectedStatusColor: Color {
        let r = projectedRatio
        if r >= 1.0 { return .red.opacity(0.6) }
        if r >= warnRatio { return .orange.opacity(0.5) }
        return accentColor.opacity(0.35)
    }
}

// MARK: - Card View

struct FRMSLimitsGaugeCard: View {
    var frmsViewModel: FRMSViewModel
    let strip: NDFRMSStripData

    // Projected hours for upcoming scheduled (non-completed) flights
    // These are passed in from a lightweight query on the dashboard ViewModel.
    var projectedFlightHours7d: Double = 0
    var projectedFlightHours28d: Double = 0
    var projectedFlightHours365d: Double = 0
    var projectedDutyHours7d: Double = 0
    var projectedDutyHours14d: Double = 0

    private var totals: FRMSCumulativeTotals? { frmsViewModel.cumulativeTotals }
    private var fleet: FRMSFleet { strip.fleet }
    private var config: FRMSConfiguration { frmsViewModel.configuration }

    private var warnFraction: Double { config.showWarningsAtPercentage }

    // Build the gauge items from live FRMS data
    // Always uses real projected values — the toggle controls opacity in the view layer.
    private var gaugeItems: [FRMSLimitGaugeItem] {
        var items: [FRMSLimitGaugeItem] = []

        // Flight time: 7-day (LH only)
        if let max7d = fleet.maxFlightTime7Days {
            items.append(FRMSLimitGaugeItem(
                label: "7 Days",
                sublabel: "Flight Time",
                actual: strip.hours7d,
                projected: projectedFlightHours7d,
                limit: max7d,
                warnAt: warnFraction * max7d,
                accentColor: .blue
            ))
        }

        // Flight time: 28/30-day
        items.append(FRMSLimitGaugeItem(
            label: "\(fleet.flightTimePeriodDays) Days",
            sublabel: "Flight Time",
            actual: strip.hours28d,
            projected: projectedFlightHours28d,
            limit: strip.max28d,
            warnAt: warnFraction * strip.max28d,
            accentColor: .blue
        ))

        // Flight time: 365-day
        items.append(FRMSLimitGaugeItem(
            label: "365 Days",
            sublabel: "Flight Time",
            actual: strip.hours365d,
            projected: projectedFlightHours365d,
            limit: strip.max365d,
            warnAt: warnFraction * strip.max365d,
            accentColor: .blue
        ))

        // Duty time: 7-day
        items.append(FRMSLimitGaugeItem(
            label: "7 Days",
            sublabel: "Duty Time",
            actual: totals?.dutyTime7Days ?? 0,
            projected: projectedDutyHours7d,
            limit: fleet.maxDutyTime7Days,
            warnAt: warnFraction * fleet.maxDutyTime7Days,
            accentColor: .orange
        ))

        // Duty time: 14-day
        let limit14d = fleet.maxDutyTime14DaysInitial ?? fleet.maxDutyTime14Days
        items.append(FRMSLimitGaugeItem(
            label: "14 Days",
            sublabel: "Duty Time",
            actual: totals?.dutyTime14Days ?? 0,
            projected: projectedDutyHours14d,
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

                    if item.hasProjected {
                        HStack(spacing: 2) {
                            Text("→")
                                .iPadScaledFont(.caption, phoneFont: .footnote)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(formattedHours(item.projected))
                                .iPadScaledFont(.caption, phoneFont: .footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(item.projectedStatusColor.opacity(1.5))
                        }
                    }

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

                    // Projected bar — shows peak rolling total, sits behind the actual bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.projectedStatusColor)
                        .frame(width: max(0, min(item.projectedRatio * w, w)), height: 10)
                        .opacity(item.hasProjected ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: item.projectedRatio)

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
        String(format: "%.1f", h)
    }

    @MainActor
    private func triggerFRMSLoadIfNeeded() async {
        guard frmsViewModel.cumulativeTotals == nil, !frmsViewModel.isLoading else { return }
        let raw = UserDefaults.standard.string(forKey: "flightTimePosition") ?? ""
        let position = FlightTimePosition(rawValue: raw) ?? .captain
        frmsViewModel.loadFlightData(crewPosition: position)
    }
}
