//
//  FRMSView.swift
//  Block-Time
//
//  FRMS (Fatigue Risk Management System) Tab View
//  Displays flight/duty time limits and maximum next duty calculator
//

import SwiftUI
import BlockTimeKit

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

    // Recent Duties period filter
    enum RecentDutiesMode: String {
        case thisBP, lastBP, specificBP
        case days7, days14, days28, days365
    }
    @AppStorage("frmsRecentDutiesMode") private var selectedMode: RecentDutiesMode = .thisBP
    @AppStorage("frmsRecentDutiesSelectedBP") private var selectedBP: String = ""

    // iPhone section tabs
    private enum FRMSScrollAnchor: String, CaseIterable {
        case cumulativeLimits = "Limits"
        case nextDuty         = "Next Duty"
        case recentDuties     = "Recent Duties"

        var icon: String {
            switch self {
            case .cumulativeLimits: return "chart.bar.fill"
            case .nextDuty:         return "clock.badge.checkmark"
            case .recentDuties:     return "list.bullet.clipboard.fill"
            }
        }

        var color: Color {
            switch self {
            case .cumulativeLimits: return .blue
            case .nextDuty:         return .orange
            case .recentDuties:     return .green
            }
        }
    }
    @State private var activePhoneSection: FRMSScrollAnchor = .cumulativeLimits

    // LH limits reference sheet
    @State private var showLimitsReference = false

    // Cached home base timezone — set once on appear to avoid per-row FRMSCalculationService allocation
    @State private var homeBaseTimeZone: TimeZone = .current

    var body: some View {
        NavigationStack {
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab strip — iPhone only, full-screen path only. Sits on the gradient.
                    if horizontalSizeClass == .compact && selectedSection == nil {
                        frmsTabStrip
                    }

                    ScrollView {
                        VStack(spacing: 20) {
                            if let section = selectedSection {
                                // iPad split view — show the selected section only
                                sectionContent(for: section)
                            } else if horizontalSizeClass == .compact {
                                // iPhone — show only the active tab section
                                iPhoneSectionContent
                            } else {
                                // iPad portrait — all sections, unchanged layout
                                allSectionsContent
                            }
                        }
                        .padding()
                        .frame(maxWidth: selectedSection == nil && horizontalSizeClass == .regular ? 800 : .infinity)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        LogManager.shared.debug("FRMSView: Pull-to-refresh triggered")
                        await viewModel.refreshFlightData(crewPosition: flightTimePosition, ignoresCooldown: true)
                        updateMBTT()
                    }
                    .opacity(viewModel.isLoading ? 0.3 : 1.0)
                }
            }
            .navigationTitle(selectedSection?.rawValue ?? "FRMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                // ViewModel observes .flightDataChanged directly and refreshes its own data.
                // Only update MBTT here (view-local state not owned by the ViewModel).
                updateMBTT()
            }
        }
    }

    // MARK: - Split View Section Content

    // MARK: - iPhone Section Content (pill-selected)

    @ViewBuilder
    private var iPhoneSectionContent: some View {
        switch activePhoneSection {
        case .cumulativeLimits:
            // Pass isInSplitView: true so AdaptiveCumulativeLimitsLayout
            // also renders Consecutive Duties and Late Night Ops cards here.
            iPhoneCumulativeLimitsSection

        case .nextDuty:
            // Minimum Rest at top, then Next Duty limits.
            // isInSplitView: true on SH_NextDutyView suppresses the
            // Consecutive Duties card (it now lives in Cumulative Limits).
            if viewModel.configuration.fleet == .a320B737,
               let limits = viewModel.a320B737NextDutyLimits {
                minimumRestSection(limits: limits)
            }
            if viewModel.configuration.fleet == .a380A330B787 {
                Picker("Limit Type", selection: $viewModel.selectedLimitType) {
                    Text("Planning").tag(FRMSLimitType.planning)
                    Text("Operational").tag(FRMSLimitType.operational)
                }
                .pickerStyle(.segmented)
            }
            if viewModel.configuration.fleet == .a320B737 {
                SH_NextDutyView(viewModel: viewModel, isInSplitView: true)
            } else {
                LH_NextDutyView(viewModel: viewModel)
            }

        case .recentDuties:
            recentDutiesSection
        }
    }

    private var iPhoneCumulativeLimitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let totals = viewModel.cumulativeTotals {
                AdaptiveCumulativeLimitsLayout(
                    viewModel: viewModel,
                    totals: totals,
                    isInSplitView: false,
                    showConsecutiveDutiesInCompact: true
                )
            } else {
                Text("No flight data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    // MARK: - iPad All-Sections Content

    /// All sections rendered sequentially — iPad portrait only (selectedSection == nil, regular size class).
    @ViewBuilder
    private var allSectionsContent: some View {
        // Minimum Rest above Cumulative Limits (legacy position)
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

                            Picker("Limit Type", selection: $viewModel.selectedLimitType) {
                                Text("Planning").tag(FRMSLimitType.planning)
                                Text("Operational").tag(FRMSLimitType.operational)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                            .padding(.trailing, 16)
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
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    }
                )
                .foregroundStyle(.primary)
            }
        } else {
            recentDutiesSection
        }
    }

    // MARK: - iPhone Tab Strip

    private var frmsTabStrip: some View {
        HStack(spacing: 0) {
            ForEach(FRMSScrollAnchor.allCases, id: \.self) { anchor in
                let isActive = activePhoneSection == anchor
                Button {
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.18)) {
                        activePhoneSection = anchor
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: anchor.icon)
                            .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? anchor.color : .secondary)
                        Text(anchor.rawValue)
                            .font(.caption)
                            .fontWeight(isActive ? .semibold : .regular)
                            .foregroundStyle(isActive ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isActive ? AnyShapeStyle(Color(.tertiarySystemFill)) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
            frmsSectionHeader("Minimum Rest")

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

            if limits.backOfClockRestriction != nil || (limits.lateNightStatus?.hasActiveRestriction == true) || limits.consecutiveDutyStatus.hasActiveRestrictions {
                activeRestrictionsSection(limits: limits)
            }
        }
    }

    // MARK: - Cumulative Limits Section

    private var cumulativeLimitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    // iPad: stacked layout — pickers full width, toggle below
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
                        Toggle(isOn: $mbttHadDutyOver18Hours) {
                            Text("Planned duty >18 hrs")
                                .font(.subheadline)
                        }
                        .onChange(of: mbttHadDutyOver18Hours) { _, newValue in
                            LogManager.shared.debug("FRMSView: MBTT duty over 18 hours changed to \(newValue)")
                            updateMBTT()
                        }
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

    private var isShortHaul: Bool { viewModel.configuration.fleet == .a320B737 }

    // All unique BP numbers present in the last 365 days of data, newest first.
    private var availableBPs: [(bp: String, startDate: Date, endDate: Date)] {
        var seen = Set<String>()
        var results: [(bp: String, startDate: Date, endDate: Date)] = []
        for summary in viewModel.recentDutiesByDay {
            guard let period = BPCalculator.rosterPeriod(containing: summary.date, isShortHaul: isShortHaul),
                  !seen.contains(period.bp) else { continue }
            seen.insert(period.bp)
            results.append(period)
        }
        return results.sorted { $0.startDate > $1.startDate }
    }

    private var activeBPRange: (start: Date, end: Date)? {
        let now = Date()
        let cal = Calendar.current
        switch selectedMode {
        case .thisBP:
            return BPCalculator.rosterPeriod(containing: now, isShortHaul: isShortHaul)
                .map { ($0.startDate, $0.endDate) }
        case .lastBP:
            let offset = isShortHaul ? -28 : -56
            let prev = cal.date(byAdding: .day, value: offset, to: now)!
            return BPCalculator.rosterPeriod(containing: prev, isShortHaul: isShortHaul)
                .map { ($0.startDate, $0.endDate) }
        case .specificBP:
            return availableBPs.first { $0.bp == selectedBP }.map { ($0.startDate, $0.endDate) }
        case .days7:
            return (cal.date(byAdding: .day, value: -7, to: now)!, now)
        case .days14:
            return (cal.date(byAdding: .day, value: -14, to: now)!, now)
        case .days28:
            return (cal.date(byAdding: .day, value: -28, to: now)!, now)
        case .days365:
            return (cal.date(byAdding: .day, value: -365, to: now)!, now)
        }
    }

    private var filteredRecentDuties: [DailyDutySummary] {
        guard let range = activeBPRange else { return [] }
        return viewModel.recentDutiesByDay.filter { $0.date >= range.start && $0.date <= range.end }
    }

    private var pickerLabel: String {
        switch selectedMode {
        case .thisBP:
            if let bp = BPCalculator.rosterPeriod(containing: Date(), isShortHaul: isShortHaul) {
                return "BP \(bp.bp)"
            }
            return "This BP"
        case .lastBP:
            let offset = isShortHaul ? -28 : -56
            let prev = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
            if let bp = BPCalculator.rosterPeriod(containing: prev, isShortHaul: isShortHaul) {
                return "BP \(bp.bp)"
            }
            return "Last BP"
        case .specificBP:
            return selectedBP.isEmpty ? "Select BP" : "BP \(selectedBP)"
        case .days7:   return "Last 7 Days"
        case .days14:  return "Last 14 Days"
        case .days28:  return "Last 28 Days"
        case .days365: return "Last 365 Days"
        }
    }

    private var recentDutiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                frmsSectionHeader("Recent Duties")
                Menu {
                    Button("This BP") { selectedMode = .thisBP }
                    Button("Last BP") { selectedMode = .lastBP }
                    Menu("Select BP") {
                        ForEach(availableBPs, id: \.bp) { period in
                            Button("BP \(period.bp)") {
                                selectedBP = period.bp
                                selectedMode = .specificBP
                            }
                        }
                    }
                    Divider()
                    Button("Last 7 Days")   { selectedMode = .days7 }
                    Button("Last 14 Days")  { selectedMode = .days14 }
                    Button("Last 28 Days")  { selectedMode = .days28 }
                    Button("Last 365 Days") { selectedMode = .days365 }
                } label: {
                    HStack(spacing: 4) {
                        Text(pickerLabel)
                            .iPadScaledFont(.subheadline, phoneFont: .subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.up.chevron.down")
                            .iPadScaledFont(.subheadline, phoneFont: .footnote)
                    }
                    .foregroundStyle(AppColors.accentBlue)
                }
                .accessibilityLabel("Recent duties period")
            }

            if !filteredRecentDuties.isEmpty {
                VStack(spacing: 8) {
                    ForEach(filteredRecentDuties) { dailySummary in
                        dailyDutyRow(dailySummary: dailySummary)
                    }
                }
            } else {
                Text("No duties in this period")
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
                        let dutyStr = appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(dailySummary.factoredDutyTime) : String(format: "%.1f", dailySummary.factoredDutyTime)
                        if dailySummary.hasSimulatorDuty {
                            return Text("Duty: ").foregroundStyle(.secondary)
                                + Text("\(dutyStr) hrs").foregroundStyle(AppColors.accentOrange)
                                + Text(" (1.5×)").foregroundStyle(.secondary).font(.footnote)
                        } else {
                            return Text("Duty: ").foregroundStyle(.secondary)
                                + Text("\(dutyStr) hrs").foregroundStyle(AppColors.accentOrange)
                        }
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)

                    if dailySummary.totalFlightTime > 0 {
                        Label {
                            Text("Flight: ").foregroundStyle(.secondary) + Text("\(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(dailySummary.totalFlightTime) : String(format: "%.1f", dailySummary.totalFlightTime)) hrs").foregroundStyle(AppColors.accentBlue)
                        } icon: {
                            Image(systemName: "clock.badge.airplane")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    } else if dailySummary.hasSimulatorDuty {
                        Label {
                            Text("Sim: ").foregroundStyle(.secondary) + Text("\(appViewModel.showTimesInHoursMinutes ? formatHoursMinutes(dailySummary.totalSimDutyTime) : String(format: "%.1f", dailySummary.totalSimDutyTime)) hrs").foregroundStyle(AppColors.accentBlue)
                        } icon: {
                            Image(systemName: "clock.badge.airplane")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    }
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

    // MARK: - Active Restrictions

    private func activeRestrictionsSection(limits: A320B737NextDutyLimits) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Restrictions")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            if limits.backOfClockRestriction != nil && limits.lateNightStatus?.recoveryOption != .require24HoursOff {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Back of Clock Restriction")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 6) {
                        Text("FD24.5")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Sign-On no earlier than 1000 local")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let lateNight = limits.lateNightStatus, lateNight.hasActiveRestriction {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Late Night Operations")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        if lateNight.recoveryOption == .require24HoursOff {
                            HStack(spacing: 6) {
                                Text("FD24.1")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("More than 2 LNO duties — 24 hrs rest required")
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
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
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if limits.consecutiveDutyStatus.hasActiveRestrictions {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
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

    private func formatDateTime(_ date: Date) -> String {
        // Display in the arrival airport's local timezone (DST-aware), falling back to UTC
        let toAirport = viewModel.lastDuty?.toAirport ?? ""
        if let tz = AirportService.shared.getTimeZone(for: toAirport, on: date) {
            Self._dateTimeFormatter.timeZone = tz
        } else {
            Self._dateTimeFormatter.timeZone = .current
        }
        return Self._dateTimeFormatter.string(from: date)
    }
}

