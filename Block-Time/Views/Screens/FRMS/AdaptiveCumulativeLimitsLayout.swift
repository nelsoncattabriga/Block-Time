//
//  AdaptiveCumulativeLimitsLayout.swift
//  Block-Time
//
//  Adaptive 2-column (iPad) / single-column (iPhone) layout for cumulative
//  flight and duty time limit cards in the FRMS tab.
//  Extracted from FRMSView.swift.
//

import SwiftUI

struct AdaptiveCumulativeLimitsLayout: View {
    var viewModel: FRMSViewModel
    let totals: FRMSCumulativeTotals
    /// True when inside the iPad split-view detail pane. Used to show
    /// Consecutive Duties in the compact (portrait) layout path, while
    /// keeping it out of the iPhone path (which shows it in Next Duty).
    var isInSplitView: Bool = false

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
                sectionHeader("Flight Time")
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
                sectionHeader("Duty Time")
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
                    sectionHeader("Consecutive Duties")

                    let lno = viewModel.a320B737NextDutyLimits?.lateNightStatus
                    let lnoCount = lno?.lnoCountIn168h ?? 0
                    let lnoMax = lno?.maxLnoIn168h ?? SH_Planning_FltDuty.lnoMaxPeriodsIn168h
                    let bocCount = lno?.bocCountIn168h ?? 0
                    let bocMax = lno?.maxBocIn168h ?? SH_Planning_FltDuty.bocMaxPeriodsIn168h

                    if let maxConsec = totals.maxConsecutiveDuties,
                       let maxDuty11 = totals.maxDutyDaysIn11Days {
                        HStack(spacing: 12) {
                            buildCounterCard(
                                title: "Cons. Days",
                                value: totals.consecutiveDuties,
                                max: maxConsec,
                                unit: "days",
                                status: totals.consecutiveDutiesStatus,
                                accentColor: .teal
                            )
                            buildCounterCard(
                                title: "in 11 Days",
                                value: totals.dutyDaysIn11Days,
                                max: maxDuty11,
                                unit: "days",
                                status: totals.dutyDaysIn11DaysStatus,
                                accentColor: .teal
                            )
                        }
                    }

                    sectionHeader("Late Night Ops")

                    if let maxEarly = totals.maxConsecutiveEarlyStarts,
                       let maxLate = totals.maxConsecutiveLateNights {
                        HStack(spacing: 12) {
                            buildCounterCard(
                                title: "Early Starts",
                                value: totals.consecutiveEarlyStarts,
                                max: maxEarly,
                                unit: "duties",
                                status: totals.consecutiveEarlyStartsStatus,
                                accentColor: .indigo
                            )
                            buildCounterCard(
                                title: "Late Nights",
                                value: totals.consecutiveLateNights,
                                max: maxLate,
                                unit: "duties",
                                status: totals.consecutiveLateNightsStatus,
                                accentColor: .indigo
                            )
                        }
                    }

