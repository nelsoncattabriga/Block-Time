//
//  FRMSView.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) Tab View
//  Displays flight/duty time limits and maximum next duty calculator
//

import SwiftUI

// MARK: - Helper Functions

private func formatHoursMinutes(_ decimalHours: Double) -> String {
    // Use standardized conversion with proper rounding
    return decimalHours.toHoursMinutesString
}

struct FRMSView: View {

    @ObservedObject var viewModel: FRMSViewModel
    let flightTimePosition: FlightTimePosition
    @Environment(ThemeService.self) private var themeService
    @EnvironmentObject var appViewModel: FlightTimeExtractorViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var selectedCrewComplement: CrewComplement = .fourPilot
    @State private var selectedRestFacility: RestFacilityClass = .class1

    // Time window selection for SH duty limits display
    enum TimeWindowSelection: String, CaseIterable {
        case early = "0500-1459"
        case afternoon = "1500-1959"
        case night = "2000-0459"
    }
    @State private var selectedTimeWindow: TimeWindowSelection = .early

    // MBTT parameters (for A380/A330/B787)
    @State private var mbttDaysAwayCategory: String = "2-4"  // Options: "1", "2-4", "5-8", "9-12", ">12"
    @State private var mbttCreditedHoursCategory: String = "≤20"  // Options: "≤20", ">20", ">40", ">60"
    @State private var mbttHadDutyOver18Hours: Bool = false
    @State private var calculatedMBTT: FRMSMinimumBaseTurnaroundTime? = nil

    // Special Scenarios expansion state (for widebody fleet)
    @State private var expandSimulator = false
    @State private var expandDaysOff = false
    @State private var expandAnnualLeave = false
    @State private var expandReserve = false
    @State private var expandDeadheading = false

    // LH section expansion state
    @State private var expandNextDutyLimits = true
    @State private var expandMinimumBaseTurnaround = true
    @State private var expandRecentDuties = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()

