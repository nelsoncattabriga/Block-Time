//
//  SH_NextDutyView.swift
//  Block-Time
//
//  A320/B737 (Short Haul) next duty limits view for the FRMS tab.
//  Extracted from FRMSView.swift.
//

import SwiftUI

/// Rest type selection for 3-pilot SH duties (FD13.1 / FD23.1).
/// Persisted in UserDefaults so the last selection is remembered across sessions.
private enum ThreePilotRestType: String, CaseIterable {
    case class2       = "Class 2"
    case businessSeat = "Business Seat"
}

struct SH_NextDutyView: View {

    @Bindable var viewModel: FRMSViewModel
    /// True when displayed inside the iPad split-view detail pane.
    /// Controls whether the Consecutive Duties card is shown here or
    /// in AdaptiveCumulativeLimitsLayout instead.
    var isInSplitView: Bool = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appViewModel: FlightTimeExtractorViewModel

    @AppStorage("frmsThreePilotRest") private var threePilotRest: ThreePilotRestType = .class2

    // MARK: - Owned State

    enum TimeWindowSelection: String, CaseIterable {
        case early = "0500-1259"
        case afternoon = "1300-1759"
        case night = "1800-0459"
    }
    @State private var selectedTimeWindow: TimeWindowSelection = .early

    @State private var expandSimulator = false
    @State private var expandDaysOff = false
    @State private var expandAnnualLeave = false
    private enum SpecialRuleItem { case splitDuty, reserve, deadheading }
    @State private var expandedSpecialRule: SpecialRuleItem? = nil

    // Retained for dead-code specialScenariosSection
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
                        buildConsecutiveInfoCard(totals: totals, lno: limits.lateNightStatus)
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

            // Active Restrictions inline (if any)
            if (limits.backOfClockRestriction != nil && viewModel.selectedLimitType == .planning) || (limits.lateNightStatus?.hasActiveRestriction == true) || limits.consecutiveDutyStatus.hasActiveRestrictions {
                activeRestrictionsSection(limits: limits)
                Divider()
            }

            // Rev 5: SH flight-time limits removed (FD13.3/FD23.3 deleted).
            maxDutySection(displayWindow: displayWindow)

