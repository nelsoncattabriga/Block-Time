//
//  SH_NextDutyView.swift
//  Block-Time
//
//  A320/B737 (Short Haul) next duty limits view for the FRMS tab.
//  Extracted from FRMSView.swift.
//

import SwiftUI

struct SH_NextDutyView: View {

    @Bindable var viewModel: FRMSViewModel
    /// True when displayed inside the iPad split-view detail pane.
    /// Controls whether the Consecutive Duties card is shown here or
    /// in AdaptiveCumulativeLimitsLayout instead.
    var isInSplitView: Bool = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appViewModel: FlightTimeExtractorViewModel

    // MARK: - Owned State

    enum TimeWindowSelection: String, CaseIterable {
        case early = "0500-1459"
        case afternoon = "1500-1959"
        case night = "2000-0459"
    }
    @State private var selectedTimeWindow: TimeWindowSelection = .early

    @State private var expandSimulator = false
    @State private var expandDaysOff = false
    @State private var expandAnnualLeave = false
    @State private var expandReserve = false
    @State private var expandDeadheading = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let limits = viewModel.a320B737NextDutyLimits, let totals = viewModel.cumulativeTotals {
                VStack(alignment: .leading, spacing: 16) {
                    // Consecutive Duties Summary — iPhone only when not in split view.
                    // On iPad (split view), it's shown inside AdaptiveCumulativeLimitsLayout instead.
                    if totals.hasConsecutiveDutyLimits && horizontalSizeClass == .compact && !isInSplitView {
                        buildConsecutiveInfoCard(totals: totals)
                    }

                    // Active Restrictions (if any)
                    if (limits.backOfClockRestriction != nil && viewModel.selectedLimitType == .planning) || limits.lateNightStatus != nil || limits.consecutiveDutyStatus.hasActiveRestrictions {
                        activeRestrictionsSection(limits: limits)
                    }

                    // Next Duty Limits Title
                    Text("Next Duty Limits")
                        .font(.title3)
                        .fontWeight(.semibold)

                    // Max Duty Card (with controls inside)
                    maxDutyCard(limits: limits)
                }
            } else {
                Text("No duty data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    // MARK: - Max Duty Card

    private func maxDutyCard(limits: A320B737NextDutyLimits) -> some View {
        let displayWindow = getSelectedWindow(limits: limits, selection: selectedTimeWindow)

        return VStack(alignment: .leading, spacing: 16) {

            // Adaptive Header
            headerSection

            Divider()

            if horizontalSizeClass == .compact {
                // iPhone: Vertical stack
                VStack(alignment: .leading, spacing: 16) {
                    maxDutySection(displayWindow: displayWindow)
                    Divider()
                    maxFlightTimeSection(displayWindow: displayWindow)
                }
            } else {
                // iPad: Horizontal layout
                HStack(alignment: .top, spacing: 20) {
                    maxDutySection(displayWindow: displayWindow)

                    Divider()
                        .frame(maxHeight: .infinity)

                    maxFlightTimeSection(displayWindow: displayWindow)
                }
            }
        }
        .padding()
        .appCardStyle()
        .onAppear {
            updateTimeWindowSelection(limits: limits)
        }
        .onChange(of: viewModel.selectedLimitType) { _, _ in
            updateTimeWindowSelection(limits: limits)
        }
    }

    private var headerSection: some View {
        Group {
            if horizontalSizeClass == .compact {
                // iPhone layout
                VStack(alignment: .leading, spacing: 12) {
                    limitTypePicker
                    signOnWindowSection
                }
            } else {
                // iPad layout
                HStack {
                    limitTypePicker
                        .frame(width: 220)

                    Spacer()

                    signOnWindowSection
                }
            }
        }
    }

    private var limitTypePicker: some View {
        Picker("Limit Type", selection: $viewModel.selectedLimitType) {
            Text("Planning").tag(FRMSLimitType.planning)
            Text("Operational").tag(FRMSLimitType.operational)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : nil)
    }

    private var signOnWindowSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Sign-On Window")
                .font(.headline)
                .foregroundStyle(.secondary)

            Picker("Time Window", selection: $selectedTimeWindow) {
                ForEach(TimeWindowSelection.allCases, id: \.self) { window in
                    Text(window.rawValue).tag(window)
                }
            }
            .pickerStyle(.menu)
            .font(.caption)
        }
    }