                ZStack {
                    ScrollView {
                        VStack(spacing: 20) {

                            // Minimum Rest / Earliest Sign-On Section (A320/B737 only)
                            if viewModel.configuration.fleet == .a320B737,
                               let limits = viewModel.a320B737NextDutyLimits {
                                minimumRestSection(limits: limits)
                            }

                            // Cumulative Limits Section
                            cumulativeLimitsSection

                            // Maximum Next Duty Calculator
                            if viewModel.configuration.fleet == .a380A330B787 {
                                VStack(alignment: .leading, spacing: 16) {
                                    DisclosureGroup(
                                        isExpanded: $expandNextDutyLimits,
                                        content: {
                                            VStack(spacing: 16) {
                                                // iPhone: Show toggle at top when expanded
                                                if horizontalSizeClass == .compact {
                                                    Picker("Limit Type", selection: $viewModel.selectedLimitType) {
                                                        Text("Planning").tag(FRMSLimitType.planning)
                                                        Text("Operational").tag(FRMSLimitType.operational)
                                                    }
                                                    .pickerStyle(.segmented)
                                                }
                                                maximumNextDutySection
                                            }
                                            .padding(.top, 8)
                                        },
                                        label: {
                                            HStack {
                                                Text("Next Duty Limits")
                                                    .font(.title2)
                                                    .fontWeight(.semibold)

                                                Spacer()

                                                // iPad: Show toggle in header
                                                if horizontalSizeClass != .compact {
                                                    Picker("Limit Type", selection: $viewModel.selectedLimitType) {
                                                        Text("Planning").tag(FRMSLimitType.planning)
                                                        Text("Operational").tag(FRMSLimitType.operational)
                                                    }
                                                    .pickerStyle(.segmented)
                                                    .frame(width: 220)
                                                    .padding(.trailing, 16)
                                                }
                                            }
                                        }
                                    )
                                    .foregroundStyle(.primary)
                                }
                            } else {
                                maximumNextDutySection
                            }

                            // MBTT Calculator Section (for A380/A330/B787)
                            if viewModel.configuration.fleet == .a380A330B787 {
                                VStack(alignment: .leading, spacing: 16) {
                                    DisclosureGroup(
                                        isExpanded: $expandMinimumBaseTurnaround,
                                        content: {
                                            minimumBaseTurnaroundSection
                                                .padding(.top, 8)
                                        },
                                        label: {
                                            Text("Minimum Base Turnaround Time")
                                                .font(.title2)
                                                .fontWeight(.semibold)
                                        }
                                    )
                                    .foregroundStyle(.primary)
                                }
                            }

                            // Recent Duties
                            if viewModel.configuration.fleet == .a380A330B787 {
                                VStack(alignment: .leading, spacing: 16) {
                                    DisclosureGroup(
                                        isExpanded: $expandRecentDuties,
                                        content: {
                                            recentDutiesSection
                                                .padding(.top, 8)
                                        },
                                        label: {
                                            Text("Recent Duties")
                                                .font(.title2)
                                                .fontWeight(.semibold)
                                        }
                                    )
                                    .foregroundStyle(.primary)
                                }
                            } else {
                                recentDutiesSection
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        LogManager.shared.debug("FRMSView: Pull-to-refresh triggered")
                        await viewModel.refreshFlightData(crewPosition: flightTimePosition)
                        updateMBTT()
                    }
                    .opacity(viewModel.isLoading ? 0.3 : 1.0)
                }
            }
            .navigationTitle(Text("FRMS"))
//            .navigationTitle("\(viewModel.configuration.fleet.shortName) FRMS")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                //LogManager.shared.debug("FRMSView: onAppear called")
                viewModel.loadFlightData(crewPosition: flightTimePosition)
                updateMBTT()  // Initialize MBTT calculation
            }
            .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
                LogManager.shared.debug("FRMSView: Received .flightDataChanged notification")
                Task {
                    await viewModel.refreshFlightData(crewPosition: flightTimePosition)
                    updateMBTT()
                }
            }
        }
    }

    // MARK: - Minimum Rest Section

    private func minimumRestSection(limits: A320B737NextDutyLimits) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Earliest Sign-On")
                .font(.title2)
                .fontWeight(.semibold)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Minimum Rest")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(formatHoursMinutes(limits.restCalculation.minimumRestHours)) hrs")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Earliest Sign-On")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatDateTime(limits.earliestSignOn))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Cumulative Limits Section

    private var cumulativeLimitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cumulative Limits")
                .font(.title2)
                .fontWeight(.semibold)

            if let totals = viewModel.cumulativeTotals {
                AdaptiveCumulativeLimitsLayout(
                    viewModel: viewModel,
                    totals: totals
                )
            } else {
                Text("No flight data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    // MARK: - Maximum Next Duty Section

    private var maximumNextDutySection: some View {
        Group {
            if viewModel.configuration.fleet == .a320B737 {
                a320B737NextDutyContent
            } else {
                maximumNextDutyContent
            }
        }
    }

    // MARK: - A320/B737 Next Duty Content

    private var a320B737NextDutyContent: some View {
        VStack(alignment: .leading, spacing: 16) {

            if let limits = viewModel.a320B737NextDutyLimits, let totals = viewModel.cumulativeTotals {
                VStack(alignment: .leading, spacing: 16) {
                    // Consecutive Duties Summary (A320/B737 only - iPhone only, iPad shows in cumulative section)
                    if totals.hasConsecutiveDutyLimits && horizontalSizeClass == .compact {
                        buildConsecutiveInfoCard(totals: totals)
                    }

                    // Active Restrictions (if any)
                    if limits.backOfClockRestriction != nil || limits.lateNightStatus != nil || limits.consecutiveDutyStatus.hasActiveRestrictions {
                        activeRestrictionsSection(limits: limits)
                    }

                    // Next Duty Limits Title
                    Text("Next Duty Limits")
                        .font(.title2)
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

    // MARK: - A320/B737 Sub-Views

//    private func maxDutyCard(limits: A320B737NextDutyLimits) -> some View {
//        // Get the window to display based on user selection
//        let displayWindow = getSelectedWindow(limits: limits, selection: selectedTimeWindow)
//
//        return VStack(alignment: .leading, spacing: 16) {
//            // Header with Planning|Operational toggle
//            HStack {
//                Picker("Limit Type", selection: $viewModel.selectedLimitType) {
//                    Text("Planning").tag(FRMSLimitType.planning)
//                    Text("Operational").tag(FRMSLimitType.operational)
//                }
//                .pickerStyle(.segmented)
//                .frame(width: horizontalSizeClass == .compact ? 200 : 220)
//                
//                Spacer()
//                
//                HStack {
//                    Text("Sign-On Window")
//                        .font(.headline)
//                        .foregroundStyle(.secondary)
//
//                    Picker("Time Window", selection: $selectedTimeWindow) {
//                        ForEach(TimeWindowSelection.allCases, id: \.self) { window in
//                            Text(window.rawValue).tag(window)
//                        }
//                    }
//                    .pickerStyle(.menu)
//                    .font(.caption)
//                }
//            }
//
//            Divider()
//
//            // Sector-based duty limits
//            
//            Text("Max Duty")
//                .font(.headline)
//                .fontWeight(.semibold)
//                .foregroundStyle(.primary)
//            
//            HStack(spacing: 12) {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("1-4 Sectors")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                    Text("\(formatHoursMinutes(displayWindow.limits.maxDutySectors1to4)) hrs")
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                }
//                
//                Divider()
//                    .frame(height: 35)
//                
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("5 Sectors")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                    Text("\(formatHoursMinutes(displayWindow.limits.maxDutySectors5)) hrs")
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                }
//                
//                Divider()
//                    .frame(height: 35)
//                
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("6 Sectors")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                    Text("\(formatHoursMinutes(displayWindow.limits.maxDutySectors6)) hrs")
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                }
//            Spacer()
//            }
//            .frame(maxWidth: .infinity)
//            
//            Divider()
//
//            // Flight time limit with darkness conditional
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Max Flight Time")
//                    .font(.headline)
//                    .fontWeight(.semibold)
//                    .foregroundStyle(.primary)
//                Text(displayWindow.limits.maxFlightTimeDescription)
//                    .font(.subheadline)
//                    .fontWeight(.semibold)
//            }
//        }
//        .padding()
//        .background(.thinMaterial)
//        .clipShape(RoundedRectangle(cornerRadius: 12))
//        .onAppear {
//            // Set initial selection to the applicable window based on earliest sign-on
//            let applicableWindow = determineApplicableWindow(limits: limits)
//            if applicableWindow.localStartTime == limits.earlyWindow.localStartTime {
//                selectedTimeWindow = .early
//            } else if applicableWindow.localStartTime == limits.afternoonWindow.localStartTime {
//                selectedTimeWindow = .afternoon
//            } else {
//                selectedTimeWindow = .night
//            }
//        }
//        .onChange(of: viewModel.selectedLimitType) { _, _ in
//            // Update time window selection when limit type changes (Planning <-> Operational)
//            let applicableWindow = determineApplicableWindow(limits: limits)
//            if applicableWindow.localStartTime == limits.earlyWindow.localStartTime {
//                selectedTimeWindow = .early
//            } else if applicableWindow.localStartTime == limits.afternoonWindow.localStartTime {
//                selectedTimeWindow = .afternoon
//            } else {
//                selectedTimeWindow = .night
//            }
//        }
//    }

    
    ///***********************************************************


    
    private func maxDutyCard(limits: A320B737NextDutyLimits) -> some View {
        
        let displayWindow = getSelectedWindow(limits: limits, selection: selectedTimeWindow)

        return VStack(alignment: .leading, spacing: 16) {
            
            // Adaptive Header
            headerSection
            
            Divider()

            // MARK: - Max Duty and Flight Time Limits (Adaptive Layout)

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
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    
    private func dutyColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(value) hrs")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func maxDutySection(displayWindow: DutyTimeWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Max Duty")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                dutyColumn(
                    title: "1-4 Sectors",
                    value: formatHoursMinutes(displayWindow.limits.maxDutySectors1to4)
                )

                Divider()
                    .frame(height: 35)

                dutyColumn(
                    title: "5 Sectors",
                    value: formatHoursMinutes(displayWindow.limits.maxDutySectors5)
                )

                Divider()
                    .frame(height: 35)

                dutyColumn(
                    title: "6 Sectors",
                    value: formatHoursMinutes(displayWindow.limits.maxDutySectors6)
                )

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

            if displayWindow.limitType == .operational {
                // Operational limits: 3 columns (1 Sector | 2+ Sectors | >7 hrs night)
                HStack(spacing: 12) {
                    dutyColumn(
                        title: "1 Sector",
                        value: "10.5"
                    )

                    Divider()
                        .frame(height: 35)

                    dutyColumn(
                        title: "2+ Sectors",
                        value: "10"
                    )

                    Divider()
                        .frame(height: 35)

                    dutyColumn(
                        title: "> 7 hrs Night",
                        value: "9.5"
                    )

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Planning limits: 2 columns (Standard | >7 hrs night)
                HStack(spacing: 12) {
                    dutyColumn(
                        title: "Standard",
                        value: "10"
                    )

                    Divider()
                        .frame(height: 35)

                    dutyColumn(
                        title: "> 7 hrs Night",
                        value: "9.5"
                    )

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

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
    
    
    
    
    ///***********************************************************
    ///
    /// Determine which time window applies based on earliest sign-on
    private func determineApplicableWindow(limits: A320B737NextDutyLimits) -> DutyTimeWindow {
        // Check which window is currently available
        if limits.earlyWindow.isCurrentlyAvailable {
            return limits.earlyWindow
        } else if limits.afternoonWindow.isCurrentlyAvailable {
            return limits.afternoonWindow
        } else {
            return limits.nightWindow
        }
    }

    /// Get the window to display based on user selection
    private func getSelectedWindow(limits: A320B737NextDutyLimits, selection: TimeWindowSelection) -> DutyTimeWindow {
        switch selection {
        case .early:
            return limits.earlyWindow
        case .afternoon:
            return limits.afternoonWindow
        case .night:
            return limits.nightWindow
        }
    }

    private func activeRestrictionsSection(limits: A320B737NextDutyLimits) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Restrictions")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Back of clock restriction
            if let backOfClock = limits.backOfClockRestriction {
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

                    Text("Next duty: Sign-on no earlier than \(formatTime(backOfClock.earliestSignOn))")
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
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

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
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bulletPoint(text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
        }
    }

    // What-If Calculator removed - operational limits only

    private var maximumNextDutyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Input Parameters and Limits
            VStack(spacing: 16) {
                // Crew Complement Picker
                VStack(spacing: 12) {
                    Picker("Crew Complement", selection: $selectedCrewComplement) {
                        ForEach([CrewComplement.twoPilot, .threePilot, .fourPilot], id: \.self) { complement in
                            Text(complement.description).tag(complement)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedCrewComplement) { _, newValue in
                        LogManager.shared.debug("FRMSView: Crew complement changed to \(newValue)")
                        updateMaxNextDuty()
                    }

                    if selectedCrewComplement != .twoPilot {
                        Picker("Rest Facility", selection: $selectedRestFacility) {
                            ForEach([RestFacilityClass.class1, .class2, .mixed, .none], id: \.self) { facility in
                                Text(facility.description).tag(facility)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedRestFacility) { _, newValue in
                            LogManager.shared.debug("FRMSView: Rest facility changed to \(newValue)")
                            updateMaxNextDuty()
                        }
                    } else {
                        // Reset to none for 2-pilot
                        Text("No rest facility (2-pilot operation)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .onAppear {
                                selectedRestFacility = .none
                            }
                    }
                }

                // Sign-On Time Based Limits (for A380/A330/B787)
                if let maxDuty = viewModel.maximumNextDuty,
                   let signOnLimits = maxDuty.signOnBasedLimits,
                   !signOnLimits.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Limits by Sign-On Time")
                            .font(.headline)
                            .fontWeight(.semibold)

                        VStack(spacing: 12) {
                            ForEach(signOnLimits.indices, id: \.self) { index in
                                signOnTimeRangeCard(range: signOnLimits[index], limitType: maxDuty.limitType)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Maximum Next Duty Display
           if let maxDuty = viewModel.maximumNextDuty {

                    if !maxDuty.restrictions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Restrictions", systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)

                            ForEach(maxDuty.restrictions, id: \.self) { restriction in
                                Text("• \(restriction)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
            }
        }
    }

    // MARK: - Minimum Base Turnaround Time Section

    private var minimumBaseTurnaroundSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Input Parameters and Result
            VStack(spacing: 16) {
                // Previous Trip Length Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trip Length")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Days Away", selection: $mbttDaysAwayCategory) {
                        Text("1 day").tag("1")
                        Text("2-4 days").tag("2-4")
                        Text("5-8 days").tag("5-8")
                        Text("9-12 days").tag("9-12")
                        Text(">12 days").tag(">12")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mbttDaysAwayCategory) { _, newValue in
                        LogManager.shared.debug("FRMSView: MBTT days away changed to \(newValue)")
                        updateMBTT()
                    }
                }

                // Credited Hours Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trip Credit Hours")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Credited Hours", selection: $mbttCreditedHoursCategory) {
                        Text("≤20 hrs").tag("≤20")
                        Text(">20 hrs").tag(">20")
                        Text(">40 hrs").tag(">40")
                        Text(">60 hrs").tag(">60")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mbttCreditedHoursCategory) { _, newValue in
                        LogManager.shared.debug("FRMSView: MBTT credited hours changed to \(newValue)")
                        updateMBTT()
                    }
                }


                // >18 hour duty toggle
                Toggle(isOn: $mbttHadDutyOver18Hours) {
                    Text("Planned duty >18 hrs")
                        .font(.subheadline)
                }
                .onChange(of: mbttHadDutyOver18Hours) { _, newValue in
                    LogManager.shared.debug("FRMSView: MBTT duty over 18 hours changed to \(newValue)")
                    updateMBTT()
                }

                // MBTT Result Display
                if let mbtt = calculatedMBTT {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Rest Required:", systemImage: "house.fill")
                                .font(.headline)
                                .fontWeight(.semibold)

                            // Spacer()

                            Text(mbtt.description)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Recent Duties Section

    private var recentDutiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title only shown for SH fleet (LH has it in DisclosureGroup)
            if viewModel.configuration.fleet == .a320B737 {
                Text("Recent Duties") // - \(viewModel.configuration.homeBase)")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text("Home Base: \(viewModel.configuration.homeBase)")
                .font(.subheadline)
                .fontWeight(.semibold)

            if !viewModel.recentDutiesByDay.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentDutiesByDay.prefix(7)) { dailySummary in
                        dailyDutyRow(dailySummary: dailySummary)
                    }
                }
            } else {
                Text("No recent duties")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    // MARK: - Helper Views

    private func limitCard(title: String, current: Double, limit: Double, status: FRMSComplianceStatus, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: status.icon)
                    .foregroundStyle(statusColor(status))
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(formatHoursMinutes(current))
                    .font(.title)
                    .fontWeight(.bold)

                Text("/ \(Int(limit)) \(unit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: current, total: limit)
                .tint(progressColor(status))

            Text(String(format: "%.0f%% used", viewModel.percentageOfLimit(used: current, limit: limit)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func daysOffCard(daysOff: Int, required: Int) -> some View {
        let periodDays = viewModel.configuration.fleet.flightTimePeriodDays
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Days Off (\(periodDays) Days)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: daysOff >= required ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(daysOff >= required ? .green : .orange)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(daysOff)")
                    .font(.title)
                    .fontWeight(.bold)

                Text("/ \(required) days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func maxDutyParameterRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    private func signOnTimeRangeCard(range: SignOnTimeRange, limitType: FRMSLimitType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Time range header
            Text(range.timeRange)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            // Duty and flight time limits - adaptive layout
            AdaptiveLimitLayout(range: range, limitType: limitType)
            
            if let notes = range.notes {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2))
                    //.clipShape(Capsule())
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private struct AdaptiveLimitLayout: View {
        let range: SignOnTimeRange
        let limitType: FRMSLimitType
        
        @Environment(\.horizontalSizeClass) var horizontalSizeClass
        
        var body: some View {
            if horizontalSizeClass == .compact {
                // iPhone layout (2x2 grid)
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        LimitInfoView(
                            icon: "clock",
                            label: "Max Duty Hours",
                            value: "\(formatHoursMinutes(range.getMaxDuty(for: limitType))) hrs"
                        )

                        LimitInfoView(
                            icon: "airplane",
                            label: "Max Flight Hours",
                            value: "\(formatHoursMinutes(range.getMaxFlight(for: limitType))) hrs"
                        )
                    }

                    HStack(spacing: 16) {
                        LimitInfoView(
                            icon: "bed.double",
                            label: "Pre Duty Rest",
                            value: "\(formatHoursMinutes(range.preRestRequired)) hrs"
                        )

                        LimitInfoView(
                            icon: "bed.double.fill",
                            label: "Post Duty Rest",
                            value: "\(formatHoursMinutes(range.postRestRequired)) hrs"
                        )
                    }
                }
            } else {
                // iPad layout (original horizontal layout)
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Max Duty Hours", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(formatHoursMinutes(range.getMaxDuty(for: limitType))) hrs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Max Flight Hours", systemImage: "airplane")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(formatHoursMinutes(range.getMaxFlight(for: limitType))) hrs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Pre Duty Rest", systemImage: "bed.double")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(formatHoursMinutes(range.preRestRequired)) hrs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Post Duty Rest", systemImage: "bed.double.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(formatHoursMinutes(range.postRestRequired)) hrs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // Helper view for iPhone layout
    private struct LimitInfoView: View {
        let icon: String
        let label: String
        let value: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Label(label, systemImage: icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Adaptive Cumulative Limits Layout

    private struct AdaptiveCumulativeLimitsLayout: View {
        @ObservedObject var viewModel: FRMSViewModel
        let totals: FRMSCumulativeTotals

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
                    // Row 1: Flight Time (28 Days) + Flight Time (365 Days)
                    let periodDays = viewModel.configuration.fleet.flightTimePeriodDays
                    HStack(spacing: 12) {
                        buildLimitCard(
                            title: "Flight Time (\(periodDays) Days)",
                            current: totals.flightTime28Or30Days,
                            limit: viewModel.configuration.fleet.maxFlightTime28Days,
                            status: totals.status28Days,
                            unit: "hrs"
                        )

                        buildLimitCard(
                            title: "Flight Time (365 Days)",
                            current: totals.flightTime365Days,
                            limit: viewModel.configuration.fleet.maxFlightTime365Days,
                            status: totals.status365Days,
                            unit: "hrs"
                        )
                    }

                    // Row 2: Duty Time (7 Days) + Duty Time (14 Days)
                    HStack(spacing: 12) {
                        buildLimitCard(
                            title: "Duty Time (7 Days)",
                            current: totals.dutyTime7Days,
                            limit: viewModel.configuration.fleet.maxDutyTime7Days,
                            status: totals.dutyStatus7Days,
                            unit: "hrs"
                        )

                        buildLimitCard(
                            title: "Duty Time (14 Days)",
                            current: totals.dutyTime14Days,
                            limit: viewModel.configuration.fleet.maxDutyTime14Days,
                            status: totals.dutyStatus14Days,
                            unit: "hrs"
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
            // Flight Time - 28/30 Days (fleet-specific)
            let periodDays = viewModel.configuration.fleet.flightTimePeriodDays
            buildLimitCard(
                title: "Flight Time (\(periodDays) Days)",
                current: totals.flightTime28Or30Days,
                limit: viewModel.configuration.fleet.maxFlightTime28Days,
                status: totals.status28Days,
                unit: "hrs"
            )
            
            // Flight Time - 365 Days
            buildLimitCard(
                title: "Flight Time (365 Days)",
                current: totals.flightTime365Days,
                limit: viewModel.configuration.fleet.maxFlightTime365Days,
                status: totals.status365Days,
                unit: "hrs"
            )
            
            // Duty Time - 7 Days
            buildLimitCard(
                title: "Duty Time (7 Days)",
                current: totals.dutyTime7Days,
                limit: viewModel.configuration.fleet.maxDutyTime7Days,
                status: totals.dutyStatus7Days,
                unit: "hrs"
            )
            
            // Duty Time - 14 Days
            buildLimitCard(
                title: "Duty Time (14 Days)",
                current: totals.dutyTime14Days,
                limit: viewModel.configuration.fleet.maxDutyTime14Days,
                status: totals.dutyStatus14Days,
                unit: "hrs"
            )
            
//            // ADDED HERE
//            if viewModel.configuration.fleet == .a320B737 {
//                    buildDaysOffCard(
//                    daysOff: totals.daysOff28Days,
//                    required: 7
//                    )
//                
//            }
            
        }

        // MARK: - Card Building Functions

        private func buildLimitCard(title: String, current: Double, limit: Double, status: FRMSComplianceStatus, unit: String) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Image(systemName: status.icon)
                        .foregroundStyle(statusColor(status))
                }

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(current) : String(format: "%.1f", current))
                        .font(.title)
                        .fontWeight(.bold)

                    Text("/ \(Int(limit)) \(unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: current, total: limit)
                    .tint(progressColor(status))

//                Text(String(format: "%.0f%% used", percentageOfLimit(used: current, limit: limit)))
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        private func buildDaysOffCard(daysOff: Int, required: Int) -> some View {
            let periodDays = viewModel.configuration.fleet.flightTimePeriodDays
            return VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Days Off (\(periodDays) Days)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Image(systemName: daysOff >= required ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(daysOff >= required ? .green : .orange)
                }

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(daysOff)")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("/ \(required) days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Spacer to match the height of ProgressView in buildLimitCard
                Spacer()
                    .frame(height: 6)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        private func buildConsecutiveInfoCard(totals: FRMSCumulativeTotals) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Consecutive Duties")
                    .font(.headline)
                    .fontWeight(.medium)

                HStack(spacing: 16) {
                    if let maxConsec = totals.maxConsecutiveDuties {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.consecutiveDuties)")
                                    .font(.title2)
                                    .fontWeight(.bold)
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
                                    .font(.title2)
                                    .fontWeight(.bold)
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
                                    .font(.title2)
                                    .fontWeight(.bold)
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
                                    .font(.title2)
                                    .fontWeight(.bold)
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
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

    // MARK: - Consecutive Duties Card

    private func buildConsecutiveInfoCard(totals: FRMSCumulativeTotals) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consecutive Duties")
                .font(.headline)
                .fontWeight(.semibold)

            // First row - 4 items (only for A320/B737)
            HStack(spacing: 16) {
                if let maxConsec = totals.maxConsecutiveDuties {
                    VStack {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(totals.consecutiveDuties)")
                                .font(.title2)
                                .fontWeight(.bold)
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
                                .font(.title2)
                                .fontWeight(.bold)
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
                                .font(.title2)
                                .fontWeight(.bold)
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
                                .font(.title2)
                                .fontWeight(.bold)
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
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dailyDutyRow(dailySummary: DailyDutySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date header
            HStack {
                Text(formatLocalDate(dailySummary.date))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(dailySummary.totalSectors) Sector\(dailySummary.totalSectors == 1 ? "" : "s")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            // Daily totals
            HStack(spacing: 16) {

                Label("Duty: \(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(dailySummary.totalDutyTime) : String(format: "%.1f", dailySummary.totalDutyTime)) hrs", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

               // Spacer()

                Label("Flight: \(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(dailySummary.totalFlightTime) : String(format: "%.1f", dailySummary.totalFlightTime)) hrs", systemImage: "clock.badge.airplane")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helper Methods

    private func updateMaxNextDuty() {
        viewModel.maximumNextDuty = viewModel.calculateMaxNextDuty(
            crewComplement: selectedCrewComplement,
            restFacility: selectedRestFacility,
            limitType: .operational  // Always use operational limits
        )
    }

    private func updateMBTT() {
        // Convert category selections to actual values for calculation
        let daysAway: Int
        switch mbttDaysAwayCategory {
        case "1": daysAway = 1
        case "2-4": daysAway = 3  // Use middle value
        case "5-8": daysAway = 6  // Use middle value
        case "9-12": daysAway = 10  // Use middle value
        case ">12": daysAway = 13
        default: daysAway = 3
        }

        let creditedHours: Double
        switch mbttCreditedHoursCategory {
        case "≤20": creditedHours = 15.0  // Representative value ≤20
        case ">20": creditedHours = 25.0  // Representative value >20 but ≤40
        case ">40": creditedHours = 50.0  // Representative value >40 but ≤60
        case ">60": creditedHours = 70.0  // Representative value >60
        default: creditedHours = 15.0
        }

        // Get the FRMS service from the viewModel's configuration
        let service = FRMSCalculationService(configuration: viewModel.configuration)
        calculatedMBTT = service.calculateMBTT(
            daysAway: daysAway,
            creditedFlightHours: creditedHours,
            hadPlannedDutyOver18Hours: mbttHadDutyOver18Hours
        )
    }

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

    private func statusText(_ status: FRMSComplianceStatus) -> String {
        switch status {
        case .compliant: return "Compliant"
        case .warning: return "Warning"
        case .violation: return "Violation"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM HHmm"
        // Use device's current timezone (wherever you are)
        return formatter.string(from: date)
    }

    private func formatLocalDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        // Use home base timezone from FRMS configuration
        let service = FRMSCalculationService(configuration: viewModel.configuration)
        formatter.timeZone = service.getHomeBaseTimeZone()
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        // Use device's current timezone (wherever you are)
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM - HHmm"
        // Use device's current timezone (wherever you are)
        return formatter.string(from: date)
    }
}
