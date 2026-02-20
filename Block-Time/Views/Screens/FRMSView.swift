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

private struct DutyBand: Identifiable {
    let id: String
    let label: String
    let value: Double   // representative value that unambiguously falls in this threshold band
}

struct FRMSView: View {

    @ObservedObject var viewModel: FRMSViewModel
    let flightTimePosition: FlightTimePosition
    /// Non-nil on iPad split view — indicates which section to show.
    /// Nil on iPhone (or iPad portrait) — all sections rendered as before.
    var selectedSection: FRMSSection? = nil
    @Environment(ThemeService.self) private var themeService
    @EnvironmentObject var appViewModel: FlightTimeExtractorViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var selectedCrewComplement: CrewComplement = .fourPilot
    @State private var selectedRestFacility: CrewRestFacility = .twoClass1
    @State private var selectedSignOnWindow: SignOnWindow = .w0800_1359
    @State private var expectedDutyHours: Double = 10.0
    @State private var nextDutyIsDeadhead: Bool = false

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
    @State private var expandNextDutyLimits = false
    @State private var expandMinimumBaseTurnaround = false
    @State private var expandRecentDuties = false
    @State private var expandCrewRestClassification = false
    @State private var expandDisruptionRest = false

    // Disruption Rest — FD10.2.1
    @State private var disruptionPreviousDutyHours: Double = 12.0
    @State private var disruptionTZDifference: Double = 0.0
    @State private var disruptionNextDutyOver16: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()

