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
                        limit: viewModel.configuration.fleet.maxDutyTime7Days,
                        status: totals.dutyStatus7Days,
                        unit: "hrs",
                        accentColor: .orange
                    )

                    buildLimitCard(
                        title: "Duty Time (14 Days)",
                        current: totals.dutyTime14Days,
                        limit: viewModel.configuration.fleet.maxDutyTime14DaysInitial ?? viewModel.configuration.fleet.maxDutyTime14Days,
                        status: totals.dutyStatus14Days,
                        unit: "hrs",
                        accentColor: .orange,
                        note: viewModel.configuration.fleet.maxDutyTime14DaysInitial != nil ? "100 hrs with pilot agreement" : nil
                    )
                }

                // Row 3: Consecutive Duties (A320/B737 only)
                if viewModel.configuration.fleet == .a320B737 {
                    HStack(spacing: 12) {
                        if totals.hasConsecutiveDutyLimits {
                            buildConsecutiveInfoCard(totals: totals)
                        }

                        // Empty space to maintain half-width layout
                        Spacer()
                            .frame(maxWidth: .infinity)
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
            limit: viewModel.configuration.fleet.maxDutyTime7Days,
            status: totals.dutyStatus7Days,
            unit: "hrs",
            accentColor: .orange
        )

        buildLimitCard(
            title: "Duty Time (14 Days)",
            current: totals.dutyTime14Days,
            limit: viewModel.configuration.fleet.maxDutyTime14DaysInitial ?? viewModel.configuration.fleet.maxDutyTime14Days,
            status: totals.dutyStatus14Days,
            unit: "hrs",
            accentColor: .orange,
            note: viewModel.configuration.fleet.maxDutyTime14DaysInitial != nil ? "100 hrs with pilot agreement" : nil
        )

        // Consecutive Duties (A320/B737 only) — shown here in compact layout
        // only when in split-view (iPad portrait). On iPhone it remains in
        // the Next Duty section via a320B737NextDutyContent.
        if isInSplitView,
           viewModel.configuration.fleet == .a320B737,
           totals.hasConsecutiveDutyLimits {
            buildConsecutiveInfoCard(totals: totals)
        }
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .bold()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    // MARK: - Card Building Functions

    private func buildLimitCard(title: String, current: Double, limit: Double, status: FRMSComplianceStatus, unit: String, accentColor: Color, note: String? = nil) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .iPadScaledFont(.headline)
                        .bold()
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: status.icon)
                        .foregroundStyle(statusColor(status))
                        .iPadScaledFont(.headline)
                }

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(current) : current.formatted(.number.precision(.fractionLength(1))))
                        .iPadScaledFont(.subheadline)
                        .bold()
                        .foregroundStyle(.primary)

                    Text("/ \(Int(limit)) \(unit)")
                        .iPadScaledFont(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: min(current, limit), total: limit)
                    .tint(progressColor(status))

                if let note {
                    Text(note)
                        .iPadScaledFont(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
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
                    .bold()
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: daysOff >= required ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(statusColor)
                    .iPadScaledFont(.headline)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(daysOff)")
                    .iPadScaledFont(.subheadline)
                    .bold()
                    .foregroundStyle(.primary)

                Text("/ \(required) days")
                    .iPadScaledFont(.caption)
                    .foregroundStyle(.secondary)
            }

            // Spacer to match the height of ProgressView in buildLimitCard
            Spacer()
                .frame(height: 6)
        }
        .padding(16)
        .appCardStyle()
    }

    private func buildConsecutiveInfoCard(totals: FRMSCumulativeTotals) -> some View {
        let worst = worstConsecutiveStatus(totals: totals)
        return HStack(spacing: 0) {
            Rectangle()
                .fill(Color.teal)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Consecutive Duties")
                        .iPadScaledFont(.headline)
                        .bold()
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: worst.icon)
                        .foregroundStyle(statusColor(worst))
                        .iPadScaledFont(.headline)
                }

                HStack(spacing: 16) {
                    if let maxConsec = totals.maxConsecutiveDuties {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.consecutiveDuties)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundStyle(statusColor(totals.consecutiveDutiesStatus))
                                Text("/\(maxConsec)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Cons. Days")
                                .font(.footnote)
                                .foregroundStyle(.primary)
                        }
                    }

                    if let maxDuty11 = totals.maxDutyDaysIn11Days {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.dutyDaysIn11Days)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundStyle(statusColor(totals.dutyDaysIn11DaysStatus))
                                Text("/\(maxDuty11)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("in 11 Days")
                                .font(.footnote)
                                .foregroundStyle(.primary)
                        }
                    }

                    if let maxEarly = totals.maxConsecutiveEarlyStarts {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.consecutiveEarlyStarts)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundStyle(statusColor(totals.consecutiveEarlyStartsStatus))
                                Text("/\(maxEarly)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Early Starts")
                                .font(.footnote)
                                .foregroundStyle(.primary)
                        }
                    }

                    if let maxLate = totals.maxConsecutiveLateNights {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.consecutiveLateNights)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundStyle(statusColor(totals.consecutiveLateNightsStatus))
                                Text("/\(maxLate)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Late Nights")
                                .font(.footnote)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .appCardStyle()
    }

    private func worstConsecutiveStatus(totals: FRMSCumulativeTotals) -> FRMSComplianceStatus {
        let statuses = [
            totals.consecutiveDutiesStatus,
            totals.dutyDaysIn11DaysStatus,
            totals.consecutiveEarlyStartsStatus,
            totals.consecutiveLateNightsStatus
        ]
        if statuses.contains(where: { if case .violation = $0 { return true }; return false }) {
            return .violation(message: "")
        }
        if statuses.contains(where: { if case .warning = $0 { return true }; return false }) {
            return .warning(message: "")
        }
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
