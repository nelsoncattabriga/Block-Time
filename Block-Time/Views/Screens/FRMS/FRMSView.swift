//
//  FRMSView.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) Tab View
//  Displays flight/duty time limits and maximum next duty calculator
//

import SwiftUI

// MARK: - Helper Functions

func formatHoursMinutes(_ decimalHours: Double) -> String {
    // Use standardized conversion with proper rounding
    return decimalHours.toHoursMinutesString
}

struct FRMSView: View {

    @Bindable var viewModel: FRMSViewModel
    let flightTimePosition: FlightTimePosition
    /// Non-nil on iPad split view — indicates which section to show.
    /// Nil on iPhone (or iPad portrait) — all sections rendered as before.
    var selectedSection: FRMSSection? = nil
    @Environment(ThemeService.self) private var themeService
    @EnvironmentObject var appViewModel: FlightTimeExtractorViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // MBTT parameters (for A380/A330/B787)
    @State private var mbttDaysAwayCategory: String = "2-4"  // Options: "1", "2-4", "5-8", "9-12", ">12"
    @State private var mbttCreditedHoursCategory: String = "≤20"  // Options: "≤20", ">20", ">40", ">60"
    @State private var mbttHadDutyOver18Hours: Bool = false
    @State private var calculatedMBTT: FRMSMinimumBaseTurnaroundTime? = nil

    // LH section expansion state
    @State private var expandNextDutyLimits = false
    @State private var expandMinimumBaseTurnaround = false
    @State private var expandRecentDuties = false

    // LH limits reference sheet
    @State private var showLimitsReference = false

    // Cached home base timezone — set once on appear to avoid per-row FRMSCalculationService allocation
    @State private var homeBaseTimeZone: TimeZone = .current

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLimitsReference = true
                    } label: {
                        Image(systemName: "book.pages")
                    }
                }
            }
            .fullScreenCover(isPresented: $showLimitsReference) {
                if viewModel.configuration.fleet == .a380A330B787 {
                    LimitsReferenceSheet(
                        initialLimitType: viewModel.selectedLimitType,
                        planningResource: "lh_frms_planning_limits",
                        operationalResource: "lh_frms_operational_limits"
                    )
                } else {
                    LimitsReferenceSheet(
                        initialLimitType: viewModel.selectedLimitType,
                        planningResource: "sh_frms_planning_limits",
                        operationalResource: "sh_frms_operational_limits"
                    )
                }
            }
            .onAppear {
                //LogManager.shared.debug("FRMSView: onAppear called")
                viewModel.loadFlightData(crewPosition: flightTimePosition)
                updateMBTT()  // Initialize MBTT calculation
                homeBaseTimeZone = FRMSCalculationService(configuration: viewModel.configuration).getHomeBaseTimeZone()
            }
            .onChange(of: viewModel.configuration.homeBase) { _, _ in
                homeBaseTimeZone = FRMSCalculationService(configuration: viewModel.configuration).getHomeBaseTimeZone()
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
                            HStack(spacing: 6) {
                                Image(systemName: "airplane.departure")
                                    .foregroundStyle(AppColors.accentOrange)
                                Text("Next Duty Limits")
                            }
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
                        HStack(spacing: 6) {
                            Image(systemName: "house.fill")
                                .foregroundStyle(.purple)
                            Text("Minimum Base Turnaround Time")
                        }
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
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundStyle(AppColors.accentBlue)
                            Text("Recent Duties")
                        }
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
                            .iPadScaledFont(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
//                            .font(.headline.bold())
//                            .foregroundStyle(.secondary)
                        Text("\(formatHoursMinutes(limits.restCalculation.minimumRestHours)) hrs")
//                            .font(.headline)
                            .iPadScaledFont(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.accentOrange)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Earliest Sign-On")
                            .iPadScaledFont(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
//                            .font(.headline.bold())
//                            .foregroundStyle(.secondary)
                        Text(formatDateTime(limits.earliestSignOn))
//                            .font(.headline)
                            .iPadScaledFont(.subheadline)
                            .fontWeight(.bold)
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
                    totals: totals,
                    isInSplitView: selectedSection != nil
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

    @ViewBuilder
    private var maximumNextDutySection: some View {
        if viewModel.configuration.fleet == .a320B737 {
            SH_NextDutyView(viewModel: viewModel, isInSplitView: selectedSection != nil)
        } else {
            LH_NextDutyView(viewModel: viewModel)
        }
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
                                .foregroundStyle(.purple)

                            // Spacer()

                            Text(mbtt.description)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.purple)
                        }
                    }
                    .padding()
                    .background(.purple.opacity(0.1))
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

    private func dailyDutyRow(dailySummary: DailyDutySummary) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.accentBlue)
                .frame(width: 3)

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
                        .foregroundStyle(.secondary)
                }

                // Daily totals
                HStack(spacing: 16) {
                    Label {
                        Text("Duty: ").foregroundStyle(.secondary) + Text("\(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(dailySummary.totalDutyTime) : String(format: "%.1f", dailySummary.totalDutyTime)) hrs").foregroundStyle(AppColors.accentOrange)
                    } icon: {
                        Image(systemName: "clock")//.foregroundStyle(AppColors.accentOrange)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    
                    Label {
                        Text("Flight: ").foregroundStyle(.secondary) + Text("\(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(dailySummary.totalFlightTime) : String(format: "%.1f", dailySummary.totalFlightTime)) hrs").foregroundStyle(AppColors.accentBlue)
                    } icon: {
                        Image(systemName: "clock.badge.airplane")//.foregroundStyle(AppColors.accentBlue)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
            }
            .padding(12)
        }
        .appCardStyle()
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

        calculatedMBTT = viewModel.calculateMBTT(
            daysAway: daysAway,
            creditedFlightHours: creditedHours,
            hadPlannedDutyOver18Hours: mbttHadDutyOver18Hours
        )
    }

    // MARK: - Cached Date Formatters
    // Static so they're allocated once per app lifetime, not once per render call.

    private static let _dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM HHmm"
        return f
    }()

    private static let _timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HHmm"
        return f
    }()

    private static let _dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM - HHmm"
        return f
    }()

    private static let _localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self._dateFormatter.string(from: date)
    }

    private func formatLocalDate(_ date: Date) -> String {
        // homeBaseTimeZone is set once in onAppear (and on homeBase change)
        // — avoids allocating FRMSCalculationService for every row render.
        Self._localDateFormatter.timeZone = homeBaseTimeZone
        return Self._localDateFormatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        Self._timeFormatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        Self._dateTimeFormatter.string(from: date)
    }
}
