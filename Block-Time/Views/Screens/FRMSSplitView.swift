//
//  FRMSSplitView.swift
//  Block-Time
//
//  iPad split-view wrapper for the FRMS tab.
//  On iPad (regular horizontal size class) a sidebar lists FRMS sections and
//  the detail pane shows the persistent FRMSView. On iPhone the layout is
//  unchanged — FRMSView renders all sections exactly as before.
//

import SwiftUI

// MARK: - FRMS Section Enum

enum FRMSSection: String, Hashable, CaseIterable {
    case cumulativeLimits   = "Cumulative Limits"
    case nextDuty           = "Next Duty Limits"
    case minBaseTurnaround  = "Min. Base Turnaround"   // A380/A330/B787 only
    case recentDuties       = "Recent Duties"

    var icon: String {
        switch self {
        case .cumulativeLimits:  return "chart.bar.fill"
        case .nextDuty:          return "clock.badge.checkmark"
        case .minBaseTurnaround: return "house.fill"
        case .recentDuties:      return "list.bullet.clipboard.fill"
        }
    }

    var color: Color {
        switch self {
        case .cumulativeLimits:  return .blue
        case .nextDuty:          return .orange
        case .minBaseTurnaround: return .purple
        case .recentDuties:      return .green
        }
    }

    var subtitle: String {
        switch self {
        case .cumulativeLimits:  return "Flight & duty time totals"
        case .nextDuty:          return "Max duty & rest requirements"
        case .minBaseTurnaround: return "Minimum home-base rest"
        case .recentDuties:      return "Recent duty history"
        }
    }
}

// MARK: - FRMS Split View

struct FRMSSplitView: View {
    @ObservedObject var flightTimeVM: FlightTimeExtractorViewModel
    @ObservedObject var frmsViewModel: FRMSViewModel
    @State private var selectedSection: FRMSSection? = .cumulativeLimits
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    private var shouldUseSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    /// Fleet-filtered list of sections — hides minBaseTurnaround for A320/B737.
    private var availableSections: [FRMSSection] {
        FRMSSection.allCases.filter { section in
            if section == .minBaseTurnaround {
                return frmsViewModel.configuration.fleet == .a380A330B787
            }
            return true
        }
    }

    var body: some View {
        if shouldUseSplitView {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                FRMSSidebarContent(
                    selectedSection: $selectedSection,
                    availableSections: availableSections,
                    viewModel: frmsViewModel
                )
                .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 450)
            } detail: {
                // Persistent detail pane — FRMSView is never recreated when
                // selectedSection changes, so all @State calculator values persist.
                FRMSView(
                    viewModel: frmsViewModel,
                    flightTimePosition: flightTimeVM.flightTimePosition,
                    selectedSection: selectedSection
                )
                .environmentObject(flightTimeVM)
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && shouldUseSplitView {
                    columnVisibility = .doubleColumn
                }
            }
            .onChange(of: frmsViewModel.configuration.fleet) { _, _ in
                // If the selected section is no longer available for the new fleet,
                // reset to Cumulative Limits (always available).
                if let current = selectedSection,
                   !availableSections.contains(current) {
                    selectedSection = .cumulativeLimits
                }
            }
        } else {
            // iPhone or iPad portrait: unchanged single-column layout.
            FRMSView(
                viewModel: frmsViewModel,
                flightTimePosition: flightTimeVM.flightTimePosition
            )
            .environmentObject(flightTimeVM)
        }
    }
}

// MARK: - FRMS Sidebar Content

private struct FRMSSidebarContent: View {
    @Binding var selectedSection: FRMSSection?
    let availableSections: [FRMSSection]
    @ObservedObject var viewModel: FRMSViewModel

    var body: some View {
        List(selection: $selectedSection) {
            ForEach(availableSections, id: \.self) { section in
                HStack(spacing: 0) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.rawValue)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(section.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: section.icon)
                            .foregroundColor(section.color)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(section.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.leading, 8)

                    Spacer()

                    // Compliance badge on Cumulative Limits row
                    if section == .cumulativeLimits,
                       let totals = viewModel.cumulativeTotals {
                        complianceBadge(for: totals)
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 6, bottom: 16, trailing: 6))
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSection == section ? section.color.opacity(0.1) : Color.clear)
                        .padding(.vertical, 2)
                        .padding(.leading, 4)
                )
                .tag(section)
            }
        }
        .onChange(of: selectedSection) { _, newValue in
            if newValue != nil {
                HapticManager.shared.impact(.light)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("FRMS")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Compliance Badge

    /// At-a-glance status badge: green ✓, orange ⚠, or red ✗ based on worst limit.
    @ViewBuilder
    private func complianceBadge(for totals: FRMSCumulativeTotals) -> some View {
        let worst = worstStatus(totals: totals)
        Image(systemName: worst.icon)
            .foregroundStyle(badgeColor(worst))
            .font(.subheadline)
            .padding(.trailing, 4)
    }

    private func worstStatus(totals: FRMSCumulativeTotals) -> FRMSComplianceStatus {
        let statuses: [FRMSComplianceStatus] = [
            totals.status28Days,
            totals.status365Days,
            totals.dutyStatus7Days,
            totals.dutyStatus14Days
        ]
        if statuses.contains(where: { if case .violation = $0 { return true }; return false }) {
            return .violation(message: "")
        }
        if statuses.contains(where: { if case .warning = $0 { return true }; return false }) {
            return .warning(message: "")
        }
        return .compliant
    }

    private func badgeColor(_ status: FRMSComplianceStatus) -> Color {
        switch status {
        case .compliant:  return .green
        case .warning:    return .orange
        case .violation:  return .red
        }
    }
}

// MARK: - FRMS Empty Detail View

struct FRMSEmptyDetailView: View {
    @Environment(ThemeService.self) private var themeService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            Text("Select a Section")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Choose a category from the sidebar")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            themeService.getGradient()
                .ignoresSafeArea()
        )
    }
}

#Preview {
    FRMSSplitView(
        flightTimeVM: FlightTimeExtractorViewModel(),
        frmsViewModel: FRMSViewModel()
    )
}
