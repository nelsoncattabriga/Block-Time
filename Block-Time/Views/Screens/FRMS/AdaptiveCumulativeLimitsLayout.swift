//
//  AdaptiveCumulativeLimitsLayout.swift
//  Block-Time
//
//  Adaptive 2-column (iPad) / single-column (iPhone) layout for cumulative
//  flight and duty time limit cards in the FRMS tab.
//  Extracted from FRMSView.swift.
//

import SwiftUI
import BlockTimeKit

struct AdaptiveCumulativeLimitsLayout: View {
    var viewModel: FRMSViewModel
    let totals: FRMSCumulativeTotals
    /// True when inside the iPad split-view detail pane. Used to show
    /// Consecutive Duties in the compact (portrait) layout path, while
    /// keeping it out of the iPhone path (which shows it in Next Duty).
    var isInSplitView: Bool = false
    /// When true, forces Consecutive Duties + Late Night Ops cards to render
    /// in the compact (iPhone) layout regardless of isInSplitView. Used by
    /// the iPhone tab strip Cumulative Limits section.
    var showConsecutiveDutiesInCompact: Bool = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var appViewModel: FlightTimeExtractorViewModel

    var body: some View {
        if horizontalSizeClass == .compact {
            // iPhone layout - single column
            VStack(spacing: 12) {
                createAllCards()
            }
        } else {
            // iPad layout - 2 column grid
            VStack(spacing: 12) {
                // Flight Time section
                frmsSectionHeader("Flight Time")
                let periodDays = viewModel.configuration.fleet.flightTimePeriodDays
                HStack(spacing: 12) {
                    buildLimitCard(
                        title: "Flight Time (\(periodDays) Days)",
                        current: totals.flightTime28Or30Days,
                        limit: viewModel.configuration.fleet.maxFlightTime28Days,
                        status: totals.status28Days,
                        unit: "hrs",
                        accentColor: .blue
                    )

                    buildLimitCard(
                        title: "Flight Time (365 Days)",
                        current: totals.flightTime365Days,
                        limit: viewModel.configuration.fleet.maxFlightTime365Days,
                        status: totals.status365Days,
                        unit: "hrs",
                        accentColor: .blue
                    )
                }

                // Duty Time section
                frmsSectionHeader("Duty Time")
                HStack(spacing: 12) {
                    buildLimitCard(
                        title: "Duty Time (7 Days)",
                        current: totals.dutyTime7Days,
                        limit: viewModel.configuration.effectiveDutyLimit7Days,
                        status: totals.dutyStatus7Days,
                        unit: "hrs",
                        accentColor: .orange
                    )

                    buildLimitCard(
                        title: "Duty Time (14 Days)",
                        current: totals.dutyTime14Days,
                        limit: viewModel.configuration.effectiveDutyLimit14DaysInitial ?? viewModel.configuration.effectiveDutyLimit14Days,
                        status: totals.dutyStatus14Days,
                        unit: "hrs",
                        accentColor: .orange,
                        note: viewModel.configuration.effectiveDutyLimit14DaysInitial != nil ? "100 hrs with pilot agreement" : nil
                    )
                }

                // Consecutive Duties section (A320/B737 only)
                if viewModel.configuration.fleet == .a320B737, totals.hasConsecutiveDutyLimits {
                    frmsSectionHeader("Consecutive Duties")

                    let lno = viewModel.a320B737NextDutyLimits?.lateNightStatus
                    let lnoCount = lno?.lnoCountIn168h ?? 0
                    let lnoMax = lno?.maxLnoIn168h ?? SH_Planning_FltDuty.lnoMaxPeriodsIn168h
                    let bocCount = lno?.bocCountIn168h ?? 0
                    let bocMax = lno?.maxBocIn168h ?? SH_Planning_FltDuty.bocMaxPeriodsIn168h

                    if let maxConsec = totals.maxConsecutiveDuties,
                       let maxDuty11 = totals.maxDutyDaysIn11Days {
                        HStack(spacing: 12) {
                            frmsCounterCard(
                                title: "Consecutive Days",
                                value: totals.consecutiveDuties,
                                max: maxConsec,
                                unit: "days",
                                status: totals.consecutiveDutiesStatus,
                                accentColor: .teal
                            )
                            frmsCounterCard(
                                title: "Duties in 11 Days",
                                value: totals.dutyDaysIn11Days,
                                max: maxDuty11,
                                unit: "days",
                                status: totals.dutyDaysIn11DaysStatus,
                                accentColor: .teal
                            )
                        }
                    }

                    frmsSectionHeader("Late Night Ops")

                    if let maxEarly = totals.maxConsecutiveEarlyStarts,
                       let maxLate = totals.maxConsecutiveLateNights {
                        HStack(spacing: 12) {
                            frmsCounterCard(
                                title: "Early Starts (Consecutive)",
                                value: totals.consecutiveEarlyStarts,
                                max: maxEarly,
                                unit: "duties",
                                status: totals.consecutiveEarlyStartsStatus,
                                accentColor: .indigo
                            )
                            frmsCounterCard(
                                title: "Late Night Ops (Consecutive)",
                                value: totals.consecutiveLateNights,
                                max: maxLate,
                                unit: "duties",
                                status: totals.consecutiveLateNightsStatus,
                                accentColor: .indigo
                            )
                        }
                    }

                    HStack(spacing: 12) {
                        frmsCounterCard(
                            title: "Late Night Ops (Rolling 168 hrs)",
                            value: lnoCount,
                            max: lnoMax,
                            unit: "duties",
                            status: frmsLnoCountStatus(lnoCount, max: lnoMax),
                            accentColor: .indigo
                        )
                        frmsCounterCard(
                            title: "Back of Clock Ops (Rolling 168 hrs)",
                            value: bocCount,
                            max: bocMax,
                            unit: "duties",
                            status: frmsBocCountStatus(bocCount, max: bocMax),
                            accentColor: .indigo
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func createAllCards() -> some View {
        let periodDays = viewModel.configuration.fleet.flightTimePeriodDays
        let compact = !isInSplitView

        // Flight Time section
        frmsSectionHeader("Flight Time")

        if compact {
            frmsCompactLimitCard(
                title: "Flight Time (\(periodDays) Days)",
                valueText: formatValue(totals.flightTime28Or30Days),
                limit: viewModel.configuration.fleet.maxFlightTime28Days,
                unit: "hrs",
                current: totals.flightTime28Or30Days,
                status: totals.status28Days,
                accentColor: .blue
            )
            frmsCompactLimitCard(
                title: "Flight Time (365 Days)",
                valueText: formatValue(totals.flightTime365Days),
                limit: viewModel.configuration.fleet.maxFlightTime365Days,
                unit: "hrs",
                current: totals.flightTime365Days,
                status: totals.status365Days,
                accentColor: .blue
            )
        } else {
            buildLimitCard(
                title: "Flight Time (\(periodDays) Days)",
                current: totals.flightTime28Or30Days,
                limit: viewModel.configuration.fleet.maxFlightTime28Days,
                status: totals.status28Days,
                unit: "hrs",
                accentColor: .blue
            )
            buildLimitCard(
                title: "Flight Time (365 Days)",
                current: totals.flightTime365Days,
                limit: viewModel.configuration.fleet.maxFlightTime365Days,
                status: totals.status365Days,
                unit: "hrs",
                accentColor: .blue
            )
        }

        // Duty Time section
        frmsSectionHeader("Duty Time")

        if compact {
            frmsCompactLimitCard(
                title: "Duty Time (7 Days)",
                valueText: formatValue(totals.dutyTime7Days),
                limit: viewModel.configuration.effectiveDutyLimit7Days,
                unit: "hrs",
                current: totals.dutyTime7Days,
                status: totals.dutyStatus7Days,
                accentColor: .orange
            )
            frmsCompactLimitCard(
                title: "Duty Time (14 Days)",
                valueText: formatValue(totals.dutyTime14Days),
                limit: viewModel.configuration.effectiveDutyLimit14DaysInitial ?? viewModel.configuration.effectiveDutyLimit14Days,
                unit: "hrs",
                current: totals.dutyTime14Days,
                status: totals.dutyStatus14Days,
                accentColor: .orange,
                note: viewModel.configuration.effectiveDutyLimit14DaysInitial != nil ? "100 hrs with pilot agreement" : nil
            )
        } else {
            buildLimitCard(
                title: "Duty Time (7 Days)",
                current: totals.dutyTime7Days,
                limit: viewModel.configuration.effectiveDutyLimit7Days,
                status: totals.dutyStatus7Days,
                unit: "hrs",
                accentColor: .orange
            )
            buildLimitCard(
                title: "Duty Time (14 Days)",
                current: totals.dutyTime14Days,
                limit: viewModel.configuration.effectiveDutyLimit14DaysInitial ?? viewModel.configuration.effectiveDutyLimit14Days,
                status: totals.dutyStatus14Days,
                unit: "hrs",
                accentColor: .orange,
                note: viewModel.configuration.effectiveDutyLimit14DaysInitial != nil ? "100 hrs with pilot agreement" : nil
            )
        }

        // Consecutive Duties section (A320/B737 only) — shown here in compact
        // layout when in split-view (iPad portrait) OR when explicitly requested
        // (iPhone tab strip Cumulative Limits section).
        if (isInSplitView || showConsecutiveDutiesInCompact),
           viewModel.configuration.fleet == .a320B737,
           totals.hasConsecutiveDutyLimits {
            let lno = viewModel.a320B737NextDutyLimits?.lateNightStatus
            let lnoCount = lno?.lnoCountIn168h ?? 0
            let lnoMax = lno?.maxLnoIn168h ?? SH_Planning_FltDuty.lnoMaxPeriodsIn168h
            let bocCount = lno?.bocCountIn168h ?? 0
            let bocMax = lno?.maxBocIn168h ?? SH_Planning_FltDuty.bocMaxPeriodsIn168h

            frmsSectionHeader("Consecutive Duties")

            if let maxConsec = totals.maxConsecutiveDuties {
                frmsCompactCounterCard(title: "Consecutive Days", value: totals.consecutiveDuties, max: maxConsec, unit: "days", status: totals.consecutiveDutiesStatus, accentColor: .teal)
            }
            if let maxDuty11 = totals.maxDutyDaysIn11Days {
                frmsCompactCounterCard(title: "Duties in 11 Days", value: totals.dutyDaysIn11Days, max: maxDuty11, unit: "days", status: totals.dutyDaysIn11DaysStatus, accentColor: .teal)
            }
            frmsSectionHeader("Late Night Ops")

            if let maxEarly = totals.maxConsecutiveEarlyStarts {
                frmsCompactCounterCard(title: "Early Starts (Consecutive)", value: totals.consecutiveEarlyStarts, max: maxEarly, unit: "duties", status: totals.consecutiveEarlyStartsStatus, accentColor: .indigo)
            }
            if let maxLate = totals.maxConsecutiveLateNights {
                frmsCompactCounterCard(title: "Late Night Ops (Consecutive)", value: totals.consecutiveLateNights, max: maxLate, unit: "duties", status: totals.consecutiveLateNightsStatus, accentColor: .indigo)
            }
            frmsCompactCounterCard(title: "Late Night Ops (Rolling 168 hrs)", value: lnoCount, max: lnoMax, unit: "duties", status: frmsLnoCountStatus(lnoCount, max: lnoMax), accentColor: .indigo)
            frmsCompactCounterCard(title: "Back of Clock Ops (Rolling 168 hrs)", value: bocCount, max: bocMax, unit: "duties", status: frmsBocCountStatus(bocCount, max: bocMax), accentColor: .indigo)
        }
    }

    // MARK: - Card Building Functions

    private func buildLimitCard(title: String, current: Double, limit: Double, status: FRMSComplianceStatus, unit: String, accentColor: Color, note: String? = nil) -> some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [accentColor, accentColor.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .foregroundStyle(statusColor(status))
                            .font(.subheadline)
                    }
                }

                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(current) : String(format: "%.1f", current))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text("/ \(Int(limit)) \(unit)")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                frmsThickGauge(value: min(current, limit), total: limit, color: progressColor(status))

                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(accentColor.opacity(0.7))
                        .fontWeight(.medium)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(accentColor.opacity(0.04))
        }
        .appCardStyle()
    }

    private func buildDaysOffCard(daysOff: Int, required: Int) -> some View {
        let periodDays = viewModel.configuration.fleet.flightTimePeriodDays
        let statusColor: Color = daysOff >= required ? .green : .orange
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Days Off (\(periodDays) Days)")
                    .iPadScaledFont(.headline, phoneFont: .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: daysOff >= required ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(statusColor)
                    .iPadScaledFont(.headline, phoneFont: .headline)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(daysOff)")
                    .iPadScaledFont(.subheadline, phoneFont: .subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("/ \(required) days")
                    .iPadScaledFont(.caption, phoneFont: .caption)
                    .foregroundColor(.secondary)
            }

            // Spacer to match the height of ProgressView in buildLimitCard
            Spacer()
                .frame(height: 6)
        }
        .padding(16)
        .appCardStyle()
    }

    // MARK: - Helper Methods (delegate to shared FRMSCardStyles)

    private func statusColor(_ status: FRMSComplianceStatus) -> Color { frmsStatusColor(status) }
    private func progressColor(_ status: FRMSComplianceStatus) -> Color { frmsProgressColor(status) }
    private func formatValue(_ hours: Double) -> String {
        appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(hours) : String(format: "%.1f", hours)
    }
}