    private func dutyColumn(title: String, hours: Double, color: Color = AppColors.accentOrange) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formatTime(hours))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    private func maxDutySection(displayWindow: DutyTimeWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Max Duty")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                dutyColumn(title: "1-4 Sectors", hours: displayWindow.limits.maxDutySectors1to4)
                Divider().frame(height: 35)
                dutyColumn(title: "5 Sectors",   hours: displayWindow.limits.maxDutySectors5)
                Divider().frame(height: 35)
                dutyColumn(title: "6 Sectors",   hours: displayWindow.limits.maxDutySectors6)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func maxFlightTimeSection(displayWindow: DutyTimeWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Max Flight Time")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // Planning (FD13.3) and Operational (FD23.3) have identical flight time conditions
            HStack(spacing: 12) {
                dutyColumn(title: "1 Sector",      hours: 10.5, color: AppColors.accentBlue)
                Divider().frame(height: 35)
                dutyColumn(title: "2+ Sectors",    hours: 10.0, color: AppColors.accentBlue)
                Divider().frame(height: 35)
                dutyColumn(title: "> 7 hrs Night", hours: 9.5,  color: AppColors.accentBlue)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Active Restrictions

    private func activeRestrictionsSection(limits: A320B737NextDutyLimits) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Restrictions")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Back of clock restriction — FD14.4 (planning only, not in operational chapter)
            if let backOfClock = limits.backOfClockRestriction, viewModel.selectedLimitType == .planning {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Back of Clock Restriction")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(backOfClock.reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Next Sign-on no earlier than \(formatTime(backOfClock.earliestSignOn))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Late night status
            if let lateNight = limits.lateNightStatus {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "moon")
                            .foregroundStyle(.blue)
                        Text("Late Night Operations")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Consecutive Nights")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(lateNight.consecutiveLateNights) / \(lateNight.maxConsecutiveLateNights)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Duty Hours (7 nights)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(formatHoursMinutes(lateNight.dutyHoursIn7Nights)) / \(formatHoursMinutes(lateNight.maxDutyHoursIn7Nights)) hrs")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }

                    if lateNight.recoveryOption != .noRestriction {
                        Text(lateNight.recoveryOption.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Consecutive duty status
            if limits.consecutiveDutyStatus.hasActiveRestrictions {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.orange)
                        Text("Consecutive Duty Limits")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    let status = limits.consecutiveDutyStatus
                    VStack(alignment: .leading, spacing: 4) {
                        if status.consecutiveDuties >= status.maxConsecutiveDuties {
                            Text("Max \(status.maxConsecutiveDuties) consecutive duty days reached")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if status.dutyDaysIn11Days >= status.maxDutyDaysIn11Days {
                            Text("Max \(status.maxDutyDaysIn11Days) duty days in 11-day period reached")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if status.consecutiveEarlyStarts >= status.maxConsecutiveEarlyStarts {
                            Text("Max \(status.maxConsecutiveEarlyStarts) consecutive early starts reached")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle()
    }

    // MARK: - Special Scenarios

    private func specialScenariosSection(scenarios: SpecialScenarios) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Special Scenarios")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                // Simulator Training
                if let simulator = scenarios.simulatorRestrictions {
                    DisclosureGroup(
                        isExpanded: $expandSimulator,
                        content: {
                            VStack(alignment: .leading, spacing: 6) {
                                if let dayBefore = simulator.dayBeforeRestriction {
                                    bulletPoint(text: dayBefore)
                                }
                                if let rest = simulator.restBeforeSimulator {
                                    bulletPoint(text: "Minimum \(formatHoursMinutes(rest)) hours rest before simulator")
                                }
                                if let sameDay = simulator.sameDayProhibition {
                                    bulletPoint(text: sameDay)
                                }
                                Text("Applies to: \(simulator.applicableRegion)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            Text("Simulator Training")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Days Off (X Days)
                if let daysOff = scenarios.daysOffRequirements {
                    DisclosureGroup(
                        isExpanded: $expandDaysOff,
                        content: {
                            VStack(alignment: .leading, spacing: 6) {
                                bulletPoint(text: "Before: \(daysOff.dutyBeforeXDay)")
                                bulletPoint(text: "After: \(daysOff.dutyAfterXDay)")
                                bulletPoint(text: "Minimum: \(formatHoursMinutes(daysOff.minimumDuration)) hours")
                                if let exception = daysOff.operationalException {
                                    bulletPoint(text: exception)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            Text("Days Off (X Days)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Annual Leave
                if let annualLeave = scenarios.annualLeaveRestrictions {
                    DisclosureGroup(
                        isExpanded: $expandAnnualLeave,
                        content: {
                            VStack(alignment: .leading, spacing: 6) {
                                bulletPoint(text: "Before: \(annualLeave.beforeLeaveRestriction)")
                                bulletPoint(text: "After: \(annualLeave.afterLeaveRestriction)")
                                if let minDays = annualLeave.minimumLeaveDays {
                                    bulletPoint(text: "Applies to leave ≥\(minDays) days (NZ)")
                                }
                                if annualLeave.canWaive {
                                    bulletPoint(text: "Pilot may agree to waive")
                                        .foregroundStyle(.blue)
                                }
                                Text("Applies to: \(annualLeave.applicableRegion)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            Text("Annual Leave Adjacency")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Reserve Duty
                if let reserve = scenarios.reserveDutyRules {
                    DisclosureGroup(
                        isExpanded: $expandReserve,
                        content: {
                            VStack(alignment: .leading, spacing: 6) {
                                bulletPoint(text: "After callout: \(reserve.afterCalloutRest)")
                                bulletPoint(text: "Without callout: \(reserve.withoutCalloutRest)")
                                bulletPoint(text: "Between reserves: \(reserve.betweenReservePeriods)")
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            Text("Reserve Duty")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Deadheading
                if let deadheading = scenarios.deadheadingLimitations {
                    DisclosureGroup(
                        isExpanded: $expandDeadheading,
                        content: {
                            VStack(alignment: .leading, spacing: 6) {
                                bulletPoint(text: "Absolute maximum: \(formatHoursMinutes(deadheading.absoluteMaximum)) hours total duty")
                                bulletPoint(text: deadheading.restCalculationNote)
                                bulletPoint(text: deadheading.sectorCountingRule)
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            Text("Deadheading Limitations")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .appCardStyle()
    }

    private func bulletPoint(text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.subheadline)
            Text(text).font(.subheadline)
        }
    }

    // MARK: - Consecutive Duties Card

    private func buildConsecutiveInfoCard(totals: FRMSCumulativeTotals) -> some View {
        let worst = worstConsecutiveStatus(totals: totals)
        return HStack(spacing: 0) {
            Rectangle()
                .fill(Color.teal)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Consecutive Duties")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: worst.icon)
                        .foregroundStyle(statusColor(worst))
                        .font(.headline)
                }

                HStack(spacing: 16) {
                    if let maxConsec = totals.maxConsecutiveDuties {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.consecutiveDuties)")
                                    .font(.headline).fontWeight(.bold)
                                    .foregroundStyle(statusColor(totals.consecutiveDutiesStatus))
                                Text("/\(maxConsec)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Text("Cons. Days").font(.footnote).foregroundStyle(.primary)
                        }
                    }

                    if let maxDuty11 = totals.maxDutyDaysIn11Days {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.dutyDaysIn11Days)")
                                    .font(.headline).fontWeight(.bold)
                                    .foregroundStyle(statusColor(totals.dutyDaysIn11DaysStatus))
                                Text("/\(maxDuty11)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Text("in 11 Days").font(.footnote).foregroundStyle(.primary)
                        }
                    }

                    if let maxEarly = totals.maxConsecutiveEarlyStarts {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.consecutiveEarlyStarts)")
                                    .font(.headline).fontWeight(.bold)
                                    .foregroundStyle(statusColor(totals.consecutiveEarlyStartsStatus))
                                Text("/\(maxEarly)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Text("Early Starts").font(.footnote).foregroundStyle(.primary)
                        }
                    }

                    if let maxLate = totals.maxConsecutiveLateNights {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.consecutiveLateNights)")
                                    .font(.headline).fontWeight(.bold)
                                    .foregroundStyle(statusColor(totals.consecutiveLateNightsStatus))
                                Text("/\(maxLate)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Text("Late Nights").font(.footnote).foregroundStyle(.primary)
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

    // MARK: - Window Selection Logic

    private func updateTimeWindowSelection(limits: A320B737NextDutyLimits) {
        let applicableWindow = determineApplicableWindow(limits: limits)

        switch applicableWindow.localStartTime {
        case limits.earlyWindow.localStartTime:
            selectedTimeWindow = .early
        case limits.afternoonWindow.localStartTime:
            selectedTimeWindow = .afternoon
        default:
            selectedTimeWindow = .night
        }
    }

    private func determineApplicableWindow(limits: A320B737NextDutyLimits) -> DutyTimeWindow {
        if limits.earlyWindow.isCurrentlyAvailable {
            return limits.earlyWindow
        } else if limits.afternoonWindow.isCurrentlyAvailable {
            return limits.afternoonWindow
        } else {
            return limits.nightWindow
        }
    }

    private func getSelectedWindow(limits: A320B737NextDutyLimits, selection: TimeWindowSelection) -> DutyTimeWindow {
        switch selection {
        case .early:     return limits.earlyWindow
        case .afternoon: return limits.afternoonWindow
        case .night:     return limits.nightWindow
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: FRMSComplianceStatus) -> Color {
        switch status {
        case .compliant: return .green
        case .warning:   return .orange
        case .violation: return .red
        }
    }

    /// Formats decimal hours respecting the Flight Times display setting.
    private func formatTime(_ decimalHours: Double) -> String {
        if appViewModel.showTimesInHoursMinutes {
            return decimalHours.toHoursMinutesString
        } else {
            return String(format: "%.1f hrs", decimalHours)
        }
    }

    private static let _timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HHmm"
        return f
    }()

    /// Formats a Date to a 4-digit UTC time string (e.g. "0830").
    private func formatTime(_ date: Date) -> String {
        Self._timeFormatter.string(from: date)
    }
}