            Divider()
            specialRulesSection()
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
                    if viewModel.lastDuty?.crewComplement == .threePilot {
                        threePilotRestPicker
                    }
                    signOnWindowSection
                }
            } else {
                // iPad layout
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        limitTypePicker
                            .frame(width: 220)

                        Spacer()

                        signOnWindowSection
                    }
                    if viewModel.lastDuty?.crewComplement == .threePilot {
                        threePilotRestPicker
                    }
                }
            }
        }
    }

    private var threePilotRestPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("3-Pilot Rest Facility")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("3-Pilot Rest", selection: $threePilotRest) {
                ForEach(ThreePilotRestType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
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
            .font(.subheadline)
        }
    }

    private func dutyColumn(title: String, hours: Double, color: Color = AppColors.accentOrange) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formatTime(hours))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    private func maxDutySection(displayWindow: DutyTimeWindow) -> some View {
        let isThreePilot = viewModel.lastDuty?.crewComplement == .threePilot
        return VStack(alignment: .leading, spacing: 12) {
            Text("Max Duty")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            if isThreePilot {
                threePilotMaxDutyRow(displayWindow: displayWindow)
            } else {
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
    }

    /// Reads the correct banded 3-pilot limit from the model static functions
    /// based on the selected sign-on window and rest facility picker.
    private func threePilotMaxDutyRow(displayWindow: DutyTimeWindow) -> some View {
        let rest: SH_Planning_FltDuty.ThreePilotRest = threePilotRest == .class2 ? .class2 : .businessSeat
        let isPlanning = viewModel.selectedLimitType == .planning
        let maxSectors = isPlanning
            ? SH_Planning_FltDuty.threePilotMaxSectors
            : SH_Operational_FltDuty.threePilotMaxSectors

        let dutyHours: Double
        if let band = SH_Planning_FltDuty.LocalStartTime(rawValue: displayWindow.localStartTime) {
            if isPlanning {
                dutyHours = SH_Planning_FltDuty.maxDutyHoursThreePilot(band: band, rest: rest) ?? 14.0
            } else if let opBand = SH_Operational_FltDuty.LocalStartTime(rawValue: displayWindow.localStartTime) {
                dutyHours = SH_Operational_FltDuty.maxDutyHoursThreePilot(band: opBand, rest: rest) ?? 16.0
            } else {
                dutyHours = 14.0
            }
        } else {
            dutyHours = 14.0
        }

        return HStack(spacing: 12) {
            dutyColumn(title: "Max \(maxSectors) Sectors", hours: dutyHours)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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

                    Text("Next Sign-On no earlier than \(formatTime(backOfClock.earliestSignOn))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Late night status — only shown when an active restriction applies
            if let lateNight = limits.lateNightStatus, lateNight.hasActiveRestriction {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "moon")
                            .foregroundStyle(.blue)
                        Text("Late Night Operations")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if lateNight.recoveryOption == .require24HoursOff {
                            lateNightRestrictionRow(
                                label: "Consecutive LNO",
                                value: "\(lateNight.consecutiveLateNights)",
                                detail: "≥24 hours off required before day duty"
                            )
                        }
                        if lateNight.lnoCountIn168h >= lateNight.maxLnoIn168h {
                            lateNightRestrictionRow(
                                label: "LNO / 168 h",
                                value: "\(lateNight.lnoCountIn168h) / \(lateNight.maxLnoIn168h)",
                                detail: "Maximum LNO duties reached"
                            )
                        }
                        if lateNight.bocCountIn168h >= lateNight.maxBocIn168h {
                            lateNightRestrictionRow(
                                label: "BOC / 168 h",
                                value: "\(lateNight.bocCountIn168h) / \(lateNight.maxBocIn168h)",
                                detail: "Maximum BOC duties reached"
                            )
                        }
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
    }

    private func lateNightRestrictionRow(label: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.footnote)
                    .fontWeight(.semibold)
            }
            .frame(width: 90, alignment: .leading)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Special Rules Section

    private func accordionBinding(for item: SpecialRuleItem) -> Binding<Bool> {
        Binding(
            get: { expandedSpecialRule == item },
            set: { expandedSpecialRule = $0 ? item : nil }
        )
    }

    private func specialRulesSection() -> some View {
        let isPlanning = viewModel.selectedLimitType == .planning
        return VStack(alignment: .leading, spacing: 12) {
            Text("Special Rules")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                DisclosureGroup(
                    isExpanded: accordionBinding(for: .splitDuty),
                    content: {
                        splitDutyContent(isPlanning: isPlanning)
                            .padding(.top, 8)
                    },
                    label: {
                        Text("Split Duty")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                )
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                DisclosureGroup(
                    isExpanded: accordionBinding(for: .reserve),
                    content: {
                        reserveDutyContent(isPlanning: isPlanning)
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

                DisclosureGroup(
                    isExpanded: accordionBinding(for: .deadheading),
                    content: {
                        deadheadingContent(isPlanning: isPlanning)
                            .padding(.top, 8)
                    },
                    label: {
                        Text("Deadheading")
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

    private func splitDutyContent(isPlanning: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if isPlanning {
                let rules = SH_Planning_FltDuty.splitDutyRules
                bulletPoint(text: "Min rest: \(Int(rules.minRestHours)) hrs at suitable sleeping accommodation")
                bulletPoint(text: "Max duty increase: +\(Int(rules.maxDutyIncreaseHours)) hrs above FD13.1 limits")
                bulletPoint(text: "Max total duty: \(Int(rules.maxTotalDutyHours)) hrs")
                bulletPoint(text: "Rest discount: \(Int(rules.restDiscountFraction * 100))% (max \(Int(rules.maxRestDiscountHours)) hrs)")
                Text("Night window \(rules.nightWindowStart)–\(rules.nightWindowEnd):")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                bulletPoint(text: "Rest must be uninterrupted ≥\(Int(rules.nightRestMinUninterruptedHours)) hrs")
                bulletPoint(text: "Max FDP \(Int(rules.nightRestMaxTotalDutyHours)) hrs; no rest discounting")
            } else {
                let sleeping = SH_Operational_FltDuty.splitDutyRulesBySleeping
                let resting  = SH_Operational_FltDuty.splitDutyRulesByResting
                Text("Sleeping accommodation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                bulletPoint(text: "Min \(Int(sleeping.minRestHours)) hrs rest → +\(Int(sleeping.maxDutyIncreaseHours)) hrs duty, max \(Int(sleeping.maxTotalDutyHours ?? 0)) hrs")
                if let frac = sleeping.restDiscountFraction, let maxDisc = sleeping.maxRestDiscountHours {
                    bulletPoint(text: "Rest discount: \(Int(frac * 100))% (max \(Int(maxDisc)) hrs)")
                }
                Text("Resting accommodation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                bulletPoint(text: "Min \(Int(resting.minRestHours)) hrs rest → +\(Int(resting.maxDutyIncreaseHours)) hrs duty (no stated max)")
                bulletPoint(text: "No rest discounting")
                Text("Night window \(sleeping.nightWindowStart)–\(sleeping.nightWindowEnd):")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                bulletPoint(text: "Uninterrupted ≥\(Int(sleeping.nightRestMinUninterruptedHours)) hrs; max FDP \(Int(sleeping.nightRestMaxTotalDutyHours)) hrs; no discount")
            }
        }
    }

    private func reserveDutyContent(isPlanning: Bool) -> some View {
        let maxHrs = isPlanning
            ? SH_Planning_FltDuty.reserveDutyMaxConsecutiveHours
            : SH_Operational_FltDuty.reserveDutyMaxConsecutiveHours
        let clause = isPlanning ? "FD13.5" : "FD23.5"
        return VStack(alignment: .leading, spacing: 6) {
            bulletPoint(text: "Max \(Int(maxHrs)) consecutive hrs (\(clause))")
            bulletPoint(text: "Must have suitable sleeping accommodation")
            bulletPoint(text: "Free from all duties associated with employment")
        }
    }

    private func deadheadingContent(isPlanning: Bool) -> some View {
        let maxDuty = isPlanning
            ? SH_Planning_FltDuty.deadheadingAbsoluteMaxDutyHours
            : SH_Operational_FltDuty.deadheadingAbsoluteMaxDutyHours
        let clause = isPlanning ? "FD15" : "FD25"
        return VStack(alignment: .leading, spacing: 6) {
            bulletPoint(text: "Absolute max duty with flight duty: \(Int(maxDuty)) hrs (\(clause).6)")
            bulletPoint(text: "Deadheading counts toward total duty for rest calculation")
            bulletPoint(text: "Last sector if deadhead: does not count toward sector limit")
            bulletPoint(text: "Deadhead before flight duty: counts as a sector")
            if !isPlanning {
                bulletPoint(text: "Operational: may extend FD23.1 limits at pilot discretion (\(clause).2)")
            }
        }
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

    private func buildConsecutiveInfoCard(totals: FRMSCumulativeTotals, lno: LateNightStatus?) -> some View {
        let lnoCount = lno?.lnoCountIn168h ?? 0
        let lnoMax   = lno?.maxLnoIn168h  ?? SH_Planning_FltDuty.lnoMaxPeriodsIn168h
        let bocCount = lno?.bocCountIn168h ?? 0
        let bocMax   = lno?.maxBocIn168h  ?? SH_Planning_FltDuty.bocMaxPeriodsIn168h

        return VStack(spacing: 8) {
            frmsSectionHeader("Consecutive Duties")

            if let maxConsec = totals.maxConsecutiveDuties {
                frmsCompactCounterCard(
                    title: "Consecutive Duties",
                    value: totals.consecutiveDuties,
                    max: maxConsec,
                    unit: "days",
                    status: totals.consecutiveDutiesStatus,
                    accentColor: .teal
                )
            }
            if let maxDuty11 = totals.maxDutyDaysIn11Days {
                frmsCompactCounterCard(
                    title: "Duties in 11 Days",
                    value: totals.dutyDaysIn11Days,
                    max: maxDuty11,
                    unit: "days",
                    status: totals.dutyDaysIn11DaysStatus,
                    accentColor: .teal
                )
            }

            frmsSectionHeader("Late Night Ops")

            if let maxEarly = totals.maxConsecutiveEarlyStarts {
                frmsCompactCounterCard(
                    title: "Early Starts (Consecutive)",
                    value: totals.consecutiveEarlyStarts,
                    max: maxEarly,
                    unit: "duties",
                    status: totals.consecutiveEarlyStartsStatus,
                    accentColor: .indigo
                )
            }
            if let maxLate = totals.maxConsecutiveLateNights {
                frmsCompactCounterCard(
                    title: "Late Night Ops (Consecutive)",
                    value: totals.consecutiveLateNights,
                    max: maxLate,
                    unit: "duties",
                    status: totals.consecutiveLateNightsStatus,
                    accentColor: .indigo
                )
            }
            frmsCompactCounterCard(
                title: "Late Night Ops (Rolling 168 hrs)",
                value: lnoCount,
                max: lnoMax,
                unit: "periods",
                status: frmsLnoCountStatus(lnoCount, max: lnoMax),
                accentColor: .indigo
            )
            frmsCompactCounterCard(
                title: "Back of Clock Ops (Rolling 168 hrs)",
                value: bocCount,
                max: bocMax,
                unit: "periods",
                status: frmsBocCountStatus(bocCount, max: bocMax),
                accentColor: .indigo
            )
        }
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