                    HStack(spacing: 12) {
                        buildCounterCard(
                            title: "LNO Rolling 168 hrs",
                            value: lnoCount,
                            max: lnoMax,
                            unit: "periods",
                            status: lnoCountStatus(lnoCount, max: lnoMax),
                            accentColor: .indigo
                        )
                        buildCounterCard(
                            title: "BOC Rolling 168 hrs",
                            value: bocCount,
                            max: bocMax,
                            unit: "periods",
                            status: bocCountStatus(bocCount, max: bocMax),
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

        // Flight Time section
        sectionHeader("Flight Time")

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

        // Duty Time section
        sectionHeader("Duty Time")

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

        // Consecutive Duties section (A320/B737 only) — shown here in compact
        // layout only when in split-view (iPad portrait). On iPhone it remains
        // in the Next Duty section via a320B737NextDutyContent.
        if isInSplitView,
           viewModel.configuration.fleet == .a320B737,
           totals.hasConsecutiveDutyLimits {
            let lno = viewModel.a320B737NextDutyLimits?.lateNightStatus
            let lnoCount = lno?.lnoCountIn168h ?? 0
            let lnoMax = lno?.maxLnoIn168h ?? SH_Planning_FltDuty.lnoMaxPeriodsIn168h
            let bocCount = lno?.bocCountIn168h ?? 0
            let bocMax = lno?.maxBocIn168h ?? SH_Planning_FltDuty.bocMaxPeriodsIn168h

            sectionHeader("Consecutive Duties")

            if let maxConsec = totals.maxConsecutiveDuties {
                buildCounterCard(title: "Cons. Days", value: totals.consecutiveDuties, max: maxConsec, unit: "days", status: totals.consecutiveDutiesStatus, accentColor: .teal)
            }
            if let maxDuty11 = totals.maxDutyDaysIn11Days {
                buildCounterCard(title: "in 11 Days", value: totals.dutyDaysIn11Days, max: maxDuty11, unit: "days", status: totals.dutyDaysIn11DaysStatus, accentColor: .teal)
            }
            sectionHeader("Late Night Ops")

            if let maxEarly = totals.maxConsecutiveEarlyStarts {
                buildCounterCard(title: "Early Starts", value: totals.consecutiveEarlyStarts, max: maxEarly, unit: "duties", status: totals.consecutiveEarlyStartsStatus, accentColor: .indigo)
            }
            if let maxLate = totals.maxConsecutiveLateNights {
                buildCounterCard(title: "Late Nights", value: totals.consecutiveLateNights, max: maxLate, unit: "duties", status: totals.consecutiveLateNightsStatus, accentColor: .indigo)
            }
            buildCounterCard(title: "LNO / 168 h", value: lnoCount, max: lnoMax, unit: "periods", status: lnoCountStatus(lnoCount, max: lnoMax), accentColor: .indigo)
            buildCounterCard(title: "BOC / 168 h", value: bocCount, max: bocMax, unit: "periods", status: bocCountStatus(bocCount, max: bocMax), accentColor: .indigo)
        }
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .iPadScaledFont(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .kerning(1.2)

            Rectangle()
                .fill(.secondary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.top, 8)
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
                        .iPadScaledFont(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .foregroundStyle(statusColor(status))
                            .iPadScaledFont(.subheadline)
                    }
                }

                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(current) : String(format: "%.1f", current))
                        .iPadScaledFont(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text("/ \(Int(limit)) \(unit)")
                        .iPadScaledFont(.footnote)
                        .foregroundStyle(.tertiary)
                }

                thickGauge(value: min(current, limit), total: limit, color: progressColor(status))

                if let note {
                    Text(note)
                        .iPadScaledFont(.caption)
                        .foregroundStyle(accentColor.opacity(0.7))
                        .fontWeight(.medium)
                } else {
                    Text(" ")
                        .iPadScaledFont(.caption)
                        .hidden()
                }
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
                    .iPadScaledFont(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: daysOff >= required ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(statusColor)
                    .iPadScaledFont(.headline)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(daysOff)")
                    .iPadScaledFont(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("/ \(required) days")
                    .iPadScaledFont(.caption)
                    .foregroundColor(.secondary)
            }

            // Spacer to match the height of ProgressView in buildLimitCard
            Spacer()
                .frame(height: 6)
        }
        .padding(16)
        .appCardStyle()
    }

    private func buildCounterCard(title: String, value: Int, max: Int, unit: String, status: FRMSComplianceStatus, accentColor: Color) -> some View {
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
                        .iPadScaledFont(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: status.icon)
                        .foregroundStyle(statusColor(status))
                        .iPadScaledFont(.subheadline)
                }

                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("\(value)")
                        .iPadScaledFont(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(statusColor(status))
                        .monospacedDigit()

                    Text("/ \(max) \(unit)")
                        .iPadScaledFont(.footnote)
                        .foregroundStyle(.tertiary)
                }

                thickGauge(value: Double(value), total: Double(max), color: progressColor(status))

                Text(" ")
                    .iPadScaledFont(.caption)
                    .hidden()
            }
            .padding(16)
            .background(accentColor.opacity(0.04))
        }
        .appCardStyle()
    }

    private func thickGauge(value: Double, total: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 5)

                Capsule()
                    .fill(color)
                    .frame(width: total > 0 ? geo.size.width * CGFloat(min(value / total, 1.0)) : 0, height: 5)
            }
        }
        .frame(height: 5)
    }

    private func lnoCountStatus(_ count: Int, max: Int) -> FRMSComplianceStatus {
        if count >= max { return .violation(message: "Maximum LNO periods in 168 hours reached") }
        if count >= max - 1 { return .warning(message: "Approaching LNO limit") }
        return .compliant
    }

    private func bocCountStatus(_ count: Int, max: Int) -> FRMSComplianceStatus {
        if count >= max { return .violation(message: "Maximum BOC periods in 168 hours reached") }
        if count >= max - 1 { return .warning(message: "Approaching BOC limit") }
        return .compliant
    }

    // MARK: - Helper Methods

    private func statusColor(_ status: FRMSComplianceStatus) -> Color {
        switch status {
        case .compliant: return .green
        case .warning: return .orange
        case .violation: return .red
        }
    }

    private func progressColor(_ status: FRMSComplianceStatus) -> Color {
        switch status {
        case .compliant: return .blue
        case .warning: return .orange
        case .violation: return .red
        }
    }

    private func percentageOfLimit(used: Double, limit: Double) -> Double {
        guard limit > 0 else { return 0 }
        return (used / limit) * 100.0
    }
}