                ZStack {
                    ScrollView {
                        VStack(spacing: 20) {
                            if let section = selectedSection {
                                // iPad split view — show the selected section only (no DisclosureGroups)
                                sectionContent(for: section)
                            } else {
                                // iPhone (or iPad portrait) — all sections, unchanged layout
                                allSectionsContent
                            }
                        }
                        .padding()
                        .frame(maxWidth: selectedSection == nil && horizontalSizeClass == .regular ? 800 : .infinity)
                        .frame(maxWidth: .infinity)
                    }
                    .refreshable {
                        LogManager.shared.debug("FRMSView: Pull-to-refresh triggered")
                        await viewModel.refreshFlightData(crewPosition: flightTimePosition)
                        updateMBTT()
                    }
                    .opacity(viewModel.isLoading ? 0.3 : 1.0)
                }
            }
            .navigationTitle(selectedSection?.rawValue ?? "FRMS")
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

    // MARK: - Split View Section Content

    /// All sections rendered sequentially — used on iPhone and iPad portrait (selectedSection == nil).
    /// This is the exact layout that existed before split-view was introduced.
    @ViewBuilder
    private var allSectionsContent: some View {
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
                                .font(.title3)
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
                            .font(.title3)
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
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                )
                .foregroundStyle(.primary)
            }
        } else {
            recentDutiesSection
        }
    }

    /// Content for the selected sidebar section (iPad split-view path).
    /// DisclosureGroups are omitted — each section fills the detail pane directly.
    @ViewBuilder
    private func sectionContent(for section: FRMSSection) -> some View {
        switch section {
        case .cumulativeLimits:
            cumulativeLimitsSection
        case .nextDuty:
            nextDutySectionContent
        case .minBaseTurnaround:
            minimumBaseTurnaroundSection
        case .recentDuties:
            recentDutiesSection
        }
    }

    /// Next Duty section content for the split-view detail pane.
    /// Includes the Planning/Operational picker that was previously in the DisclosureGroup label.
    @ViewBuilder
    private var nextDutySectionContent: some View {
        // Minimum Rest (A320/B737 only)
        if viewModel.configuration.fleet == .a320B737,
           let limits = viewModel.a320B737NextDutyLimits {
            minimumRestSection(limits: limits)
        }

        // Planning / Operational toggle (replaces the DisclosureGroup label for A380)
        if viewModel.configuration.fleet == .a380A330B787 {
            Picker("Limit Type", selection: $viewModel.selectedLimitType) {
                Text("Planning").tag(FRMSLimitType.planning)
                Text("Operational").tag(FRMSLimitType.operational)
            }
            .pickerStyle(.segmented)
        }

        maximumNextDutySection
    }

    // MARK: - Minimum Rest Section

    private func minimumRestSection(limits: A320B737NextDutyLimits) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Minimum Rest & Sign-On")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 3)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minimum Rest")
                            .font(.headline.bold())
                            .foregroundStyle(.secondary)
                        Text("\(formatHoursMinutes(limits.restCalculation.minimumRestHours)) hrs")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.accentOrange)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Earliest Sign-On")
                            .font(.headline.bold())
                            .foregroundStyle(.secondary)
                        Text(formatDateTime(limits.earliestSignOn))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.accentOrange)
                    }
                }
                .padding(16)
            }
            .appCardStyle()
        }
    }

    // MARK: - Cumulative Limits Section

    private var cumulativeLimitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cumulative Limits")
                .font(.title3)
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
    
    private func dutyColumn(title: String, hours: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formatTime(hours))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.accentOrange)
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
                    hours: displayWindow.limits.maxDutySectors1to4
                )

                Divider()
                    .frame(height: 35)

                dutyColumn(
                    title: "5 Sectors",
                    hours: displayWindow.limits.maxDutySectors5
                )

                Divider()
                    .frame(height: 35)

                dutyColumn(
                    title: "6 Sectors",
                    hours: displayWindow.limits.maxDutySectors6
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
                        hours: 10.5
                    )

                    Divider()
                        .frame(height: 35)

                    dutyColumn(
                        title: "2+ Sectors",
                        hours: 10.0
                    )

                    Divider()
                        .frame(height: 35)

                    dutyColumn(
                        title: "> 7 hrs Night",
                        hours: 9.5
                    )

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Planning limits: 2 columns (Standard | >7 hrs night)
                HStack(spacing: 12) {
                    dutyColumn(
                        title: "Standard",
                        hours: 10.0
                    )

                    Divider()
                        .frame(height: 35)

                    dutyColumn(
                        title: "> 7 hrs Night",
                        hours: 9.5
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
        .appCardStyle()
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
        .appCardStyle()
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
                    switch newValue {
                    case .twoPilot:
                        selectedRestFacility = .class1
                    case .threePilot:
                        selectedRestFacility = .class1
                    case .fourPilot:
                        selectedRestFacility = .twoClass1
                    }
                    // Reset to first valid option for the new complement + current limit type
                    expectedDutyHours = dutyBandOptions.first?.value ?? 10.0
                    updateMaxNextDuty()
                }
            }
            .padding()
            .appCardStyle()

            // Duty & Flight Time Limits
            if let maxDuty = viewModel.maximumNextDuty,
               let signOnLimits = maxDuty.signOnBasedLimits,
               !signOnLimits.isEmpty {

                VStack(alignment: .leading, spacing: 12) {
                    Text("Duty & Flight Time Limits")
                        .font(.headline)
                        .fontWeight(.semibold)

                    // Rest facility picker (3/4-pilot only)
                    if !restFacilityPickerOptions.isEmpty {
                        Picker("Rest Facility", selection: $selectedRestFacility) {
                            ForEach(restFacilityPickerOptions, id: \.facility) { option in
                                Text(option.label).tag(option.facility)
                            }
                        }
                        .pickerStyle(.segmented)

                        crewRestFacilityNoteView
                    }

                    // Sign-on time picker (2-pilot planning only)
                    if selectedCrewComplement == .twoPilot && viewModel.selectedLimitType == .planning {
                        Picker("Sign-On Time", selection: $selectedSignOnWindow) {
                            ForEach(SignOnWindow.allCases, id: \.self) { window in
                                Text(window.rawValue).tag(window)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(filteredSignOnLimits(from: signOnLimits).enumerated()), id: \.offset) { _, range in
                            signOnTimeRangeCard(range: range, limitType: viewModel.selectedLimitType)
                        }
                    }
                }
                .padding()
                .appCardStyle()
            }

            // Rest Requirements
            lhRestRequirementsSection

            // Disruption Rest — FD10.2.1
            DisruptionRestSection(
                isExpanded: $expandDisruptionRest,
                previousDutyHours: $disruptionPreviousDutyHours,
                tzDifference: $disruptionTZDifference,
                nextDutyOver16: $disruptionNextDutyOver16,
                crewComplement: selectedCrewComplement
            )

            // Deadheading (planning only)
            if viewModel.selectedLimitType == .planning {
                lhDeadheadingSection
            }

            // Relevant Sectors (A380 & B787 only)
            lhRelevantSectorsSection

            // Cumulative restriction warnings
            if let maxDuty = viewModel.maximumNextDuty, !maxDuty.restrictions.isEmpty {
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
        .onAppear {
            if !viewModel.isLoading, viewModel.cumulativeTotals != nil {
                updateMaxNextDuty()
            }
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading {
                updateMaxNextDuty()
            }
        }
        .onChange(of: viewModel.selectedLimitType) { _, newLimitType in
            updateMaxNextDuty()
            expectedDutyHours = dutyBandOptions.first?.value ?? 10.0
            // Seats in Passenger Compartment is operational-only; reset when switching to planning
            if newLimitType == .planning && selectedRestFacility == .seatInPassengerCompartment {
                selectedRestFacility = .twoClass1
            }
        }
    }

    // MARK: - Rest Facility Picker Helpers

    private var dutyBandOptions: [DutyBand] {
        if nextDutyIsDeadhead {
            return [
                DutyBand(id: "dh_le12", label: "≤ 12 hrs", value: 10.0),
                DutyBand(id: "dh_gt12", label: "> 12 hrs", value: 14.0),
            ]
        }
        switch (selectedCrewComplement, viewModel.selectedLimitType) {
        case (.twoPilot, .operational):
            return [
                DutyBand(id: "op2p_le11", label: "≤ 11:00", value: 10.0),
                DutyBand(id: "op2p_1115", label: "11:15",   value: 11.25),
                DutyBand(id: "op2p_1130", label: "11:30",   value: 11.5),
                DutyBand(id: "op2p_1145", label: "11:45",   value: 11.75),
                DutyBand(id: "op2p_1200", label: "12:00",   value: 12.0),
                DutyBand(id: "op2p_gt12", label: "> 12:00", value: 13.0),
            ]
        case (.twoPilot, .planning):
            return [
                DutyBand(id: "pl2p_le11", label: "≤ 11 hrs", value: 10.0),
                DutyBand(id: "pl2p_gt11", label: "> 11 hrs",  value: 12.0),
            ]
        case (.threePilot, .operational):
            return [
                DutyBand(id: "op3p_le16", label: "≤ 16 hrs", value: 14.0),
                DutyBand(id: "op3p_gt16", label: "> 16 hrs",  value: 18.0),
            ]
        case (.threePilot, .planning):
            return [
                DutyBand(id: "pl3p_le12", label: "≤ 12 hrs", value: 10.0),
                DutyBand(id: "pl3p_gt12", label: "> 12 hrs",  value: 14.0),
            ]
        case (.fourPilot, .operational):
            return [
                DutyBand(id: "op4p_le16", label: "≤ 16 hrs",         value: 14.0),
                DutyBand(id: "op4p_gt16", label: "> 16 hrs",          value: 17.0),
                DutyBand(id: "op4p_gt18", label: "> 18 hrs (FD3.4)", value: 20.0),
            ]
        case (.fourPilot, .planning):
            return [
                DutyBand(id: "pl4p_le12", label: "≤ 12 hrs", value: 10.0),
                DutyBand(id: "pl4p_gt12", label: "> 12 hrs",  value: 13.0),
                DutyBand(id: "pl4p_gt14", label: "> 14 hrs",  value: 15.0),
                DutyBand(id: "pl4p_gt16", label: "> 16 hrs",  value: 17.0),
            ]
        }
    }

    /// FD10.2.2 note shown below the rest facility picker (collapsed by default).
    private var crewRestFacilityNoteView: some View {
        DisclosureGroup(
            isExpanded: $expandCrewRestClassification,
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach([
                        ("Class 1", LH_Operational_FltDuty.class1Aircraft),
                        ("Class 2", LH_Operational_FltDuty.class2Aircraft),
                    ], id: \.0) { label, aircraft in
                        HStack(alignment: .top, spacing: 6) {
                            Text(label)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .frame(width: 48, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(aircraft, id: \.aircraft) { def in
                                    if let config = def.configuration {
                                        Text("\(def.aircraft) — \(config)")
                                    } else {
                                        Text(def.aircraft)
                                    }
                                }
                            }
                            .font(.footnote)
                            .foregroundStyle(.primary)
                        }
                    }

//                    Text(LH_Operational_FltDuty.crewRestFacilityStatutoryNote)
//                        .font(.caption2)
//                        .foregroundStyle(.tertiary)
//                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)
            },
            label: {
                Text("Crew Rest Classification")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        )
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var restFacilityPickerOptions: [(facility: CrewRestFacility, label: String)] {
        switch selectedCrewComplement {
        case .twoPilot:
            return []
        case .threePilot:
            return [(.class1, "Class 1"), (.class2, "Class 2")]
        case .fourPilot:
            if viewModel.selectedLimitType == .operational {
                return [
                    (.twoClass1, "2× Class 1"),
                    (.oneClass1OneClass2, "Mixed"),
                    (.twoClass2, "2× Class 2"),
                    (.seatInPassengerCompartment, "PAX Seat"),
                    
                    
                    
                ]
            } else {
                return [(.twoClass1, "2× Class 1"), (.oneClass1OneClass2, "Mixed"), (.twoClass2, "2× Class 2")]
            }
        }
    }

    private func filteredSignOnLimits(from limits: [SignOnTimeRange]) -> [SignOnTimeRange] {
        if selectedCrewComplement == .twoPilot {
            // Planning: filter to the selected sign-on window (may return 1 or 2 rows for 0800–1359)
            if viewModel.selectedLimitType == .planning {
                return limits.filter { $0.timeRange == selectedSignOnWindow.rawValue }
            }
            // Operational: single "All sign-on times" row, show as-is
            return limits
        }
        // For 4-pilot with 2×Class 1 selected, also show the FD3.4 extension row
        if selectedCrewComplement == .fourPilot && selectedRestFacility == .twoClass1 {
            return limits.filter { $0.restFacility == .twoClass1 || $0.restFacility == .twoClass1FD34 }
        }
        return limits.filter { $0.restFacility == selectedRestFacility }
    }

    // MARK: - LH Rest Requirements Section

    private var lhRestRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rest Requirements")
                .font(.headline)
                .fontWeight(.semibold)

            // Calculator controls
            VStack(alignment: .leading, spacing: 8) {
                Text("Expected Next Duty")
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.8))

                Picker("Next Duty", selection: $nextDutyIsDeadhead) {
                    Text("Operating").tag(false)
                    Text("Deadheading").tag(true)
                }
                .pickerStyle(.segmented)

                Picker("Expected Duty", selection: $expectedDutyHours) {
                    ForEach(dutyBandOptions) { band in
                        Text(band.label).tag(band.value)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onAppear {
                expectedDutyHours = dutyBandOptions.first?.value ?? 10.0
            }
            .onChange(of: nextDutyIsDeadhead) { _, _ in
                expectedDutyHours = dutyBandOptions.first?.value ?? 10.0
            }

            // Pre-Duty Rest
            lhRestCard(
                title: "Minimum Pre-Duty Rest",
                rows: calculatePreDutyRestRows(dutyHours: expectedDutyHours),
                footnote: nextDutyIsDeadhead ? LH_Planning_FltDuty.deadheadPreDutyRestNote : lhPreDutyRestFootnote
            )

            // Post-Duty Rest
            lhRestCard(
                title: "Minimum Post-Duty Rest",
                rows: calculatePostDutyRestRows(dutyHours: expectedDutyHours, isDeadhead: nextDutyIsDeadhead),
                footnote: nextDutyIsDeadhead ? LH_Planning_FltDuty.deadheadPostDutyRestNote : lhPostDutyRestFootnote
            )
        }
        .padding()
        .appCardStyle()
    }

    // MARK: - (Disruption Rest moved to DisruptionRestSection struct below)

    private func calculatePreDutyRestRows(dutyHours: Double) -> [LHRestRow] {
        if nextDutyIsDeadhead {
            let threshold = dutyHours <= 12 ? "≤ 12" : "> 12"
            return LH_Planning_FltDuty.deadheadPreDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
        }

        switch (selectedCrewComplement, viewModel.selectedLimitType) {
        case (.twoPilot, .operational):
            let threshold = dutyHours <= 11 ? "≤ 11" : "> 11"
            return LH_Operational_FltDuty.twoPilotPreDutyRest
                .filter { $0.dutyPeriodThreshold == threshold && $0.minimumRestHours != nil }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours!)) hrs", condition: $0.requirements) }

        case (.twoPilot, .planning):
            let threshold = dutyHours <= 11 ? "≤ 11" : "> 11"
            return LH_Planning_FltDuty.twoPilotPreDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }

        case (.threePilot, .operational):
            return LH_Operational_FltDuty.threePilotPreDutyRest
                .filter { $0.minimumRestHours != nil }
                .map { (threshold: "—", minRest: "\(Int($0.minimumRestHours!)) hrs", condition: $0.requirements) }

        case (.threePilot, .planning):
            let threshold = dutyHours <= 12 ? "≤ 12" : "> 12"
            return LH_Planning_FltDuty.threePilotPreDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }

        case (.fourPilot, .operational):
            if dutyHours > 18 {
                return [("—", "22+ hrs", "Relevant Sector disruption limits apply — see below")]
            }
            return LH_Operational_FltDuty.fourPilotPreDutyRest
                .filter { $0.dutyPeriodThreshold == "—" && $0.minimumRestHours != nil }
                .map { (threshold: "—", minRest: "\(Int($0.minimumRestHours!)) hrs", condition: $0.requirements) }

        case (.fourPilot, .planning):
            if dutyHours <= 14 {
                return LH_Planning_FltDuty.fourPilotPreDutyRest
                    .filter { $0.dutyPeriodThreshold == "≤ 14" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else if dutyHours <= 16 {
                return LH_Planning_FltDuty.fourPilotPreDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 14 ≤ 16" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else {
                return LH_Planning_FltDuty.fourPilotPreDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 16" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            }
        }
    }

    private func calculatePostDutyRestRows(dutyHours: Double, isDeadhead: Bool) -> [LHRestRow] {
        if isDeadhead {
            let threshold = dutyHours <= 12 ? "≤ 12" : "> 12"
            return LH_Planning_FltDuty.deadheadPostDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
        }

        switch (selectedCrewComplement, viewModel.selectedLimitType) {
        case (.twoPilot, .operational):
            if dutyHours <= 11 {
                return [("≤11 hrs", "10 hrs", nil)]
            } else if dutyHours <= 12 {
                let excessMin = (dutyHours - 11.0) * 60.0
                let addHrs = Int(ceil(excessMin / 15.0))
                let total = 10 + addHrs
                return [(">11 hrs", "\(total) hrs", "10 + \(addHrs)h (duty exceeded 11h by \(Int(excessMin))m)")]
            } else {
                return [(">12 hrs", "24 hrs", nil)]
            }

        case (.twoPilot, .planning):
            let threshold = dutyHours <= 11 ? "≤ 11" : "> 11"
            return LH_Planning_FltDuty.twoPilotPostDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }

        case (.threePilot, .operational):
            if dutyHours <= 16 {
                return [("≤16 hrs", "12 hrs", nil)]
            } else {
                return [(">16 hrs", "24 hrs", nil)]
            }

        case (.fourPilot, .operational):
            if dutyHours <= 16 {
                return [("≤16 hrs", "12 hrs", nil)]
            } else if dutyHours <= 18 {
                return [(">16 hrs", "24 hrs", nil)]
            } else {
                return [(">18 hrs (FD3.4)", "Refer to Relevant Sector disruption limits", nil)]
            }

        case (.threePilot, .planning):
            let threshold = dutyHours <= 12 ? "≤ 12" : "> 12"
            return LH_Planning_FltDuty.threePilotPostDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }

        case (.fourPilot, .planning):
            if dutyHours <= 12 {
                return LH_Planning_FltDuty.fourPilotPostDutyRest
                    .filter { $0.dutyPeriodThreshold == "≤ 12" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else if dutyHours <= 14 {
                return LH_Planning_FltDuty.fourPilotPostDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 12" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else if dutyHours <= 16 {
                return LH_Planning_FltDuty.fourPilotPostDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 14" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else {
                return LH_Planning_FltDuty.fourPilotPostDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 16" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            }
        }
    }

    // Row data: (threshold, minRest, condition)
    private typealias LHRestRow = (threshold: String, minRest: String, condition: String?)

    private var lhPreDutyRestRows: [LHRestRow] {
        switch (selectedCrewComplement, viewModel.selectedLimitType) {
        case (.twoPilot, .operational):
            return LH_Operational_FltDuty.twoPilotPreDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: $0.minimumRestHours.map { "\(Int($0)) hrs" } ?? ($0.minimumRestFormula ?? "—"),
                 condition: $0.requirements)
            }
        case (.twoPilot, .planning):
            return LH_Planning_FltDuty.twoPilotPreDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: "\(Int($0.minimumRestHours)) hrs",
                 condition: $0.requirements)
            }
        case (.threePilot, .operational):
            return LH_Operational_FltDuty.threePilotPreDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: $0.minimumRestHours.map { "\(Int($0)) hrs" } ?? "—",
                 condition: $0.requirements)
            }
        case (.threePilot, .planning):
            return LH_Planning_FltDuty.threePilotPreDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: "\(Int($0.minimumRestHours)) hrs",
                 condition: $0.requirements)
            }
        case (.fourPilot, .operational):
            return LH_Operational_FltDuty.fourPilotPreDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: $0.minimumRestHours.map { "\(Int($0)) hrs" } ?? "—",
                 condition: $0.requirements)
            }
        case (.fourPilot, .planning):
            return LH_Planning_FltDuty.fourPilotPreDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: "\(Int($0.minimumRestHours)) hrs",
                 condition: $0.requirements)
            }
        }
    }

    private var lhPostDutyRestRows: [LHRestRow] {
        switch (selectedCrewComplement, viewModel.selectedLimitType) {
        case (.twoPilot, .operational):
            return LH_Operational_FltDuty.twoPilotPostDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: $0.minimumRestHours.map { "\(Int($0)) hrs" } ?? ($0.minimumRestFormula ?? "—"),
                 condition: $0.requirements)
            }
        case (.twoPilot, .planning):
            return LH_Planning_FltDuty.twoPilotPostDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: "\(Int($0.minimumRestHours)) hrs",
                 condition: $0.requirements)
            }
        case (.threePilot, .operational):
            return LH_Operational_FltDuty.threePilotPostDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: $0.minimumRestHours.map { "\(Int($0)) hrs" } ?? "—",
                 condition: $0.requirements)
            }
        case (.threePilot, .planning):
            return LH_Planning_FltDuty.threePilotPostDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: "\(Int($0.minimumRestHours)) hrs",
                 condition: $0.requirements)
            }
        case (.fourPilot, .operational):
            return LH_Operational_FltDuty.fourPilotPostDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: $0.minimumRestHours.map { "\(Int($0)) hrs" } ?? "—",
                 condition: $0.requirements)
            }
        case (.fourPilot, .planning):
            return LH_Planning_FltDuty.fourPilotPostDutyRest.map {
                (threshold: $0.dutyPeriodThreshold,
                 minRest: "\(Int($0.minimumRestHours)) hrs",
                 condition: $0.requirements)
            }
        }
    }

    private var lhPreDutyRestFootnote: String? {
        switch selectedCrewComplement {
        case .twoPilot:
            return viewModel.selectedLimitType == .operational
                ? LH_Operational_FltDuty.twoPilotConsecutiveDutyNote.text
                : nil
        case .threePilot, .fourPilot:
            return nil
        }
    }

    private var lhPostDutyRestFootnote: String? {
        switch selectedCrewComplement {
        case .twoPilot:
            return viewModel.selectedLimitType == .planning
                ? LH_Planning_FltDuty.twoPilotPostDutyDeadheadNote
                : nil
        case .threePilot:
            return viewModel.selectedLimitType == .operational
                ? LH_Operational_FltDuty.augmentedPostDutyDeadheadNote
                : LH_Planning_FltDuty.threePilotPostDutyDeadheadNote
        case .fourPilot:
            return viewModel.selectedLimitType == .operational
                ? LH_Operational_FltDuty.augmentedPostDutyDeadheadNote
                : LH_Planning_FltDuty.fourPilotPostDutyDeadheadNote
        }
    }

    private func lhRestCard(title: String, rows: [LHRestRow], footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))

            ForEach(rows.indices, id: \.self) { i in
                let row = rows[i]
                HStack(alignment: .top, spacing: 8) {
                    Text(row.threshold == "—" ? row.threshold : "\(row.threshold) hrs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 80, alignment: .leading)

                    Text(row.minRest)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 70, alignment: .leading)

                    if let condition = row.condition {
                        Text(condition)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)

                if i < rows.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }

            if let note = footnote, !note.isEmpty {
                Divider()
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.04))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    // MARK: - LH Deadheading Section (Planning Only)

    private var lhDeadheadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deadheading Limits")
                .font(.headline)
                .fontWeight(.semibold)

            // Duty Limits — one block per duty type
            VStack(alignment: .leading, spacing: 0) {
                ForEach(LH_Planning_FltDuty.deadheadLimits.indices, id: \.self) { i in
                    let limit = LH_Planning_FltDuty.deadheadLimits[i]

                    VStack(alignment: .leading, spacing: 8) {
                        Text(limit.dutyType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Duty Limit")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatHoursMinutes(limit.dutyPeriodLimit) + " hrs")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sectors")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(limit.sectorLimit)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if let req = limit.requirements {
                            Text(req)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if i < LH_Planning_FltDuty.deadheadLimits.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }

                Divider()
                Text(LH_Planning_FltDuty.deadheadPreDutyRestNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.04))
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            // Pre-Duty Rest
            lhRestCard(
                title: "Deadhead — Min Pre-Duty Rest",
                rows: LH_Planning_FltDuty.deadheadPreDutyRest.map {
                    (threshold: $0.dutyPeriodThreshold,
                     minRest: "\(Int($0.minimumRestHours)) hrs",
                     condition: $0.requirements)
                },
                footnote: nil
            )

            // Post-Duty Rest
            lhRestCard(
                title: "Deadhead — Min Post-Duty Rest",
                rows: LH_Planning_FltDuty.deadheadPostDutyRest.map {
                    (threshold: $0.dutyPeriodThreshold,
                     minRest: "\(Int($0.minimumRestHours)) hrs",
                     condition: $0.requirements)
                },
                footnote: LH_Planning_FltDuty.deadheadPostDutyRestNote
            )
        }
        .padding()
        .appCardStyle()
    }

    // MARK: - LH Relevant Sectors Section

    private var lhRelevantSectorsSection: some View {
        let sectors = LH_Operational_FltDuty.relevantSectors
        let postDutyRest = LH_Operational_FltDuty.relevantSectorPostDutyRest
        let inboundRest = LH_Operational_FltDuty.relevantSectorInboundAUNZRest
        let preRest = LH_Operational_FltDuty.relevantSectorPreDutyRestHours

        return VStack(alignment: .leading, spacing: 12) {
            Text("Relevant Sectors - Patterns > 18 hrs")
                .font(.headline)
                .fontWeight(.semibold)

            Text("A380 & B787 only")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Named sectors list
            VStack(alignment: .leading, spacing: 0) {
                Text("Relevant Sectors")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))

                ForEach(sectors.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text(sectors[i])
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)

                    if i < sectors.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            // Disruption Rest table
            VStack(alignment: .leading, spacing: 0) {
                Text("Disruption Rest Limits")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))

                // Pre-duty
                HStack(alignment: .top) {
                    Text("Prior to operating")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int(preRest)) hrs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)

                Divider().padding(.leading, 12)

                Text("After operating a Relevant Sector:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(postDutyRest.indices, id: \.self) { i in
                    let row = postDutyRest[i]
                    HStack(alignment: .top, spacing: 8) {
                        Text(row.condition)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let hrs = row.minimumRestHours {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(hrs)) hrs")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if let note = row.note {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        } else if let note = row.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)

                    if i < postDutyRest.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }

                Divider().padding(.leading, 12)

                Text("After Relevant Sector inbound to AU or NZ:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(inboundRest.indices, id: \.self) { i in
                    let row = inboundRest[i]
                    HStack {
                        Text(row.context.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(Int(row.minimumRestHours)) hrs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)

                    if i < inboundRest.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            if viewModel.selectedLimitType == .planning {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FD3.4.1")
                        .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                    Text("Minimum 4 pilot crew for patterns > 18 hrs.")
                        .font(.caption).foregroundStyle(.secondary)

                    Text("FD3.4.2")
                        .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Text(LH_Planning_FltDuty.relevantSectorMBTTIncrease)
                        .font(.caption).foregroundStyle(.secondary)

                    Text("FD3.4.3")
                        .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Text(LH_Planning_FltDuty.relevantSectorHomeTransport)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .appCardStyle()
    }

    // MARK: - LH Table Helper Views

    private func lhTableHeader(columns: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(columns, id: \.self) { col in
                Text(col)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
    }

    private func formatDecimalHours(_ hours: Double) -> String {
        if hours == Double(Int(hours)) {
            return String(Int(hours))
        }
        return String(format: "%.1f", hours)
    }

    // MARK: - Minimum Base Turnaround Time Section

    private var minimumBaseTurnaroundSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 16) {
                if horizontalSizeClass == .compact {
                    // iPhone: stacked layout
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
                    Toggle(isOn: $mbttHadDutyOver18Hours) {
                        Text("Planned duty >18 hrs")
                            .font(.subheadline)
                    }
                    .onChange(of: mbttHadDutyOver18Hours) { _, newValue in
                        LogManager.shared.debug("FRMSView: MBTT duty over 18 hours changed to \(newValue)")
                        updateMBTT()
                    }
                } else {
                    // iPad: two-column layout — pickers on left, toggle on right
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
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
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $mbttHadDutyOver18Hours) {
                                Text("Planned duty >18 hrs")
                                    .font(.subheadline)
                            }
                            .onChange(of: mbttHadDutyOver18Hours) { _, newValue in
                                LogManager.shared.debug("FRMSView: MBTT duty over 18 hours changed to \(newValue)")
                                updateMBTT()
                            }
                        }
                        .frame(maxWidth: 240)
                    }
                }

                // MBTT Result Display — always full width
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
            .appCardStyle()
        }
    }

    // MARK: - Recent Duties Section

    private var recentDutiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title only shown for SH fleet (LH has it in DisclosureGroup)
            if viewModel.configuration.fleet == .a320B737 {
                Text("Recent Duties (\(viewModel.configuration.homeBase))")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

//            Text("Home Base: \(viewModel.configuration.homeBase)")
//                .font(.subheadline)
//                .fontWeight(.semibold)

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
        .appCardStyle()
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
        .appCardStyle()
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
            AdaptiveLimitLayout(range: range, limitType: limitType, showTimesInHoursMinutes: appViewModel.showTimesInHoursMinutes)
            
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private struct AdaptiveLimitLayout: View {
        let range: SignOnTimeRange
        let limitType: FRMSLimitType
        let showTimesInHoursMinutes: Bool

        @Environment(\.horizontalSizeClass) var horizontalSizeClass

        private func formatTime(_ hours: Double) -> String {
            if showTimesInHoursMinutes {
                return hours.toHoursMinutesString
            } else {
                return String(format: "%.1f hrs", hours)
            }
        }

        private var flightTimeDisplay: String {
            return range.notes ?? formatTime(range.getMaxFlight(for: limitType))
        }

        var body: some View {
            if horizontalSizeClass == .compact {
                // iPhone layout
                VStack(alignment: .leading, spacing: 10) {
                    LimitInfoView(
                        icon: "clock",
                        label: "Max Duty",
                        value: formatTime(range.getMaxDuty(for: limitType))
                    )

                    LimitInfoView(
                        icon: "airplane",
                        label: "Max Flight Time",
                        value: flightTimeDisplay
                    )

                    if let sectorLimit = range.sectorLimit {
                        LimitInfoView(
                            icon: "airplane",
                            label: "Sectors",
                            value: sectorLimit
                        )
                    }
                }
            } else {
                // iPad layout
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Max Duty", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(formatTime(range.getMaxDuty(for: limitType)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Max Flight Time", systemImage: "airplane")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(flightTimeDisplay)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if let sectorLimit = range.sectorLimit {
                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Label("Sectors", systemImage: "airplane")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(sectorLimit)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                            limit: viewModel.configuration.fleet.maxDutyTime14Days,
                            status: totals.dutyStatus14Days,
                            unit: "hrs",
                            accentColor: .orange
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
                limit: viewModel.configuration.fleet.maxDutyTime14Days,
                status: totals.dutyStatus14Days,
                unit: "hrs",
                accentColor: .orange
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

        // MARK: - Section Header Helper

        private func sectionHeader(_ title: String) -> some View {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }

        // MARK: - Card Building Functions

        private func buildLimitCard(title: String, current: Double, limit: Double, status: FRMSComplianceStatus, unit: String, accentColor: Color) -> some View {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(title)
                            .iPadScaledFont(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)

                        Spacer()

                        Image(systemName: status.icon)
                            .foregroundStyle(statusColor(status))
                            .iPadScaledFont(.headline)
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(current) : String(format: "%.1f", current))
                            .iPadScaledFont(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("/ \(Int(limit)) \(unit)")
                            .iPadScaledFont(.caption)
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor(status))
                                .frame(width: min(CGFloat(current / limit) * geometry.size.width, geometry.size.width), height: 6)
                        }
                    }
                    .frame(height: 6)
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

        private func buildConsecutiveInfoCard(totals: FRMSCumulativeTotals) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Consecutive Duties")
                    .iPadScaledFont(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    if let maxConsec = totals.maxConsecutiveDuties {
                        VStack {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totals.consecutiveDuties)")
                                    .font(.headline)
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
                                    .font(.headline)
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
                                    .font(.headline)
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
                                    .font(.headline)
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
            .padding(16)
            .appCardStyle()
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
                                .font(.headline)
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
                                .font(.headline)
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
                                .font(.headline)
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
                                .font(.headline)
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
        .appCardStyle()
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
        .appCardStyle()
    }

    // MARK: - Helper Methods

    /// Formats decimal hours respecting the Flight Times display setting.
    /// Returns "H:MM" in hrs:min mode, or "X.X hrs" in decimal mode.
    private func formatTime(_ decimalHours: Double) -> String {
        if appViewModel.showTimesInHoursMinutes {
            return decimalHours.toHoursMinutesString
        } else {
            return String(format: "%.1f hrs", decimalHours)
        }
    }

    private func updateMaxNextDuty() {
        // Use Class 1 as the default rest facility for augmented ops
        // (rest facility picker removed; all options shown in the duty limits table)
        let restFacility: RestFacilityClass = selectedCrewComplement == .twoPilot ? .none : .class1
        viewModel.maximumNextDuty = viewModel.calculateMaxNextDuty(
            crewComplement: selectedCrewComplement,
            restFacility: restFacility,
            limitType: viewModel.selectedLimitType
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

// MARK: - Disruption Rest — FD10.2.1

private struct DisruptionRestSection: View {
    @Binding var isExpanded: Bool
    @Binding var previousDutyHours: Double
    @Binding var tzDifference: Double
    @Binding var nextDutyOver16: Bool
    let crewComplement: CrewComplement

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: Clause calculations

    private var clauseI: Double {
        switch crewComplement {
        case .twoPilot:
            return previousDutyHours > 11.0 ? 12.0 : 10.0
        case .threePilot, .fourPilot:
            return previousDutyHours > 16.0 ? 24.0 : 12.0
        }
    }

    private var clauseII: Double? {
        guard previousDutyHours > 12.0 else { return nil }
        return 12.0 + 1.5 * (previousDutyHours - 12.0)
    }

    private var clauseIII: Double? {
        guard nextDutyOver16 else { return nil }
        switch crewComplement {
        case .twoPilot:   return nil
        case .threePilot: return 24.0
        case .fourPilot:  return 24.0
        }
    }

    private var effectiveRest: Double {
        let base = max(clauseI, clauseII ?? 0.0, clauseIII ?? 0.0)
        return base + max(0, tzDifference - 3)
    }

    // MARK: Body

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 0) {

                Text("Applies when a disruption occurs after commencement of a pattern. Uses crew complement and operating/deadheading selection from Rest Requirements above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)

                if horizontalSizeClass == .compact {
                    // iPhone: stacked layout
                    inputRows
                        .padding(.bottom, 12)
                    clauseRows
                    effectiveRestRow
                } else {
                    // iPad: inputs on left, clause results on right
                    HStack(alignment: .top, spacing: 24) {
                        inputRows
                            .frame(maxWidth: .infinity)
                        Divider()
                        VStack(alignment: .leading, spacing: 0) {
                            clauseRows
                            effectiveRestRow
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            Text("Disruption Rest — FD10.2.1")
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding()
        .appCardStyle()
    }

    // MARK: Sub-views

    @ViewBuilder
    private var inputRows: some View {
        VStack(spacing: 0) {
            // Previous Duty
            HStack {
                Text("Previous Duty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 0) {
                    Text(formatHoursMinutes(previousDutyHours))
                        .font(.subheadline)
                        .monospacedDigit()
                        .frame(minWidth: 44, alignment: .trailing)
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 8)
                    Button {
                        if previousDutyHours > 12.0 { previousDutyHours -= 0.25 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.subheadline)
                            .frame(width: 28, height: 28)
                    }
                    Divider()
                        .frame(height: 20)
                    Button {
                        if previousDutyHours < 24.0 { previousDutyHours += 0.25 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline)
                            .frame(width: 28, height: 28)
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 6))
                .padding(.trailing, 6)
            }
            .padding(.vertical, 10)

            Divider()

            // TZ Difference
            HStack {
                Text("TZ Difference")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 0) {
                    Text(tzDifference == 0 ? "None" : formatHoursMinutes(tzDifference))
                        .font(.subheadline)
                        .monospacedDigit()
                        .frame(minWidth: 64, alignment: .trailing)
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 8)
                    Button {
                        if tzDifference > 0 { tzDifference -= 0.5 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.subheadline)
                            .frame(width: 28, height: 28)
                    }
                    Divider()
                        .frame(height: 20)
                    Button {
                        if tzDifference < 12 { tzDifference += 0.5 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline)
                            .frame(width: 28, height: 28)
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 6))
                .padding(.trailing, 6)
            }
            .padding(.vertical, 10)

            Divider()

            // Next Duty Planned > 16 hrs
            HStack {
                Text("Next Duty Planned > 16 hrs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $nextDutyOver16)
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .padding(.trailing, 6)
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var clauseRows: some View {
        let ci   = clauseI
        let cii  = clauseII
        let ciii = clauseIII
        VStack(spacing: 0) {
            clauseRow(
                label: "Clause (i)",
                subtitle: "Standard FD10.1",
                value: ci,
                isBold: ci >= (cii ?? 0) && ci >= (ciii ?? 0)
            )

            Divider()

            if let ciiVal = cii {
                clauseRow(
                    label: "Clause (ii)",
                    subtitle: "12:00 + 1.5×\(formatHoursMinutes(previousDutyHours - 12.0))",
                    value: ciiVal,
                    isBold: ciiVal >= ci && ciiVal >= (ciii ?? 0)
                )
            } else {
                naRow(label: "Clause (ii)", subtitle: "Duty ≤ 12 hrs")
            }

            Divider()

            if let ciiiVal = ciii {
                clauseRow(
                    label: "Clause (iii)",
                    subtitle: "Planned > 16 hrs",
                    value: ciiiVal,
                    isBold: ciiiVal >= ci && ciiiVal >= (cii ?? 0)
                )
            } else {
                naRow(label: "Clause (iii)", subtitle: "Planned > 16 hrs")
            }
        }
    }

    private var effectiveRestRow: some View {
        HStack {
            Text("Minimum Rest")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Text(formatHoursMinutes(effectiveRest))
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 4)
    }

    // MARK: Row helpers

    private func clauseRow(label: String, subtitle: String, value: Double, isBold: Bool) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isBold ? .semibold : .regular)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatHoursMinutes(value))
                .font(.subheadline)
                .fontWeight(isBold ? .semibold : .regular)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }

    private func naRow(label: String, subtitle: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("N/A")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }
}
